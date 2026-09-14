class_name LevelCard
extends ActionButton

const TITLE_MAX_FONT_SIZE := 40
const TITLE_MIN_SINGLE_LINE_FONT_SIZE := 28
const TITLE_WRAP_MIN_FONT_SIZE := 18

@onready var title_label: Label = $Title
@onready var thumbnail: TextureRect = $Thumbnail
@onready var completed_modes: CompletedModeStickers = $CompletedModes

var level_id := ""
var _view_model: Variant
var _thumbnail_path := ""
var _thumbnail_fade: Tween


func _ready() -> void:
	kind = Kind.CARD
	super._ready()
	set_process(false)
	resized.connect(_apply_layout)
	_apply_layout()
	if _view_model != null:
		_apply_view_model()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if is_node_ready():
		_apply_view_model()


func _apply_view_model() -> void:
	level_id = str(_read("level_id"))
	title_label.text = str(_read("title"))
	var is_locked := bool(_read("locked"))
	disabled = is_locked
	_set_thumbnail(_read("thumbnail") as Texture2D, str(_read("thumbnail_path", "")))
	var mode_states: Array = _read("modes", [])
	completed_modes.set_modes(mode_states, not is_locked)
	tooltip_text = title_label.text
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
	_apply_layout()


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
	_cancel_thumbnail_fade()
	_thumbnail_path = ""
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
	var inset := maxf(4.0, size.x * 0.012)
	var image_height := minf(size.y - 64.0, (size.x - inset * 2.0) * 4.0 / 3.0)
	thumbnail.position = Vector2(inset, inset)
	thumbnail.size = Vector2(size.x - inset * 2.0, image_height)
	var remaining := maxf(0.0, size.y - image_height)
	var title_height := minf(72.0, maxf(54.0, remaining - inset))
	title_label.position = Vector2(20.0, image_height + inset + 2.0)
	title_label.size = Vector2(maxf(0.0, size.x - 40.0), title_height)
	_fit_title_font(title_label.size.x, title_label.size.y)
	var icon_size := clampf(size.x * 0.108, 40.0, 58.0)
	completed_modes.configure(icon_size, maxf(5.0, icon_size * 0.13))
	completed_modes.position = Vector2(inset + 10.0, inset + image_height - icon_size - 10.0)
	completed_modes.size = Vector2(maxf(0.0, size.x - inset * 2.0 - 20.0), icon_size)
	var shader_material := thumbnail.material as ShaderMaterial
	if shader_material != null and image_height > 0.0:
		shader_material.set_shader_parameter("rect_aspect", thumbnail.size.x / thumbnail.size.y)
		shader_material.set_shader_parameter("rect_size", thumbnail.size)
		shader_material.set_shader_parameter("saturation", 0.16 if disabled else 1.0)
		shader_material.set_shader_parameter("opacity", 0.56 if disabled else 1.0)


func _fit_title_font(max_width: float, max_height: float) -> void:
	var font := title_label.get_theme_font("font")
	var single_line_size := TITLE_MAX_FONT_SIZE
	while single_line_size >= TITLE_MIN_SINGLE_LINE_FONT_SIZE:
		var text_width := (
			font
			. get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, single_line_size)
			. x
		)
		if text_width <= max_width:
			title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			title_label.max_lines_visible = 1
			title_label.add_theme_font_size_override("font_size", single_line_size)
			return
		single_line_size -= 2

	var wrapped_size := TITLE_MAX_FONT_SIZE
	while wrapped_size > TITLE_WRAP_MIN_FONT_SIZE:
		var text_block := font.get_multiline_string_size(
			title_label.text, HORIZONTAL_ALIGNMENT_CENTER, max_width, wrapped_size
		)
		if text_block.x <= max_width and text_block.y <= max_height:
			break
		wrapped_size -= 2
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.add_theme_font_size_override("font_size", wrapped_size)


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
