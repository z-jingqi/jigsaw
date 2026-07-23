extends RefCounted
class_name GameModalHost

const MODAL_SHELL_SCENE := preload("res://scenes/ui/AnimatedModalShell.tscn")

var shell


func show(game: Node, shade_color := Color(0, 0, 0, 0.42), blur_background := false) -> void:
	game._stop_complete_confetti()
	var active = _live_shell()
	if active == null:
		for child in game.modal_root.get_children():
			if not child.is_queued_for_deletion():
				child.queue_free()
		active = MODAL_SHELL_SCENE.instantiate()
		game.modal_root.add_child(active)
		active.closed.connect(Callable(self, "_on_shell_closed").bind(game))
		shell = active
	else:
		active.prepare_reuse()
	game.modal_open = true
	game.modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	active.configure_shade(shade_color, blur_material(shade_color) if blur_background else null)


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
	var active = _ensure_shell(game)
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
	var content: VBoxContainer = active.configure_panel(size, style, Vector4(padding, padding, padding, padding))
	content.add_theme_constant_override("separation", 18)
	if close_action.is_valid():
		active.panel.add_child(close_button(game, close_action))
	active.play_open(game._ui_motion_reduced())
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
	var active = _live_shell()
	if active != null:
		active.play_close(game._ui_motion_reduced())
	else:
		for child in game.modal_root.get_children():
			if not child.is_queued_for_deletion():
				child.queue_free()


func reset() -> void:
	var active = _live_shell()
	if active != null:
		active.dispose()
	shell = null


func active_motion_count() -> int:
	var active = _live_shell()
	return active.active_motion_count() if active != null else 0


func debug_state() -> Dictionary:
	var active = _live_shell()
	return active.debug_state() if active != null else {
		"phase": "none",
		"active_motion_count": 0,
	}


func _ensure_shell(game: Node):
	var active = _live_shell()
	if active == null:
		show(game)
		active = _live_shell()
	return active


func _live_shell():
	if shell == null or not is_instance_valid(shell) or shell.is_queued_for_deletion():
		shell = null
		return null
	return shell


func _on_shell_closed(closed_shell, game: Node) -> void:
	if shell == closed_shell:
		shell = null
	if is_instance_valid(game) and game.modal_root != null:
		game.modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
