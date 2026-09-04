extends RefCounted
class_name BoardTrayController

const TRAY_HIT_PADDING := 18.0
const KineticsScript := preload("res://scripts/ui/motion/ScrollKinetics.gd")
const ReturnMotionScript := preload("res://scripts/gameplay/board/TrayReturnMotion.gd")
const GlassMaterialScript := preload("res://scripts/gameplay/board/TrayGlassMaterial.gd")

var host: Node2D
var _scroll_motion := KineticsScript.new()
var _tray_back_buffer: BackBufferCopy


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
	if _tray_back_buffer == null or not is_instance_valid(_tray_back_buffer):
		_tray_back_buffer = BackBufferCopy.new()
		_tray_back_buffer.name = "tray_back_buffer"
		_tray_back_buffer.copy_mode = BackBufferCopy.COPY_MODE_RECT
		_tray_back_buffer.z_index = -30
		host.tray_root.add_child(_tray_back_buffer)
	if host.tray_background == null or not is_instance_valid(host.tray_background):
		host.tray_background = Panel.new()
		host.tray_background.name = "tray_background"
		host.tray_background.z_index = -20
		host.tray_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var initial_background_style := StyleBoxFlat.new()
		initial_background_style.bg_color = Color.WHITE
		host.tray_background.add_theme_stylebox_override("panel", initial_background_style)
		host.tray_background.material = GlassMaterialScript.create_material()
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
	var screen_transform := host.get_viewport().get_screen_transform()
	var copy_position: Vector2 = screen_transform * area.position
	var copy_end: Vector2 = screen_transform * area.end
	_tray_back_buffer.rect = Rect2(copy_position, copy_end - copy_position).grow(
		GlassMaterialScript.BACK_BUFFER_MARGIN_PIXELS
	)
	host.tray_background.position = area.position
	host.tray_background.size = area.size
	host.tray_top_border.position = area.position
	host.tray_top_border.size = Vector2(area.size.x, host.TRAY_TOP_BORDER_HEIGHT * layout_scale)


func _layout_tray(instant := false) -> void:
	_ensure_tray_top_border()
	_rebalance_tray_lanes()
	_update_tray_content_width()
	# Resolve the final scroll position before assigning any slots. Previously a
	# shortened tray could lay out once, clamp, then immediately restart every
	# motion against a second set of targets.
	_clamp_tray_scroll()
	_layout_tray_items(instant)
	if instant:
		host._refresh_hint_line_widths()


func _layout_tray_items(instant := false) -> void:
	var area: Rect2 = _tray_area()
	var leading_x: float = area.position.x + host.TRAY_PADDING - host.tray_scroll_offset
	var groups_by_lane: Array = _tray_groups_by_lane()

	# Keep a stable two-row rail. Each row owns its own ordered queue, while every
	# position uses the same square cell. Picking a piece therefore leaves a real
	# placeholder; a committed removal only closes that row's gap instead of
	# recomputing widths and disturbing both rows.
	var cell_width: float = _tray_cell_width(area)
	var column_pitch: float = cell_width + host.TRAY_GAP
	for lane in host.TRAY_ROW_COUNT:
		var lane_groups: Array = groups_by_lane[lane]
		for column in lane_groups.size():
			var group = lane_groups[column]
			if not group.in_tray:
				continue
			var geometry := _tray_display_geometry(group, area)
			var scaled_size: Vector2 = geometry["scaled_size"]
			var cell_x: float = leading_x + float(column) * column_pitch
			var piece_x: float = cell_x + (cell_width - scaled_size.x) * 0.5
			_move_group_to_tray(group, group.tray_index, instant, piece_x)


func _tray_groups_by_lane() -> Array:
	var groups_by_lane: Array = []
	for lane in host.TRAY_ROW_COUNT:
		groups_by_lane.append([])
	for index in host.tray_groups.size():
		var group = host.tray_groups[index]
		if group == null or not is_instance_valid(group.node):
			continue
		if group.tray_lane < 0 or group.tray_lane >= host.TRAY_ROW_COUNT:
			group.tray_lane = index % host.TRAY_ROW_COUNT
		groups_by_lane[group.tray_lane].append(group)
	return groups_by_lane


