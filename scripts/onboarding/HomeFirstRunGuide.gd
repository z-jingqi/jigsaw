class_name HomeFirstRunGuide
extends Control

signal skip_requested()

@onready var prompt: Label = $GuidePanel/Prompt
@onready var gesture_hint: Label = $GuidePanel/GestureHint
@onready var skip_button: Button = $SkipButton

var _motion: Tween
var _dismissed := false


func _ready() -> void:
	skip_button.pressed.connect(skip_requested.emit)


func show_step(step: StringName, reduced_motion: bool, labels: Dictionary) -> void:
	visible = true
	set_step(step, reduced_motion, labels)


func set_step(step: StringName, reduced_motion: bool, labels: Dictionary) -> void:
	_stop_motion()
	skip_button.text = str(labels.get("skip", "Skip"))
	skip_button.tooltip_text = skip_button.text
	if step == &"enter":
		prompt.text = str(labels.get("enter", "Tap the cover to open its levels"))
		gesture_hint.text = str(labels.get("enter_hint", "Tap to play"))
	else:
		prompt.text = str(labels.get("swipe", "Swipe left or right to explore themes"))
		gesture_hint.text = str(labels.get("swipe_hint", "←   Swipe   →"))
	if reduced_motion:
		return
	_motion = create_tween()
	_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if step == &"enter":
		for _index in 2:
			_motion.tween_property(gesture_hint, "scale", Vector2(1.04, 1.04), 0.18)
			_motion.tween_property(gesture_hint, "scale", Vector2.ONE, 0.18)
	else:
		_motion.tween_property(gesture_hint, "position:x", -20.0, 0.18)
		_motion.tween_property(gesture_hint, "position:x", 0.0, 0.18)
		_motion.tween_property(gesture_hint, "position:x", 20.0, 0.18)
		_motion.tween_property(gesture_hint, "position:x", 0.0, 0.18)
	_motion.finished.connect(_stop_motion, CONNECT_ONE_SHOT)


func dismiss(reduced_motion: bool) -> void:
	if _dismissed:
		return
	_dismissed = true
	_stop_motion()
	if reduced_motion:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.finished.connect(queue_free, CONNECT_ONE_SHOT)


func active_motion_count() -> int:
	return 1 if _motion != null and _motion.is_valid() else 0


func _stop_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
