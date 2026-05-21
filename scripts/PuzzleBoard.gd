extends Node2D
class_name PuzzleBoard

signal status_changed(text: String)
signal completed

const SNAP_TOLERANCE := 22.0
const ROTATION_TOLERANCE := 3.0
const HIT_ALPHA_RADIUS := 2
const PIECE_DRAG_PADDING := 8.0
const PIECE_SPAWN_EDGE_PADDING := 22.0
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
var groups: Array = []
var spawn_bounds: Array[Rect2] = []
var dragging = null
var selected_group = null
var hint_highlighted_groups: Array = []
var hint_highlighted_lines: Array[Line2D] = []
var active_touch_index := -1
var drag_offset := Vector2.ZERO
var preview_sprite: Sprite2D
var hud_icon_size := 56.0
var completion_emitted := false


func _ready() -> void:
	rng.seed = 7


func start(level_config: Dictionary, play_mode: String, source_texture: Texture2D, image: Image, image_size: Vector2, icon_size: float) -> bool:
	clear()
	active_level_config = level_config
	current_mode = _mode_key(play_mode)
	texture = source_texture
	source_image = image
	source_size = image_size
	hud_icon_size = icon_size
	completion_emitted = false
	_add_level_background(active_level_config)
	return _start_play_session(current_mode)


func clear() -> void:
	for child in get_children():
		child.queue_free()
	groups.clear()
	spawn_bounds.clear()
	dragging = null
	selected_group = null
	hint_highlighted_groups.clear()
	hint_highlighted_lines.clear()
	preview_sprite = null
	active_touch_index = -1
	completion_emitted = false


func handle_input(event: InputEvent, modal_open: bool) -> bool:
	if modal_open:
		return false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			var double_group = _group_at(mouse_event.position)
			if double_group != null:
				_select_group(double_group)
				_rotate_group(double_group)
			return true
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_drag(mouse_event.position)
			else:
				_end_drag()
			return true
	elif event is InputEventMouseMotion and dragging != null:
		var motion := event as InputEventMouseMotion
		_move_group_to(dragging, motion.position + drag_offset)
		return true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.double_tap:
				var double_group = _group_at(touch.position)
				if double_group != null:
					_select_group(double_group)
					_rotate_group(double_group)
			else:
				active_touch_index = touch.index
				_begin_drag(touch.position)
			return true
		if touch.index == active_touch_index:
			_end_drag()
			active_touch_index = -1
			return true
	elif event is InputEventScreenDrag and dragging != null:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == active_touch_index:
			_move_group_to(dragging, drag_event.position + drag_offset)
			return true
	return false


func align_all() -> void:
	for group in groups:
		if group.is_animating:
			continue
		group.is_animating = true
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(group.node, "rotation_degrees", 0.0, 0.16)
		tween.finished.connect(func(g = group) -> void:
			if is_instance_valid(g.node):
				g.is_animating = false
		)
	status_changed.emit("所有碎片已转正。")


func show_hint() -> void:
	var pair := _find_hint_pair()
	if pair.is_empty():
		_clear_hint_highlights()
		status_changed.emit("暂时没有可提示的相邻碎片。")
		return
	_set_hint_highlights(pair)
	_hint_pulse_node(pair[0].node)
	_hint_pulse_node(pair[1].node)
	status_changed.emit("高亮的两块可以拼在一起。")


func toggle_preview() -> void:
	if not is_instance_valid(preview_sprite):
		return
	var show := not preview_sprite.visible
	preview_sprite.visible = true
	var start_alpha := 0.0 if show else preview_sprite.modulate.a
	var target_alpha := 0.82 if show else 0.0
	preview_sprite.modulate.a = start_alpha
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(preview_sprite, "modulate:a", target_alpha, 0.18)
	if not show:
		tween.finished.connect(func() -> void:
			if is_instance_valid(preview_sprite):
				preview_sprite.visible = false
		)


func _start_play_session(play_mode: String) -> bool:
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
	_add_preview_sprite(level["play_area"])
	return true


func _add_preview_sprite(play_area: Rect2) -> void:
	preview_sprite = Sprite2D.new()
	preview_sprite.texture = texture
	var preview_max := Vector2(play_area.size.x * 0.24, play_area.size.y * 0.24)
	var preview_scale := minf(preview_max.x / source_size.x, preview_max.y / source_size.y)
	preview_sprite.scale = Vector2.ONE * preview_scale
	preview_sprite.position = play_area.end - source_size * preview_scale * 0.5 - Vector2(16, 16)
	preview_sprite.modulate = Color(1, 1, 1, 0.82)
	preview_sprite.visible = false
	add_child(preview_sprite)


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


func _mobile_board_layout() -> Dictionary:
	return BoardLayoutScript.mobile_board_layout(
		source_size,
		get_viewport_rect().size,
		active_level_config,
		_current_mode_piece_count(),
		hud_icon_size
	)


func _current_mode_piece_count() -> int:
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
	var bg := ColorRect.new()
	bg.color = _level_background_color(level_config)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	group_node.rotation_degrees = [0, 90, 180, 270][int(rng.randi_range(0, 3))]
	group_node.z_index = groups.size()
	add_child(group_node)
	var visual := PieceVisualFactoryScript.create_piece_visual(piece, texture)
	group_node.add_child(visual)
	piece["visual"] = visual
	var group = PieceGroupScript.new(group_node, piece)
	groups.append(group)
	_move_group_to(group, _scatter_position_for_group(group))
	spawn_bounds.append(_group_bounds_at(group, group.node.position).grow(8.0))


