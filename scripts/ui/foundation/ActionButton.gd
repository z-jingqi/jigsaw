class_name ActionButton
extends Button

enum Kind { PRIMARY, PILL, ICON, CARD }

@export var kind: Kind = Kind.PRIMARY
@export var accessibility_label := ""
@export_multiline var accessibility_detail := ""
@export var motion_tokens: MotionTokens

var _feedback: PressFeedback
var _reduced_motion := false


func _ready() -> void:
	custom_minimum_size = custom_minimum_size.max(Vector2(44.0, 44.0))
	accessibility_name = accessibility_label if not accessibility_label.is_empty() else text
	tooltip_text = accessibility_name
	accessibility_description = accessibility_detail
	if motion_tokens == null:
		motion_tokens = preload("res://themes/motion_tokens.tres")
	var press_scale := motion_tokens.primary_press_scale
	if kind == Kind.CARD:
		press_scale = motion_tokens.card_press_scale
	elif kind == Kind.ICON:
		press_scale = motion_tokens.icon_press_scale
	_feedback = PressFeedback.new(self, motion_tokens, press_scale)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if _feedback != null:
		_feedback.set_reduced_motion(enabled)


func cancel_motion() -> void:
	if _feedback != null:
		_feedback.cancel()


func active_motion_count() -> int:
	return _feedback.active_motion_count() if _feedback != null else 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN:
		cancel_motion()


func _exit_tree() -> void:
	if _feedback != null:
		_feedback.dispose()
