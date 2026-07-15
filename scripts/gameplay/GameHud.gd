extends RefCounted
class_name GameHud

var game: Node


func _init(owner: Node) -> void:
	game = owner


func build(level_title: String) -> void:
	var ui_scale: float = game._topics_ui_scale()
	var viewport_width: float = game.get_viewport_rect().size.x
	var bar_height: float = top_bar_height()
	var title_height: float = 52.0 * ui_scale
	var top: float = 20.0 * ui_scale
	var palette: Dictionary = game._topic_ui_palette(game.current_topic)
	var foreground: Color = palette.foreground
	var top_bar := Control.new()
	top_bar.name = "game_topbar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 0
	top_bar.offset_top = 0
	top_bar.offset_right = 0
	top_bar.offset_bottom = bar_height
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(top_bar)
	var title := Label.new()
	title.name = "game_title"
	title.text = level_title
	title.position = Vector2(viewport_width * 0.28, top)
	title.size = Vector2(viewport_width * 0.44, title_height)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.add_theme_font_size_override("font_size", int(28.0 * ui_scale))
	title.add_theme_color_override("font_color", foreground)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(title)
	var title_font := title.get_theme_font("font")
	var title_font_size := title.get_theme_font_size("font_size")
	var title_text_width := title_font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_font_size).x
	var decoration_gap: float = 6.0 * ui_scale
	var decoration_width := minf(
		42.0 * ui_scale,
		viewport_width * 0.5 - title_text_width * 0.5 - decoration_gap - 20.0 * ui_scale,
	)
	add_topic_title_decorations(
		top_bar,
		title,
		title_height,
		viewport_width * 0.5,
		top,
		Vector2(maxf(20.0 * ui_scale, decoration_width), 26.0 * ui_scale),
		decoration_gap,
		game.current_topic,
	)
	var bottom_bar := Control.new()
	bottom_bar.name = "game_bottom_actions"
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_left = 0.0
	bottom_bar.offset_top = -bottom_bar_height()
	bottom_bar.offset_right = 0.0
	bottom_bar.offset_bottom = 0.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(bottom_bar)
	var center := CenterContainer.new()
	center.name = "game_bottom_actions_center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 0.0
	center.offset_top = 0.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(center)
	var actions := HBoxContainer.new()
	actions.name = "game_bottom_actions_row"
	actions.add_theme_constant_override("separation", roundi(clampf(8.0 * ui_scale, 10.0, 24.0)))
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(actions)
	var restart_action := func() -> void:
		game._show_game(game.current_topic, game.current_level, game.current_mode, true)
	var action_specs: Array[Dictionary] = [
		{"name": "game_back_button", "text": game._t("back"), "action": Callable(game, "_return_to_current_level_list")},
		{"name": "game_restart_button", "text": game._t("restart"), "action": restart_action},
		{"name": "game_hint_button", "text": game._t("hint"), "action": game.puzzle_board.show_hint},
	]
	if game.current_mode == "swap":
		action_specs.append({"name": "game_shift_up_button", "text": game._t("shift_row_up"), "action": game.puzzle_board.shift_swap_rows_up})
		action_specs.append({"name": "game_shift_down_button", "text": game._t("shift_row_down"), "action": game.puzzle_board.shift_swap_rows_down})
	game.hud_blocker_controls.clear()
	game.hud_blocker_controls.append(top_bar)
	game.hud_blocker_controls.append(bottom_bar)
	for spec in action_specs:
		var button := bottom_action_button(str(spec["text"]), spec["action"], ui_scale)
		button.name = str(spec["name"])
		actions.add_child(button)
	queue_drag_blocker_refresh()


func topic_ui_asset_texture(topic: Dictionary, key: String) -> Texture2D:
	var assets_value = topic.get("ui_assets", {})
	if typeof(assets_value) != TYPE_DICTIONARY:
		return null
	var assets := assets_value as Dictionary
	var path := str(assets.get(key, ""))
	var texture: Texture2D = game.repository.cached_texture(path) if not path.is_empty() else null
	var region_value = assets.get("%s_region" % key, [])
	if texture == null or typeof(region_value) != TYPE_ARRAY or region_value.size() != 4:
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		float(region_value[0]),
		float(region_value[1]),
		float(region_value[2]),
		float(region_value[3]),
	)
	return atlas


