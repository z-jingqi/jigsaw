class_name TransitionHost
extends Control

signal transition_settled(committed: bool)
signal motion_started(kind: StringName)

const CardMotion := preload("res://scripts/navigation/CardPageMotion.gd")
const SheetCloseOverlay := preload("res://scripts/navigation/ThemeLibraryCloseOverlay.gd")
var _sheet_close := SheetCloseOverlay.new()
const ThemeLibraryMotion := preload("res://scripts/navigation/ThemeLibraryMotion.gd")
const NORMAL_DURATION := 0.32
const HOME_TO_LEVELS_DURATION := 0.32
const LEVELS_TO_HOME_DURATION := 0.32
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
var _motion_start_source: Dictionary = {}
var _motion_start_target: Dictionary = {}
var _motion_start_source_companion: Dictionary = {}
var _motion_start_target_companion: Dictionary = {}
var _carried_states: Dictionary = {}
var _carried_companion_states: Dictionary = {}
var _target_companion_carried := false
var _continuing := false
var _target_carried := false
var _gesture_paused := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(kind: StringName, context: Dictionary = {}) -> Dictionary:
	interrupt_at_current_pose()
	_active_sequence += 1
	_active_kind = kind
	_active_context = context.duplicate(true)
	_motion_phase = &"running"
	_gesture_progress = float(context.get("gesture_progress", 0.0))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var duration := _duration_for(kind, bool(context.get("reduced_motion", false)))
	_source_view = context.get("source_view") as Control
	_target_view = context.get("target_view") as Control
	_source_companion = context.get("source_companion") as Node2D
	_target_companion = context.get("target_companion") as Node2D
	_capture_view_states()
	if bool(context.get("prepare_before_motion", false)):
		_motion_phase = &"preparing"
		_active_tween = create_tween()
		_active_tween.tween_interval(duration)
		_active_tween.pause()
	else:
		_start_motion(kind, duration)
	return snapshot()


func reveal_prepared_view(view: Control) -> void:
	if _motion_phase != &"preparing" or view != _target_view:
		return
	_active_tween.kill()
	_motion_phase = &"running"
	_start_motion(
		_active_kind,
		_duration_for(_active_kind, bool(_active_context.get("reduced_motion", false)))
	)


func _start_motion(kind: StringName, duration: float) -> void:
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var animated := (
		_configure_continuation(duration) if _continuing else _configure_motion(kind, duration)
	)
	_motion_start_source = (
		_source_state.duplicate() if _continuing else _capture_view_state(_source_view)
	)
	_motion_start_target = _capture_view_state(_target_view)
	_motion_start_source_companion = (
		_source_companion_state.duplicate()
		if _continuing
		else _capture_companion_state(_source_companion)
	)
	_motion_start_target_companion = _capture_companion_state(_target_companion)
	if not animated:
		_active_tween.tween_interval(duration)
	_active_tween.finished.connect(_settle.bind(_active_sequence, true))
	if _gesture_paused:
		_active_tween.pause()
	motion_started.emit(kind)


func reverse_active_to_source() -> bool:
	if _active_tween == null:
		return false
	if _motion_phase == &"reversing":
		return true
	_active_tween.kill()
	_active_sequence += 1
	_motion_phase = &"reversing"
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var fraction := 0.0
	for pair in [[_source_view, _motion_start_source], [_target_view, _motion_start_target]]:
		var view := pair[0] as Control
		var state: Dictionary = pair[1]
		if is_instance_valid(view) and not state.is_empty():
			fraction = maxf(
				fraction, view.position.distance_to(state.position) / maxf(1.0, view.size.length())
			)
			fraction = maxf(fraction, absf(view.modulate.a - state.modulate.a))
	var duration := (
		0.001
		if bool(_active_context.get("reduced_motion", false))
		else clampf(0.24 * sqrt(fraction), 0.04, 0.24)
	)
	_tween_view_to(
		_source_view,
		_motion_start_source if not _motion_start_source.is_empty() else _source_state,
		duration
	)
	_tween_view_to(
		_target_view,
		_motion_start_target if not _motion_start_target.is_empty() else _target_state,
		duration
	)
	_tween_companion_to(_source_companion, _motion_start_source_companion, duration)
	_tween_companion_to(_target_companion, _motion_start_target_companion, duration)
	_active_tween.tween_interval(duration)
	_active_tween.finished.connect(_settle.bind(_active_sequence, false))
	return true


func resume_active_to_target() -> void:
	if _motion_phase != &"reversing":
		return
	_active_tween.kill()
	_active_sequence += 1
	_motion_phase = &"running"
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_target_carried = true
	_target_companion_carried = true
	_configure_continuation(0.20)
	_active_tween.finished.connect(_settle.bind(_active_sequence, true))


func interrupt_at_current_pose() -> void:
	if _active_tween == null:
		return
	var reversing := _motion_phase == &"reversing"
	var target := _source_view if reversing else _target_view
	var pose := _capture_view_state(target)
	var baseline := (_source_state if reversing else _target_state).duplicate()
	var companion := _source_companion if reversing else _target_companion
	var companion_pose := _capture_companion_state(companion)
	var companion_baseline := (
		(_source_companion_state if reversing else _target_companion_state).duplicate()
	)
	_settle(_active_sequence, not reversing, false)
	# Resolve the route transaction exactly once, but never expose its visual end
	# pose. The next motion receives the surviving view's current transform.
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		_restore_view_state(target, pose)
		_carried_states[target.get_instance_id()] = baseline
	if is_instance_valid(companion) and not companion.is_queued_for_deletion():
		_restore_companion_state(companion, companion_pose)
		_carried_companion_states[companion.get_instance_id()] = companion_baseline


