extends RefCounted
class_name GameDebugAdapter

var game: Node


func _init(owner: Node) -> void:
	game = owner


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
