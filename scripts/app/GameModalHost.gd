extends RefCounted
class_name GameModalHost


func show(game: Node, shade_color := Color(0, 0, 0, 0.42), blur_background := false) -> void:
	game._stop_complete_confetti()
	for child in game.modal_root.get_children():
		if not child.is_queued_for_deletion():
			child.queue_free()
	game.modal_open = true
	game.modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.name = "ModalShade"
	shade.color = shade_color
	if blur_background:
		shade.color = Color.WHITE
		shade.material = blur_material(shade_color)
	shade.modulate.a = 0.0
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.modal_root.add_child(shade)
	if game._ui_motion_reduced():
		shade.modulate.a = 1.0
		return
	var tween: Tween = game.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(shade, "modulate:a", 1.0, 0.14)


func blur_material(tint: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.16, 0.11, 0.08, 0.78);
uniform float blur_lod = 3.2;

void fragment() {
	vec4 blurred = textureLod(screen_texture, SCREEN_UV, blur_lod);
	COLOR = mix(blurred, vec4(tint.rgb, 1.0), tint.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", tint)
	return material


func box(
	game: Node,
	size: Vector2,
	bg_color := Color("#FFF6E6"),
	padding := 52.0,
	close_action := Callable(),
) -> VBoxContainer:
	var panel := Panel.new()
	panel.name = "ModalPanel"
	panel.custom_minimum_size = size
	panel.clip_contents = false
	panel.z_index = 2
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color("#E4B77F")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 34
	style.corner_radius_top_right = 34
	style.corner_radius_bottom_left = 34
	style.corner_radius_bottom_right = 34
	style.shadow_color = Color(0.28, 0.16, 0.07, 0.20)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	game.modal_root.add_child(panel)
	game._animate_modal_panel(panel)
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = padding
	content.offset_top = padding
	content.offset_right = -padding
	content.offset_bottom = -padding
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	if close_action.is_valid():
		panel.add_child(close_button(game, close_action))
	return content


func close_button(game: Node, action: Callable) -> Button:
	var button := Button.new()
	button.text = "×"
	button.custom_minimum_size = Vector2(84, 84)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -100
	button.offset_top = 12
	button.offset_right = -18
	button.offset_bottom = 96
	button.add_theme_font_size_override("font_size", 52)
	button.add_theme_color_override("font_color", game.soft_brown)
	button.add_theme_color_override("font_hover_color", game.deep_orange)
	button.add_theme_color_override("font_pressed_color", game.deep_orange)
	button.add_theme_color_override("font_focus_color", game.brown)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(action)
	game._wire_button_animation(button)
	return button


func mode_box(game: Node, size: Vector2) -> VBoxContainer:
	var panel := Panel.new()
	panel.custom_minimum_size = size
	panel.clip_contents = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#FFF8EC")
	style.border_color = Color("#E7B47E")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 36
	style.corner_radius_top_right = 36
	style.corner_radius_bottom_left = 36
	style.corner_radius_bottom_right = 36
	style.shadow_color = Color(0.36, 0.20, 0.08, 0.16)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	game.modal_root.add_child(panel)
	game._animate_modal_panel(panel)
	panel.add_child(mode_close_button(game))
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	var horizontal_padding: float = game.mode_select_modal._mode_dialog_horizontal_padding(size.x)
	content.offset_left = horizontal_padding
	content.offset_top = 66
	content.offset_right = -horizontal_padding
	content.offset_bottom = -52
	content.add_theme_constant_override("separation", 24)
	panel.add_child(content)
	return content


func mode_close_button(game: Node) -> Button:
	var button := Button.new()
	button.text = "×"
	button.custom_minimum_size = Vector2(104, 104)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -126
	button.offset_top = 14
	button.offset_right = -22
	button.offset_bottom = 118
	button.add_theme_font_size_override("font_size", 68)
	button.add_theme_color_override("font_color", game.brown)
	button.add_theme_color_override("font_hover_color", game.deep_orange)
	button.add_theme_color_override("font_pressed_color", game.deep_orange)
	var normal: StyleBoxFlat = game._rounded_panel_style(Color(1.0, 0.98, 0.93, 0.0), 52)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.93, 0.82, 0.78)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover.duplicate())
	button.add_theme_stylebox_override("focus", normal.duplicate())
	button.add_theme_stylebox_override("disabled", normal.duplicate())
	button.pressed.connect(Callable(game, "_close_modal"))
	game._wire_button_animation(button)
	return button


func title(game: Node, text: String, font_size := 44) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.y = 70
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", game.brown)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func close(game: Node) -> void:
	game._stop_complete_confetti()
	game.modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.modal_open = false
	for child in game.modal_root.get_children():
		if child.is_queued_for_deletion():
			continue
		if game._ui_motion_reduced() or not child is Control:
			child.queue_free()
			continue
		var control := child as Control
		var tween: Tween = game.create_tween().bind_node(control).set_parallel(true)
		tween.tween_property(control, "modulate:a", 0.0, 0.14).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		if control.name == "ModalPanel":
			control.pivot_offset = control.size * 0.5
			tween.tween_property(control, "scale", Vector2(0.98, 0.98), 0.14).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.chain().tween_callback(control.queue_free)
