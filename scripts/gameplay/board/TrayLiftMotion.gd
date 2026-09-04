extends RefCounted
class_name TrayLiftMotion

## Animate only the lift/size adjustment. Pointer translation remains immediate.
const LIFT_DURATION := 0.18

var host: Node2D
var _group = null
var _tween: Tween
var _pointer := Vector2.ZERO
var _grab := Vector2.ZERO
var _from_offset := Vector2.ZERO
var _target_offset := Vector2.ZERO
var _offset := Vector2.ZERO
var _from_scale := 1.0


func _init(owner: Node2D) -> void:
	host = owner


func begin(group, previous_point: Vector2, point: Vector2, grab: Vector2, offset: Vector2) -> void:
	stop()
	_group = group
	_pointer = point
	_grab = grab
	_target_offset = offset
	var screen_position: Vector2 = group.node.position
	var screen_scale: float = group.node.scale.x
	_from_scale = screen_scale / maxf(0.001, host.view_scale)
	_from_offset = screen_position + grab * screen_scale - previous_point
	host._send_group_to_world(group, host._screen_to_world(screen_position), _from_scale)
	if host.reduced_motion:
		_advance(1.0)
		return
	# The first pose includes the real pointer delta but no extra lift displacement.
	_advance(0.0)
	_tween = host.create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_advance, 0.0, 1.0, LIFT_DURATION)


func update(point: Vector2) -> void:
	_pointer = point
	_apply_pose()


func finish() -> void:
	if _group != null and is_instance_valid(_group.node):
		# Snap testing must not depend on how much of the visual lift tween happened
		# to finish. Preserve the displayed pose for a seamless failed return, then
		# commit the same full-size logical pose for every release at this pointer.
		_group.remember_tray_return_pose(
			host._world_to_screen(_group.node.position),
			_group.node.scale.x * host.view_scale
		)
		_group.node.scale = Vector2.ONE
		_group.node.position = host._screen_to_world(_pointer + _target_offset) - _grab
	stop()


func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_group = null


func _advance(progress: float) -> void:
	if _group == null or not is_instance_valid(_group.node):
		return
	_offset = _from_offset.lerp(_target_offset, progress)
	_group.node.scale = Vector2.ONE * lerpf(_from_scale, 1.0, progress)
	_apply_pose()


func _apply_pose() -> void:
	if _group == null or not is_instance_valid(_group.node):
		return
	host.last_drag_screen_pos = _pointer
	_group.node.position = (host._screen_to_world(_pointer + _offset) - _grab * _group.node.scale.x)
	_group.node.z_index = host.TRAY_DRAG_Z_INDEX
