extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "user://jigcat_visual_inventory_test.json"
const OUTPUT_DIR := "res://tmp/visual-audit"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(603, 1200)
	var game = MAIN_SCENE.instantiate()
	game.progress_store.save_path = TEST_SAVE_PATH
	root.add_child(game)
	await _settle()
	var topic: Dictionary = game.topics[0]
	var level: Dictionary = topic.get("levels", [])[0]
	game._show_levels(topic)
	await _capture("01-level-list.png")
	game._show_mode_dialog(level)
	await _capture("02-mode-select.png")
	game._close_modal()
	await _settle()
	game._show_settings_modal()
	await _capture("03-settings.png")
	game._close_modal()
	await _settle()
	for play_mode in ["polygon", "swap"]:
		var level_index := _level_index_for_mode(game, topic, play_mode)
		if level_index < 0:
			continue
		game.progress_store.mark_tutorial_seen(play_mode)
		game.debug_enter_level(level_index, play_mode)
		await _capture("04-game-%s.png" % play_mode)
		game._show_tutorial_modal()
		await _capture("05-tutorial-%s.png" % play_mode)
		game._close_modal()
		await _settle()
		if play_mode == "polygon":
			game.puzzle_board.debug_force_complete()
			await _capture("06-complete.png")
			game._close_modal()
			await _settle()
	print("VISUAL_INVENTORY %s" % JSON.stringify({"ok": true, "output": ProjectSettings.globalize_path(OUTPUT_DIR)}))
	game.queue_free()
	await process_frame
	_remove_test_save()
	quit(0)


func _capture(file_name: String) -> void:
	await _settle()
	var output_path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	root.get_texture().get_image().save_png(output_path)


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _level_index_for_mode(game, topic: Dictionary, play_mode: String) -> int:
	var levels: Array = topic.get("levels", [])
	for index in levels.size():
		if game._available_modes_for_level(levels[index]).has(play_mode):
			return index
	return -1


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
