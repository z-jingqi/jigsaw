extends RefCounted
class_name BoardDebugAdapter

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func debug_runtime_metrics() -> Dictionary:
	var area: Rect2 = host._tray_area()
	var pieces: Array = []
	for group in host.tray_groups:
		if group == null or not is_instance_valid(group.node):
			continue
		var bounds: Rect2 = host._group_local_bounds(group)
		pieces.append({
			"id": _debug_group_id(group),
			"in_tray": group.in_tray,
			"screen_height": bounds.size.y * host._tray_original_screen_scale(),
			"scale": group.tray_scale,
			"slot_x": group.tray_slot.position.x,
			"slot_w": group.tray_slot.size.x,
		})
	return {
		"mode": host.current_mode,
		"groups": host.groups.size(),
		"locked_groups": host.locked_groups.size(),
		"tray_groups": host.tray_groups.size(),
		"tray": {
			"height": area.size.y,
			"usable_height": maxf(24.0, area.size.y - host.TRAY_VERTICAL_SAFE_GAP * 2.0),
			"vertical_gap": host.TRAY_VERTICAL_SAFE_GAP,
			"scroll": host.tray_scroll_offset,
			"content_width": host.tray_content_width,
			"velocity": host.tray_scroll_velocity,
			"count": host.tray_groups.size(),
			"pieces": pieces,
		},
		"hint": {
			"nodes": host.hint_highlighted_nodes.size(),
			"lines": host.hint_highlighted_lines.size(),
			"key": host.active_hint_key,
		},
	}


func debug_clear_hint() -> void:
	host._clear_hint_highlights()


func debug_reset_tray() -> void:
	host.tray_scroll_offset = 0.0
	host.tray_scroll_velocity = 0.0
	host._layout_tray(false)


func debug_scroll_tray_left() -> void:
	host.tray_scroll_offset = 0.0
	host.tray_scroll_velocity = 0.0
	host._layout_tray(true)


func debug_scroll_tray_right() -> void:
	host.tray_scroll_offset = maxf(0.0, host.tray_content_width - host._tray_area().size.x + host.TRAY_PADDING)
	host.tray_scroll_velocity = 0.0
	host._layout_tray(true)


func debug_toggle_bounds_overlay() -> void:
	host.debug_bounds_overlay_enabled = not host.debug_bounds_overlay_enabled
	if not host.debug_bounds_overlay_enabled:
		_clear_debug_bounds_overlay()
		return
	_refresh_debug_bounds_overlay()


func debug_run_interaction_smoke() -> Dictionary:
	var result := {
		"mode": host.current_mode,
		"tray_scroll": true,
		"pickup_drop": false,
		"tray_drag_scale": true,
		"hint": false,
		"snap_preview": true,
		"snap_shimmer_only": true,
		"swap_preview": true,
		"snap": true,
		"undo": true,
		"complete": false,
	}
	if host.current_mode == "swap":
		await _debug_smoke_swap(result)
	else:
		await _debug_smoke_piece_mode(result)
	var ok := true
	for key in ["tray_scroll", "pickup_drop", "tray_drag_scale", "hint", "snap_preview", "snap_shimmer_only", "swap_preview", "snap", "undo", "complete"]:
		ok = ok and bool(result.get(key, false))
	result["ok"] = ok
	return result


