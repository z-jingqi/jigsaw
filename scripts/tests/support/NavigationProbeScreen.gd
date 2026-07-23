extends Control

var entered_payload: Dictionary = {}
var enter_count := 0
var exit_count := 0
var active := false


func navigation_enter(payload: Dictionary, _context: Dictionary) -> void:
	entered_payload = payload.duplicate(true)
	enter_count += 1


func navigation_exit(_context: Dictionary) -> void:
	exit_count += 1


func navigation_set_active(is_active: bool) -> void:
	active = is_active
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
	set_process(is_active)
	set_process_input(is_active)
	set_process_unhandled_input(is_active)
