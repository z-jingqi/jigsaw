class_name HomeFirstRunGuide
extends Control

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")

signal skip_requested

@onready var step_label: Label = $GuidePanel/Step
@onready var gesture_hint: Label = $GuidePanel/GestureHint
@onready var skip_button: Button = $GuidePanel/SkipButton

var _motion: Tween
var _dismissed := false
var _hint_rest := Vector2.ZERO


func _ready() -> void:
	skip_button.pressed.connect(skip_requested.emit)
	resized.connect(_layout)
	_layout()


func navigation_set_active(enabled: bool) -> void:
	# This teaching overlay must not become a full-screen modal input shield.
	# The navigator's default activation uses STOP, so preserve pass-through
	# explicitly while the Skip button remains the only interactive child.
	visible = enabled
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not enabled:
		_stop_motion()


func show_step(step: StringName, reduced_motion: bool, labels: Dictionary) -> void:
	visible = true
	set_step(step, reduced_motion, labels)


func set_step(step: StringName, reduced_motion: bool, labels: Dictionary) -> void:
	_stop_motion()
	skip_button.text = ""
	skip_button.accessibility_name = str(labels.get("skip", "Skip"))
	skip_button.tooltip_text = ""
	step_label.text = "2 / 2" if step == &"enter" else "1 / 2"
	if step == &"enter":
		gesture_hint.text = str(labels.get("enter_hint", "Tap to play"))
	else:
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
	var safe := Clean.safe_insets(size)
	var usable_width := size.x - safe.x - safe.z
	# Extend beyond the home pagination row so its edge actions cannot peek out.
	panel.size = Vector2(minf(usable_width - 32 * unit, 390 * unit), 128 * unit)
	panel.add_theme_stylebox_override("panel", Clean.panel(Clean.SAGE, roundi(24 * unit)))
	panel.position = Vector2(
		safe.x + (usable_width - panel.size.x) * 0.5, size.y - safe.w - 220 * unit
	)
	for label in [gesture_hint]:
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.size = Vector2(panel.size.x - 32 * unit, 46 * unit)
		Clean.label(label, roundi(17 * unit))
	step_label.position = Vector2(24, 20) * unit
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	step_label.size = Vector2(panel.size.x - 88 * unit, 22 * unit)
	Clean.label(step_label, roundi(12 * unit), true)
	_hint_rest = Vector2(16, 62) * unit
	gesture_hint.position = _hint_rest
	gesture_hint.pivot_offset = gesture_hint.size * 0.5
	skip_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	Clean.icon_button(skip_button)
	skip_button.custom_minimum_size = (Vector2.ONE * 44 * unit).max(
		Clean.minimum_touch_size(skip_button)
	)
	skip_button.size = skip_button.custom_minimum_size
	skip_button.position = Vector2(panel.size.x - skip_button.size.x - 12 * unit, 8 * unit)
