class_name PressFeedback
extends RefCounted

var _target: Control
var _tokens: MotionTokens
var _press_scale: float
var _tween: Tween

func _init(target: Control, tokens: MotionTokens, press_scale: float) -> void:
	_target = target
	_tokens = tokens
	_press_scale = press_scale
	target.gui_input.connect(_on_gui_input)
	target.tree_exiting.connect(dispose)
	target.focus_exited.connect(_release)


func dispose() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _on_gui_input(event: InputEvent) -> void:
	if not is_instance_valid(_target) or _target.disabled:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_play_to(Vector2(_press_scale, _press_scale), _tokens.press_duration)
		else:
			_release()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_play_to(Vector2(_press_scale, _press_scale), _tokens.press_duration)
		else:
			_release()
	elif event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release()


func _release() -> void:
	if _target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion():
		return
	if _target.scale.is_equal_approx(Vector2.ONE):
		return
	dispose()
	_tween = _target.create_tween()
	_tween.set_trans(_tokens.press_transition).set_ease(_tokens.press_ease)
	_tween.tween_property(_target, "scale", Vector2(_tokens.release_scale, _tokens.release_scale), _tokens.release_duration * 0.45)
	_tween.tween_property(_target, "scale", Vector2.ONE, _tokens.release_duration * 0.55)


func _play_to(scale_value: Vector2, duration: float) -> void:
	dispose()
	_tween = _target.create_tween()
	_tween.set_trans(_tokens.press_transition).set_ease(_tokens.press_ease)
	_tween.tween_property(_target, "scale", scale_value, duration)
