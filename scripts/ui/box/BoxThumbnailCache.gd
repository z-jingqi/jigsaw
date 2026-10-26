class_name BoxThumbnailCache
extends Node
## One offscreen renderer, serial jobs and a bounded cache shared by virtual cards.

const BoxScene := preload("res://scenes/ui/box/PuzzleBox3D.tscn")
const MAX_ENTRIES := 24
const RENDER_SIZE := Vector2i(512, 683)
const SINGLETON_NAME := "BoxThumbnailCache"
var _renderer: Control
var _entries: Dictionary = {}
var _lru: Array[String] = []
var _jobs: Dictionary = {}
var _queue: Array[String] = []
var _active_key := ""
var _frames := 0
var _capturing := false
var _epoch := 0


static func shared(tree: SceneTree) -> Node:
	var found := tree.root.get_node_or_null(SINGLETON_NAME)
	if found != null:
		return found
	var cache := BoxThumbnailCache.new()
	cache.name = SINGLETON_NAME
	tree.root.add_child(cache)
	return cache


func _ready() -> void:
	add_to_group("runtime_box_cache")
	_renderer = BoxScene.instantiate()
	_renderer.position = Vector2(-10000, -10000)
	_renderer.size = Vector2(RENDER_SIZE)
	_renderer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_renderer)
	_renderer.call("set_rendering", false)


func request(key: String, texture: Texture2D, packaging: Dictionary, callback: Callable) -> void:
	if _entries.has(key):
		_touch(key)
		callback.call_deferred(_entries[key])
		return
	if _jobs.has(key):
		_jobs[key].callbacks.append(callback)
		return
	_jobs[key] = {"texture": texture, "packaging": packaging, "callbacks": [callback]}
	_queue.append(key)


func pause_for_modal() -> void:
	_epoch += 1
	if is_instance_valid(_renderer):
		_renderer.call("set_rendering", false)
	if not _active_key.is_empty():
		_queue.push_front(_active_key)
		_active_key = ""
	_frames = 0


func _process(_delta: float) -> void:
	if not get_tree().get_nodes_in_group("runtime_box_modal").is_empty():
		if not _active_key.is_empty():
			pause_for_modal()
		return
	if _capturing:
		return
	if _active_key.is_empty():
		_start_next()
		return
	_frames += 1
	if _frames >= 2:
		_capture(_active_key, _epoch)


func _start_next() -> void:
	while not _queue.is_empty():
		var key: String = _queue.pop_front()
		if not _jobs.has(key):
			continue
		var job: Dictionary = _jobs[key]
		var live: Array = []
		for callback: Callable in job.callbacks:
			if callback.is_valid():
				live.append(callback)
		if live.is_empty():
			_jobs.erase(key)
			continue
		job.callbacks = live
		_active_key = key
		_frames = 0
		_renderer.call("configure", job.texture, job.packaging)
		_renderer.call("set_open", false, true)
		(_renderer.get_node("Viewport") as SubViewport).size = RENDER_SIZE
		_renderer.call("set_rendering", true)
		return


func _capture(key: String, epoch: int) -> void:
	_capturing = true
	await RenderingServer.frame_post_draw
	_capturing = false
	if epoch != _epoch or key != _active_key:
		return
	_renderer.call("set_rendering", false)
	var image := (_renderer.get_node("Viewport") as SubViewport).get_texture().get_image()
	var used := Rect2(image.get_used_rect())
	if used.has_area():
		var entry := {
			"texture": ImageTexture.create_from_image(image),
			"full_size": Vector2(image.get_size()),
			"used_rect": used,
		}
		_entries[key] = entry
		_touch(key)
		while _lru.size() > MAX_ENTRIES:
			_entries.erase(_lru.pop_front())
		var callbacks: Array = _jobs[key].callbacks
		for callback: Callable in callbacks:
			if callback.is_valid():
				callback.call_deferred(entry)
	_jobs.erase(key)
	_active_key = ""


func _touch(key: String) -> void:
	_lru.erase(key)
	_lru.append(key)


func debug_snapshot() -> Dictionary:
	return {
		"entries": _entries.size(),
		"queued": _queue.size(),
		"active_key": _active_key,
		"rendering": (_renderer.get_node("Viewport") as SubViewport).render_target_update_mode,
		"limit": MAX_ENTRIES,
		"render_size": RENDER_SIZE,
	}


func _exit_tree() -> void:
	_epoch += 1
	_queue.clear()
	_jobs.clear()
	_entries.clear()
	if is_instance_valid(_renderer):
		_renderer.call("set_rendering", false)
