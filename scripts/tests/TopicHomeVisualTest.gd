extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "user://jigcat_topic_home_visual_test.json"
const OUTPUT_DIR := "res://tmp/validation"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(603, 1311)
	var game = MAIN_SCENE.instantiate()
	game.progress_store.save_path = TEST_SAVE_PATH
	root.add_child(game)
	await process_frame
	await process_frame
	await create_timer(0.55).timeout
	var phone := await _validate_viewport(game, "phone", Vector2i(603, 1311))
	root.size = Vector2i(768, 1024)
	game._show_topics()
	await process_frame
	await process_frame
	await create_timer(0.55).timeout
	var tablet := await _validate_viewport(game, "tablet", Vector2i(768, 1024))
	var result := {
		"ok": bool(phone.get("ok", false)) and bool(tablet.get("ok", false)),
		"phone": phone,
		"tablet": tablet,
	}
	print("TOPIC_HOME_VISUAL %s" % JSON.stringify(result))
	game.queue_free()
	await process_frame
	_remove_test_save()
	quit(0 if bool(result["ok"]) else 1)


func _validate_viewport(game, label: String, expected_size: Vector2i) -> Dictionary:
	var viewport_size: Vector2 = game.get_viewport_rect().size
	var order: Array[String] = []
	var covers_ok := true
	for topic in game.topics:
		order.append(str(topic.get("name", "")))
		var cover := str(topic.get("cover", ""))
		covers_ok = covers_ok and cover.get_extension().to_lower() == "webp" and FileAccess.file_exists(game.repository.image_file_path(cover))
	var pager: Dictionary = game.topic_pager_controller.debug_state()
	var fixed_ui: Control = game.screen_root.get_node_or_null("topic_home_fixed_ui")
	var title: Label = game.screen_root.find_child("topic_home_title", true, false)
	var progress: Control = game.screen_root.find_child("topic_home_progress", true, false)
	var enter: Button = game.screen_root.find_child("topic_enter_button", true, false)
	var previous: Button = game.screen_root.find_child("topic_previous_button", true, false)
	var all_topics: Button = game.screen_root.find_child("topic_all_button", true, false)
	var next: Button = game.screen_root.find_child("topic_next_button", true, false)
	var logo: TextureRect = game.screen_root.find_child("theme_logo", true, false)
	var settings: Button = game.screen_root.find_child("theme_settings_button", true, false)
	var initial_index: int = game.topic_pager_controller.current_page
	game.topic_pager_controller.go_to_page(game.topics.size() - 1, false)
	game.topic_pager_controller.go_relative(1, false)
	var wraps: bool = game.topic_pager_controller.current_page == 0
	game.topic_pager_controller.go_to_page(initial_index, false)
	var current_page: Control = game.topic_pager_controller.rendered_pages.get(0, null)
	var cover: TextureRect = current_page.get_node_or_null("topic_home_cover") if current_page != null else null
	game.topics_screen._toggle_selector()
	await create_timer(0.22).timeout
	var selector: Panel = game.screen_root.get_node_or_null("topic_selector_panel")
	var grid: GridContainer = selector.get_node_or_null("topic_selector_scroll/topic_selector_grid") if selector != null else null
	var selector_ok: bool = selector != null and selector.visible and grid != null and grid.columns == 2 and grid.get_child_count() == game.topics.size()
	await _save_frame("%s/topic-home-%s-selector.png" % [OUTPUT_DIR, label])
	game.topics_screen._toggle_selector()
	await create_timer(0.16).timeout
	var controls: Array[Control] = [logo, settings, title, progress, enter, previous, all_topics, next]
	var bounds_ok := true
	for control in controls:
		bounds_ok = bounds_ok and control != null and _inside_viewport(control.get_global_rect(), viewport_size)
	var cover_ok := cover != null and cover.texture != null and cover.size.is_equal_approx(viewport_size)
	var persisted := str(game.progress_store.progress.get("current_topic_id", "")) == str(game.topics[initial_index].get("id", ""))
	var structure_ok: bool = (
		fixed_ui != null
		and pager.get("page_count", 0) == game.topics.size()
		and int(pager.get("rendered_page_count", 0)) <= 3
		and title != null
		and title.text == str(game.topics[initial_index].get("name", ""))
		and order == ["山海经", "希腊神话", "猫", "狗"]
	)
	await _save_frame("%s/topic-home-%s.png" % [OUTPUT_DIR, label])
	return {
		"ok": covers_ok and structure_ok and bounds_ok and cover_ok and selector_ok and wraps and persisted,
		"viewport": viewport_size,
		"expected": expected_size,
		"topic_order": order,
		"covers": covers_ok,
		"structure": structure_ok,
		"bounds": bounds_ok,
		"cover_fills_viewport": cover_ok,
		"cover_size": cover.size if cover != null else Vector2.ZERO,
		"selector": selector_ok,
		"wraps": wraps,
		"persisted": persisted,
		"pager": pager,
	}


func _inside_viewport(rect: Rect2, viewport_size: Vector2) -> bool:
	return rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= viewport_size.x + 0.5 and rect.end.y <= viewport_size.y + 0.5


func _save_frame(path: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
