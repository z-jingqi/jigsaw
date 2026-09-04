class_name GameplayScreen
extends Control

signal back_requested
signal hint_requested
signal move_swap_up_requested
signal move_swap_down_requested

const GameplayLayoutScript := preload("res://scripts/screens/gameplay/GameplayLayout.gd")

@onready var back_button: ActionButton = $Hud/BackButton
@onready var title_label: Label = $Hud/Title
@onready var hint_button: ActionButton = $Hud/HintButton
@onready var back_shadow: TextureRect = $Hud/BackShadow
@onready var hint_shadow: TextureRect = $Hud/HintShadow
@onready var tray_view: Control = $BottomHost/TrayView
@onready var swap_action_bar: SwapActionBarView = $BottomHost/SwapActionBar

var _view_model: Variant
var _input_live := false
var _navigation_active := false
var _layout_scale := 1.0
var _layout := GameplayLayoutScript.new()


func _ready() -> void:
	back_button.pressed.connect(back_requested.emit)
	hint_button.pressed.connect(hint_requested.emit)
	swap_action_bar.move_up_requested.connect(move_swap_up_requested.emit)
	swap_action_bar.move_down_requested.connect(move_swap_down_requested.emit)
	resized.connect(_apply_current_layout)
	_set_input_live(false)
	_apply_current_layout()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	set_reduced_motion(bool(context.get("reduced_motion", false)))


func navigation_exit(_context: Dictionary) -> void:
	_set_input_live(false)


func navigation_set_active(is_active: bool) -> void:
	_navigation_active = is_active
	visible = is_active
	if not is_active:
		_set_input_live(false)
	else:
		back_button.disabled = false


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if not is_node_ready():
		return
	title_label.text = str(_read("level_title", ""))
	var mode := String(_read("mode", ""))
	tray_view.visible = mode == "polygon" or mode == "knob"
	swap_action_bar.visible = mode == "swap"
	_apply_layout_scale(float(_read("ui_scale", 1.0)))
	hint_button.visible = true
	hint_shadow.visible = true


func set_reduced_motion(enabled: bool) -> void:
	# Fixed screen entrance is owned by the navigator transition; gameplay
	# interactions themselves remain deterministic regardless of this preference.
	back_button.set_reduced_motion(enabled)
	hint_button.set_reduced_motion(enabled)
	swap_action_bar.set_reduced_motion(enabled)


func mark_board_live() -> void:
	_set_input_live(true)


func board_reserved_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for control in [back_button, hint_button]:
		if control.visible:
			result.append(Rect2($Hud.position + control.position, control.size))
	if swap_action_bar.visible:
		result.append(Rect2(swap_action_bar.position, swap_action_bar.size))
	return result


func tray_rect() -> Rect2:
	return Rect2(tray_view.position, tray_view.size) if tray_view.visible else Rect2()


func top_reserved_height() -> float:
	return $Hud.size.y


func _apply_layout_scale(value: float) -> void:
	_layout_scale = maxf(1.0, value)
	_apply_current_layout()


func _apply_current_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	(
		_layout
		. apply(
			size,
			$Hud,
			back_shadow,
			back_button,
			title_label,
			hint_shadow,
			hint_button,
			tray_view,
			swap_action_bar,
			_layout_scale,
		)
	)


func bottom_reserved_height() -> float:
	# PuzzleBoard already adds the explicit tray bounds to the play-area reserve.
	# Returning the tray height here would reserve it twice.
	if tray_view.visible:
		return 0.0
	if swap_action_bar.visible:
		return swap_action_bar.size.y
	return 0.0


func _set_input_live(enabled: bool) -> void:
	_input_live = enabled
	back_button.disabled = not _navigation_active
	hint_button.disabled = not enabled
	swap_action_bar.set_actions_enabled(enabled)


func _read(field: String, fallback: Variant = null) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	if _view_model == null:
		return fallback
	var value: Variant = _view_model.get(field)
	return fallback if value == null else value
