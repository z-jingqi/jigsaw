class_name AlbumThumbnailLoader
extends Node
## Shared, bounded thumbnail loading survives card recycling and screen transitions.

const MAX_IN_FLIGHT := 3
const CACHE_LIMIT := 16
const CACHE_BYTE_LIMIT := 24 * 1024 * 1024

var _watchers: Dictionary = {}
var _queued: Array[String] = []
var _in_flight: Array[String] = []
var _cache: Dictionary = {}
var _order: Array[String] = []
var _cache_bytes := 0


func _ready() -> void:
	set_process(false)


func watch(card: AlbumCard) -> void:
	var path := str(card.model.get("thumbnail_path", ""))
	var id := card.get_instance_id()
	if str(_watchers.get(id, "")) == path:
		return
	unwatch(card)
	if path.is_empty():
		return
	_watchers[id] = path
	if _cache.has(path):
		_touch(path)
		card.apply_thumbnail(path, _cache[path].texture)
	elif not _queued.has(path) and not _in_flight.has(path):
		_queued.append(path)
	set_process(not _queued.is_empty() or not _in_flight.is_empty())


func unwatch(card: AlbumCard) -> void:
	_watchers.erase(card.get_instance_id())
	card.release_thumbnail()


func debug_state_snapshot() -> Dictionary:
	return {
		"watched_cards": _watchers.size(),
		"queued": _queued.size(),
		"in_flight": _in_flight.size(),
		"cached_textures": _cache.size(),
		"estimated_cache_bytes": _cache_bytes,
	}


func _process(_delta: float) -> void:
	for path in _in_flight.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var texture := ResourceLoader.load_threaded_get(path) as Texture2D
			_in_flight.erase(path)
			if texture != null:
				_remember(path, texture)
				_deliver(path, texture)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(path)
			_in_flight.erase(path)
	while _in_flight.size() < MAX_IN_FLIGHT and not _queued.is_empty():
		var path: String = _queued.pop_front()
		if not _is_watched(path) or not ResourceLoader.exists(path):
			continue
		if ResourceLoader.load_threaded_request(path, "Texture2D") == OK:
			_in_flight.append(path)
	set_process(not _queued.is_empty() or not _in_flight.is_empty())


func _is_watched(path: String) -> bool:
	for id in _watchers.keys():
		if not is_instance_id_valid(id):
			_watchers.erase(id)
		elif str(_watchers[id]) == path:
			return true
	return false


func _deliver(path: String, texture: Texture2D) -> void:
	for id in _watchers:
		var card := instance_from_id(id) as AlbumCard if is_instance_id_valid(id) else null
		if card != null and str(_watchers[id]) == path:
			card.apply_thumbnail(path, texture)


func _remember(path: String, texture: Texture2D) -> void:
	var bytes := texture.get_width() * texture.get_height() * 4
	if _cache.has(path):
		_cache_bytes -= int(_cache[path].bytes)
	_cache[path] = {"texture": texture, "bytes": bytes}
	_cache_bytes += bytes
	_touch(path)
	while _order.size() > CACHE_LIMIT or _cache_bytes > CACHE_BYTE_LIMIT:
		var oldest: String = _order.pop_front()
		_cache_bytes -= int(_cache[oldest].bytes)
		_cache.erase(oldest)


func _touch(path: String) -> void:
	_order.erase(path)
	_order.append(path)


func _exit_tree() -> void:
	for path in _in_flight:
		ResourceLoader.load_threaded_get(path)
	_in_flight.clear()
	_queued.clear()
	_watchers.clear()
	_cache.clear()
	_order.clear()