func _update_tray_content_width() -> void:
	var column_count := 0
	for lane_groups in _tray_groups_by_lane():
		column_count = maxi(column_count, lane_groups.size())
	var content_span := 0.0
	if column_count > 0:
		var cell_width: float = _tray_cell_width(_tray_area())
		content_span = (
			float(column_count) * cell_width
			+ float(column_count - 1) * host.TRAY_GAP
		)
	host.tray_content_width = host.TRAY_PADDING + content_span


func _clamp_tray_scroll() -> void:
	var area: Rect2 = _tray_area()
	host.tray_scroll_offset = clampf(
		host.tray_scroll_offset,
		0.0,
		maxf(0.0, host.tray_content_width - area.size.x + host.TRAY_PADDING)
	)


func _pan_tray(delta_x: float, record_velocity := true) -> void:
	var previous: float = host.tray_scroll_offset
	if host.hint_pending or not host.hint_highlighted_groups.is_empty():
		host._clear_hint_highlights()
	if record_velocity:
		host.tray_scroll_offset = _scroll_motion.drag_by(delta_x, 0.0, _maximum_scroll())
		host.tray_last_pan_msec = Time.get_ticks_msec()
	else:
		host.tray_scroll_offset -= delta_x
	_clamp_tray_scroll()
	_shift_tray_items(previous - host.tray_scroll_offset)


func _shift_tray_items(delta_x: float) -> void:
	if is_zero_approx(delta_x):
		return
	# Scrolling only translates existing slots. Geometry, styling and scale stay fixed.
	for group in host.tray_groups:
		if group == null or not is_instance_valid(group.node):
			continue
		group.tray_slot.position.x += delta_x
		if group.in_tray:
			group.node.position.x += delta_x


func _start_tray_inertia() -> void:
	if absf(host.tray_scroll_velocity) < KineticsScript.STOP_SPEED:
		_stop_tray_inertia()
		host._notify_state_changed(true)
		return
	host.tray_inertia_active = true


func _stop_tray_inertia() -> void:
	host.tray_inertia_active = false
	host.tray_scroll_velocity = 0.0
	host.tray_last_pan_msec = 0
	_scroll_motion.stop()


func _begin_tray_pan() -> void:
	host.tray_panning = true
	host.tray_inertia_active = false
	host.tray_scroll_velocity = 0.0
	host.tray_last_pan_msec = Time.get_ticks_msec()
	_scroll_motion.begin(host.tray_scroll_offset)


func _release_tray_pan() -> void:
	host.tray_panning = false
	host.tray_scroll_velocity = _scroll_motion.release()
	_start_tray_inertia()


func process_scroll(delta: float) -> void:
	if not host.tray_inertia_active or host.tray_panning:
		return
	var previous: float = host.tray_scroll_offset
	host.tray_scroll_offset = _scroll_motion.advance(delta, 0.0, _maximum_scroll())
	host.tray_scroll_velocity = _scroll_motion.velocity
	_shift_tray_items(previous - host.tray_scroll_offset)
	if is_zero_approx(_scroll_motion.velocity):
		_stop_tray_inertia()
		host._notify_state_changed(true)


func _maximum_scroll() -> float:
	return maxf(0.0, host.tray_content_width - _tray_area().size.x + host.TRAY_PADDING)


func _tray_original_screen_scale() -> float:
	var scale: float = host.base_view_scale if host.base_view_scale > 0.0 else host.view_scale
	return maxf(0.001, scale)


func resume_held_scroll(group, point: Vector2, relative: Vector2, grab: Vector2) -> void:
	# Preserve the displayed pose and this event's real finger movement before reparenting.
	var from_position: Vector2 = host._world_to_screen(group.node.position) + relative
	var from_scale: float = group.node.scale.x * host.view_scale
	_move_group_to_tray(group, group.tray_index, true, group.tray_slot.position.x)
	var grab_x: float = group.node.position.x + grab.x * group.node.scale.x
	_pan_tray(point.x - grab_x, false)
	# World-space movement must never leak into the tray's release velocity.
	_begin_tray_pan()
	ReturnMotionScript.begin(host, group, from_position, from_scale, true)
	raise_group_for_drag(group)


