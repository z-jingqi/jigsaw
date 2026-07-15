extends RefCounted
class_name GameUiFactory


func highlight_button_bounds(game: Node, button: BaseButton) -> void:
	if not game.BUTTON_BOUNDS_DEBUG or button == null or not is_instance_valid(button):
		return
	if button.has_node("button_bounds_debug"):
		return
	var overlay := ColorRect.new()
	overlay.name = "button_bounds_debug"
	overlay.color = game.BUTTON_BOUNDS_DEBUG_COLOR
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 4096
	button.add_child(overlay)
	overlay.move_to_front()


func screen_margin(game: Node) -> float:
	var width: float = game.get_viewport_rect().size.x
	if width < 430.0:
		return 16.0
	if width < 700.0:
		return 24.0
	return 36.0


func icon_button(
	game: Node,
	icon: Texture2D,
	action: Callable,
	button_size: float,
	icon_inset: float,
	subtle_shadow := false,
	transparent := false,
	normal_icon_color := Color("#8A6847"),
	hover_icon_color := Color("#C77C2E"),
	outline_only := false,
	outline_color := Color("#879174"),
) -> Button:
	var button := Button.new()
	button.text = ""
	var icon_size := Vector2(button_size, button_size)
	button.custom_minimum_size = icon_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if transparent:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	elif outline_only:
		var normal := outline_icon_style(button_size, outline_color)
		button.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate()
		hover.bg_color = Color(outline_color, 0.08)
		button.add_theme_stylebox_override("hover", hover)
		var pressed := normal.duplicate()
		pressed.bg_color = Color(outline_color, 0.14)
		button.add_theme_stylebox_override("pressed", pressed)
		for state in ["disabled", "focus"]:
			button.add_theme_stylebox_override(state, normal.duplicate())
	elif show_hud_debug_measurements(game):
		apply_debug_control_background(button, Color(0.18, 0.52, 0.95, 0.24))
	else:
		var normal := round_icon_style(Color(1.0, 0.96, 0.88, 0.92), button_size, subtle_shadow)
		button.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate()
		hover.bg_color = Color("#FFF2D8")
		button.add_theme_stylebox_override("hover", hover)
		var pressed := normal.duplicate()
		pressed.bg_color = Color("#F8E7C7")
		button.add_theme_stylebox_override("pressed", pressed)
		for state in ["disabled", "focus"]:
			button.add_theme_stylebox_override(state, normal.duplicate())
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(button_size - icon_inset * 2.0, button_size - icon_inset * 2.0)
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = icon_inset
	icon_rect.offset_top = icon_inset
	icon_rect.offset_right = -icon_inset
	icon_rect.offset_bottom = -icon_inset
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_material: ShaderMaterial = game._icon_tint_material(normal_icon_color)
	icon_rect.material = icon_material
	button.add_child(icon_rect)
	button.mouse_entered.connect(func() -> void:
		icon_material.set_shader_parameter("icon_color", hover_icon_color)
	)
	button.mouse_exited.connect(func() -> void:
		icon_material.set_shader_parameter("icon_color", normal_icon_color)
	)
	button.button_down.connect(func() -> void:
		icon_material.set_shader_parameter("icon_color", hover_icon_color)
	)
	button.button_up.connect(func() -> void:
		icon_material.set_shader_parameter("icon_color", normal_icon_color)
	)
	button.pressed.connect(action)
	game._wire_button_animation(button)
	return button


