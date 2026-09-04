class_name HomePagerController
extends RefCounted

signal drag_updated(direction: int, progress: float, offset: float)
signal page_settled(index: int, committed: bool)
signal activation_requested

const CLICK_THRESHOLD := 8.0
const COMMIT_RATIO := 0.25
const FLING_VELOCITY := 760.0
const EDGE_DAMPING := 0.28
const KineticsScript := preload("res://scripts/ui/motion/ScrollKinetics.gd")
const SETTLE_DECAY := 10.0

var _host: Control
var _tokens: MotionTokens
var _page_count := 0
var _current_index := 0
var _page_width := 1.0
var _drag_total := 0.0
var _velocity := 0.0
var _dragging := false
var _active := false
var _motion := KineticsScript.new()
var _tween: Tween
var _visual_direction := 0
var _visual_progress := 0.0
var _visual_offset := 0.0


func _init(host: Control, tokens: MotionTokens) -> void:
	_host = host
	_tokens = tokens


func configure(page_count: int, selected_index: int, page_width: float) -> void:
	cancel_motion()
	_page_count = maxi(0, page_count)
	_current_index = clampi(selected_index, 0, maxi(0, _page_count - 1))
	_page_width = maxf(1.0, page_width)
	_reset_gesture()


func begin() -> void:
	if _page_count <= 0:
		return
	var takeover_offset := _visual_offset
	cancel_motion()
	_active = true
	_drag_total = takeover_offset
	_dragging = absf(takeover_offset) > CLICK_THRESHOLD
	_velocity = 0.0
	_motion.begin(-takeover_offset)
	if _dragging:
		_emit_visual(
			_direction_from_offset(takeover_offset),
			clampf(absf(takeover_offset) / _page_width, 0.0, 1.0),
			takeover_offset
		)
	else:
		_emit_visual(0, 0.0, 0.0)


func drag_by(delta_x: float) -> void:
	if not _active:
		return
	_drag_total = -_motion.drag_by(delta_x, -_page_width, _page_width)
	if absf(_drag_total) > CLICK_THRESHOLD:
		_dragging = true
	if not _dragging:
		return
	var raw_offset := _drag_total
	var direction := _direction_from_offset(raw_offset)
	if _page_count <= 1:
		raw_offset *= EDGE_DAMPING
	var progress := clampf(absf(raw_offset) / _page_width, 0.0, 1.0)
	_emit_visual(direction, progress, raw_offset)


func end() -> void:
	if not _active:
		return
	_active = false
	_velocity = -_motion.release()
	if not _dragging:
		_reset_gesture()
		activation_requested.emit()
		return
	var direction := _direction_from_offset(_drag_total)
	var ratio := absf(_drag_total) / _page_width
	var can_commit := direction != 0 and _can_move(direction)
	var flinging := absf(_velocity) >= FLING_VELOCITY
	var moving_outward := _direction_from_offset(_velocity) == direction
	var should_commit := can_commit and (moving_outward if flinging else ratio >= COMMIT_RATIO)
	_settle(direction if should_commit else 0)


func cancel_to_current() -> void:
	if not _active and _tween == null:
		return
	_active = false
	_motion.stop()
	_velocity = 0.0
	_settle(0)


func finish_to_current() -> void:
	var had_visual_state := (
		_active or _tween != null or _visual_progress > 0.0 or not is_zero_approx(_visual_offset)
	)
	cancel_motion()
	_reset_gesture()
	_reset_visual()
	if had_visual_state:
		page_settled.emit(_current_index, false)


func current_index() -> int:
	return _current_index


func finish_to_visible() -> void:
	var direction := _visual_direction if _visual_progress >= 0.5 else 0
	cancel_motion()
	_complete_settle(direction, direction != 0 and _can_move(direction))


func is_dragging() -> bool:
	return _dragging


func gesture_progress() -> float:
	return _visual_progress


func gesture_offset() -> float:
	return _visual_offset


func active_motion_count() -> int:
	return 1 if _tween != null and _tween.is_valid() and _tween.is_running() else 0


func cancel_motion() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _settle(direction: int) -> void:
	cancel_motion()
	var committed := direction != 0 and _can_move(direction)
	if _is_reduced():
		_complete_settle(direction, committed)
		return
	var target_offset := -float(direction) * _page_width if committed else 0.0
	var displacement := _visual_offset - target_offset
	var duration := _tokens.page_duration if _tokens != null else 0.28
	var frequency := SETTLE_DECAY / maxf(0.01, duration)
	var coefficient := _velocity + frequency * displacement
	_tween = _host.create_tween()
	# Critically damped settling starts at the actual release position/velocity.
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_method(
		func(elapsed: float) -> void:
			var offset := (
				target_offset + ((displacement + coefficient * elapsed) * exp(-frequency * elapsed))
			)
			offset = clampf(offset, -_page_width, _page_width)
			_emit_visual(_direction_from_offset(offset), absf(offset) / _page_width, offset),
		0.0,
		duration,
		duration
	)
	_tween.finished.connect(func() -> void: _complete_settle(direction, committed))


func _complete_settle(direction: int, committed: bool) -> void:
	_tween = null
	if committed:
		_current_index = posmod(_current_index + direction, _page_count)
	_reset_gesture()
	_reset_visual()
	page_settled.emit(_current_index, committed)


func _can_move(direction: int) -> bool:
	return direction != 0 and _page_count > 1


func _direction_from_offset(offset: float) -> int:
	if is_zero_approx(offset):
		return 0
	return 1 if offset < 0.0 else -1


func _reset_gesture() -> void:
	_motion.stop()
	_drag_total = 0.0
	_velocity = 0.0
	_dragging = false
	_active = false


func _emit_visual(direction: int, progress: float, offset: float) -> void:
	_visual_direction = direction
	_visual_progress = progress
	_visual_offset = offset
	drag_updated.emit(direction, progress, offset)


func _reset_visual() -> void:
	_visual_direction = 0
	_visual_progress = 0.0
	_visual_offset = 0.0


func _is_reduced() -> bool:
	return bool(_host.get_meta("reduced_motion", false))
