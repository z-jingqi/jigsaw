class_name GameplayPausePanel
extends Control
## Lightweight gameplay pause actions; navigation remains owned by the coordinator.

signal resume_requested
signal exit_requested

@onready var shell: AnimatedModalShell = $ModalShell
@onready var resume_button: Button = $ModalShell/Panel/Content/Resume
@onready var exit_button: Button = $ModalShell/Panel/Content/Exit

var _reduced_motion := false
var _outcome := &"idle"


func _ready() -> void:
	resume_button.pressed.connect(_close.bind(&"resume"))
	exit_button.pressed.connect(_close.bind(&"exit"))
	shell.closed.connect(_on_shell_closed)
	resized.connect(_configure_panel)
	_style_actions()
	_configure_panel()


func navigation_enter(_payload: Dictionary, context: Dictionary) -> void:
	_reduced_motion = bool(context.get("reduced_motion", false))
	_outcome = &"idle"
	shell.configure_shade(Color(0.05, 0.16, 0.14, 0.28))
	shell.play_open(_reduced_motion)


func navigation_exit(_context: Dictionary) -> void:
	if is_instance_valid(shell):
		shell.dispose()


func request_dismiss() -> void:
	_close(&"resume")


func active_motion_count() -> int:
	return shell.active_motion_count() if is_instance_valid(shell) else 0


func _close(outcome: StringName) -> void:
	if _outcome != &"idle" or not is_instance_valid(shell):
		return
	_outcome = outcome
	resume_button.disabled = true
	exit_button.disabled = true
	shell.play_close(_reduced_motion)


func _on_shell_closed(_closed_shell: AnimatedModalShell) -> void:
	if _outcome == &"exit":
		exit_requested.emit()
	else:
		resume_requested.emit()


func _configure_panel() -> void:
	if not is_instance_valid(shell):
		return
	var width := minf(620.0, maxf(320.0, size.x - 48.0))
	var height := minf(520.0, maxf(360.0, size.y - 48.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("FFF9EC")
	style.border_color = Color("194F47")
	style.set_border_width_all(2)
	style.set_corner_radius_all(30)
	shell.configure_panel(Vector2(width, height), style, Vector4(54, 48, 54, 48))


func _style_actions() -> void:
	var filled := _button_style(Color("194F47"), Color("194F47"), 0)
	var filled_hover := _button_style(Color("25665C"), Color("25665C"), 0)
	var outline := _button_style(Color.TRANSPARENT, Color("194F47"), 2)
	var outline_hover := _button_style(Color("E7F0E8"), Color("194F47"), 2)
	for state in [&"normal", &"focus"]:
		resume_button.add_theme_stylebox_override(state, filled)
		exit_button.add_theme_stylebox_override(state, outline)
	resume_button.add_theme_stylebox_override(&"hover", filled_hover)
	resume_button.add_theme_stylebox_override(&"pressed", filled_hover)
	exit_button.add_theme_stylebox_override(&"hover", outline_hover)
	exit_button.add_theme_stylebox_override(&"pressed", outline_hover)


func _button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(22)
	return style