func outline_icon_style(button_size: float, outline_color := Color("#879174")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = outline_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	var radius := int(button_size * 0.18)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func round_icon_style(bg_color: Color, button_size: float, subtle_shadow := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.72, 0.50, 0.27, 0.20)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = int(button_size * 0.5)
	style.corner_radius_top_right = int(button_size * 0.5)
	style.corner_radius_bottom_left = int(button_size * 0.5)
	style.corner_radius_bottom_right = int(button_size * 0.5)
	style.shadow_color = Color(0.42, 0.24, 0.07, 0.06 if subtle_shadow else 0.14)
	style.shadow_size = 2 if subtle_shadow else 5
	style.shadow_offset = Vector2(0, 1 if subtle_shadow else 2)
	return style


func rounded_panel_style(bg_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func capsule_panel_style(bg_color: Color, height: float) -> StyleBoxFlat:
	var radius := maxi(1, ceili(height * 0.5))
	var style := rounded_panel_style(bg_color, radius)
	style.corner_detail = 12
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	return style


func tool_text_button(game: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(game._hud_text_button_width(text), game._hud_text_button_height())
	button.add_theme_font_size_override("font_size", game.HUD_TEXT_BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", game.soft_brown)
	button.add_theme_color_override("font_hover_color", game.deep_orange)
	button.add_theme_color_override("font_pressed_color", game.deep_orange)
	if show_hud_debug_measurements(game):
		apply_debug_control_background(button, Color(0.95, 0.56, 0.18, 0.24))
	else:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(action)
	game._wire_button_animation(button)
	return button


func show_hud_debug_measurements(game: Node) -> bool:
	return game.HUD_DEBUG_MEASUREMENTS and game.current_screen == "game"


func apply_debug_control_background(control: Control, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = Color(0.22, 0.13, 0.04, 0.9)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	control.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "pressed", "disabled", "focus"]:
		control.add_theme_stylebox_override(state, normal.duplicate())


func mode_state_icon(game: Node, play_mode: String, state: String, size: float) -> Control:
	var rect := TextureRect.new()
	rect.texture = mode_icon_texture(game, play_mode, state == "done")
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state == "active":
		var dot_size := size * 0.36
		var dot := Panel.new()
		dot.position = Vector2(size - dot_size * 0.80, size - dot_size * 0.80)
		dot.size = Vector2(dot_size, dot_size)
		var dot_style := rounded_panel_style(game.orange, int(dot_size * 0.5))
		dot_style.border_color = Color.WHITE
		dot_style.border_width_left = 2
		dot_style.border_width_top = 2
		dot_style.border_width_right = 2
		dot_style.border_width_bottom = 2
		dot.add_theme_stylebox_override("panel", dot_style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(dot)
	return rect


func level_display_title(level: Dictionary) -> String:
	var title := str(level.get("title", "")).strip_edges()
	return str(level.get("id", "")) if title.is_empty() else title


func empty_level_message(game: Node) -> Label:
	var label := Label.new()
	label.text = game._t("no_levels")
	label.custom_minimum_size = Vector2(380, 110)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", game.soft_brown)
	return label


func empty_topic_message(game: Node) -> Label:
	var label := Label.new()
	label.text = game._t("no_topics")
	label.custom_minimum_size = Vector2(380, 160)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", game.soft_brown)
	return label


func topic_color(game: Node, topic: Dictionary) -> Color:
	var value := str(topic.get("color", "#D9933F"))
	return Color(value) if value.begins_with("#") else game.orange


func topic_ui_palette(game: Node, topic: Dictionary) -> Dictionary:
	var base_color := topic_color(game, topic)
	var defaults := {
		"surface": Color("#FFF4DE").lerp(base_color, 0.14),
		"foreground": base_color.darkened(0.62),
		"outline": base_color.darkened(0.20),
		"accent": base_color,
	}
	var raw = topic.get("ui_palette", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return defaults
	var palette: Dictionary = raw
	return {
		"surface": topic_ui_color(palette, "surface", defaults.surface),
		"foreground": topic_ui_color(palette, "foreground", defaults.foreground),
		"outline": topic_ui_color(palette, "outline", defaults.outline),
		"accent": topic_ui_color(palette, "accent", defaults.accent),
	}


func topic_ui_color(palette: Dictionary, key: String, fallback: Color) -> Color:
	var value := str(palette.get(key, ""))
	return Color.from_string(value, fallback) if not value.is_empty() else fallback


func topic_progress_bar(done: int, total: int, size: Vector2, fill_color: Color, track_color := Color(0.78, 0.64, 0.48, 0.22)) -> Panel:
	var bar_size := Vector2(maxf(0.0, size.x), maxf(0.0, size.y))
	var holder := Panel.new()
	holder.custom_minimum_size = bar_size
	holder.size = bar_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := capsule_panel_style(track_color, bar_size.y)
	holder.add_theme_stylebox_override("panel", track)
	var ratio := 0.0 if total <= 0 else clampf(float(done) / float(total), 0.0, 1.0)
	var fill := Panel.new()
	fill.name = "progress_fill"
	var proportional_width := bar_size.x * ratio
	var minimum_visible_width := minf(bar_size.x, bar_size.y)
	fill.size = Vector2(clampf(maxf(proportional_width, minimum_visible_width), 0.0, bar_size.x), bar_size.y) if ratio > 0.0 else Vector2(0.0, bar_size.y)
	fill.visible = ratio > 0.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := capsule_panel_style(fill_color, bar_size.y)
	fill.add_theme_stylebox_override("panel", fill_style)
	holder.add_child(fill)
	return holder


func status_icon(game: Node, mode: String, done: bool, size: float) -> Control:
	var rect := TextureRect.new()
	rect.texture = mode_icon_texture(game, mode, done)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func mode_icon_texture(game: Node, mode: String, done: bool) -> Texture2D:
	var key: String = game._mode_key(mode)
	if key == "polygon":
		return game.icon_mode_polygon_done if done else game.icon_mode_polygon_todo
	if key == "swap":
		return game.icon_mode_swap_done if done else game.icon_mode_swap_todo
	return game.icon_mode_knob_done if done else game.icon_mode_knob_todo


func mode_label(game: Node, mode: String) -> String:
	var key: String = game._mode_key(mode)
	if key == "polygon":
		return game._t("mode_polygon")
	if key == "swap":
		return game._t("mode_swap")
	return game._t("mode_knob")
