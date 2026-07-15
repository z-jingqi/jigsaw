extends RefCounted
class_name BoardTrayController

const TRAY_HIT_PADDING := 18.0

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func _tray_area() -> Rect2:
	var viewport: Vector2 = host.get_viewport_rect().size
	var height: float = maxf(host.TRAY_MIN_HEIGHT, viewport.y * host.TRAY_HEIGHT_RATIO)
	var bottom: float = maxf(0.0, viewport.y - host.hud_bottom_reserved_height)
	return Rect2(Vector2(0, maxf(0.0, bottom - height)), Vector2(viewport.x, height))


func _ensure_tray_top_border() -> void:
	if host.tray_root == null or not is_instance_valid(host.tray_root):
		return
	if host.tray_top_border == null or not is_instance_valid(host.tray_top_border):
		host.tray_top_border = ColorRect.new()
		host.tray_top_border.name = "tray_top_border"
		host.tray_top_border.color = host.TRAY_TOP_BORDER_COLOR
		host.tray_top_border.z_index = -10
		host.tray_top_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.tray_root.add_child(host.tray_top_border)
	var area: Rect2 = _tray_area()
	host.tray_top_border.position = area.position
	host.tray_top_border.size = Vector2(area.size.x, host.TRAY_TOP_BORDER_HEIGHT)


func _layout_tray(instant := false) -> void:
	_ensure_tray_top_border()
	_layout_tray_items(instant)
	var previous_scroll: float = host.tray_scroll_offset
	_clamp_tray_scroll()
	if not is_equal_approx(previous_scroll, host.tray_scroll_offset):
		_layout_tray_items(instant)


func _layout_tray_items(instant := false) -> void:
	var area: Rect2 = _tray_area()
	var cursor_x: float = area.position.x + host.TRAY_PADDING - host.tray_scroll_offset
	var content_end: float = area.position.x + host.TRAY_PADDING
	for index in host.tray_groups.size():
		var group = host.tray_groups[index]
		if group == null or not is_instance_valid(group.node):
			continue
		if not group.in_tray:
			if group == host.dragging and host.dragging_from_tray:
				var slot_width := maxf(group.tray_slot.size.x, host.TRAY_GAP)
				cursor_x += slot_width + host.TRAY_GAP
				content_end = maxf(content_end, cursor_x + host.tray_scroll_offset)
			continue
		_move_group_to_tray(group, index, instant, cursor_x)
		cursor_x = group.tray_slot.end.x + host.TRAY_GAP
		content_end = maxf(content_end, cursor_x + host.tray_scroll_offset)
	host.tray_content_width = maxf(0.0, content_end - area.position.x)


func _clamp_tray_scroll() -> void:
	var area: Rect2 = _tray_area()
	host.tray_scroll_offset = clampf(host.tray_scroll_offset, 0.0, maxf(0.0, host.tray_content_width - area.size.x + host.TRAY_PADDING))


func _pan_tray(delta_x: float, record_velocity := true) -> void:
	if not host.hint_highlighted_groups.is_empty():
		host._clear_hint_highlights()
	var now := Time.get_ticks_msec()
	if record_velocity:
		var elapsed := maxf(0.001, float(now - host.tray_last_pan_msec) / 1000.0) if host.tray_last_pan_msec > 0 else 0.016
		host.tray_scroll_velocity = -delta_x / elapsed
		host.tray_last_pan_msec = now
	host.tray_scroll_offset -= delta_x
	_clamp_tray_scroll()
	_layout_tray(true)
	host._notify_state_changed()


func _start_tray_inertia() -> void:
	if absf(host.tray_scroll_velocity) < host.TRAY_INERTIA_MIN_SPEED:
		_stop_tray_inertia()
		return
	host.tray_inertia_active = true


func _stop_tray_inertia() -> void:
	host.tray_inertia_active = false
	host.tray_scroll_velocity = 0.0
	host.tray_last_pan_msec = 0


func _release_tray_pan() -> void:
	host.tray_panning = false
	_start_tray_inertia()


func _tray_original_screen_scale() -> float:
	var scale: float = host.base_view_scale if host.base_view_scale > 0.0 else host.view_scale
	return maxf(0.001, scale)


