class_name CompletionModal
extends Control

signal confirm_requested(completion_event_id: String)
signal dismissed(completion_event_id: String)

const CompletionLayoutScript := preload("res://scripts/modals/CompletionLayout.gd")
const ModeStatusIconScene := preload("res://scenes/ui/foundation/ModeStatusIcon.tscn")

@onready var canvas: Control = $Canvas
@onready var header: Control = $Canvas/Header
@onready var back_button: ActionButton = $Canvas/Header/BackButton
@onready var level_label: Label = $Canvas/Header/LevelTitle
@onready var card_stage: Control = $Canvas/CardStage
@onready var card_frame: Panel = $Canvas/CardStage/CardFrame
@onready var image_rect: TextureRect = $Canvas/CardStage/CompletedImage
@onready var completion_paw: TextureRect = $Canvas/CardStage/CompletionPaw
@onready var celebration: Control = $Canvas/Celebration
@onready var left_leaf: TextureRect = $Canvas/Celebration/LeftLeaf
@onready var title_label: Label = $Canvas/Celebration/Title
@onready var right_leaf: TextureRect = $Canvas/Celebration/RightLeaf
@onready var mode_row: HBoxContainer = $Canvas/ModeRow
@onready var confirm_button: ActionButton = $Canvas/Confirm
@onready var confirm_label: Label = $Canvas/Confirm/Label
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _view_model: AppViewModels.CompletionViewModel
var _layout := CompletionLayoutScript.new()
var _reduced_motion := false
var _closing := false
var _confirming := false


func _ready() -> void:
	back_button.pressed.connect(_request_confirm)
	confirm_button.pressed.connect(_request_confirm)
	animation_player.animation_finished.connect(_on_animation_finished)
	resized.connect(_apply_layout)
	_apply_layout()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_reduced_motion = bool(context.get("reduced_motion", false))
	back_button.set_reduced_motion(_reduced_motion)
	confirm_button.set_reduced_motion(_reduced_motion)
	_view_model = payload.get("view_model", null) as AppViewModels.CompletionViewModel
	if _view_model == null:
		return
	level_label.text = _view_model.level_title
	title_label.text = _view_model.title
	image_rect.texture = _view_model.completed_texture
	confirm_label.text = _view_model.primary_action_text
	_reconcile_modes(_view_model.modes)
	_apply_layout()
	_play_open()


func navigation_exit(_context: Dictionary) -> void:
	animation_player.stop()
	back_button.cancel_motion()
	confirm_button.cancel_motion()
	for child in mode_row.get_children():
		if child is ActionButton:
			child.cancel_motion()


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE


func request_dismiss() -> void:
	_request_confirm()


func active_motion_count() -> int:
	var count := 1 if animation_player.is_playing() else 0
	count += back_button.active_motion_count()
	count += confirm_button.active_motion_count()
	return count


func _request_confirm() -> void:
	if _closing or _view_model == null:
		return
	_confirming = true
	_play_close()


func _play_open() -> void:
	_closing = false
	_confirming = false
	back_button.disabled = false
	confirm_button.disabled = false
	animation_player.stop()
	if _reduced_motion:
		animation_player.play(&"RESET")
		animation_player.advance(0.0)
		animation_player.stop(true)
	else:
		animation_player.play(&"open")


func _play_close() -> void:
	_closing = true
	back_button.disabled = true
	confirm_button.disabled = true
	back_button.cancel_motion()
	confirm_button.cancel_motion()
	animation_player.stop()
	if _reduced_motion:
		_finish_close()
	else:
		animation_player.play(&"close")


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"close":
		_finish_close()


func _finish_close() -> void:
	if _view_model == null:
		return
	if _confirming:
		confirm_requested.emit(_view_model.completion_event_id)
	else:
		dismissed.emit(_view_model.completion_event_id)


func _reconcile_modes(modes: Array[AppViewModels.ModeStatusViewModel]) -> void:
	for child in mode_row.get_children():
		mode_row.remove_child(child)
		child.queue_free()
	for mode_model in modes:
		var status_icon := ModeStatusIconScene.instantiate() as ModeStatusIcon
		mode_row.add_child(status_icon)
		status_icon.set_variant(&"completion")
		status_icon.set_interactive(false)
		status_icon.set_show_progress_dot(false)
		status_icon.set_reduced_motion(_reduced_motion)
		status_icon.set_view_model(mode_model)


func _apply_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	_layout.apply_header(size, header, back_button, level_label)
	_layout.apply_card(size, card_stage, card_frame, image_rect, completion_paw)
	(
		_layout
		. apply_footer(
			size,
			celebration,
			left_leaf,
			title_label,
			right_leaf,
			mode_row,
			confirm_button,
			confirm_label,
		)
	)
