extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "user://jigcat_progress_responsive_test.json"
const PRESETS := [
	{"label": "iPhone SE", "size": Vector2i(750, 1334)},
	{"label": "iPhone 15", "size": Vector2i(1179, 2556)},
	{"label": "iPad mini", "size": Vector2i(1536, 2048)},
	{"label": "iPad Pro", "size": Vector2i(2048, 2732)},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_save()
	var all_ok := true
	for preset in PRESETS:
		root.size = preset["size"]
		var game = MAIN_SCENE.instantiate()
		game.progress_store.save_path = TEST_SAVE_PATH
		root.add_child(game)
		await process_frame
		await process_frame
		var viewport_size: Vector2 = game.get_viewport_rect().size
		var topic_style := _theme_list_style_check(game, viewport_size)
		var topics_ok := _grid_starts_left_and_fits(game.topics_island_items, viewport_size) and bool(topic_style.get("ok", false))
		var topic_rects := _grid_rect_summary(game.topics_island_items)
		var topic: Dictionary = game.topics[0] if not game.topics.is_empty() else {}
		game._show_levels(topic)
		await process_frame
		var levels_ok := _grid_starts_left_and_fits(game.topics_island_items, viewport_size)
		var level_rects := _grid_rect_summary(game.topics_island_items)
		game._show_settings_modal()
		await process_frame
		var settings_ok := _modal_content_fits(game.modal_root, viewport_size)
		var settings_rects := _modal_rect_summary(game.modal_root)
		game._close_modal()
		var level: Dictionary = topic.get("levels", [])[0] if not topic.get("levels", []).is_empty() else {}
		game._show_mode_dialog(level)
		await process_frame
		var modes_ok := _modal_content_fits(game.modal_root, viewport_size)
		var mode_rects := _modal_rect_summary(game.modal_root)
		game._close_modal()
		var polygon_level_index := _level_index_for_mode(game, topic, "polygon")
		game.debug_enter_level(polygon_level_index, "polygon")
		await process_frame
		game.debug_preview_complete()
		await process_frame
		var complete_ok := _modal_content_fits(game.modal_root, viewport_size)
		var complete_rects := _modal_rect_summary(game.modal_root)
		var result := {
			"preset": preset["label"],
			"window": [preset["size"].x, preset["size"].y],
			"viewport": [roundi(viewport_size.x), roundi(viewport_size.y)],
			"topics": topics_ok,
			"topic_rects": topic_rects,
			"topic_style": topic_style,
			"levels": levels_ok,
			"level_rects": level_rects,
			"settings": settings_ok,
			"settings_rects": settings_rects,
			"modes": modes_ok,
			"mode_rects": mode_rects,
			"complete": complete_ok,
			"complete_rects": complete_rects,
		}
		result["ok"] = topics_ok and levels_ok and settings_ok and modes_ok and complete_ok
		all_ok = all_ok and bool(result["ok"])
		print("RESPONSIVE_LAYOUT %s" % JSON.stringify(result))
		game.queue_free()
		await process_frame
	_remove_test_save()
	quit(0 if all_ok else 1)


func _grid_starts_left_and_fits(items: Array, viewport_size: Vector2) -> bool:
	if items.is_empty():
		return false
	var first_rect: Rect2 = items[0].get("rect", Rect2())
	if first_rect.position.x > viewport_size.x * 0.12:
		return false
	for item in items:
		var rect: Rect2 = item.get("rect", Rect2())
		if rect.position.x < -1.0 or rect.end.x > viewport_size.x + 1.0:
			return false
	return true


func _theme_list_style_check(game, viewport_size: Vector2) -> Dictionary:
	var topbar: Control = game.screen_root.get_node_or_null("theme_topbar")
	var settings: Control = topbar.get_node_or_null("theme_settings_button") if topbar != null else null
	var logo: Control = topbar.get_node_or_null("theme_logo") if topbar != null else null
	var topbar_button_count := 0
	if topbar != null:
		for child in topbar.get_children():
			if child is Button:
				topbar_button_count += 1
	var settings_right := settings != null and settings.position.x >= viewport_size.x * 0.70
	var logo_centered := logo != null and absf(logo.get_rect().get_center().x - viewport_size.x * 0.5) <= 2.0
	var card: Control = game.topics_content.get_child(0) if game.topics_content != null and game.topics_content.get_child_count() > 0 else null
	var aspect := 0.0 if card == null or card.size.x <= 0.0 else card.size.y / card.size.x
	var cover: Control = card.get_node_or_null("theme_card_cover") if card != null else null
	var badge: Control = card.get_node_or_null("theme_card_percent_badge") if card != null else null
	var title: Label = card.get_node_or_null("theme_card_title") if card != null else null
	var compact_card := aspect >= 0.275 and aspect <= 0.295
	var badge_in_info_column := cover != null and badge != null and badge.position.x >= cover.position.x + cover.size.x
	var localized_title := title != null and not title.text.is_empty() and title.text == str(game.topics[0].get("name", ""))
	var no_level_count_label := card != null and not _contains_level_count_label(card)
	var all_covers_present: bool = game.topics_content != null and game.topics_content.get_child_count() == game.topics.size()
	if all_covers_present:
		for candidate in game.topics_content.get_children():
			if not (candidate.get_node_or_null("theme_card_cover") is TextureRect):
				all_covers_present = false
				break
	var result := {
		"settings_right": settings_right,
		"single_topbar_button": topbar_button_count == 1,
		"logo_centered": logo_centered,
		"card_aspect": snappedf(aspect, 0.001),
		"compact_card": compact_card,
		"badge_in_info_column": badge_in_info_column,
		"localized_title": localized_title,
		"no_level_count_label": no_level_count_label,
		"all_covers_present": all_covers_present,
	}
	result["ok"] = settings_right and topbar_button_count == 1 and logo_centered and compact_card and badge_in_info_column and localized_title and no_level_count_label and all_covers_present
	return result


func _level_index_for_mode(game, topic: Dictionary, play_mode: String) -> int:
	var levels: Array = topic.get("levels", [])
	for index in levels.size():
		if game._available_modes_for_level(levels[index]).has(play_mode):
			return index
	return 0


func _contains_level_count_label(node: Node) -> bool:
	if node is Label:
		var text := (node as Label).text.to_lower()
		if "levels" in text or "关卡" in text:
			return true
	for child in node.get_children():
		if _contains_level_count_label(child):
			return true
	return false


func _modal_content_fits(modal: Control, viewport_size: Vector2) -> bool:
	var found := false
	for child in modal.get_children():
		if not child is Control or child is ColorRect:
			continue
		var control := child as Control
		var rect := control.get_global_rect()
		if rect.size.x < 100.0 or rect.size.y < 100.0:
			continue
		found = true
		if rect.position.x < -1.0 or rect.position.y < -1.0:
			return false
		if rect.end.x > viewport_size.x + 1.0 or rect.end.y > viewport_size.y + 1.0:
			return false
	return found


func _grid_rect_summary(items: Array) -> Array:
	var result := []
	for item in items:
		var rect: Rect2 = item.get("rect", Rect2())
		result.append([roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)])
	return result


func _modal_rect_summary(modal: Control) -> Array:
	var result := []
	for child in modal.get_children():
		if child is Control and not child is ColorRect:
			var rect := (child as Control).get_global_rect()
			if rect.size.x >= 100.0 and rect.size.y >= 100.0:
				result.append([child.get_class(), roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)])
	return result


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
