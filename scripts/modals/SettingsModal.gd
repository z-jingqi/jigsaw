class_name SettingsModal
extends Control

signal setting_changed(key: StringName, enabled: bool)
signal close_requested

@onready var shell: AnimatedModalShell = $ModalShell
@onready var title_label: Label = $ModalShell/Panel/Content/Header/Title
@onready var close_button: Button = $ModalShell/Panel/Content/Header/Close
@onready var music_row: SettingsRow = $ModalShell/Panel/Content/Rows/Music
@onready var sound_effects_row: SettingsRow = $ModalShell/Panel/Content/Rows/SoundEffects
@onready var haptics_row: SettingsRow = $ModalShell/Panel/Content/Rows/Haptics
@onready var reduced_motion_row: SettingsRow = $ModalShell/Panel/Content/Rows/ReducedMotion
@onready var error_label: Label = $ModalShell/Panel/Content/Error

var _view_model: AppViewModels.SettingsViewModel
var _reduced_motion := false
var _closing := false
var _error_tween: Tween


func _ready() -> void:
	close_button.pressed.connect(request_close)
	music_row.value_changed.connect(_on_value_changed)
	sound_effects_row.value_changed.connect(_on_value_changed)
	haptics_row.value_changed.connect(_on_value_changed)
	reduced_motion_row.value_changed.connect(_on_value_changed)
	shell.shade.gui_input.connect(_on_shade_input)
	shell.closed.connect(_on_shell_closed)
	resized.connect(_configure_panel)
	_style_close_button()
	reduced_motion_row.set_divider_visible(false)
	_configure_panel()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_reduced_motion = bool(context.get("reduced_motion", false))
	_view_model = payload.get("view_model", null) as AppViewModels.SettingsViewModel
	if _view_model == null:
		return
	var labels: Dictionary = payload.get("labels", {})
	title_label.text = str(labels.get("title", "Settings"))
	music_row.configure(
		&"music_enabled", str(labels.get("music", "Music")), _view_model.music_enabled
	)
	sound_effects_row.configure(
		&"sound_effects_enabled",
		str(labels.get("sound_effects", "Sound effects")),
		_view_model.sound_effects_enabled
	)
	haptics_row.configure(
		&"haptics_enabled", str(labels.get("haptics", "Haptics")), _view_model.haptics_enabled
	)
	reduced_motion_row.configure(
		&"reduced_motion_enabled",
		str(labels.get("reduced_motion", "Reduce motion")),
		_view_model.reduced_motion_enabled
	)
	set_reduced_motion(_reduced_motion)
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
	music_row.configure(&"music_enabled", music_row.label.text, _view_model.music_enabled, animate)
	sound_effects_row.configure(
		&"sound_effects_enabled",
		sound_effects_row.label.text,
		_view_model.sound_effects_enabled,
		animate
	)
	haptics_row.configure(
		&"haptics_enabled", haptics_row.label.text, _view_model.haptics_enabled, animate
	)
	reduced_motion_row.configure(
		&"reduced_motion_enabled",
		reduced_motion_row.label.text,
		_view_model.reduced_motion_enabled,
		animate
	)
	for row in _settings_rows():
		row.set_interaction_enabled(not bool(_view_model.pending.get(row.setting_key, false)))
	_render_errors()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	for row in _settings_rows():
		row.set_reduced_motion(enabled)


func request_close() -> void:
	if _closing:
		return
	_closing = true
	close_button.disabled = true
	_stop_error_motion()
	shell.play_close(_reduced_motion)


func active_motion_count() -> int:
	var result := 1 if _error_tween != null else 0
	result += shell.active_motion_count() if is_instance_valid(shell) else 0
	for row in _settings_rows():
		result += row.active_motion_count()
	return result


func _open() -> void:
	_closing = false
	close_button.disabled = false
	shell.configure_shade(Color(0.31, 0.16, 0.08, 0.18))
	shell.play_open(_reduced_motion)


func _on_value_changed(key: StringName, enabled: bool) -> void:
	if _closing:
		return
	setting_changed.emit(key, enabled)


func _on_shade_input(event: InputEvent) -> void:
	if (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	):
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
	var horizontal_margin := maxf(84.0, size.x * 0.09)
	var vertical_margin := maxf(120.0, size.y * 0.08)
	var panel_size := Vector2(
		minf(960.0, maxf(720.0, size.x - horizontal_margin * 2.0)),
		minf(1080.0, maxf(940.0, size.y - vertical_margin * 2.0)),
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("FFF4E2")
	style.corner_radius_top_left = 58
	style.corner_radius_top_right = 58
	style.corner_radius_bottom_left = 58
	style.corner_radius_bottom_right = 58
	style.corner_detail = 20
	style.anti_aliasing = true
	style.shadow_color = Color(0.30, 0.14, 0.06, 0.22)
	style.shadow_size = 20
	style.shadow_offset = Vector2(10, 14)
	shell.configure_panel(panel_size, style, Vector4(72, 54, 72, 46))


func _style_close_button() -> void:
	var normal := _close_style(Color("D35929"), Color(0.30, 0.14, 0.06, 0.26), 8)
	var hover := _close_style(Color("D9683C"), Color(0.30, 0.14, 0.06, 0.28), 9)
	var pressed := _close_style(Color("C94C20"), Color(0.30, 0.14, 0.06, 0.18), 4)
	var disabled := _close_style(Color("D8A084"), Color(0.30, 0.14, 0.06, 0.10), 4)
	close_button.add_theme_stylebox_override("normal", normal)
	close_button.add_theme_stylebox_override("hover", hover)
	close_button.add_theme_stylebox_override("pressed", pressed)
	close_button.add_theme_stylebox_override("focus", normal.duplicate())
	close_button.add_theme_stylebox_override("disabled", disabled)


func _close_style(fill: Color, shadow: Color, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = 34
	style.corner_radius_top_right = 34
	style.corner_radius_bottom_left = 34
	style.corner_radius_bottom_right = 34
	style.corner_detail = 16
	style.anti_aliasing = true
	style.shadow_color = shadow
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(4, 7)
	return style


func _settings_rows() -> Array[SettingsRow]:
	return [music_row, sound_effects_row, haptics_row, reduced_motion_row]
