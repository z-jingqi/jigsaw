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
		var topics_ok := _topic_page_fits(game.topics_island_items, viewport_size, game.topics.size()) and bool(topic_style.get("ok", false))
		var topic_rects := _grid_rect_summary(game.topics_island_items)
		var topic: Dictionary = game.topics[0] if not game.topics.is_empty() else {}
		game._show_levels(topic)
		await process_frame
		var level_topbar_style := _topic_level_topbar_style_check(game, topic, viewport_size)
		var levels_ok := _grid_starts_left_and_fits(game.topics_island_items, viewport_size) and bool(level_topbar_style.get("ok", false))
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
		var puzzle_layout := _puzzle_layout_check(game, viewport_size)
		var swap_level_index := _level_index_for_mode(game, topic, "swap")
		game.debug_enter_level(swap_level_index, "swap")
		await process_frame
		var swap_actions := _swap_action_layout_check(game, viewport_size)
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
			"level_topbar_style": level_topbar_style,
			"settings": settings_ok,
			"settings_rects": settings_rects,
			"modes": modes_ok,
			"mode_rects": mode_rects,
			"puzzle_layout": puzzle_layout,
			"swap_actions": swap_actions,
			"complete": complete_ok,
			"complete_rects": complete_rects,
		}
		result["ok"] = topics_ok and levels_ok and settings_ok and modes_ok and bool(puzzle_layout.get("ok", false)) and bool(swap_actions.get("ok", false)) and complete_ok
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


func _topic_page_fits(items: Array, viewport_size: Vector2, topic_count: int) -> bool:
	var expected_count := mini(4, topic_count)
	var current_page_items: Array = []
	for item in items:
		if int(item.get("page_index", 0)) == 0:
			current_page_items.append(item)
	if current_page_items.size() != expected_count:
		return false
	for item in current_page_items:
		var rect: Rect2 = item.get("rect", Rect2())
		if rect.position.x < -1.0 or rect.end.x > viewport_size.x + 1.0:
			return false
		if rect.position.y < -1.0 or rect.end.y > viewport_size.y + 1.0:
			return false
		if absf(rect.get_center().x - viewport_size.x * 0.5) > 1.0:
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
	var card: Control = game.topics_content.find_child("theme_card_*", true, false) if game.topics_content != null else null
	var aspect := 0.0 if card == null or card.size.x <= 0.0 else card.size.y / card.size.x
	var cover: Control = card.get_node_or_null("theme_card_cover") if card != null else null
	var base: Control = card.get_node_or_null("theme_card_base") if card != null else null
	var title: Label = card.get_node_or_null("theme_card_title") if card != null else null
	var compact_card := aspect >= 0.435 and aspect <= 0.445
	var uses_topic_background := base is TextureRect and (base as TextureRect).texture != null
	var localized_title := title != null and not title.text.is_empty() and title.text == str(game.topics[0].get("name", ""))
	var no_level_count_label := card != null and not _contains_level_count_label(card)
	var no_badge_or_arrow := card != null and card.get_node_or_null("theme_card_percent_badge") == null and card.get_node_or_null("theme_card_arrow_button") == null
	var first_page: Control = game.topic_pager_controller.rendered_pages.get(0, null)
	var all_covers_present: bool = first_page != null and first_page.get_child_count() == mini(game.topic_pager_controller.PAGE_SIZE, game.topics.size())
	var all_decorations_present := all_covers_present
	if all_covers_present and first_page != null:
		for candidate in first_page.get_children():
			var candidate_cover = candidate.get_node_or_null("theme_card_cover")
			if not candidate_cover is TextureRect or not _cover_has_left_only_rounding(candidate_cover as TextureRect):
				all_covers_present = false
				break
			var candidate_decoration = candidate.get_node_or_null("theme_card_decoration")
			if not candidate_decoration is TextureRect or (candidate_decoration as TextureRect).texture == null:
				all_decorations_present = false
	var pager_state: Dictionary = game.topic_pager_controller.debug_state()
	var single_page_lazy := int(pager_state.get("page_count", 0)) == 1 and int(pager_state.get("rendered_page_count", 0)) == 1
	var progress_capsules := _progress_capsule_style_check(game)
	var pager_capsule := _pager_capsule_style_check(game)
	var result := {
		"settings_right": settings_right,
		"single_topbar_button": topbar_button_count == 1,
		"logo_centered": logo_centered,
		"card_aspect": snappedf(aspect, 0.001),
		"compact_card": compact_card,
		"uses_topic_background": uses_topic_background,
		"localized_title": localized_title,
		"no_level_count_label": no_level_count_label,
		"no_badge_or_arrow": no_badge_or_arrow,
		"all_covers_present": all_covers_present,
		"all_decorations_present": all_decorations_present,
		"single_page_lazy": single_page_lazy,
		"progress_capsules": progress_capsules,
		"pager_capsule": pager_capsule,
	}
	result["ok"] = settings_right and topbar_button_count == 1 and logo_centered and compact_card and uses_topic_background and localized_title and no_level_count_label and no_badge_or_arrow and all_covers_present and all_decorations_present and single_page_lazy and progress_capsules and pager_capsule
	return result


