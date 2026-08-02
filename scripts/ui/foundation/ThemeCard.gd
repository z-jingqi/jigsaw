class_name ThemeCard
extends ActionButton

@onready var cover: TextureRect = $Cover
@onready var information: Control = $Information
@onready var title_label: Label = $Information/Content/TitleRow/Title
@onready var current_indicator: Label = $Information/Content/TitleRow/CurrentIndicator
@onready var progress_label: Label = $Information/Content/Progress
@onready var completion_mark: TextureRect = $CompletionMark

var theme_id := ""
var _view_model: Variant
var _cover_material: ShaderMaterial


func _ready() -> void:
	kind = Kind.CARD
	super._ready()
	if cover.material is ShaderMaterial:
		_cover_material = (cover.material as ShaderMaterial).duplicate() as ShaderMaterial
		cover.material = _cover_material
	resized.connect(_apply_visual_layout)
	_apply_visual_layout()
	if _view_model != null:
		_apply_view_model()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if is_node_ready():
		_apply_view_model()


func source_rect() -> Rect2:
	return get_global_rect()


func source_texture() -> Texture2D:
	return cover.texture


func set_information_visible(should_show: bool) -> void:
	information.visible = should_show


func set_pointer_enabled(enabled: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _apply_view_model() -> void:
	theme_id = str(_read("theme_id"))
	title_label.text = str(_read("title"))
	cover.texture = _read("cover_texture") as Texture2D
	current_indicator.visible = bool(_read("is_current", false))
	var completed := int(_read_progress("completed_modes", 0))
	var total := int(_read_progress("total_modes", 0))
	var is_complete := bool(_read_progress("is_complete", false))
	progress_label.text = "%d / %d" % [completed, total]
	completion_mark.visible = is_complete
	tooltip_text = "%s，已完成 %d / %d" % [title_label.text, completed, total]
	accessibility_name = tooltip_text
	_apply_visual_layout()


func _apply_visual_layout() -> void:
	if not is_node_ready():
		return
	if _cover_material != null:
		_cover_material.set_shader_parameter("control_size", size.max(Vector2.ONE))
		_cover_material.set_shader_parameter("corner_radius_px", clampf(size.x * 0.09, 44.0, 58.0))
	var title_size := clampi(roundi(size.x * 0.095), 46, 58)
	var progress_size := clampi(roundi(size.x * 0.078), 38, 48)
	title_label.add_theme_font_size_override(&"font_size", title_size)
	current_indicator.add_theme_font_size_override(&"font_size", 28)
	progress_label.add_theme_font_size_override(&"font_size", progress_size)
	var information_height := clampf(size.y * 0.30, 150.0, 196.0)
	information.offset_top = -information_height
	var mark_side := clampf(minf(size.x, size.y) * 0.30, 52.0, 82.0)
	completion_mark.offset_left = -mark_side - 10.0
	completion_mark.offset_top = -mark_side - 10.0
	completion_mark.offset_right = -10.0
	completion_mark.offset_bottom = -10.0
	pivot_offset = size * 0.5


func _read_progress(field: String, fallback: Variant) -> Variant:
	var value: Variant = _read("progress")
	if value == null:
		return fallback
	if value is Dictionary:
		return value.get(field, fallback)
	var result: Variant = value.get(field)
	return fallback if result == null else result


func _read(field: String, fallback: Variant = null) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	return _view_model.get(field) if _view_model != null else fallback
