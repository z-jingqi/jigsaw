extends RefCounted
## A reversible visual-only session. No navigation or persistence while held.

var source: Control
var previous: Control
var _source_position := Vector2.ZERO
var _previous_visible := false
var _previous_filter := Control.MOUSE_FILTER_IGNORE
var _transition: Control
var _pause_token: Dictionary = {}
var _offset := 0.0
var _source_z := 0
var _backplate: ColorRect
var _preview_cards: Array[Node] = []


func begin(view: Control, behind: Control, transition: Control) -> bool:
	if not is_instance_valid(view) or not is_instance_valid(behind):
		return false
	source = view
	previous = behind
	_transition = transition
	_source_position = source.position
	_source_z = source.z_index
	# Each moving route is an opaque page, even if its normal background is
	# supplied by the shared canvas. Keep the retained page's raised children
	# behind this whole surface, not interleaved with the incoming artwork.
	source.z_index = maxi(_source_z, previous.z_index + 64)
	_backplate = ColorRect.new()
	_backplate.name = "EdgeBackPagePaper"
	_backplate.color = preload("res://scripts/ui/foundation/CleanTheme.gd").PAPER
	_backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source.add_child(_backplate)
	source.move_child(_backplate, 0)
	_backplate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_previous_visible = previous.visible
	_previous_filter = previous.mouse_filter
	_pause_token = transition.gesture_pause_motion()
	if source.has_method("gesture_pause_motion"):
		source.gesture_pause_motion()
	for child in previous.find_children("*", "", true, false):
		if child.has_method("set_edge_back_preview"):
			_preview_cards.append(child)
			child.set_edge_back_preview(true)
	previous.visible = true
	previous.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offset = 0.0
	return true


func apply_offset(value: float) -> void:
	_offset = value
	if is_instance_valid(source):
		source.position = _source_position + Vector2(value, 0)


func offset() -> float:
	return _offset


func restore(resume: bool = true) -> void:
	for card in _preview_cards:
		if is_instance_valid(card):
			card.set_edge_back_preview(false)
	_preview_cards.clear()
	if is_instance_valid(_backplate):
		_backplate.hide()
		_backplate.queue_free()
	_backplate = null
	if is_instance_valid(source):
		source.position = _source_position
		source.z_index = _source_z
		if resume and source.has_method("gesture_resume_motion"):
			source.gesture_resume_motion()
	if is_instance_valid(previous):
		previous.visible = _previous_visible
		previous.mouse_filter = _previous_filter
	if resume and is_instance_valid(_transition):
		_transition.gesture_resume_motion(_pause_token)
	_offset = 0.0
