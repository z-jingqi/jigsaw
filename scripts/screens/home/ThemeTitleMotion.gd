extends RefCounted
## Projects the deck's live browsing progress onto the title presentation.

const HELD_MIN_ALPHA := 0.18

var _current_label: Label
var _incoming_label: Label
var _ornaments: Array[Control]
var _apply_layout: Callable
var _current_title := ""
var _incoming_title := ""
var _outgoing_progress := 0.0
var _incoming_progress := 0.0
var _committed := false
var _reduced_motion := false
var _ornament_starts: Array[Vector2] = []
var _ornament_targets: Array[Vector2] = []


func _init(
	current_label: Label, incoming_label: Label, ornaments: Array[Control], apply_layout: Callable
) -> void:
	_current_label = current_label
	_incoming_label = incoming_label
	_ornaments = ornaments
	_apply_layout = apply_layout


func set_current(current_title: String, incoming_title: String) -> void:
	_outgoing_progress = 0.0
	_incoming_progress = 0.0
	_committed = false
	_reduced_motion = false
	_set_titles(current_title, incoming_title)
	_apply_visual_state()


func apply_progress(
	current_title: String,
	incoming_title: String,
	outgoing_progress: float,
	incoming_progress: float,
	committed: bool,
	reduced_motion: bool
) -> void:
	_outgoing_progress = clampf(outgoing_progress, 0.0, 1.0)
	_incoming_progress = clampf(incoming_progress, 0.0, 1.0)
	_committed = committed
	_reduced_motion = reduced_motion
	_set_titles(current_title, incoming_title)
	_apply_visual_state()


func relayout() -> void:
	_set_titles(_current_title, _incoming_title, true)
	_apply_visual_state()


func _set_titles(current_title: String, incoming_title: String, force := false) -> void:
	if not force and current_title == _current_title and incoming_title == _incoming_title:
		return
	_current_title = current_title
	_incoming_title = incoming_title
	_current_label.text = current_title
	_incoming_label.text = incoming_title
	_apply_layout.call()
	_capture_ornament_positions()


func _capture_ornament_positions() -> void:
	_ornament_starts.clear()
	_ornament_targets.clear()
	if _ornaments.size() < 2:
		return
	var left := _ornaments[0]
	var right := _ornaments[1]
	_ornament_starts.assign([left.position, right.position])
	var left_gap := _current_label.position.x - (left.position.x + left.size.x)
	var right_gap := right.position.x - (_current_label.position.x + _current_label.size.x)
	_ornament_targets.assign(
		[
			Vector2(_incoming_label.position.x - left.size.x - left_gap, left.position.y),
			Vector2(
				_incoming_label.position.x + _incoming_label.size.x + right_gap, right.position.y
			)
		]
	)


func _apply_visual_state() -> void:
	if _reduced_motion:
		_current_label.modulate.a = 1.0
		_incoming_label.modulate.a = 0.0
		_restore_ornaments()
		return
	var minimum_alpha := 0.0 if _committed else HELD_MIN_ALPHA
	_current_label.modulate.a = maxf(minimum_alpha, 1.0 - _outgoing_progress)
	_incoming_label.modulate.a = _incoming_progress if _committed else 0.0
	if _ornament_starts.size() != _ornaments.size():
		return
	for ornament_index in _ornaments.size():
		_ornaments[ornament_index].position = _ornament_starts[ornament_index].lerp(
			_ornament_targets[ornament_index], _incoming_progress if _committed else 0.0
		)


func _restore_ornaments() -> void:
	if _ornament_starts.size() != _ornaments.size():
		return
	for ornament_index in _ornaments.size():
		_ornaments[ornament_index].position = _ornament_starts[ornament_index]