func _cover_has_left_only_rounding(cover: TextureRect) -> bool:
	if cover == null or cover.texture == null:
		return false
	var image := cover.texture.get_image()
	if image == null or image.is_empty():
		return false
	var right := image.get_width() - 1
	var bottom := image.get_height() - 1
	return (
		image.get_pixel(0, 0).a <= 0.05
		and image.get_pixel(0, bottom).a <= 0.05
		and image.get_pixel(right, 0).a >= 0.95
		and image.get_pixel(right, bottom).a >= 0.95
	)


func _progress_capsule_style_check(game) -> bool:
	var sample: Panel = game._topic_progress_bar(1, 100, Vector2(100.0, 10.0), Color("#E57A16"))
	var fill: Panel = sample.get_node_or_null("progress_fill")
	var full_sample: Panel = game._topic_progress_bar(100, 100, Vector2(100.0, 10.0), Color("#E57A16"))
	var full_fill: Panel = full_sample.get_node_or_null("progress_fill")
	var track_style = sample.get_theme_stylebox("panel")
	var fill_style = fill.get_theme_stylebox("panel") if fill != null else null
	var valid := (
		fill != null
		and full_fill != null
		and fill.visible
		and fill.size.x >= sample.size.y
		and fill.size.x <= sample.size.x
		and is_equal_approx(full_fill.size.x, full_sample.size.x)
		and _is_capsule_style(track_style, sample.size.y)
		and _is_capsule_style(fill_style, sample.size.y)
	)
	sample.free()
	full_sample.free()
	return valid


func _pager_capsule_style_check(game) -> bool:
	var indicator: Panel = game.screen_root.get_node_or_null("topic_pager_indicator")
	var thumb: Panel = indicator.get_node_or_null("topic_pager_thumb") if indicator != null else null
	return (
		indicator != null
		and thumb != null
		and _is_capsule_style(indicator.get_theme_stylebox("panel"), indicator.size.y)
		and _is_capsule_style(thumb.get_theme_stylebox("panel"), thumb.size.y)
	)


func _is_capsule_style(style, height: float) -> bool:
	if not style is StyleBoxFlat:
		return false
	var minimum_radius := ceili(height * 0.5)
	return (
		style.corner_radius_top_left >= minimum_radius
		and style.corner_radius_top_right >= minimum_radius
		and style.corner_radius_bottom_left >= minimum_radius
		and style.corner_radius_bottom_right >= minimum_radius
		and style.corner_detail >= 12
		and style.anti_aliasing
	)


func _level_index_for_mode(game, topic: Dictionary, play_mode: String) -> int:
	var levels: Array = topic.get("levels", [])
	for index in levels.size():
		if game._available_modes_for_level(levels[index]).has(play_mode):
			return index
	return 0


