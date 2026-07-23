class_name GameplayScreen
extends Control

signal back_requested()
signal hint_requested()
signal move_swap_up_requested()
signal move_swap_down_requested()

@onready var back_button: Button = $Hud/BackButton
@onready var title_label: Label = $Hud/Title
@onready var hint_button: Button = $Hud/HintButton
@onready var tray_view: Control = $BottomHost/TrayView
@onready var swap_action_bar: SwapActionBarView = $BottomHost/SwapActionBar

var _view_model: Variant
var _input_live := false
var _layout_scale := 1.0


func _ready() -> void:
	back_button.pressed.connect(back_requested.emit)
	hint_button.pressed.connect(hint_requested.emit)
	swap_action_bar.move_up_requested.connect(move_swap_up_requested.emit)
	swap_action_bar.move_down_requested.connect(move_swap_down_requested.emit)
	_set_input_live(false)


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	set_reduced_motion(bool(context.get("reduced_motion", false)))


func navigation_exit(_context: Dictionary) -> void:
	_set_input_live(false)


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	if not is_active:
		_set_input_live(false)


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if not is_node_ready():
		return
	title_label.text = str(_read("level_title", ""))
	var mode := String(_read("mode", ""))
	tray_view.visible = mode == "polygon" or mode == "knob"
	swap_action_bar.visible = mode == "swap"
	_apply_layout_scale(float(_read("ui_scale", 1.0)))
	var foreground: Color = _read("foreground", Color("#062F43"))
	title_label.add_theme_color_override("font_color", foreground)
	back_button.add_theme_color_override("font_color", foreground)
	back_button.add_theme_color_override("font_hover_color", foreground)
	hint_button.add_theme_color_override("font_color", foreground)
	hint_button.add_theme_color_override("font_hover_color", foreground)


func set_reduced_motion(_enabled: bool) -> void:
	# Fixed screen entrance is owned by the navigator transition; gameplay
	# interactions themselves remain deterministic regardless of this preference.
	pass


func mark_board_live() -> void:
	_set_input_live(true)


func board_reserved_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for control in [back_button, hint_button, swap_action_bar]:
		if control.visible:
			result.append(control.get_global_rect())
	return result


func tray_rect() -> Rect2:
	return tray_view.get_global_rect() if tray_view.visible else Rect2()


func top_reserved_height() -> float:
	return $Hud.size.y


func _apply_layout_scale(value: float) -> void:
	_layout_scale = maxf(1.0, value)
	var hud_height := 64.0 * _layout_scale
	var side_margin := 16.0 * _layout_scale
	var button_size := 44.0 * _layout_scale
	var button_top := 10.0 * _layout_scale
	$Hud.offset_bottom = hud_height
	back_button.offset_left = side_margin
	back_button.offset_top = button_top
	back_button.offset_right = side_margin + button_size
	back_button.offset_bottom = button_top + button_size
	hint_button.offset_left = -side_margin - button_size
	hint_button.offset_top = button_top
	hint_button.offset_right = -side_margin
	hint_button.offset_bottom = button_top + button_size
	title_label.offset_left = side_margin + button_size + 8.0 * _layout_scale
	title_label.offset_top = button_top
	title_label.offset_right = -side_margin - button_size - 8.0 * _layout_scale
	title_label.offset_bottom = button_top + button_size
	title_label.add_theme_font_size_override("font_size", roundi(20.0 * _layout_scale))
	back_button.add_theme_font_size_override("font_size", roundi(24.0 * _layout_scale))
	hint_button.add_theme_font_size_override("font_size", roundi(20.0 * _layout_scale))
	_configure_bottom_panel(tray_view, 112.0 * _layout_scale)
	_configure_bottom_panel(swap_action_bar, 88.0 * _layout_scale)
	var actions := swap_action_bar.get_node("Actions") as HBoxContainer
	actions.offset_top = 16.0 * _layout_scale
	actions.offset_bottom = -16.0 * _layout_scale
	actions.add_theme_constant_override("separation", roundi(12.0 * _layout_scale))


func _configure_bottom_panel(panel: Control, height: float) -> void:
	panel.custom_minimum_size.y = height
	panel.offset_top = -height
	panel.offset_bottom = 0.0


func bottom_reserved_height() -> float:
	if tray_view.visible:
		return tray_view.size.y
	if swap_action_bar.visible:
		return swap_action_bar.size.y
	return 0.0


func _set_input_live(enabled: bool) -> void:
	_input_live = enabled
	back_button.disabled = not enabled
	hint_button.disabled = not enabled
	swap_action_bar.set_actions_enabled(enabled)


func _read(field: String, fallback: Variant = null) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	if _view_model == null:
		return fallback
	var value: Variant = _view_model.get(field)
	return fallback if value == null else value
