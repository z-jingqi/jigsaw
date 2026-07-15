extends RefCounted
class_name BoardSessionBuilder

const SWAP_FALLBACK_COLS := 5
const SWAP_FALLBACK_ROWS := 7

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func _start_play_session(play_mode: String) -> bool:
	if host._mode_key(play_mode) == "swap":
		return _start_swap_session()
	var level: Dictionary = _level_from_mode_pieces(play_mode)
	if level.is_empty():
		return false
	host.source_scale = level["source_scale"]
	host.board_origin = level["board_origin"]
	host._add_board_outline_shadow()
	var sorted_pieces: Array = level["pieces"].duplicate()
	sorted_pieces.sort_custom(func(a, b) -> bool:
		return host._points_bounds_area(a["bounds_points"]) > host._points_bounds_area(b["bounds_points"])
	)
	var seed_ids: Array[String] = _seed_piece_ids(sorted_pieces, host._mode_config(host.active_level_config, play_mode))
	for piece in sorted_pieces:
		var is_seed: bool = seed_ids.has(str(piece.get("id", "")))
		_create_group(piece, is_seed)
	host.tray_scroll_offset = 0.0
	host._layout_tray(true)
	host.fit_view_to_pieces(false)
	for group in host.locked_groups:
		host.PieceVisualFactoryScript.add_seam_outline(group, host._seam_line_width())
	return true


