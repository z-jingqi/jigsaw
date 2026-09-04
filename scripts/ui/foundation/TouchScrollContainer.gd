class_name TouchScrollContainer
extends ScrollContainer

## Capture at viewport level so recycling a pressed card cannot lose the drag.
const KineticsScript := preload("res://scripts/ui/motion/ScrollKinetics.gd")
const DRAG_THRESHOLD := 8.0
const NO_POINTER := -2

var _motion := KineticsScript.new()
var _pointer := NO_POINTER
var _origin := Vector2.ZERO
var _last := Vector2.ZERO
var _claimed := false
var _touch_scroll_enabled := true


func set_touch_scroll_enabled(enabled: bool) -> void:
	_touch_scroll_enabled = enabled
	if not enabled:
		_finish(true)
		_motion.stop()


func _input(event: InputEvent) -> void:
	if not _touch_scroll_enabled or not is_visible_in_tree():
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if _claimed:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _pointer == NO_POINTER and _can_begin(event.position):
			_begin(event.index, event.position)
		elif not event.pressed and event.index == _pointer:
			_finish(event.canceled)
	elif event is InputEventScreenDrag and event.index == _pointer:
		_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _pointer == NO_POINTER and _can_begin(event.position):
			_begin(-1, event.position)
		elif not event.pressed and _pointer == -1:
			_finish(false)
	elif event is InputEventMouseMotion and _pointer == -1:
		_drag(event.position)


func _gui_input(event: InputEvent) -> void:
	# Keep native wheel/trackpad support, but not a second native drag/inertia loop.
	if event is InputEventMouseMotion:
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
	elif event is InputEventMouseButton or event is InputEventPanGesture:
		_motion.stop()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not _touch_scroll_enabled:
		_motion.stop()
		return
	if _motion.held or is_zero_approx(_motion.velocity):
		return
	get_v_scroll_bar().value = _motion.advance(delta, 0.0, _maximum())


func _can_begin(point: Vector2) -> bool:
	if not get_global_rect().has_point(point):
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered == null or hovered == self or is_ancestor_of(hovered)


func _begin(index: int, point: Vector2) -> void:
	var catching_inertia := not is_zero_approx(_motion.velocity)
	_pointer = index
	_origin = get_global_transform_with_canvas().affine_inverse() * point
	_last = _origin
	_claimed = false
	_motion.begin(get_v_scroll_bar().value)
	if catching_inertia:
		_claim()
		get_viewport().set_input_as_handled()


func _drag(point: Vector2) -> void:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	if not _claimed:
		if absf(local.y - _origin.y) < DRAG_THRESHOLD:
			return
		_claim()
	get_v_scroll_bar().value = _motion.drag_by(local.y - _last.y, 0.0, _maximum())
	_last = local
	get_viewport().set_input_as_handled()


func _claim() -> void:
	_claimed = true
	propagate_notification(NOTIFICATION_SCROLL_BEGIN)
	scroll_started.emit()


func _finish(cancelled: bool) -> void:
	if _pointer == NO_POINTER:
		return
	_motion.release(cancelled or not _claimed)
	_pointer = NO_POINTER
	if _claimed:
		propagate_notification(NOTIFICATION_SCROLL_END)
		scroll_ended.emit()
		get_viewport().set_input_as_handled()
	_claimed = false


func _maximum() -> float:
	var bar := get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)
