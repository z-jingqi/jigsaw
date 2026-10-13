extends RefCounted
## Shared gameplay surfaces follow the approved home page for every theme.

const Background := preload("res://assets/ui/home/library/page.webp")
const INK := Color("194F47")
const BUTTON := Color("DDE3CF")
const BUTTON_PRESSED := Color("BCCDAF")
const BUTTON_DISABLED := Color("E7E8DD")
const BOARD_SURFACE := Color("DDE5D5")
const BOARD_RIM := Color("FAF8EF")
const TRAY_SURFACE := Color("E7EBDD")
const SCROLL_TRACK := Color("D3DBC9")
const SCROLL_THUMB := Color("A9B79E")


static func apply_button(button: Button, secondary := false) -> void:
	button.flat = false
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = BUTTON
		if state == &"pressed":
			style.bg_color = BUTTON_PRESSED
		elif state == &"disabled":
			style.bg_color = BUTTON_DISABLED
		elif state == &"focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = INK
		if secondary and state in [&"normal", &"hover"]:
			style.bg_color = Color(0.98, 0.98, 0.94, 0.3)
			style.set_border_width_all(2)
			style.border_color = Color("BECBB6")
		style.set_corner_radius_all(200)
		style.shadow_size = 0
		button.add_theme_stylebox_override(state, style)
	for state in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(state, INK)
