class_name AlbumImageCache
extends Node
## Main-thread publication of bounded asynchronous original/thumbnail resources.
## Requests are replaceable slots, not a FIFO of every intermediate selection.

const MAX_IN_FLIGHT := 2
const FULL_LIMIT := 3
const FULL_BYTES := 24 * 1024 * 1024
const THUMB_LIMIT := 16
const THUMB_BYTES := 12 * 1024 * 1024

var _watchers: Dictionary = {}
var _in_flight: Dictionary = {}
var _cache: Dictionary = {}
var _order: Array[String] = []
var _serial := 0
var _loaded := 0
var _discarded := 0
var _peak_in_flight := 0


func _ready() -> void:
	set_process(false)


func watch(
	owner: Object, slot: String, path: String, callback: Callable, kind := "full", priority := 0
) -> void:
	var key := _key(owner, slot)
	_serial += 1
	_watchers.erase(key)
	if path.is_empty():
		return
	_watchers[key] = {
		"owner": weakref(owner),
		"path": path,
		"callback": callback,
		"kind": kind,
		"priority": priority,
		"serial": _serial,
	}
	if _cache.has(path):
		_touch(path)
		_watchers[key].delivered = true
		if callback.is_valid():
			callback.call(path, _cache[path].texture)
	set_process(true)


func unwatch(owner: Object, slot: String) -> void:
	_watchers.erase(_key(owner, slot))


func unwatch_owner(owner: Object) -> void:
	var prefix := str(owner.get_instance_id()) + ":"
	for key: String in _watchers.keys():
		if key.begins_with(prefix):
			_watchers.erase(key)


func get_cached(path: String) -> Texture2D:
	if not _cache.has(path):
		return null
	_touch(path)
	return _cache[path].texture


func _process(_delta: float) -> void:
	_prune()
	for path: String in _in_flight.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var kind: String = _in_flight[path]
		_in_flight.erase(path)
		var texture: Texture2D
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			texture = ResourceLoader.load_threaded_get(path) as Texture2D
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(path)
		if not _wanted(path):
			_discarded += 1
			continue
		if texture != null:
			_remember(path, texture, kind)
			_loaded += 1
		_deliver(path, texture)
	var pending := _pending()
	for request: Dictionary in pending:
		if _in_flight.size() >= MAX_IN_FLIGHT:
			break
		var path: String = request.path
		if not ResourceLoader.exists(path):
			_deliver(path, null)
			continue
		var error := ResourceLoader.load_threaded_request(
			path, "Texture2D", false, ResourceLoader.CACHE_MODE_IGNORE
		)
		if error == OK:
			_in_flight[path] = request.kind
			_peak_in_flight = maxi(_peak_in_flight, _in_flight.size())
		else:
			_deliver(path, null)
	set_process(not _in_flight.is_empty() or not _pending().is_empty())


func _pending() -> Array[Dictionary]:
	var requests: Dictionary = {}
	for item: Dictionary in _watchers.values():
		var path: String = item.path
		if _cache.has(path) or _in_flight.has(path) or bool(item.get("delivered", false)):
			continue
		if not requests.has(path) or _before(item, requests[path]):
			requests[path] = item
	var result: Array[Dictionary] = []
	result.assign(requests.values())
	result.sort_custom(_before)
	return result


func _before(a: Dictionary, b: Dictionary) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.serial > b.serial


func _prune() -> void:
	for key in _watchers.keys():
		var item: Dictionary = _watchers[key]
		if item.owner.get_ref() == null or not item.callback.is_valid():
			_watchers.erase(key)


func _wanted(path: String) -> bool:
	for item: Dictionary in _watchers.values():
		if item.path == path:
			return true
	return false


func _deliver(path: String, texture: Texture2D) -> void:
	# Snapshot keys: callbacks can replace/unwatch their own slots synchronously.
	for key in _watchers.keys():
		if not _watchers.has(key):
			continue
		var item: Dictionary = _watchers[key]
		if item.path != path or item.owner.get_ref() == null:
			continue
		item.delivered = true
		if item.callback.is_valid():
			item.callback.call(path, texture)


func _remember(path: String, texture: Texture2D, kind: String) -> void:
	_cache[path] = {
		"texture": texture,
		"kind": kind,
		"bytes": texture.get_width() * texture.get_height() * 4 * 4 / 3,
	}
	_touch(path)
	var limit := FULL_LIMIT if kind == "full" else THUMB_LIMIT
	var byte_limit := FULL_BYTES if kind == "full" else THUMB_BYTES
	while _count(kind) > limit or _bytes(kind) > byte_limit:
		for oldest in _order:
			if _cache[oldest].kind == kind:
				_order.erase(oldest)
				_cache.erase(oldest)
				break


func _count(kind: String) -> int:
	var count := 0
	for entry: Dictionary in _cache.values():
		if entry.kind == kind:
			count += 1
	return count


func _bytes(kind: String) -> int:
	var count := 0
	for entry: Dictionary in _cache.values():
		if entry.kind == kind:
			count += int(entry.bytes)
	return count


func _touch(path: String) -> void:
	_order.erase(path)
	_order.append(path)


func _key(owner: Object, slot: String) -> String:
	return "%d:%s" % [owner.get_instance_id(), slot]


func debug_state_snapshot() -> Dictionary:
	return {
		"watchers": _watchers.size(),
		"queued": _pending().size(),
		"in_flight": _in_flight.size(),
		"peak_in_flight": _peak_in_flight,
		"full_count": _count("full"),
		"full_bytes": _bytes("full"),
		"thumb_count": _count("thumb"),
		"thumb_bytes": _bytes("thumb"),
		"loaded": _loaded,
		"discarded": _discarded,
	}


func _exit_tree() -> void:
	# This service survives all album routes. Only whole-product shutdown reaches
	# this hook: reap the at-most-two engine tasks, without publishing callbacks.
	# Ordinary Back/unwatch is non-blocking and never joins resource work.
	_watchers.clear()
	var started := Time.get_ticks_usec()
	var pending := _in_flight.size()
	for path: String in _in_flight.keys():
		ResourceLoader.load_threaded_get(path)
	if pending > 0:
		print("AlbumImageCache shutdown: jobs=", pending, " usec=", Time.get_ticks_usec() - started)
	_in_flight.clear()
	_cache.clear()
	_order.clear()
