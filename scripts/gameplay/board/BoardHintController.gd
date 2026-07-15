extends RefCounted
class_name BoardHintController

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func show_hint() -> void:
	if _hint_in_progress():
		return
	host.hint_count += 1
	host._notify_state_changed(true)
	if host.current_mode == "swap":
		host._show_swap_hint()
		return
	var pair: Array = _find_hint_pair()
	if pair.is_empty():
		_clear_hint_highlights()
		return
	host.hint_pending = true
	_animate_tray_scroll_to_group(pair[0], func() -> void:
		if not host.hint_pending:
			return
		host.hint_pending = false
		_set_hint_highlights(pair)
		_bring_hint_group_to_front(pair[0])
		host._focus_hint_pair(pair)
	)


func _hint_in_progress() -> bool:
	if host.hint_pending:
		return true
	return _has_active_hint_highlights() and Time.get_ticks_msec() < host.hint_expires_at_msec


func _animate_tray_scroll_to_group(group, on_done: Callable) -> void:
	if group == null or not group.in_tray:
		on_done.call()
		return
	var area: Rect2 = host._tray_area().grow(-host.TRAY_PADDING)
	var target_offset: float = host.tray_scroll_offset
	if group.tray_slot.position.x < area.position.x:
		target_offset -= area.position.x - group.tray_slot.position.x
	elif group.tray_slot.end.x > area.end.x:
		target_offset += group.tray_slot.end.x - area.end.x
	target_offset = clampf(target_offset, 0.0, maxf(0.0, host.tray_content_width - host._tray_area().size.x + host.TRAY_PADDING))
	if absf(target_offset - host.tray_scroll_offset) < 1.0:
		on_done.call()
		return
	host._stop_tray_inertia()
	if host.hint_tray_scroll_tween != null and host.hint_tray_scroll_tween.is_valid():
		host.hint_tray_scroll_tween.kill()
	host.hint_tray_scroll_tween = host.create_tween()
	host.hint_tray_scroll_tween.set_ease(Tween.EASE_OUT)
	host.hint_tray_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	host.hint_tray_scroll_tween.tween_method(func(value: float) -> void:
		host.tray_scroll_offset = value
		host._layout_tray(true)
	, host.tray_scroll_offset, target_offset, host.HINT_TRAY_SCROLL_TIME)
	host.hint_tray_scroll_tween.finished.connect(on_done)


func _set_hint_highlights(pair: Array) -> void:
	var hint_key := _hint_pair_key(pair)
	if hint_key == host.active_hint_key and _has_active_hint_highlights():
		host.hint_expires_at_msec = Time.get_ticks_msec() + int(host.HINT_DURATION * 1000.0)
		_bring_hint_group_to_front(pair[0])
		return
	_clear_hint_highlights()
	host.hint_highlight_token += 1
	host.active_hint_key = hint_key
	host.hint_expires_at_msec = Time.get_ticks_msec() + int(host.HINT_DURATION * 1000.0)
	var token: int = host.hint_highlight_token
	var first = pair[0]
	_bring_hint_group_to_front(first)
	host.hint_highlighted_groups.append(first)
	_add_hint_target_outline(first)
	_add_hint_outline_to_group(first)
	_auto_clear_hint_highlights(token)


func _has_active_hint_highlights() -> bool:
	for line in host.hint_highlighted_lines:
		if line != null and is_instance_valid(line):
			return true
	for node in host.hint_highlighted_nodes:
		if node != null and is_instance_valid(node):
			return true
	return false


func _bring_hint_group_to_front(group) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	if group.in_tray:
		group.node.z_index = host.HINT_GROUP_Z_INDEX
		return
	host._bring_to_front(group)
	group.node.z_index = host.HINT_GROUP_Z_INDEX


func _add_hint_outline_to_group(group) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	var center := _hint_outline_local_center(group)
	var outline_root := Node2D.new()
	outline_root.name = "hint_group_outline"
	outline_root.position = center
	outline_root.z_index = 31
	group.node.add_child(outline_root)
	host.hint_highlighted_nodes.append(outline_root)
	for member in group.members:
		var visual: Node2D = member["visual"]
		var polygon: PackedVector2Array = member["polygon"]
		var outline := PackedVector2Array()
		for point in polygon:
			outline.append(visual.position + point - center)
		_add_hint_outline_line(outline_root, outline, host.HINT_OUTLINE_SCREEN_WIDTH, host.HINT_OUTLINE_COLOR, 0, false)
	_hint_breathe_group(group)


func _hint_outline_local_center(group) -> Vector2:
	var bounds: Rect2 = host._group_local_bounds(group)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.ZERO
	return bounds.get_center()


func _add_hint_target_outline(group) -> void:
	if host.world_root == null or group == null:
		return
	var polygons: Array = []
	for member in group.members:
		var visual_position: Vector2 = member["visual"].position
		var polygon: PackedVector2Array = member["polygon"]
		var outline := PackedVector2Array()
		for point in polygon:
			outline.append(visual_position + point)
		polygons.append(outline)
	_spawn_dashed_outline(host.world_root, polygons, group.anchor_home, host.HINT_TARGET_Z_INDEX)


