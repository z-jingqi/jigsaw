extends RefCounted
## Latest-request-wins sample presentation. Geometry/UVs remain gameplay supplied.

signal stopped

const Pieces := preload("res://scripts/ui/box/BoxPieceMeshes.gd")
const HIDDEN_Y := 2.50
var phase: StringName = &"idle"
var _host: Control
var _samples: Node3D
var _tween: Tween
var _epoch := 0


func _init(host: Control, samples: Node3D) -> void:
	_host = host
	_samples = samples


func show(
	mode: StringName, data: Array, texture: Texture2D, reduced: bool, opening_ready: Callable
) -> void:
	_epoch += 1
	var token := _epoch
	_kill_tween()
	if _samples.get_child_count() > 0 and not reduced:
		phase = &"retracting"
		_lower(token)
		if not await _wait(token):
			return
	if not _current(token):
		return
	_clear_children()
	phase = &"waiting_for_lid"
	while _current(token) and not bool(opening_ready.call()):
		await _host.get_tree().process_frame
	if not _current(token):
		return
	_build(mode, data, texture)
	if reduced or _samples.get_child_count() == 0:
		_set_idle(token)
		return
	phase = &"emerging"
	_tween = _host.create_tween().set_parallel(true)
	for index in _samples.get_child_count():
		var piece := _samples.get_child(index) as Node3D
		var final_y := piece.position.y
		var delay := float(index) * 0.045
		var overshoot := 0.025 if mode == &"swap" else 0.045
		piece.position.y = HIDDEN_Y
		(
			_tween
			. tween_property(piece, "position:y", final_y + overshoot, 0.30)
			. set_delay(delay)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
		(
			_tween
			. tween_property(piece, "position:y", final_y, 0.14)
			. from(final_y + overshoot)
			. set_delay(delay + 0.30)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)
	_tween.finished.connect(_set_idle.bind(token), CONNECT_ONE_SHOT)


func retract(reduced: bool) -> void:
	_epoch += 1
	var token := _epoch
	_kill_tween()
	if reduced or _samples.get_child_count() == 0:
		_clear_children()
		_set_idle(token)
		return
	phase = &"retracting"
	_lower(token)
	if await _wait(token):
		_clear_children()
		_set_idle(token)


func cancel() -> void:
	_epoch += 1
	_kill_tween()
	_clear_children()
	phase = &"idle"
	stopped.emit()


func active_motion_count() -> int:
	return int(phase != &"idle")


func _lower(token: int) -> void:
	_tween = _host.create_tween().set_parallel(true)
	for child in _samples.get_children():
		var duration := 0.24 * clampf(absf(child.position.y - HIDDEN_Y) / 0.78, 0.004, 1.0)
		(
			_tween
			. tween_property(child, "position:y", HIDDEN_Y, duration)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN)
		)
	_tween.finished.connect(
		func() -> void:
			if token == _epoch:
				_tween = null,
		CONNECT_ONE_SHOT
	)


func _wait(token: int) -> bool:
	# Never await Tween.finished: kill() does not emit it. Cancellation/exit must wake.
	while _current(token) and _tween != null:
		await _host.get_tree().process_frame
	return _current(token)


func _current(token: int) -> bool:
	return token == _epoch and is_instance_valid(_host) and _host.is_inside_tree()


func _set_idle(token: int) -> void:
	if token != _epoch:
		return
	_tween = null
	phase = &"idle"
	stopped.emit()


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _clear_children() -> void:
	if is_instance_valid(_samples):
		for child in _samples.get_children():
			child.free()


func _build(mode: StringName, data: Array, texture: Texture2D) -> void:
	_samples.position = Vector3.ZERO
	var order: Array = [2, 0, 3, 1] if mode == &"swap" else [0, 1, 2]
	for index in order.size():
		var source_index: int = order[index]
		if source_index >= data.size():
			continue
		var source: Dictionary = data[source_index]
		var piece := Pieces.textured_polygon(
			PackedVector2Array(source.get("polygon", [])),
			PackedVector2Array(source.get("uv", [])),
			texture,
			0.53 if mode == &"swap" else 0.78
		)
		if mode == &"swap":
			piece.position = Vector3(
				(float(index) - 1.5) * 0.55, [3.14, 3.18, 3.15, 3.19][index], 0
			)
			piece.rotation.x = PI / 2
		else:
			var x: float = [-0.64, 0.02, 0.63][index]
			var y: float = [3.13, 3.27, 3.18][index]
			var z: float = [0.02, -0.055, 0.04][index]
			if mode == &"knob":
				x += [0.02, 0.01, 0.02][index]
				y += [0.02, 0.01, 0.0][index]
			piece.position = Vector3(x, y, z)
			# XZ source mesh faces the camera after X rotation. Apply roll in world Z
			# afterward: default YXZ Euler would turn this into yaw instead.
			piece.basis = (
				Basis(Vector3.BACK, deg_to_rad([-8.0, 6.0, -5.0][index]))
				* Basis(Vector3.RIGHT, deg_to_rad([84.0, 94.0, 87.0][index]))
			)
		_samples.add_child(piece)
