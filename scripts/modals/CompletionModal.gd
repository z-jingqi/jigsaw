class_name CompletionModal
extends Control

signal confirm_requested(completion_event_id: String)
signal dismissed(completion_event_id: String)

@onready var shell: AnimatedModalShell = $ModalShell
@onready var title_label: Label = $ModalShell/Panel/Content/Title
@onready var image_rect: TextureRect = $ModalShell/Panel/Content/CompletedImage
@onready var level_label: Label = $ModalShell/Panel/Content/LevelName
@onready var description_label: Label = $ModalShell/Panel/Content/Description
@onready var confirm_button: Button = $ModalShell/Panel/Content/Confirm
@onready var confetti: Node2D = $CompletionConfetti

var _view_model: AppViewModels.CompletionViewModel
var _reduced_motion := false
var _closing := false
var _confirming := false
var _content_tween: Tween


func _ready() -> void:
	confirm_button.pressed.connect(_request_confirm)
	shell.closed.connect(_on_shell_closed)
	resized.connect(_configure_panel)
	_configure_panel()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_reduced_motion = bool(context.get("reduced_motion", false))
	_view_model = payload.get("view_model", null) as AppViewModels.CompletionViewModel
	if _view_model == null:
		return
	title_label.text = _view_model.title
	image_rect.texture = _view_model.completed_texture
	level_label.text = _view_model.level_title
	description_label.text = _view_model.description
	description_label.visible = not _view_model.description.is_empty()
	confirm_button.text = _view_model.primary_action_text
	_configure_panel()
	_open()


func navigation_exit(_context: Dictionary) -> void:
	_stop_content_motion()
	confetti.call(&"stop")
	if is_instance_valid(shell):
		shell.dispose()


func request_dismiss() -> void:
	if _closing:
		return
	_confirming = false
	_request_close()


func active_motion_count() -> int:
	return (1 if _content_tween != null else 0) + (shell.active_motion_count() if is_instance_valid(shell) else 0)


func _request_confirm() -> void:
	if _closing:
		return
	_confirming = true
	_request_close()


func _request_close() -> void:
	_closing = true
	confirm_button.disabled = true
	_stop_content_motion()
	confetti.call(&"stop")
	shell.play_close(_reduced_motion)


func _on_shell_closed(_closed_shell: AnimatedModalShell) -> void:
	if _view_model == null:
		return
	if _confirming:
		confirm_requested.emit(_view_model.completion_event_id)
	else:
		dismissed.emit(_view_model.completion_event_id)


func _open() -> void:
	_closing = false
	_confirming = false
	confirm_button.disabled = false
	shell.configure_shade(Color(0.14, 0.09, 0.05, 0.72))
	shell.play_open(_reduced_motion)
	_play_content_entry()
	confetti.call(&"start", _reduced_motion)


func _play_content_entry() -> void:
	_stop_content_motion()
	var controls: Array[Control] = [title_label, image_rect, level_label, description_label, confirm_button]
	if _reduced_motion:
		for control in controls:
			control.modulate.a = 1.0
		image_rect.scale = Vector2.ONE
		return
	for control in controls:
		control.modulate.a = 0.0
	image_rect.pivot_offset = image_rect.size * 0.5
	image_rect.scale = Vector2(0.96, 0.96)
	_content_tween = create_tween().set_parallel(true)
	for index in controls.size():
		var control := controls[index]
		_content_tween.tween_property(control, "modulate:a", 1.0, 0.22).set_delay(0.12 + float(index) * 0.05)
	_content_tween.tween_property(image_rect, "scale", Vector2.ONE, 0.36).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_content_tween.finished.connect(_stop_content_motion, CONNECT_ONE_SHOT)


func _stop_content_motion() -> void:
	if _content_tween != null and _content_tween.is_valid():
		_content_tween.kill()
	_content_tween = null


func _configure_panel() -> void:
	if not is_instance_valid(shell):
		return
	var panel_size := Vector2(minf(520.0, maxf(300.0, size.x - 40.0)), minf(720.0, maxf(420.0, size.y - 40.0)))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("FFF8EC")
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.shadow_color = Color(0.02, 0.10, 0.13, 0.24)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	shell.configure_panel(panel_size, style, Vector4(26, 22, 26, 24))
