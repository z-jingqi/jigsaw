extends Node2D
class_name PuzzleBoard

signal status_changed(text: String)
signal zoom_changed(percent: int)
signal completed

const SNAP_TOLERANCE := 22.0
const ROTATION_TOLERANCE := 3.0
const HIT_ALPHA_RADIUS := 2
const PIECE_DRAG_PADDING := 8.0
const PIECE_SPAWN_EDGE_PADDING := 22.0
const PIECE_SPAWN_SEPARATION := 34.0
const VIEW_MIN_RATIO := 1.0
const VIEW_MAX_RATIO := 2.0
const VIEW_WHEEL_STEP := 0.08
const TRACKPAD_MAGNIFY_MIN := 0.86
const TRACKPAD_MAGNIFY_MAX := 1.16
const VIEW_FIT_PADDING := 36.0
const VIEW_HINT_PADDING := 58.0
const VIEW_HINT_MAX_RATIO := 1.45
const HINT_GLOW_COLOR := Color(1.0, 0.72, 0.16, 0.34)
const HINT_OUTLINE_COLOR := Color(1.0, 0.82, 0.26, 0.96)
const SWAP_COLS := 3
const SWAP_ROWS := 4
const SWAP_ANIMATION_TIME := 0.20
const TABLE_EXTRA_MIN := 180.0
const TABLE_EXTRA_MAX := 620.0
const ORGANIZE_GAP := 22.0
const ORGANIZE_MIN_SCREEN_GAP := 48.0
const GROUP_Z_STEP := 64
const BoardLayoutScript := preload("res://scripts/BoardLayout.gd")
const PieceGroupScript := preload("res://scripts/PieceGroup.gd")
const PieceVisualFactoryScript := preload("res://scripts/PieceVisualFactory.gd")
const SnapSolverScript := preload("res://scripts/SnapSolver.gd")

var texture: Texture2D
var source_image: Image
var source_size := Vector2.ZERO
var source_scale := 1.0
var board_origin := Vector2.ZERO
var active_level_config := {}
var current_mode := "knob"
var rng := RandomNumberGenerator.new()
var world_root: Node2D
var view_scale := 1.0
var view_target_scale := 1.0
var view_target_ratio := 1.0
var base_view_scale := 1.0
var base_view_offset := Vector2.ZERO
var view_offset := Vector2.ZERO
var view_tween: Tween
var groups: Array = []
var swap_tiles: Array = []
var spawn_bounds: Array[Rect2] = []
var dragging = null
var swap_dragging = null
var swap_drag_start_slot := -1
var swap_drag_offset := Vector2.ZERO
var selected_group = null
var hint_highlighted_groups: Array = []
var hint_highlighted_lines: Array[Line2D] = []
var active_touch_index := -1
var active_touches := {}
var drag_offset := Vector2.ZERO
var panning := false
var pan_touch_index := -1
var pan_last_screen := Vector2.ZERO
var pinch_active := false
var pinch_start_distance := 0.0
var pinch_start_scale := 1.0
var pinch_start_world_midpoint := Vector2.ZERO
var hud_icon_size := 56.0
var drag_blockers: Array[Rect2] = []
var completion_emitted := false
var randomize_piece_rotation := false
var hint_highlight_token := 0


func _ready() -> void:
	rng.seed = 7


func start(level_config: Dictionary, play_mode: String, source_texture: Texture2D, image: Image, image_size: Vector2, icon_size: float, random_rotation_enabled := false) -> bool:
	clear()
	active_level_config = level_config
	current_mode = _mode_key(play_mode)
	texture = source_texture
	source_image = image
	source_size = image_size
	hud_icon_size = icon_size
	randomize_piece_rotation = random_rotation_enabled and current_mode != "swap"
	completion_emitted = false
	_add_level_background(active_level_config)
	world_root = Node2D.new()
	world_root.name = "world_root"
	add_child(world_root)
	_reset_view_transform()
	return _start_play_session(current_mode)


func clear() -> void:
	for child in get_children():
		child.queue_free()
	groups.clear()
	swap_tiles.clear()
	spawn_bounds.clear()
	dragging = null
	swap_dragging = null
	swap_drag_start_slot = -1
	swap_drag_offset = Vector2.ZERO
	selected_group = null
	hint_highlighted_groups.clear()
	hint_highlighted_lines.clear()
	hint_highlight_token = 0
	drag_blockers.clear()
	active_touch_index = -1
	active_touches.clear()
	panning = false
	pan_touch_index = -1
	pinch_active = false
	world_root = null
	view_scale = 1.0
	view_target_scale = 1.0
	view_target_ratio = 1.0
	base_view_scale = 1.0
	base_view_offset = Vector2.ZERO
	view_offset = Vector2.ZERO
	view_tween = null
	completion_emitted = false
	randomize_piece_rotation = false


func handle_input(event: InputEvent, modal_open: bool) -> bool:
	if modal_open:
		return false
	if event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		var factor := clampf(magnify.factor, TRACKPAD_MAGNIFY_MIN, TRACKPAD_MAGNIFY_MAX)
		_zoom_view_at(magnify.position, view_scale * factor)
		return true
	if event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		_pan_view(-pan.delta)
		return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_zoom_view_at(mouse_event.position, view_scale + base_view_scale * VIEW_WHEEL_STEP)
			return true
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_zoom_view_at(mouse_event.position, view_scale - base_view_scale * VIEW_WHEEL_STEP)
			return true
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			var double_group = _group_at_world(_screen_to_world(mouse_event.position))
			if double_group != null and randomize_piece_rotation:
				_select_group(double_group)
				_rotate_group(double_group)
			elif double_group == null:
				reset_view()
			return true
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_drag(mouse_event.position)
			else:
				_end_drag()
				_end_pan()
			return true
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if swap_dragging != null:
			_move_swap_tile_to(swap_dragging, _screen_to_world(motion.position) + swap_drag_offset)
			return true
		if dragging != null:
			_move_group_to(dragging, _screen_to_world(motion.position) + drag_offset)
			return true
		if panning:
			_pan_view(motion.relative)
			return true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			active_touches[touch.index] = touch.position
			if active_touches.size() >= 2:
				_begin_pinch()
				return true
			if touch.double_tap:
				var double_group = _group_at_world(_screen_to_world(touch.position))
				if double_group != null and randomize_piece_rotation:
					_select_group(double_group)
					_rotate_group(double_group)
				elif double_group == null:
					reset_view()
			else:
				active_touch_index = touch.index
				_begin_drag(touch.position)
			return true
		active_touches.erase(touch.index)
		if touch.index == active_touch_index:
			_end_drag()
			active_touch_index = -1
		if touch.index == pan_touch_index:
			_end_pan()
		if active_touches.size() < 2:
			pinch_active = false
		return true
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		active_touches[drag_event.index] = drag_event.position
		if pinch_active and active_touches.size() >= 2:
			_update_pinch()
			return true
		if swap_dragging != null and drag_event.index == active_touch_index:
			_move_swap_tile_to(swap_dragging, _screen_to_world(drag_event.position) + swap_drag_offset)
			return true
		if dragging != null and drag_event.index == active_touch_index:
			_move_group_to(dragging, _screen_to_world(drag_event.position) + drag_offset)
			return true
		if panning and drag_event.index == pan_touch_index:
			_pan_view(drag_event.relative)
			return true
	return false