func _debug_smoke_piece_mode(result: Dictionary) -> void:
	var tray_wait_started := Time.get_ticks_msec()
	while _debug_tray_animation_active() and Time.get_ticks_msec() - tray_wait_started < 1200:
		await host.get_tree().create_timer(0.02).timeout
	var max_scroll := maxf(0.0, host.tray_content_width - host._tray_area().size.x + host.TRAY_PADDING)
	debug_scroll_tray_left()
	if max_scroll > 1.0 and not host.tray_groups.is_empty():
		var scroll_start: Vector2 = host.tray_groups[0].tray_slot.get_center()
		var scroll_end := scroll_start + Vector2(-minf(180.0, host._tray_area().size.x * 0.28), 0.0)
		host.handle_input(_debug_mouse_button(scroll_start, true), false)
		host.handle_input(_debug_mouse_motion(scroll_end, scroll_end - scroll_start), false)
		host.handle_input(_debug_mouse_button(scroll_end, false), false)
		result["tray_scroll"] = host.tray_scroll_offset > 0.5
	else:
		result["tray_scroll"] = true
	debug_scroll_tray_left()
	if not host.tray_groups.is_empty():
		var picked = host.tray_groups[0]
		var original_screen_scale: float = host._tray_original_screen_scale()
		for candidate in host.tray_groups:
			if candidate.tray_scale < original_screen_scale * 0.98:
				picked = candidate
				break
		var started_scaled_down: bool = picked.tray_scale < original_screen_scale * 0.98
		var center: Vector2 = picked.tray_slot.get_center()
		var lift_position := Vector2(center.x, host._tray_area().position.y - 72.0)
		var reentered_position := Vector2(center.x, host._tray_area().position.y + 48.0)
		host.handle_input(_debug_mouse_button(center, true), false)
		host.handle_input(_debug_mouse_motion(lift_position, lift_position - center), false)
		var lifted_at_original_scale: bool = host.dragging == picked and not picked.in_tray and picked.node.scale.is_equal_approx(Vector2.ONE)
		host.handle_input(_debug_mouse_motion(reentered_position, reentered_position - lift_position), false)
		var reentered_at_original_scale: bool = host.dragging == picked and picked.node.scale.is_equal_approx(Vector2.ONE)
		host.handle_input(_debug_mouse_button(reentered_position, false), false)
		if picked.tray_tween != null and picked.tray_tween.is_valid():
			await picked.tray_tween.finished
		await host.get_tree().process_frame
		var returned_scaled_down: bool = (
			picked.in_tray
			and picked.node.get_parent() == host.tray_root
			and is_equal_approx(picked.node.scale.x, picked.tray_scale)
		)
		result["tray_drag_scale"] = lifted_at_original_scale and reentered_at_original_scale and returned_scaled_down
		result["tray_drag_scale_details"] = {
			"started_scaled_down": started_scaled_down,
			"lifted_at_original_scale": lifted_at_original_scale,
			"reentered_at_original_scale": reentered_at_original_scale,
			"returned_scaled_down": returned_scaled_down,
			"tray_scale": picked.tray_scale,
			"node_scale": picked.node.scale.x,
			"in_tray": picked.in_tray,
			"parent": picked.node.get_parent().name if picked.node.get_parent() != null else "",
			"original_screen_scale": original_screen_scale,
		}
		result["pickup_drop"] = lifted_at_original_scale and picked.in_tray and host.dragging == null
	host.show_hint()
	var hint_wait_started := Time.get_ticks_msec()
	while host.hint_pending and Time.get_ticks_msec() - hint_wait_started < 1200:
		await host.get_tree().create_timer(0.02).timeout
	result["hint"] = host._has_active_hint_highlights()
	debug_clear_hint()
	var pair: Array = host._find_hint_pair()
	if pair.is_empty():
		result["snap_preview"] = false
		result["snap_shimmer_only"] = false
		result["snap"] = false
	else:
		var active = pair[0]
		host._send_group_to_world(active, active.anchor_home + Vector2(host._snap_tolerance() * 1.05, 0.0))
		active.node.scale = Vector2.ONE
		host._update_snap_preview(active)
		var outside_hidden: bool = host.snap_preview_lines.is_empty()
		active.node.position = active.anchor_home + Vector2(host._snap_tolerance() * 0.92, 0.0)
		host._update_snap_preview(active)
		result["snap_preview"] = outside_hidden and not host.snap_preview_lines.is_empty()
		var group_count_before: int = host.groups.size()
		host.PieceVisualFactoryScript.set_group_lifted(active, true, host, false)
		host.dragging = active
		host.dragging_from_tray = false
		host._end_drag()
		var scale_reset := true
		var shimmer_visible := false
		for member in active.members:
			var visual: Node2D = member.get("visual", null)
			if visual == null or not is_instance_valid(visual):
				continue
			scale_reset = scale_reset and visual.scale.is_equal_approx(Vector2.ONE)
			shimmer_visible = shimmer_visible or visual.get_node_or_null("snap_shimmer") != null
		result["snap_shimmer_only"] = scale_reset and (host.reduced_motion or shimmer_visible)
		result["snap"] = host.groups.size() < group_count_before and active.locked and host.dragging == null
		host._clear_snap_preview()
	debug_force_complete()
	result["complete"] = host.completion_emitted


func _debug_tray_animation_active() -> bool:
	for group in host.tray_groups:
		if group != null and group.is_animating:
			return true
	return false


func _debug_mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	return event


