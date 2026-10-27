extends RefCounted
## Latest-request-wins sample presentation. Geometry/UVs remain gameplay supplied.

signal stopped

const FrameGate := preload("res://scripts/runtime/CancellableFrame.gd")
const Pieces := preload("res://scripts/ui/box/BoxPieceMeshes.gd")
const HIDDEN_Y := 2.50
var phase: StringName = &"idle"
var _host: Control
var _samples: Node3D
var _tween: Tween
var _epoch := 0
var _gesture_paused := false
var _gesture_tween: Tween


func _init(host: Control, samples: Node3D) -> void:
	_host = host
	_samples = samples


func show(
	mode: StringName, data: Array, texture: Texture2D, reduced: bool, opening_ready: Callable
) -> void:
	_epoch += 1
	var token := _epoch
	_kill_tween()
	if not await _wait_gesture(token):
		return
	if _samples.get_child_count() > 0 and not reduced:
		phase = &"retracting"
		_lower(token)
		if not await _wait(token):
			return
	if not _current(token):
		return
	_clear_children()
	phase = &"waiting_for_lid"
	while _current(token) and (_gesture_paused or not bool(opening_ready.call())):
		if not await FrameGate.wait(_host.get_tree().process_frame, stopped):
			return
	if not _current(token):
		return
	_build(mode, data, texture)
	if reduced or _samples.get_child_count() == 0:
		_set_idle(token)
		return
	_emerge(mode, token)


func _emerge(mode: StringName, token: int) -> void:
	phase = &"extracting"
	_tween = _host.create_tween().set_parallel(true)
	for index in _samples.get_child_count():
		var piece := _samples.get_child(index) as Node3D
		var final := piece.transform
		var stacked: Transform3D = piece.get_meta("stack_pose")
		var delay: float = ([0.045, 0.0, 0.025, 0.060] if mode == &"swap" else [0.030, 0.0, 0.060])[index]
		var extracted := stacked
		extracted.origin.y = final.origin.y + (0.025 if mode == &"swap" else 0.045)
		var spread := final
		spread.origin.y += 0.015 if mode == &"swap" else 0.025
		piece.transform = stacked
		_pose_track(piece, stacked, extracted, 0.16, delay, Tween.EASE_OUT)
		_pose_track(piece, extracted, spread, 0.22, delay + 0.16, Tween.EASE_IN_OUT)
		_pose_track(piece, spread, final, 0.10, delay + 0.38, Tween.EASE_IN_OUT)
	_tween.tween_callback(_set_phase.bind(token, &"fanning")).set_delay(0.16)
	_tween.tween_callback(_set_phase.bind(token, &"settling")).set_delay(0.38)
	_tween.finished.connect(_set_idle.bind(token), CONNECT_ONE_SHOT)
	_pause_new_tween()


func _set_phase(token: int, value: StringName) -> void:
	if _current(token):
		phase = value


func _pose_track(
	piece: Node3D,
	start: Transform3D,
	target: Transform3D,
	duration: float,
	delay: float,
	easing: Tween.EaseType
) -> void:
	(
		_tween
		. tween_method(_apply_pose.bind(piece, start, target), 0.0, 1.0, duration)
		. set_delay(delay)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(easing)
	)


func _apply_pose(progress: float, piece: Node3D, start: Transform3D, target: Transform3D) -> void:
	if is_instance_valid(piece):
		# Transform interpolation preserves orientation through quaternion slerp,
		# unlike independently tweening Euler axes (which can flip/choose a long arc).
		piece.transform = start.interpolate_with(target, progress)


func retract(reduced: bool) -> void:
	_epoch += 1
	var token := _epoch
	_kill_tween()
	if not await _wait_gesture(token):
		return
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
	_gesture_paused = false
	_gesture_tween = null
	_epoch += 1
	_kill_tween()
	_clear_children()
	phase = &"idle"
	stopped.emit()


func gesture_pause_motion() -> void:
	if _gesture_paused:
		return
	_gesture_paused = true
	_pause_new_tween()


func gesture_resume_motion() -> void:
	_gesture_paused = false
	if _gesture_tween != null and _gesture_tween == _tween and _gesture_tween.is_valid():
		_gesture_tween.play()
	_gesture_tween = null


func _pause_new_tween() -> void:
	if _gesture_paused and _tween != null and _tween.is_valid() and _tween.is_running():
		_gesture_tween = _tween
		_tween.pause()


func _wait_gesture(token: int) -> bool:
	while _current(token) and _gesture_paused:
		if not await FrameGate.wait(_host.get_tree().process_frame, stopped):
			return false
	return _current(token)


func active_motion_count() -> int:
	return int(phase != &"idle")


func _lower(token: int) -> void:
	phase = &"gathering"
	_tween = _host.create_tween().set_parallel(true)
	var gather_end := 0.0
	for child in _samples.get_children():
		var piece := child as Node3D
		var current := piece.transform
		var gathered: Transform3D = piece.get_meta("stack_pose", current)
		# A return during the first extraction must never lift a piece to a later pose.
		gathered.origin.y = minf(current.origin.y, gathered.origin.y)
		var angle := current.basis.get_rotation_quaternion().angle_to(
			gathered.basis.get_rotation_quaternion()
		)
		var travel := maxf(current.origin.distance_to(gathered.origin) / 0.85, angle / 0.25)
		var gather_time := 0.12 * clampf(travel, 0.01, 1.0)
		var hidden := gathered
		hidden.origin.y = HIDDEN_Y
		var lower_time := 0.14 * clampf(absf(gathered.origin.y - HIDDEN_Y) / 0.30, 0.01, 1.0)
		_pose_track(piece, current, gathered, gather_time, 0.0, Tween.EASE_IN_OUT)
		_pose_track(piece, gathered, hidden, lower_time, gather_time, Tween.EASE_IN)
		gather_end = maxf(gather_end, gather_time)
	_tween.tween_callback(_set_phase.bind(token, &"retracting")).set_delay(gather_end)
	_tween.finished.connect(
		func() -> void:
			if token == _epoch:
				_tween = null,
		CONNECT_ONE_SHOT
	)

	_pause_new_tween()


func _wait(token: int) -> bool:
	# Never await Tween.finished: kill() does not emit it. Cancellation/exit must wake.
	while _current(token) and (_tween != null or _gesture_paused):
		if not await FrameGate.wait(_host.get_tree().process_frame, stopped):
			return false
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
	_gesture_tween = null
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
		piece.set_meta("stack_pose", _stack_pose(piece, index, order.size()))


func _stack_pose(piece: MeshInstance3D, index: int, count: int) -> Transform3D:
	var center := 1
	var stack_basis := (
		Basis(Vector3.BACK, deg_to_rad(float(index - center))) * Basis(Vector3.RIGHT, PI / 2)
	)
	var top_extent := 0.0
	if piece.mesh != null:
		var bounds := piece.mesh.get_aabb()
		for corner in 8:
			top_extent = maxf(top_extent, (stack_basis * bounds.get_endpoint(corner)).y)
	var position := Vector3(
		(float(index) - float(count - 1) * 0.5) * 0.035,
		3.035 - top_extent,
		0.06 if index == center else float(index - center) * 0.035 - 0.02
	)
	return Transform3D(stack_basis, position)
