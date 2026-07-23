class_name SettingsModal
extends Control

signal setting_changed(key: StringName, enabled: bool)
signal close_requested()

@onready var shell: AnimatedModalShell = $ModalShell
@onready var title_label: Label = $ModalShell/Panel/Content/Header/Title
@onready var close_button: Button = $ModalShell/Panel/Content/Header/Close
@onready var haptics_row: SettingsRow = $ModalShell/Panel/Content/Rows/Haptics
@onready var music_row: SettingsRow = $ModalShell/Panel/Content/Rows/Music
@onready var sound_effects_row: SettingsRow = $ModalShell/Panel/Content/Rows/SoundEffects
@onready var error_label: Label = $ModalShell/Panel/Content/Error

var _view_model: AppViewModels.SettingsViewModel
var _reduced_motion := false
var _closing := false
var _error_tween: Tween


func _ready() -> void:
	close_button.pressed.connect(request_close)
	haptics_row.value_changed.connect(_on_value_changed)
	music_row.value_changed.connect(_on_value_changed)
	sound_effects_row.value_changed.connect(_on_value_changed)
	shell.shade.gui_input.connect(_on_shade_input)
	shell.closed.connect(_on_shell_closed)
	resized.connect(_configure_panel)
	_configure_panel()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_reduced_motion = bool(context.get("reduced_motion", false))
	_view_model = payload.get("view_model", null) as AppViewModels.SettingsViewModel
	if _view_model == null:
		return
	var labels: Dictionary = payload.get("labels", {})
	title_label.text = str(labels.get("title", "Settings"))
	haptics_row.configure(&"haptics_enabled", str(labels.get("haptics", "Haptics")), _view_model.haptics_enabled)
	music_row.configure(&"music_enabled", str(labels.get("music", "Music")), _view_model.music_enabled)
	sound_effects_row.configure(&"sound_effects_enabled", str(labels.get("sound_effects", "Sound effects")), _view_model.sound_effects_enabled)
	render_view_model(_view_model, false)
	_configure_panel()
	_open()


func navigation_exit(_context: Dictionary) -> void:
	_stop_error_motion()
	if is_instance_valid(shell):
		shell.dispose()


func render_view_model(view_model: AppViewModels.SettingsViewModel, animate := true) -> void:
	_view_model = view_model
	if _view_model == null:
		return
	haptics_row.configure(&"haptics_enabled", haptics_row.label.text, _view_model.haptics_enabled, animate)
	music_row.configure(&"music_enabled", music_row.label.text, _view_model.music_enabled, animate)
	sound_effects_row.configure(&"sound_effects_enabled", sound_effects_row.label.text, _view_model.sound_effects_enabled, animate)
	for row in [haptics_row, music_row, sound_effects_row]:
		row.set_interaction_enabled(not bool(_view_model.pending.get(row.setting_key, false)))
	_render_errors()


func request_close() -> void:
	if _closing:
		return
	_closing = true
	close_button.disabled = true
	_stop_error_motion()
	shell.play_close(_reduced_motion)


func active_motion_count() -> int:
	return (1 if _error_tween != null else 0) + (shell.active_motion_count() if is_instance_valid(shell) else 0)


func _open() -> void:
	_closing = false
	close_button.disabled = false
	shell.configure_shade(Color(0.0, 0.0, 0.0, 0.42))
	shell.play_open(_reduced_motion)


func _on_value_changed(key: StringName, enabled: bool) -> void:
	if _closing:
		return
	setting_changed.emit(key, enabled)


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		request_close()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_ESCAPE:
		request_close()
		get_viewport().set_input_as_handled()


func _on_shell_closed(_closed_shell: AnimatedModalShell) -> void:
	close_requested.emit()


func _render_errors() -> void:
	var messages: Array[String] = []
	for key in _view_model.error_text:
		messages.append(str(_view_model.error_text[key]))
	error_label.text = "\n".join(messages)
	error_label.visible = not messages.is_empty()
	if error_label.visible and not _reduced_motion:
		_stop_error_motion()
		error_label.modulate.a = 0.0
		_error_tween = create_tween()
		_error_tween.tween_property(error_label, "modulate:a", 1.0, 0.12)
		_error_tween.finished.connect(_stop_error_motion, CONNECT_ONE_SHOT)
	else:
		error_label.modulate.a = 1.0


func _stop_error_motion() -> void:
	if _error_tween != null and _error_tween.is_valid():
		_error_tween.kill()
	_error_tween = null


func _configure_panel() -> void:
	if not is_instance_valid(shell):
		return
	var margin := maxf(32.0, minf(56.0, size.x * 0.05))
	var panel_size := Vector2(
		minf(820.0, maxf(300.0, size.x - margin * 2.0)),
		minf(620.0, maxf(420.0, size.y - margin * 2.0)),
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("FFF8EC")
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.shadow_color = Color(0.02, 0.10, 0.13, 0.24)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	shell.configure_panel(panel_size, style, Vector4(54, 42, 54, 42))
