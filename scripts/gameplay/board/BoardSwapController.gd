extends RefCounted
class_name BoardSwapController

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func _begin_swap_drag(screen_pos: Vector2) -> void:
	host._clear_hint_highlights()
	var world_pos: Vector2 = host._screen_to_world(screen_pos)
	var tile = _swap_tile_at_world(world_pos)
	if tile == null:
		host._begin_pan(screen_pos, host.active_touch_index)
		return
	if bool(tile.get("is_animating", false)):
		return
	_clear_swap_target_preview()
	host.swap_dragging = tile
	host.swap_drag_start_slot = int(tile["slot_index"])
	host.swap_drag_offset = tile["node"].position - world_pos
	_bring_swap_tile_to_front(tile)
	_set_swap_tile_lifted(tile, true)
	host._trigger_haptic("pickup")
	host._notify_state_changed()


func _end_swap_drag() -> void:
	if host.swap_dragging == null:
		return
	var released = host.swap_dragging
	var target = _swap_target_for_drag(released)
	_clear_swap_target_preview()
	if target == null:
		_animate_swap_tile_to(released, host._swap_slot_position(host.swap_drag_start_slot, _swap_cols(), _swap_rows()))
	else:
		var target_slot := int(target["slot_index"])
		released["slot_index"] = target_slot
		target["slot_index"] = host.swap_drag_start_slot
		_animate_swap_tile_to(released, host._swap_slot_position(target_slot, _swap_cols(), _swap_rows()))
		_animate_swap_tile_to(target, host._swap_slot_position(host.swap_drag_start_slot, _swap_cols(), _swap_rows()))
		host._trigger_haptic("swap")
	_set_swap_tile_lifted(released, false)
	host.swap_dragging = null
	host.swap_drag_start_slot = -1
	host._notify_state_changed(true)


func _move_swap_tile_to(tile, target_position: Vector2) -> void:
	if tile == null or not is_instance_valid(tile["node"]):
		return
	var area: Rect2 = host._piece_drag_area(true)
	var bounds := _swap_tile_bounds(tile, target_position)
	var delta := Vector2.ZERO
	if bounds.position.x < area.position.x:
		delta.x = area.position.x - bounds.position.x
	elif bounds.end.x > area.end.x:
		delta.x = area.end.x - bounds.end.x
	if bounds.position.y < area.position.y:
		delta.y = area.position.y - bounds.position.y
	elif bounds.end.y > area.end.y:
		delta.y = area.end.y - bounds.end.y
	tile["node"].position = target_position + delta
	_update_swap_target_preview(tile)
	host._notify_state_changed()


func _swap_target_for_drag(tile):
	if tile == null or not is_instance_valid(tile["node"]):
		return null
	var center: Vector2 = tile["node"].position + tile["size"] * 0.5
	return _swap_tile_at_world(center, tile)


func _update_swap_target_preview(tile) -> void:
	var target = _swap_target_for_drag(tile)
	if target == host.swap_target_preview:
		return
	_clear_swap_target_preview()
	if target == null:
		return
	host.swap_target_preview = target
	var size: Vector2 = target.get("size", Vector2.ZERO)
	var polygon := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)])
	var root := Node2D.new()
	root.name = "swap_target_preview"
	root.z_index = 48
	target["node"].add_child(root)
	host.swap_target_preview_root = root
	var fill := Polygon2D.new()
	fill.polygon = polygon
	fill.color = host.SWAP_TARGET_PREVIEW_FILL
	root.add_child(fill)
	var line := Line2D.new()
	line.name = "swap_target_preview_outline"
	line.points = polygon
	line.closed = true
	line.default_color = host.SWAP_TARGET_PREVIEW_COLOR
	line.width = host.SWAP_TARGET_PREVIEW_SCREEN_WIDTH
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = 1
	line.set_meta("screen_width", host.SWAP_TARGET_PREVIEW_SCREEN_WIDTH)
	root.add_child(line)
	host.swap_target_preview_line = line
	host._update_hint_line_width(line)
	host._trigger_haptic("ready")
	if host.reduced_motion:
		return
	root.modulate.a = 0.68
	host.swap_target_preview_tween = host.create_tween()
	host.swap_target_preview_tween.bind_node(root)
	host.swap_target_preview_tween.set_loops()
	host.swap_target_preview_tween.set_ease(Tween.EASE_IN_OUT)
	host.swap_target_preview_tween.set_trans(Tween.TRANS_SINE)
	host.swap_target_preview_tween.tween_property(root, "modulate:a", 1.0, 0.34)
	host.swap_target_preview_tween.tween_property(root, "modulate:a", 0.68, 0.34)


