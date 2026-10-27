class_name GameplayScreen
extends Control

signal back_requested
signal hint_requested
signal move_swap_up_requested
signal move_swap_down_requested
signal move_swap_left_requested
signal move_swap_right_requested

const GameplayLayoutScript := preload("res://scripts/screens/gameplay/GameplayLayout.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Composition := preload("res://scripts/screens/gameplay/GameplaySceneComposition.gd")

@onready var loading_label: Label = $LoadingLabel
@onready var back_button: ActionButton = $Hud/BackButton
@onready var title_label: Label = $Hud/Title
@onready var hint_button: ActionButton = $Hud/HintButton
@onready var title_cloud_left: TextureRect = $Hud/TitleCloudLeft
@onready var title_cloud_right: TextureRect = $Hud/TitleCloudRight
@onready var tray_view: Control = $BottomHost/TrayView
@onready var swap_action_bar: SwapActionBarView = $BottomHost/SwapActionBar

var _view_model: Variant
var _input_live := false
var _board_ready := false
var _preparing_board := true
var _navigation_active := false
var _navigation_locked := false
var _composition := Composition.new()
var _layout_scale := 1.0
var _layout := GameplayLayoutScript.new()


func _ready() -> void:
	back_button.pressed.connect(back_requested.emit)
	hint_button.pressed.connect(hint_requested.emit)
	swap_action_bar.move_up_requested.connect(move_swap_up_requested.emit)
	swap_action_bar.move_down_requested.connect(move_swap_down_requested.emit)
	swap_action_bar.move_left_requested.connect(move_swap_left_requested.emit)
	swap_action_bar.move_right_requested.connect(move_swap_right_requested.emit)
	resized.connect(_apply_current_layout)
	_set_input_live(false)
	_apply_current_layout()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_preparing_board = true
	loading_label.text = GameStrings.ui_text("loading_puzzle")
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	set_reduced_motion(bool(context.get("reduced_motion", false)))


func navigation_exit(_context: Dictionary) -> void:
	_navigation_active = false
	_preparing_board = false
	_board_ready = false
	_set_input_live(false)
	_composition.release()


func attach_board_host(host: Node2D) -> void:
	_composition.mount(host, $BoardHost)


func navigation_set_active(is_active: bool) -> void:
	_navigation_active = is_active
	visible = is_active
	_set_input_live(is_active and _board_ready and not _navigation_locked)


func set_navigation_locked(locked: bool) -> void:
	_navigation_locked = locked
	_set_input_live(_navigation_active and _board_ready and not locked)


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if not is_node_ready():
		return
	back_button.accessibility_label = GameStrings.ui_text("back")
	back_button.accessibility_name = back_button.accessibility_label
	hint_button.accessibility_label = GameStrings.ui_text("hint")
	hint_button.accessibility_name = hint_button.accessibility_label
	swap_action_bar.refresh_accessibility()
	title_label.text = str(_read("level_title", ""))
	var mode := String(_read("mode", ""))
	tray_view.visible = mode == "polygon" or mode == "knob"
	swap_action_bar.visible = mode == "swap"
	_apply_layout_scale(float(_read("ui_scale", 1.0)))
	hint_button.visible = true


func set_reduced_motion(enabled: bool) -> void:
	# Fixed screen entrance is owned by the navigator transition; gameplay
	# interactions themselves remain deterministic regardless of this preference.
	back_button.set_reduced_motion(enabled)
	hint_button.set_reduced_motion(enabled)
	swap_action_bar.set_reduced_motion(enabled)


func mark_board_live() -> void:
	_preparing_board = false
	_board_ready = true
	_set_input_live(_navigation_active and not _navigation_locked)


func mark_board_preparing() -> void:
	_preparing_board = true
	_board_ready = false
	loading_label.text = GameStrings.ui_text("loading_puzzle")
	_set_input_live(false)


func mark_board_failed() -> void:
	_board_ready = false
	_preparing_board = true
	loading_label.text = GameStrings.ui_text("puzzle_load_failed")
	_set_input_live(false)


func has_live_board() -> bool:
	return _board_ready


func is_board_input_enabled() -> bool:
	return _input_live


func prepare_completion() -> void:
	_preparing_board = false
	_board_ready = false
	_set_input_live(false)


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
	var unit := Clean.canvas_scale(size, get_window())
	loading_label.add_theme_font_size_override("font_size", roundi(16 * unit))
	loading_label.add_theme_font_override("font", Clean.FONT)
	loading_label.add_theme_color_override("font_color", Clean.INK)
	loading_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	loading_label.position = Vector2(24 * unit, size.y * 0.38 - 24 * unit)
	loading_label.size = Vector2(size.x - 48 * unit, 48 * unit)
	(
		_layout
		. apply(
			size,
			$Hud,
			[back_button, hint_button],
			title_label,
			title_cloud_left,
			title_cloud_right,
			tray_view,
			swap_action_bar,
			_layout_scale,
		)
	)


func bottom_reserved_height() -> float:
	# The board adds tray height itself; reserve only the space below it here.
	var gap := _layout.board_gap(size, _layout_scale)
	if tray_view.visible:
		return maxf(0.0, size.y - tray_view.position.y - tray_view.size.y) + gap
	if swap_action_bar.visible:
		return size.y - swap_action_bar.position.y + gap
	return 0.0


func _set_input_live(enabled: bool) -> void:
	_input_live = enabled
	loading_label.visible = _navigation_active and _preparing_board
	back_button.disabled = not _navigation_active
	for button in [hint_button]:
		button.disabled = not enabled
		if not enabled:
			button.cancel_motion()
	swap_action_bar.set_actions_enabled(enabled)


func _read(field: String, fallback: Variant = null) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	if _view_model == null:
		return fallback
	var value: Variant = _view_model.get(field)
	return fallback if value == null else value
