class_name AlbumDetailScreen
extends Control
## Pure artwork viewer. Loading follows latest intent, never gates navigation.
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")
const ZoomGesture := preload("res://scripts/screens/album/AlbumZoomGesture.gd")

signal back_requested
signal back_preview_requested
signal browse_requested(direction: int)
signal index_selected(index: int)

var _model: Dictionary = {}
var _reduced_motion := false
var _active := true
var _generation := 0
var _loader: Node
var _gesture: Node
var _textures: Dictionary = {}
var _quality: Dictionary = {}
var _area := Rect2()
var _artworks: Array = []


func _ready() -> void:
	Clean.icon_button($BackButton)
	$BackButton.pressed.connect(back_requested.emit)
	_gesture = ZoomGesture.new()
	_gesture.name = "ZoomGesture"
	add_child(_gesture)
	_gesture.changed.connect(_apply_view)
	_gesture.index_requested.connect(_on_index_requested)
	resized.connect(_layout)


func set_image_loader(loader: Node) -> void:
	if is_instance_valid(_loader):
		_loader.unwatch_owner(self)
	_loader = loader
	if not _model.is_empty():
		_request_images()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_reduced_motion = bool(context.get("reduced_motion", false))
	render(payload.get("view_model", {}))


func render(model: Dictionary, _animate := false) -> void:
	var previous := int(_model.get("index", -1))
	_model = model.duplicate()
	_artworks = model.get("artworks", [])
	var current := int(model.get("index", 0))
	_sync_current_entry(current)
	if previous != current and _gesture.index != current:
		_gesture.reset()
	$BackButton.accessibility_name = str(model.get("close_label", "Close artwork"))
	$Artwork.accessibility_name = str(model.get("title", ""))
	_request_images()
	_layout()


func _request_images() -> void:
	_generation += 1
	if is_instance_valid(_loader):
		_loader.unwatch_owner(self)
	var previous := _textures.duplicate()
	var previous_quality := _quality.duplicate()
	_textures.clear()
	_quality.clear()
	for offset in [-1, 0, 1]:
		var entry := _entry(int(_model.get("index", 0)) + offset)
		var path := str(entry.get("image_path", entry.get("path", "")))
		if path.is_empty():
			continue
		if previous.has(path):
			_textures[path] = previous[path]
			_quality[path] = previous_quality.get(path, "thumbnail")
		if is_instance_valid(_loader):
			_request_slot(str(offset), entry, _generation)
		elif offset == 0 and _model.get("texture") is Texture2D:
			_textures[path] = _model.texture
	_apply_view()


func _entry(at: int) -> Dictionary:
	if at >= 0 and at < _artworks.size():
		return _artworks[at]
	if _artworks.is_empty() and at == int(_model.get("index", 0)):
		var entry := _model.duplicate()
		if str(entry.get("image_path", "")).is_empty() and entry.get("texture") is Texture2D:
			entry.image_path = "legacy_texture"
		return entry
	return {}


func _request_slot(slot: String, entry: Dictionary, generation: int) -> void:
	var path := str(entry.get("image_path", entry.get("path", "")))
	var thumb := str(entry.get("thumbnail_path", ""))
	var full: Texture2D = _loader.get_cached(path)
	if full != null:
		_apply_loaded(path, full, generation, true)
	var callback := func(loaded_path: String, texture: Texture2D) -> void:
		_apply_loaded(loaded_path, texture, generation, true)
	var priority := 100 if slot == "0" else 0
	if full != null or thumb.is_empty() or thumb == path:
		_loader.watch(self, slot, path, callback, "full", priority)
		return
	var cached_thumb: Texture2D = _loader.get_cached(thumb)
	if cached_thumb != null:
		_apply_loaded(path, cached_thumb, generation, false)
		_loader.watch(self, slot, path, callback, "full", priority)
	else:
		_loader.watch(
			self,
			slot,
			thumb,
			func(_path: String, texture: Texture2D) -> void:
				if generation != _generation or not _active:
					return
				_apply_loaded(path, texture, generation, false)
				_loader.watch(self, slot, path, callback, "full", priority),
			"thumb",
			priority
		)


func _apply_loaded(path: String, texture: Texture2D, generation: int, full: bool) -> void:
	if generation != _generation or not _active:
		return
	# A cached/late thumbnail must never replace a full image still held by this view.
	if not full and _quality.get(path, "") == "full" and _textures.has(path):
		return
	if texture != null:
		_textures[path] = texture
		_quality[path] = "full" if full else "thumbnail"
	_apply_view()


