class_name SettingsGlyph
extends Control

const SURFACE := Color("D35929")
const DEEP := Color(0.482, 0.141, 0.047, 0.30)
const HIGHLIGHT := Color(0.94, 0.48, 0.28, 0.72)

var _kind := &"music"


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_kind(value: StringName) -> void:
	_kind = value
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor := minf(size.x, size.y) / 96.0
	var origin := (size - Vector2(96.0, 96.0) * scale_factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
	_draw_glyph(Vector2(3.0, 4.0), DEEP)
	_draw_glyph(Vector2.ZERO, SURFACE)
	_draw_highlight()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glyph(offset: Vector2, color: Color) -> void:
	match _kind:
		&"sound":
			_draw_sound(offset, color)
		&"haptics":
			_draw_haptics(offset, color)
		&"reduced_motion":
			_draw_reduced_motion(offset, color)
		_:
			_draw_music(offset, color)


func _draw_music(offset: Vector2, color: Color) -> void:
	draw_circle(Vector2(28, 68) + offset, 12.0, color, true, -1.0, true)
	draw_circle(Vector2(64, 60) + offset, 11.0, color, true, -1.0, true)
	draw_line(Vector2(38, 67) + offset, Vector2(38, 27) + offset, color, 12.0, true)
	draw_line(Vector2(74, 59) + offset, Vector2(74, 19) + offset, color, 12.0, true)
	draw_line(Vector2(38, 28) + offset, Vector2(74, 20) + offset, color, 12.0, true)


func _draw_sound(offset: Vector2, color: Color) -> void:
	var speaker := PackedVector2Array(
		[
			Vector2(17, 41) + offset,
			Vector2(34, 41) + offset,
			Vector2(54, 25) + offset,
			Vector2(54, 71) + offset,
			Vector2(34, 55) + offset,
			Vector2(17, 55) + offset,
		]
	)
	draw_colored_polygon(speaker, color)
	draw_arc(Vector2(55, 48) + offset, 16.0, -0.78, 0.78, 18, color, 7.0, true)
	draw_arc(Vector2(55, 48) + offset, 28.0, -0.72, 0.72, 22, color, 6.0, true)


func _draw_haptics(offset: Vector2, color: Color) -> void:
	var phone_style := StyleBoxFlat.new()
	phone_style.bg_color = Color.TRANSPARENT
	phone_style.border_color = color
	phone_style.border_width_left = 7
	phone_style.border_width_top = 7
	phone_style.border_width_right = 7
	phone_style.border_width_bottom = 7
	phone_style.corner_radius_top_left = 8
	phone_style.corner_radius_top_right = 8
	phone_style.corner_radius_bottom_left = 8
	phone_style.corner_radius_bottom_right = 8
	phone_style.corner_detail = 12
	phone_style.anti_aliasing = true
	draw_style_box(phone_style, Rect2(Vector2(34, 20) + offset, Vector2(28, 56)))
	draw_arc(Vector2(35, 48) + offset, 12.0, PI * 0.64, PI * 1.36, 16, color, 6.0, true)
	draw_arc(Vector2(35, 48) + offset, 23.0, PI * 0.68, PI * 1.32, 18, color, 6.0, true)
	draw_arc(Vector2(61, 48) + offset, 12.0, -PI * 0.36, PI * 0.36, 16, color, 6.0, true)
	draw_arc(Vector2(61, 48) + offset, 23.0, -PI * 0.32, PI * 0.32, 18, color, 6.0, true)


func _draw_reduced_motion(offset: Vector2, color: Color) -> void:
	var center := Vector2(48, 48) + offset
	draw_arc(center, 31.0, -2.72, -0.42, 24, color, 7.0, true)
	draw_arc(center, 31.0, 0.42, 2.72, 24, color, 7.0, true)
	var pause_style := StyleBoxFlat.new()
	pause_style.bg_color = color
	pause_style.corner_radius_top_left = 4
	pause_style.corner_radius_top_right = 4
	pause_style.corner_radius_bottom_left = 4
	pause_style.corner_radius_bottom_right = 4
	pause_style.corner_detail = 10
	pause_style.anti_aliasing = true
	draw_style_box(pause_style, Rect2(Vector2(35, 31) + offset, Vector2(9, 34)))
	draw_style_box(pause_style, Rect2(Vector2(52, 31) + offset, Vector2(9, 34)))


func _draw_highlight() -> void:
	match _kind:
		&"music":
			draw_line(Vector2(36, 25), Vector2(70, 18), HIGHLIGHT, 3.0, true)
		&"sound":
			draw_line(Vector2(21, 42), Vector2(34, 42), HIGHLIGHT, 3.0, true)
		&"haptics":
			draw_line(Vector2(40, 23), Vector2(55, 23), HIGHLIGHT, 2.5, true)
		&"reduced_motion":
			draw_line(Vector2(37, 33), Vector2(42, 33), HIGHLIGHT, 2.0, true)
