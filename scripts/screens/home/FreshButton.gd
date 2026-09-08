extends Button
## Shared flat controls; vector strokes stay sharp at every display scale.
@export_enum("none", "grid", "settings", "undo", "close") var symbol := "none"
const GearIcon := preload("res://assets/ui/icons/settings.svg")
const INK := Color("194F47")


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("DDE3CF")
		if state == "pressed":
			style.bg_color = Color("BCCDAF")
		if state == "disabled":
			style.bg_color = Color("E7E8DD")
		style.set_corner_radius_all(200)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(3)
			style.border_color = INK
		add_theme_stylebox_override(state, style)
	add_theme_color_override("font_color", INK)
	add_theme_color_override("font_hover_color", INK)
	add_theme_color_override("font_pressed_color", INK)
	add_theme_color_override("font_disabled_color", Color("8C9B8A"))
	resized.connect(queue_redraw)


func _draw() -> void:
	if symbol.is_empty():
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.21
	var w := maxf(1.5, r * 0.13)
	var ink := Color("94A28F") if disabled else INK
	match symbol:
		"close":
			draw_line(c - Vector2.ONE * r, c + Vector2.ONE * r, ink, w, true)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), ink, w, true)
		"grid":
			for x in [-1, 1]:
				for y in [-1, 1]:
					draw_rect(
						Rect2(
							c + Vector2(x, y) * r * 0.62 - Vector2.ONE * r * 0.43,
							Vector2.ONE * r * 0.86
						),
						ink,
						false,
						w
					)
		"undo":
			draw_arc(c, r, -PI * 0.85, PI * 0.75, 32, ink, w, true)
			var tip := c + Vector2.from_angle(-PI * 0.85) * r
			draw_polyline(
				PackedVector2Array([tip + Vector2(0, -r * 0.65), tip, tip + Vector2(r * 0.65, 0)]),
				ink,
				w,
				true
			)
		"settings":
			var icon_size := Vector2.ONE * r * 2.5
			draw_texture_rect(GearIcon, Rect2(c - icon_size * 0.5, icon_size), false)
