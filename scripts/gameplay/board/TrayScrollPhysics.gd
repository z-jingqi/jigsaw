extends RefCounted
## Estimate release velocity from a short input window, never from an old gesture.

const PuzzleRulesScript := preload("res://scripts/config/PuzzleRules.gd")

var samples: Array[Vector2] = []
var distance := 0.0
var last_motion_msec := 0
var config: Dictionary = PuzzleRulesScript.tray_layout()
var _direction := 0.0


func reset(now := Time.get_ticks_msec()) -> void:
	samples.clear()
	samples.append(Vector2(now, 0.0))
	distance = 0.0
	last_motion_msec = 0
	_direction = 0.0


func record(delta: float, now := Time.get_ticks_msec()) -> void:
	if samples.is_empty():
		samples.append(Vector2(now - 16, distance))
	if absf(delta) > 0.01:
		var direction := signf(delta)
		if _direction != 0.0 and direction != _direction:
			# A deliberate reversal must fling in its new direction, not an old one.
			var previous: Vector2 = samples.back()
			samples.assign([previous])
		_direction = direction
		last_motion_msec = now
	distance += delta
	if is_equal_approx(samples.back().x, float(now)):
		samples[-1].y = distance
	else:
		samples.append(Vector2(now, distance))
	while samples.size() > 2 and samples[1].x < now - int(config["inertia_sample_window_ms"]):
		samples.pop_front()


func release_velocity(now := Time.get_ticks_msec()) -> float:
	if samples.is_empty() or now - last_motion_msec >= int(config["inertia_stationary_ms"]):
		return 0.0
	record(0.0, now)
	var oldest := samples[0]
	var cutoff := float(now - int(config["inertia_sample_window_ms"]))
	if samples.size() > 1 and oldest.x < cutoff:
		var next := samples[1]
		var ratio := clampf((cutoff - oldest.x) / maxf(1.0, next.x - oldest.x), 0.0, 1.0)
		oldest = Vector2(cutoff, lerpf(oldest.y, next.y, ratio))
	var elapsed := maxf(1.0, now - oldest.x)
	return (distance - oldest.y) * 1000.0 / elapsed


func step(velocity: float, delta: float) -> Vector2:
	var friction := float(config["inertia_friction"])
	var decay := exp(-friction * maxf(0.0, delta))
	return Vector2(velocity * (1.0 - decay) / friction, velocity * decay)
