class_name AlbumCard
extends Button
## A recycled card releases its image before being bound to a different artwork.

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const RoundedShader := preload("res://shaders/ui/rounded_texture.gdshader")
const AlbumIcon := preload("res://assets/ui/icons/album.svg")
const UiFont := preload("res://themes/douyin_ui_font.tres")

var model: Dictionary = {}
var level_id := ""
var loaded_path := ""
var _art: TextureRect
var _title: Label
var _subtitle: Label
var _material: ShaderMaterial


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Clean.button(self)
	add_theme_stylebox_override("normal", Clean.panel(Clean.SAGE, 24))
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_material = ShaderMaterial.new()
	_material.shader = RoundedShader
	_material.set_shader_parameter("corner_radius", 0.03)
	_art.material = _material
	add_child(_art)
	_title = _label()
	_subtitle = _label()
	_subtitle.add_theme_color_override("font_color", Clean.MUTED)
	resized.connect(_layout)
	_sync_model()


func set_view_model(data: Dictionary) -> void:
	release_thumbnail()
	model = data
	level_id = str(data.level_id)
	if is_node_ready():
		_sync_model()


func apply_thumbnail(path: String, texture: Texture2D) -> void:
	if path != str(model.get("thumbnail_path", "")) or _art == null:
		return
	_art.texture = texture
	loaded_path = path
	queue_redraw()


func release_thumbnail() -> void:
	loaded_path = ""
	if _art != null:
		_art.texture = null
		queue_redraw()


func image_ready() -> bool:
	return _art != null and _art.texture != null


func _sync_model() -> void:
	_title.text = str(model.get("title", ""))
	_subtitle.text = str(model.get("subtitle", ""))
	_subtitle.visible = not _subtitle.text.is_empty()
	accessibility_name = _title.text + " " + _subtitle.text
	tooltip_text = ""
	_layout()


func _draw() -> void:
	if model.is_empty() or _art == null or _art.texture != null:
		return
	var frame := StyleBoxFlat.new()
	frame.bg_color = Clean.LAVENDER
	frame.set_corner_radius_all(maxi(4, roundi(size.x * 0.035)))
	draw_style_box(frame, Rect2(_art.position, _art.size))
	var icon_size := Vector2.ONE * size.x * 0.23
	var center := _art.position + _art.size * 0.5
	draw_texture_rect(
		AlbumIcon, Rect2(center - icon_size * 0.5, icon_size), false, Color(1, 1, 1, 0.3)
	)


func _label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_override("font", UiFont)
	label.add_theme_color_override("font_color", Clean.INK)
	add_child(label)
	return label


func _layout() -> void:
	if _art == null:
		return
	var inset := size.x * 0.04
	_art.position = Vector2.ONE * inset
	_art.size = Vector2(size.x - inset * 2, (size.x - inset * 2) / 0.75)
	_material.set_shader_parameter("rect_size", _art.size)
	_material.set_shader_parameter("rect_aspect", 0.75)
	_title.position = Vector2(0, _art.size.y + inset * 2)
	_title.size = Vector2(size.x, size.x * 0.20)
	_title.add_theme_font_size_override("font_size", maxi(12, roundi(size.x * 0.10)))
	_subtitle.position = _title.position + Vector2(0, size.x * 0.20)
	_subtitle.size = Vector2(size.x, size.x * 0.13)
	_subtitle.add_theme_font_size_override("font_size", maxi(10, roundi(size.x * 0.075)))
	queue_redraw()
