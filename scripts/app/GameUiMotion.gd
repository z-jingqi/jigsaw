extends RefCounted
class_name GameUiMotion

var host: Node
var progress_store


func _init(owner: Node, player_progress) -> void:
	host = owner
	progress_store = player_progress


func reduced() -> bool:
	return progress_store.reduced_motion_enabled()


func fade_control_in(control: Control) -> void:
	if reduced():
		control.modulate.a = 1.0
		return
	control.modulate.a = 0.0
	var tween := host.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "modulate:a", 1.0, 0.24)


func animate_modal_panel(panel: Control) -> void:
	if reduced():
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE
		return
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.965, 0.965)
	await host.get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	var tween := host.create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func wire_button(button: BaseButton) -> void:
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.button_down.connect(func() -> void:
		tween_control_scale(button, Vector2(0.95, 0.95), 0.08)
	)
	button.button_up.connect(func() -> void:
		tween_control_scale(button, Vector2.ONE, 0.12)
	)
	button.mouse_exited.connect(func() -> void:
		tween_control_scale(button, Vector2.ONE, 0.12)
	)


func tween_control_scale(control: Control, target: Vector2, duration: float) -> void:
	if not is_instance_valid(control):
		return
	if reduced():
		control.scale = target
		return
	var tween := host.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "scale", target, duration)
