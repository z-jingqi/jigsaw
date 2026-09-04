extends RefCounted
class_name TrayGestureController

## A held piece keeps ownership across scrolling, lifting and returning.
const LIFT_ENTER_THRESHOLD_PIXELS := 16.0
const LIFT_EXIT_THRESHOLD_PIXELS := 8.0
const LIFT_DISTANCE_PIXELS := 96.0
const LiftMotionScript := preload("res://scripts/gameplay/board/TrayLiftMotion.gd")

enum GestureState {
	IDLE,
	TRAY_SCROLL,
	WORLD_DRAG,
}

var host: Node2D
var held_group = null
var _origin := Vector2.ZERO
var _last := Vector2.ZERO
var _local_grab := Vector2.ZERO
var _lift_offset := Vector2.ZERO
var _lift_enter_threshold := 0.0
var _lift_exit_threshold := 0.0
var _state := GestureState.IDLE
var _pickup_haptic_sent := false
var _lift_motion: TrayLiftMotion


func _init(owner: Node2D) -> void:
	host = owner
	_lift_motion = LiftMotionScript.new(owner)


func begin(group, point: Vector2) -> void:
	held_group = group
	_origin = point
	_last = point
	_state = GestureState.TRAY_SCROLL
	_pickup_haptic_sent = false
	# Capture the actual down point, not the later event that crosses the threshold.
	_local_grab = (point - group.node.position) / maxf(0.001, group.node.scale.x)
	var screen_scale: float = host.get_viewport().get_screen_transform().y.length()
	_lift_enter_threshold = LIFT_ENTER_THRESHOLD_PIXELS / maxf(0.001, screen_scale)
	_lift_exit_threshold = LIFT_EXIT_THRESHOLD_PIXELS / maxf(0.001, screen_scale)
	# Keep the touch-to-piece relationship consistent across both tray rows and
	# irregular piece shapes. A shape-dependent offset made some polygon pieces
	# sit almost 200 physical pixels above the finger, so an apparently correct
	# finger release could leave the piece far outside the snap radius.
	_lift_offset = Vector2(0.0, -LIFT_DISTANCE_PIXELS / maxf(0.001, screen_scale))
	host._begin_tray_pan()
	host.tray_controller.raise_group_for_drag(group)


func update(point: Vector2) -> void:
	if held_group == null:
		return
	var relative := point - _last
	var previous := _last
	_last = point
	var upward_distance := _origin.y - point.y
	if _state == GestureState.WORLD_DRAG:
		if upward_distance < _lift_exit_threshold:
			_resume_scroll(point, relative)
		else:
			_lift_motion.update(point)
	elif _state == GestureState.TRAY_SCROLL:
		if upward_distance > _lift_enter_threshold:
			_lift(previous, point)
			_lift_motion.update(point)
		else:
			host._pan_tray(relative.x)


func release(cancelled := false) -> bool:
	if held_group == null:
		return false
	var was_lifted := _state == GestureState.WORLD_DRAG
	if not was_lifted:
		host.tray_controller.restore_group_tray_z(held_group)
	else:
		# A quick release can arrive before the lift tween reaches world scale.
		# Finish that pose so release-only snapping is never rejected mid-transition.
		_lift_motion.finish()
	reset()
	if was_lifted:
		# BoardInputController owns the existing release-only snap/return path.
		return false
	if cancelled:
		host.tray_panning = false
		host._stop_tray_inertia()
	else:
		host._release_tray_pan()
	return true


func reset() -> void:
	_lift_motion.stop()
	held_group = null
	_state = GestureState.IDLE
	_pickup_haptic_sent = false
	_origin = Vector2.ZERO
	_last = Vector2.ZERO
	_local_grab = Vector2.ZERO
	_lift_offset = Vector2.ZERO


func _lift(previous: Vector2, point: Vector2) -> void:
	_state = GestureState.WORLD_DRAG
	host._stop_tray_inertia()
	host.tray_panning = false
	host.dragging = held_group
	host.dragging_from_tray = true
	host.dragging_tray_index = held_group.tray_index
	_lift_motion.begin(held_group, previous, point, _local_grab, _lift_offset)
	# Match the original single-row interaction: confirm pickup when the piece
	# actually leaves the tray, not while the finger is merely pressing it.
	if not _pickup_haptic_sent:
		host._trigger_haptic("pickup")
		_pickup_haptic_sent = true
	host.PieceVisualFactoryScript.set_group_lifted(held_group, true, host, not host.reduced_motion)


func _resume_scroll(point: Vector2, relative: Vector2) -> void:
	_lift_motion.stop()
	_state = GestureState.TRAY_SCROLL
	host.dragging = null
	host.dragging_from_tray = false
	host.dragging_tray_index = -1
	host.tray_controller.resume_held_scroll(held_group, point, relative, _local_grab)
	host.PieceVisualFactoryScript.set_group_lifted(held_group, false, host, not host.reduced_motion)
