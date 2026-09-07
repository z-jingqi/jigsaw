extends RefCounted
class_name BoardTrayController

const TRAY_HIT_PADDING := 18.0

var host: Node2D
var grid_layout := preload("res://scripts/gameplay/board/TrayGridLayout.gd").new()
var grid_cells: Dictionary = {}
var scroll_physics := preload("res://scripts/gameplay/board/TrayScrollPhysics.gd").new()
var grab_gesture := preload("res://scripts/gameplay/board/TrayGrabGesture.gd").new()


func _init(owner: Node2D) -> void:
	host = owner


func _tray_area() -> Rect2:
	if host.tray_bounds_override.size.x > 0.0 and host.tray_bounds_override.size.y > 0.0:
		return host.tray_bounds_override
	var viewport: Vector2 = host.get_viewport_rect().size
	var height: float = maxf(host.TRAY_MIN_HEIGHT, viewport.y * host.TRAY_HEIGHT_RATIO)
	var bottom: float = maxf(0.0, viewport.y - host.hud_bottom_reserved_height)
	return Rect2(Vector2(0, maxf(0.0, bottom - height)), Vector2(viewport.x, height))


func _ensure_tray_top_border() -> void:
	if host.tray_root == null or not is_instance_valid(host.tray_root):
		return
	if host.tray_background == null or not is_instance_valid(host.tray_background):
		host.tray_background = Panel.new()
		host.tray_background.name = "tray_background"
		host.tray_background.z_index = -20
		host.tray_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var initial_background_style := StyleBoxFlat.new()
		initial_background_style.bg_color = Color(0.93, 0.78, 0.58, 0.45)
		host.tray_background.add_theme_stylebox_override("panel", initial_background_style)
		host.tray_root.add_child(host.tray_background)
	if host.tray_top_border == null or not is_instance_valid(host.tray_top_border):
		host.tray_top_border = ColorRect.new()
		host.tray_top_border.name = "tray_top_border"
		host.tray_top_border.color = host.TRAY_TOP_BORDER_COLOR
		host.tray_top_border.z_index = -10
		host.tray_top_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.tray_root.add_child(host.tray_top_border)
	var area: Rect2 = _tray_area()
	var layout_scale := maxf(1.0, area.size.y / 400.0)
	var background_style := host.tray_background.get_theme_stylebox("panel") as StyleBoxFlat
	background_style.corner_radius_top_left = 0
	background_style.corner_radius_top_right = 0
	background_style.corner_radius_bottom_left = 0
	background_style.corner_radius_bottom_right = 0
	background_style.border_width_top = 0
	host.tray_background.position = area.position
	host.tray_background.size = area.size
	host.tray_top_border.position = area.position
	host.tray_top_border.size = Vector2(area.size.x, host.TRAY_TOP_BORDER_HEIGHT * layout_scale)


func _layout_tray(instant := false) -> void:
	_ensure_tray_top_border()
	_layout_tray_items(instant)
	var previous_scroll: float = host.tray_scroll_offset
	_clamp_tray_scroll()
	if not is_equal_approx(previous_scroll, host.tray_scroll_offset):
		_layout_tray_items(instant)


func _layout_tray_items(instant := false) -> void:
	var items: Array = []
	var visible_groups: Array = []
	for group in host.tray_groups:
		if group == null or not is_instance_valid(group.node):
			continue
		if not group.in_tray and not (group == host.dragging and host.dragging_from_tray):
			continue
		items.append({"id": group.node.get_instance_id(), "bounds": _group_local_bounds(group)})
		visible_groups.append(group)
	var result: Dictionary = grid_layout.arrange(
		items, _tray_area(), host.tray_scroll_offset, _tray_original_screen_scale()
	)
	host.tray_scroll_offset = result.offset
	host.tray_content_width = result.width
	grid_cells.clear()
	for index in visible_groups.size():
		var group = visible_groups[index]
		grid_cells[group.node.get_instance_id()] = result.cells[index]
		if group.in_tray:
			_move_group_to_tray(group, index, instant)


func _clamp_tray_scroll() -> void:
	var area: Rect2 = _tray_area()
	host.tray_scroll_offset = clampf(
		host.tray_scroll_offset, 0.0, maxf(0.0, host.tray_content_width - area.size.x)
	)


func _pan_tray(delta_x: float, record_velocity := true) -> void:
	if not host.hint_highlighted_groups.is_empty():
		host._clear_hint_highlights()
	var previous: float = host.tray_scroll_offset
	host.tray_scroll_offset -= delta_x
	_clamp_tray_scroll()
	if record_velocity:
		scroll_physics.record(host.tray_scroll_offset - previous)
	_layout_tray(true)
	host._notify_state_changed()