func _spawn_dashed_outline(parent: Node2D, polygons: Array, local_position: Vector2, z_index_value: int) -> Node2D:
	var root := Node2D.new()
	root.name = "hint_dashed_outline"
	root.position = local_position
	root.z_index = z_index_value
	parent.add_child(root)
	host.hint_highlighted_nodes.append(root)
	_redraw_dashed_outline(root, polygons, 0.0)
	if host.reduced_motion:
		return root
	var tween := host.create_tween()
	tween.bind_node(root)
	tween.set_loops()
	tween.set_trans(Tween.TRANS_LINEAR)
	var dash_cycle: float = host.HINT_TARGET_DASH_LENGTH + host.HINT_TARGET_DASH_GAP
	tween.tween_method(func(phase: float) -> void:
		_redraw_dashed_outline(root, polygons, phase)
	, 0.0, dash_cycle, 0.64)
	return root


func _redraw_dashed_outline(root: Node2D, polygons: Array, phase: float) -> void:
	if not is_instance_valid(root):
		return
	for child in root.get_children():
		child.free()
	for polygon in polygons:
		for dash in _dashed_polygon_segments(polygon, host.HINT_TARGET_DASH_LENGTH, host.HINT_TARGET_DASH_GAP, phase):
			_add_hint_outline_line(root, dash, host.HINT_TARGET_SCREEN_WIDTH, host.HINT_TARGET_COLOR, 0, false, false)


func _dashed_polygon_segments(points: PackedVector2Array, dash_length: float, gap_length: float, phase: float) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	if points.size() < 2:
		return segments
	var cycle := maxf(1.0, dash_length + gap_length)
	var distance_cursor := -fposmod(phase, cycle)
	for index in range(points.size()):
		var start := points[index]
		var end := points[(index + 1) % points.size()]
		var edge := end - start
		var edge_length := edge.length()
		if edge_length <= 0.001:
			continue
		var direction := edge / edge_length
		var local := 0.0
		while local < edge_length:
			var cycle_position := fposmod(distance_cursor, cycle)
			var until_next := cycle - cycle_position
			# fposmod can return the divisor itself due to float error, which
			# would make the step zero and hang this loop
			var step := maxf(0.01, minf(edge_length - local, until_next))
			if cycle_position < dash_length:
				var dash_remaining := dash_length - cycle_position
				var dash_step := minf(step, dash_remaining)
				var dash := PackedVector2Array()
				dash.append(start + direction * local)
				dash.append(start + direction * (local + dash_step))
				segments.append(dash)
			local += step
			distance_cursor += step
	return segments


func _hint_breathe_group(group) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	if host.reduced_motion:
		return
	var node: Node2D = group.node
	var base_scale: float = node.scale.x
	var base_position: Vector2 = node.position
	var local_center := _hint_outline_local_center(group)
	var pinned_center := base_position + local_center * base_scale
	var apply_factor := func(factor: float) -> void:
		if not is_instance_valid(node):
			return
		node.scale = Vector2.ONE * base_scale * factor
		node.position = pinned_center - local_center * base_scale * factor
	var tween := host.create_tween()
	tween.bind_node(node)
	tween.set_loops(int(ceil(host.HINT_DURATION / host.HINT_BREATHE_CYCLE)))
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(apply_factor, 1.0, host.HINT_BREATHE_SCALE, host.HINT_BREATHE_CYCLE * 0.5)
	tween.tween_method(apply_factor, host.HINT_BREATHE_SCALE, 1.0, host.HINT_BREATHE_CYCLE * 0.5)
	tween.finished.connect(func() -> void:
		apply_factor.call(1.0)
	)
	host.hint_blink_tweens.append(tween)


func _add_hint_outline_line(visual: Node2D, polygon: PackedVector2Array, width: float, color: Color, z_index: int, animate := true, track := true) -> Line2D:
	var line := Line2D.new()
	line.name = "hint_highlight"
	line.width = width
	line.default_color = color
	line.closed = polygon.size() > 2
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.points = polygon
	line.z_index = z_index
	line.set_meta("screen_width", width)
	visual.add_child(line)
	_update_hint_line_width(line)
	if track:
		host.hint_highlighted_lines.append(line)
	if not animate or host.reduced_motion:
		return line
	var tween := host.create_tween()
	tween.set_loops(5)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(line, "modulate:a", 0.42, 0.30)
	tween.tween_property(line, "modulate:a", 1.0, 0.30)
	return line


func _refresh_hint_line_widths() -> void:
	var valid_lines: Array[Line2D] = []
	for line in host.hint_highlighted_lines:
		if line != null and is_instance_valid(line):
			_update_hint_line_width(line)
			valid_lines.append(line)
	host.hint_highlighted_lines = valid_lines