func _level_from_mode_pieces(play_mode: String) -> Dictionary:
	var config: Dictionary = host._mode_config(host.active_level_config, play_mode)
	if config.is_empty():
		return {}
	var source_pieces: Array = []
	if config.has("pieces") and typeof(config["pieces"]) == TYPE_ARRAY:
		source_pieces = config["pieces"]
	if source_pieces.is_empty() and host._mode_key(play_mode) == "knob":
		source_pieces = _generated_knob_source_pieces(config)
	if source_pieces.is_empty():
		return {}
	var layout: Dictionary = _mobile_board_layout()
	var mode_source_scale: float = layout["source_scale"]
	var mode_board_origin: Vector2 = layout["board_origin"]
	var board_size: Vector2 = layout["board_size"]
	var pieces: Array[Dictionary] = []
	for source_piece in source_pieces:
		if typeof(source_piece) != TYPE_DICTIONARY:
			continue
		var piece_data: Dictionary = source_piece
		var source_polygon: PackedVector2Array = host._json_points(piece_data.get("points", []))
		if source_polygon.size() < 3:
			continue
		var home_source: Vector2 = host._json_point(piece_data.get("home", host._polygon_center(source_polygon)))
		var home: Vector2 = mode_board_origin + home_source * mode_source_scale
		var local_polygon := PackedVector2Array()
		var uvs := PackedVector2Array()
		for source_point in source_polygon:
			var display_point: Vector2 = mode_board_origin + source_point * mode_source_scale
			local_polygon.append(display_point - home)
			uvs.append(source_point)
		var visible_source_rect: Rect2 = host._json_rect(
			piece_data.get("visible_bounds", []),
			Rect2()
		)
		if visible_source_rect.size.x <= 0.0 or visible_source_rect.size.y <= 0.0:
			visible_source_rect = host._visible_source_rect_for_polygon(source_polygon, host._source_rect_for_points(source_polygon))
		var visible_source_rects: Array[Rect2] = host._json_rects(piece_data.get("visible_bounds_list", []))
		if visible_source_rects.is_empty():
			visible_source_rects = [visible_source_rect]
		var bounds_points_list: Array[PackedVector2Array] = []
		for source_rect in visible_source_rects:
			bounds_points_list.append(host._local_rect_points(source_rect, home, mode_source_scale, mode_board_origin))
		var cut_lines: Array[PackedVector2Array] = []
		if piece_data.has("cut_lines") and typeof(piece_data["cut_lines"]) == TYPE_ARRAY:
			for line_data in piece_data["cut_lines"]:
				var source_line: PackedVector2Array = host._json_points(line_data)
				if source_line.size() < 2:
					continue
				for local_line in host._visible_cut_line_segments(source_line, home, mode_source_scale, mode_board_origin):
					cut_lines.append(local_line)
		pieces.append({
			"id": str(piece_data.get("id", "piece_%d" % pieces.size())),
			"cell": host._json_cell(piece_data.get("cell", [0, 0])),
			"home": home,
			"polygon": local_polygon,
			"uv": uvs,
			"neighbors": piece_data.get("neighbors", []),
			"source_rect": host._source_rect_for_points(source_polygon),
			"bounds_points": host._local_rect_points(visible_source_rect, home, mode_source_scale, mode_board_origin),
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


func _generated_knob_source_pieces(config: Dictionary) -> Array:
	if host.source_size.x <= 0.0 or host.source_size.y <= 0.0:
		return []
	var cols: int = maxi(1, int(config.get("cols", 6)))
	var rows: int = maxi(1, int(config.get("rows", 8)))
	var cell_size := Vector2(host.source_size.x / float(cols), host.source_size.y / float(rows))
	var knob_amount := minf(cell_size.x, cell_size.y) * float(config.get("knob_size", 0.24))
	var pieces := []
	for row in range(rows):
		for col in range(cols):
			var x0 := float(col) * cell_size.x
			var y0 := float(row) * cell_size.y
			var x1 := float(col + 1) * cell_size.x
			var y1 := float(row + 1) * cell_size.y
			var points: Array = []
			_append_knob_edge(points, Vector2(x0, y0), Vector2(x1, y0), Vector2(0, -1), 0 if row == 0 else -_knob_horizontal_sign(col, row), knob_amount)
			_append_knob_edge(points, Vector2(x1, y0), Vector2(x1, y1), Vector2(1, 0), 0 if col == cols - 1 else _knob_vertical_sign(col + 1, row), knob_amount)
			_append_knob_edge(points, Vector2(x1, y1), Vector2(x0, y1), Vector2(0, 1), 0 if row == rows - 1 else _knob_horizontal_sign(col, row + 1), knob_amount)
			_append_knob_edge(points, Vector2(x0, y1), Vector2(x0, y0), Vector2(-1, 0), 0 if col == 0 else -_knob_vertical_sign(col, row), knob_amount)
			var neighbors := []
			if col > 0:
				neighbors.append("knob_%d_%d" % [row, col - 1])
			if col < cols - 1:
				neighbors.append("knob_%d_%d" % [row, col + 1])
			if row > 0:
				neighbors.append("knob_%d_%d" % [row - 1, col])
			if row < rows - 1:
				neighbors.append("knob_%d_%d" % [row + 1, col])
			pieces.append({
				"id": "knob_%d_%d" % [row, col],
				"points": points,
				"home": [x0 + cell_size.x * 0.5, y0 + cell_size.y * 0.5],
				"neighbors": neighbors,
				"visible_bounds": [x0 - knob_amount, y0 - knob_amount, cell_size.x + knob_amount * 2.0, cell_size.y + knob_amount * 2.0],
				"cell": [col, row],
			})
	return pieces


func _append_knob_edge(target: Array, start: Vector2, end: Vector2, normal: Vector2, sign: int, amount: float) -> void:
	var edge_points: Array[Vector2] = _knob_edge_points(start, end, normal, sign, amount)
	for index in range(edge_points.size()):
		if target.size() > 0 and index == 0:
			continue
		var point: Vector2 = edge_points[index]
		target.append([point.x, point.y])


func _knob_edge_points(start: Vector2, end: Vector2, normal: Vector2, sign: int, amount: float) -> Array[Vector2]:
	if sign == 0:
		return [start, end]
	var edge := end - start
	var edge_length := edge.length()
	if edge_length <= 0.0 or amount <= 0.0:
		return [start, end]
	var tangent := edge / edge_length
	var signed_normal := normal * float(sign)
	var center_on_edge := start.lerp(end, 0.5)
	var radius := amount / (1.0 + sqrt(0.5))
	var half_chord := radius * sqrt(0.5)
	var center := center_on_edge + signed_normal * half_chord
	var before := center_on_edge - tangent * half_chord
	var after := center_on_edge + tangent * half_chord
	var points: Array[Vector2] = [start, before]
	var steps := 18
	for step in range(1, steps):
		var t := float(step) / float(steps)
		var angle := PI * 1.25 - PI * 1.5 * t
		points.append(center + tangent * cos(angle) * radius + signed_normal * sin(angle) * radius)
	points.append(after)
	points.append(end)
	return points


func _knob_vertical_sign(edge_col: int, row: int) -> int:
	return 1 if int(edge_col + row) % 2 == 0 else -1


func _knob_horizontal_sign(col: int, edge_row: int) -> int:
	return 1 if int(col + edge_row) % 2 == 0 else -1


func _start_swap_session() -> bool:
	if host.source_size.x <= 0.0 or host.source_size.y <= 0.0:
		return false
	var grid: Dictionary = _swap_grid_config()
	var cols: int = grid["cols"]
	var rows: int = grid["rows"]
	var layout: Dictionary = _mobile_board_layout()
	host.source_scale = layout["source_scale"]
	host.board_origin = layout["board_origin"]
	var order: Array = _swap_shuffled_order(cols, rows)
	for slot_index in range(order.size()):
		_create_swap_tile(int(order[slot_index]), slot_index, cols, rows)
	host.fit_view_to_pieces(false)
	return true


func _create_swap_tile(correct_index: int, slot_index: int, cols: int, rows: int) -> void:
	var tile_source_size := Vector2(host.source_size.x / float(cols), host.source_size.y / float(rows))
	var source_col := correct_index % cols
	var source_row := int(correct_index / cols)
	var source_rect := Rect2(Vector2(source_col, source_row) * tile_source_size, tile_source_size)
	var display_size: Vector2 = tile_source_size * host.source_scale
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
	node.z_index = host.swap_tiles.size() * host.GROUP_Z_STEP
	host.world_root.add_child(node)
	var piece := {
		"id": node.name,
		"polygon": polygon,
		"uv": uv,
		"cut_lines": [],
	}
	node.add_child(host.PieceVisualFactoryScript.create_piece_visual(piece, host.texture, host.piece_visual_style))
	var tile := {
		"node": node,
		"correct_index": correct_index,
		"slot_index": slot_index,
		"size": display_size,
		"is_animating": false,
	}
	host.swap_tiles.append(tile)
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


func _swap_slot_position(slot_index: int, cols := SWAP_FALLBACK_COLS, rows := SWAP_FALLBACK_ROWS) -> Vector2:
	var tile_size: Vector2 = Vector2(host.source_size.x / float(cols), host.source_size.y / float(rows)) * host.source_scale
	var col := slot_index % cols
	var row := int(slot_index / cols)
	return host.board_origin + Vector2(col * tile_size.x, row * tile_size.y)


func _mobile_board_layout() -> Dictionary:
	var bottom_reserved_height: float = host.hud_bottom_reserved_height
	if host.current_mode != "swap":
		bottom_reserved_height += host._tray_area().size.y
	return host.BoardLayoutScript.mobile_board_layout(
		host.source_size,
		host.get_viewport_rect().size,
		host.hud_top_reserved_height,
		bottom_reserved_height,
	)


func _current_mode_piece_count() -> int:
	if host.current_mode == "swap":
		var grid: Dictionary = _swap_grid_config()
		return int(grid["cols"]) * int(grid["rows"])
	var config: Dictionary = host._mode_config(host.active_level_config, host.current_mode)
	if config.has("pieces") and typeof(config["pieces"]) == TYPE_ARRAY:
		var pieces: Array = config["pieces"]
		if not pieces.is_empty():
			return pieces.size()
	if host.current_mode == "knob":
		return max(1, int(config.get("cols", 6))) * max(1, int(config.get("rows", 8)))
	return 0


func _swap_grid_config() -> Dictionary:
	var config: Dictionary = host._mode_config(host.active_level_config, "swap")
	var configured_cols := int(config.get("cols", 0))
	var configured_rows := int(config.get("rows", 0))
	if configured_cols > 0 and configured_rows > 0:
		return {
			"cols": configured_cols,
			"rows": configured_rows,
		}
	return _auto_swap_grid()


func _auto_swap_grid() -> Dictionary:
	return {
		"cols": host.SWAP_FALLBACK_COLS,
		"rows": host.SWAP_FALLBACK_ROWS,
	}


func _create_group(piece: Dictionary, locked_seed := false) -> void:
	var group_node := Node2D.new()
	group_node.name = piece["id"]
	group_node.rotation_degrees = 0.0 if locked_seed else ([0, 90, 180, 270][int(host.rng.randi_range(0, 3))] if host.randomize_piece_rotation else 0.0)
	group_node.z_index = host.groups.size() * host.GROUP_Z_STEP
	host.world_root.add_child(group_node)
	var visual: Node2D = host.PieceVisualFactoryScript.create_piece_visual(piece, host.texture, host.piece_visual_style)
	group_node.add_child(visual)
	piece["visual"] = visual
	var group = host.PieceGroupScript.new(group_node, piece)
	host.groups.append(group)
	if locked_seed:
		group.locked = true
		group.is_seed = true
		group.node.position = group.anchor_home
		host.locked_groups.append(group)
	else:
		group.in_tray = true
		host.tray_groups.append(group)
		host._move_group_to_tray(group, host.tray_groups.size() - 1, true)


func _seed_piece_ids(pieces: Array, mode_config: Dictionary) -> Array[String]:
	var valid := {}
	for piece in pieces:
		valid[str(piece.get("id", ""))] = true
	var assist: Dictionary = mode_config.get("assist", {})
	var seed: Dictionary = assist.get("seed", {}) if typeof(assist) == TYPE_DICTIONARY else {}
	var manual_ids: Array[String] = []
	if str(seed.get("mode", "auto")) == "manual" and seed.has("piece_ids") and typeof(seed["piece_ids"]) == TYPE_ARRAY:
		for id_value in seed["piece_ids"]:
			var id := str(id_value)
			if valid.has(id) and not manual_ids.has(id):
				manual_ids.append(id)
	if not manual_ids.is_empty():
		return manual_ids
	var count := maxi(1, int(seed.get("count", 1)))
	return _auto_seed_piece_ids(pieces, count)


func _auto_seed_piece_ids(pieces: Array, count: int) -> Array[String]:
	var scored := pieces.duplicate()
	scored.sort_custom(func(a, b) -> bool:
		return _seed_score(a) > _seed_score(b)
	)
	var result: Array[String] = []
	if scored.is_empty():
		return result
	var step: int = maxi(1, int(ceil(float(scored.size()) / float(maxi(1, count)))))
	var index: int = 0
	while result.size() < count and index < scored.size():
		var id := str(scored[index].get("id", ""))
		if not id.is_empty():
			result.append(id)
		index += step
	index = 0
	while result.size() < count and index < scored.size():
		var id := str(scored[index].get("id", ""))
		if not id.is_empty() and not result.has(id):
			result.append(id)
		index += 1
	return result


func _seed_score(piece: Dictionary) -> float:
	var home: Vector2 = piece.get("home", Vector2.ZERO)
	var source_center: Vector2 = host.board_origin + host.source_size * host.source_scale * 0.5
	var max_distance := maxf(1.0, (host.source_size * host.source_scale * 0.5).length())
	var edge_score := home.distance_to(source_center) / max_distance
	var neighbor_count := 0
	if piece.has("neighbors") and typeof(piece["neighbors"]) == TYPE_ARRAY:
		neighbor_count = piece["neighbors"].size()
	return edge_score + float(4 - mini(4, neighbor_count)) * 0.25
