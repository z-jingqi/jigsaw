class_name SwapActionBarView
extends Control

signal move_up_requested
signal move_down_requested
signal move_left_requested
signal move_right_requested

const BUTTON_SIZE := 156.0
const BUTTON_GAP := 40.0

@onready var move_up_group: Control = $Actions/MoveUpGroup
@onready var move_down_group: Control = $Actions/MoveDownGroup
@onready var move_up: ActionButton = $Actions/MoveUpGroup/HitTarget
@onready var move_down: ActionButton = $Actions/MoveDownGroup/HitTarget

@onready var move_left_group: Control = $Actions/MoveLeftGroup
@onready var move_right_group: Control = $Actions/MoveRightGroup
@onready var move_left: ActionButton = $Actions/MoveLeftGroup/HitTarget
@onready var move_right: ActionButton = $Actions/MoveRightGroup/HitTarget


func _ready() -> void:
	move_up.pressed.connect(move_up_requested.emit)
	move_down.pressed.connect(move_down_requested.emit)
	move_left.pressed.connect(move_left_requested.emit)
	move_right.pressed.connect(move_right_requested.emit)
	resized.connect(_apply_layout)
	_apply_layout()


func configure_layout(scale: float) -> void:
	set_meta(&"gameplay_layout_scale", maxf(0.25, scale))
	_apply_layout()


func set_reduced_motion(enabled: bool) -> void:
	move_up.set_reduced_motion(enabled)
	move_down.set_reduced_motion(enabled)
	move_left.set_reduced_motion(enabled)
	move_right.set_reduced_motion(enabled)


func set_actions_enabled(enabled: bool) -> void:
	for button in [move_left, move_up, move_down, move_right]:
		button.disabled = not enabled
		if not enabled:
			button.cancel_motion()


func _apply_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	var scale := float(get_meta(&"gameplay_layout_scale", 1.0))
	var button_size := maxf(44.0, BUTTON_SIZE * scale)
	var gap := BUTTON_GAP * scale
	var total_width := button_size * 4.0 + gap * 3.0
	var top := maxf(0.0, (size.y - button_size) * 0.5)
	var groups := [move_left_group, move_up_group, move_down_group, move_right_group]
	for index in groups.size():
		_configure_group(
			groups[index],
			Vector2((size.x - total_width) * 0.5 + index * (button_size + gap), top),
			button_size,
		)


func _configure_group(group: Control, position: Vector2, button_size: float) -> void:
	group.set_anchors_preset(Control.PRESET_TOP_LEFT)
	group.position = position
	group.size = Vector2.ONE * button_size
	group.pivot_offset = group.size * 0.5
