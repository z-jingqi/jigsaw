extends RefCounted
class_name GameDialogs

const ConfettiEffectScript := preload("res://scripts/effects/ConfettiEffect.gd")

var game: Node
var complete_confetti_layer: Control


func _init(owner: Node) -> void:
	game = owner


func show_settings() -> void:
	game._show_modal()
	var modal_size: Vector2 = responsive_modal_size(820.0, 760.0)
	var box: VBoxContainer = game._modal_box(modal_size, Color("#FFF8EC"), 54.0, Callable(game, "_close_modal"))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.add_child(game._modal_title(game._t("settings_title")))
	box.add_child(settings_row(
		game.modal_setting_vibration_texture,
		game._t("haptics"),
		game.progress_store.haptics_enabled(),
		func(enabled: bool) -> void:
			game.progress_store.set_haptics_enabled(enabled)
			game.puzzle_board.set_feedback_preferences(enabled, game.progress_store.reduced_motion_enabled(), game.progress_store.edge_contrast_mode())
	))
	box.add_child(modal_separator())
	box.add_child(settings_row(
		game.modal_setting_music_texture,
		game._t("music"),
		game.progress_store.music_enabled(),
		func(enabled: bool) -> void: game.progress_store.set_music_enabled(enabled)
	))
	box.add_child(modal_separator())
	box.add_child(settings_row(
		game.modal_setting_sfx_texture,
		game._t("sfx"),
		game.progress_store.sound_effects_enabled(),
		func(enabled: bool) -> void: game.progress_store.set_sound_effects_enabled(enabled)
	))
	box.add_child(modal_action_button(game._t("settings_done"), Callable(game, "_close_modal"), true))


