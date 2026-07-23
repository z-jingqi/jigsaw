class_name ActionButton
extends Button

enum Kind { PRIMARY, PILL, ICON, CARD }

@export var kind: Kind = Kind.PRIMARY
@export var accessibility_label := ""
@export_multiline var accessibility_detail := ""
@export var motion_tokens: MotionTokens

var _feedback: PressFeedback

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


func _exit_tree() -> void:
	if _feedback != null:
		_feedback.dispose()