func add_topic_title_decorations(
	parent: Control,
	title: Label,
	bar_height: float,
	requested_center_x := -1.0,
	top_offset := 0.0,
	requested_size := Vector2.ZERO,
	requested_gap := -1.0,
	topic_override: Dictionary = {},
) -> void:
	var asset_topic: Dictionary = topic_override if not topic_override.is_empty() else game.current_topic
	var texture := topic_ui_asset_texture(asset_topic, "title_side")
	if texture == null:
		texture = topic_ui_asset_texture(asset_topic, "title_mountains")
	if texture == null:
		return
	var viewport_width: float = game.get_viewport_rect().size.x
	var decoration_size: Vector2 = requested_size if requested_size != Vector2.ZERO else Vector2(clampf(viewport_width * 0.11, 104.0, 136.0), 42.0)
	var font := title.get_theme_font("font")
	var font_size := title.get_theme_font_size("font_size")
	var measured_title_width := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var title_width := maxf(88.0, measured_title_width)
	var gap: float = requested_gap if requested_gap >= 0.0 else 16.0
	var center_x: float = requested_center_x if requested_center_x >= 0.0 else viewport_width * 0.5
	var top := top_offset + (bar_height - decoration_size.y) * 0.5
	var left := topic_title_decoration(texture, false, decoration_size)
	left.name = "topic_title_decoration_left"
	left.position = Vector2(center_x - title_width * 0.5 - gap - decoration_size.x, top)
	parent.add_child(left)
	var right := topic_title_decoration(texture, true, decoration_size)
	right.name = "topic_title_decoration_right"
	right.position = Vector2(center_x + title_width * 0.5 + gap, top)
	parent.add_child(right)
	var ear_texture := topic_ui_asset_texture(asset_topic, "title_ear")
	if ear_texture != null:
		add_topic_title_ears(
			parent,
			ear_texture,
			center_x,
			title_width,
			font_size,
			bar_height,
			top_offset,
			decoration_size,
		)


func add_topic_title_ears(
	parent: Control,
	texture: Texture2D,
	center_x: float,
	title_width: float,
	font_size: float,
	bar_height: float,
	top_offset: float,
	decoration_size: Vector2,
) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var ear_height := minf(decoration_size.y * 0.55, font_size * 0.48)
	var ear_width := ear_height * texture_size.x / texture_size.y
	var ear_size := Vector2(ear_width, ear_height)
	var ear_top := top_offset + (bar_height - font_size) * 0.5 - ear_height
	var ear_center_distance := maxf(ear_width + 2.0, title_width * 0.65)
	var left := topic_title_decoration(texture, false, ear_size)
	left.name = "topic_title_ear_left"
	left.position = Vector2(center_x - ear_center_distance * 0.5 - ear_width * 0.5, ear_top)
	parent.add_child(left)
	var right := topic_title_decoration(texture, true, ear_size)
	right.name = "topic_title_ear_right"
	right.position = Vector2(center_x + ear_center_distance * 0.5 - ear_width * 0.5, ear_top)
	parent.add_child(right)


func topic_title_decoration(texture: Texture2D, flipped: bool, size: Vector2) -> TextureRect:
	var decoration := TextureRect.new()
	decoration.texture = texture
	decoration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	decoration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	decoration.flip_h = flipped
	decoration.size = size
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return decoration


func top_bar_height() -> float:
	return game._theme_topbar_height(game._topics_ui_scale())


func bottom_bar_height() -> float:
	return maxf(72.0, 56.0 * game._topics_ui_scale())


func bottom_action_button(text: String, action: Callable, ui_scale: float) -> Button:
	var button: Button = game._tool_text_button(text, action)
	var font_size := roundi(clampf(18.0 * ui_scale, 22.0, 32.0))
	button.add_theme_font_size_override("font_size", font_size)
	var font: Font = button.get_theme_font("font")
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	button.custom_minimum_size = Vector2(
		ceilf(text_width + clampf(12.0 * ui_scale, 20.0, 32.0)),
		maxf(48.0, 30.0 * ui_scale),
	)
	return button


func text_button_width(text: String) -> float:
	return maxf(20.0, float(text.length()) * game.HUD_TEXT_BUTTON_FONT_SIZE * 0.9)


func text_button_height() -> float:
	return float(game.HUD_TEXT_BUTTON_FONT_SIZE) + 8.0


func queue_drag_blocker_refresh() -> void:
	game.call_deferred("_refresh_game_drag_blockers")


func refresh_drag_blockers() -> void:
	if game.current_screen != "game" or game.puzzle_board == null:
		return
	var blockers: Array[Rect2] = []
	for control in game.hud_blocker_controls:
		if not is_instance_valid(control) or not control.visible:
			continue
		var rect := Rect2(control.global_position, control.size).grow(game.HUD_BLOCKER_PADDING)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			blockers.append(rect)
	game.puzzle_board.set_drag_blockers(blockers)