func _move_group_to_tray(group, index: int, instant := false, forced_x := NAN) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	if group.tray_tween != null and group.tray_tween.is_valid():
		group.tray_tween.kill()
	var current_screen_position: Vector2 = group.node.position
	if group.node.get_parent() == host.world_root:
		current_screen_position = host._world_to_screen(group.node.position)
	if group.node.get_parent() != host.tray_root:
		if group.node.get_parent() != null:
			group.node.get_parent().remove_child(group.node)
		host.tray_root.add_child(group.node)
		group.node.position = current_screen_position
	group.in_tray = true
	group.locked = false
	group.tray_index = index
	group.node.rotation_degrees = 0.0
	var bounds: Rect2 = _group_local_bounds(group)
	var area: Rect2 = _tray_area()
	var target_height: float = maxf(24.0, area.size.y - host.TRAY_VERTICAL_SAFE_GAP * 2.0)
	var original_screen_scale: float = _tray_original_screen_scale()
	var original_screen_size: Vector2 = bounds.size * original_screen_scale
	var scale: float = original_screen_scale
	if original_screen_size.y > target_height + 1.0:
		scale = original_screen_scale * (target_height / maxf(1.0, original_screen_size.y))
	group.tray_scale = scale
	var scaled_size: Vector2 = bounds.size * scale
	var x: float = forced_x if not is_nan(forced_x) else area.position.x + host.TRAY_PADDING + float(index) * (scaled_size.x + host.TRAY_GAP)
	var top_left: Vector2 = Vector2(x, area.position.y + (area.size.y - scaled_size.y) * 0.5)
	group.tray_slot = Rect2(top_left, scaled_size)
	var target_position: Vector2 = top_left - bounds.position * scale
	group.node.z_index = index * host.GROUP_Z_STEP
	if instant:
		group.is_animating = false
		group.node.scale = Vector2.ONE * scale
		group.node.position = target_position
		host._refresh_hint_line_widths()
		return
	group.is_animating = true
	var tween: Tween = host.create_tween()
	group.tray_tween = tween
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	var duration: float = host._motion_duration(host.TRAY_ANIMATION_TIME)
	tween.parallel().tween_property(group.node, "position", target_position, duration)
	tween.parallel().tween_property(group.node, "scale", Vector2.ONE * scale, duration)
	tween.finished.connect(func(g = group) -> void:
		if is_instance_valid(g.node):
			g.is_animating = false
			g.tray_tween = null
			host._refresh_hint_line_widths()
	)


func _tray_group_at_screen(screen_pos: Vector2, exclude = null, hit_padding := TRAY_HIT_PADDING):
	for i in range(host.tray_groups.size() - 1, -1, -1):
		var group = host.tray_groups[i]
		if group == exclude:
			continue
		if group != null and group.in_tray and group.tray_slot.grow(hit_padding).has_point(screen_pos):
			return group
	return null


func _begin_tray_piece_press(group, screen_pos: Vector2) -> void:
	host.tray_pending_group = group
	host.tray_pending_total_delta = Vector2.ZERO
	group.node.z_index = host.TRAY_DRAG_Z_INDEX
	host.PieceVisualFactoryScript.set_group_lifted(group, true, host, not host.reduced_motion)


func _end_tray_piece_press() -> void:
	var group = host.tray_pending_group
	host.tray_pending_group = null
	host.tray_pending_total_delta = Vector2.ZERO
	if group != null and is_instance_valid(group.node):
		host.PieceVisualFactoryScript.set_group_lifted(group, false, host, not host.reduced_motion)
	_layout_tray(false)


func _group_local_bounds(group) -> Rect2:
	var has_point := false
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for member in group.members:
		var visual_position: Vector2 = member["visual"].position
		for bounds_points in host._member_bounds_points_list(member):
			for point in bounds_points:
				var local_point: Vector2 = visual_position + point
				min_point = min_point.min(local_point)
				max_point = max_point.max(local_point)
				has_point = true
	if not has_point:
		return Rect2(Vector2.ZERO, Vector2(1, 1))
	return Rect2(min_point, max_point - min_point)


func _send_group_to_world(group, world_position: Vector2, local_scale := 1.0) -> void:
	if group.node.get_parent() != host.world_root:
		if group.node.get_parent() != null:
			group.node.get_parent().remove_child(group.node)
		host.world_root.add_child(group.node)
	group.node.scale = Vector2.ONE * local_scale
	group.node.position = world_position
	group.in_tray = false
	host._bring_to_front(group)


func _update_pending_tray_drag(screen_pos: Vector2, relative: Vector2) -> void:
	if host.tray_pending_group == null:
		return
	host.tray_pending_total_delta += relative
	var left_tray: bool = screen_pos.y < _tray_area().position.y - host.TRAY_EXIT_THRESHOLD
	if host.tray_pending_total_delta.length() < host.TRAY_GESTURE_DECIDE_THRESHOLD and not left_tray:
		return
	if not left_tray and absf(host.tray_pending_total_delta.x) > absf(host.tray_pending_total_delta.y):
		_start_tray_scroll_from_pending(screen_pos)
		return
	_start_tray_world_drag(host.tray_pending_group, screen_pos)


