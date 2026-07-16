extends RefCounted
class_name SwapActionBar

var game: Node


func _init(owner: Node) -> void:
	game = owner


func build(ui_scale: float) -> Control:
	if game.current_mode != "swap":
		return null
	var bottom_bar := Control.new()
	bottom_bar.name = "game_bottom_actions"
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_left = 0.0
	bottom_bar.offset_top = -height()
	bottom_bar.offset_right = 0.0
	bottom_bar.offset_bottom = 0.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(bottom_bar)
	var center := CenterContainer.new()
	center.name = "game_bottom_actions_center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(center)
	var actions := HBoxContainer.new()
	actions.name = "game_bottom_actions_row"
	actions.add_theme_constant_override("separation", roundi(clampf(8.0 * ui_scale, 10.0, 24.0)))
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(actions)
	_add_action(actions, "game_shift_up_button", game._t("shift_row_up"), game.puzzle_board.shift_swap_rows_up, ui_scale)
	_add_action(actions, "game_shift_down_button", game._t("shift_row_down"), game.puzzle_board.shift_swap_rows_down, ui_scale)
	return bottom_bar


func height() -> float:
	return maxf(72.0, 56.0 * game._topics_ui_scale())


func _add_action(parent: Control, button_name: String, text: String, action: Callable, ui_scale: float) -> void:
	var button: Button = game._tool_text_button(text, action)
	button.name = button_name
	var font_size := roundi(clampf(18.0 * ui_scale, 22.0, 32.0))
	button.add_theme_font_size_override("font_size", font_size)
	var font: Font = button.get_theme_font("font")
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	button.custom_minimum_size = Vector2(
		ceilf(text_width + clampf(12.0 * ui_scale, 20.0, 32.0)),
		maxf(48.0, 30.0 * ui_scale),
	)
	parent.add_child(button)