func _debug_mouse_motion(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


func _debug_smoke_swap(result: Dictionary) -> void:
	host.show_hint()
	await host.get_tree().process_frame
	result["hint"] = host._has_active_hint_highlights()
	debug_clear_hint()
	var pair: Array = host._find_swap_hint_pair()
	if pair.size() < 2:
		result["pickup_drop"] = false
		result["swap_preview"] = false
		result["undo"] = false
	else:
		var first = pair[0]
		var second = pair[1]
		var first_slot := int(first["slot_index"])
		var second_slot := int(second["slot_index"])
		var first_center: Vector2 = first["node"].position + first["size"] * 0.5
		host._begin_swap_drag(host._world_to_screen(first_center))
		var lifted: bool = host.swap_dragging == first
		host._move_swap_tile_to(first, second["node"].position)
		result["swap_preview"] = host.swap_target_preview == second and host.swap_target_preview_root != null and is_instance_valid(host.swap_target_preview_root)
		host._end_swap_drag()
		await host.get_tree().create_timer(host._motion_duration(host.SWAP_ANIMATION_TIME) + 0.03).timeout
		var swapped := int(first["slot_index"]) == second_slot and int(second["slot_index"]) == first_slot
		result["pickup_drop"] = lifted and swapped and host.swap_dragging == null
		var undo_was_available: bool = host.can_undo_swap()
		host.undo_last_swap()
		await host.get_tree().create_timer(host._motion_duration(host.SWAP_ANIMATION_TIME) + 0.03).timeout
		result["undo"] = undo_was_available and int(first["slot_index"]) == first_slot and int(second["slot_index"]) == second_slot
	debug_force_complete()
	result["complete"] = host.completion_emitted


func debug_force_complete() -> void:
	host._clear_hint_highlights()
	host._clear_snap_preview()
	if host.current_mode == "swap":
		for tile in host.swap_tiles:
			tile["slot_index"] = int(tile["correct_index"])
			tile["node"].position = host._swap_slot_position(int(tile["correct_index"]), host._swap_cols(), host._swap_rows())
		host._check_swap_complete()
		return
	for group in host.groups.duplicate():
		if group.locked:
			continue
		host._send_group_to_world(group, group.anchor_home)
		group.locked = true
		group.in_tray = false
		group.node.position = group.anchor_home
		group.node.rotation_degrees = 0.0
		group.node.scale = Vector2.ONE
		host.PieceVisualFactoryScript.add_seam_outline(group, host._seam_line_width())
		if not host.locked_groups.has(group):
			host.locked_groups.append(group)
	host.tray_groups.clear()
	host._layout_tray(true)
	host._check_complete()


func debug_prepare_restore_snapshot() -> Dictionary:
	host.hint_count = 2
	host._zoom_view_at(host._world_view_screen_rect().get_center(), host.base_view_scale * 1.45)
	if host.current_mode == "swap":
		var pair: Array = host._find_swap_hint_pair()
		if pair.size() >= 2:
			var first = pair[0]
			var second = pair[1]
			var first_slot := int(first["slot_index"])
			var second_slot := int(second["slot_index"])
			host.swap_history.append({
				"first": int(first["correct_index"]),
				"second": int(second["correct_index"]),
				"first_slot": first_slot,
				"second_slot": second_slot,
			})
			first["slot_index"] = second_slot
			second["slot_index"] = first_slot
			first["node"].position = host._swap_slot_position(second_slot, host._swap_cols(), host._swap_rows())
			second["node"].position = host._swap_slot_position(first_slot, host._swap_cols(), host._swap_rows())
			host.undo_available_changed.emit(true)
	else:
		var pair: Array = host._find_hint_pair()
		if not pair.is_empty():
			var active = pair[0]
			host._send_group_to_world(active, active.anchor_home)
			if host._try_snap_chain(active):
				host._lock_group(active)
		debug_scroll_tray_right()
	return host.state_snapshot()


func debug_validate_restored_snapshot(expected: Dictionary) -> Dictionary:
	var actual: Dictionary = host.state_snapshot()
	var checks := {
		"mode": str(actual.get("mode", "")) == str(expected.get("mode", "")),
		"hint_count": int(actual.get("hint_count", -1)) == int(expected.get("hint_count", -2)),
		"view": _debug_view_state_matches(actual.get("view", {}), expected.get("view", {})),
		"tray_scroll": absf(float(actual.get("tray", {}).get("scroll_ratio", 0.0)) - float(expected.get("tray", {}).get("scroll_ratio", 0.0))) <= 0.01,
	}
	if host.current_mode == "swap":
		checks["pieces"] = _debug_swap_state_matches(actual.get("tiles", []), expected.get("tiles", []))
		checks["history"] = actual.get("swap_history", []).size() == expected.get("swap_history", []).size()
	else:
		checks["pieces"] = _debug_group_state_matches(actual.get("groups", []), expected.get("groups", []))
		checks["tray_order"] = actual.get("tray_order", []) == expected.get("tray_order", [])
	var ok := true
	for value in checks.values():
		ok = ok and bool(value)
	return {
		"mode": host.current_mode,
		"ok": ok,
		"checks": checks,
		"tray_scroll": {
			"actual": float(actual.get("tray", {}).get("scroll", 0.0)),
			"expected": float(expected.get("tray", {}).get("scroll", 0.0)),
			"actual_ratio": float(actual.get("tray", {}).get("scroll_ratio", 0.0)),
			"expected_ratio": float(expected.get("tray", {}).get("scroll_ratio", 0.0)),
		},
	}


func _debug_view_state_matches(actual, expected) -> bool:
	if typeof(actual) != TYPE_DICTIONARY or typeof(expected) != TYPE_DICTIONARY:
		return false
	return absf(float(actual.get("ratio", 1.0)) - float(expected.get("ratio", 1.0))) <= 0.01 \
		and host._json_vector(actual.get("offset", [])).distance_to(host._json_vector(expected.get("offset", []))) <= 1.0


func _debug_swap_state_matches(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	var actual_slots := {}
	for item in actual:
		actual_slots[int(item.get("correct_index", -1))] = int(item.get("slot_index", -1))
	for item in expected:
		if int(actual_slots.get(int(item.get("correct_index", -1)), -2)) != int(item.get("slot_index", -1)):
			return false
	return true


func _debug_group_state_matches(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	var actual_keys: Array[String] = []
	var expected_keys: Array[String] = []
	for item in actual:
		var ids: Array = item.get("members", []).duplicate()
		ids.sort()
		actual_keys.append("|".join(ids))
	for item in expected:
		var ids: Array = item.get("members", []).duplicate()
		ids.sort()
		expected_keys.append("|".join(ids))
	actual_keys.sort()
	expected_keys.sort()
	return actual_keys == expected_keys


func _debug_group_id(group) -> String:
	if group == null or group.members.is_empty():
		return "group"
	return str(group.members[0].get("id", "group"))


func _refresh_debug_bounds_overlay() -> void:
	if not host.debug_bounds_overlay_enabled:
		return
	if host.debug_bounds_overlay == null or not is_instance_valid(host.debug_bounds_overlay):
		host.debug_bounds_overlay = Control.new()
		host.debug_bounds_overlay.name = "debug_bounds_overlay"
		host.debug_bounds_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.debug_bounds_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.debug_bounds_overlay.z_index = 5000
		host.add_child(host.debug_bounds_overlay)
	for child in host.debug_bounds_overlay.get_children():
		child.free()
	var tray: Rect2 = host._tray_area()
	_debug_add_rect_outline(host.debug_bounds_overlay, tray, Color(1.0, 0.74, 0.20, 0.88), 4.0)
	var usable := Rect2(
		Vector2(tray.position.x, tray.position.y + host.TRAY_VERTICAL_SAFE_GAP),
		Vector2(tray.size.x, maxf(1.0, tray.size.y - host.TRAY_VERTICAL_SAFE_GAP * 2.0))
	)
	_debug_add_rect_outline(host.debug_bounds_overlay, usable, Color(0.25, 0.85, 1.0, 0.72), 3.0)
	for group in host.groups:
		if group == null or not is_instance_valid(group.node):
			continue
		var rect: Rect2 = group.tray_slot if group.in_tray else host._world_rect_to_screen(host._group_bounds_at(group, group.node.position))
		var color := Color(0.38, 1.0, 0.45, 0.72) if group.locked else Color(0.28, 0.72, 1.0, 0.68)
		_debug_add_rect_outline(host.debug_bounds_overlay, rect, color, 2.0)
	for blocker in host.drag_blockers:
		_debug_add_rect_outline(host.debug_bounds_overlay, blocker, Color(1.0, 0.15, 0.15, 0.72), 3.0)


func _clear_debug_bounds_overlay() -> void:
	if host.debug_bounds_overlay != null and is_instance_valid(host.debug_bounds_overlay):
		host.debug_bounds_overlay.queue_free()
	host.debug_bounds_overlay = null


func _debug_add_rect_outline(parent: Control, rect: Rect2, color: Color, width: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var top := ColorRect.new()
	top.color = color
	top.position = rect.position
	top.size = Vector2(rect.size.x, width)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top)
	var bottom := ColorRect.new()
	bottom.color = color
	bottom.position = Vector2(rect.position.x, rect.end.y - width)
	bottom.size = Vector2(rect.size.x, width)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bottom)
	var left := ColorRect.new()
	left.color = color
	left.position = rect.position
	left.size = Vector2(width, rect.size.y)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(left)
	var right := ColorRect.new()
	right.color = color
	right.position = Vector2(rect.end.x - width, rect.position.y)
	right.size = Vector2(width, rect.size.y)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(right)
