class_name HomeCoverMotion
extends RefCounted

const OUTGOING_DEPTH_SCALE := 0.008
const INCOMING_START_SCALE := 1.03
const OUTGOING_END_ALPHA := 0.82
const INCOMING_START_ALPHA := 0.82

var _previous: TextureRect
var _current: TextureRect
var _next: TextureRect


func _init(previous: TextureRect, current: TextureRect, next: TextureRect) -> void:
	_previous = previous
	_current = current
	_next = next
	reset()


func apply(direction: int, progress: float, reduced_motion := false) -> void:
	reset()
	if direction == 0 or progress <= 0.0:
		return
	var amount := clampf(progress, 0.0, 1.0)
	var incoming := _next if direction > 0 else _previous
	if not reduced_motion:
		var outgoing_scale := 1.0 - sin(amount * PI) * OUTGOING_DEPTH_SCALE
		_current.scale = Vector2.ONE * outgoing_scale
		incoming.scale = Vector2.ONE * lerpf(INCOMING_START_SCALE, 1.0, amount)
	_current.modulate.a = lerpf(1.0, OUTGOING_END_ALPHA, amount)
	incoming.modulate.a = lerpf(INCOMING_START_ALPHA, 1.0, amount)


func reset() -> void:
	for cover in [_previous, _current, _next]:
		cover.scale = Vector2.ONE
		cover.modulate.a = 1.0
