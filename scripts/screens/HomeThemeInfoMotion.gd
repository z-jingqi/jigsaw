class_name HomeThemeInfoMotion
extends RefCounted

## Crossfades the title and card-attached progress tag while the carousel is dragged.
## The outgoing and incoming copies move as whole groups rather than per-field.
const SHIFT_DISTANCE := 72.0

var _outgoing: Control
var _incoming: Control
var _outgoing_base := 0.0
var _incoming_base := 0.0
var _gesture_progress := 0.0


func _init(outgoing: Control, incoming: Control) -> void:
	_outgoing = outgoing
	_incoming = incoming
	capture_layout()
	reset()


func capture_layout() -> void:
	_outgoing_base = _outgoing.position.x
	_incoming_base = _incoming.position.x


func apply(direction: int, progress: float, reduced_motion := false) -> void:
	if direction == 0 or progress <= 0.0:
		reset()
		return
	_gesture_progress = clampf(progress, 0.0, 1.0)
	_incoming.visible = true
	if reduced_motion:
		_outgoing.position.x = _outgoing_base
		_incoming.position.x = _incoming_base
	else:
		var travel := SHIFT_DISTANCE * float(direction)
		_outgoing.position.x = _outgoing_base - travel * _gesture_progress
		_incoming.position.x = _incoming_base + travel * (1.0 - _gesture_progress)
	_outgoing.modulate.a = 1.0 - smoothstep(0.05, 0.5, _gesture_progress)
	_incoming.modulate.a = smoothstep(0.35, 0.72, _gesture_progress)


func reset() -> void:
	_gesture_progress = 0.0
	_outgoing.position.x = _outgoing_base
	_incoming.position.x = _incoming_base
	_outgoing.modulate.a = 1.0
	_incoming.modulate.a = 0.0
	_incoming.visible = false


func gesture_progress() -> float:
	return _gesture_progress
