class_name TransitionHost
extends Control

signal transition_settled(committed: bool)

const CardMotion := preload("res://scripts/navigation/CardPageMotion.gd")
const ThemeLibraryMotion := preload("res://scripts/navigation/ThemeLibraryMotion.gd")
const NORMAL_DURATION := 0.40
const HOME_TO_LEVELS_DURATION := 0.56
const LEVELS_TO_HOME_DURATION := 0.42
const THEME_LIBRARY_OPEN_DURATION := 0.44
const THEME_LIBRARY_CLOSE_DURATION := 0.32
const REDUCED_MOTION_DURATION := 0.12

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
		&"home_to_themes":
			return THEME_LIBRARY_OPEN_DURATION
		&"themes_to_home":
			return THEME_LIBRARY_CLOSE_DURATION
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
	if kind in [&"home_to_themes", &"themes_to_home"] and is_instance_valid(_source_view):
		ThemeLibraryMotion.configure(
			_active_tween, _source_view, _target_view, _active_context, duration, reduced
		)
		return true
	if reduced:
		_target_view.modulate.a = 0.0
		_active_tween.tween_property(_target_view, "modulate:a", 1.0, duration)
		if is_instance_valid(_source_view):
			_active_tween.tween_property(_source_view, "modulate:a", 0.0, duration)
		return true
	if kind in [&"home_to_levels", &"levels_to_home", &"screen"]:
		if is_instance_valid(_source_view):
			CardMotion.configure(
				_active_tween, _source_view, _target_view, _active_context, duration
			)
			return true
		_target_view.modulate.a = 0.0
		_active_tween.tween_property(_target_view, "modulate:a", 1.0, duration)
		return true
	_target_view.modulate.a = 0.0
	_active_tween.tween_property(_target_view, "modulate:a", 1.0, duration)
	if is_instance_valid(_source_view):
		_active_tween.tween_property(_source_view, "modulate:a", 0.0, duration)
	return true


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
		"rotation": view.rotation,
		"z_index": view.z_index,
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
	view.rotation = state.rotation
	view.z_index = state.z_index


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
