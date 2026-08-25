class_name SwapActionBarView
extends Control

signal move_up_requested
signal move_down_requested

const BUTTON_SIZE := 228.0
const BUTTON_GAP := 68.0
const BOTTOM_MARGIN := 70.0
const SHADOW_OFFSET := Vector2(8.0, 11.0)

@onready var move_up_group: Control = $Actions/MoveUpGroup
@onready var move_down_group: Control = $Actions/MoveDownGroup
@onready var move_up: ActionButton = $Actions/MoveUpGroup/HitTarget
@onready var move_down: ActionButton = $Actions/MoveDownGroup/HitTarget

var _reduced_motion := false
var _press_tweens: Dictionary = {}


func _ready() -> void:
	move_up.pressed.connect(move_up_requested.emit)
	move_down.pressed.connect(move_down_requested.emit)
	move_up.button_down.connect(_set_group_pressed.bind(move_up_group, true))
	move_up.button_up.connect(_set_group_pressed.bind(move_up_group, false))
	move_down.button_down.connect(_set_group_pressed.bind(move_down_group, true))
	move_down.button_up.connect(_set_group_pressed.bind(move_down_group, false))
	resized.connect(_apply_layout)
	_apply_layout()


func configure_layout(scale: float) -> void:
	set_meta(&"gameplay_layout_scale", maxf(0.5, scale))
	_apply_layout()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	move_up.set_reduced_motion(enabled)
	move_down.set_reduced_motion(enabled)


func set_actions_enabled(enabled: bool) -> void:
	move_up.disabled = not enabled
	move_down.disabled = not enabled


func _apply_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	var scale := float(get_meta(&"gameplay_layout_scale", 1.0))
	var button_size := BUTTON_SIZE * scale
	var gap := BUTTON_GAP * scale
	var total_width := button_size * 2.0 + gap
	var top := maxf(0.0, size.y - BOTTOM_MARGIN * scale - button_size)
	_configure_group(
		move_up_group, Vector2((size.x - total_width) * 0.5, top), button_size, false, scale
	)
	_configure_group(
		move_down_group,
		Vector2((size.x - total_width) * 0.5 + button_size + gap, top),
		button_size,
		true,
		scale,
	)


func _configure_group(
	group: Control, position: Vector2, button_size: float, rotated: bool, scale: float
) -> void:
	group.set_anchors_preset(Control.PRESET_TOP_LEFT)
	group.position = position
	group.size = Vector2.ONE * button_size
	group.pivot_offset = group.size * 0.5
	var shadow := group.get_node("Shadow") as TextureRect
	var visual := group.get_node("Visual") as TextureRect
	shadow.position = SHADOW_OFFSET * scale
	shadow.size = group.size
	visual.offset_left = 0.0
	visual.offset_top = 0.0
	visual.offset_right = 0.0
	visual.offset_bottom = 0.0
	shadow.pivot_offset = shadow.size * 0.5
	shadow.rotation = PI if rotated else 0.0
	visual.pivot_offset = visual.size * 0.5
	visual.rotation = PI if rotated else 0.0


func _set_group_pressed(group: Control, pressed: bool) -> void:
	if _press_tweens.has(group):
		var existing := _press_tweens[group] as Tween
		if existing != null and existing.is_valid():
			existing.kill()
	var target := Vector2.ONE * (0.965 if pressed else 1.0)
	if _reduced_motion:
		group.scale = target
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_press_tweens[group] = tween
	tween.tween_property(group, "scale", target, 0.08 if pressed else 0.12)
	tween.finished.connect(func() -> void: _press_tweens.erase(group))
