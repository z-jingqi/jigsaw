extends RefCounted
## Estimate release velocity from a short input window, never from an old gesture.

const SAMPLE_WINDOW_MS := 100
const STATIONARY_MS := 80
const FRICTION := 9.0

var samples: Array[Vector2] = []
var distance := 0.0
var last_motion_msec := 0


func reset() -> void:
	samples.clear()
	distance = 0.0
	last_motion_msec = 0


func record(delta: float, now := Time.get_ticks_msec()) -> void:
	if samples.is_empty():
		samples.append(Vector2(now - 16, distance))
	distance += delta
	if absf(delta) > 0.01:
		last_motion_msec = now
	samples.append(Vector2(now, distance))
	while samples.size() > 2 and samples[1].x < now - SAMPLE_WINDOW_MS:
		samples.pop_front()


func release_velocity(now := Time.get_ticks_msec()) -> float:
	if samples.is_empty() or now - last_motion_msec >= STATIONARY_MS:
		return 0.0
	record(0.0, now)
	var oldest := samples[0]
	var elapsed := maxf(1.0, now - oldest.x)
	return (distance - oldest.y) * 1000.0 / elapsed


func step(velocity: float, delta: float) -> Vector2:
	var decay := exp(-FRICTION * maxf(0.0, delta))
	return Vector2(velocity * (1.0 - decay) / FRICTION, velocity * decay)
