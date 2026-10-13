extends RefCounted
## Fits oversized tray pieces, then restores their board size around the grab point.

var scale := 1.0
var target := 1.0
var _tray_scale := 1.0
var _velocity := 0.0
var _active := false


func begin(local_scale: float) -> void:
	scale = clampf(local_scale, 0.001, 1.0)
	_tray_scale = scale
	target = scale
	_velocity = 0.0
	_active = true


func set_lifted(lifted: bool, reduced_motion: bool) -> void:
	target = 1.0 if lifted else _tray_scale
	if reduced_motion:
		scale = target
		_velocity = 0.0


func step(delta: float, settle_time: float, reduced_motion: bool) -> bool:
	if not _active:
		return false
	var previous := scale
	if reduced_motion:
		scale = target
		_velocity = 0.0
	else:
		var frequency := 6.64 / maxf(0.01, settle_time)
		var displacement := scale - target
		var coefficient := _velocity + frequency * displacement
		var decay := exp(-frequency * maxf(0.0, delta))
		scale = target + (displacement + coefficient * delta) * decay
		_velocity = (_velocity - frequency * coefficient * delta) * decay
		if absf(scale - target) < 0.0001 and absf(_velocity) < 0.001:
			scale = target
			_velocity = 0.0
	return not is_equal_approx(previous, scale)


func reset() -> void:
	_active = false
	scale = 1.0
	target = 1.0
	_velocity = 0.0
