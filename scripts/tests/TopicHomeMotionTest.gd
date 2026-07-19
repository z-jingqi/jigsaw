extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "user://jigcat_progress_topic_home_motion_test.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_save()
	root.size = Vector2i(603, 1200)
	var game = MAIN_SCENE.instantiate()
	game.progress_store.save_path = TEST_SAVE_PATH
	root.add_child(game)
	await process_frame
	await process_frame
	await create_timer(0.45).timeout
	var viewport_width: float = game.get_viewport_rect().size.x
	var initial: Dictionary = game.topic_pager_controller.debug_state()
	var real_catalog_ok: bool = game.topics.size() == 4 and str(game.topics[0].get("name", "")) == "山海经"
	game.topic_pager_controller.begin_drag(Vector2(viewport_width * 0.5, 600.0))
	game.topic_pager_controller.drag_by(Vector2(-viewport_width * 0.45, 0.0), 0.25)
	var midpoint: Dictionary = game.topic_pager_controller.debug_state()
	var outgoing: Control = game.topic_pager_controller.rendered_pages.get(0, null)
	var incoming: Control = game.topic_pager_controller.rendered_pages.get(1, null)
	var fade_ok := (
		outgoing != null
		and incoming != null
		and outgoing.modulate.a < 0.9
		and incoming.modulate.a < 0.9
		and outgoing.modulate.a > 0.6
		and incoming.modulate.a > 0.6
	)
	var midpoint_ok := (
		absf(float(midpoint.get("visual_page", 0.0)) - 0.45) <= 0.03
		and int(midpoint.get("rendered_page_count", 0)) == 3
		and bool(midpoint.get("drag_active", false))
		and fade_ok
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/validation"))
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp/validation/topic-home-swipe-midpoint.png"))
	game.topic_pager_controller.end_drag(Vector2(viewport_width * 0.05, 600.0))
	await create_timer(0.42).timeout
	var swipe_ok: bool = game.topic_pager_controller.current_page == 1 and str(game.current_topic.get("id", "")) == str(game.topics[1].get("id", ""))
	game.topic_pager_controller.go_to_page(3, true)
	await create_timer(0.48).timeout
	var direct_ok: bool = game.topic_pager_controller.current_page == 3
	game.topic_pager_controller.go_relative(1, false)
	var wrap_ok: bool = game.topic_pager_controller.current_page == 0
	var persisted_ok := str(game.progress_store.progress.get("current_topic_id", "")) == str(game.topics[0].get("id", ""))
	game.progress_store.set_reduced_motion_enabled(true)
	game._show_topics()
	await process_frame
	var before_reduced: int = game.topic_pager_controller.current_page
	game.topic_pager_controller.go_relative(1, true)
	var reduced_ok: bool = game.topic_pager_controller.current_page == posmod(before_reduced + 1, game.topics.size()) and not game.topic_pager_controller.transitioning
	var final_state: Dictionary = game.topic_pager_controller.debug_state()
	var result := {
		"ok": real_catalog_ok and midpoint_ok and swipe_ok and direct_ok and wrap_ok and persisted_ok and reduced_ok,
		"real_catalog": real_catalog_ok,
		"initial": initial,
		"midpoint": midpoint,
		"midpoint_ok": midpoint_ok,
		"fade": fade_ok,
		"swipe": swipe_ok,
		"direct": direct_ok,
		"wrap": wrap_ok,
		"persisted": persisted_ok,
		"reduced_motion": reduced_ok,
		"final": final_state,
	}
	print("TOPIC_HOME_MOTION %s" % JSON.stringify(result))
	game.queue_free()
	await process_frame
	_remove_test_save()
	quit(0 if bool(result["ok"]) else 1)


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
