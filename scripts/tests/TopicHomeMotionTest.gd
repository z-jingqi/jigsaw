extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "user://jigcat_progress_topic_home_motion_test.json"
const MOCK_TOPIC_COUNT := 16


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_save()
	root.size = Vector2i(1179, 2556)
	var game = MAIN_SCENE.instantiate()
	game.progress_store.save_path = TEST_SAVE_PATH
	root.add_child(game)
	await process_frame
	await process_frame
	if game.topics.is_empty():
		push_error("Topic home motion test needs at least one real topic.")
		quit(1)
		return

	var expected_first_page_cards := mini(game.topic_pager_controller.PAGE_SIZE, game.topics.size())
	var initial_state: Dictionary = game.topic_home_motion.debug_state()
	var entrance_registered := int(initial_state.get("registered_card_count", 0)) == expected_first_page_cards
	var entrance_staggered := int(initial_state.get("entry_card_count", 0)) == expected_first_page_cards
	await create_timer(0.62).timeout
	var first_topic: Dictionary = game.topics[0]
	var first_topic_id := str(first_topic.get("id", ""))
	var first_card := _topic_card(game, first_topic_id)
	var entrance_settled := _card_is_settled(first_card)
	var entry_page: Control = game.topic_pager_controller.rendered_pages.get(0, null)
	var decorations_settled := _decorations_are_settled(entry_page)

	game.topic_home_motion.press_card(first_topic_id)
	await create_timer(0.10).timeout
	var press_feedback := first_card != null and first_card.scale.x < 0.995
	game.topic_home_motion.cancel_card(first_topic_id)
	await create_timer(0.20).timeout
	var press_restored := first_card != null and first_card.scale.is_equal_approx(Vector2.ONE)

	var completion := _first_completion(game, first_topic)
	var progress_detected := false
	var progress_finished := false
	if not completion.is_empty():
		game.progress_store.mark_completed(str(completion.get("level_id", "")), str(completion.get("mode", "")))
		game._show_topics()
		await process_frame
		var progress_state: Dictionary = game.topic_home_motion.debug_state()
		progress_detected = str(progress_state.get("last_progress_topic_id", "")) == first_topic_id
		await create_timer(1.05).timeout
		first_card = _topic_card(game, first_topic_id)
		var count: Label = first_card.get_node_or_null("theme_card_progress_count") if first_card != null else null
		var total := int(first_card.get_meta("topic_progress_total", 0)) if first_card != null else 0
		progress_finished = count != null and count.text == "1/%d" % total

	game.progress_store.progress["reduced_motion_enabled"] = true
	game._show_topics()
	await process_frame
	first_card = _topic_card(game, first_topic_id)
	var reduced_state: Dictionary = game.topic_home_motion.debug_state()
	var reduced_motion_ok := (
		_card_is_settled(first_card)
		and int(reduced_state.get("registered_card_count", 0)) == expected_first_page_cards
	)

	game.progress_store.progress["reduced_motion_enabled"] = false
	_append_runtime_mock_topics(game, MOCK_TOPIC_COUNT)
	game._show_topics()
	await process_frame
	var initial_pager: Dictionary = game.topic_pager_controller.debug_state()
	var page_count := int(initial_pager.get("page_count", 0))
	var lazy_initial := (
		page_count >= 4
		and int(initial_pager.get("rendered_page_count", 0)) <= 2
		and int(initial_pager.get("rendered_page_count", 0)) < page_count
	)
	var blank_point := Vector2(5.0, game.get_viewport_rect().size.y - 5.0)
	game.topic_pager_controller.begin_drag(blank_point)
	game.topic_pager_controller.drag_by(Vector2(-game.get_viewport_rect().size.x * 0.5, 0.0), 0.7)
	var midpoint_state: Dictionary = game.topic_pager_controller.debug_state()
	var visual_page := float(midpoint_state.get("visual_page", -1.0))
	var first_page: Control = game.topic_pager_controller.rendered_pages.get(0, null)
	var next_page: Control = game.topic_pager_controller.rendered_pages.get(1, null)
	var midpoint_held := (
		bool(midpoint_state.get("drag_active", false))
		and absf(visual_page - 0.5) <= 0.02
		and _page_is_between_states(first_page)
		and _page_is_between_states(next_page)
	)
	game.topic_pager_controller.end_drag(blank_point)
	game.topic_pager_controller.go_to_page(2, false)
	var centered_pager: Dictionary = game.topic_pager_controller.debug_state()
	var centered_motion: Dictionary = game.topic_home_motion.debug_state()
	var lazy_centered := (
		int(centered_pager.get("current_page", -1)) == 2
		and int(centered_pager.get("rendered_page_count", 0)) <= 3
		and int(centered_pager.get("rendered_page_count", 0)) < page_count
		and int(centered_motion.get("registered_card_count", 0)) == int(centered_pager.get("rendered_card_count", -1))
	)
	game.topic_pager_controller.go_to_page(page_count - 1, false)
	var edge_pager: Dictionary = game.topic_pager_controller.debug_state()
	var edge_motion: Dictionary = game.topic_home_motion.debug_state()
	var lazy_edge := (
		int(edge_pager.get("rendered_page_count", 0)) <= 2
		and int(edge_motion.get("registered_card_count", 0)) == int(edge_pager.get("rendered_card_count", -1))
	)
	var tap_item := _first_item_on_page(game, page_count - 1)
	var tap_point := Vector2.ZERO
	if not tap_item.is_empty():
		var tap_rect: Rect2 = tap_item.get("rect", Rect2())
		tap_point = tap_rect.get_center() + game.topic_pager_controller.track.position
	game.topic_pager_controller.begin_drag(tap_point)
	game.topic_pager_controller.end_drag(tap_point)
	var activation_waits_for_release: bool = game.current_screen == "topics"
	var activation_started_state: Dictionary = game.topic_home_motion.debug_state()
	var activation_started_pager: Dictionary = game.topic_pager_controller.debug_state()
	await create_timer(0.30).timeout
	var activation_completed: bool = game.current_screen == "levels"
	var activation_finished_state: Dictionary = game.topic_home_motion.debug_state()

	var result := {
		"ok": (
			entrance_registered
			and entrance_staggered
			and entrance_settled
			and decorations_settled
			and press_feedback
			and press_restored
			and progress_detected
			and progress_finished
			and reduced_motion_ok
			and lazy_initial
			and midpoint_held
			and lazy_centered
			and lazy_edge
			and activation_waits_for_release
			and activation_completed
		),
		"entrance_registered": entrance_registered,
		"entrance_staggered": entrance_staggered,
		"entrance_settled": entrance_settled,
		"decorations_settled": decorations_settled,
		"press_feedback": press_feedback,
		"press_restored": press_restored,
		"progress_detected": progress_detected,
		"progress_finished": progress_finished,
		"reduced_motion_ok": reduced_motion_ok,
		"page_count": page_count,
		"initial_rendered_pages": initial_pager.get("rendered_pages", []),
		"midpoint_visual_page": snappedf(visual_page, 0.001),
		"midpoint_held": midpoint_held,
		"centered_rendered_pages": centered_pager.get("rendered_pages", []),
		"edge_rendered_pages": edge_pager.get("rendered_pages", []),
		"lazy_initial": lazy_initial,
		"lazy_centered": lazy_centered,
		"lazy_edge": lazy_edge,
		"activation_waits_for_release": activation_waits_for_release,
		"activation_completed": activation_completed,
		"activation_started_pending": activation_started_state.get("activation_pending", false),
		"activation_finished_pending": activation_finished_state.get("activation_pending", false),
		"activation_pressed_topic": activation_started_pager.get("pressed_topic_id", ""),
	}
	print("TOPIC_HOME_MOTION %s" % JSON.stringify(result))
	game.queue_free()
	await process_frame
	_remove_test_save()
	quit(0 if bool(result["ok"]) else 1)