func organize_pieces() -> void:
	if current_mode == "swap":
		reset_view()
		status_changed.emit("方格交换模式只需要拖动两块图片互换位置。")
		return
	if groups.is_empty():
		return
	_clear_hint_highlights()
	var movable := _organizable_groups(false)
	if movable.is_empty():
		movable = _organizable_groups(true)
	if movable.is_empty():
		status_changed.emit("当前碎片已经很接近完成位置。")
		return
	movable.sort_custom(func(a, b) -> bool:
		return _group_sort_area(a) > _group_sort_area(b)
	)
	var placements := _organized_group_positions(movable)
	for group in movable:
		if not placements.has(group):
			continue
		_animate_group_to(group, placements[group])
	await _wait_for_group_layout_animation()
	status_changed.emit("已整理未完成的碎片。")


func fit_view_to_pieces(animate := true) -> void:
	var bounds := _world_content_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		reset_view()
		return
	_fit_view_to_world_rect(bounds.grow(VIEW_FIT_PADDING), animate, 1.0, true)


func reset_view() -> void:
	_animate_view_to(base_view_scale, base_view_offset, 0.18)


func _reset_view_transform() -> void:
	view_scale = 1.0
	view_target_scale = 1.0
	view_target_ratio = 1.0
	base_view_scale = 1.0
	base_view_offset = Vector2.ZERO
	view_offset = Vector2.ZERO
	_apply_view_transform()


func _apply_view_transform() -> void:
	if world_root == null or not is_instance_valid(world_root):
		return
	world_root.position = view_offset
	world_root.scale = Vector2.ONE * view_scale
	zoom_changed.emit(roundi(_view_ratio() * 100.0))


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - view_offset) / maxf(0.001, view_scale)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return world_pos * view_scale + view_offset


func _view_ratio() -> float:
	return _view_ratio_for_scale(view_scale)


func _view_ratio_for_scale(scale: float) -> float:
	return scale / maxf(0.001, base_view_scale)


func _clamped_actual_scale(scale: float) -> float:
	return clampf(scale, base_view_scale * VIEW_MIN_RATIO, base_view_scale * VIEW_MAX_RATIO)


func _zoom_view_at(screen_anchor: Vector2, target_scale: float) -> void:
	var before := _screen_to_world(screen_anchor)
	view_scale = _clamped_actual_scale(target_scale)
	view_target_scale = view_scale
	view_target_ratio = _view_ratio_for_scale(view_scale)
	view_offset = screen_anchor - before * view_scale
	_clamp_view_to_table()
	_apply_view_transform()


func _animate_view_to(target_scale: float, target_offset: Vector2, duration: float) -> void:
	if view_tween != null and view_tween.is_valid():
		view_tween.kill()
	view_target_scale = _clamped_actual_scale(target_scale)
	view_target_ratio = _view_ratio_for_scale(view_target_scale)
	var start_scale := view_scale
	var start_offset := view_offset
	var final_scale := view_target_scale
	var final_offset := _clamped_view_offset(target_offset, final_scale)
	view_tween = create_tween()
	view_tween.set_ease(Tween.EASE_OUT)
	view_tween.set_trans(Tween.TRANS_CUBIC)
	view_tween.tween_method(func(t: float) -> void:
		view_scale = lerpf(start_scale, final_scale, t)
		view_offset = start_offset.lerp(final_offset, t)
		_clamp_view_to_table()
		_apply_view_transform()
	, 0.0, 1.0, duration)
	view_tween.finished.connect(func() -> void:
		view_scale = final_scale
		view_offset = final_offset
		_clamp_view_to_table()
		_apply_view_transform()
	)


func _pan_view(delta: Vector2) -> void:
	view_offset += delta
	_clamp_view_to_table()
	_apply_view_transform()


func _begin_pan(screen_pos: Vector2, touch_index: int) -> void:
	panning = true
	pan_touch_index = touch_index
	pan_last_screen = screen_pos
	status_changed.emit("拖动桌布可移动视角，双指可缩放。")


func _end_pan() -> void:
	panning = false
	pan_touch_index = -1


func _begin_pinch() -> void:
	_end_drag()
	_end_pan()
	var points := _active_touch_points()
	if points.size() < 2:
		return
	pinch_active = true
	pinch_start_distance = maxf(1.0, points[0].distance_to(points[1]))
	pinch_start_scale = view_scale
	var midpoint := (points[0] + points[1]) * 0.5
	pinch_start_world_midpoint = _screen_to_world(midpoint)


func _update_pinch() -> void:
	var points := _active_touch_points()
	if points.size() < 2:
		return
	var distance := maxf(1.0, points[0].distance_to(points[1]))
	var midpoint := (points[0] + points[1]) * 0.5
	view_scale = _clamped_actual_scale(pinch_start_scale * distance / pinch_start_distance)
	view_target_scale = view_scale
	view_target_ratio = _view_ratio_for_scale(view_scale)
	view_offset = midpoint - pinch_start_world_midpoint * view_scale
	_clamp_view_to_table()
	_apply_view_transform()


func _active_touch_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for key in active_touches.keys():
		points.append(active_touches[key])
		if points.size() >= 2:
			break
	return points


func _clamp_view_to_table() -> void:
	view_offset = _clamped_view_offset(view_offset, view_scale)


