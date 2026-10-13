extends RefCounted
class_name BoardHintController

const Presentation := preload("res://scripts/gameplay/board/BoardHintPresentation.gd")
const Edge := preload("res://scripts/gameplay/board/PieceEdgeFeather.gd")

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func show_hint() -> void:
	if host.hint_pending:
		return
	if _has_active_hint_highlights() and Time.get_ticks_msec() < host.hint_expires_at_msec:
		host.hint_expires_at_msec = Time.get_ticks_msec() + int(host.HINT_DURATION * 1000)
		for effect in host.hint_highlighted_nodes:
			if is_instance_valid(effect) and effect.has_method("extend"):
				effect.extend()
		return
	if host.current_mode == "swap":
		_show_swap_when_ready()
		return
	var pair: Array = _find_hint_pair()
	if pair.is_empty():
		_clear_hint_highlights()
		return
	host.hint_pending = true
	var token: int = host.hint_highlight_token
	_animate_tray_scroll_to_group(
		pair[0],
		func() -> void:
			if not is_instance_valid(host):
				return
			if not host.hint_pending or token != host.hint_highlight_token:
				return
			host.hint_pending = false
			_set_hint_highlights(pair)
			host.feedback_requested.emit(&"hint")
			host.hint_count += 1
			host._notify_state_changed(true)
	)


func _show_swap_when_ready() -> void:
	host.hint_pending = true
	var token: int = host.hint_highlight_token
	while host.swap_tiles.any(func(tile): return bool(tile.get("is_animating", false))):
		await host.get_tree().process_frame
		if not is_instance_valid(host):
			return
		if token != host.hint_highlight_token or not host.hint_pending:
			return
	host.hint_pending = false
	if host.swap_dragging != null or host.completion_emitted:
		return
	if host.swap_controller._show_swap_hint():
		host.feedback_requested.emit(&"hint")
		host.hint_count += 1
		host._notify_state_changed(true)


func present_swap(pair: Array) -> void:
	var effect := _new_presentation()
	effect.show_swap(host, pair)


func set_reduced_motion(enabled: bool) -> void:
	for effect in host.hint_highlighted_nodes:
		if is_instance_valid(effect) and effect.has_method("set_reduced_motion"):
			effect.set_reduced_motion(enabled)


func _new_presentation() -> Node2D:
	var effect := Presentation.new()
	effect.name = "HintPresentation"
	effect.z_as_relative = false
	effect.z_index = 4094
	host.add_child(effect)
	host.hint_highlighted_nodes.append(effect)
	return effect


func _animate_tray_scroll_to_group(group, on_done: Callable) -> void:
	if group == null or not group.in_tray:
		on_done.call()
		return
	var area: Rect2 = host._tray_area().grow(-float(host.tray_config["hint_padding"]))
	var target_offset: float = host.tray_scroll_offset
	if group.tray_slot.position.x < area.position.x:
		target_offset -= area.position.x - group.tray_slot.position.x
	elif group.tray_slot.end.x > area.end.x:
		target_offset += group.tray_slot.end.x - area.end.x
	target_offset = clampf(
		target_offset, 0.0, maxf(0.0, host.tray_content_width - host._tray_area().size.x)
	)
	if absf(target_offset - host.tray_scroll_offset) < 1.0:
		on_done.call()
		return
	host._stop_tray_inertia()
	if host.hint_tray_scroll_tween != null and host.hint_tray_scroll_tween.is_valid():
		host.hint_tray_scroll_tween.kill()
	host.hint_tray_scroll_tween = host.create_tween()
	host.hint_tray_scroll_tween.set_ease(Tween.EASE_OUT)
	host.hint_tray_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	host.hint_tray_scroll_tween.tween_method(
		func(value: float) -> void:
			host.tray_scroll_offset = value
			host._layout_tray(true),
		host.tray_scroll_offset,
		target_offset,
		host.HINT_TRAY_SCROLL_TIME
	)
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
	_new_presentation().show_piece(host, first)
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
		group.node.z_as_relative = false
		group.node.z_index = int(host.tray_config["z_index"])
		group.node.get_parent().move_child(group.node, -1)
		return
	host._bring_to_front(group)
	group.node.z_index = host.HINT_GROUP_Z_INDEX


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
	hint_line.width = screen_width / Edge.pixel_scale(hint_line)


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
	host.hint_clear_timer.timeout.connect(
		func() -> void:
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
			node.visible = false
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
	result.sort_custom(func(a, b) -> bool: return _hint_group_sort_key(a) < _hint_group_sort_key(b))
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
	a_members.sort_custom(
		func(first, second) -> bool: return str(first.get("id", "")) < str(second.get("id", ""))
	)
	b_members.sort_custom(
		func(first, second) -> bool: return str(first.get("id", "")) < str(second.get("id", ""))
	)
	for am in a_members:
		for bm in b_members:
			if am["neighbors"].has(bm["id"]) or bm["neighbors"].has(am["id"]):
				return [am, bm]
	return []