func _on_index_requested(at: int) -> void:
	var previous := int(_model.get("index", 0))
	_model["index"] = at
	_sync_current_entry(at)
	_request_images()
	_layout()
	if not index_selected.get_connections().is_empty():
		index_selected.emit(at)
	else:
		browse_requested.emit(at - previous)


func _sync_current_entry(at: int) -> void:
	var entry := _entry(at)
	_model["current"] = entry
	_model["level_id"] = entry.get("level_id", entry.get("artwork_id", ""))
	_model["title"] = entry.get("title", "")
	_model["theme_id"] = entry.get("theme_id", _model.get("theme_id", ""))
	$Artwork.accessibility_name = str(_model.title)


func navigation_set_active(enabled: bool) -> void:
	_active = enabled
	visible = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_gesture.enabled = enabled
	if not enabled:
		_gesture.cancel()
		_release_requests()
	elif not _model.is_empty():
		_request_images()


func gesture_pause_motion() -> void:
	back_preview_requested.emit()
	# Edge-back owns the pointer; freeze the current page pose underneath it.
	_gesture.cancel()


func gesture_resume_motion() -> void:
	if _active and _gesture.enabled:
		_gesture.settle()


func navigation_prepare_transition() -> void:
	back_preview_requested.emit()
	_gesture.enabled = false
	_gesture.cancel()


func navigation_exit(_context: Dictionary) -> void:
	_active = false
	_gesture.enabled = false
	_gesture.cancel()
	_release_requests()
	$ImageMotion.finish()


func _release_requests() -> void:
	_generation += 1
	if is_instance_valid(_loader):
		_loader.unwatch_owner(self)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	_gesture.set_reduced_motion(enabled)
	if enabled:
		$ImageMotion.finish()


func active_motion_count() -> int:
	return _gesture.active_motion_count() + $ImageMotion.active_motion_count()


func debug_state_snapshot() -> Dictionary:
	return {
		"theme_id": _model.get("theme_id", ""),
		"level_id": _model.get("level_id", ""),
		"index": _model.get("index", 0),
		"total": _model.get("total", _artworks.size()),
		"image_ready": $Artwork.texture != null,
		"zoom": _gesture.zoom,
		"pan": _gesture.pan,
		"page_offset": _gesture.page_offset,
		"quality": _quality.duplicate(),
		"active_motion_count": active_motion_count(),
	}


func _layout() -> void:
	if not is_node_ready():
		return
	var u := Metrics.unit(get_viewport_rect().size)
	var safe := Clean.safe_insets(size)
	Buttons.place_navigation($BackButton, self)
	_area = Rect2(
		Vector2(
			safe.x + Metrics.EDGE * u, safe.y + (Metrics.TOP + Metrics.TOUCH + Metrics.GAP) * u
		),
		(
			size
			- Vector2(
				safe.x + safe.z + Metrics.EDGE * 2 * u,
				safe.y + safe.w + (Metrics.TOP + Metrics.TOUCH + Metrics.GAP + Metrics.EDGE) * u
			)
		)
	)
	_gesture.excluded = $BackButton.get_global_rect()
	_gesture.image_center = global_position + _area.get_center()
	_gesture.reduced_motion = _reduced_motion
	_apply_view()


func _apply_view() -> void:
	if not is_node_ready() or _gesture == null:
		return
	var current := int(_model.get("index", 0))
	var nodes := [$PreviousArtwork, $Artwork, $NextArtwork]
	var fitted := _area.size
	for offset in [-1, 0, 1]:
		var entry := _entry(current + offset)
		var path := str(entry.get("image_path", entry.get("path", "")))
		var image: TextureRect = nodes[offset + 1]
		image.texture = _textures.get(path)
		image.visible = image.texture != null
		if image.texture == null:
			continue
		var dimensions := image.texture.get_size()
		var fit := minf(_area.size.x / dimensions.x, _area.size.y / dimensions.y)
		var base := dimensions * fit
		var scale: float = _gesture.zoom if offset == 0 else 1.0
		image.size = base * scale
		image.position = _area.get_center() - image.size * 0.5
		image.position.x += offset * size.x + _gesture.page_offset
		if offset == 0:
			image.position += _gesture.pan
			fitted = base
		else:
			image.visible = image.visible and _gesture.zoom <= 1.001
	_gesture.configure(
		Rect2(global_position, size),
		fitted,
		current,
		int(_model.get("total", _artworks.size())),
		Clean.canvas_scale(get_viewport_rect().size, get_window())
	)


func _exit_tree() -> void:
	_release_requests()