func _clamped_view_offset(offset: Vector2, scale: float) -> Vector2:
	var viewport := get_viewport_rect().size
	var table := _virtual_table_area().grow(VIEW_FIT_PADDING)
	var clamped := offset
	if table.size.x * scale <= viewport.x:
		clamped.x = viewport.x * 0.5 - table.get_center().x * scale
	else:
		var min_x := viewport.x - table.end.x * scale
		var max_x := -table.position.x * scale
		clamped.x = clampf(offset.x, min_x, max_x)
	if table.size.y * scale <= viewport.y:
		clamped.y = viewport.y * 0.5 - table.get_center().y * scale
	else:
		var min_y := viewport.y - table.end.y * scale
		var max_y := -table.position.y * scale
		clamped.y = clampf(offset.y, min_y, max_y)
	return clamped


func _fit_view_to_world_rect(bounds: Rect2, animate: bool, max_ratio := VIEW_MAX_RATIO, set_baseline := false) -> void:
	var viewport := get_viewport_rect().size
	var target_center := bounds.get_center()
	var target_scale := minf(viewport.x / maxf(1.0, bounds.size.x), viewport.y / maxf(1.0, bounds.size.y))
	target_scale = maxf(0.001, target_scale)
	var target_offset := viewport * 0.5 - target_center * target_scale
	target_offset = _clamped_view_offset(target_offset, target_scale)
	if set_baseline:
		base_view_scale = target_scale
		base_view_offset = target_offset
		view_target_ratio = 1.0
	else:
		target_scale = clampf(target_scale, base_view_scale * VIEW_MIN_RATIO, base_view_scale * minf(max_ratio, VIEW_MAX_RATIO))
		target_offset = viewport * 0.5 - target_center * target_scale
		target_offset = _clamped_view_offset(target_offset, target_scale)
	if animate:
		_animate_view_to(target_scale, target_offset, 0.22)
	else:
		view_scale = target_scale
		view_target_scale = target_scale
		view_target_ratio = _view_ratio_for_scale(target_scale)
		view_offset = target_offset
		_clamp_view_to_table()
		_apply_view_transform()


func _base_view_bounds() -> Rect2:
	var board := Rect2(board_origin, source_size * source_scale).grow(VIEW_FIT_PADDING)
	return board.merge(_virtual_table_area())


func _world_content_bounds() -> Rect2:
	var bounds := Rect2(board_origin, source_size * source_scale)
	var has_bounds := bounds.size.x > 0.0 and bounds.size.y > 0.0
	for tile in swap_tiles:
		var tile_bounds := _swap_tile_bounds(tile, tile["node"].position)
		if tile_bounds.size.x <= 0.0 or tile_bounds.size.y <= 0.0:
			continue
		bounds = bounds.merge(tile_bounds) if has_bounds else tile_bounds
		has_bounds = true
	for group in groups:
		var group_bounds := _group_bounds_at(group, group.node.position)
		if group_bounds.size.x <= 0.0 or group_bounds.size.y <= 0.0:
			continue
		bounds = bounds.merge(group_bounds) if has_bounds else group_bounds
		has_bounds = true
	return bounds if has_bounds else _base_view_bounds()


func _focus_hint_pair(pair: Array) -> void:
	var bounds := _group_bounds_at(pair[0], pair[0].node.position)
	bounds = bounds.merge(_group_bounds_at(pair[1], pair[1].node.position))
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	_fit_view_to_world_rect(bounds.grow(VIEW_HINT_PADDING), true, VIEW_HINT_MAX_RATIO, false)


func _organizable_groups(include_clusters: bool) -> Array:
	var result := []
	for group in groups:
		if group == dragging or group.is_animating:
			continue
		if _group_near_home(group):
			continue
		if include_clusters or group.members.size() <= 1:
			result.append(group)
	return result


func _group_near_home(group) -> bool:
	var target: Vector2 = group.anchor_home
	var distance: float = group.node.position.distance_to(target)
	return distance <= maxf(28.0, source_scale * 34.0) and absf(wrapf(group.node.rotation_degrees, -180.0, 180.0)) <= ROTATION_TOLERANCE


func _group_sort_area(group) -> float:
	var bounds := _group_bounds_at(group, group.node.position)
	return bounds.size.x * bounds.size.y


func _organized_group_positions(movable: Array) -> Dictionary:
	var placements := {}
	var remaining := movable.duplicate()
	var areas := _organize_areas()
	for area in areas:
		if remaining.is_empty():
			break
		remaining = _pack_groups_in_area(remaining, area, placements)
	if not remaining.is_empty():
		var fallback := _safe_organize_area()
		_pack_groups_in_area(remaining, fallback, placements)
	return placements


func _organize_areas() -> Array[Rect2]:
	var gap := _organize_gap()
	var table := _safe_organize_area()
	var board := Rect2(board_origin, source_size * source_scale).grow(gap)
	var areas: Array[Rect2] = []
	var bottom := Rect2(
		Vector2(table.position.x, board.end.y + gap),
		Vector2(table.size.x, table.end.y - board.end.y - gap)
	)
	var left := Rect2(
		table.position,
		Vector2(board.position.x - table.position.x - gap, table.size.y)
	)
	var right := Rect2(
		Vector2(board.end.x + gap, table.position.y),
		Vector2(table.end.x - board.end.x - gap, table.size.y)
	)
	var top := Rect2(
		table.position,
		Vector2(table.size.x, board.position.y - table.position.y - gap)
	)
	for area in [bottom, left, right, top]:
		if area.size.x >= 96.0 and area.size.y >= 96.0:
			areas.append(area)
	return areas