func _configure_continuation(duration: float) -> bool:
	if (
		_active_kind in [&"home_to_themes", &"themes_to_home"]
		and is_instance_valid(_source_view)
		and is_instance_valid(_target_view)
	):
		_configure_theme_sheet(duration, true)
		return true
	if not is_instance_valid(_target_view):
		return false
	var returning := str(_active_context.get("reason")) in ["pop", "close_modal"]
	var width := _target_view.size.x
	if not _target_carried and not returning:
		_target_view.position.x = _target_state.position.x + width
	_tween_view_to(_target_view, _target_state, duration)
	if is_instance_valid(_source_view):
		var destination := _source_state.duplicate()
		if returning:
			destination.position.x += width
			_source_view.z_index = 50
		elif _active_context.get("reason") == "push_from_modal":
			destination.position.x -= width
		else:
			_target_view.z_index = 50
		_tween_view_to(_source_view, destination, duration)
	return true


func _tween_view_to(view: Control, state: Dictionary, duration: float) -> void:
	if not is_instance_valid(view) or state.is_empty():
		return
	for property in ["position", "scale", "modulate", "rotation"]:
		_active_tween.tween_property(view, property, state[property], duration)


func _tween_companion_to(companion: Node2D, state: Dictionary, duration: float) -> void:
	if not is_instance_valid(companion) or state.is_empty():
		return
	for property in ["position", "scale", "modulate"]:
		_active_tween.tween_property(companion, property, state[property], duration)


func gesture_pause_motion() -> Dictionary:
	_gesture_paused = true
	var token := {"sequence": _active_sequence, "running": false}
	if _active_tween != null:
		token.running = _active_tween.is_running()
		_active_tween.pause()
	return token


func gesture_resume_motion(token: Dictionary) -> void:
	_gesture_paused = false
	if (
		_active_tween != null
		and int(token.get("sequence", -1)) == _active_sequence
		and bool(token.get("running", false))
	):
		_active_tween.play()


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
		"reason": str(_active_context.get("reason", "")),
		"reduced_motion": bool(_active_context.get("reduced_motion", false)),
	}


func _duration_for(kind: StringName, reduced_motion: bool) -> float:
	if reduced_motion:
		if kind == &"gameplay_page":
			if (
				_active_context.get("reason") == "pop"
				and _active_context.get("source_view") is CompletionModal
			):
				# Show the end state immediately, but absorb the return button's
				# second tap before the exposed level cards accept input.
				return REDUCED_MOTION_DURATION
			return 0.001
		return 0.001
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


func _settle(sequence: int, committed: bool, settle_custom := true) -> void:
	_gesture_paused = false
	if _active_tween == null or sequence != _active_sequence:
		return
	var tween := _active_tween
	_active_tween = null
	if is_instance_valid(tween):
		tween.kill()
	if (
		settle_custom
		and is_instance_valid(_target_view)
		and _target_view.has_method("settle_box_transition")
	):
		_target_view.settle_box_transition(committed)
	_sheet_close.clear()
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
		_configure_theme_sheet(duration, false)
		return true
	if (
		kind == &"modal"
		and _active_context.get("reason") == "show_modal"
		and _target_view.has_method("configure_box_transition")
	):
		return _target_view.configure_box_transition(_active_tween, duration)
	if reduced:
		_target_view.modulate.a = 1.0
		if is_instance_valid(_source_view):
			_source_view.modulate.a = 0.0
		return false
	if kind in [&"home_to_levels", &"levels_to_home", &"screen", &"gameplay_page", &"modal"]:
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


func _configure_theme_sheet(duration: float, continuation: bool) -> void:
	var closing: bool = _active_context.get("reason") == "pop"
	var sheet := _source_view if closing else _target_view
	var state := _source_state if closing else _target_state
	_sheet_close.install(self, sheet, state.get("position", Vector2.ZERO))
	ThemeLibraryMotion.configure(
		_active_tween,
		_source_view,
		_target_view,
		_active_context,
		duration,
		bool(_active_context.get("reduced_motion", false)),
		continuation,
		_source_state.get("position", Vector2.ZERO),
		_target_state.get("position", Vector2.ZERO)
	)


func _capture_view_states() -> void:
	_continuing = false
	_source_state = _baseline_state(_source_view)
	_target_carried = (
		is_instance_valid(_target_view) and _carried_states.has(_target_view.get_instance_id())
	)
	_target_state = _baseline_state(_target_view)
	_motion_start_source = {}
	_motion_start_target = {}
	_motion_start_source_companion = {}
	_motion_start_target_companion = {}
	_target_companion_carried = (
		is_instance_valid(_target_companion)
		and _carried_companion_states.has(_target_companion.get_instance_id())
	)
	_source_companion_state = _baseline_companion_state(_source_companion)
	_target_companion_state = _baseline_companion_state(_target_companion)


func _baseline_state(view: Control) -> Dictionary:
	if is_instance_valid(view) and _carried_states.has(view.get_instance_id()):
		_continuing = true
		var state: Dictionary = _carried_states[view.get_instance_id()]
		_carried_states.erase(view.get_instance_id())
		return state
	return _capture_view_state(view)


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


func _baseline_companion_state(companion: Node2D) -> Dictionary:
	if is_instance_valid(companion) and _carried_companion_states.has(companion.get_instance_id()):
		_continuing = true
		var state: Dictionary = _carried_companion_states[companion.get_instance_id()]
		_carried_companion_states.erase(companion.get_instance_id())
		return state
	return _capture_companion_state(companion)


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
