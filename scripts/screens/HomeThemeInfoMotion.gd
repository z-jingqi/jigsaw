class_name HomeThemeInfoMotion
extends RefCounted

const TITLE_DISTANCE := 96.0
const PROGRESS_DISTANCE := 64.0
const PAGE_DISTANCE := 48.0

var _outgoing_name: Control
var _outgoing_progress: Control
var _outgoing_page: Control
var _incoming_panel: Control
var _incoming_name: Control
var _incoming_progress: Control
var _incoming_page: Control
var _base_horizontal_offsets: Dictionary = {}
var _gesture_progress := 0.0


func _init(
	outgoing_name: Control,
	outgoing_progress: Control,
	outgoing_page: Control,
	incoming_panel: Control,
	incoming_name: Control,
	incoming_progress: Control,
	incoming_page: Control
) -> void:
	_outgoing_name = outgoing_name
	_outgoing_progress = outgoing_progress
	_outgoing_page = outgoing_page
	_incoming_panel = incoming_panel
	_incoming_name = incoming_name
	_incoming_progress = incoming_progress
	_incoming_page = incoming_page
	capture_layout()
	reset()


func capture_layout() -> void:
	_base_horizontal_offsets = {
		"outgoing_name": _horizontal_offsets(_outgoing_name),
		"outgoing_progress": _horizontal_offsets(_outgoing_progress),
		"outgoing_page": _horizontal_offsets(_outgoing_page),
		"incoming_name": _horizontal_offsets(_incoming_name),
		"incoming_progress": _horizontal_offsets(_incoming_progress),
		"incoming_page": _horizontal_offsets(_incoming_page),
	}


func apply(direction: int, progress: float, reduced_motion := false) -> void:
	if direction == 0 or progress <= 0.0:
		reset()
		return
	_gesture_progress = clampf(progress, 0.0, 1.0)
	_incoming_panel.visible = true
	_incoming_page.visible = true
	var outgoing_sign := -float(direction)
	var incoming_sign := float(direction)
	if reduced_motion:
		_restore_positions()
	else:
		_set_horizontal_shift(
			_outgoing_name, "outgoing_name", outgoing_sign * TITLE_DISTANCE * _gesture_progress
		)
		_set_horizontal_shift(
			_outgoing_progress,
			"outgoing_progress",
			outgoing_sign * PROGRESS_DISTANCE * _gesture_progress
		)
		_set_horizontal_shift(
			_outgoing_page, "outgoing_page", outgoing_sign * PAGE_DISTANCE * _gesture_progress
		)
		_set_horizontal_shift(
			_incoming_name,
			"incoming_name",
			incoming_sign * TITLE_DISTANCE * (1.0 - _gesture_progress)
		)
		_set_horizontal_shift(
			_incoming_progress,
			"incoming_progress",
			incoming_sign * PROGRESS_DISTANCE * (1.0 - _gesture_progress)
		)
		_set_horizontal_shift(
			_incoming_page,
			"incoming_page",
			incoming_sign * PAGE_DISTANCE * (1.0 - _gesture_progress)
		)
	_outgoing_name.modulate.a = 1.0 - smoothstep(0.05, 0.45, _gesture_progress)
	_outgoing_progress.modulate.a = 1.0 - smoothstep(0.12, 0.55, _gesture_progress)
	_outgoing_page.modulate.a = 1.0 - smoothstep(0.18, 0.62, _gesture_progress)
	_incoming_name.modulate.a = smoothstep(0.35, 0.72, _gesture_progress)
	_incoming_progress.modulate.a = smoothstep(0.42, 0.82, _gesture_progress)
	_incoming_page.modulate.a = smoothstep(0.50, 0.92, _gesture_progress)


func reset() -> void:
	_gesture_progress = 0.0
	_restore(_outgoing_name, "outgoing_name", 1.0)
	_restore(_outgoing_progress, "outgoing_progress", 1.0)
	_restore(_outgoing_page, "outgoing_page", 1.0)
	_restore(_incoming_name, "incoming_name", 0.0)
	_restore(_incoming_progress, "incoming_progress", 0.0)
	_restore(_incoming_page, "incoming_page", 0.0)
	_incoming_panel.visible = false
	_incoming_page.visible = false


func gesture_progress() -> float:
	return _gesture_progress


func _restore(control: Control, key: String, alpha: float) -> void:
	_set_horizontal_shift(control, key, 0.0)
	control.modulate.a = alpha


func _restore_positions() -> void:
	_set_horizontal_shift(_outgoing_name, "outgoing_name", 0.0)
	_set_horizontal_shift(_outgoing_progress, "outgoing_progress", 0.0)
	_set_horizontal_shift(_outgoing_page, "outgoing_page", 0.0)
	_set_horizontal_shift(_incoming_name, "incoming_name", 0.0)
	_set_horizontal_shift(_incoming_progress, "incoming_progress", 0.0)
	_set_horizontal_shift(_incoming_page, "incoming_page", 0.0)


func _set_horizontal_shift(control: Control, key: String, shift: float) -> void:
	var offsets := _base_horizontal_offsets.get(key, Vector2.ZERO) as Vector2
	control.offset_left = offsets.x + shift
	control.offset_right = offsets.y + shift


func _horizontal_offsets(control: Control) -> Vector2:
	return Vector2(control.offset_left, control.offset_right)
