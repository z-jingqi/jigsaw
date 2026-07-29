class_name TransitionHost
extends Control

signal transition_settled(committed: bool)

const NORMAL_DURATION := 0.28
const HOME_TO_LEVELS_DURATION := 0.36
const LEVELS_TO_HOME_DURATION := 0.30
const HOME_TO_ALL_THEMES_DURATION := 0.28
const ALL_THEMES_TO_HOME_DURATION := 0.22
const CARD_TO_LEVELS_DURATION := 0.48
const REDUCED_MOTION_DURATION := 0.12

var _active_tween: Tween
var _active_sequence := 0
var _active_kind := StringName()
var _active_context: Dictionary = {}
var _motion_phase := &"idle"
var _gesture_progress := 0.0
var _source_view: Control
var _target_view: Control
var _source_state: Dictionary = {}
var _target_state: Dictionary = {}
var _cover_proxy: TextureRect


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
		"proxy_active": is_instance_valid(_cover_proxy),
	}


func _duration_for(kind: StringName, reduced_motion: bool) -> float:
	if reduced_motion:
		return REDUCED_MOTION_DURATION
	match kind:
		&"home_to_levels":
			return HOME_TO_LEVELS_DURATION
		&"levels_to_home":
			return LEVELS_TO_HOME_DURATION
		&"home_to_all_themes":
			return HOME_TO_ALL_THEMES_DURATION
		&"all_themes_to_home":
			return ALL_THEMES_TO_HOME_DURATION
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
	_restore_view_states()
	_release_proxy()
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
	match kind:
		&"home_to_levels":
			_prepare_center_pivots()
			_target_view.modulate.a = 0.0
			_target_view.scale = Vector2(0.99, 0.99)
			_active_tween.tween_property(_target_view, "modulate:a", 1.0, HOME_TO_LEVELS_DURATION)
			_active_tween.tween_property(_target_view, "scale", Vector2.ONE, duration)
			if is_instance_valid(_source_view):
				_active_tween.tween_property(_source_view, "scale", Vector2(1.03, 1.03), duration)
				_active_tween.tween_property(_source_view, "modulate:a", 0.82, duration)
		&"levels_to_home":
			_prepare_center_pivots()
			_target_view.modulate.a = 0.82
			_target_view.scale = Vector2(1.03, 1.03)
			_active_tween.tween_property(_target_view, "modulate:a", 1.0, duration)
			_active_tween.tween_property(_target_view, "scale", Vector2.ONE, duration)
			if is_instance_valid(_source_view):
				_active_tween.tween_property(_source_view, "modulate:a", 0.0, duration)
				_active_tween.tween_property(_source_view, "scale", Vector2(0.99, 0.99), duration)
		&"home_to_all_themes":
			_prepare_center_pivots()
			var target_y := _target_view.position.y
			_target_view.position.y = target_y + 48.0
			_target_view.modulate.a = 0.0
			_active_tween.tween_property(_target_view, "position:y", target_y, duration)
			_active_tween.tween_property(_target_view, "modulate:a", 1.0, duration)
			if is_instance_valid(_source_view):
				_active_tween.tween_property(_source_view, "scale", Vector2(0.985, 0.985), duration)
				_active_tween.tween_property(_source_view, "modulate:a", 0.78, duration)
		&"all_themes_to_home":
			_prepare_center_pivots()
			_target_view.scale = Vector2(0.985, 0.985)
			_target_view.modulate.a = 0.78
			_active_tween.tween_property(_target_view, "scale", Vector2.ONE, duration)
			_active_tween.tween_property(_target_view, "modulate:a", 1.0, duration)
			if is_instance_valid(_source_view):
				_active_tween.tween_property(
					_source_view, "position:y", _source_view.position.y + 48.0, duration
				)
				_active_tween.tween_property(_source_view, "modulate:a", 0.0, duration)
		&"card_to_levels":
			_target_view.modulate.a = 0.0
			_active_tween.tween_property(_target_view, "modulate:a", 1.0, 0.18).set_delay(0.30)
			if is_instance_valid(_source_view):
				_active_tween.tween_property(_source_view, "modulate:a", 0.0, 0.20)
			_create_cover_proxy()
			if is_instance_valid(_cover_proxy):
				(
					_active_tween
					. tween_property(_cover_proxy, "position", Vector2.ZERO, duration - 0.12)
					. set_delay(0.12)
				)
				_active_tween.tween_property(_cover_proxy, "size", size, duration - 0.12).set_delay(
					0.12
				)
				_active_tween.tween_property(_cover_proxy, "modulate:a", 0.0, 0.12).set_delay(
					duration - 0.12
				)
		_:
			_target_view.modulate.a = 0.0
			_active_tween.tween_property(_target_view, "modulate:a", 1.0, duration)
			if is_instance_valid(_source_view):
				_active_tween.tween_property(_source_view, "modulate:a", 0.0, duration)
	return true


func _capture_view_states() -> void:
	_source_state = _capture_view_state(_source_view)
	_target_state = _capture_view_state(_target_view)


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
	_source_view = null
	_target_view = null
	_source_state = {}
	_target_state = {}


func _restore_view_state(view: Control, state: Dictionary) -> void:
	if not is_instance_valid(view) or state.is_empty():
		return
	view.position = state.position
	view.scale = state.scale
	view.modulate = state.modulate
	view.pivot_offset = state.pivot_offset


func _prepare_center_pivots() -> void:
	if is_instance_valid(_source_view):
		_source_view.pivot_offset = _source_view.size * 0.5
	if is_instance_valid(_target_view):
		_target_view.pivot_offset = _target_view.size * 0.5


func _create_cover_proxy() -> void:
	var source_rect := _active_context.get("source_rect", Rect2()) as Rect2
	var source_texture := _active_context.get("source_texture") as Texture2D
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0 or source_texture == null:
		return
	_cover_proxy = TextureRect.new()
	_cover_proxy.name = "SharedCoverProxy"
	_cover_proxy.texture = source_texture
	_cover_proxy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover_proxy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cover_proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover_proxy.position = source_rect.position - global_position
	_cover_proxy.size = source_rect.size
	add_child(_cover_proxy)


func _release_proxy() -> void:
	if is_instance_valid(_cover_proxy):
		_cover_proxy.queue_free()
	_cover_proxy = null