func _safe_organize_area() -> Rect2:
	var gap := _organize_gap()
	var organize_scale := maxf(0.001, view_scale)
	var organize_offset := view_offset
	var area := _visible_world_area_for_view(organize_scale, organize_offset).grow(-PIECE_DRAG_PADDING / organize_scale).grow(-gap)
	if area.size.x < 140.0 or area.size.y < 140.0:
		area = _piece_drag_area(false).grow(-gap)
	if drag_blockers.is_empty():
		return area
	var trimmed := area
	var viewport := get_viewport_rect().size
	for blocker in drag_blockers:
		if blocker.size.x <= 0.0 or blocker.size.y <= 0.0:
			continue
		var world_blocker := _screen_rect_to_world_for_view(blocker.grow(8.0), organize_scale, organize_offset)
		if not trimmed.intersects(world_blocker):
			continue
		var touches_left := blocker.position.x <= 6.0
		var touches_top := blocker.position.y <= 6.0
		var touches_right := blocker.end.x >= viewport.x - 6.0
		var touches_bottom := blocker.end.y >= viewport.y - 6.0
		if touches_bottom:
			trimmed.size.y = minf(trimmed.size.y, maxf(0.0, world_blocker.position.y - trimmed.position.y - gap))
		if touches_top:
			var bottom := trimmed.end.y
			trimmed.position.y = minf(bottom, maxf(trimmed.position.y, world_blocker.end.y + gap))
			trimmed.size.y = maxf(0.0, bottom - trimmed.position.y)
		if touches_right:
			trimmed.size.x = minf(trimmed.size.x, maxf(0.0, world_blocker.position.x - trimmed.position.x - gap))
		if touches_left:
			var right := trimmed.end.x
			trimmed.position.x = minf(right, maxf(trimmed.position.x, world_blocker.end.x + gap))
			trimmed.size.x = maxf(0.0, right - trimmed.position.x)
	if trimmed.size.x >= 140.0 and trimmed.size.y >= 140.0:
		return trimmed
	return area


func _organize_gap() -> float:
	return maxf(ORGANIZE_GAP, ORGANIZE_MIN_SCREEN_GAP / maxf(0.001, view_scale))


func _pack_groups_in_area(candidates: Array, area: Rect2, placements: Dictionary) -> Array:
	var remaining := []
	var gap := _organize_gap()
	var cursor := area.position + Vector2(gap, gap)
	var row_height := 0.0
	for group in candidates:
		var bounds := _group_bounds_at(group, group.node.position)
		var size := bounds.size + Vector2(gap, gap)
		if size.x > area.size.x or size.y > area.size.y:
			remaining.append(group)
			continue
		if cursor.x + size.x > area.end.x:
			cursor.x = area.position.x + gap
			cursor.y += row_height + gap
			row_height = 0.0
		if cursor.y + size.y > area.end.y:
			remaining.append(group)
			continue
		var top_left := cursor
		placements[group] = top_left + group.node.position - bounds.position
		cursor.x += size.x
		row_height = maxf(row_height, size.y)
	return remaining


func _animate_group_to(group, target_position: Vector2) -> void:
	group.is_animating = true
	_bring_to_front(group)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(group.node, "position", _clamped_group_position(group, target_position, true), 0.24)
	tween.finished.connect(func(g = group) -> void:
		if is_instance_valid(g.node):
			g.is_animating = false
	)


func _wait_for_group_layout_animation() -> void:
	await get_tree().create_timer(0.26).timeout


func show_hint() -> void:
	if current_mode == "swap":
		status_changed.emit("拖动任意一块图片到另一块上，即可交换它们的位置。")
		return
	var pair := _find_hint_pair()
	if pair.is_empty():
		_clear_hint_highlights()
		status_changed.emit("暂时没有可提示的相邻碎片。")
		return
	_set_hint_highlights(pair)
	_focus_hint_pair(pair)
	_hint_pulse_node(pair[0].node)
	_hint_pulse_node(pair[1].node)
	status_changed.emit("高亮的两块可以拼在一起。")


func set_drag_blockers(blockers: Array[Rect2]) -> void:
	drag_blockers = blockers.duplicate()


func _start_play_session(play_mode: String) -> bool:
	if _mode_key(play_mode) == "swap":
		return _start_swap_session()
	var level := _level_from_mode_pieces(play_mode)
	if level.is_empty():
		return false
	source_scale = level["source_scale"]
	board_origin = level["board_origin"]
	spawn_bounds.clear()
	var sorted_pieces: Array = level["pieces"].duplicate()
	sorted_pieces.sort_custom(func(a, b) -> bool:
		return _points_bounds_area(a["bounds_points"]) > _points_bounds_area(b["bounds_points"])
	)
	for piece in sorted_pieces:
		_create_group(piece)
	fit_view_to_pieces(false)
	return true


func _level_from_mode_pieces(play_mode: String) -> Dictionary:
	var config := _mode_config(active_level_config, play_mode)
	if config.is_empty() or not config.has("pieces") or typeof(config["pieces"]) != TYPE_ARRAY:
		return {}
	var source_pieces: Array = config["pieces"]
	if source_pieces.is_empty():
		return {}
	var layout := _mobile_board_layout()
	var mode_source_scale: float = layout["source_scale"]
	var mode_board_origin: Vector2 = layout["board_origin"]
	var board_size: Vector2 = layout["board_size"]
	var pieces: Array[Dictionary] = []
	for source_piece in source_pieces:
		if typeof(source_piece) != TYPE_DICTIONARY:
			continue
		var piece_data: Dictionary = source_piece
		var source_polygon := _json_points(piece_data.get("points", []))
		if source_polygon.size() < 3:
			continue
		var home_source := _json_point(piece_data.get("home", _polygon_center(source_polygon)))
		var home := mode_board_origin + home_source * mode_source_scale
		var local_polygon := PackedVector2Array()
		var uvs := PackedVector2Array()
		for source_point in source_polygon:
			var display_point := mode_board_origin + source_point * mode_source_scale
			local_polygon.append(display_point - home)
			uvs.append(source_point)
		var visible_source_rect := _json_rect(
			piece_data.get("visible_bounds", []),
			Rect2()
		)
		if visible_source_rect.size.x <= 0.0 or visible_source_rect.size.y <= 0.0:
			visible_source_rect = _visible_source_rect_for_polygon(source_polygon, _source_rect_for_points(source_polygon))
		var visible_source_rects := _json_rects(piece_data.get("visible_bounds_list", []))
		if visible_source_rects.is_empty():
			visible_source_rects = [visible_source_rect]
		var bounds_points_list: Array[PackedVector2Array] = []
		for source_rect in visible_source_rects:
			bounds_points_list.append(_local_rect_points(source_rect, home, mode_source_scale, mode_board_origin))
		var cut_lines: Array[PackedVector2Array] = []
		if piece_data.has("cut_lines") and typeof(piece_data["cut_lines"]) == TYPE_ARRAY:
			for line_data in piece_data["cut_lines"]:
				var source_line := _json_points(line_data)
				if source_line.size() < 2:
					continue
				for local_line in _visible_cut_line_segments(source_line, home, mode_source_scale, mode_board_origin):
					cut_lines.append(local_line)
		pieces.append({
			"id": str(piece_data.get("id", "piece_%d" % pieces.size())),
			"cell": _json_cell(piece_data.get("cell", [0, 0])),
			"home": home,
			"polygon": local_polygon,
			"uv": uvs,
			"neighbors": piece_data.get("neighbors", []),
			"source_rect": _source_rect_for_points(source_polygon),
			"bounds_points": _local_rect_points(visible_source_rect, home, mode_source_scale, mode_board_origin),
			"bounds_points_list": bounds_points_list,
			"cut_lines": cut_lines,
		})
	return {
		"pieces": pieces,
		"board_origin": mode_board_origin,
		"board_size": board_size,
		"source_scale": mode_source_scale,
		"play_area": layout["play_area"],
	}


