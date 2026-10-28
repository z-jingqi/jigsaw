extends RefCounted
## Quiet, shared gameplay chrome; puzzle artwork remains the primary visual.

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const INK := Clean.INK
const BOARD_SURFACE := Color(0.80, 0.81, 0.80, 0.30)
const BOARD_RIM := Clean.PAPER
const TRAY_SURFACE := BOARD_SURFACE
const SCROLL_TRACK := Color(0.55, 0.57, 0.55, 0.20)
const SCROLL_THUMB := Color(0.38, 0.40, 0.38, 0.55)


static func apply_button(button: Button, _secondary := false) -> void:
	Clean.button(button, false)
