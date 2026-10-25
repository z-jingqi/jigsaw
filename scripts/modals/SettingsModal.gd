class_name SettingsModal
extends Control

signal setting_changed(key: StringName, enabled: bool)
signal close_requested

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")

@onready var shell: AnimatedModalShell = $ModalShell
@onready var title_label: Label = $ModalShell/Panel/Content/Header/Title
@onready var close_button: Button = $ModalShell/Panel/Content/Header/Close
@onready var music_row: SettingsRow = $ModalShell/Panel/Content/Rows/Music
@onready var sound_effects_row: SettingsRow = $ModalShell/Panel/Content/Rows/SoundEffects
@onready var haptics_row: SettingsRow = $ModalShell/Panel/Content/Rows/Haptics
@onready var snap_preview_row: SettingsRow = $ModalShell/Panel/Content/Rows/SnapPreview
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
	snap_preview_row.value_changed.connect(_on_value_changed)
	reduced_motion_row.value_changed.connect(_on_value_changed)
	shell.shade.gui_input.connect(_on_shade_input)
	shell.closed.connect(_on_shell_closed)
	resized.connect(_configure_panel)
	(title_label.get_parent() as Control).resized.connect(_layout_navigation)
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
	snap_preview_row.configure(
		&"snap_preview_enabled",
		str(labels.get("snap_preview", "Snap preview")),
		_view_model.snap_preview_enabled
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
	snap_preview_row.configure(
		&"snap_preview_enabled",
		snap_preview_row.label.text,
		_view_model.snap_preview_enabled,
		animate
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
	shell.configure_shade(Color(0.15, 0.16, 0.14, 0.24))
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
	var portrait := size.x < size.y
	var unit := (
		minf(size.x / 390.0, size.y / 700.0) if portrait else minf(size.x / 844.0, size.y / 390.0)
	)
	var panel_size := Vector2(340, 514) * unit if portrait else Vector2(660, 356) * unit
	var style := StyleBoxFlat.new()
	style.bg_color = Clean.PAPER
	style.set_corner_radius_all(roundi(24 * unit))
	style.corner_detail = 20
	style.anti_aliasing = true
	shell.configure_panel(panel_size, style, Vector4(24, 20, 24, 20) * unit)
	var header := title_label.get_parent() as Control
	header.custom_minimum_size.y = 64 * unit
	Clean.label(title_label, roundi(28 * unit))
	error_label.add_theme_font_size_override("font_size", maxi(13, roundi(13 * unit)))
	error_label.custom_minimum_size.y = 30 * unit
	_layout_navigation.call_deferred()
	var rows := music_row.get_parent() as GridContainer
	rows.columns = 1 if portrait else 2
	rows.add_theme_constant_override("h_separation", roundi(24 * unit))
	rows.add_theme_constant_override("v_separation", roundi(8 * unit))
	for row in _settings_rows():
		row.set_visual_scale(unit)
		row.set_divider_visible(false)


func _layout_navigation() -> void:
	if not is_node_ready():
		return
	Buttons.place_navigation(close_button, shell.panel, true, 0, size)
	var header := title_label.get_parent() as Control
	var title_shift := close_button.position.y + close_button.size.y * 0.5 - header.size.y * 0.5
	title_label.offset_top = title_shift
	title_label.offset_bottom = title_shift


func _style_close_button() -> void:
	close_button.text = ""


func _settings_rows() -> Array[SettingsRow]:
	return [music_row, sound_effects_row, haptics_row, snap_preview_row, reduced_motion_row]
