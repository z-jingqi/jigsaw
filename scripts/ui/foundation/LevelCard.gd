class_name LevelCard
extends ActionButton

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")

const TITLE_MAX_FONT_SIZE := 48
const PROTOTYPE_LEVEL := "shanhai_v2_01"
const BOX_CACHE_PATH := "res://assets/ui/box/prototype-closed.png"

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
var _box_depth := Vector2.ZERO

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
	Clean.label(title_label, TITLE_MAX_FONT_SIZE)
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
	_apply_layout()
	if _view_model != null:
		_apply_view_model()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if is_node_ready():
		_apply_view_model()


func _apply_view_model() -> void:
	var next_level_id := str(_read("level_id"))
	if level_id != next_level_id and _box_preview != null:
		_box_preview.texture = null
		_box_source_texture = null
		_box_preview.visible = false
	level_id = next_level_id
	if level_id == PROTOTYPE_LEVEL and ResourceLoader.exists(BOX_CACHE_PATH):
		set_box_preview(load(BOX_CACHE_PATH) as Texture2D)
	var next_title := str(_read("title"))
	var title_changed := title_label.text != next_title
	if title_changed:
		title_label.text = next_title
	var is_locked := bool(_read("locked"))
	disabled = is_locked
	_status.text = GameStrings.ui_text("locked") if is_locked else ""
	_status.visible = is_locked
	_set_thumbnail(_read("thumbnail") as Texture2D, str(_read("thumbnail_path", "")))
	var mode_states: Array = _read("modes", [])
	completed_modes.set_modes(mode_states, not is_locked)
	var descriptions: PackedStringArray = []
	for state in mode_states:
		var mode_label := str(state.get("label"))
		var status := StringName(state.get("status"))
		if status == &"completed":
			descriptions.append(GameStrings.ui_text("completed_mode") % mode_label)
		else:
			var status_key := "in_progress" if status == &"in_progress" else "todo"
			descriptions.append("%s: %s" % [mode_label, GameStrings.ui_text(status_key)])
	accessibility_description = ", ".join(descriptions)
	queue_redraw()
	tooltip_text = ""
	accessibility_name = (
		"%s, %s"
		% [
			title_label.text,
			(
				"Locked"
				if is_locked
				else (
					"%d modes completed" % completed_modes.completed_count()
					if completed_modes.completed_count() > 0
					else "Available"
				)
			)
		]
	)
	# Progress refreshes keep the same geometry and typography. Reapplying the
	# font overrides to every retained card stalls the first return frame.
	if title_changed:
		_apply_layout()
	else:
		_apply_preview_style()


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
		return
	thumbnail.texture = texture
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
	var native := Clean.minimum_touch_size(self).x / 44.0
	var inset := maxf(8.0, size.x * 0.035)
	_box_depth = (
		Vector2(4, 5) * native
		if level_id == PROTOTYPE_LEVEL and not _box_preview.visible
		else Vector2.ZERO
	)
	var image_width := size.x - inset * 2.0 - _box_depth.x
	var image_height := minf(size.y - size.x * 0.24, image_width * 4.0 / 3.0)
	thumbnail.position = Vector2(inset, inset)
	thumbnail.size = Vector2(image_width, image_height)
	var title_top := image_height + inset + _box_depth.y + 5.0 * native
	var title_height := maxf(18.0 * native, size.y - title_top)
	var icon_side := 14.0 * native
	var icon_gap := 3.0 * native
	completed_modes.configure(icon_side, icon_gap)
	completed_modes.position = Vector2(
		size.x - inset - completed_modes.size.x, title_top + (title_height - icon_side) * 0.5
	)
	title_label.position = Vector2(inset, title_top)
	title_label.size = Vector2(
		maxf(0.0, completed_modes.position.x - inset - 5.0 * native), title_height
	)
	_fit_title_font(title_label.size.x, title_label.size.y)
	_box_preview.position = thumbnail.position
	_box_preview.size = thumbnail.size + _box_depth
	thumbnail.visible = not _box_preview.visible
	var shader_material := thumbnail.material as ShaderMaterial
	if shader_material != null and image_height > 0.0:
		shader_material.set_shader_parameter("rect_aspect", thumbnail.size.x / thumbnail.size.y)
		shader_material.set_shader_parameter("rect_size", thumbnail.size)
	_status.position = thumbnail.position + Vector2(12, 12)
	_status.size = Vector2(size.x * 0.30, maxf(32, size.x * 0.1))
	Clean.label(_status, maxi(18, roundi(size.x * 0.06)), true)
	queue_redraw()
	_apply_preview_style()


func _draw() -> void:
	if not is_node_ready():
		return
	var unit := size.x / 150.0
	if level_id == PROTOTYPE_LEVEL and not _box_preview.visible:
		var rect := thumbnail.get_rect()
		var depth := _box_depth
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(rect.end.x, rect.position.y),
					rect.end,
					rect.end + depth,
					Vector2(rect.end.x + depth.x, rect.position.y + depth.y),
				]
			),
			Color("D9C9AC")
		)
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(rect.position.x, rect.end.y),
					rect.end,
					rect.end + depth,
					Vector2(rect.position.x + depth.x, rect.end.y + depth.y),
				]
			),
			Color("E8DCC7")
		)
	if has_focus():
		var center := title_label.position + title_label.size * 0.5
		draw_line(
			center + Vector2(-12, 8) * unit,
			center + Vector2(12, 8) * unit,
			Clean.INK,
			maxf(1.5, unit),
			true
		)


func _apply_preview_style() -> void:
	var shader_material := thumbnail.material as ShaderMaterial
	if shader_material != null:
		var revealed := bool(_read("preview_revealed", not disabled))
		shader_material.set_shader_parameter("saturation", 1.0 if revealed else 0.16)
		shader_material.set_shader_parameter("opacity", 1.0 if revealed else 0.56)


func _fit_title_font(max_width: float, _max_height: float) -> void:
	var native := Clean.minimum_touch_size(self).x / 44.0
	var font := title_label.get_theme_font("font")
	var font_size := roundi(14.0 * native)
	var minimum := ceili(12.0 * native)
	while font_size > minimum:
		if (
			font.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			<= max_width
		):
			break
		font_size -= 1
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.max_lines_visible = 1
	title_label.add_theme_font_size_override("font_size", font_size)


func prototype_box_rect() -> Rect2:
	if not _box_preview.visible or not _box_used_rect.has_area():
		return thumbnail.get_global_rect()
	var area := _box_preview.get_global_rect()
	var scale_factor := minf(
		area.size.x / _box_used_rect.size.x, area.size.y / _box_used_rect.size.y
	)
	var drawn := _box_used_rect.size * scale_factor
	var origin := area.position + (area.size - drawn) * 0.5
	return Rect2(origin - _box_used_rect.position * scale_factor, _box_full_size * scale_factor)


func set_box_preview(texture: Texture2D) -> void:
	if not is_node_ready() or level_id != PROTOTYPE_LEVEL or texture == _box_source_texture:
		return
	_box_source_texture = texture
	if texture != null:
		_box_full_size = texture.get_size()
		_box_used_rect = Rect2(texture.get_image().get_used_rect())
		var cropped := AtlasTexture.new()
		cropped.atlas = texture
		cropped.region = _box_used_rect
		_box_preview.texture = cropped
	else:
		_box_preview.texture = null
	_box_preview.visible = texture != null
	thumbnail.visible = texture == null
	_apply_layout()
	queue_redraw()


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
	_cancel_thumbnail_fade()
	super._exit_tree()