func _topic_level_topbar_style_check(game, topic: Dictionary, viewport_size: Vector2) -> Dictionary:
	var topbar: Control = game.screen_root.get_node_or_null("level_list_topbar")
	var back: Button = topbar.get_node_or_null("level_list_back_button") if topbar != null else null
	var back_icon: TextureRect = back.get_node_or_null("level_list_back_icon") if back != null else null
	var title: Label = topbar.get_node_or_null("level_list_title") if topbar != null else null
	var left: TextureRect = topbar.get_node_or_null("topic_title_decoration_left") if topbar != null else null
	var right: TextureRect = topbar.get_node_or_null("topic_title_decoration_right") if topbar != null else null
	var progress: Control = topbar.get_node_or_null("level_list_progress") if topbar != null else null
	var progress_bar: Panel = progress.get_node_or_null("level_list_progress_bar") if progress != null else null
	var progress_label: Label = progress.get_node_or_null("level_list_progress_label") if progress != null else null
	var back_style = back.get_theme_stylebox("normal") if back != null else null
	var palette: Dictionary = game._topic_ui_palette(topic)
	var rounded_outline: bool = (
		back_style is StyleBoxFlat
		and back_style.bg_color.a <= 0.001
		and back_style.border_color.is_equal_approx(palette.outline)
		and back_style.border_width_left > 0
		and back_style.shadow_size == 0
		and back_style.corner_radius_top_left >= int(back.size.x * 0.15)
		and back_style.corner_radius_top_left <= int(back.size.x * 0.35)
	)
	var title_unframed: bool = title != null and topbar.get_node_or_null("level_list_title_panel") == null
	var back_icon_fills_button: bool = back_icon != null and back_icon.size.y >= back.size.y * 0.58 and back_icon.size.y <= back.size.y * 0.62 and back_icon.texture is AtlasTexture
	var theme_colors: bool = (
		title != null
		and title.get_theme_color("font_color").is_equal_approx(palette.foreground)
		and back_icon != null
		and back_icon.material is ShaderMaterial
		and typeof(back_icon.material.get_shader_parameter("icon_color")) == TYPE_COLOR
		and back_icon.material.get_shader_parameter("icon_color").is_equal_approx(palette.foreground)
	)
	var progress_unframed: bool = progress != null and not progress is Panel and progress_bar != null and progress_label != null
	var progress_stacked_centered: bool = (
		progress_bar != null
		and progress_label != null
		and progress_label.get_rect().end.y <= progress_bar.position.y
		and absf(progress_label.get_rect().get_center().x - progress_bar.get_rect().get_center().x) <= 1.0
	)
	var decorations_present: bool = left != null and right != null and left.texture != null and right.texture != null
	var separated: bool = (
		back != null
		and left != null
		and right != null
		and progress != null
		and back.get_global_rect().end.x < left.get_global_rect().position.x
		and right.get_global_rect().end.x < progress.get_global_rect().position.x
		and progress.get_global_rect().end.x <= viewport_size.x + 1.0
	)
	var assets_value = topic.get("ui_assets", {})
	var asset_path := str((assets_value as Dictionary).get("title_mountains", "")) if typeof(assets_value) == TYPE_DICTIONARY else ""
	var theme_local_asset := asset_path.begins_with("res://levels/topic_01/ui/")
	var result := {
		"rounded_outline_back": rounded_outline,
		"back_icon_fills_button": back_icon_fills_button,
		"theme_colors": theme_colors,
		"title_unframed": title_unframed,
		"progress_unframed": progress_unframed,
		"progress_stacked_centered": progress_stacked_centered,
		"decorations_present": decorations_present,
		"separated": separated,
		"theme_local_asset": theme_local_asset,
	}
	result["ok"] = rounded_outline and back_icon_fills_button and theme_colors and title_unframed and progress_unframed and progress_stacked_centered and decorations_present and separated and theme_local_asset
	return result


