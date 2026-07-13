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
	var shared_background_path := str(first_topic.get("level_background", ""))
	var shared_background_ok := (
		not shared_background_path.is_empty()
		and shared_background_path.get_extension().to_lower() == "webp"
		and FileAccess.file_exists(game.repository.image_file_path(shared_background_path))
	)
	var cover_path := str(first_topic.get("cover", ""))
	var card_back_path := str(first_topic.get("card_back", ""))
	var shanhai_webp_media_ok := (
		cover_path.get_extension().to_lower() == "webp"
		and card_back_path.get_extension().to_lower() == "webp"
		and FileAccess.file_exists(game.repository.image_file_path(cover_path))
		and FileAccess.file_exists(game.repository.image_file_path(card_back_path))
	)
	var raw_catalog: Dictionary = game.repository.load_config_path(game.repository.LEVEL_CATALOG_PATH)
	var topic_media_ok: bool = not raw_catalog.get("topics", []).is_empty() and shared_background_ok and shanhai_webp_media_ok
	for topic_data in raw_catalog.get("topics", []):
		if typeof(topic_data) == TYPE_DICTIONARY and topic_data.has("island"):
			topic_media_ok = false
			break
	var legacy_topic := first_topic.duplicate(true)
	legacy_topic["id"] = "legacy_topic_without_cover"
	legacy_topic["cover"] = ""
	legacy_topic["island"] = str(first_topic.get("cover", ""))
	var legacy_card = game._theme_card(legacy_topic, 960.0, 1.0)
	var no_cover_fallback: bool = legacy_card.find_child("theme_card_cover", true, false) is Panel and legacy_card.find_child("theme_card_cover_art", true, false) == null
	legacy_card.queue_free()
	topic_media_ok = topic_media_ok and no_cover_fallback
	print("TOPIC_MEDIA %s" % JSON.stringify({"ok": topic_media_ok, "no_cover_fallback": no_cover_fallback, "shared_background": shared_background_path, "cover": cover_path, "card_back": card_back_path, "topics": game.topics.size()}))
	all_ok = all_ok and topic_media_ok
	var title_layout_result := _topic_title_layout_probe(game)
	print("TOPIC_TITLE_LAYOUT %s" % JSON.stringify(title_layout_result))
	all_ok = all_ok and bool(title_layout_result.get("ok", false))
	var theme_header_result := await _theme_header_style_probe(game)
	print("THEME_HEADER_STYLE %s" % JSON.stringify(theme_header_result))
	all_ok = all_ok and bool(theme_header_result.get("ok", false))
	var level_focus_result := await _level_list_focus_probe(game, first_topic)
	print("LEVEL_LIST_FOCUS %s" % JSON.stringify(level_focus_result))
	all_ok = all_ok and bool(level_focus_result.get("ok", false))
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
		and thumbnail_image.get_width() <= game.LEVEL_LIST_THUMBNAIL_SIZE.x
		and thumbnail_image.get_height() <= game.LEVEL_LIST_THUMBNAIL_SIZE.y
	)
	print("LEVEL_THUMBNAIL %s" % JSON.stringify({"ok": thumbnail_ok, "path": thumbnail_path, "source": source_path}))
	all_ok = all_ok and thumbnail_ok
	var largest_topic := first_topic
	for topic in game.topics:
		if topic.get("levels", []).size() > largest_topic.get("levels", []).size():
			largest_topic = topic
	game._show_levels(largest_topic)
	await process_frame
	await process_frame
	var total_cards: int = game.level_virtual_items.size()
	var initial_indices: Array = game.level_virtual_nodes.keys()
	initial_indices.sort()
	var initial_count: int = initial_indices.size()
	var texture_sizes_ok := _visible_thumbnail_sizes_fit(game)
	game._scroll_topics_to(game._topics_max_scroll())
	await process_frame
	await process_frame
	var final_indices: Array = game.level_virtual_nodes.keys()
	final_indices.sort()
	var virtualized_ok: bool = (
		total_cards == largest_topic.get("levels", []).size()
		and initial_count > 0
		and initial_count < total_cards
		and final_indices.size() > 0
		and final_indices.size() < total_cards
		and initial_indices != final_indices
		and texture_sizes_ok
	)
	game._show_topics()
	await process_frame
	await process_frame
	var released_ok: bool = game.level_virtual_items.is_empty() and game.level_virtual_nodes.is_empty()
	var virtualization_result := {
		"ok": virtualized_ok and released_ok,
		"total": total_cards,
		"initial_loaded": initial_count,
		"final_loaded": final_indices.size(),
		"texture_sizes": texture_sizes_ok,
		"released": released_ok,
	}
	print("LEVEL_LIST_VIRTUALIZATION %s" % JSON.stringify(virtualization_result))
	all_ok = all_ok and bool(virtualization_result["ok"])
	game._show_levels(first_topic)
	await process_frame
	var locked_card = game._level_grid_card(first_topic, first_level, false, 300.0, 1.0)
	var locked_back = locked_card.find_child("level_card_back", true, false)
	var locked_card_ok: bool = (
		locked_back is TextureRect
		and locked_back.material is ShaderMaterial
		and locked_card.find_child("level_card_overlay", true, false) == null
	)
	print("LOCKED_CARD %s" % JSON.stringify({
		"ok": locked_card_ok,
		"rounded": locked_back is TextureRect and locked_back.material is ShaderMaterial,
		"has_modes": locked_card.find_child("level_card_overlay", true, false) != null,
	}))
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
		var active_background_value = game.active_level_config.get("background", {})
		var active_background: Dictionary = active_background_value if typeof(active_background_value) == TYPE_DICTIONARY else {}
		var shared_game_background: bool = (
			str(active_background.get("type", "")) == "image"
			and str(active_background.get("path", "")) == shared_background_path
		)
		var tray_border = game.puzzle_board.tray_top_border
		var tray_style_ok: bool = tray_border == null if play_mode == "swap" else (
			tray_border != null
			and is_instance_valid(tray_border)
			and tray_border.name == "tray_top_border"
			and is_equal_approx(tray_border.size.y, game.puzzle_board.TRAY_TOP_BORDER_HEIGHT)
		)
		var line_frame_ok := true
		if play_mode != "swap":
			var world_root = game.puzzle_board.world_root
			var line_frame = world_root.get_node_or_null("board_line_frame") if world_root != null else null
			var frame_style = line_frame.get_theme_stylebox("panel") if line_frame is Panel else null
			line_frame_ok = (
				line_frame is Panel
				and frame_style is StyleBoxFlat
				and frame_style.bg_color.a <= 0.001
				and frame_style.shadow_size == 0
				and world_root.get_node_or_null("board_outline_shadow") == null
				and world_root.get_node_or_null("board_target_area") == null
			)
		var back_button = game.screen_root.find_child("game_back_button", true, false)
		var hint_button = game.screen_root.find_child("game_hint_button", true, false)
		var title_left = game.screen_root.find_child("topic_title_decoration_left", true, false)
		var title_right = game.screen_root.find_child("topic_title_decoration_right", true, false)
		var interface_style_ok := (
			_outline_only_button(back_button)
			and _outline_only_button(hint_button)
			and title_left is TextureRect
			and title_right is TextureRect
			and line_frame_ok
		)
		var loaded: bool = (
			game.current_screen == "game"
			and game.current_mode == play_mode
			and game.puzzle_board.should_persist_state()
			and shared_game_background
			and tray_style_ok
			and interface_style_ok
		)
		game.puzzle_board.debug_force_complete()
		await process_frame
		var modal_visible: bool = game.modal_open and _tree_has_text(game.modal_root, game._t("complete"))
		var completed: bool = game.progress_store.is_done(str(game.current_level.get("id", "")), play_mode)
		var state_cleared: bool = game.progress_store.play_state(game.current_topic, game.current_level, play_mode).is_empty()
		var result := {
			"mode": play_mode,
			"loaded": loaded,
			"shared_background": shared_game_background,
			"tray_top_border": tray_style_ok,
			"line_frame": line_frame_ok,
			"line_buttons_and_title": interface_style_ok,
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


func _level_list_focus_probe(game, topic: Dictionary) -> Dictionary:
	var original_progress: Dictionary = game.progress_store.progress.duplicate(true)
	var playable: Array[Dictionary] = []
	var levels: Array = topic.get("levels", [])
	for index in levels.size():
		var level: Dictionary = levels[index]
		var modes: Array[String] = game._available_modes_for_level(level)
		if not modes.is_empty():
			playable.append({"index": index, "level": level, "modes": modes})
	if playable.size() < 2:
		return {"ok": false, "reason": "not_enough_playable_levels"}
	var first: Dictionary = playable[0]
	var target: Dictionary = playable[mini(8, playable.size() - 1)]
	var first_level: Dictionary = first["level"]
	var target_level: Dictionary = target["level"]
	var first_id := str(first_level.get("id", ""))
	var target_id := str(target_level.get("id", ""))
	var topic_id := str(topic.get("id", ""))
	game.progress_store.progress = {
		"last_topic_id": topic_id,
		"last_level_id": target_id,
		"last_mode": str((target["modes"] as Array[String])[0]),
	}
	var stale_last_falls_back: bool = game._level_list_focus_level_id(topic) == first_id
	var target_mode := str((target["modes"] as Array[String])[0])
	game.progress_store.progress["play_states"] = {
		game.progress_store.play_state_key(topic, target_level, target_mode): {"started": true},
	}
	var current_focuses_target: bool = game._level_list_focus_level_id(topic) == target_id
	game._show_levels(topic, game._level_list_focus_level_id(topic))
	await process_frame
	await process_frame
	var target_index := int(target["index"])
	var target_positioned: bool = game.topics_scroll_offset > 0.0 and game.level_virtual_nodes.has(target_index)
	var completed: Dictionary = {}
	for play_mode in first["modes"]:
		completed["%s:%s" % [first_id, game.progress_store.mode_key(str(play_mode))]] = true
	game.progress_store.progress = {"completed": completed}
	var next_id := str((playable[1]["level"] as Dictionary).get("id", ""))
	var first_unfinished_after_complete: bool = game._level_list_focus_level_id(topic) == next_id
	game.progress_store.progress = original_progress
	game._show_topics()
	await process_frame
	return {
		"ok": stale_last_falls_back and current_focuses_target and target_positioned and first_unfinished_after_complete,
		"stale_last_falls_back": stale_last_falls_back,
		"current_focuses_target": current_focuses_target,
		"target_positioned": target_positioned,
		"first_unfinished_after_complete": first_unfinished_after_complete,
		"first": first_id,
		"current": target_id,
		"next_unfinished": next_id,
	}


func _outline_only_button(value) -> bool:
	if not value is Button:
		return false
	var style = value.get_theme_stylebox("normal")
	return (
		style is StyleBoxFlat
		and style.bg_color.a <= 0.001
		and style.border_width_left > 0
		and style.border_width_top > 0
		and style.border_width_right > 0
		and style.border_width_bottom > 0
		and style.shadow_size == 0
	)


func _icon_uses_color(value, expected: Color) -> bool:
	if not value is TextureRect or not value.material is ShaderMaterial:
		return false
	var actual = value.material.get_shader_parameter("icon_color")
	return typeof(actual) == TYPE_COLOR and actual.is_equal_approx(expected)


func _theme_header_style_probe(game) -> Dictionary:
	var details: Array[Dictionary] = []
	var all_ok := true
	for topic in game.topics:
		var palette: Dictionary = game._topic_ui_palette(topic)
		var foreground: Color = palette.foreground
		var outline: Color = palette.outline
		var assets_value = topic.get("ui_assets", {})
		var assets: Dictionary = assets_value if typeof(assets_value) == TYPE_DICTIONARY else {}
		var has_title_decoration := not str(assets.get("title_mountains", "")).is_empty()
		game._show_levels(topic)
		await process_frame
		var level_topbar: Control = game.screen_root.get_node_or_null("level_list_topbar")
		var level_back: Button = level_topbar.get_node_or_null("level_list_back_button") if level_topbar != null else null
		var level_back_style = level_back.get_theme_stylebox("normal") if level_back != null else null
		var level_back_icon: TextureRect = level_back.get_node_or_null("level_list_back_icon") if level_back != null else null
		var level_title: Label = level_topbar.get_node_or_null("level_list_title") if level_topbar != null else null
		var level_left = level_topbar.get_node_or_null("topic_title_decoration_left") if level_topbar != null else null
		var level_right = level_topbar.get_node_or_null("topic_title_decoration_right") if level_topbar != null else null
		var level_decorations_match: bool = (
			(level_left is TextureRect and level_right is TextureRect) == has_title_decoration
		)
		var level_ok: bool = (
			level_back_style is StyleBoxFlat
			and level_back_style.border_color.is_equal_approx(outline)
			and _icon_uses_color(level_back_icon, foreground)
			and level_title != null
			and level_title.get_theme_color("font_color").is_equal_approx(foreground)
			and level_topbar.get_node_or_null("level_list_title_panel") == null
			and level_decorations_match
		)
		game._clear_ui()
		game.current_topic = topic
		game.current_mode = "polygon"
		game._build_game_hud("Header")
		await process_frame
		var game_back: Button = game.screen_root.find_child("game_back_button", true, false)
		var hint_button: Button = game.screen_root.find_child("game_hint_button", true, false)
		var game_title: Label = game.screen_root.find_child("game_title", true, false)
		var game_back_style = game_back.get_theme_stylebox("normal") if game_back != null else null
		var hint_style = hint_button.get_theme_stylebox("normal") if hint_button != null else null
		var game_back_icon: TextureRect = game_back.get_child(0) if game_back != null and game_back.get_child_count() > 0 else null
		var hint_icon: TextureRect = hint_button.get_child(0) if hint_button != null and hint_button.get_child_count() > 0 else null
		var game_left = game.screen_root.find_child("topic_title_decoration_left", true, false)
		var game_right = game.screen_root.find_child("topic_title_decoration_right", true, false)
		var game_decorations_match: bool = (
			(game_left is TextureRect and game_right is TextureRect) == has_title_decoration
		)
		var game_ok: bool = (
			game_back_style is StyleBoxFlat
			and game_back_style.border_color.is_equal_approx(outline)
			and hint_style is StyleBoxFlat
			and hint_style.border_color.is_equal_approx(outline)
			and _icon_uses_color(game_back_icon, foreground)
			and _icon_uses_color(hint_icon, foreground)
			and game_title != null
			and game_title.get_theme_color("font_color").is_equal_approx(foreground)
			and game_decorations_match
		)
		var topic_ok := level_ok and game_ok
		details.append({
			"topic": str(topic.get("id", "")),
			"level_header": level_ok,
			"game_header": game_ok,
			"has_decoration": has_title_decoration,
		})
		all_ok = all_ok and topic_ok
	game._show_topics()
	await process_frame
	return {"ok": all_ok, "topics": details}


func _topic_title_layout_probe(game) -> Dictionary:
	var parent := Control.new()
	game.screen_root.add_child(parent)
	var title := Label.new()
	title.text = "羲和浴日"
	title.add_theme_font_size_override("font_size", 38)
	parent.add_child(title)
	game._add_topic_title_decorations(parent, title, game._game_top_bar_height(), -1.0, 0.0, Vector2.ZERO, -1.0, game.topics[0])
	var left: TextureRect = parent.get_node_or_null("topic_title_decoration_left")
	var right: TextureRect = parent.get_node_or_null("topic_title_decoration_right")
	var font := title.get_theme_font("font")
	var text_width: float = font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title.get_theme_font_size("font_size")).x
	var center_x: float = game.get_viewport_rect().size.x * 0.5
	var text_left: float = center_x - text_width * 0.5
	var text_right: float = center_x + text_width * 0.5
	var left_gap: float = text_left - left.get_rect().end.x if left != null else -INF
	var right_gap: float = right.position.x - text_right if right != null else -INF
	var result := {
		"ok": left != null and right != null and left_gap >= 15.5 and right_gap >= 15.5,
		"title": title.text,
		"text_width": text_width,
		"left_gap": left_gap,
		"right_gap": right_gap,
	}
	parent.queue_free()
	return result


func _tree_has_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text == expected:
		return true
	if node is Button and (node as Button).text == expected:
		return true
	for child in node.get_children():
		if _tree_has_text(child, expected):
			return true
	return false


func _visible_thumbnail_sizes_fit(game) -> bool:
	var found := false
	for card in game.level_virtual_nodes.values():
		if not is_instance_valid(card):
			continue
		var cover := (card as Node).find_child("level_card_cover", true, false)
		if not cover is TextureRect or cover.texture == null:
			continue
		found = true
		if cover.texture.get_width() > game.LEVEL_LIST_THUMBNAIL_SIZE.x:
			return false
		if cover.texture.get_height() > game.LEVEL_LIST_THUMBNAIL_SIZE.y:
			return false
	return found


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
