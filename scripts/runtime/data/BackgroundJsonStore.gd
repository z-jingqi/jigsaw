class_name BackgroundJsonStore
extends AtomicJsonStore
## Serializes immutable save snapshots away from the rendering thread.

var _writer := AtomicJsonStore.new()
var _mutex := Mutex.new()
var _pending: Dictionary = {}
var _working := false
var _task_id := -1
var _last_failure: Dictionary = {}


func load_dictionary(path: String) -> Dictionary:
	flush()
	return _writer.load_dictionary(path)


func load_validated_dictionary(path: String, validator: Callable) -> Dictionary:
	flush()
	return _writer.load_validated_dictionary(path, validator)


func load_status(path: String) -> Dictionary:
	return _writer.load_status(path)


func write_dictionary(path: String, data: Dictionary) -> Dictionary:
	var permitted := _writer.can_write(path, data)
	if not permitted.ok:
		return permitted
	var snapshot := data.duplicate(true)
	_mutex.lock()
	# Coalesce without moving a queued path behind its dependent writes.
	# In particular, a retained failed progress record stays ahead of cleanup.
	_pending[path] = snapshot
	var start_worker := not _working
	_working = true
	if start_worker:
		_last_failure = {}
	_mutex.unlock()
	if start_worker:
		if _task_id >= 0:
			WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = WorkerThreadPool.add_task(_drain, false, "JIGCAT save")
	return {"ok": true, "queued": true}


func flush() -> Dictionary:
	# A later explicit flush retries retained failures once. The flush that joins
	# a failed task still reports that failure instead of hiding it with a retry.
	if _task_id < 0:
		_mutex.lock()
		var retry := not _working and not _pending.is_empty()
		if retry:
			_working = true
			_last_failure = {}
		_mutex.unlock()
		if retry:
			_task_id = WorkerThreadPool.add_task(_drain, false, "JIGCAT save retry")
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
	_mutex.lock()
	var result := {"ok": true} if _last_failure.is_empty() else _last_failure.duplicate()
	_mutex.unlock()
	return result


func _drain() -> void:
	while true:
		_mutex.lock()
		if _pending.is_empty():
			_working = false
			_mutex.unlock()
			return
		var path: String = _pending.keys()[0]
		var snapshot: Dictionary = _pending[path]
		_pending.erase(path)
		_mutex.unlock()
		var saved := _writer.write_dictionary(path, snapshot)
		if not bool(saved.get("ok", false)):
			_mutex.lock()
			_last_failure = saved.duplicate()
			_last_failure["path"] = path
			# Never lose the failed payload or pass it with a dependent session
			# clear. A newer queued snapshot for this path supersedes the old one.
			var retained := {path: _pending.get(path, snapshot)}
			for queued_path in _pending:
				if queued_path != path:
					retained[queued_path] = _pending[queued_path]
			_pending = retained
			_working = false
			_mutex.unlock()
			return