func _clear_swap_target_preview() -> void:
	if host.swap_target_preview_tween != null and host.swap_target_preview_tween.is_valid():
		host.swap_target_preview_tween.kill()
	host.swap_target_preview_tween = null
	if host.swap_target_preview_root != null and is_instance_valid(host.swap_target_preview_root):
		host.swap_target_preview_root.queue_free()
	host.swap_target_preview = null
	host.swap_target_preview_root = null
	host.swap_target_preview_line = null


func _swap_tile_at_world(world_pos: Vector2, exclude = null):
	for index in range(host.swap_tiles.size() - 1, -1, -1):
		var tile = host.swap_tiles[index]
		if tile == exclude:
			continue
		var node: Node2D = tile["node"]
		if not is_instance_valid(node):
			continue
		var local: Vector2 = node.transform.affine_inverse() * world_pos
		if Rect2(Vector2.ZERO, tile["size"]).has_point(local):
			return tile
	return null


func _swap_tile_bounds(tile, target_position: Vector2) -> Rect2:
	return Rect2(target_position, tile.get("size", Vector2.ZERO))


func _bring_swap_tile_to_front(tile) -> void:
	host.swap_tiles.erase(tile)
	host.swap_tiles.append(tile)
	for index in host.swap_tiles.size():
		host.swap_tiles[index]["node"].z_index = index * host.GROUP_Z_STEP
	host._notify_state_changed()


func _set_swap_tile_lifted(tile, lifted: bool) -> void:
	if tile == null:
		return
	var node: Node2D = tile["node"]
	if not is_instance_valid(node):
		return
	var target_scale := Vector2(1.025, 1.025) if lifted else Vector2.ONE
	if host.reduced_motion:
		node.scale = target_scale
		return
	var tween := host.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "scale", target_scale, 0.12)


func _animate_swap_tile_to(tile, target_position: Vector2) -> void:
	if tile == null or not is_instance_valid(tile["node"]):
		return
	tile["is_animating"] = true
	var tween := host.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(tile["node"], "position", target_position, host._motion_duration(host.SWAP_ANIMATION_TIME))
	tween.finished.connect(func(t = tile) -> void:
		if is_instance_valid(t["node"]):
			t["is_animating"] = false
		_check_swap_complete()
		host._notify_state_changed(true)
	)


func can_shift_rows() -> bool:
	if host.current_mode != "swap" or host.swap_tiles.is_empty() or host.swap_dragging != null or host.panning or host.pinch_active:
		return false
	if _swap_rows() <= 1:
		return false
	for tile in host.swap_tiles:
		if bool(tile.get("is_animating", false)):
			return false
	return true


func shift_rows(direction: int) -> void:
	var step := signi(direction)
	if step == 0 or not can_shift_rows():
		return
	host._clear_hint_highlights()
	_clear_swap_target_preview()
	var cols := _swap_cols()
	var rows := _swap_rows()
	var pending := {"count": host.swap_tiles.size()}
	for tile in host.swap_tiles:
		var old_slot := int(tile["slot_index"])
		var old_row := int(old_slot / cols)
		var col := old_slot % cols
		var new_row := posmod(old_row + step, rows)
		var new_slot := new_row * cols + col
		var wraps := (step > 0 and old_row == rows - 1) or (step < 0 and old_row == 0)
		tile["slot_index"] = new_slot
		tile["is_animating"] = true
		_animate_row_shift_tile(tile, host._swap_slot_position(new_slot, cols, rows), step, wraps, pending)


