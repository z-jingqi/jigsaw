class_name CompletionModal
extends Control

signal confirm_requested(completion_event_id: String)
signal dismissed(completion_event_id: String)

const Layout := preload("res://scripts/modals/CompletionLayout.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")

@onready var header: Control = $Canvas/Header
@onready var level_label: Label = $Canvas/Header/LevelTitle
@onready var card_stage: Control = $Canvas/Body/Content/CardStage
@onready var image_rect: TextureRect = $Canvas/Body/Content/CardStage/CompletedImage
@onready var confirm_button: ActionButton = $Canvas/Confirm
@onready var confirm_label: Label = $Canvas/Confirm/Label
@onready var return_button: ActionButton = $Canvas/Return
@onready var body: ScrollContainer = $Canvas/Body
@onready var body_content: Control = $Canvas/Body/Content
@onready var description_label: Label = $Canvas/Body/Content/Description
@onready var cat: TextureRect = $Canvas/Cat
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var image_motion: Node = $ImageMotion

var _view_model: AppViewModels.CompletionViewModel
var _layout := Layout.new()
var _reduced_motion := false
var _closing := false


func _ready() -> void:
	confirm_button.pressed.connect(_request_confirm)
	return_button.pressed.connect(request_dismiss)
	animation_player.animation_finished.connect(_on_animation_finished)
	resized.connect(_apply_layout)
	Clean.button(confirm_button, true)
	confirm_label.add_theme_color_override("font_color", Clean.PAPER)
	Clean.icon_button(return_button)
	# Input gating during the entrance must not change either button's surface.
	for button in [confirm_button, return_button]:
		button.add_theme_stylebox_override(
			"disabled", button.get_theme_stylebox("normal").duplicate()
		)


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_view_model = payload.get("view_model") as AppViewModels.CompletionViewModel
	if _view_model == null:
		return
	_reduced_motion = bool(context.get("reduced_motion", false))
	confirm_button.set_reduced_motion(_reduced_motion)
	return_button.set_reduced_motion(_reduced_motion)
	level_label.text = _view_model.level_title
	image_rect.texture = _view_model.completed_texture
	confirm_label.text = _view_model.primary_action_text
	confirm_button.accessibility_name = confirm_label.text
	return_button.accessibility_name = _view_model.secondary_action_text
	description_label.text = _view_model.level_description
	description_label.visible = not description_label.text.is_empty()
	description_label.add_theme_color_override("font_color", Clean.INK)
	description_label.add_theme_font_override("font", Clean.FONT)
	body.scroll_vertical = 0
	if not _view_model.has_next_level:
		confirm_label.text = GameStrings.ui_text("completion_done")
		confirm_button.accessibility_name = confirm_label.text
	_closing = false
	_apply_layout()
	if _reduced_motion:
		_finish_open()
	else:
		_set_buttons_enabled(true)
		animation_player.play(&"open")
		animation_player.advance(0.0)


func navigation_exit(_context: Dictionary) -> void:
	animation_player.stop()
	confirm_button.cancel_motion()
	return_button.cancel_motion()


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
	if is_active and _closing:
		_closing = false
		_finish_open()


func navigation_prepare_transition() -> void:
	animation_player.stop(true)
	_closing = true
	_set_buttons_enabled(false)
	confirm_button.cancel_motion()
	return_button.cancel_motion()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	confirm_button.set_reduced_motion(enabled)
	return_button.set_reduced_motion(enabled)
	if enabled and not _closing:
		_finish_open()


func request_dismiss() -> void:
	if _closing or _view_model == null:
		return
	_closing = true
	_set_buttons_enabled(false)
	confirm_button.cancel_motion()
	return_button.cancel_motion()
	dismissed.emit(_view_model.completion_event_id)


func restore_actions() -> void:
	_closing = false
	_finish_open()


func active_motion_count() -> int:
	return (
		int(animation_player.is_playing())
		+ confirm_button.active_motion_count()
		+ return_button.active_motion_count()
	)


func _request_confirm() -> void:
	if _closing or _view_model == null:
		return
	if not _view_model.has_next_level:
		request_dismiss()
		return
	_closing = true
	_set_buttons_enabled(false)
	confirm_button.cancel_motion()
	return_button.cancel_motion()
	confirm_requested.emit(_view_model.completion_event_id)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"open" and not _closing:
		_set_buttons_enabled(true)


func _finish_open() -> void:
	animation_player.play(&"RESET")
	animation_player.advance(0.0)
	animation_player.stop(true)
	_set_buttons_enabled(not _closing)


func _set_buttons_enabled(enabled: bool) -> void:
	confirm_button.disabled = not enabled or _view_model == null
	return_button.disabled = not enabled


func _apply_layout() -> void:
	if not is_node_ready() or _view_model == null or size.x <= 0 or size.y <= 0:
		return
	var target := _layout.apply(self)
	var source := (
		body_content.get_global_transform_with_canvas().affine_inverse() * _view_model.source_rect
	)
	image_motion.configure(card_stage, image_rect, source, target)
