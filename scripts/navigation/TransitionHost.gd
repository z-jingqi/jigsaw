class_name TransitionHost
extends Control

signal transition_settled(committed: bool)

const NORMAL_DURATION := 0.50
const HOME_TO_LEVELS_DURATION := 0.56
const LEVELS_TO_HOME_DURATION := 0.42
const REDUCED_MOTION_DURATION := 0.12
const TARGET_OVERLAP_DELAY := 0.07

var _active_tween: Tween
var _active_sequence := 0
var _active_kind := StringName()
var _active_context: Dictionary = {}
var _motion_phase := &"idle"
var _gesture_progress := 0.0
var _source_view: Control
var _target_view: Control
var _source_companion: Node2D
var _target_companion: Node2D
var _source_state: Dictionary = {}
var _target_state: Dictionary = {}
var _source_companion_state: Dictionary = {}
var _target_companion_state: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(kind: StringName, context: Dictionary = {}) -> Dictionary:
	finish_active_to_target()
	_active_sequence += 1
	_active_kind = kind
	_active_context = context.duplicate(true)
	_motion_phase = &"running"
	_gesture_progress = float(context.get("gesture_progress", 0.0))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var duration := _duration_for(kind, bool(context.get("reduced_motion", false)))
	_source_view = context.get("source_view") as Control
	_target_view = context.get("target_view") as Control
	_source_companion = context.get("source_companion") as Node2D
	_target_companion = context.get("target_companion") as Node2D
	_capture_view_states()
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var animated := _configure_motion(kind, duration)
	if not animated:
		_active_tween.tween_interval(duration)
	_active_tween.finished.connect(_settle.bind(_active_sequence, true))
	return snapshot()


func finish_active_to_target() -> void:
	_settle(_active_sequence, true)


func cancel_active_to_source() -> void:
	_settle(_active_sequence, false)


func active_count() -> int:
	return 1 if _active_tween != null else 0


func snapshot() -> Dictionary:
	return {
		"active_motion_count": active_count(),
		"motion_phase": String(_motion_phase),
		"transition_kind": String(_active_kind),
		"gesture_progress": _gesture_progress,
		"reduced_motion": bool(_active_context.get("reduced_motion", false)),
	}


func _duration_for(kind: StringName, reduced_motion: bool) -> float:
	if reduced_motion:
		return REDUCED_MOTION_DURATION
	match kind:
		&"home_to_levels":
			return HOME_TO_LEVELS_DURATION
		&"levels_to_home":
			return LEVELS_TO_HOME_DURATION
		_:
			return NORMAL_DURATION


func _settle(sequence: int, committed: bool) -> void:
	if _active_tween == null or sequence != _active_sequence:
		return
	var tween := _active_tween
	_active_tween = null
	if is_instance_valid(tween) and tween.is_running():
		tween.kill()
	_restore_view_states()
	_motion_phase = &"idle"
	_gesture_progress = 0.0
	_active_kind = StringName()
	_active_context = {}
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_settled.emit(committed)


func _configure_motion(kind: StringName, duration: float) -> bool:
	if not is_instance_valid(_target_view):
		return false
	var reduced := bool(_active_context.get("reduced_motion", false))
	if reduced:
		_target_view.modulate.a = 0.0
		_active_tween.tween_property(_target_view, "modulate:a", 1.0, duration)
		if is_instance_valid(_source_view):
			_active_tween.tween_property(_source_view, "modulate:a", 0.0, duration)
		return true
	if kind in [&"home_to_levels", &"levels_to_home", &"screen"]:
		return _configure_tabletop_slide(kind, duration)
	_target_view.modulate.a = 0.0
	_active_tween.tween_property(_target_view, "modulate:a", 1.0, duration)
	if is_instance_valid(_source_view):
		_active_tween.tween_property(_source_view, "modulate:a", 0.0, duration)
	return true


func _configure_tabletop_slide(kind: StringName, duration: float) -> bool:
	if not is_instance_valid(_source_view):
		_target_view.modulate.a = 0.0
		_active_tween.tween_property(_target_view, "modulate:a", 1.0, duration * 0.65)
		return true
	var backward := kind == &"levels_to_home" or str(_active_context.get("reason", "")) == "pop"
	var exit_direction := 1.0 if backward else -1.0
	var travel := maxf(size.x, get_viewport_rect().size.x) * 1.08
	var source_target := _source_view.position + Vector2(travel * exit_direction, 0.0)
	var target_final := _target_view.position
	_target_view.position = target_final - Vector2(travel * exit_direction, 0.0)
	(
		_active_tween
		. tween_property(_source_view, "position", source_target, duration * 0.82)
		. set_trans(Tween.TRANS_QUART)
		. set_ease(Tween.EASE_IN)
	)
	(
		_active_tween
		. tween_property(_target_view, "position", target_final, duration * 0.86)
		. set_delay(TARGET_OVERLAP_DELAY)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_animate_companion(_source_companion, travel * exit_direction, duration * 0.82, 0.0, true)
	_animate_companion(
		_target_companion, -travel * exit_direction, duration * 0.86, TARGET_OVERLAP_DELAY, false
	)
	return true


func _animate_companion(
	companion: Node2D, start_or_target_x: float, duration: float, delay: float, outgoing: bool
) -> void:
	if not is_instance_valid(companion):
		return
	var final_position := companion.position
	if outgoing:
		final_position.x += start_or_target_x
	else:
		companion.position.x += start_or_target_x
	(
		_active_tween
		. tween_property(companion, "position", final_position, duration)
		. set_delay(delay)
		. set_trans(Tween.TRANS_QUART if outgoing else Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN if outgoing else Tween.EASE_OUT)
	)


func _capture_view_states() -> void:
	_source_state = _capture_view_state(_source_view)
	_target_state = _capture_view_state(_target_view)
	_source_companion_state = _capture_companion_state(_source_companion)
	_target_companion_state = _capture_companion_state(_target_companion)


func _capture_view_state(view: Control) -> Dictionary:
	if not is_instance_valid(view):
		return {}
	return {
		"position": view.position,
		"scale": view.scale,
		"modulate": view.modulate,
		"pivot_offset": view.pivot_offset,
	}


func _restore_view_states() -> void:
	_restore_view_state(_source_view, _source_state)
	_restore_view_state(_target_view, _target_state)
	_restore_companion_state(_source_companion, _source_companion_state)
	_restore_companion_state(_target_companion, _target_companion_state)
	_source_view = null
	_target_view = null
	_source_companion = null
	_target_companion = null
	_source_state = {}
	_target_state = {}
	_source_companion_state = {}
	_target_companion_state = {}


func _restore_view_state(view: Control, state: Dictionary) -> void:
	if not is_instance_valid(view) or state.is_empty():
		return
	view.position = state.position
	view.scale = state.scale
	view.modulate = state.modulate
	view.pivot_offset = state.pivot_offset


func _capture_companion_state(companion: Node2D) -> Dictionary:
	if not is_instance_valid(companion):
		return {}
	return {
		"position": companion.position,
		"scale": companion.scale,
		"modulate": companion.modulate,
	}


func _restore_companion_state(companion: Node2D, state: Dictionary) -> void:
	if not is_instance_valid(companion) or state.is_empty():
		return
	companion.position = state.position
	companion.scale = state.scale
	companion.modulate = state.modulate


func _prepare_center_pivots() -> void:
	if is_instance_valid(_source_view):
		_source_view.pivot_offset = _source_view.size * 0.5
	if is_instance_valid(_target_view):
		_target_view.pivot_offset = _target_view.size * 0.5
