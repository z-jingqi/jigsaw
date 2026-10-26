class_name LevelCard
extends ActionButton

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")

const BoxCache := preload("res://scripts/ui/box/BoxThumbnailCache.gd")

@onready var title_label: Label = $Title
@onready var thumbnail: TextureRect = $Thumbnail
@onready var completed_modes: Control = $CompletedModes

var level_id := ""
var _view_model: Variant
var _thumbnail_path := ""
var _displayed_thumbnail_path := ""
var _thumbnail_fade: Tween
var _status: Label
var _box_preview: TextureRect
var _box_hidden := false
var _cache_key := ""
var _request_token := 0
var _requested_token := -1
var _locked := false

var _box_full_size := Vector2.ZERO
var _box_used_rect := Rect2()
var _box_source_texture: Texture2D


func _ready() -> void:
	kind = Kind.CARD
	super._ready()
	_status = Label.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_stylebox_override("normal", Clean.panel(Clean.PAPER, 18))
	title_label.hide()
	completed_modes.hide()
	add_child(_status)
	_box_preview = TextureRect.new()
	_box_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_box_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_box_preview.visible = false
	add_child(_box_preview)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	set_process(false)
	resized.connect(_apply_layout)
	get_viewport().size_changed.connect(_apply_layout)
	tree_entered.connect(_request_box)
	_apply_layout()
	if _view_model != null:
		_apply_view_model()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if is_node_ready():
		_apply_view_model()


func _apply_view_model() -> void:
	var next_level_id := str(_read("level_id"))
	var modes: Array = []
	var descriptions: PackedStringArray = []
	for state in _read("modes", []):
		var status := StringName(state.get("status"))
		modes.append({"mode": String(state.get("mode")), "status": String(status)})
		var mode_label := str(state.get("label"))
		var detail := GameStrings.ui_text("completed_mode") % mode_label
		if status != &"completed":
			var status_key := "in_progress" if status == &"in_progress" else "todo"
			detail = "%s: %s" % [mode_label, GameStrings.ui_text(status_key)]
		descriptions.append(detail)
	_locked = bool(_read("locked", false))
	completed_modes.set_modes(_read("modes", []), not _locked)
	var key := (
		JSON
		. stringify(
			[
				_read("theme_id", ""),
				next_level_id,
				_read("thumbnail_path", ""),
				_read("title", ""),
				modes,
				_read("preview_revealed", not _locked),
				_locked,
			]
		)
	)
	if key != _cache_key:
		_request_token += 1
		_requested_token = -1
		_box_preview.texture = null
		_box_source_texture = null
		_box_preview.visible = false
		_box_used_rect = Rect2()
		if level_id != next_level_id:
			_box_hidden = false
	_cache_key = key
	level_id = next_level_id
	title_label.text = str(_read("title"))
	accessibility_name = title_label.text
	accessibility_description = ", ".join(descriptions)
	tooltip_text = ""
	disabled = _locked or _box_source_texture == null
	_status.visible = false
	_set_thumbnail(_read("thumbnail") as Texture2D, str(_read("thumbnail_path", "")))
	_request_box()
	_apply_layout()


func _request_box() -> void:
	if not is_node_ready() or not is_inside_tree() or _cache_key.is_empty():
		return
	if (
		(thumbnail.texture == null and not _thumbnail_path.is_empty())
		or _requested_token == _request_token
	):
		return
	_requested_token = _request_token
	var modes: Array = []
	for state in _read("modes", []):
		modes.append({"mode": String(state.get("mode")), "status": String(state.get("status"))})
	var packaging := {
		"theme_id": str(_read("theme_id", "")),
		"title": title_label.text,
		"modes": modes,
		"preview_revealed": bool(_read("preview_revealed", not _locked)),
		"locked": _locked,
	}
	BoxCache.shared(get_tree()).request(
		_cache_key, thumbnail.texture, packaging, _accept_box.bind(_request_token, _cache_key)
	)


func _accept_box(entry: Dictionary, token: int, key: String) -> void:
	if not is_inside_tree() or token != _request_token or key != _cache_key:
		return
	_box_full_size = entry.full_size
	_box_used_rect = entry.used_rect
	_box_source_texture = entry.texture
	var cropped := AtlasTexture.new()
	cropped.atlas = entry.texture
	cropped.region = _box_used_rect
	_box_preview.texture = cropped
	disabled = _locked
	_apply_layout()


func set_box_transition_hidden(hidden: bool) -> void:
	_box_hidden = hidden
	_apply_layout()


func cancel_thumbnail_request() -> void:
	_request_token += 1
	_requested_token = -1
	_box_hidden = false