func _animate_row_shift_tile(tile, target_position: Vector2, direction: int, wraps: bool, pending: Dictionary) -> void:
	var node: Node2D = tile["node"]
	if not is_instance_valid(node):
		_finish_row_shift_tile(tile, pending)
		return
	if host.reduced_motion:
		node.position = target_position
		_finish_row_shift_tile(tile, pending)
		return
	var duration: float = host.SWAP_ROW_SHIFT_ANIMATION_TIME
	var tween := host.create_tween()
	tween.bind_node(node)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	if wraps:
		var tile_height: float = float(tile.get("size", Vector2.ZERO).y)
		var travel := Vector2(0.0, tile_height * float(direction))
		tween.tween_property(node, "position", node.position + travel, duration * 0.5)
		tween.tween_callback(func() -> void:
			if is_instance_valid(node):
				node.position = target_position - travel
		)
		tween.tween_property(node, "position", target_position, duration * 0.5)
	else:
		tween.tween_property(node, "position", target_position, duration)
	tween.finished.connect(func() -> void:
		_finish_row_shift_tile(tile, pending)
	)


func _finish_row_shift_tile(tile, pending: Dictionary) -> void:
	if tile != null:
		tile["is_animating"] = false
	pending["count"] = maxi(0, int(pending.get("count", 1)) - 1)
	if int(pending["count"]) > 0:
		return
	_check_swap_complete()
	host._trigger_haptic("swap")
	host._notify_state_changed(true)


func _show_swap_hint() -> void:
	var pair := _find_swap_hint_pair()
	if pair.is_empty():
		host._clear_hint_highlights()
		return
	var hint_key := "swap:%d:%d" % [int(pair[0]["correct_index"]), int(pair[1]["correct_index"])]
	if hint_key == host.active_hint_key and host._has_active_hint_highlights():
		host.hint_expires_at_msec = Time.get_ticks_msec() + int(host.SWAP_HINT_DURATION * 1000.0)
		return
	host._clear_hint_highlights()
	host.hint_highlight_token += 1
	host.active_hint_key = hint_key
	host.hint_expires_at_msec = Time.get_ticks_msec() + int(host.SWAP_HINT_DURATION * 1000.0)
	for tile in pair:
		_add_swap_hint_outline(tile)
	host._auto_clear_hint_highlights(host.hint_highlight_token)


func _find_swap_hint_pair() -> Array:
	var by_slot := {}
	for tile in host.swap_tiles:
		by_slot[int(tile["slot_index"])] = tile
	var fallback: Array = []
	for tile in host.swap_tiles:
		if int(tile["slot_index"]) == int(tile["correct_index"]):
			continue
		var occupant = by_slot.get(int(tile["correct_index"]), null)
		if occupant == null or occupant == tile:
			continue
		if int(occupant["correct_index"]) == int(tile["slot_index"]):
			return [tile, occupant]
		if fallback.is_empty():
			fallback = [tile, occupant]
	return fallback


func _add_swap_hint_outline(tile) -> void:
	var node: Node2D = tile["node"]
	if not is_instance_valid(node):
		return
	var size: Vector2 = tile["size"]
	var rect_polygon := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	host._spawn_dashed_outline(
		node,
		[rect_polygon],
		Vector2.ZERO,
		30,
		host.SWAP_HINT_SCREEN_WIDTH,
		host.HINT_TARGET_COLOR,
		true,
	)


func _check_swap_complete() -> void:
	if host.completion_emitted or host.swap_tiles.is_empty():
		return
	for tile in host.swap_tiles:
		if int(tile["slot_index"]) != int(tile["correct_index"]):
			return
	host.completion_emitted = true
	host._trigger_haptic("complete")
	host.completed.emit()


func _swap_cols() -> int:
	return int(host._swap_grid_config()["cols"])


func _swap_rows() -> int:
	return int(host._swap_grid_config()["rows"])
