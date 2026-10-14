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


func write_dictionary(path: String, data: Dictionary) -> Dictionary:
	if path.is_empty():
		return {"ok": false, "error": "invalid_path"}
	var snapshot := data.duplicate(true)
	_mutex.lock()
	if not _last_failure.is_empty():
		var failure := _last_failure.duplicate()
		_mutex.unlock()
		return failure
	# Coalesce snapshots while preserving the order of their latest writes.
	# A completed record must reach disk before the subsequent session clear.
	_pending.erase(path)
	_pending[path] = snapshot
	var start_worker := not _working
	_working = true
	_mutex.unlock()
	if start_worker:
		if _task_id >= 0:
			WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = WorkerThreadPool.add_task(_drain, false, "JIGCAT save")
	return {"ok": true, "queued": true}


func flush() -> Dictionary:
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
			_mutex.unlock()
			push_error("Save failed: %s" % str(saved.get("error", "unknown")))
