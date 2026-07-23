class_name MotionTokens
extends Resource

@export var press_duration := 0.08
@export var release_duration := 0.14
@export var state_duration := 0.16
@export var content_duration := 0.22
@export var page_duration := 0.28
@export var modal_open_duration := 0.24
@export var modal_close_duration := 0.14
@export var home_to_levels_duration := 0.36
@export var shared_card_duration := 0.48
@export var home_cold_duration := 0.9
@export var unlock_duration := 1.25
@export var reduced_motion_duration := 0.12
@export var progress_cat_duration := 0.26
@export var progress_paw_duration := 0.14
@export var progress_completion_duration := 0.16
@export var numeric_progress_duration := 0.12
@export var numeric_completion_duration := 0.22
@export var primary_press_scale := 0.97
@export var card_press_scale := 0.98
@export var icon_press_scale := 0.96
@export var release_scale := 1.01
@export var press_transition: Tween.TransitionType = Tween.TRANS_QUAD
@export var press_ease: Tween.EaseType = Tween.EASE_OUT
@export var enter_transition: Tween.TransitionType = Tween.TRANS_CUBIC
@export var enter_ease: Tween.EaseType = Tween.EASE_OUT
@export var settle_transition: Tween.TransitionType = Tween.TRANS_QUART
@export var settle_ease: Tween.EaseType = Tween.EASE_OUT