func _start_tray_scroll_from_pending(screen_pos: Vector2) -> void:
	host._clear_hint_highlights()
	var group = host.tray_pending_group
	var accumulated_x: float = host.tray_pending_total_delta.x
	host.tray_pending_group = null
	host.tray_pending_total_delta = Vector2.ZERO
	if group != null and is_instance_valid(group.node):
		host.PieceVisualFactoryScript.set_group_lifted(group, false, host, not host.reduced_motion)
	host.tray_panning = true
	_pan_tray(accumulated_x)


func _start_tray_world_drag(group, screen_pos: Vector2) -> void:
	if group == null:
		return
	host._clear_hint_highlights()
	_stop_tray_inertia()
	host.tray_pending_group = null
	host.tray_pending_total_delta = Vector2.ZERO
	host.dragging = group
	host.dragging_from_tray = true
	host.dragging_tray_index = group.tray_index
	host.PieceVisualFactoryScript.set_group_lifted(group, true, host, not host.reduced_motion)
	host._trigger_haptic("pickup")
	host.tray_drag_screen_offset = Vector2.ZERO
	host.tray_drag_target_screen_offset = Vector2.ZERO
	host.last_drag_screen_pos = screen_pos
	var tray_node_screen_position: Vector2 = group.node.position
	var tray_node_screen_scale: float = maxf(0.001, group.node.scale.x)
	host.tray_drag_local_grab = (screen_pos - tray_node_screen_position) / tray_node_screen_scale
	_send_group_to_world(group, host._screen_to_world(tray_node_screen_position), 1.0)
	group.node.z_index = host.TRAY_DRAG_Z_INDEX
	_set_tray_drag_target_offset(_tray_drag_target_for_screen(screen_pos))
	_place_dragging_from_screen(screen_pos)
	host.drag_offset = Vector2.ZERO
	host._notify_state_changed()


func _update_drag_position(screen_pos: Vector2) -> void:
	host.last_drag_screen_pos = screen_pos
	if host.dragging_from_tray:
		_set_tray_drag_target_offset(_tray_drag_target_for_screen(screen_pos))
		_place_dragging_from_screen(screen_pos)
		if _tray_area().has_point(screen_pos):
			host._clear_snap_preview()
		else:
			host._update_snap_preview(host.dragging)
		return
	host._move_group_to(host.dragging, host._screen_to_world(screen_pos) + host.drag_offset)
	host._update_snap_preview(host.dragging)


func _place_dragging_from_screen(screen_pos: Vector2) -> void:
	if host.dragging == null or not is_instance_valid(host.dragging.node):
		return
	var pointer_world: Vector2 = host._screen_to_world(screen_pos + host.tray_drag_screen_offset)
	host.dragging.node.position = pointer_world - host.tray_drag_local_grab * host.dragging.node.scale.x
	host.dragging.node.z_index = host.TRAY_DRAG_Z_INDEX


func _tray_drag_target_for_screen(screen_pos: Vector2) -> Vector2:
	if host.dragging == null or _tray_area().has_point(screen_pos):
		return Vector2.ZERO
	var bounds: Rect2 = _group_local_bounds(host.dragging)
	var bottom_at_pointer: float = bounds.end.y * host.view_scale
	return Vector2(0.0, minf(-host.TRAY_DRAG_LIFT_MARGIN, -host.TRAY_DRAG_LIFT_MARGIN - bottom_at_pointer))


func _set_tray_drag_target_offset(target: Vector2) -> void:
	if host.tray_drag_target_screen_offset.is_equal_approx(target):
		return
	host.tray_drag_target_screen_offset = target
	if host.tray_drag_offset_tween != null and host.tray_drag_offset_tween.is_valid():
		host.tray_drag_offset_tween.kill()
	var start: Vector2 = host.tray_drag_screen_offset
	host.tray_drag_offset_tween = host.create_tween()
	host.tray_drag_offset_tween.set_ease(Tween.EASE_OUT)
	host.tray_drag_offset_tween.set_trans(Tween.TRANS_CUBIC)
	host.tray_drag_offset_tween.tween_method(func(t: float) -> void:
		host.tray_drag_screen_offset = start.lerp(host.tray_drag_target_screen_offset, t)
		_place_dragging_from_screen(host.last_drag_screen_pos)
	, 0.0, 1.0, host._motion_duration(0.12))
