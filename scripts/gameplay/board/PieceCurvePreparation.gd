extends Node
## Bounded CPU-only jobs; main-thread texture publication, never scene work on workers.

const FrameGate := preload("res://scripts/runtime/CancellableFrame.gd")
const Field := preload("res://scripts/gameplay/board/PieceCurveField.gd")
const MAX_JOBS := 2

static var _service: WeakRef
var _jobs: Dictionary = {}
var completed_jobs := 0
var canceled_jobs := 0
var maximum_upload_usec := 0
var maximum_active_jobs := 0
var maximum_worker_frame_usec := 0
var _last_process_usec := 0
var _previously_active := false
var last_batch_ms := 0
var worker_total_usec := 0
var maximum_worker_usec := 0
var disk_hits := 0


class Job:
	extends RefCounted
	var mutex := Mutex.new()
	var canceled := false
	var task := -1
	var consumers := 0
	var finished := false
	var published := false
	var data: Dictionary = {}
	var points := PackedVector2Array()
	var width := 0.0

	func cancel() -> void:
		mutex.lock()
		canceled = true
		mutex.unlock()

	func is_canceled() -> bool:
		mutex.lock()
		var value := canceled
		mutex.unlock()
		return value

	func run() -> void:
		data = Field.bake_data(points, width, is_canceled)


class Batch:
	extends RefCounted
	var finished := 0
	var failed := false


static func prepare_many(
	pieces: Array, tree: SceneTree, current: Callable, canceled: Signal
) -> bool:
	var started := Time.get_ticks_msec()
	var batch := Batch.new()
	for lane in MAX_JOBS:
		_prepare_lane(pieces, lane, tree, current, batch, canceled)
	while batch.finished < MAX_JOBS:
		if not current.call():
			return false
		await FrameGate.wait(tree.process_frame, canceled)
	var service: Node = _service.get_ref() if _service != null else null
	if service != null:
		service.last_batch_ms = Time.get_ticks_msec() - started
	return not batch.failed and current.call()


static func _prepare_lane(
	pieces: Array, lane: int, tree: SceneTree, current: Callable, batch: Batch, canceled: Signal
) -> void:
	for index in range(lane, pieces.size(), MAX_JOBS):
		var points: PackedVector2Array = pieces[index]["polygon"]
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		var ready := await prepare(
			points, minf(bounds.size.x, bounds.size.y) * 0.065, tree, current, canceled
		)
		if not ready:
			batch.failed = true
			break
	batch.finished += 1


static func prepare(
	points: PackedVector2Array, width: float, tree: SceneTree, current: Callable, canceled: Signal
) -> bool:
	if not Field.get_cached(points, width).is_empty():
		return current.call()
	var service: Node = _service.get_ref() if _service != null else null
	if service == null:
		service = load("res://scripts/gameplay/board/PieceCurvePreparation.gd").new()
		service.name = "PieceCurvePreparation"
		tree.root.add_child(service)
		_service = weakref(service)
	return await service.request(points, width, tree, current, canceled)


func request(
	points: PackedVector2Array, width: float, tree: SceneTree, current: Callable, canceled: Signal
) -> bool:
	var key: String = Field.key_for(points, width)
	while _jobs.size() >= MAX_JOBS and not _jobs.has(key):
		if not current.call():
			return false
		await FrameGate.wait(tree.process_frame, canceled)
	if not current.call():
		return false
	if not Field.get_cached(points, width).is_empty():
		return true
	var job: Job = _jobs.get(key)
	# A superseded canceled job cannot be adopted by a fresh session.
	while job != null and job.is_canceled():
		if not current.call():
			return false
		await FrameGate.wait(tree.process_frame, canceled)
		job = _jobs.get(key)
	if job == null:
		job = Job.new()
		job.points = points.duplicate()
		job.width = width
		_jobs[key] = job
		job.task = WorkerThreadPool.add_task(job.run, false, "Curved piece field")
		maximum_active_jobs = maxi(maximum_active_jobs, _jobs.size())
	job.consumers += 1
	while not job.finished:
		if not current.call():
			job.consumers -= 1
			if job.consumers == 0:
				job.cancel()
			return false
		await FrameGate.wait(tree.process_frame, canceled)
	job.consumers -= 1
	return current.call() and job.published


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _previously_active and not _jobs.is_empty() and _last_process_usec > 0:
		maximum_worker_frame_usec = maxi(maximum_worker_frame_usec, now - _last_process_usec)
	_last_process_usec = now
	_previously_active = not _jobs.is_empty()
	# At most one small texture upload per frame, never block waiting for CPU work.
	for key in _jobs.keys():
		var job: Job = _jobs[key]
		if not WorkerThreadPool.is_task_completed(job.task):
			continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		if not job.is_canceled() and job.consumers > 0 and not job.data.is_empty():
			worker_total_usec += int(job.data.get("bake_usec", 0))
			maximum_worker_usec = maxi(maximum_worker_usec, int(job.data.get("bake_usec", 0)))
			disk_hits += int(bool(job.data.get("disk_cache_hit", false)))
			var started := Time.get_ticks_usec()
			var field := Field.publish(job.points, job.width, job.data)
			maximum_upload_usec = maxi(maximum_upload_usec, Time.get_ticks_usec() - started)
			job.published = field.get("texture") != null
			completed_jobs += 1
		else:
			canceled_jobs += 1
		job.data.clear()
		job.finished = true
		_jobs.erase(key)
		break


func debug_snapshot() -> Dictionary:
	return {
		"worker_frame_max_usec": maximum_worker_frame_usec,
		"last_batch_ms": last_batch_ms,
		"worker_total_usec": worker_total_usec,
		"maximum_worker_usec": maximum_worker_usec,
		"disk_hits": disk_hits,
		"active": _jobs.size(),
		"maximum_active": maximum_active_jobs,
		"completed": completed_jobs,
		"canceled": canceled_jobs,
		"maximum_upload_usec": maximum_upload_usec,
	}


func _exit_tree() -> void:
	for job: Job in _jobs.values():
		job.cancel()
	for job: Job in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(job.task)
		job.finished = true
	_jobs.clear()
