extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "user://jigcat_progress_transition_visual_test.json"


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
	if game.topics.is_empty():
		push_error("Transition smoke test needs at least one real topic.")
		quit(1)
		return
	var no_launch_clouds := _cloud_transitions(game).is_empty()
	var topic: Dictionary = game.topics[0]
	game._open_topic_levels(topic)
	var entered_immediately: bool = game.current_screen == "levels"
	await process_frame
	var no_forward_clouds := _cloud_transitions(game).is_empty()
	game._show_topics()
	var returned_immediately: bool = game.current_screen == "topics"
	await process_frame
	var no_back_clouds := _cloud_transitions(game).is_empty()
	var result := {
		"ok": no_launch_clouds and entered_immediately and no_forward_clouds and returned_immediately and no_back_clouds,
		"no_launch_clouds": no_launch_clouds,
		"entered_immediately": entered_immediately,
		"no_forward_clouds": no_forward_clouds,
		"returned_immediately": returned_immediately,
		"no_back_clouds": no_back_clouds,
	}
	print("CLOUD_TRANSITION_REMOVED %s" % JSON.stringify(result))
	game.queue_free()
	await process_frame
	_remove_test_save()
	quit(0 if bool(result["ok"]) else 1)


func _cloud_transitions(game: Node) -> Array[Node]:
	return game.find_children("*", "CloudTransition", true, false)


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
