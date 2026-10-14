class_name HomeFirstRunGuide
extends Control

signal skip_requested

@onready var prompt: Label = $GuidePanel/Prompt
@onready var gesture_hint: Label = $GuidePanel/GestureHint
@onready var skip_button: Button = $SkipButton

var _motion: Tween
var _dismissed := false
var _hint_rest := Vector2.ZERO


func _ready() -> void:
	skip_button.pressed.connect(skip_requested.emit)
	resized.connect(_layout)
	_layout()


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
		_motion.tween_property(gesture_hint, "position:x", _hint_rest.x - 20.0, 0.18)
		_motion.tween_property(gesture_hint, "position:x", _hint_rest.x, 0.18)
		_motion.tween_property(gesture_hint, "position:x", _hint_rest.x + 20.0, 0.18)
		_motion.tween_property(gesture_hint, "position:x", _hint_rest.x, 0.18)
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
	if is_instance_valid(gesture_hint):
		gesture_hint.position = _hint_rest
		gesture_hint.scale = Vector2.ONE


func set_reduced_motion(enabled: bool) -> void:
	if enabled:
		_stop_motion()


func _layout() -> void:
	if not is_node_ready():
		return
	_stop_motion()
	var unit := minf(size.x / 390.0, size.y / 700.0)
	var panel := $GuidePanel as Panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(size.x * 0.84, 180 * unit)
	panel.position = Vector2(size.x * 0.08, minf(size.y * 0.61, size.y - 300 * unit))
	for label in [prompt, gesture_hint]:
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.size = Vector2(panel.size.x - 32 * unit, 46 * unit)
		label.add_theme_font_size_override("font_size", roundi(18 * unit))
	prompt.position = Vector2(16, 14) * unit
	_hint_rest = Vector2(16, 68) * unit
	gesture_hint.position = _hint_rest
	gesture_hint.pivot_offset = gesture_hint.size * 0.5
	skip_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	skip_button.size = Vector2(86, 34) * unit
	skip_button.position = (
		panel.position + Vector2((panel.size.x - skip_button.size.x) * 0.5, 130 * unit)
	)
	skip_button.add_theme_font_size_override("font_size", roundi(15 * unit))