func _scatter_position_for_group(group) -> Vector2:
	var area := _piece_spawn_area()
	var clamp_area := _piece_drag_area()
	var best_position := area.get_center()
	var best_score := INF
	var attempts := 96
	for attempt in range(attempts):
		var candidate := _spawn_candidate(area, attempt, attempts)
		var clamped := _clamped_group_position(group, candidate)
		var bounds := _group_bounds_at(group, clamped).grow(8.0)
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


func _move_group_to(group, target_position: Vector2) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	group.node.position = _clamped_group_position(group, target_position)


func _clamped_group_position(group, target_position: Vector2) -> Vector2:
	var bounds := _group_bounds_at(group, target_position)
	var area := _piece_drag_area()
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


func _piece_drag_area() -> Rect2:
	var play_area: Rect2 = _mobile_board_layout()["play_area"]
	return play_area.grow(-PIECE_DRAG_PADDING)


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
	var group = _group_at(screen_pos)
	if group == null:
		return
	if group.is_animating:
		return
	_clear_hint_highlights()
	_select_group(group)
	dragging = group
	drag_offset = group.node.position - screen_pos
	_bring_to_front(group)
	PieceVisualFactoryScript.set_group_lifted(group, true, self)


func _end_drag() -> void:
	if dragging == null:
		return
	var released_group = dragging
	_try_snap_chain(dragging)
	_check_complete()
	PieceVisualFactoryScript.set_group_lifted(released_group, false, self)
	dragging = null


func _group_at(screen_pos: Vector2):
	for i in range(groups.size() - 1, -1, -1):
		var group = groups[i]
		var local_to_group: Vector2 = group.node.to_local(screen_pos)
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


func _select_group(group) -> void:
	selected_group = group
	status_changed.emit("已选中碎片。")


func _rotate_group(group) -> void:
	if group == null or group.is_animating:
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
	for i in groups.size():
		groups[i].node.z_index = i


func _try_snap_chain(active) -> void:
	var progressed := true
	while progressed:
		progressed = false
		var other = SnapSolverScript.find_match(active, groups, _snap_tolerance(), ROTATION_TOLERANCE)
		if other != null:
			_clear_hint_highlights()
			active.absorb(other)
			groups.erase(other)
			_move_group_to(active, active.node.position)
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
	else:
		status_changed.emit("剩余碎片组：%d" % groups.size())


func _set_hint_highlights(pair: Array) -> void:
	_clear_hint_highlights()
	hint_highlighted_groups.append(pair[0])
	hint_highlighted_groups.append(pair[1])
	_add_hint_edge_highlights(pair[2], pair[3])


func _add_hint_edge_highlights(a_member: Dictionary, b_member: Dictionary) -> void:
	var a_segments := _shared_edge_segments(a_member, b_member)
	var b_segments := _shared_edge_segments(b_member, a_member)
	if a_segments.is_empty() or b_segments.is_empty():
		a_segments = _nearest_edge_segments(a_member, b_member)
		b_segments = _nearest_edge_segments(b_member, a_member)
	_add_hint_lines_to_member(a_member, a_segments)
	_add_hint_lines_to_member(b_member, b_segments)


func _shared_edge_segments(member: Dictionary, other_member: Dictionary) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var polygon: PackedVector2Array = member["polygon"]
	var other_solved := _member_solved_polygon(other_member)
	var tolerance := maxf(5.0, source_scale * 8.0)
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		var solved_a: Vector2 = member["home"] + a
		var solved_b: Vector2 = member["home"] + b
		var midpoint := (solved_a + solved_b) * 0.5
		var distance := _point_to_polygon_boundary_distance(midpoint, other_solved)
		if distance <= tolerance:
			segments.append(PackedVector2Array([a, b]))
	return segments


func _nearest_edge_segments(member: Dictionary, other_member: Dictionary) -> Array[PackedVector2Array]:
	var polygon: PackedVector2Array = member["polygon"]
	var other_solved := _member_solved_polygon(other_member)
	var best_distance := INF
	var best_segment := PackedVector2Array()
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		var midpoint: Vector2 = member["home"] + (a + b) * 0.5
		var distance := _point_to_polygon_boundary_distance(midpoint, other_solved)
		if distance < best_distance:
			best_distance = distance
			best_segment = PackedVector2Array([a, b])
	return [best_segment] if best_segment.size() >= 2 else []


func _add_hint_lines_to_member(member: Dictionary, segments: Array[PackedVector2Array]) -> void:
	var visual: Node2D = member["visual"]
	for segment in segments:
		if segment.size() < 2:
			continue
		var line := Line2D.new()
		line.name = "hint_highlight"
		line.width = 5.0
		line.default_color = Color(1.0, 0.82, 0.30, 0.94)
		line.closed = false
		line.points = segment
		line.z_index = 20
		visual.add_child(line)
		hint_highlighted_lines.append(line)


func _member_solved_polygon(member: Dictionary) -> PackedVector2Array:
	var solved := PackedVector2Array()
	var polygon: PackedVector2Array = member["polygon"]
	for point in polygon:
		solved.append(member["home"] + point)
	return solved


func _point_to_polygon_boundary_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	var best := INF
	for index in range(polygon.size()):
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		best = minf(best, _point_to_segment_distance(point, a, b))
	return best


func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _clear_hint_highlights() -> void:
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
