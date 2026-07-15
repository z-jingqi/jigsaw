extends RefCounted
class_name BoardPlacementController

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func _move_group_to(group, target_position: Vector2, use_visible_area := true) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	group.node.position = _clamped_group_position(group, target_position, use_visible_area)
	if use_visible_area:
		host._notify_state_changed()


func _clamped_group_position(group, target_position: Vector2, use_visible_area := true) -> Vector2:
	var area := _piece_drag_area(use_visible_area)
	var clamped := _clamp_position_to_area(group, target_position, area)
	if use_visible_area:
		clamped = _avoid_drag_blockers(group, clamped, area)
	return clamped


func _clamp_position_to_area(group, target_position: Vector2, area: Rect2) -> Vector2:
	var bounds := _group_bounds_at(group, target_position)
	var delta := Vector2.ZERO
	if bounds.size.x <= area.size.x:
		if bounds.position.x < area.position.x:
			delta.x = area.position.x - bounds.position.x
		elif bounds.end.x > area.end.x:
			delta.x = area.end.x - bounds.end.x
	else:
		delta.x = area.get_center().x - bounds.get_center().x
	if bounds.size.y <= area.size.y:
		if bounds.position.y < area.position.y:
			delta.y = area.position.y - bounds.position.y
		elif bounds.end.y > area.end.y:
			delta.y = area.end.y - bounds.end.y
	else:
		delta.y = area.get_center().y - bounds.get_center().y
	return target_position + delta


func _avoid_drag_blockers(group, target_position: Vector2, area: Rect2) -> Vector2:
	if host.drag_blockers.is_empty():
		return target_position
	var clamped := target_position
	for iteration in range(3):
		var moved := false
		for blocker in host.drag_blockers:
			var piece_rect := _world_rect_to_screen(_group_bounds_at(group, clamped))
			if not piece_rect.intersects(blocker):
				continue
			var push := _screen_push_out(piece_rect, blocker)
			if push == Vector2.ZERO:
				continue
			clamped += push / maxf(0.001, host.view_scale)
			clamped = _clamp_position_to_area(group, clamped, area)
			moved = true
		if not moved:
			break
	return clamped


func _screen_push_out(subject: Rect2, obstacle: Rect2) -> Vector2:
	var viewport := host.get_viewport_rect().size
	var touches_left := obstacle.position.x <= 0.0
	var touches_top := obstacle.position.y <= 0.0
	var touches_right := obstacle.end.x >= viewport.x
	var touches_bottom := obstacle.end.y >= viewport.y
	var push_left := obstacle.position.x - subject.end.x
	var push_right := obstacle.end.x - subject.position.x
	var push_up := obstacle.position.y - subject.end.y
	var push_down := obstacle.end.y - subject.position.y
	var candidates: Array[Vector2] = []
	if not touches_left:
		candidates.append(Vector2(push_left, 0.0))
	if not touches_right:
		candidates.append(Vector2(push_right, 0.0))
	if not touches_top:
		candidates.append(Vector2(0.0, push_up))
	if not touches_bottom:
		candidates.append(Vector2(0.0, push_down))
	if candidates.is_empty():
		return Vector2.ZERO
	var best: Vector2 = candidates[0]
	for candidate in candidates:
		if candidate.length_squared() < best.length_squared():
			best = candidate
	return best


func _world_rect_to_screen(rect: Rect2) -> Rect2:
	var top_left: Vector2 = host._world_to_screen(rect.position)
	var bottom_right: Vector2 = host._world_to_screen(rect.end)
	return Rect2(top_left.min(bottom_right), (bottom_right - top_left).abs())


func _screen_to_world_for_view(screen_pos: Vector2, scale: float, offset: Vector2) -> Vector2:
	return (screen_pos - offset) / maxf(0.001, scale)


func _piece_drag_area(use_visible_area := false) -> Rect2:
	var table := _virtual_table_area().grow(-host.PIECE_DRAG_PADDING)
	if not use_visible_area:
		return table
	var visible := _visible_world_area().grow(-host.PIECE_DRAG_PADDING / maxf(0.001, host.view_scale))
	if visible.size.x >= 48.0 and visible.size.y >= 48.0:
		return visible
	return table


