class_name ModeTutorialModal
extends Control

signal completed()
signal skipped()
signal dismissed()

@onready var shell: AnimatedModalShell = $ModalShell
@onready var title_label: Label = $ModalShell/Panel/Content/Title
@onready var demo: Label = $ModalShell/Panel/Content/Demo
@onready var description: Label = $ModalShell/Panel/Content/Description
@onready var skip_button: Button = $ModalShell/Panel/Content/Actions/Skip
@onready var confirm_button: Button = $ModalShell/Panel/Content/Actions/Confirm

var _reduced_motion := false
var _outcome := &"dismissed"
var _demo_motion: Tween


func _ready() -> void:
	skip_button.pressed.connect(_skip)
	confirm_button.pressed.connect(_complete)
	shell.closed.connect(_on_shell_closed)
	resized.connect(_configure_panel)
	_configure_panel()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_reduced_motion = bool(context.get("reduced_motion", false))
	var model: Variant = payload.get("view_model", null)
	title_label.text = str(payload.get("title", "How to play"))
	description.text = str(model.description) if model != null else ""
	skip_button.text = str(payload.get("skip_text", "Skip"))
	confirm_button.text = str(payload.get("confirm_text", "Got it"))
	demo.text = "▣  →  ◎" if str(payload.get("mode", "")) != "swap" else "▣  ⇄  ▣"
	shell.play_open(_reduced_motion)
	_play_demo()


func navigation_exit(_context: Dictionary) -> void:
	_stop_demo()
	if is_instance_valid(shell):
		shell.dispose()


func request_dismiss() -> void:
	_close(&"dismissed")


func active_motion_count() -> int:
	return (shell.active_motion_count() if is_instance_valid(shell) else 0) + (1 if _demo_motion != null and _demo_motion.is_valid() else 0)


func _complete() -> void:
	_close(&"completed")


func _skip() -> void:
	_close(&"skipped")


func _close(outcome: StringName) -> void:
	if _outcome != &"dismissed" or not is_instance_valid(shell):
		return
	_outcome = outcome
	_stop_demo()
	skip_button.disabled = true
	confirm_button.disabled = true
	shell.play_close(_reduced_motion)


func _on_shell_closed(_closed_shell: AnimatedModalShell) -> void:
	match _outcome:
		&"completed": completed.emit()
		&"skipped": skipped.emit()
		_: dismissed.emit()


func _play_demo() -> void:
	_stop_demo()
	if _reduced_motion:
		return
	demo.pivot_offset = demo.size * 0.5
	_demo_motion = create_tween()
	_demo_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for _index in 2:
		_demo_motion.tween_property(demo, "position:x", 12.0, 0.24)
		_demo_motion.tween_property(demo, "position:x", 0.0, 0.24)
	_demo_motion.finished.connect(_stop_demo, CONNECT_ONE_SHOT)


func _stop_demo() -> void:
	if _demo_motion != null and _demo_motion.is_valid():
		_demo_motion.kill()
	_demo_motion = null


func _configure_panel() -> void:
	if not is_instance_valid(shell):
		return
	var width := minf(520.0, maxf(280.0, size.x - 40.0))
	var height := minf(430.0, maxf(300.0, size.y - 40.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("FFF9EC")
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.shadow_color = Color(0.02, 0.10, 0.13, 0.24)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	shell.configure_panel(Vector2(width, height), style, Vector4(28, 28, 28, 28))
