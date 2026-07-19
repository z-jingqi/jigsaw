extends RefCounted
class_name GameUiMotion

var host: Node
var progress_store
var button_tweens: Dictionary = {}


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
	button.pivot_offset = button.size * 0.5
	button.button_down.connect(func() -> void:
		_animate_button_press(button)
	)
	button.button_up.connect(func() -> void:
		_animate_button_release(button)
	)
	button.mouse_exited.connect(func() -> void:
		_animate_button_cancel(button)
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


func _animate_button_press(button: BaseButton) -> void:
	_kill_button_tween(button)
	if reduced():
		button.scale = Vector2.ONE
		return
	var kind := str(button.get_meta("button_motion_kind", "default"))
	var scale_value := 0.97 if kind == "primary" else (0.92 if kind == "settings" else 0.96)
	var tween := host.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(scale_value, scale_value), 0.07)
	var icon := button.get_node_or_null("icon") as Control
	if icon != null and kind == "settings":
		tween.tween_property(icon, "rotation", deg_to_rad(12.0), 0.07)
	elif icon != null and kind == "direction":
		var direction := float(button.get_meta("direction_sign", 1.0))
		button.set_meta("motion_icon_origin_x", icon.position.x)
		tween.tween_property(icon, "position:x", icon.position.x + 4.0 * direction * _button_scale(button), 0.07)
	button_tweens[button.get_instance_id()] = tween


func _animate_button_release(button: BaseButton) -> void:
	_kill_button_tween(button)
	var kind := str(button.get_meta("button_motion_kind", "default"))
	var icon := button.get_node_or_null("icon") as Control
	if reduced():
		button.scale = Vector2.ONE
		_reset_special_icon(button, icon)
		return
	var overshoot := 1.01 if kind == "primary" else 1.015
	var tween := host.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(overshoot, overshoot), 0.08)
	tween.tween_property(button, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_CUBIC)
	if icon != null and kind == "settings":
		tween.parallel().tween_property(icon, "rotation", 0.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif icon != null and kind == "direction":
		var origin_x := float(button.get_meta("motion_icon_origin_x", icon.position.x))
		tween.parallel().tween_property(icon, "position:x", origin_x, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	button_tweens[button.get_instance_id()] = tween
	tween.finished.connect(func() -> void: button_tweens.erase(button.get_instance_id()))


func _animate_button_cancel(button: BaseButton) -> void:
	if not button.button_pressed:
		return
	_kill_button_tween(button)
	var icon := button.get_node_or_null("icon") as Control
	if reduced():
		button.scale = Vector2.ONE
		_reset_special_icon(button, icon)
		return
	var tween := host.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.10)
	if icon != null:
		if str(button.get_meta("button_motion_kind", "")) == "settings":
			tween.tween_property(icon, "rotation", 0.0, 0.10)
		elif button.has_meta("motion_icon_origin_x"):
			tween.tween_property(icon, "position:x", float(button.get_meta("motion_icon_origin_x")), 0.10)
	button_tweens[button.get_instance_id()] = tween


func _reset_special_icon(button: BaseButton, icon: Control) -> void:
	if icon == null:
		return
	icon.rotation = 0.0
	if button.has_meta("motion_icon_origin_x"):
		icon.position.x = float(button.get_meta("motion_icon_origin_x"))


func _kill_button_tween(button: BaseButton) -> void:
	var key := button.get_instance_id()
	var active = button_tweens.get(key, null)
	if active is Tween and active.is_valid():
		active.kill()
	button_tweens.erase(key)


func _button_scale(button: BaseButton) -> float:
	return maxf(1.0, button.size.x / 112.0)
