extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "user://jigcat_progress_game_flow_test.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_save()
	root.size = Vector2i(1206, 2622)
	var game = MAIN_SCENE.instantiate()
	game.progress_store.save_path = TEST_SAVE_PATH
	root.add_child(game)
	await process_frame
	await process_frame
	var all_ok := true
	var first_topic: Dictionary = game.topics[0] if not game.topics.is_empty() else {}
	var first_level: Dictionary = first_topic.get("levels", [])[0] if not first_topic.get("levels", []).is_empty() else {}
	var first_config: Dictionary = game.repository.load_level_config(first_level)
	var thumbnail_path: String = game.repository.level_thumbnail_source_path(first_config)
	var source_path: String = game.repository.default_level_image_path(first_config)
	var thumbnail_image := Image.load_from_file(game.repository.image_file_path(thumbnail_path))
	var thumbnail_ok: bool = (
		thumbnail_path != source_path
		and thumbnail_path.get_file() == game.repository.LEVEL_THUMBNAIL_FILE
		and FileAccess.file_exists(thumbnail_path)
		and thumbnail_image != null
		and not thumbnail_image.is_empty()
		and maxi(thumbnail_image.get_width(), thumbnail_image.get_height()) <= 960
	)
	print("LEVEL_THUMBNAIL %s" % JSON.stringify({"ok": thumbnail_ok, "path": thumbnail_path, "source": source_path}))
	all_ok = all_ok and thumbnail_ok
	var locked_card = game._level_grid_card(first_topic, first_level, false, 300.0, 1.0)
	var locked_card_ok: bool = locked_card.find_child("level_card_back", true, false) != null and locked_card.find_child("level_card_overlay", true, false) == null
	print("LOCKED_CARD %s" % JSON.stringify({"ok": locked_card_ok, "has_modes": locked_card.find_child("level_card_overlay", true, false) != null}))
	all_ok = all_ok and locked_card_ok
	locked_card.queue_free()
	var dev_key_ok := _test_dev_key(game)
	print("DEV_KEY %s" % JSON.stringify({"ok": dev_key_ok}))
	all_ok = all_ok and dev_key_ok
	for play_mode in ["polygon", "knob", "swap"]:
		var level_index := _level_index_for_mode(game, first_topic, play_mode)
		if level_index < 0:
			all_ok = false
			print("GAME_FLOW %s" % JSON.stringify({"mode": play_mode, "ok": false, "reason": "no_available_level"}))
			continue
		game.debug_enter_level(level_index, play_mode)
		await process_frame
		var loaded: bool = game.current_screen == "game" and game.current_mode == play_mode and game.puzzle_board.should_persist_state()
		game.puzzle_board.debug_force_complete()
		await process_frame
		var modal_visible: bool = game.modal_open and _tree_has_text(game.modal_root, game._t("complete"))
		var completed: bool = game.progress_store.is_done(str(game.current_level.get("id", "")), play_mode)
		var state_cleared: bool = game.progress_store.play_state(game.current_topic, game.current_level, play_mode).is_empty()
		var result := {
			"mode": play_mode,
			"loaded": loaded,
			"modal": modal_visible,
			"completed": completed,
			"state_cleared": state_cleared,
		}
		result["ok"] = loaded and modal_visible and completed and state_cleared
		all_ok = all_ok and bool(result["ok"])
		print("GAME_FLOW %s" % JSON.stringify(result))
		game._close_modal()
		await process_frame
	game.queue_free()
	await process_frame
	_remove_test_save()
	quit(0 if all_ok else 1)


func _level_index_for_mode(game, topic: Dictionary, play_mode: String) -> int:
	var levels: Array = topic.get("levels", [])
	for index in levels.size():
		if game._available_modes_for_level(levels[index]).has(play_mode):
			return index
	return -1


func _tree_has_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text == expected:
		return true
	if node is Button and (node as Button).text == expected:
		return true
	for child in node.get_children():
		if _tree_has_text(child, expected):
			return true
	return false


func _test_dev_key(game) -> bool:
	if game.dev_panel == null:
		return false
	var press := InputEventKey.new()
	press.keycode = KEY_D
	press.physical_keycode = KEY_D
	press.pressed = true
	game._input(press)
	var opened: bool = game.dev_panel.visible
	var release := press.duplicate()
	release.pressed = false
	game._input(release)
	game._input(press)
	return opened and not game.dev_panel.visible


func _remove_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)
