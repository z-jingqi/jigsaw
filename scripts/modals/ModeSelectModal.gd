class_name RuntimeModeSelectModal
extends Control

signal close_requested()
signal mode_selected(mode: StringName, start_policy: StringName)

const ModeOptionScene := preload("res://scenes/ui/foundation/ModeOption.tscn")

@onready var shell: AnimatedModalShell = $ModalShell
@onready var title_label: Label = $ModalShell/Panel/Content/Header/Title
@onready var close_button: Button = $ModalShell/Panel/Content/Header/CloseButton
@onready var subtitle_label: Label = $ModalShell/Panel/Content/Subtitle
@onready var options: VBoxContainer = $ModalShell/Panel/Content/Options

var _view_model: Variant
var _reduced_motion := false
var _pending_selection: Dictionary = {}
var _content_tween: Tween
var _closing := false


func _ready() -> void:
	close_button.pressed.connect(request_close)
	shell.closed.connect(_on_shell_closed)
	resized.connect(_configure_panel)
	_configure_panel()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	opening()


func navigation_exit(_context: Dictionary) -> void:
	_stop_content_motion()
	if is_instance_valid(shell):
		shell.dispose()


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
	if not is_active:
		_stop_content_motion()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if not is_node_ready():
		return
	title_label.text = str(_read("level_title", ""))
	subtitle_label.text = "Choose a mode"
	_reconcile_options()
	_configure_panel()


func opening() -> void:
	if not is_instance_valid(shell):
		return
	_closing = false
	_pending_selection.clear()
	_set_interaction_enabled(true)
	shell.play_open(_reduced_motion)
	_play_content_entry()


func request_close() -> void:
	if _closing or not is_instance_valid(shell):
		return
	_closing = true
	_set_interaction_enabled(false)
	_stop_content_motion()
	shell.play_close(_reduced_motion)


func active_motion_count() -> int:
	var shell_motion := shell.active_motion_count() if is_instance_valid(shell) else 0
	return shell_motion + (1 if _content_tween != null else 0)


func _reconcile_options() -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	for option_model in _read("options", []):
		var option := ModeOptionScene.instantiate() as Control
		options.add_child(option)
		option.call(&"set_view_model", option_model)
		option.connect(&"selection_requested", _on_option_selected)


func _on_option_selected(mode: StringName, start_policy: StringName) -> void:
	if _closing:
		return
	_pending_selection = {"mode": mode, "start_policy": start_policy}
	request_close()


func _on_shell_closed(_closed_shell: AnimatedModalShell) -> void:
	_stop_content_motion()
	if _pending_selection.is_empty():
		close_requested.emit()
	else:
		mode_selected.emit(_pending_selection.mode, _pending_selection.start_policy)
	_pending_selection.clear()


func _set_interaction_enabled(enabled: bool) -> void:
	close_button.disabled = not enabled
	for child in options.get_children():
		child.call(&"set_interaction_enabled", enabled)


func _play_content_entry() -> void:
	_stop_content_motion()
	if _reduced_motion:
		_set_content_visible_state()
		return
	title_label.modulate.a = 0.0
	title_label.position.y = 8.0
	for child in options.get_children():
		child.modulate.a = 0.0
		child.position.y += 8.0
	_content_tween = create_tween().set_parallel(true)
	_content_tween.tween_property(title_label, "modulate:a", 1.0, 0.22)
	_content_tween.tween_property(title_label, "position:y", 0.0, 0.22)
	for index in options.get_child_count():
		var option := options.get_child(index) as Control
		_content_tween.tween_property(option, "modulate:a", 1.0, 0.20).set_delay(float(index) * 0.035)
		_content_tween.tween_property(option, "position:y", 0.0, 0.20).set_delay(float(index) * 0.035)
	_content_tween.finished.connect(_stop_content_motion, CONNECT_ONE_SHOT)


func _set_content_visible_state() -> void:
	title_label.modulate.a = 1.0
	title_label.position.y = 0.0
	for child in options.get_children():
		child.modulate.a = 1.0
		child.position.y = 0.0


func _stop_content_motion() -> void:
	if _content_tween != null and _content_tween.is_valid():
		_content_tween.kill()
	_content_tween = null


func _configure_panel() -> void:
	if not is_instance_valid(shell):
		return
	var width := minf(560.0, maxf(280.0, size.x - 40.0))
	var option_count := options.get_child_count() if is_instance_valid(options) else 1
	var height := minf(size.y - 40.0, 160.0 + float(maxi(1, option_count)) * 116.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("FFF9EC")
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.shadow_color = Color(0.02, 0.10, 0.13, 0.24)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	shell.configure_panel(Vector2(width, height), style, Vector4(24, 20, 24, 20))


func _read(field: String, fallback: Variant = null) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	return _view_model.get(field) if _view_model != null else fallback
