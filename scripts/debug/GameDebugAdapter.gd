extends RefCounted
class_name GameDebugAdapter

var game: Node


func _init(owner: Node) -> void:
	game = owner


func execute(command: String, args: Dictionary = {}) -> Dictionary:
	if not OS.is_debug_build():
		return _failure(command, "debug_only", "Debug commands are disabled in release exports.")
	match command:
		"state":
			pass
		"show_topics":
			game._show_topics()
		"show_levels":
			var topic_result := _required_topic(command, args)
			if not bool(topic_result.get("ok", false)):
				return topic_result
			game._show_levels(topic_result["topic"])
		"show_mode_select":
			var selection := _required_level(command, args)
			if not bool(selection.get("ok", false)):
				return selection
			game._show_levels(selection["topic"])
			game._show_mode_dialog(selection["level"])
		"show_settings":
			game._show_settings_modal()
		"show_tutorial":
			if game.current_screen != "game":
				return _failure(command, "wrong_screen", "Tutorial preview requires an active game screen.")
			game._show_tutorial_modal()
		"enter_level":
			var entry := _required_level(command, args)
			if not bool(entry.get("ok", false)):
				return entry
			var play_mode_result := _required_mode(command, args, entry["level"])
			if not bool(play_mode_result.get("ok", false)):
				return play_mode_result
			game._close_modal()
			game._show_game(entry["topic"], entry["level"], play_mode_result["mode"])
		"preview_complete":
			preview_complete()
		"close_modal":
			if not game.modal_open:
				return _failure(command, "wrong_screen", "No modal is currently open.")
			game._close_modal()
		"set_viewport":
			var viewport_result := _viewport_args(command, args)
			if not bool(viewport_result.get("ok", false)):
				return viewport_result
			apply_viewport_preset(Vector2i(viewport_result["width"], viewport_result["height"]))
		"set_reduced_motion":
			if not args.has("enabled") or typeof(args["enabled"]) != TYPE_BOOL:
				return _failure(command, "invalid_argument", "enabled must be a boolean.")
			var enabled := bool(args["enabled"])
			game.progress_store.set_reduced_motion_enabled(enabled)
			game.puzzle_board.set_feedback_preferences(
				game.progress_store.haptics_enabled(),
				enabled,
				game.progress_store.edge_contrast_mode(),
			)
		_:
			return _failure(command, "unknown_command", "Unknown debug command: %s" % command)
	return {
		"ok": true,
		"command": command,
		"state": state_snapshot(),
	}


func state_snapshot() -> Dictionary:
	if not OS.is_debug_build():
		return {
			"ok": false,
			"error": {"code": "debug_only", "message": "Debug state is disabled in release exports."},
		}
	var viewport_size: Vector2i = game.get_window().size
	var content_viewport_size: Vector2 = game.get_viewport_rect().size
	var active_motion_count: int = game.modal_host.active_motion_count()
	if game.topic_pager_controller != null and bool(game.topic_pager_controller.transitioning):
		active_motion_count += 1
	if (
		game.level_list_screen != null
		and game.level_list_screen.pager != null
		and game.level_list_screen.pager.tween != null
		and game.level_list_screen.pager.tween.is_valid()
	):
		active_motion_count += 1
	if game.ui_motion != null:
		active_motion_count += game.ui_motion.button_tweens.size()
	var state := {
		"screen": game.current_screen,
		"modal": game.current_modal if game.modal_open else "",
		"topic_id": str(game.current_topic.get("id", "")),
		"level_id": str(game.current_level.get("id", "")),
		"mode": game.current_mode if game.current_screen == "game" else "",
		"viewport": [viewport_size.x, viewport_size.y],
		"content_viewport": [roundi(content_viewport_size.x), roundi(content_viewport_size.y)],
		"reduced_motion": game.progress_store.reduced_motion_enabled(),
		"active_motion_count": active_motion_count,
	}
	if game.modal_open:
		state["modal_motion"] = game.modal_host.debug_state()
	return state


func level_options() -> Array:
	var result: Array = []
	for topic in game.topics:
		for level in topic.get("levels", []):
			if typeof(level) != TYPE_DICTIONARY:
				continue
			var modes: Array[String] = game._available_modes_for_level(level)
			if modes.is_empty():
				continue
			result.append({
				"label": "%s / %s" % [str(topic.get("name", "")), game._level_display_title(level)],
				"topic_id": str(topic.get("id", "")),
				"level_id": str(level.get("id", "")),
				"modes": modes,
			})
	return result


func enter_level(option_index: int, play_mode: String) -> void:
	var options := level_options()
	if option_index < 0 or option_index >= options.size():
		return
	var option: Dictionary = options[option_index]
	var topic := _topic_by_id(str(option.get("topic_id", "")))
	var level := _level_by_id(topic, str(option.get("level_id", "")))
	if topic.is_empty() or level.is_empty():
		return
	game._close_modal()
	game._show_game(topic, level, play_mode)


func restart_current_level() -> void:
	if game.current_topic.is_empty() or game.current_level.is_empty() or game.current_mode.is_empty():
		return
	game._close_modal()
	game.progress_store.clear_play_state(game.current_topic, game.current_level, game.current_mode)
	game._show_game(game.current_topic, game.current_level, game.current_mode, true)


func apply_viewport_preset(size: Vector2i) -> void:
	if size.x > 0 and size.y > 0:
		game.get_window().size = size
	game.call_deferred("_debug_refresh_current_screen")


