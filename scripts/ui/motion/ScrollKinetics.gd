class_name ScrollKinetics
extends RefCounted

## Direct manipulation while held; only release velocity is sampled/smoothed.
const SAMPLE_WINDOW := 0.10
const FRICTION := 4.8
const STOP_SPEED := 8.0
const MAX_SPEED := 6000.0

var position := 0.0
var velocity := 0.0
var held := false
var _samples: Array[Vector2] = []
var _started_usec := 0
var _last_motion_time := 0.0
var _direction := 0.0


func begin(value: float) -> void:
	stop()
	position = value
	held = true
	_started_usec = Time.get_ticks_usec()
	_samples.append(Vector2(0.0, position))


func drag_by(pointer_delta: float, minimum := -INF, maximum := INF) -> float:
	if not held:
		begin(position)
	var previous := position
	position = clampf(position - pointer_delta, minimum, maximum)
	var movement := position - previous
	var now := _time()
	if not is_zero_approx(movement):
		var direction := signf(movement)
		if _direction != 0.0 and direction != _direction:
			var last: Vector2 = _samples.back()
			_samples.assign([last])
		_direction = direction
		_last_motion_time = now
	_record(now)
	return position


func release(cancelled := false) -> float:
	if not held:
		return velocity
	held = false
	var now := _time()
	_record(now)
	velocity = 0.0
	if cancelled or now - _last_motion_time >= SAMPLE_WINDOW or _samples.size() < 2:
		return velocity
	var first: Vector2 = _samples.front()
	var elapsed := now - first.x
	if elapsed >= 0.008:
		velocity = clampf((position - first.y) / elapsed, -MAX_SPEED, MAX_SPEED)
	return velocity


func advance(delta: float, minimum: float, maximum: float) -> float:
	if held or is_zero_approx(velocity):
		return position
	var decay := exp(-FRICTION * delta)
	var target := position + velocity * (1.0 - decay) / FRICTION
	position = clampf(target, minimum, maximum)
	velocity *= decay
	if not is_equal_approx(position, target) or absf(velocity) < STOP_SPEED:
		velocity = 0.0
	return position


func stop() -> void:
	held = false
	velocity = 0.0
	_samples.clear()
	_last_motion_time = 0.0
	_direction = 0.0


func _time() -> float:
	return float(Time.get_ticks_usec() - _started_usec) / 1000000.0


func _record(now: float) -> void:
	_samples.append(Vector2(now, position))
	while _samples.size() > 2 and _samples[1].x < now - SAMPLE_WINDOW:
		_samples.pop_front()
