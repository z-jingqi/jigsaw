extends RefCounted
## Quiet, shared gameplay chrome; puzzle artwork remains the primary visual.

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const INK := Clean.INK
const BUTTON := Clean.SAGE
const BUTTON_PRESSED := Color("D4DAC6")
const BUTTON_DISABLED := Color("EFEEE7")
const BOARD_SURFACE := Clean.SAGE
const BOARD_RIM := Clean.PAPER
const TRAY_SURFACE := Clean.SAGE
const SCROLL_TRACK := Color("D5D9CA")
const SCROLL_THUMB := Color("858C78")


static func apply_button(button: Button, secondary := false) -> void:
	Clean.button(button, false)
	button.focus_mode = Control.FOCUS_ALL
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		var fill := Clean.PAPER if secondary else BUTTON
		if state == &"hover":
			fill = fill.darkened(0.025)
		elif state == &"pressed":
			fill = BUTTON_PRESSED
		elif state == &"disabled":
			fill = BUTTON_DISABLED
		button.add_theme_stylebox_override(state, Clean.panel(fill, 200))