func runtime_metrics() -> Dictionary:
	var metrics := {
		"screen": game.current_screen,
		"topic": str(game.current_topic.get("name", "")),
		"level": game._level_display_title(game.current_level) if not game.current_level.is_empty() else "",
		"mode": game.current_mode,
	}
	if game.puzzle_board != null and game.puzzle_board.has_method("debug_runtime_metrics"):
		metrics.merge(game.puzzle_board.debug_runtime_metrics(), true)
	return metrics


func trigger_hint() -> void:
	if game.current_screen == "game" and game.puzzle_board != null:
		game.puzzle_board.show_hint()


func clear_hint() -> void:
	_call_board_debug("debug_clear_hint")


func reset_tray() -> void:
	_call_board_debug("debug_reset_tray")


func scroll_tray_left() -> void:
	_call_board_debug("debug_scroll_tray_left")


func scroll_tray_right() -> void:
	_call_board_debug("debug_scroll_tray_right")


func toggle_bounds_overlay() -> void:
	_call_board_debug("debug_toggle_bounds_overlay")


func preview_complete() -> void:
	if game.current_topic.is_empty() or game.current_level.is_empty():
		var options := level_options()
		if options.is_empty():
			return
		enter_level(0, str(options[0].get("modes", ["polygon"])[0]))
	game._show_complete_modal()


func clear_current_progress() -> void:
	if game.current_level.is_empty():
		return
	game.progress_store.clear_level_progress(game.current_topic, game.current_level)
	refresh_current_screen()


func clear_all_progress() -> void:
	game.progress_store.clear_all_progress()
	refresh_current_screen()


func dump_state() -> void:
	var state := runtime_metrics()
	if game.puzzle_board != null and game.puzzle_board.has_method("state_snapshot"):
		state["snapshot"] = game.puzzle_board.state_snapshot()
	print(JSON.stringify(state, "\t"))


func run_current_interaction_smoke() -> Dictionary:
	if game.current_screen != "game" or game.puzzle_board == null:
		return {"ok": false, "reason": "no_active_game"}
	return await game.puzzle_board.debug_run_interaction_smoke()


func refresh_current_screen() -> void:
	if game.current_screen == "game" and not game.current_topic.is_empty() and not game.current_level.is_empty() and not game.current_mode.is_empty():
		game._show_game(game.current_topic, game.current_level, game.current_mode)
	elif game.current_screen == "levels" and not game.current_topic.is_empty():
		game._show_levels(game.current_topic, str(game.current_level.get("id", "")))
	else:
		game._show_topics()


func _call_board_debug(method: StringName) -> void:
	if game.puzzle_board != null and game.puzzle_board.has_method(method):
		game.puzzle_board.call(method)


func _topic_by_id(topic_id: String) -> Dictionary:
	for topic in game.topics:
		if str(topic.get("id", "")) == topic_id:
			return topic
	return {}


func _level_by_id(topic: Dictionary, level_id: String) -> Dictionary:
	for level in topic.get("levels", []):
		if str(level.get("id", "")) == level_id:
			return level
	return {}


func _required_topic(command: String, args: Dictionary) -> Dictionary:
	var topic_id_value = args.get("topic_id", null)
	if typeof(topic_id_value) != TYPE_STRING or str(topic_id_value).strip_edges().is_empty():
		return _failure(command, "invalid_argument", "topic_id must be a non-empty string.")
	var topic := _topic_by_id(str(topic_id_value))
	if topic.is_empty():
		return _failure(command, "not_found", "Topic not found: %s" % str(topic_id_value))
	return {"ok": true, "topic": topic}


func _required_level(command: String, args: Dictionary) -> Dictionary:
	var topic_result := _required_topic(command, args)
	if not bool(topic_result.get("ok", false)):
		return topic_result
	var level_id_value = args.get("level_id", null)
	if typeof(level_id_value) != TYPE_STRING or str(level_id_value).strip_edges().is_empty():
		return _failure(command, "invalid_argument", "level_id must be a non-empty string.")
	var topic: Dictionary = topic_result["topic"]
	var level := _level_by_id(topic, str(level_id_value))
	if level.is_empty():
		return _failure(command, "not_found", "Level not found in topic: %s" % str(level_id_value))
	return {"ok": true, "topic": topic, "level": level}


func _required_mode(command: String, args: Dictionary, level: Dictionary) -> Dictionary:
	var mode_value = args.get("mode", null)
	if typeof(mode_value) != TYPE_STRING or str(mode_value).strip_edges().is_empty():
		return _failure(command, "invalid_argument", "mode must be a non-empty string.")
	var mode := str(mode_value)
	var available: Array[String] = game._available_modes_for_level(level)
	if not available.has(mode):
		return _failure(command, "invalid_argument", "Mode %s is unavailable; expected one of %s." % [mode, available])
	return {"ok": true, "mode": mode}


func _viewport_args(command: String, args: Dictionary) -> Dictionary:
	if not args.has("width") or not args.has("height"):
		return _failure(command, "invalid_argument", "width and height are required.")
	if typeof(args["width"]) != TYPE_INT or typeof(args["height"]) != TYPE_INT:
		return _failure(command, "invalid_argument", "width and height must be integers.")
	var width := int(args["width"])
	var height := int(args["height"])
	if width <= 0 or height <= 0 or width > 8192 or height > 8192:
		return _failure(command, "invalid_argument", "width and height must be between 1 and 8192.")
	return {"ok": true, "width": width, "height": height}


func _failure(command: String, code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"command": command,
		"error": {"code": code, "message": message},
		"state": state_snapshot() if OS.is_debug_build() else {},
	}
