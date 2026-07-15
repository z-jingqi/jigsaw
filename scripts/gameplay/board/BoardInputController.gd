extends RefCounted
class_name BoardInputController

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func handle(event: InputEvent, modal_open: bool) -> bool:
	if modal_open:
		return false
	if event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		if _screen_in_drag_blockers(magnify.position):
			return false
		var factor: float = clampf(magnify.factor, host.TRACKPAD_MAGNIFY_MIN, host.TRACKPAD_MAGNIFY_MAX)
		host._zoom_view_at(magnify.position, host.view_target_scale * factor)
		return true
	if event is InputEventPanGesture:
		return false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if _screen_in_drag_blockers(mouse_event.position):
			return false
		if host._tray_area().has_point(mouse_event.position) and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			host._stop_tray_inertia()
			host._pan_tray(48.0, false)
			return true
		if host._tray_area().has_point(mouse_event.position) and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			host._stop_tray_inertia()
			host._pan_tray(-48.0, false)
			return true
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			return false
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			return false
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			var double_group = host._group_at_world(host._screen_to_world(mouse_event.position))
			if double_group != null and host.randomize_piece_rotation:
				host._rotate_group(double_group)
			elif double_group == null:
				host.reset_view()
			return true
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_drag(mouse_event.position)
			else:
				_end_drag()
				host._end_pan()
			return true
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if host.tray_pending_group != null:
			host._update_pending_tray_drag(motion.position, motion.relative)
			return true
		if host.tray_panning:
			host._pan_tray(motion.relative.x)
			return true
		if host.swap_dragging != null:
			host._move_swap_tile_to(host.swap_dragging, host._screen_to_world(motion.position) + host.swap_drag_offset)
			return true
		if host.dragging != null:
			host._update_drag_position(motion.position)
			return true
		if host.panning:
			host._pan_view(motion.relative)
			return true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if _screen_in_drag_blockers(touch.position):
			return false
		if touch.pressed:
			host._stop_tray_inertia()
			host.active_touches[touch.index] = touch.position
			if host.active_touches.size() >= 2:
				host._begin_pinch()
				return true
			if touch.double_tap:
				var double_group = host._group_at_world(host._screen_to_world(touch.position))
				if double_group != null and host.randomize_piece_rotation:
					host._rotate_group(double_group)
				elif double_group == null:
					host.reset_view()
			else:
				host.active_touch_index = touch.index
				_begin_drag(touch.position)
			return true
		host.active_touches.erase(touch.index)
		if touch.index == host.active_touch_index:
			_end_drag()
			host.active_touch_index = -1
		if host.tray_panning:
			host._release_tray_pan()
		if touch.index == host.pan_touch_index:
			host._end_pan()
		if host.active_touches.size() < 2:
			host.pinch_active = false
		return true
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		host.active_touches[drag_event.index] = drag_event.position
		if host.tray_pending_group != null and drag_event.index == host.active_touch_index:
			host._update_pending_tray_drag(drag_event.position, drag_event.relative)
			return true
		if host.tray_panning and drag_event.index == host.active_touch_index:
			host._pan_tray(drag_event.relative.x)
			return true
		if host.pinch_active and host.active_touches.size() >= 2:
			host._update_pinch()
			return true
		if host.swap_dragging != null and drag_event.index == host.active_touch_index:
			host._move_swap_tile_to(host.swap_dragging, host._screen_to_world(drag_event.position) + host.swap_drag_offset)
			return true
		if host.dragging != null and drag_event.index == host.active_touch_index:
			host._update_drag_position(drag_event.position)
			return true
		if host.panning and drag_event.index == host.pan_touch_index:
			host._pan_view(drag_event.relative)
			return true
	return false


func _screen_in_drag_blockers(screen_pos: Vector2) -> bool:
	for blocker in host.drag_blockers:
		if blocker.has_point(screen_pos):
			return true
	return false


func _begin_drag(screen_pos: Vector2) -> void:
	if host.current_mode == "swap":
		host._begin_swap_drag(screen_pos)
		return
	host.last_drag_screen_pos = screen_pos
	if host._tray_area().has_point(screen_pos):
		host._stop_tray_inertia()
	var tray_group = host._tray_group_at_screen(screen_pos)
	if tray_group != null:
		if tray_group.is_animating:
			return
		host._begin_tray_piece_press(tray_group, screen_pos)
		return
	if host._tray_area().has_point(screen_pos):
		host.tray_panning = true
		return
	var world_pos: Vector2 = host._screen_to_world(screen_pos)
	var group = host._group_at_world(world_pos)
	if group == null:
		host._begin_pan(screen_pos, host.active_touch_index)
		return
	if group.is_animating or group.locked:
		host._begin_pan(screen_pos, host.active_touch_index)
		return
	host._clear_hint_highlights()
	host.dragging = group
	host.drag_offset = group.node.position - world_pos
	host._bring_to_front(group)
	host.PieceVisualFactoryScript.set_group_lifted(group, true, host, not host.reduced_motion)
	host._trigger_haptic("pickup")
	host._notify_state_changed()


func _end_drag() -> void:
	if host.current_mode == "swap":
		host._end_swap_drag()
		return
	if host.tray_pending_group != null:
		host._end_tray_piece_press()
		return
	if host.tray_panning:
		host._release_tray_pan()
		return
	if host.dragging == null:
		return
	var released_group = host.dragging
	var released_members: Array = released_group.members.duplicate()
	host._clear_snap_preview()
	var snapped: bool = host._try_snap_chain(host.dragging)
	if host.dragging_from_tray and not snapped:
		host._return_group_to_tray(released_group)
	elif snapped:
		host._lock_group(released_group)
		host._play_snap_shimmer(released_members)
	else:
		host._trigger_haptic("drop")
	host._check_complete()
	host.PieceVisualFactoryScript.set_group_lifted(released_group, false, host, not host.reduced_motion and not snapped)
	host.dragging = null
	host.dragging_from_tray = false
	host.dragging_tray_index = -1
	host.tray_drag_screen_offset = Vector2.ZERO
	host.tray_drag_target_screen_offset = Vector2.ZERO
	if host.tray_drag_offset_tween != null and host.tray_drag_offset_tween.is_valid():
		host.tray_drag_offset_tween.kill()
	host.tray_drag_offset_tween = null
	host.tray_drag_local_grab = Vector2.ZERO
	host.last_drag_screen_pos = Vector2.ZERO
	host._notify_state_changed(true)
