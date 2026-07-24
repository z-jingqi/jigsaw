class_name DebugCommandRouter
extends RefCounted

var _runtime: RuntimeAppCoordinator


func _init(runtime: RuntimeAppCoordinator) -> void:
	_runtime = runtime


func execute(command: String, args: Dictionary = {}) -> Dictionary:
	if not OS.is_debug_build():
		return _failure(command, "debug_only", "Debug commands are disabled in release exports.")
	if command != "state":
		_runtime.settle_navigation()
	var result: Dictionary = {"ok": true}
	match command:
		"state":
			pass
		"show_home", "show_topics":
			result = _runtime.show_home(str(args.get("theme_id", "")))
		"show_all_themes":
			result = _runtime.show_all_themes()
		"show_levels":
			if not _strings(args, ["topic_id"]):
				return _failure(command, "invalid_argument", "topic_id is required.")
			result = _runtime.show_levels(str(args.topic_id), str(args.get("level_id", "")))
		"show_mode_select":
			if not _strings(args, ["topic_id", "level_id"]):
				return _failure(command, "invalid_argument", "topic_id and level_id are required.")
			result = _runtime.show_mode_select(str(args.topic_id), str(args.level_id))
		"show_settings":
			result = _runtime.show_settings()
		"show_home_guide":
			result = _runtime.show_home_guide()
		"show_mode_tutorial", "show_tutorial":
			if not _strings(args, ["mode"]):
				return _failure(command, "invalid_argument", "mode is required.")
			result = _runtime.show_mode_tutorial(str(args.mode))
		"enter_level":
			if not _strings(args, ["topic_id", "level_id", "mode"]):
				return _failure(
					command, "invalid_argument", "topic_id, level_id and mode are required."
				)
			result = _runtime.enter_level(
				str(args.topic_id),
				str(args.level_id),
				str(args.mode),
				str(args.get("start_policy", "start"))
			)
		"preview_complete":
			result = _runtime.preview_complete()
		"close_modal":
			result = _runtime.close_modal()
		"set_viewport":
			if (
				typeof(args.get("width")) != TYPE_INT
				or typeof(args.get("height")) != TYPE_INT
				or int(args.width) <= 0
				or int(args.height) <= 0
			):
				return _failure(
					command, "invalid_argument", "width and height must be positive integers."
				)
			_runtime.set_viewport(int(args.width), int(args.height))
		"set_reduced_motion":
			if typeof(args.get("enabled")) != TYPE_BOOL:
				return _failure(command, "invalid_argument", "enabled must be a boolean.")
			result = _runtime.set_reduced_motion(bool(args.enabled))
		_:
			return _failure(command, "unknown_command", "Unknown debug command: %s" % command)
	if not bool(result.get("ok", false)):
		return _failure(command, str(result.get("error", "invalid_argument")), "Command failed.")
	return {"ok": true, "command": command, "state": state_snapshot()}


func state_snapshot() -> Dictionary:
	if not OS.is_debug_build():
		return {
			"ok": false,
			"error":
			{"code": "debug_only", "message": "Debug state is disabled in release exports."}
		}
	return _runtime.state_snapshot()


func _strings(args: Dictionary, fields: Array[String]) -> bool:
	for field in fields:
		if typeof(args.get(field)) != TYPE_STRING or str(args.get(field)).strip_edges().is_empty():
			return false
	return true


func _failure(command: String, code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"command": command,
		"error": {"code": code, "message": message},
		"state": state_snapshot() if OS.is_debug_build() else {}
	}
