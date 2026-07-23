class_name HomePagerController
extends RefCounted

signal drag_updated(direction: int, progress: float, offset: float)
signal page_settled(index: int, committed: bool)
signal activation_requested()

const CLICK_THRESHOLD := 8.0
const COMMIT_RATIO := 0.25
const FLING_VELOCITY := 760.0
const EDGE_DAMPING := 0.28

var _host: Control
var _tokens: MotionTokens
var _page_count := 0
var _current_index := 0
var _page_width := 1.0
var _drag_total := 0.0
var _velocity := 0.0
var _dragging := false
var _active := false
var _last_usec := 0
var _tween: Tween


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
	cancel_motion()
	drag_updated.emit(0, 0.0, 0.0)
	_active = true
	_dragging = false
	_drag_total = 0.0
	_velocity = 0.0
	_last_usec = Time.get_ticks_usec()


func drag_by(delta_x: float, elapsed_override := -1.0) -> void:
	if not _active:
		return
	var elapsed := elapsed_override
	if elapsed <= 0.0:
		var now := Time.get_ticks_usec()
		elapsed = maxf(0.001, float(now - _last_usec) / 1000000.0)
		_last_usec = now
	_drag_total += delta_x
	_velocity = lerpf(_velocity, delta_x / elapsed, 0.45)
	if absf(_drag_total) > CLICK_THRESHOLD:
		_dragging = true
	if not _dragging:
		return
	var raw_offset := _drag_total
	var direction := _direction_from_offset(raw_offset)
	if (direction < 0 and _current_index == 0) or (direction > 0 and _current_index == _page_count - 1):
		raw_offset *= EDGE_DAMPING
	var progress := clampf(absf(raw_offset) / _page_width, 0.0, 1.0)
	drag_updated.emit(direction, progress, raw_offset)


func end() -> void:
	if not _active:
		return
	_active = false
	if not _dragging:
		_reset_gesture()
		activation_requested.emit()
		return
	var direction := _direction_from_offset(_drag_total)
	var ratio := absf(_drag_total) / _page_width
	var can_commit := direction != 0 and _can_move(direction)
	var should_commit := can_commit and (ratio >= COMMIT_RATIO or absf(_velocity) >= FLING_VELOCITY)
	_settle(direction if should_commit else 0)


func cancel_to_current() -> void:
	if not _active and _tween == null:
		return
	_active = false
	_settle(0)


func current_index() -> int:
	return _current_index


func is_dragging() -> bool:
	return _dragging


func active_motion_count() -> int:
	return 1 if _tween != null and _tween.is_valid() and _tween.is_running() else 0


func cancel_motion() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _settle(direction: int) -> void:
	cancel_motion()
	var committed := direction != 0 and _can_move(direction)
	var target_progress := 1.0 if committed else 0.0
	var duration := _tokens.reduced_motion_duration if _tokens == null or _is_reduced() else (_tokens.page_duration if committed else 0.22)
	var start_progress := clampf(absf(_drag_total) / _page_width, 0.0, 1.0)
	var visual_direction := direction if direction != 0 else _direction_from_offset(_drag_total)
	if duration <= 0.0:
		_complete_settle(direction, committed)
		return
	_tween = _host.create_tween()
	_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(value: float) -> void:
			drag_updated.emit(visual_direction, value, -float(visual_direction) * value * _page_width), start_progress, target_progress, duration)
	_tween.finished.connect(func() -> void: _complete_settle(direction, committed))


func _complete_settle(direction: int, committed: bool) -> void:
	_tween = null
	if committed:
		_current_index += direction
	_reset_gesture()
	page_settled.emit(_current_index, committed)


func _can_move(direction: int) -> bool:
	return _current_index + direction >= 0 and _current_index + direction < _page_count


func _direction_from_offset(offset: float) -> int:
	if is_zero_approx(offset):
		return 0
	return 1 if offset < 0.0 else -1


func _reset_gesture() -> void:
	_drag_total = 0.0
	_velocity = 0.0
	_dragging = false
	_active = false


func _is_reduced() -> bool:
	return bool(_host.get_meta("reduced_motion", false))
