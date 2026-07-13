extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "user://jigcat_progress_transition_visual_test.json"
const CAPTURE_DIR := "user://transition_visual_test"

var _device_prefix := "iphone"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_save()
	if OS.get_cmdline_user_args().has("--ipad"):
		root.size = Vector2i(1536, 2048)
		_device_prefix = "ipad"
	elif OS.get_cmdline_user_args().has("--project-size"):
		root.size = Vector2i(1206, 2622)
		_device_prefix = "project"
	else:
		root.size = Vector2i(904, 1532)
	var game = MAIN_SCENE.instantiate()
	game.progress_store.save_path = TEST_SAVE_PATH
	game.skip_launch_reveal = OS.get_cmdline_user_args().has("--skip-launch")
	root.add_child(game)
	if game.skip_launch_reveal:
		await process_frame
		await process_frame
	else:
		await _capture_sequence("%s_launch_clouds" % _device_prefix, [0.16, 0.20, 0.22, 0.24, 0.28, 0.32])
		await create_timer(0.20).timeout
	if game.topics.is_empty():
		push_error("Transition visual test needs at least one real topic.")
		quit(1)
		return
	var topic: Dictionary = game.topics[0]
	game._play_forward_transition(
		game._screen_transition_color(topic),
		func() -> void: game._show_levels(topic, game.progress_store.focus_level_id(topic))
	)
	await _capture_sequence("%s_forward_clouds" % _device_prefix, [0.12, 0.18, 0.22, 0.22, 0.24, 0.22, 0.22, 0.24, 0.28, 0.32])
	await create_timer(0.20).timeout
	game._play_back_transition(
		game._screen_transition_color(topic),
		game._show_topics
	)
	await _capture_sequence("%s_back_clouds" % _device_prefix, [0.12, 0.18, 0.22, 0.22, 0.24, 0.22, 0.22, 0.24, 0.28, 0.32])
	await create_timer(0.20).timeout
	game.queue_free()
	await process_frame
	_remove_test_save()
	quit(0)


func _capture_sequence(prefix: String, delays: Array[float]) -> void:
	for index in delays.size():
		await create_timer(delays[index]).timeout
		await RenderingServer.frame_post_draw
		_save_capture("%s_%02d.png" % [prefix, index + 1])


func _save_capture(file_name: String) -> void:
	var directory := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [directory, file_name]
	var error := image.save_png(path)
	if error != OK:
		push_error("Cannot save transition capture %s (error %d)" % [path, error])
	else:
		print("TRANSITION_CAPTURE %s" % path)


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