func _update_hint_line_width(line) -> void:
	if line == null or not is_instance_valid(line) or not line is Line2D:
		return
	var hint_line := line as Line2D
	var screen_width := float(hint_line.get_meta("screen_width", hint_line.width))
	var transform := hint_line.get_global_transform()
	var scale := maxf(transform.x.length(), transform.y.length())
	hint_line.width = screen_width / maxf(0.001, scale)


func _auto_clear_hint_highlights(token: int) -> void:
	_stop_hint_clear_timer()
	if token != host.hint_highlight_token:
		return
	var remaining_msec: int = host.hint_expires_at_msec - Time.get_ticks_msec()
	if remaining_msec <= 0:
		_clear_hint_highlights()
		return
	host.hint_clear_timer = Timer.new()
	host.hint_clear_timer.one_shot = true
	host.hint_clear_timer.wait_time = maxf(0.01, float(remaining_msec) / 1000.0)
	host.add_child(host.hint_clear_timer)
	host.hint_clear_timer.timeout.connect(func() -> void:
		if token == host.hint_highlight_token:
			_auto_clear_hint_highlights(token)
	)
	host.hint_clear_timer.start()


func _stop_hint_clear_timer() -> void:
	if host.hint_clear_timer != null and is_instance_valid(host.hint_clear_timer):
		host.hint_clear_timer.stop()
		host.hint_clear_timer.queue_free()
	host.hint_clear_timer = null


func _clear_hint_highlights() -> void:
	_stop_hint_clear_timer()
	host.hint_highlight_token += 1
	host.active_hint_key = ""
	host.hint_expires_at_msec = 0
	host.hint_pending = false
	if host.hint_tray_scroll_tween != null and host.hint_tray_scroll_tween.is_valid():
		host.hint_tray_scroll_tween.kill()
	host.hint_tray_scroll_tween = null
	for line in host.hint_highlighted_lines:
		if is_instance_valid(line):
			line.queue_free()
	for node in host.hint_highlighted_nodes:
		if is_instance_valid(node):
			node.queue_free()
	for tween in host.hint_blink_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	host.hint_highlighted_groups.clear()
	host.hint_highlighted_lines.clear()
	host.hint_highlighted_nodes.clear()
	host.hint_blink_tweens.clear()
	if host.current_mode != "swap":
		host._refresh_group_z_indices()
		if host.tray_root != null and is_instance_valid(host.tray_root):
			host._layout_tray(true)


func _find_hint_pair() -> Array:
	var tray_pair := _find_hint_pair_for_candidates(_sorted_hint_groups(host.tray_groups))
	if not tray_pair.is_empty():
		return tray_pair
	return _find_hint_pair_for_candidates(_sorted_hint_groups(host.groups))


func _find_hint_pair_for_candidates(candidates: Array) -> Array:
	var locked_candidates := _sorted_hint_groups(host.locked_groups)
	if locked_candidates.is_empty():
		locked_candidates = _sorted_locked_hint_groups()
	for a in candidates:
		if a == null or not is_instance_valid(a.node):
			continue
		if a.locked:
			continue
		for b in locked_candidates:
			if a == b:
				continue
			if b == null or not is_instance_valid(b.node):
				continue
			if not b.locked:
				continue
			if not _groups_are_neighbors(a, b):
				continue
			var pair := _neighbor_member_pair(a, b)
			if not pair.is_empty():
				return [a, b, pair[0], pair[1]]
	return []


func _sorted_locked_hint_groups() -> Array:
	var result := []
	for group in host.groups:
		if group != null and group.locked:
			result.append(group)
	return _sorted_hint_groups(result)


func _sorted_hint_groups(source_groups: Array) -> Array:
	var result := source_groups.duplicate()
	result.sort_custom(func(a, b) -> bool:
		return _hint_group_sort_key(a) < _hint_group_sort_key(b)
	)
	return result


func _hint_group_sort_key(group) -> String:
	if group == null:
		return "~"
	var ids: Array[String] = []
	for member in group.members:
		ids.append(str(member.get("id", "")))
	ids.sort()
	return "|".join(ids)


func _hint_pair_key(pair: Array) -> String:
	if pair.is_empty():
		return ""
	var parts: Array[String] = [_hint_group_sort_key(pair[0])]
	if pair.size() > 1:
		parts.append(_hint_group_sort_key(pair[1]))
	if pair.size() > 2:
		parts.append(str(pair[2].get("id", "")))
	if pair.size() > 3:
		parts.append(str(pair[3].get("id", "")))
	return "->".join(parts)


func _groups_are_neighbors(a, b) -> bool:
	return not _neighbor_member_pair(a, b).is_empty()


func _neighbor_member_pair(a, b) -> Array:
	var a_members: Array = a.members.duplicate()
	var b_members: Array = b.members.duplicate()
	a_members.sort_custom(func(first, second) -> bool:
		return str(first.get("id", "")) < str(second.get("id", ""))
	)
	b_members.sort_custom(func(first, second) -> bool:
		return str(first.get("id", "")) < str(second.get("id", ""))
	)
	for am in a_members:
		for bm in b_members:
			if am["neighbors"].has(bm["id"]) or bm["neighbors"].has(am["id"]):
				return [am, bm]
	return []