func _start_swap_session() -> bool:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return false
	var config := _mode_config(active_level_config, "swap")
	var cols: int = max(1, int(config.get("cols", SWAP_COLS)))
	var rows: int = max(1, int(config.get("rows", SWAP_ROWS)))
	var layout := _mobile_board_layout()
	source_scale = layout["source_scale"]
	board_origin = layout["board_origin"]
	var order := _swap_shuffled_order(cols, rows)
	for slot_index in range(order.size()):
		_create_swap_tile(int(order[slot_index]), slot_index, cols, rows)
	fit_view_to_pieces(false)
	status_changed.emit("拖动一块图片到另一块上交换位置。")
	return true


func _create_swap_tile(correct_index: int, slot_index: int, cols: int, rows: int) -> void:
	var tile_source_size := Vector2(source_size.x / float(cols), source_size.y / float(rows))
	var source_col := correct_index % cols
	var source_row := int(correct_index / cols)
	var source_rect := Rect2(Vector2(source_col, source_row) * tile_source_size, tile_source_size)
	var display_size := tile_source_size * source_scale
	var polygon := PackedVector2Array([
		Vector2.ZERO,
		Vector2(display_size.x, 0.0),
		display_size,
		Vector2(0.0, display_size.y),
	])
	var uv := PackedVector2Array([
		source_rect.position,
		Vector2(source_rect.end.x, source_rect.position.y),
		source_rect.end,
		Vector2(source_rect.position.x, source_rect.end.y),
	])
	var node := Node2D.new()
	node.name = "swap_tile_%02d" % correct_index
	node.z_index = swap_tiles.size() * GROUP_Z_STEP
	world_root.add_child(node)
	var piece := {
		"id": node.name,
		"polygon": polygon,
		"uv": uv,
		"cut_lines": [],
	}
	node.add_child(PieceVisualFactoryScript.create_piece_visual(piece, texture))
	var tile := {
		"node": node,
		"correct_index": correct_index,
		"slot_index": slot_index,
		"size": display_size,
		"is_animating": false,
	}
	swap_tiles.append(tile)
	node.position = _swap_slot_position(slot_index, cols, rows)


func _swap_shuffled_order(cols: int, rows: int) -> Array:
	var total := cols * rows
	var base := []
	for index in range(total):
		base.append(index)
	var local_rng := RandomNumberGenerator.new()
	local_rng.randomize()
	for attempt in range(3000):
		var candidate := base.duplicate()
		_shuffle_array(candidate, local_rng)
		if _is_valid_swap_order(candidate, cols, rows):
			return candidate
	var fallback := []
	for index in range(total - 1, -1, -2):
		fallback.append(index)
	for index in range(total - 2, -1, -2):
		fallback.append(index)
	return fallback if _is_valid_swap_order(fallback, cols, rows) else base


