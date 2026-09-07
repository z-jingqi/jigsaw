extends RefCounted
## Shared cyclic row and column movement. No retained board reference.


static func can_shift(host: Node2D, horizontal: bool) -> bool:
	if (
		host.current_mode != "swap"
		or host.swap_tiles.is_empty()
		or host.swap_dragging != null
		or host.panning
		or host.pinch_active
	):
		return false
	if (host._swap_cols() if horizontal else host._swap_rows()) <= 1:
		return false
	for tile in host.swap_tiles:
		if bool(tile.get("is_animating", false)):
			return false
	return true


static func shift(host: Node2D, direction: int, horizontal: bool) -> void:
	var step := signi(direction)
	if step == 0 or not can_shift(host, horizontal):
		return
	host._clear_hint_highlights()
	host._clear_swap_target_preview()
	var cols: int = host._swap_cols()
	var rows: int = host._swap_rows()
	var pending := {"count": host.swap_tiles.size()}
	for tile in host.swap_tiles:
		var old_slot := int(tile["slot_index"])
		var old_row := int(old_slot / cols)
		var col := old_slot % cols
		var axis_index := col if horizontal else old_row
		var axis_count := cols if horizontal else rows
		var next_index := posmod(axis_index + step, axis_count)
		var new_slot := old_row * cols + next_index if horizontal else next_index * cols + col
		var wraps := (step > 0 and axis_index == axis_count - 1) or (step < 0 and axis_index == 0)
		tile["slot_index"] = new_slot
		tile["is_animating"] = true
		_animate_tile(
			host,
			tile,
			host._swap_slot_position(new_slot, cols, rows),
			Vector2(step, 0) if horizontal else Vector2(0, step),
			wraps,
			pending
		)


static func _animate_tile(
	host: Node2D,
	tile,
	target_position: Vector2,
	direction: Vector2,
	wraps: bool,
	pending: Dictionary
) -> void:
	var node: Node2D = tile["node"]
	if not is_instance_valid(node):
		_finish_tile(host, tile, pending)
		return
	if host.reduced_motion:
		node.position = target_position
		_finish_tile(host, tile, pending)
		return
	var duration: float = host.SWAP_ROW_SHIFT_ANIMATION_TIME
	var tween := host.create_tween()
	tween.bind_node(node)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	if wraps:
		var travel: Vector2 = tile.get("size", Vector2.ZERO) * direction
		tween.tween_property(node, "position", node.position + travel, duration * 0.5)
		tween.tween_callback(
			func() -> void:
				if is_instance_valid(node):
					node.position = target_position - travel
		)
		tween.tween_property(node, "position", target_position, duration * 0.5)
	else:
		tween.tween_property(node, "position", target_position, duration)
	tween.finished.connect(func() -> void: _finish_tile(host, tile, pending))


static func _finish_tile(host: Node2D, tile, pending: Dictionary) -> void:
	if tile != null:
		tile["is_animating"] = false
	pending["count"] = maxi(0, int(pending.get("count", 1)) - 1)
	if int(pending["count"]) > 0:
		return
	host._check_swap_complete()
	host._trigger_haptic("swap")
	host._notify_state_changed(true)
