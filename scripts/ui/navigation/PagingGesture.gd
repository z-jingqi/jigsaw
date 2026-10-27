extends RefCounted
## Shared release policy; coordinates and velocity are measured in native pixels.
var origin := 0.0
var origin_page := 0
var axis := 0  # 0 undecided, 1 horizontal, 2 rejected vertical
var start := Vector2.ZERO
var delta := Vector2.ZERO
var _samples: Array[Vector2] = []
var _native := 1.0
var _width := 1.0
var _last_page := 0


func begin(point: Vector2, visual: float, width: float, native: float, count: int) -> void:
	origin = visual
	_last_page = maxi(0, count - 1)
	origin_page = clampi(roundi(visual), 0, _last_page)
	axis = 0
	start = point
	delta = Vector2.ZERO
	_native = maxf(native, 0.001)
	_width = maxf(width, 1.0)
	_samples = [Vector2(float(Time.get_ticks_msec()), 0)]


func move(point: Vector2) -> float:
	delta = point - start
	if axis == 0 and delta.length() >= 12 * _native:
		axis = 1 if absf(delta.x) > absf(delta.y) else 2
	var now := float(Time.get_ticks_msec())
	_samples.append(Vector2(now, delta.x / _native))
	while _samples.size() > 1 and now - _samples[0].x > 100:
		_samples.pop_front()
	var value := origin - delta.x / _width
	# Finite resistance, asymptotically limited to 0.12 of a page.
	if value < 0:
		value = -0.12 * (1.0 - exp(value / 0.12))
	elif value > _last_page:
		value = _last_page + 0.12 * (1.0 - exp(-(value - _last_page) / 0.12))
	return value


func release_target(point: Vector2) -> int:
	move(point)
	if axis != 1:
		return origin_page
	var velocity := 0.0
	if _samples.size() > 1:
		var first := _samples[0]
		var last := _samples.back() as Vector2
		velocity = (last.y - first.y) * 1000.0 / maxf(1.0, last.x - first.x)
	var distance_pass := absf(delta.x) >= _width * 0.28
	var fling_pass := (
		absf(delta.x) >= 45.0 * _native
		and absf(velocity) >= 700.0
		and signf(velocity) == signf(delta.x)
	)
	if distance_pass or fling_pass:
		return clampi(origin_page + (1 if delta.x < 0 else -1), 0, _last_page)
	return origin_page
