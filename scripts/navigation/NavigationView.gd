class_name NavigationView
extends Control

## Base protocol for a navigable runtime view.
##
## Product screens are free to implement only the callbacks they need. The
## navigator also applies a safe default when a scene does not extend this
## class, so a screen never has to reach into navigation internals.

func navigation_enter(_payload: Dictionary, _context: Dictionary) -> void:
	pass


func navigation_exit(_context: Dictionary) -> void:
	pass


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
	set_process(is_active)
	set_process_input(is_active)
	set_process_unhandled_input(is_active)
