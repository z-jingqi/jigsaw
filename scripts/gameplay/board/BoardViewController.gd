extends RefCounted
class_name BoardViewController

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func fit_view_to_pieces(animate := true) -> void:
	if host.current_mode != "swap":
		_fit_view_to_board_outline(animate, true)
		return
	var bounds: Rect2 = _world_content_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		reset_view()
		return
	_fit_view_to_world_rect(bounds.grow(host.SWAP_VIEW_FIT_PADDING), animate, true)


func reset_view() -> void:
	_animate_view_to(host.base_view_scale, host.base_view_offset, 0.18, host.current_mode == "swap")


func _reset_view_transform() -> void:
	host.view_scale = 1.0
	host.view_target_scale = 1.0
	host.view_target_ratio = 1.0
	host.base_view_scale = 1.0
	host.base_view_offset = Vector2.ZERO
	host.view_offset = Vector2.ZERO
	_apply_view_transform()


func _apply_view_transform() -> void:
	if host.world_root == null or not is_instance_valid(host.world_root):
		return
	host.world_root.position = host.view_offset
	host.world_root.scale = Vector2.ONE * host.view_scale
	host._refresh_hint_line_widths()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - host.view_offset) / maxf(0.001, host.view_scale)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return world_pos * host.view_scale + host.view_offset


func _view_ratio() -> float:
	return _view_ratio_for_scale(host.view_scale)


func _view_ratio_for_scale(scale: float) -> float:
	return scale / maxf(0.001, host.base_view_scale)


func _clamped_actual_scale(_scale: float) -> float:
	# Layout determines the board size; gestures and saved zoom cannot change it.
	return maxf(0.001, host.base_view_scale)


func _animate_view_to(
	target_scale: float, target_offset: Vector2, duration: float, clamp_target := true
) -> void:
	if host.view_tween != null and host.view_tween.is_valid():
		host.view_tween.kill()
	host.view_target_scale = _clamped_actual_scale(target_scale)
	host.view_target_ratio = _view_ratio_for_scale(host.view_target_scale)
	var start_scale: float = host.view_scale
	var start_offset: Vector2 = host.view_offset
	var final_scale: float = host.view_target_scale
	var final_offset: Vector2 = (
		_clamped_view_offset(target_offset, final_scale) if clamp_target else target_offset
	)
	duration = host._motion_duration(duration)
	host.view_tween = host.create_tween()
	host.view_tween.set_ease(Tween.EASE_OUT)
	host.view_tween.set_trans(Tween.TRANS_CUBIC)
	host.view_tween.tween_method(
		func(t: float) -> void:
			host.view_scale = lerpf(start_scale, final_scale, t)
			host.view_offset = start_offset.lerp(final_offset, t)
			if clamp_target:
				_clamp_view_to_table()
			_apply_view_transform(),
		0.0,
		1.0,
		duration
	)
	host.view_tween.finished.connect(
		func() -> void:
			host.view_scale = final_scale
			host.view_offset = final_offset
			if clamp_target:
				_clamp_view_to_table()
			_apply_view_transform()
			host._notify_state_changed(true)
	)


func _clamp_view_to_table() -> void:
	host.view_offset = _clamped_view_offset(host.view_offset, host.view_scale)


func _clamped_view_offset(offset: Vector2, scale: float) -> Vector2:
	if host.current_mode != "swap":
		return _clamped_board_view_offset(offset, scale)
	var view_rect: Rect2 = _world_view_screen_rect()
	var table: Rect2 = host._virtual_table_area().grow(host.VIEW_FIT_PADDING)
	var clamped: Vector2 = offset
	if table.size.x * scale <= view_rect.size.x:
		clamped.x = view_rect.position.x + view_rect.size.x * 0.5 - table.get_center().x * scale
	else:
		var min_x: float = view_rect.end.x - table.end.x * scale
		var max_x: float = view_rect.position.x - table.position.x * scale
		clamped.x = clampf(offset.x, min_x, max_x)
	if table.size.y * scale <= view_rect.size.y:
		clamped.y = view_rect.position.y + view_rect.size.y * 0.5 - table.get_center().y * scale
	else:
		var min_y: float = view_rect.end.y - table.end.y * scale
		var max_y: float = view_rect.position.y - table.position.y * scale
		clamped.y = clampf(offset.y, min_y, max_y)
	return clamped


func _clamped_board_view_offset(offset: Vector2, scale: float) -> Vector2:
	var view_rect: Rect2 = _world_view_screen_rect()
	var board: Rect2 = _board_outline_world_rect()
	if board.size.x <= 0.0 or board.size.y <= 0.0:
		return offset
	var base_screen := Rect2(
		board.position * host.base_view_scale + host.base_view_offset,
		board.size * host.base_view_scale
	)
	var left_gap := maxf(0.0, base_screen.position.x - view_rect.position.x)
	var right_gap := maxf(0.0, view_rect.end.x - base_screen.end.x)
	var top_gap := maxf(0.0, base_screen.position.y - view_rect.position.y)
	var bottom_gap := maxf(0.0, view_rect.end.y - base_screen.end.y)
	var min_x: float = view_rect.end.x - right_gap - board.end.x * scale
	var max_x: float = view_rect.position.x + left_gap - board.position.x * scale
	var min_y: float = view_rect.end.y - bottom_gap - board.end.y * scale
	var max_y: float = view_rect.position.y + top_gap - board.position.y * scale
	var clamped := offset
	clamped.x = (min_x + max_x) * 0.5 if min_x > max_x else clampf(offset.x, min_x, max_x)
	clamped.y = (min_y + max_y) * 0.5 if min_y > max_y else clampf(offset.y, min_y, max_y)
	return clamped


