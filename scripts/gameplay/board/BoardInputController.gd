extends RefCounted
class_name BoardInputController

var host: Node2D
var _mouse_position := Vector2.ZERO
var _direct_input_active := false
var _previous_accumulation := true
var _ui_mouse_sequence_active := false
var _ui_touch_indices := {}


func _init(owner: Node2D) -> void:
	host = owner


func handle(event: InputEvent, modal_open: bool) -> bool:
	if modal_open:
		if event is InputEventMouseButton:
			var modal_mouse := event as InputEventMouseButton
			if modal_mouse.button_index == MOUSE_BUTTON_LEFT and not modal_mouse.pressed:
				_ui_mouse_sequence_active = false
		elif event is InputEventScreenTouch:
			var modal_touch := event as InputEventScreenTouch
			if not modal_touch.pressed:
				_ui_touch_indices.erase(modal_touch.index)
		if _direct_input_active:
			cancel_gesture()
		return false
	# Android also emits mouse events for the same finger. Buttons still need
	# those events, but board gestures must consume only the real touch stream.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return false
	if event is InputEventPanGesture:
		return false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_ui_mouse_sequence_active = _screen_in_drag_blockers(mouse_event.position)
			if _ui_mouse_sequence_active:
				return false
		elif (
			mouse_event.button_index == MOUSE_BUTTON_LEFT
			and not mouse_event.pressed
			and _ui_mouse_sequence_active
		):
			# A press that started on HUD remains UI-owned even if the pointer
			# drifts outside before release. The board must not eat Button.pressed.
			_ui_mouse_sequence_active = false
			return false
		elif mouse_event.pressed and _screen_in_drag_blockers(mouse_event.position):
			return false
		if (
			host._tray_area().has_point(mouse_event.position)
			and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP
			and mouse_event.pressed
		):
			host._stop_tray_inertia()
			host._pan_tray(48.0, false)
			host._notify_state_changed(true)
			return true
		if (
			host._tray_area().has_point(mouse_event.position)
			and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN
			and mouse_event.pressed
		):
			host._stop_tray_inertia()
			host._pan_tray(-48.0, false)
			host._notify_state_changed(true)
			return true
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			return false
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			return false
		if (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and mouse_event.double_click
			and not host._tray_area().has_point(mouse_event.position)
		):
			var double_group = host._group_at_world(host._screen_to_world(mouse_event.position))
			if double_group != null and host.randomize_piece_rotation:
				host._rotate_group(double_group)
			elif double_group == null:
				host.reset_view()
			return true
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_mouse_position = mouse_event.position
				_begin_drag(mouse_event.position, false)
			else:
				if not mouse_event.position.is_equal_approx(_mouse_position):
					_move_pointer(mouse_event.position, mouse_event.position - _mouse_position)
				_end_drag()
				host._end_pan()
			return true
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var relative := motion.position - _mouse_position
		_mouse_position = motion.position
		if _ui_mouse_sequence_active:
			return false
		return _move_pointer(motion.position, relative)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _screen_in_drag_blockers(touch.position):
				_ui_touch_indices[touch.index] = true
				return false
			_ui_touch_indices.erase(touch.index)
			host.active_touches[touch.index] = touch.position
			if host.active_touches.size() >= 2:
				# Ignore extra fingers; the original drag keeps ownership. Do not
				# drop/commit a piece when another finger touches the screen.
				return true
			host._stop_tray_inertia()
			if touch.double_tap and not host._tray_area().has_point(touch.position):
				var double_group = host._group_at_world(host._screen_to_world(touch.position))
				if double_group != null and host.randomize_piece_rotation:
					host._rotate_group(double_group)
				elif double_group == null:
					host.reset_view()
			else:
				host.active_touch_index = touch.index
				_begin_drag(touch.position, true)
			return true
		if _ui_touch_indices.has(touch.index):
			_ui_touch_indices.erase(touch.index)
			return false
		if not host.active_touches.has(touch.index):
			return false
		var last: Vector2 = host.active_touches[touch.index]
		host.active_touches.erase(touch.index)
		if touch.index == host.active_touch_index:
			if not touch.canceled and not touch.position.is_equal_approx(last):
				_move_pointer(touch.position, touch.position - last)
			_end_drag(not touch.canceled)
			host.active_touch_index = -1
			if touch.canceled:
				host._stop_tray_inertia()
		if touch.index == host.pan_touch_index:
			host._end_pan()
		return true
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if _ui_touch_indices.has(drag_event.index):
			return false
		if not host.active_touches.has(drag_event.index):
			return false
		var relative: Vector2 = drag_event.position - host.active_touches[drag_event.index]
		host.active_touches[drag_event.index] = drag_event.position
		if drag_event.index == host.active_touch_index:
			return _move_pointer(drag_event.position, relative)
	return false