func _process(_delta: float) -> void:
	if _thumbnail_path.is_empty():
		set_process(false)
		return
	var status := ResourceLoader.load_threaded_get_status(_thumbnail_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var requested_path := _thumbnail_path
		var loaded := ResourceLoader.load_threaded_get(requested_path) as Texture2D
		if requested_path == _thumbnail_path:
			_thumbnail_path = ""
			set_process(false)
			_show_loaded_thumbnail(loaded, true)
	elif status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
		_thumbnail_path = ""
		set_process(false)
		_request_box()


func _set_thumbnail(texture: Texture2D, path: String) -> void:
	# Retain unchanged resources so progress refreshes cannot evict the image
	# and restart a blank-to-image fade.
	if texture != null and texture == thumbnail.texture:
		return
	if texture == null and not path.is_empty():
		if path == _displayed_thumbnail_path and thumbnail.texture != null:
			return
		if path == _thumbnail_path:
			return
	_cancel_thumbnail_fade()
	_thumbnail_path = ""
	_displayed_thumbnail_path = path
	set_process(false)
	if texture != null:
		_show_loaded_thumbnail(texture, false)
		return
	thumbnail.texture = null
	thumbnail.modulate = Color(1, 1, 1, 0)
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	if ResourceLoader.has_cached(path):
		_show_loaded_thumbnail(load(path) as Texture2D, false)
		return
	_thumbnail_path = path
	var request_error := ResourceLoader.load_threaded_request(path, "Texture2D")
	var status := ResourceLoader.load_threaded_get_status(path)
	if request_error == OK or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		set_process(true)
		return
	_thumbnail_path = ""


func _show_loaded_thumbnail(texture: Texture2D, animate: bool) -> void:
	if texture == null:
		thumbnail.texture = null
		thumbnail.modulate = Color(1, 1, 1, 0)
		_request_box()
		return
	thumbnail.texture = texture
	_request_box()
	if not animate or _reduced_motion:
		thumbnail.modulate = Color.WHITE
		return
	thumbnail.modulate = Color(1, 1, 1, 0)
	_thumbnail_fade = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_thumbnail_fade.tween_property(thumbnail, "modulate:a", 1.0, 0.14)
	_thumbnail_fade.finished.connect(func() -> void: _thumbnail_fade = null)


func _cancel_thumbnail_fade() -> void:
	if _thumbnail_fade != null and _thumbnail_fade.is_valid():
		_thumbnail_fade.kill()
	_thumbnail_fade = null


func _apply_layout() -> void:
	if not is_node_ready() or size.x <= 0.0:
		return
	var inset := maxf(8.0, size.x * 0.035)
	var area := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
	thumbnail.position = area.position
	thumbnail.size = area.size
	_box_preview.position = area.position
	_box_preview.size = area.size
	_box_preview.visible = _box_source_texture != null and not _box_hidden
	thumbnail.visible = _box_source_texture == null and not _box_hidden
	title_label.hide()
	completed_modes.hide()
	_status.hide()
	var material := thumbnail.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("rect_aspect", thumbnail.size.x / thumbnail.size.y)
		material.set_shader_parameter("rect_size", thumbnail.size)
		material.set_shader_parameter("saturation", 0.0)
		material.set_shader_parameter("opacity", 0.12)
	queue_redraw()


func _draw() -> void:
	if not is_node_ready() or not has_focus() or _box_hidden:
		return
	var native := Clean.minimum_touch_size(self).x / 44.0
	var center := Vector2(size.x * 0.5, size.y - 3.0 * native)
	draw_line(
		center - Vector2(12, 0) * native, center + Vector2(12, 0) * native, Clean.INK, native, true
	)


func prototype_box_rect() -> Rect2:
	if not _box_used_rect.has_area():
		return Rect2()
	var area := _box_preview.get_global_rect()
	var scale_factor := minf(
		area.size.x / _box_used_rect.size.x, area.size.y / _box_used_rect.size.y
	)
	var drawn := _box_used_rect.size * scale_factor
	var origin := area.position + (area.size - drawn) * 0.5
	return Rect2(origin - _box_used_rect.position * scale_factor, _box_full_size * scale_factor)


func set_box_preview(texture: Texture2D) -> void:
	if not is_node_ready() or texture == null:
		return
	_accept_box(
		{
			"texture": texture,
			"full_size": texture.get_size(),
			"used_rect": Rect2(texture.get_image().get_used_rect()),
		},
		_request_token,
		_cache_key
	)


func _read(field: String, fallback: Variant = null) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	return _view_model.get(field) if _view_model != null else fallback


func set_reduced_motion(enabled: bool) -> void:
	super.set_reduced_motion(enabled)
	if enabled:
		_cancel_thumbnail_fade()
		if is_instance_valid(thumbnail) and thumbnail.texture != null:
			thumbnail.modulate.a = 1.0


func _exit_tree() -> void:
	cancel_thumbnail_request()
	_cancel_thumbnail_fade()
	super._exit_tree()