func _start_tray_inertia() -> void:
	host.tray_scroll_velocity = scroll_physics.release_velocity()
	if absf(host.tray_scroll_velocity) < host.TRAY_INERTIA_MIN_SPEED:
		_stop_tray_inertia()
		return
	host.tray_inertia_active = true


func _stop_tray_inertia() -> void:
	scroll_physics.reset()
	host.tray_inertia_active = false
	host.tray_scroll_velocity = 0.0
	host.tray_last_pan_msec = 0


func process_scroll(delta: float) -> void:
	if not host.tray_inertia_active:
		return
	var motion: Vector2 = scroll_physics.step(host.tray_scroll_velocity, delta)
	var previous: float = host.tray_scroll_offset
	_pan_tray(-motion.x, false)
	host.tray_scroll_velocity = motion.y
	if (
		is_equal_approx(previous, host.tray_scroll_offset)
		or absf(host.tray_scroll_velocity) < host.TRAY_INERTIA_MIN_SPEED
	):
		_stop_tray_inertia()


func _release_tray_pan() -> void:
	host.tray_panning = false
	_start_tray_inertia()


func _tray_original_screen_scale() -> float:
	var scale: float = host.base_view_scale if host.base_view_scale > 0.0 else host.view_scale
	return maxf(0.001, scale)


func _move_group_to_tray(group, index: int, instant := false, _forced_x := NAN) -> void:
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
	var cell: Dictionary = grid_cells.get(group.node.get_instance_id(), {})
	if cell.is_empty():
		# Construction and restore call this before the final shared layout pass.
		_layout_tray_items(true)
		return
	var scale: float = cell.scale
	group.tray_scale = scale
	var top_left: Vector2 = cell.top_left
	group.tray_slot = cell.slot

	var target_position: Vector2 = top_left - bounds.position * scale
	group.node.z_as_relative = false
	group.node.z_index = host.TRAY_Z_INDEX + 1
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
	tween.finished.connect(
		func(g = group) -> void:
			if is_instance_valid(g.node):
				g.is_animating = false
				g.tray_tween = null
				host._refresh_hint_line_widths()
	)


func _tray_group_at_screen(screen_pos: Vector2, exclude = null, _hit_padding := TRAY_HIT_PADDING):
	for i in range(host.tray_groups.size() - 1, -1, -1):
		var group = host.tray_groups[i]
		if group == exclude:
			continue
		if group == null or not group.in_tray:
			continue
		var hit_rect: Rect2 = group.tray_slot
		if group.is_animating:
			var bounds := _group_local_bounds(group)
			hit_rect = (
				Rect2(
					group.node.position + bounds.position * group.node.scale.x,
					bounds.size * group.node.scale.x
				)
				. grow(TRAY_HIT_PADDING)
			)
		if _tray_area().has_point(screen_pos) and hit_rect.has_point(screen_pos):
			return group
	return null


func _begin_tray_piece_press(group, screen_pos: Vector2) -> void:
	_start_tray_world_drag(group, screen_pos)


func _end_tray_piece_press() -> void:
	grab_gesture.reset()


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


func _start_tray_world_drag(group, screen_pos: Vector2) -> void:
	if group == null:
		return
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
	grab_gesture.begin(screen_pos)
	_send_group_to_world(
		group,
		host._screen_to_world(tray_node_screen_position),
		tray_node_screen_scale / maxf(0.001, host.view_scale)
	)
	host._clear_hint_highlights()
	group.node.z_as_relative = false
	group.node.z_index = host.TRAY_DRAG_Z_INDEX
	_place_dragging_from_screen(screen_pos)
	host.drag_offset = Vector2.ZERO
	host._notify_state_changed()


func _update_drag_position(screen_pos: Vector2) -> void:
	host.last_drag_screen_pos = screen_pos
	if host.dragging_from_tray:
		var motion: Dictionary = grab_gesture.advance(screen_pos, _tray_area())
		if motion.changed:
			_stop_tray_inertia()
		if not grab_gesture.scroll_locked:
			_pan_tray(motion.delta_x)
		var screen_scale: float = host.dragging.tray_scale
		host.dragging.node.scale = (
			Vector2.ONE
			* (1.0 if grab_gesture.scroll_locked else screen_scale / maxf(0.001, host.view_scale))
		)
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
	var pointer_world: Vector2 = host._screen_to_world(screen_pos)
	host.dragging.node.position = (
		pointer_world - host.tray_drag_local_grab * host.dragging.node.scale.x
	)
	host.dragging.node.z_index = host.TRAY_DRAG_Z_INDEX