func _move_pointer(point: Vector2, relative: Vector2) -> bool:
	if host.tray_gesture.held_group != null:
		host.tray_gesture.update(point)
	elif host.tray_panning:
		host._pan_tray(relative.x)
	elif host.swap_dragging != null:
		host._move_swap_tile_to(
			host.swap_dragging, host._screen_to_world(point) + host.swap_drag_offset
		)
	elif host.dragging != null:
		update_drag_position(point)
	elif host.panning:
		host._pan_view(relative)
	else:
		return false
	return true


func _screen_in_drag_blockers(screen_pos: Vector2) -> bool:
	for blocker in host.drag_blockers:
		if blocker.has_point(screen_pos):
			return true
	return false


func _begin_drag(screen_pos: Vector2, is_touch: bool) -> void:
	_begin_direct_input()
	if host.current_mode == "swap":
		host._begin_swap_drag(screen_pos)
		return
	host.last_drag_screen_pos = screen_pos
	if host._tray_area().has_point(screen_pos):
		if host.hint_pending or not host.hint_highlighted_groups.is_empty():
			host._clear_hint_highlights()
		host._stop_tray_inertia()
	var tray_group = host._tray_group_at_screen(screen_pos)
	if tray_group != null:
		host.tray_gesture.begin(tray_group, screen_pos)
		return
	if host._tray_area().has_point(screen_pos):
		host._begin_tray_pan()
		return
	var world_pos: Vector2 = host._screen_to_world(screen_pos)
	var group = host._group_at_world(world_pos)
	if group == null:
		host._begin_pan(screen_pos, host.active_touch_index)
		return
	host._trigger_haptic("pickup")
	if group.is_animating or group.locked:
		host._begin_pan(screen_pos, host.active_touch_index)
		return
	host._clear_hint_highlights()
	host.dragging = group
	host.drag_offset = group.node.position - world_pos
	if is_touch:
		host.drag_offset.y -= host.TOUCH_DRAG_LIFT_DISTANCE / maxf(0.001, host.view_scale)
	host._bring_to_front(group)
	host.PieceVisualFactoryScript.set_group_lifted(group, true, host, false)


func _end_drag(allow_placement := true) -> void:
	_end_direct_input()
	if host.current_mode == "swap":
		host._end_swap_drag(allow_placement)
		return
	if host.tray_gesture.release(not allow_placement):
		return
	if host.tray_panning:
		if allow_placement:
			host._release_tray_pan()
		else:
			host.tray_panning = false
			host._stop_tray_inertia()
		return
	if host.dragging == null:
		return
	var released_group = host.dragging
	var released_members: Array = released_group.members.duplicate()
	var release_displacement: Vector2 = released_group.node.position - released_group.anchor_home
	var snapped: bool = allow_placement and host._try_snap_chain(host.dragging)
	if host.dragging_from_tray and not snapped:
		host._return_group_to_tray(released_group)
	elif snapped:
		host._lock_group(released_group)
	else:
		host._trigger_haptic("drop")
	host.PieceVisualFactoryScript.set_group_lifted(
		released_group, false, host, not host.reduced_motion and not snapped
	)
	host.dragging = null
	host.dragging_from_tray = false
	host.dragging_tray_index = -1
	host.last_drag_screen_pos = Vector2.ZERO
	if snapped:
		host.piece_feedback.confirm_placement(released_members, release_displacement)
	# Completion may open a modal or change screens; release input ownership first.
	host._check_complete()
	host._notify_state_changed(true)


func update_drag_position(screen_pos: Vector2) -> void:
	host.last_drag_screen_pos = screen_pos
	host._move_group_to(host.dragging, host._screen_to_world(screen_pos) + host.drag_offset)


func cancel_gesture() -> void:
	_end_drag(false)
	host._end_pan()
	host.active_touches.clear()
	host.active_touch_index = -1


func reset() -> void:
	_end_direct_input()
	_ui_mouse_sequence_active = false
	_ui_touch_indices.clear()
	host.tray_gesture.reset()
	host._stop_tray_inertia()


func _begin_direct_input() -> void:
	if _direct_input_active:
		return
	_previous_accumulation = Input.use_accumulated_input
	Input.use_accumulated_input = false
	_direct_input_active = true


func _end_direct_input() -> void:
	if not _direct_input_active:
		return
	Input.use_accumulated_input = _previous_accumulation
	_direct_input_active = false