func raise_group_for_drag(group) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	group.node.z_index = host.TRAY_DRAG_Z_INDEX


func restore_group_tray_z(group) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	group.node.z_index = _tray_resting_z(group.tray_index)


func _move_group_to_tray(group, index: int, instant := false, forced_x := NAN) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	ReturnMotionScript.stop(group)
	var current_screen_position: Vector2 = group.node.position
	var current_screen_scale: float = group.node.scale.x
	var returned_from_world: bool = group.node.get_parent() == host.world_root
	if group.node.get_parent() == host.world_root:
		if group.tray_return_pose_valid:
			current_screen_position = group.tray_return_screen_position
			current_screen_scale = group.tray_return_screen_scale
		else:
			current_screen_position = host._world_to_screen(group.node.position)
			current_screen_scale *= host.view_scale
		group.clear_tray_return_pose()
	if group.node.get_parent() != host.tray_root:
		if group.node.get_parent() != null:
			group.node.get_parent().remove_child(group.node)
		host.tray_root.add_child(group.node)
		group.node.position = current_screen_position
	group.in_tray = true
	group.locked = false
	group.tray_index = index
	if group.tray_lane < 0 or group.tray_lane >= host.TRAY_ROW_COUNT:
		group.tray_lane = index % host.TRAY_ROW_COUNT
	group.node.rotation_degrees = 0.0
	var area: Rect2 = _tray_area()
	var geometry := _tray_display_geometry(group, area)
	var bounds: Rect2 = geometry["bounds"]
	var row_area: Rect2 = geometry["row_area"]
	var scale: float = geometry["scale"]
	group.tray_scale = scale
	var scaled_size: Vector2 = geometry["scaled_size"]
	var x: float = (
		forced_x
		if not is_nan(forced_x)
		else (
			area.position.x
			+ host.TRAY_PADDING
			+ float(index / host.TRAY_ROW_COUNT) * (_tray_cell_width(area) + host.TRAY_GAP)
			+ (_tray_cell_width(area) - scaled_size.x) * 0.5
		)
	)
	var top_left: Vector2 = Vector2(
		x, row_area.position.y + (row_area.size.y - scaled_size.y) * 0.5
	)
	group.tray_slot = Rect2(top_left, scaled_size)
	var target_position: Vector2 = top_left - bounds.position * scale
	# TrayRoot already sits close to CanvasItem.MAX_Z. Keep resting children below
	# the dedicated drag layer instead of letting their relative z values clamp
	# to the same effective z as the held piece.
	group.node.z_index = (
		host.TRAY_DRAG_Z_INDEX
		if returned_from_world and not instant
		else _tray_resting_z(index)
	)
	group.node.scale = Vector2.ONE * scale
	group.node.position = target_position
	var needs_motion := (
		current_screen_position.distance_to(target_position) > 0.5
		or absf(current_screen_scale - scale) > 0.001
	)
	if not instant and needs_motion:
		ReturnMotionScript.begin(
			host,
			group,
			current_screen_position,
			current_screen_scale,
			returned_from_world
		)


func _tray_cell_width(area: Rect2) -> float:
	# A slightly narrower-than-tall cell keeps both rows aligned without stretching
	# the search strip. Wide pieces scale down to fit; narrow ones keep this rhythm.
	return maxf(96.0, _tray_row_area(area, 0).size.y * 0.92)


func _tray_display_geometry(group, area: Rect2) -> Dictionary:
	var bounds: Rect2 = _group_local_bounds(group)
	var row_area: Rect2 = _tray_row_area(area, group.tray_lane)
	var original_scale: float = _tray_original_screen_scale()
	var original_size: Vector2 = bounds.size * original_scale
	var fit := minf(
		1.0,
		minf(
			_tray_cell_width(area) / maxf(1.0, original_size.x),
			row_area.size.y / maxf(1.0, original_size.y)
		)
	)
	var scale := original_scale * fit
	return {
		"bounds": bounds,
		"row_area": row_area,
		"scale": scale,
		"scaled_size": bounds.size * scale,
	}