func _visible_world_area() -> Rect2:
	return _visible_world_area_for_view(host.view_scale, host.view_offset)


func _visible_world_area_for_view(scale: float, offset: Vector2) -> Rect2:
	var view_rect: Rect2 = host._world_view_screen_rect()
	var top_left := _screen_to_world_for_view(view_rect.position, scale, offset)
	var bottom_right := _screen_to_world_for_view(view_rect.end, scale, offset)
	var position := top_left.min(bottom_right)
	var size := (bottom_right - top_left).abs()
	return Rect2(position, size)


func _virtual_table_area() -> Rect2:
	var layout: Dictionary = host._mobile_board_layout()
	var play_area: Rect2 = layout["play_area"]
	var piece_count: int = max(1, host._current_mode_piece_count())
	var extra := clampf(sqrt(float(piece_count)) * 52.0, host.TABLE_EXTRA_MIN, host.TABLE_EXTRA_MAX)
	return play_area.grow_individual(extra, extra * 0.55, extra, extra * 1.15)


func _group_bounds_at(group, target_position: Vector2) -> Rect2:
	var has_point := false
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for member in group.members:
		var visual_position: Vector2 = member["visual"].position
		for bounds_points in _member_bounds_points_list(member):
			for point in bounds_points:
				var global_point: Vector2 = target_position + (visual_position + point).rotated(group.node.rotation)
				min_point = min_point.min(global_point)
				max_point = max_point.max(global_point)
				has_point = true
	if not has_point:
		return Rect2(target_position, Vector2.ZERO)
	return Rect2(min_point, max_point - min_point)


func _member_bounds_points_list(member: Dictionary) -> Array[PackedVector2Array]:
	if member.has("bounds_points_list") and typeof(member["bounds_points_list"]) == TYPE_ARRAY and not member["bounds_points_list"].is_empty():
		return member["bounds_points_list"]
	return [member.get("bounds_points", member["polygon"])]


func _group_at_world(world_pos: Vector2):
	for i in range(host.groups.size() - 1, -1, -1):
		var group = host.groups[i]
		if group.locked or group.in_tray:
			continue
		var local_to_group: Vector2 = group.node.transform.affine_inverse() * world_pos
		for member in group.members:
			var local_to_piece: Vector2 = local_to_group - member["visual"].position
			if Geometry2D.is_point_in_polygon(local_to_piece, member["polygon"]) and _local_point_has_alpha(member, local_to_piece):
				return group
	return null


func _local_point_has_alpha(member: Dictionary, local_point: Vector2) -> bool:
	var source_point: Vector2 = (local_point + member["home"] - host.board_origin) / host.source_scale
	return _source_point_has_alpha(source_point, host.HIT_ALPHA_RADIUS)


func _source_point_has_alpha(source_point: Vector2, radius := 2) -> bool:
	var center := Vector2i(roundi(source_point.x), roundi(source_point.y))
	var image_size: Vector2i = host.source_image.get_size()
	for y in range(center.y - radius, center.y + radius + 1):
		if y < 0 or y >= image_size.y:
			continue
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= image_size.x:
				continue
			if host.source_image.get_pixel(x, y).a > 0.08:
				return true
	return false


func _visible_cut_line_segments(source_line: PackedVector2Array, home: Vector2, scale: float, origin: Vector2) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var current := PackedVector2Array()
	for index in range(source_line.size() - 1):
		var a: Vector2 = source_line[index]
		var b: Vector2 = source_line[index + 1]
		var sample_count: int = max(2, ceili(a.distance_to(b) / 6.0))
		for sample_index in range(sample_count + 1):
			if index > 0 and sample_index == 0:
				continue
			var source_point: Vector2 = a.lerp(b, float(sample_index) / float(sample_count))
			if _source_point_has_alpha(source_point, 3):
				current.append(origin + source_point * scale - home)
			else:
				if current.size() >= 2:
					segments.append(current)
				current = PackedVector2Array()
	if current.size() >= 2:
		segments.append(current)
	return segments