func show_tutorial() -> void:
	game._show_modal()
	var modal_size: Vector2 = responsive_modal_size(860.0, 820.0)
	var box: VBoxContainer = game._modal_box(modal_size, Color("#FFF8EC"), 54.0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	var tutorial_texture: Texture2D = game.modal_tutorial_drag_texture
	var tutorial_text: String = game._t("tutorial_drag")
	if game.current_mode == "swap":
		tutorial_texture = game.modal_tutorial_swap_texture
		tutorial_text = game._t("tutorial_swap")
	var art: TextureRect = tutorial_illustration(tutorial_texture, Vector2(modal_size.x - 108.0, 430.0))
	box.add_child(art)
	animate_tutorial_illustration(art)
	var text: Label = modal_body_label(tutorial_text, 27, game.soft_brown)
	text.custom_minimum_size.y = 64
	box.add_child(text)
	box.add_child(modal_action_button(game._t("got_it"), func() -> void:
		game.progress_store.mark_tutorial_seen(game.current_mode)
		game._close_modal()
	))


func show_complete() -> void:
	game._show_modal(Color(0.14, 0.09, 0.05, 0.72), true)
	var viewport_size: Vector2 = game.get_viewport_rect().size
	var description: String = level_description(game.current_level)
	var panel_width := minf(920.0, maxf(1.0, viewport_size.x - 96.0))
	var content_width := maxf(1.0, panel_width - 104.0)
	var image_height := minf(content_width * 4.0 / 3.0, viewport_size.y * 0.46)
	var description_height := 0.0 if description.is_empty() else 110.0
	var fixed_height := 74.0 + 60.0 + description_height + 84.0 + 184.0
	var max_panel_height := maxf(1.0, viewport_size.y - 96.0)
	var panel_height := image_height + fixed_height
	if panel_height > max_panel_height:
		image_height = maxf(280.0, image_height - (panel_height - max_panel_height))
		panel_height = image_height + fixed_height
	var box: VBoxContainer = game._modal_box(Vector2(panel_width, minf(panel_height, max_panel_height)), Color("#FFF8EC"), 52.0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	var title: Label = game._modal_title(game._t("complete"), 50)
	title.add_theme_color_override("font_color", game.orange)
	box.add_child(title)
	var completed_image: Control = complete_full_image(Vector2(content_width, image_height))
	box.add_child(completed_image)
	var level_name := Label.new()
	level_name.text = game._level_display_title(game.current_level)
	level_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_name.custom_minimum_size.y = 58
	level_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_name.add_theme_font_size_override("font_size", 36)
	level_name.add_theme_color_override("font_color", game.brown)
	level_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(level_name)
	var desc: Label = null
	if not description.is_empty():
		desc = Label.new()
		desc.text = description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(content_width, description_height)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc.add_theme_font_size_override("font_size", 23)
		desc.add_theme_color_override("font_color", game.soft_brown)
		desc.add_theme_constant_override("line_spacing", 5)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(desc)
	var button_holder := CenterContainer.new()
	button_holder.custom_minimum_size = Vector2(content_width, 84.0)
	var confirm: Button = modal_action_button(game._t("confirm"), func() -> void:
		game._close_modal()
		game._return_to_current_level_list()
	, true, Vector2(minf(420.0, content_width), 84.0))
	button_holder.add_child(confirm)
	box.add_child(button_holder)
	animate_completion_content(title, completed_image, level_name, desc, button_holder)
	start_complete_confetti()


func level_description(level: Dictionary) -> String:
	var description := str(level.get("description", "")).strip_edges()
	if not description.is_empty():
		return description
	var level_config: Dictionary = game.repository.load_level_config(level)
	return str(level_config.get("description", "")).strip_edges()


func complete_full_image(size: Vector2) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	var level_config: Dictionary = game.repository.load_level_config(game.current_level)
	var image_path: String = game.repository.level_image_path(level_config)
	var target_size := Vector2i(maxi(1, int(round(size.x))), maxi(1, int(round(size.y))))
	image.texture = game._rounded_complete_image_texture(image_path, target_size, 28)
	if image.texture == null:
		image.texture = game.texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(image)
	return holder


func responsive_modal_size(max_width: float, desired_height: float) -> Vector2:
	var viewport_size: Vector2 = game.get_viewport_rect().size
	var margin := maxf(32.0, minf(56.0, viewport_size.x * 0.05))
	return Vector2(
		minf(max_width, maxf(1.0, viewport_size.x - margin * 2.0)),
		minf(desired_height, maxf(1.0, viewport_size.y - margin * 2.0))
	)


func modal_action_button(
	text: String,
	action: Callable,
	primary := true,
	min_size := Vector2(0, 82),
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color.WHITE if primary else game.brown)
	button.add_theme_color_override("font_hover_color", Color.WHITE if primary else game.deep_orange)
	button.add_theme_color_override("font_pressed_color", Color.WHITE if primary else game.deep_orange)
	button.add_theme_color_override("font_focus_color", Color.WHITE if primary else game.brown)
	var normal: StyleBoxFlat = game._rounded_panel_style(game.orange if primary else Color("#FFFDF7"), 22)
	if primary:
		normal.shadow_color = Color(0.42, 0.24, 0.07, 0.18)
		normal.shadow_size = 7
		normal.shadow_offset = Vector2(0, 3)
	else:
		normal.border_color = Color(game.soft_brown, 0.28)
		normal.border_width_left = 2
		normal.border_width_top = 2
		normal.border_width_right = 2
		normal.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = game.deep_orange if primary else Color("#FFF3DE")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = game.deep_orange.darkened(0.05) if primary else Color("#F8E7C7")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal.duplicate())
	button.pressed.connect(action)
	game._wire_button_animation(button)
	return button


func modal_body_label(text: String, font_size := 25, color := Color("#8A6847")) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func modal_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.custom_minimum_size.y = 1
	var line := StyleBoxLine.new()
	line.color = Color(game.soft_brown, 0.18)
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	return separator


func settings_row(icon: Texture2D, label_text: String, enabled: bool, on_changed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 112
	row.add_theme_constant_override("separation", 22)
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(82, 82)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", game.brown)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	row.add_child(settings_toggle(enabled, on_changed))
	return row


func settings_toggle(enabled: bool, on_changed: Callable) -> Button:
	var toggle := Button.new()
	toggle.name = "SettingsToggle"
	toggle.text = ""
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.custom_minimum_size = Vector2(112, 62)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var thumb := Panel.new()
	thumb.name = "Thumb"
	thumb.custom_minimum_size = Vector2(46, 46)
	thumb.size = Vector2(46, 46)
	thumb.position = Vector2(58, 8) if enabled else Vector2(8, 8)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thumb_style: StyleBoxFlat = game._rounded_panel_style(Color("#FFFDF8"), 23)
	thumb_style.shadow_color = Color(0.24, 0.14, 0.07, 0.22)
	thumb_style.shadow_size = 4
	thumb_style.shadow_offset = Vector2(0, 2)
	thumb.add_theme_stylebox_override("panel", thumb_style)
	toggle.add_child(thumb)
	refresh_settings_toggle(toggle, enabled, false)
	toggle.toggled.connect(func(is_enabled: bool) -> void:
		refresh_settings_toggle(toggle, is_enabled, true)
		on_changed.call(is_enabled)
	)
	game._wire_button_animation(toggle)
	return toggle


func refresh_settings_toggle(toggle: Button, enabled: bool, animate: bool) -> void:
	var normal := settings_toggle_style(enabled)
	toggle.add_theme_stylebox_override("normal", normal)
	toggle.add_theme_stylebox_override("pressed", normal.duplicate())
	toggle.add_theme_stylebox_override("focus", normal.duplicate())
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.04)
	toggle.add_theme_stylebox_override("hover", hover)
	var thumb := toggle.get_node_or_null("Thumb") as Panel
	if thumb == null:
		return
	var target := Vector2(58, 8) if enabled else Vector2(8, 8)
	if not animate or game._ui_motion_reduced():
		thumb.position = target
		return
	var tween: Tween = game.create_tween().bind_node(toggle)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(thumb, "position", target, 0.18)


func settings_toggle_style(enabled: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = game._rounded_panel_style(game.green if enabled else Color("#D8CDBB"), 31)
	style.border_color = Color(game.brown, 0.12)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	return style


func tutorial_illustration(tutorial_texture: Texture2D, size: Vector2) -> TextureRect:
	var art := TextureRect.new()
	art.texture = tutorial_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func animate_tutorial_illustration(art: Control) -> void:
	if game._ui_motion_reduced():
		return
	await game.get_tree().process_frame
	if not is_instance_valid(art):
		return
	art.pivot_offset = art.size * 0.5
	var tween: Tween = game.create_tween().bind_node(art).set_loops()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(art, "scale", Vector2(1.015, 1.015), 0.9)
	tween.tween_property(art, "scale", Vector2.ONE, 0.9)


func animate_completion_content(
	title: Control,
	completed_image: Control,
	level_name: Control,
	description: Control,
	button_holder: Control,
) -> void:
	if game._ui_motion_reduced():
		return
	var controls: Array[Control] = [title, completed_image, level_name]
	if description != null:
		controls.append(description)
	controls.append(button_holder)
	for control in controls:
		control.modulate.a = 0.0
	await game.get_tree().process_frame
	if not is_instance_valid(completed_image):
		return
	completed_image.pivot_offset = completed_image.size * 0.5
	completed_image.scale = Vector2(0.975, 0.975)
	var tween: Tween = game.create_tween().set_parallel(true)
	for index in controls.size():
		var control := controls[index]
		tween.tween_property(control, "modulate:a", 1.0, 0.22).set_delay(0.08 + float(index) * 0.055).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(completed_image, "scale", Vector2.ONE, 0.28).set_delay(0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func start_complete_confetti() -> void:
	stop_complete_confetti()
	if game._ui_motion_reduced():
		return
	complete_confetti_layer = Control.new()
	complete_confetti_layer.name = "CompleteConfettiLayer"
	complete_confetti_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	complete_confetti_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	complete_confetti_layer.z_index = 1
	game.modal_root.add_child(complete_confetti_layer)
	complete_confetti_layer.add_child(ConfettiEffectScript.new())


func stop_complete_confetti() -> void:
	if complete_confetti_layer != null and is_instance_valid(complete_confetti_layer):
		if not complete_confetti_layer.is_queued_for_deletion():
			complete_confetti_layer.queue_free()
	complete_confetti_layer = null
