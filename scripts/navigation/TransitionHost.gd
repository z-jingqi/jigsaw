class_name TransitionHost
extends Control

signal transition_settled(committed: bool)

const NORMAL_DURATION := 0.28
const HOME_TO_LEVELS_DURATION := 0.36
const CARD_TO_LEVELS_DURATION := 0.48
const REDUCED_MOTION_DURATION := 0.12

var _active_tween: Tween
var _active_sequence := 0
var _active_kind := StringName()
var _active_context: Dictionary = {}
var _motion_phase := &"idle"
var _gesture_progress := 0.0


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
	_active_tween = create_tween()
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
		&"card_to_levels":
			return CARD_TO_LEVELS_DURATION
		_:
			return NORMAL_DURATION


func _settle(sequence: int, committed: bool) -> void:
	if _active_tween == null or sequence != _active_sequence:
		return
	var tween := _active_tween
	_active_tween = null
	if is_instance_valid(tween) and tween.is_running():
		tween.kill()
	_motion_phase = &"idle"
	_gesture_progress = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_settled.emit(committed)