func _topic_card(game: Node, topic_id: String) -> Control:
	if game.topics_content == null:
		return null
	return game.topics_content.find_child("theme_card_%s" % topic_id, true, false) as Control


func _card_is_settled(card: Control) -> bool:
	return (
		card != null
		and card.scale.is_equal_approx(Vector2.ONE)
		and is_equal_approx(card.modulate.a, 1.0)
	)


func _page_is_between_states(page: Control) -> bool:
	return (
		page != null
		and page.scale.x > 0.965
		and page.scale.x < 1.0
		and page.modulate.a > 0.72
		and page.modulate.a < 1.0
	)


func _decorations_are_settled(page: Control) -> bool:
	if page == null or page.get_child_count() == 0:
		return false
	for card_value in page.get_children():
		var card := card_value as Control
		var decoration: Control = card.get_node_or_null("theme_card_decoration") if card != null else null
		if decoration == null or not is_equal_approx(decoration.modulate.a, 1.0) or not is_zero_approx(decoration.rotation):
			return false
	return true


func _first_completion(game: Node, topic: Dictionary) -> Dictionary:
	for level_value in topic.get("levels", []):
		if typeof(level_value) != TYPE_DICTIONARY:
			continue
		var level: Dictionary = level_value
		var modes: Array[String] = game._available_modes_for_level(level)
		if modes.is_empty():
			continue
		return {"level_id": str(level.get("id", "")), "mode": modes[0]}
	return {}


func _append_runtime_mock_topics(game: Node, count: int) -> void:
	var template: Dictionary = game.topics[0]
	for index in count:
		var topic: Dictionary = template.duplicate(true)
		topic["id"] = "motion_test_mock_%d" % index
		topic["name"] = "Motion Test %d" % index
		game.topics.append(topic)


func _first_item_on_page(game: Node, page_index: int) -> Dictionary:
	for item_value in game.topics_island_items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		if int(item.get("page_index", -1)) == page_index:
			return item
	return {}


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
