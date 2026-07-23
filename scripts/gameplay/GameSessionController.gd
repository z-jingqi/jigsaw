extends RefCounted
class_name GameSessionController


func persist_current_puzzle_state(game: Node) -> void:
	if game.puzzle_board == null or game.current_topic.is_empty() or game.current_level.is_empty() or game.current_mode.is_empty():
		return
	if not game.puzzle_board.should_persist_state():
		return
	game.session_repository.save_play_state(
		game.puzzle_board.session_snapshot(str(game.current_topic.get("id", "")), str(game.current_level.get("id", ""))),
		game.puzzle_board.session_piece_ids(),
	)


func show_game(game: Node, topic: Dictionary, level: Dictionary, play_mode: String, discard_current_state := false) -> void:
	if not discard_current_state:
		persist_current_puzzle_state(game)
	game.current_screen = "game"
	game.current_topic = topic
	game.current_level = level
	game.active_level_config = level_config_with_topic_background(game.repository.load_level_config(level), topic)
	var available_modes: Array[String] = game._available_modes_for_config(game.active_level_config)
	game.current_mode = game._mode_key(play_mode)
	if not available_modes.has(game.current_mode):
		game.current_mode = available_modes[0] if not available_modes.is_empty() else ""
	if game.current_mode.is_empty():
		game._show_levels(topic, str(level.get("id", "")))
		return
	if discard_current_state:
		game.session_repository.clear_play_state(str(topic.get("id", "")), str(level.get("id", "")), game.current_mode)
	game.session_repository.set_current(str(topic.get("id", "")), str(level.get("id", "")), game.current_mode)
	apply_level_media(game, game.active_level_config)
	game._clear_ui()
	game._clear_board()
	game.gameplay_runtime_host.show_gameplay(level, game.current_mode)
	var random_rotation: bool = game.progress_store.random_rotation_enabled() and game.current_mode != "swap"
	var loaded: bool = game.puzzle_board.start(
		game.active_level_config,
		game.current_mode,
		game.texture,
		game.source_image,
		game.source_size,
		game.gameplay_runtime_host.gameplay_top_reserved_height(),
		random_rotation,
		{},
		game.gameplay_runtime_host.gameplay_bottom_reserved_height(),
		game.gameplay_runtime_host.gameplay_tray_rect(),
	)
	if loaded:
		var restore_state: Dictionary = game.session_repository.play_state(str(topic.get("id", "")), str(level.get("id", "")), game.current_mode, game.puzzle_board.session_piece_ids())
		if not restore_state.is_empty():
			game.puzzle_board.apply_state_snapshot(restore_state)
		game.gameplay_runtime_host.mark_board_live()
	if loaded and not game.progress_store.tutorial_seen(game.current_mode):
		game._show_tutorial_modal()


func level_config_with_topic_background(level_config: Dictionary, topic: Dictionary) -> Dictionary:
	var result := level_config.duplicate(true)
	var background_path := str(topic.get("level_background", ""))
	if background_path.is_empty():
		return result
	var palette_value = topic.get("ui_palette", {})
	var palette: Dictionary = palette_value if typeof(palette_value) == TYPE_DICTIONARY else {}
	result["_topic_ui_palette"] = palette.duplicate(true)
	result["background"] = {
		"type": "image",
		"path": background_path,
		"color": str(palette.get("surface", "#F5F0E3")),
	}
	return result


func on_puzzle_completed(game: Node) -> void:
	var locks_before: Dictionary = game._compute_level_locks(game.current_topic)
	game.progress_store.mark_completed(game.current_level["id"], game.current_mode)
	var locks_after: Dictionary = game._compute_level_locks(game.current_topic)
	for level in game.current_topic.get("levels", []):
		var level_id := str(level.get("id", ""))
		if not bool(locks_before.get(level_id, false)) and bool(locks_after.get(level_id, false)):
			game.newly_unlocked_topic_id = str(game.current_topic.get("id", ""))
			game.newly_unlocked_level_id = level_id
			break
	game.session_repository.clear_play_state(str(game.current_topic.get("id", "")), str(game.current_level.get("id", "")), game.current_mode)
	game._show_complete_modal()


func on_puzzle_state_changed(game: Node, _state: Dictionary) -> void:
	if game.current_screen != "game" or game.current_topic.is_empty() or game.current_level.is_empty() or game.current_mode.is_empty():
		return
	game.session_repository.save_play_state(
		game.puzzle_board.session_snapshot(str(game.current_topic.get("id", "")), str(game.current_level.get("id", ""))),
		game.puzzle_board.session_piece_ids(),
	)


func apply_level_media(game: Node, level_config: Dictionary) -> void:
	var media: Dictionary = game.repository.apply_level_media(level_config)
	game.texture = media["texture"]
	game.source_image = media["image"]
	game.source_size = media["source_size"]


func return_to_current_level_list(game: Node) -> void:
	if game.current_topic.is_empty():
		game._show_topics()
		return
	var topic: Dictionary = game.current_topic
	var focus_id := str(game.current_level.get("id", ""))
	game._show_levels(topic, focus_id)