func _tray_row_area(area: Rect2, lane: int) -> Rect2:
	var total_gap: float = host.TRAY_ROW_GAP * float(maxi(0, host.TRAY_ROW_COUNT - 1))
	var usable_height: float = maxf(
		24.0 * float(host.TRAY_ROW_COUNT),
		area.size.y - host.TRAY_VERTICAL_SAFE_GAP * 2.0 - total_gap
	)
	var row_height: float = usable_height / float(host.TRAY_ROW_COUNT)
	var row_y: float = (
		area.position.y
		+ host.TRAY_VERTICAL_SAFE_GAP
		+ float(clampi(lane, 0, host.TRAY_ROW_COUNT - 1)) * (row_height + host.TRAY_ROW_GAP)
	)
	return Rect2(Vector2(area.position.x, row_y), Vector2(area.size.x, row_height))


func _rebalance_tray_lanes() -> void:
	var row_count: int = maxi(1, host.TRAY_ROW_COUNT)
	if row_count <= 1:
		for group in host.tray_groups:
			if group != null:
				group.tray_lane = 0
		return
	var lane_counts: Array[int] = []
	lane_counts.resize(row_count)
	for index in host.tray_groups.size():
		var group = host.tray_groups[index]
		if group == null:
			continue
		if group.tray_lane < 0 or group.tray_lane >= row_count:
			group.tray_lane = index % row_count
		lane_counts[group.tray_lane] += 1
	var order_changed := false
	while true:
		var fullest_lane := 0
		var emptiest_lane := 0
		for lane in range(1, row_count):
			if lane_counts[lane] > lane_counts[fullest_lane]:
				fullest_lane = lane
			if lane_counts[lane] < lane_counts[emptiest_lane]:
				emptiest_lane = lane
		if lane_counts[fullest_lane] - lane_counts[emptiest_lane] <= 1:
			break
		# Move only the last piece in the fuller row. This keeps the other pieces
		# stable and lets the existing tray return motion animate the row change.
		var donor = null
		for index in range(host.tray_groups.size() - 1, -1, -1):
			var candidate = host.tray_groups[index]
			if candidate == null or candidate.tray_lane != fullest_lane:
				continue
			donor = candidate
			break
		if donor == null:
			break
		donor.tray_lane = emptiest_lane
		# Lane order is derived from tray_groups. Append the source-row tail so it
		# truly lands at the destination tail instead of being inserted somewhere
		# in the middle because of the old interleaved global order.
		host.tray_groups.erase(donor)
		host.tray_groups.append(donor)
		order_changed = true
		lane_counts[fullest_lane] -= 1
		lane_counts[emptiest_lane] += 1
	if order_changed:
		for index in host.tray_groups.size():
			var group = host.tray_groups[index]
			if group != null:
				group.tray_index = index


func _tray_resting_z(index: int) -> int:
	var highest_local_z: int = maxi(
		0, host.TRAY_DRAG_Z_INDEX - host.TRAY_Z_INDEX - 1
	)
	return mini(maxi(0, index) * host.GROUP_Z_STEP, highest_local_z)


func _tray_group_at_screen(screen_pos: Vector2, exclude = null, hit_padding := TRAY_HIT_PADDING):
	for i in range(host.tray_groups.size() - 1, -1, -1):
		var group = host.tray_groups[i]
		if group == exclude:
			continue
		if (
			group != null
			and group.in_tray
			and _tray_group_screen_rect(group).grow(hit_padding).has_point(screen_pos)
		):
			return group
	return null


func _tray_group_screen_rect(group) -> Rect2:
	var bounds := _group_local_bounds(group)
	var scale: float = group.node.scale.x
	return Rect2(group.node.position + bounds.position * scale, bounds.size * scale)


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
	ReturnMotionScript.stop(group)
	if group.node.get_parent() != host.world_root:
		if group.node.get_parent() != null:
			group.node.get_parent().remove_child(group.node)
		host.world_root.add_child(group.node)
	group.node.scale = Vector2.ONE * local_scale
	group.node.position = world_position
	group.in_tray = false
	host._bring_to_front(group)