func _shuffle_array(items: Array, local_rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other := local_rng.randi_range(0, index)
		var value = items[index]
		items[index] = items[other]
		items[other] = value


func _is_valid_swap_order(order: Array, cols: int, rows: int) -> bool:
	for slot in range(order.size()):
		if int(order[slot]) == slot:
			return false
		var col := slot % cols
		var row := int(slot / cols)
		var current := int(order[slot])
		if col < cols - 1:
			var right := int(order[slot + 1])
			if right == current + 1 and int(current / cols) == int(right / cols):
				return false
		if row < rows - 1:
			var below := int(order[slot + cols])
			if below == current + cols:
				return false
	return true


func _swap_slot_position(slot_index: int, cols := SWAP_COLS, rows := SWAP_ROWS) -> Vector2:
	var tile_size := Vector2(source_size.x / float(cols), source_size.y / float(rows)) * source_scale
	var col := slot_index % cols
	var row := int(slot_index / cols)
	return board_origin + Vector2(col * tile_size.x, row * tile_size.y)


func _mobile_board_layout() -> Dictionary:
	return BoardLayoutScript.mobile_board_layout(
		source_size,
		get_viewport_rect().size,
		active_level_config,
		_current_mode_piece_count(),
		hud_icon_size
	)


func _current_mode_piece_count() -> int:
	if current_mode == "swap":
		var swap_config := _mode_config(active_level_config, current_mode)
		return int(swap_config.get("cols", SWAP_COLS)) * int(swap_config.get("rows", SWAP_ROWS))
	var config := _mode_config(active_level_config, current_mode)
	if config.has("pieces") and typeof(config["pieces"]) == TYPE_ARRAY:
		return (config["pieces"] as Array).size()
	return 0


func _mode_key(play_mode: String) -> String:
	return "knob" if play_mode == "classic" else play_mode


func _mode_config(level_config: Dictionary, play_mode: String) -> Dictionary:
	var mode := _mode_key(play_mode)
	if not level_config.has("modes") or typeof(level_config["modes"]) != TYPE_DICTIONARY:
		return {}
	var modes: Dictionary = level_config["modes"]
	if not modes.has(mode) or typeof(modes[mode]) != TYPE_DICTIONARY:
		return {}
	return modes[mode]


func _json_points(value) -> PackedVector2Array:
	var points := PackedVector2Array()
	if typeof(value) != TYPE_ARRAY:
		return points
	for item in value:
		points.append(_json_point(item))
	return points


func _json_point(value) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO


func _json_cell(value) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _json_rect(value, fallback: Rect2) -> Rect2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 4:
		return Rect2(
			Vector2(float(value[0]), float(value[1])),
			Vector2(maxf(1.0, float(value[2])), maxf(1.0, float(value[3])))
		)
	return fallback


func _json_rects(value) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if typeof(value) != TYPE_ARRAY:
		return rects
	for item in value:
		var rect := _json_rect(item, Rect2())
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			rects.append(rect)
	return rects


func _local_rect_points(source_rect: Rect2, home: Vector2, scale: float, origin: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var source_points := [
		source_rect.position,
		Vector2(source_rect.end.x, source_rect.position.y),
		source_rect.end,
		Vector2(source_rect.position.x, source_rect.end.y),
	]
	for source_point in source_points:
		points.append(origin + source_point * scale - home)
	return points


func _polygon_center(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / max(1, points.size())


func _source_rect_for_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


func _points_bounds_area(points: PackedVector2Array) -> float:
	var bounds := _source_rect_for_points(points)
	return bounds.size.x * bounds.size.y


func _visible_source_rect_for_polygon(points: PackedVector2Array, fallback: Rect2) -> Rect2:
	var bounds := _source_rect_for_points(points)
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	var found := false
	for y in range(floori(bounds.position.y), ceili(bounds.end.y) + 1):
		for x in range(floori(bounds.position.x), ceili(bounds.end.x) + 1):
			var point := Vector2(x, y)
			if not Geometry2D.is_point_in_polygon(point, points):
				continue
			if not _source_point_has_alpha(point, 0):
				continue
			min_point = min_point.min(point)
			max_point = max_point.max(point)
			found = true
	if not found:
		return fallback
	return Rect2(min_point, max_point - min_point).grow(2.0)


func _add_level_background(level_config: Dictionary) -> void:
	var viewport_size := get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = _level_background_color(level_config)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.position = Vector2.ZERO
	bg.size = viewport_size
	bg.z_index = -101
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if not level_config.has("background") or typeof(level_config["background"]) != TYPE_DICTIONARY:
		return
	var bg_config: Dictionary = level_config["background"]
	if str(bg_config.get("type", "color")) != "image":
		return
	var bg_texture: Texture2D = load(str(bg_config.get("path", "")))
	if bg_texture == null:
		return
	var bg_image := TextureRect.new()
	bg_image.texture = bg_texture
	bg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_image.position = Vector2.ZERO
	bg_image.size = viewport_size
	bg_image.z_index = -100
	bg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_image)


func _level_background_color(level_config: Dictionary) -> Color:
	if level_config.has("background") and typeof(level_config["background"]) == TYPE_DICTIONARY:
		var bg: Dictionary = level_config["background"]
		if str(bg.get("type", "color")) == "color":
			return Color(str(bg.get("color", "#ead8bd")))
	return Color("#ead8bd")


func _create_group(piece: Dictionary) -> void:
	var group_node := Node2D.new()
	group_node.name = piece["id"]
	group_node.rotation_degrees = [0, 90, 180, 270][int(rng.randi_range(0, 3))] if randomize_piece_rotation else 0.0
	group_node.z_index = groups.size() * GROUP_Z_STEP
	world_root.add_child(group_node)
	var visual := PieceVisualFactoryScript.create_piece_visual(piece, texture)
	group_node.add_child(visual)
	piece["visual"] = visual
	var group = PieceGroupScript.new(group_node, piece)
	groups.append(group)
	_move_group_to(group, _scatter_position_for_group(group), false)
	spawn_bounds.append(_group_bounds_at(group, group.node.position).grow(PIECE_SPAWN_SEPARATION))


func _scatter_position_for_group(group) -> Vector2:
	var area := _piece_spawn_area()
	var clamp_area := _piece_drag_area(false)
	var best_position := area.get_center()
	var best_score := INF
	var attempts := 160
	for attempt in range(attempts):
		var candidate := _spawn_candidate(area, attempt, attempts)
		var clamped := _clamped_group_position(group, candidate, false)
		var bounds := _group_bounds_at(group, clamped).grow(PIECE_SPAWN_SEPARATION)
		var score := _spawn_overlap_score(bounds, clamp_area)
		if score <= 0.001:
			return clamped
		if score < best_score:
			best_score = score
			best_position = clamped
	return best_position


func _spawn_candidate(area: Rect2, attempt: int, attempts: int) -> Vector2:
	if attempt < 12:
		var t := float(attempt) / 12.0
		var angle := t * TAU
		var radius := minf(area.size.x, area.size.y) * 0.36
		return area.get_center() + Vector2(cos(angle), sin(angle)) * radius
	if attempt < 28:
		var side := (attempt - 12) % 4
		var offset := float((attempt - 12) / 4 + 1) / 5.0
		if side == 0:
			return Vector2(lerpf(area.position.x, area.end.x, offset), area.position.y)
		if side == 1:
			return Vector2(area.end.x, lerpf(area.position.y, area.end.y, offset))
		if side == 2:
			return Vector2(lerpf(area.end.x, area.position.x, offset), area.end.y)
		return Vector2(area.position.x, lerpf(area.end.y, area.position.y, offset))
	return Vector2(
		rng.randf_range(area.position.x, area.end.x),
		rng.randf_range(area.position.y, area.end.y)
	)


func _spawn_overlap_score(bounds: Rect2, area: Rect2) -> float:
	var score := 0.0
	for existing in spawn_bounds:
		score += _rect_overlap_area(bounds, existing) * 18.0
	score += bounds.get_center().distance_squared_to(area.get_center()) * 0.002
	return score


func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var x0 := maxf(a.position.x, b.position.x)
	var y0 := maxf(a.position.y, b.position.y)
	var x1 := minf(a.end.x, b.end.x)
	var y1 := minf(a.end.y, b.end.y)
	return maxf(0.0, x1 - x0) * maxf(0.0, y1 - y0)


func _move_group_to(group, target_position: Vector2, use_visible_area := true) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	group.node.position = _clamped_group_position(group, target_position, use_visible_area)


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
	if drag_blockers.is_empty():
		return target_position
	var clamped := target_position
	for iteration in range(3):
		var moved := false
		for blocker in drag_blockers:
			var piece_rect := _world_rect_to_screen(_group_bounds_at(group, clamped))
			if not piece_rect.intersects(blocker):
				continue
			var push := _screen_push_out(piece_rect, blocker)
			if push == Vector2.ZERO:
				continue
			clamped += push / maxf(0.001, view_scale)
			clamped = _clamp_position_to_area(group, clamped, area)
			moved = true
		if not moved:
			break
	return clamped


func _screen_push_out(subject: Rect2, obstacle: Rect2) -> Vector2:
	var viewport := get_viewport_rect().size
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
	var top_left := _world_to_screen(rect.position)
	var bottom_right := _world_to_screen(rect.end)
	return Rect2(top_left.min(bottom_right), (bottom_right - top_left).abs())


func _screen_to_world_for_view(screen_pos: Vector2, scale: float, offset: Vector2) -> Vector2:
	return (screen_pos - offset) / maxf(0.001, scale)


func _screen_rect_to_world_for_view(rect: Rect2, scale: float, offset: Vector2) -> Rect2:
	var top_left := _screen_to_world_for_view(rect.position, scale, offset)
	var bottom_right := _screen_to_world_for_view(rect.end, scale, offset)
	return Rect2(top_left.min(bottom_right), (bottom_right - top_left).abs())


func _piece_drag_area(use_visible_area := false) -> Rect2:
	var table := _virtual_table_area().grow(-PIECE_DRAG_PADDING)
	if not use_visible_area:
		return table
	var visible := _visible_world_area().grow(-PIECE_DRAG_PADDING / maxf(0.001, view_scale))
	if visible.size.x >= 48.0 and visible.size.y >= 48.0:
		return visible
	return table


func _visible_world_area() -> Rect2:
	return _visible_world_area_for_view(view_scale, view_offset)


func _visible_world_area_for_view(scale: float, offset: Vector2) -> Rect2:
	var viewport := get_viewport_rect().size
	var top_left := _screen_to_world_for_view(Vector2.ZERO, scale, offset)
	var bottom_right := _screen_to_world_for_view(viewport, scale, offset)
	var position := top_left.min(bottom_right)
	var size := (bottom_right - top_left).abs()
	return Rect2(position, size)


func _virtual_table_area() -> Rect2:
	var layout := _mobile_board_layout()
	var play_area: Rect2 = layout["play_area"]
	var piece_count: int = max(1, _current_mode_piece_count())
	var extra := clampf(sqrt(float(piece_count)) * 52.0, TABLE_EXTRA_MIN, TABLE_EXTRA_MAX)
	return play_area.grow_individual(extra, extra * 0.55, extra, extra * 1.15)


func _piece_spawn_area() -> Rect2:
	var drag_area := _piece_drag_area()
	var padding := maxf(PIECE_SPAWN_EDGE_PADDING, minf(drag_area.size.x, drag_area.size.y) * 0.05)
	var spawn_area := drag_area.grow(-padding)
	if spawn_area.size.x < 140.0 or spawn_area.size.y < 140.0:
		return drag_area
	return spawn_area


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


func _begin_drag(screen_pos: Vector2) -> void:
	if current_mode == "swap":
		_begin_swap_drag(screen_pos)
		return
	var world_pos := _screen_to_world(screen_pos)
	var group = _group_at_world(world_pos)
	if group == null:
		_begin_pan(screen_pos, active_touch_index)
		return
	if group.is_animating:
		return
	_clear_hint_highlights()
	_select_group(group)
	dragging = group
	drag_offset = group.node.position - world_pos
	_bring_to_front(group)
	PieceVisualFactoryScript.set_group_lifted(group, true, self)


func _end_drag() -> void:
	if current_mode == "swap":
		_end_swap_drag()
		return
	if dragging == null:
		return
	var released_group = dragging
	_try_snap_chain(dragging)
	_check_complete()
	PieceVisualFactoryScript.set_group_lifted(released_group, false, self)
	dragging = null


func _group_at_world(world_pos: Vector2):
	for i in range(groups.size() - 1, -1, -1):
		var group = groups[i]
		var local_to_group: Vector2 = group.node.transform.affine_inverse() * world_pos
		for member in group.members:
			var local_to_piece: Vector2 = local_to_group - member["visual"].position
			if Geometry2D.is_point_in_polygon(local_to_piece, member["polygon"]) and _local_point_has_alpha(member, local_to_piece):
				return group
	return null


func _local_point_has_alpha(member: Dictionary, local_point: Vector2) -> bool:
	var source_point: Vector2 = (local_point + member["home"] - board_origin) / source_scale
	return _source_point_has_alpha(source_point, HIT_ALPHA_RADIUS)


func _source_point_has_alpha(source_point: Vector2, radius := HIT_ALPHA_RADIUS) -> bool:
	var center := Vector2i(roundi(source_point.x), roundi(source_point.y))
	var image_size := source_image.get_size()
	for y in range(center.y - radius, center.y + radius + 1):
		if y < 0 or y >= image_size.y:
			continue
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= image_size.x:
				continue
			if source_image.get_pixel(x, y).a > 0.08:
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


func _begin_swap_drag(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var tile = _swap_tile_at_world(world_pos)
	if tile == null:
		_begin_pan(screen_pos, active_touch_index)
		return
	if bool(tile.get("is_animating", false)):
		return
	_clear_hint_highlights()
	swap_dragging = tile
	swap_drag_start_slot = int(tile["slot_index"])
	swap_drag_offset = tile["node"].position - world_pos
	_bring_swap_tile_to_front(tile)
	_set_swap_tile_lifted(tile, true)


func _end_swap_drag() -> void:
	if swap_dragging == null:
		return
	var released = swap_dragging
	var center: Vector2 = released["node"].position + released["size"] * 0.5
	var target = _swap_tile_at_world(center, released)
	if target == null:
		_animate_swap_tile_to(released, _swap_slot_position(swap_drag_start_slot, _swap_cols(), _swap_rows()))
	else:
		var target_slot := int(target["slot_index"])
		released["slot_index"] = target_slot
		target["slot_index"] = swap_drag_start_slot
		_animate_swap_tile_to(released, _swap_slot_position(target_slot, _swap_cols(), _swap_rows()))
		_animate_swap_tile_to(target, _swap_slot_position(swap_drag_start_slot, _swap_cols(), _swap_rows()))
		status_changed.emit("已交换两块图片。")
	_set_swap_tile_lifted(released, false)
	swap_dragging = null
	swap_drag_start_slot = -1


func _move_swap_tile_to(tile, target_position: Vector2) -> void:
	if tile == null or not is_instance_valid(tile["node"]):
		return
	var area := _piece_drag_area(true)
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


func _swap_tile_at_world(world_pos: Vector2, exclude = null):
	for index in range(swap_tiles.size() - 1, -1, -1):
		var tile = swap_tiles[index]
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
	swap_tiles.erase(tile)
	swap_tiles.append(tile)
	for index in swap_tiles.size():
		swap_tiles[index]["node"].z_index = index * GROUP_Z_STEP


func _set_swap_tile_lifted(tile, lifted: bool) -> void:
	if tile == null:
		return
	var node: Node2D = tile["node"]
	if not is_instance_valid(node):
		return
	var target_scale := Vector2(1.025, 1.025) if lifted else Vector2.ONE
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "scale", target_scale, 0.12)


func _animate_swap_tile_to(tile, target_position: Vector2) -> void:
	if tile == null or not is_instance_valid(tile["node"]):
		return
	tile["is_animating"] = true
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(tile["node"], "position", target_position, SWAP_ANIMATION_TIME)
	tween.finished.connect(func(t = tile) -> void:
		if is_instance_valid(t["node"]):
			t["is_animating"] = false
		_check_swap_complete()
	)


func _check_swap_complete() -> void:
	if completion_emitted or swap_tiles.is_empty():
		return
	for tile in swap_tiles:
		if int(tile["slot_index"]) != int(tile["correct_index"]):
			return
	completion_emitted = true
	completed.emit()


func _swap_cols() -> int:
	return max(1, int(_mode_config(active_level_config, "swap").get("cols", SWAP_COLS)))


func _swap_rows() -> int:
	return max(1, int(_mode_config(active_level_config, "swap").get("rows", SWAP_ROWS)))


func _select_group(group) -> void:
	selected_group = group


func _rotate_group(group) -> void:
	if not randomize_piece_rotation or group == null or group.is_animating:
		return
	group.is_animating = true
	var target: float = snappedf(group.node.rotation_degrees + 90.0, 90.0)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(group.node, "rotation_degrees", target, 0.16)
	tween.finished.connect(func() -> void:
		if not groups.has(group) or not is_instance_valid(group.node):
			return
		group.is_animating = false
		_try_snap_chain(group)
		_check_complete()
	)


func _bring_to_front(group) -> void:
	groups.erase(group)
	groups.append(group)
	_refresh_group_z_indices()


func _refresh_group_z_indices() -> void:
	for i in groups.size():
		groups[i].node.z_index = i * GROUP_Z_STEP


func _try_snap_chain(active) -> void:
	var progressed := true
	while progressed:
		progressed = false
		var other = SnapSolverScript.find_match(active, groups, _snap_tolerance(), ROTATION_TOLERANCE)
		if other != null:
			_clear_hint_highlights()
			active.absorb(other)
			groups.erase(other)
			_refresh_group_z_indices()
			_move_group_to(active, active.node.position, false)
			if selected_group == other:
				selected_group = active
			_pulse_node(active.node)
			progressed = true


func _snap_tolerance() -> float:
	return clampf(SNAP_TOLERANCE * maxf(0.75, source_scale), 16.0, 24.0)


func _check_complete() -> void:
	if groups.size() == 1:
		if not completion_emitted:
			completion_emitted = true
			completed.emit()


func _set_hint_highlights(pair: Array) -> void:
	_clear_hint_highlights()
	hint_highlight_token += 1
	var token := hint_highlight_token
	var first = pair[0]
	var second = pair[1]
	_bring_to_front(first)
	_bring_to_front(second)
	hint_highlighted_groups.append(first)
	hint_highlighted_groups.append(second)
	_add_hint_outline_to_group(first)
	_add_hint_outline_to_group(second)
	_auto_clear_hint_highlights(token)


func _add_hint_outline_to_group(group) -> void:
	for member in group.members:
		var visual: Node2D = member["visual"]
		var polygon: PackedVector2Array = member["polygon"]
		_add_hint_outline_line(visual, polygon, 9.0, HINT_GLOW_COLOR, 30)
		_add_hint_outline_line(visual, polygon, 4.0, HINT_OUTLINE_COLOR, 31)


func _add_hint_outline_line(visual: Node2D, polygon: PackedVector2Array, width: float, color: Color, z_index: int) -> void:
	var line := Line2D.new()
	line.name = "hint_highlight"
	line.width = width
	line.default_color = color
	line.closed = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.points = polygon
	line.z_index = z_index
	visual.add_child(line)
	hint_highlighted_lines.append(line)
	var tween := create_tween()
	tween.set_loops(3)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(line, "modulate:a", 0.38, 0.28)
	tween.tween_property(line, "modulate:a", 1.0, 0.28)


func _auto_clear_hint_highlights(token: int) -> void:
	await get_tree().create_timer(1.85).timeout
	if token == hint_highlight_token:
		_clear_hint_highlights()


func _clear_hint_highlights() -> void:
	hint_highlight_token += 1
	for line in hint_highlighted_lines:
		if is_instance_valid(line):
			line.queue_free()
	hint_highlighted_groups.clear()
	hint_highlighted_lines.clear()


func _find_hint_pair() -> Array:
	for a in groups:
		for b in groups:
			if a == b:
				continue
			if not _groups_are_neighbors(a, b):
				continue
			var pair := _neighbor_member_pair(a, b)
			if not pair.is_empty():
				return [a, b, pair[0], pair[1]]
	return []


func _groups_are_neighbors(a, b) -> bool:
	return not _neighbor_member_pair(a, b).is_empty()


func _neighbor_member_pair(a, b) -> Array:
	for am in a.members:
		for bm in b.members:
			if am["neighbors"].has(bm["id"]) or bm["neighbors"].has(am["id"]):
				return [am, bm]
	return []


func _pulse_node(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "scale", Vector2(1.05, 1.05), 0.08)
	tween.tween_property(node, "scale", Vector2.ONE, 0.12)


func _hint_pulse_node(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	for i in 2:
		tween.tween_property(node, "scale", Vector2(1.08, 1.08), 0.24)
		tween.tween_property(node, "scale", Vector2.ONE, 0.34)