func _board_outline_world_rect() -> Rect2:
	if host.source_size.x <= 0.0 or host.source_size.y <= 0.0:
		return Rect2(host.board_origin, Vector2.ZERO)
	if host.world_root != null:
		var frame := host.world_root.get_node_or_null("board_line_frame") as Control
		if frame != null:
			return frame.get_rect()
	return Rect2(host.board_origin, host.source_size * host.source_scale).grow(
		float(host.BOARD_LINE_FRAME_WIDTH)
	)


func _world_view_screen_rect() -> Rect2:
	var viewport: Vector2 = host.get_viewport_rect().size
	var content_top: float = clampf(host.hud_top_reserved_height, 0.0, viewport.y)
	var content_bottom: float = (
		viewport.y - host.hud_bottom_reserved_height
		if host.current_mode == "swap"
		else viewport.y - host.hud_bottom_reserved_height - host._tray_area().size.y
	)
	content_bottom = clampf(content_bottom, content_top, viewport.y)
	return Rect2(
		Vector2(0.0, content_top),
		Vector2(viewport.x, maxf(1.0, content_bottom - content_top)),
	)


func _fit_view_to_board_outline(animate: bool, set_baseline := false) -> void:
	var board := Rect2(host.board_origin, host.source_size * host.source_scale)
	if board.size.x <= 0.0 or board.size.y <= 0.0:
		return
	var view_rect: Rect2 = _world_view_screen_rect()
	var edge_gap: float = host.board_screen_edge_gap()
	var usable_size: Vector2 = view_rect.size - Vector2.ONE * edge_gap * 2.0
	var target_scale := maxf(
		0.001,
		minf(
			maxf(1.0, usable_size.x) / maxf(1.0, board.size.x),
			maxf(1.0, usable_size.y) / maxf(1.0, board.size.y),
		)
	)
	var target_offset: Vector2 = view_rect.get_center() - board.get_center() * target_scale
	if set_baseline:
		host.base_view_scale = target_scale
		host.base_view_offset = target_offset
		host.view_target_ratio = 1.0
	if animate:
		_animate_view_to(target_scale, target_offset, 0.22, false)
	else:
		host.view_scale = target_scale
		host.view_target_scale = target_scale
		host.view_target_ratio = _view_ratio_for_scale(target_scale)
		host.view_offset = target_offset
		_apply_view_transform()


func _fit_view_to_world_rect(bounds: Rect2, animate: bool, set_baseline := false) -> void:
	var view_rect: Rect2 = _world_view_screen_rect()
	var target_center := bounds.get_center()
	var target_scale := minf(
		view_rect.size.x / maxf(1.0, bounds.size.x), view_rect.size.y / maxf(1.0, bounds.size.y)
	)
	target_scale = maxf(0.001, target_scale)
	var target_offset: Vector2 = view_rect.get_center() - target_center * target_scale
	target_offset = _clamped_view_offset(target_offset, target_scale)
	if set_baseline:
		host.base_view_scale = target_scale
		host.base_view_offset = target_offset
		host.view_target_ratio = 1.0
	else:
		target_scale = _clamped_actual_scale(target_scale)
		target_offset = view_rect.get_center() - target_center * target_scale
		target_offset = _clamped_view_offset(target_offset, target_scale)
	if animate:
		_animate_view_to(target_scale, target_offset, 0.22)
	else:
		host.view_scale = target_scale
		host.view_target_scale = target_scale
		host.view_target_ratio = _view_ratio_for_scale(target_scale)
		host.view_offset = target_offset
		_clamp_view_to_table()
		_apply_view_transform()


func _base_view_bounds() -> Rect2:
	var board := Rect2(host.board_origin, host.source_size * host.source_scale).grow(
		host.VIEW_FIT_PADDING
	)
	return board.merge(host._virtual_table_area())


func _world_content_bounds() -> Rect2:
	var bounds := Rect2(host.board_origin, host.source_size * host.source_scale)
	var has_bounds := bounds.size.x > 0.0 and bounds.size.y > 0.0
	for tile in host.swap_tiles:
		var tile_bounds: Rect2 = host._swap_tile_bounds(tile, tile["node"].position)
		if tile_bounds.size.x <= 0.0 or tile_bounds.size.y <= 0.0:
			continue
		bounds = bounds.merge(tile_bounds) if has_bounds else tile_bounds
		has_bounds = true
	for group in host.groups:
		if group.in_tray:
			continue
		var group_bounds: Rect2 = host._group_bounds_at(group, group.node.position)
		if group_bounds.size.x <= 0.0 or group_bounds.size.y <= 0.0:
			continue
		bounds = bounds.merge(group_bounds) if has_bounds else group_bounds
		has_bounds = true
	return bounds if has_bounds else _base_view_bounds()
