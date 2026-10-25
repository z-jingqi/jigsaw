class_name CleanTheme
extends RefCounted
## Shared, quiet paper palette for every player-facing surface.

const PAPER := Color("FAF7EF")
const INK := Color("272925")
const MUTED := Color("62665D")
const SAGE := Color("E5E9D8")
const APRICOT := Color("F8E3D1")
const LAVENDER := Color("ECE7F1")
const DISABLED := Color("E9E6DE")
const OUTLINE := Color("C7CCBD")
const FONT := preload("res://themes/clean_body_font.tres")
const HEADING := preload("res://themes/clean_heading_font.tres")


static func panel(fill: Color, radius: float = 24.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(roundi(radius))
	style.corner_detail = 16
	style.anti_aliasing = true
	return style


static func button(control: Button, primary: bool = false) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.flat = false
	var fill := INK if primary else SAGE
	var ink := PAPER if primary else INK
	control.add_theme_font_override("font", FONT)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := fill
		if state == "hover":
			color = fill.lightened(0.07) if primary else fill.darkened(0.04)
		elif state == "pressed":
			color = fill.lightened(0.14) if primary else fill.darkened(0.08)
		elif state == "disabled":
			color = DISABLED
		var style := panel(color, 28.0)
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		control.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, ink)
	control.add_theme_color_override("font_disabled_color", MUTED)
	var focus := panel(Color.TRANSPARENT, 28.0)
	focus.set_border_width_all(3)
	focus.border_color = MUTED
	focus.expand_margin_left = 4.0
	focus.expand_margin_right = 4.0
	focus.expand_margin_top = 4.0
	focus.expand_margin_bottom = 4.0
	control.add_theme_stylebox_override("focus", focus)
	control.custom_minimum_size = control.custom_minimum_size.max(Vector2(44.0, 44.0))


static func label(control: Label, font_size: int, muted: bool = false) -> void:
	control.add_theme_font_override("font", HEADING if not muted else FONT)
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", MUTED if muted else INK)
	control.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)


static func safe_insets(viewport_size: Vector2) -> Vector4:
	# Desktop safe-area APIs report screen coordinates, not the app's window.
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var screen := Vector2(DisplayServer.screen_get_size())
	if screen.x <= 0.0 or screen.y <= 0.0:
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var scale := viewport_size / screen
	return Vector4(
		maxf(0.0, safe.position.x * scale.x),
		maxf(0.0, safe.position.y * scale.y),
		maxf(0.0, (screen.x - safe.end.x) * scale.x),
		maxf(0.0, (screen.y - safe.end.y) * scale.y)
	)
