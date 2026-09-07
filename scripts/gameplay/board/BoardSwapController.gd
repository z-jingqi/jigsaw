extends RefCounted
class_name BoardSwapController

const GridShiftScript := preload("res://scripts/gameplay/board/SwapGridShift.gd")

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
		_animate_swap_tile_to(
			released,
			host._swap_slot_position(host.swap_drag_start_slot, _swap_cols(), _swap_rows())
		)
	else:
		var target_slot := int(target["slot_index"])
		released["slot_index"] = target_slot
		target["slot_index"] = host.swap_drag_start_slot
		_animate_swap_tile_to(
			released, host._swap_slot_position(target_slot, _swap_cols(), _swap_rows())
		)
		_animate_swap_tile_to(
			target, host._swap_slot_position(host.swap_drag_start_slot, _swap_cols(), _swap_rows())
		)
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
	var polygon := PackedVector2Array(
		[Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]
	)
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
		if tile == exclude or bool(tile.get("is_animating", false)):
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
	var visual := node.get_child(0) as Node2D
	host.PieceVisualFactoryScript.set_visual_lifted(visual, lifted, host, not host.reduced_motion)


func _animate_swap_tile_to(tile, target_position: Vector2) -> void:
	if tile == null or not is_instance_valid(tile["node"]):
		return
	var previous: Tween = tile.get("position_tween", null)
	if previous != null and previous.is_valid():
		previous.kill()
	tile["is_animating"] = true
	var tween := host.create_tween().bind_node(tile["node"])
	tile["position_tween"] = tween
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(
		tile["node"], "position", target_position, host._motion_duration(host.SWAP_ANIMATION_TIME)
	)
	tween.finished.connect(
		func(t = tile) -> void:
			if is_instance_valid(t["node"]):
				t["is_animating"] = false
				t["position_tween"] = null
			_check_swap_complete()
			host._notify_state_changed(true)
	)


func can_shift_rows() -> bool:
	return GridShiftScript.can_shift(host, false)


func shift_rows(direction: int) -> void:
	GridShiftScript.shift(host, direction, false)


func shift_columns(direction: int) -> void:
	GridShiftScript.shift(host, direction, true)


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
	var by_correct := {}
	for tile in host.swap_tiles:
		if bool(tile.get("is_animating", false)):
			return []
		by_slot[int(tile["slot_index"])] = tile
		by_correct[int(tile["correct_index"])] = tile
	for slot in range(_swap_cols() * _swap_rows()):
		var occupant = by_slot.get(slot)
		if occupant == null or int(occupant["correct_index"]) == slot:
			continue
		var correct_piece = by_correct.get(slot)
		if correct_piece != null:
			return [correct_piece, occupant]
	return []


func _add_swap_hint_outline(tile) -> void:
	var node: Node2D = tile["node"]
	if not is_instance_valid(node):
		return
	var size: Vector2 = tile["size"]
	var rect_polygon := PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(size.x, 0.0),
			size,
			Vector2(0.0, size.y),
		]
	)
	(
		host
		. _spawn_dashed_outline(
			node,
			[rect_polygon],
			Vector2.ZERO,
			30,
			host.SWAP_HINT_SCREEN_WIDTH,
			host.HINT_TARGET_COLOR,
			true,
		)
	)


func _check_swap_complete() -> void:
	if host.completion_emitted or host.swap_tiles.is_empty():
		return
	for tile in host.swap_tiles:
		if bool(tile.get("is_animating", false)):
			return
		if int(tile["slot_index"]) != int(tile["correct_index"]):
			return
	host.completion_emitted = true
	host._trigger_haptic("complete")
	host.completed.emit()


func _swap_cols() -> int:
	return int(host._swap_grid_config()["cols"])


func _swap_rows() -> int:
	return int(host._swap_grid_config()["rows"])
