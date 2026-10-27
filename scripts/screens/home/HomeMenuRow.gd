extends Button
## Local menu-row styling: no global button theme and no stacked focus frames.
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
var _action: StringName = &"themes"
var _unit := 1.0
var _keyboard_focus_visible := false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clip_text = true
	tooltip_text = ""
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	configure(_action, _unit)


func configure(action: StringName, unit: float) -> void:
	_action = action
	_unit = maxf(0.01, unit)
	custom_minimum_size = Vector2(0, Metrics.TOUCH * _unit)
	add_theme_font_override("font", Clean.FONT)
	add_theme_font_size_override("font_size", roundi(Metrics.BODY * _unit))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, Clean.INK)
	add_theme_color_override("font_disabled_color", Clean.MUTED)
	add_theme_stylebox_override("normal", _background(Color.TRANSPARENT))
	add_theme_stylebox_override("disabled", _background(Color.TRANSPARENT))
	add_theme_stylebox_override("hover", _background(Color("F2F1EC")))
	add_theme_stylebox_override("pressed", _background(Color("E9E7DF")))
	add_theme_stylebox_override("hover_pressed", _background(Color("E9E7DF")))
	_update_focus_style()
	queue_redraw()


func set_keyboard_focus_visible(enabled: bool) -> void:
	_keyboard_focus_visible = enabled
	_update_focus_style()
	queue_redraw()


func _background(fill: Color) -> StyleBoxFlat:
	var style := Clean.panel(fill, 8.0 * _unit)
	style.content_margin_left = 48.0 * _unit
	style.content_margin_right = 12.0 * _unit
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.expand_margin_left = -4.0 * _unit
	style.expand_margin_right = -4.0 * _unit
	style.expand_margin_top = -3.0 * _unit
	style.expand_margin_bottom = -3.0 * _unit
	return style


func _update_focus_style() -> void:
	if not _keyboard_focus_visible:
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		return
	var outline := _background(Color.TRANSPARENT)
	outline.border_color = Color("99998F")
	outline.set_border_width_all(maxi(1, roundi(_unit)))
	add_theme_stylebox_override("focus", outline)


func _draw() -> void:
	var center := Vector2(24.0 * _unit, size.y * 0.5)
	var ink := Clean.MUTED if disabled else Clean.INK
	var stroke := 1.5 * _unit
	match _action:
		&"themes":
			var square := Clean.panel(Color.TRANSPARENT, 1.2 * _unit)
			square.border_color = ink
			square.set_border_width_all(maxi(1, roundi(stroke)))
			for x in [-1, 1]:
				for y in [-1, 1]:
					var origin := center + Vector2(x, y) * 5.0 * _unit - Vector2.ONE * 3.5 * _unit
					draw_style_box(square, Rect2(origin, Vector2.ONE * 7.0 * _unit))
		&"album":
			var frame := Clean.panel(Color.TRANSPARENT, 1.5 * _unit)
			frame.border_color = ink
			frame.set_border_width_all(maxi(1, roundi(stroke)))
			draw_style_box(
				frame, Rect2(center - Vector2.ONE * 9.0 * _unit, Vector2.ONE * 18.0 * _unit)
			)
			draw_circle(center + Vector2(-4, -4) * _unit, 1.3 * _unit, ink, true, -1, true)
			var mountain := PackedVector2Array()
			for point in [
				Vector2(-6, 5), Vector2(-1, 0), Vector2(2, 3), Vector2(5, -1), Vector2(7, 2)
			]:
				mountain.append(center + point * _unit)
			draw_polyline(mountain, ink, stroke, true)
		&"settings":
			var gear := PackedVector2Array()
			for tooth in 8:
				for segment in 4:
					var angle := (float(tooth) + float(segment) * 0.25) * TAU / 8.0
					var radius := 9.0 if segment in [1, 2] else 7.0
					gear.append(center + Vector2.from_angle(angle) * radius * _unit)
			gear.append(gear[0])
			draw_polyline(gear, ink, stroke, true)
			draw_arc(center, 3.0 * _unit, 0, TAU, 32, ink, stroke, true)
