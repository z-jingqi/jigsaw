class_name Game
extends Node2D

const RuntimeAppCoordinatorScript := preload("res://scripts/runtime/RuntimeAppCoordinator.gd")
const DebugCommandRouterScript := preload("res://scripts/debug/DebugCommandRouter.gd")

var _runtime: RuntimeAppCoordinator
var _debug_router: DebugCommandRouter


func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	_runtime = RuntimeAppCoordinatorScript.new(self)
	_runtime.start()
	_debug_router = DebugCommandRouterScript.new(_runtime)


func _exit_tree() -> void:
	if _runtime != null:
		_runtime.shutdown()
	_runtime = null
	_debug_router = null


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		if _runtime != null:
			_runtime.close_modal()
		get_viewport().set_input_as_handled()
		return
	if _runtime != null and _runtime.handle_input(event):
		get_viewport().set_input_as_handled()


func debug_execute(command: String, args: Dictionary = {}) -> Dictionary:
	if _debug_router == null:
		return {"ok": false, "command": command, "error": {"code": "debug_only", "message": "Debug adapter is not available."}}
	return _debug_router.execute(command, args)


func debug_state_snapshot() -> Dictionary:
	if _debug_router == null:
		return {"ok": false, "error": {"code": "debug_only", "message": "Debug adapter is not available."}}
	return _debug_router.state_snapshot()


func debug_level_options() -> Array:
	return _runtime.debug_level_options() if _runtime != null else []


func debug_runtime_metrics() -> Dictionary:
	return _runtime.runtime_metrics() if _runtime != null else {}


func debug_enter_level(option_index: int, play_mode: String) -> void:
	var options := debug_level_options()
	if option_index >= 0 and option_index < options.size():
		var option: Dictionary = options[option_index]
		_runtime.enter_level(str(option.topic_id), str(option.level_id), play_mode)


func debug_restart_current_level() -> void:
	var state := debug_state_snapshot()
	if str(state.get("level_id", "")).is_empty():
		return
	_runtime.enter_level(str(state.topic_id), str(state.level_id), str(state.mode), "replay")


func debug_apply_viewport_preset(size: Vector2i) -> void:
	if size.x > 0 and size.y > 0:
		get_window().size = size


func debug_trigger_hint() -> void:
	_runtime.trigger_hint()


func debug_clear_hint() -> void:
	_runtime.debug_board(&"debug_clear_hint")


func debug_reset_tray() -> void:
	_runtime.debug_board(&"debug_reset_tray")


func debug_scroll_tray_left() -> void:
	_runtime.debug_board(&"debug_scroll_tray_left")


func debug_scroll_tray_right() -> void:
	_runtime.debug_board(&"debug_scroll_tray_right")


func debug_toggle_bounds_overlay() -> void:
	_runtime.debug_board(&"debug_toggle_bounds_overlay")


func debug_preview_complete() -> void:
	_runtime.preview_complete()


func _start_runtime_board(screen: GameplayScreen) -> void:
	_runtime.start_runtime_board(screen)


func _run_runtime_action(action: Callable) -> void:
	_runtime.run_deferred(action)