func _puzzle_layout_check(game, viewport_size: Vector2) -> Dictionary:
	var board = game.puzzle_board
	var board_rect := Rect2(
		board._world_to_screen(board.board_origin),
		board.source_size * board.source_scale * board.view_scale,
	)
	var play_area: Rect2 = board._world_view_screen_rect()
	var left_gap := board_rect.position.x - play_area.position.x
	var right_gap := play_area.end.x - board_rect.end.x
	var top_gap := board_rect.position.y - play_area.position.y
	var bottom_gap := play_area.end.y - board_rect.end.y
	var expected_tray_top: float = board._tray_area().position.y
	var keeps_aspect := absf(
		board_rect.size.x / maxf(1.0, board_rect.size.y)
		- board.source_size.x / maxf(1.0, board.source_size.y)
	) <= 0.001
	var no_overlap := (
		board_rect.position.y >= play_area.position.y - 0.75
		and board_rect.end.y <= play_area.end.y + 0.75
		and board_rect.position.x >= play_area.position.x - 0.75
		and board_rect.end.x <= play_area.end.x + 0.75
	)
	var result := {
		"board": [roundi(board_rect.position.x), roundi(board_rect.position.y), roundi(board_rect.size.x), roundi(board_rect.size.y)],
		"play_area": [roundi(play_area.position.x), roundi(play_area.position.y), roundi(play_area.size.x), roundi(play_area.size.y)],
		"left_gap": snappedf(left_gap, 0.01),
		"right_gap": snappedf(right_gap, 0.01),
		"top_gap": snappedf(top_gap, 0.01),
		"bottom_gap": snappedf(bottom_gap, 0.01),
		"horizontal_centered": absf(left_gap - right_gap) <= 0.75,
		"vertical_centered": absf(top_gap - bottom_gap) <= 0.75,
		"minimum_phone_side_gap": left_gap >= board.BOARD_SCREEN_EDGE_GAP - 0.75 and right_gap >= board.BOARD_SCREEN_EDGE_GAP - 0.75,
		"header_excluded": absf(play_area.position.y - game._game_top_bar_height()) <= 0.75,
		"tray_excluded": absf(play_area.end.y - expected_tray_top) <= 0.75,
		"keeps_aspect": keeps_aspect,
		"no_overlap": no_overlap,
		"viewport_matches": absf(play_area.size.x - viewport_size.x) <= 0.75,
	}
	result["ok"] = (
		result["horizontal_centered"]
		and result["vertical_centered"]
		and result["minimum_phone_side_gap"]
		and result["header_excluded"]
		and result["tray_excluded"]
		and result["keeps_aspect"]
		and result["no_overlap"]
		and result["viewport_matches"]
	)
	return result


func _swap_action_layout_check(game, viewport_size: Vector2) -> Dictionary:
	var bar: Control = game.screen_root.find_child("game_bottom_actions", true, false)
	var row: HBoxContainer = game.screen_root.find_child("game_bottom_actions_row", true, false)
	var board = game.puzzle_board
	var bar_rect := bar.get_global_rect() if bar != null else Rect2()
	var row_rect := row.get_global_rect() if row != null else Rect2()
	var expected_names: Array[String] = [
		"game_shift_up_button",
		"game_shift_down_button",
	]
	var names_match := row != null and row.get_child_count() == expected_names.size()
	if names_match:
		for index in expected_names.size():
			if row.get_child(index).name != expected_names[index]:
				names_match = false
				break
	var centered := row != null and absf(row_rect.get_center().x - viewport_size.x * 0.5) <= 1.0
	var fits_width := row != null and row_rect.position.x >= -0.75 and row_rect.end.x <= viewport_size.x + 0.75
	var pinned_bottom := bar != null and absf(bar_rect.end.y - viewport_size.y) <= 1.0
	var board_excludes_actions: bool = bar != null and board._world_view_screen_rect().end.y <= bar_rect.position.y + 0.75
	var topbar: Control = game.screen_root.find_child("game_topbar", true, false)
	var back_button: Button = game.screen_root.find_child("game_back_button", true, false)
	var hint_button: Button = game.screen_root.find_child("game_hint_button", true, false)
	var top_actions_restored := (
		topbar != null
		and back_button != null
		and hint_button != null
		and back_button.get_parent() == topbar
		and hint_button.get_parent() == topbar
		and game.screen_root.find_child("game_restart_button", true, false) == null
	)
	var result := {
		"names": names_match,
		"centered": centered,
		"fits_width": fits_width,
		"pinned_bottom": pinned_bottom,
		"board_excludes_actions": board_excludes_actions,
		"top_actions_restored": top_actions_restored,
		"bar": [roundi(bar_rect.position.x), roundi(bar_rect.position.y), roundi(bar_rect.size.x), roundi(bar_rect.size.y)],
		"row": [roundi(row_rect.position.x), roundi(row_rect.position.y), roundi(row_rect.size.x), roundi(row_rect.size.y)],
	}
	result["ok"] = names_match and centered and fits_width and pinned_bottom and board_excludes_actions and top_actions_restored
	return result


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
