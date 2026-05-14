extends RefCounted
class_name LevelGenerator

const EDGE_POINTS := 24
const ALPHA_THRESHOLD := 0.08
const ALPHA_SAMPLE_STEP := 8
const COMPONENT_SAMPLE_STEP := 4
const COMPONENT_RECT_PADDING := 6.0
const MIN_COMPONENT_SAMPLES := 16
const MIN_COMPONENT_SOURCE_SIZE := 44.0
const EDGE_ALPHA_RADIUS := 3
const EDGE_TEMPLATE_COUNT := 6


static func generate(texture_size: Vector2, cols: int, rows: int, piece_size: float, piece_mode: String, alpha_image: Image = null, level_config := {}) -> Dictionary:
	var source_scale := (piece_size * float(cols)) / texture_size.x
	var board_size := texture_size * source_scale
	var board_origin := -board_size * 0.5
	var edge_defs := _create_edge_defs(cols, rows, piece_mode, piece_size)
	var components_by_cell := _find_visible_components(edge_defs, cols, rows, source_scale, alpha_image, level_config)
	var visible_cells := {}
	for cell in components_by_cell.keys():
		visible_cells[cell] = true
	var pieces: Array[Dictionary] = []
	var pieces_by_cell := {}

	for row in rows:
		for col in cols:
			var cell := Vector2i(col, row)
			if not components_by_cell.has(cell):
				continue
			var components: Array = components_by_cell[cell]
			var rect_pos := Vector2(col, row) * piece_size
			pieces_by_cell[cell] = []
			for component_index in components.size():
				var component: Dictionary = components[component_index]
				var component_rect: Rect2 = component["rect"]
				var use_full_piece := alpha_image == null
				var whole_polygon := _build_piece_polygon(edge_defs, col, row)
				var source_polygon := whole_polygon if use_full_piece else _clip_polygon_to_rect(whole_polygon, component_rect, source_scale)
				var home := board_origin + rect_pos + Vector2.ONE * piece_size * 0.5 if use_full_piece else board_origin + (component_rect.position + component_rect.size * 0.5) * source_scale
				var local_polygon := PackedVector2Array()
				var uvs := PackedVector2Array()
				for p in source_polygon:
					var display_point: Vector2 = board_origin + p
					local_polygon.append(display_point - home)
					uvs.append(p / source_scale)

				var piece := {
					"id": _piece_id(cell, component_index, components.size()),
					"cell": cell,
					"home": home,
					"polygon": local_polygon,
					"uv": uvs,
					"neighbors": [],
					"source_rect": component_rect,
					"component_samples": component["samples"],
					"cut_lines": [],
				}
				pieces.append(piece)
				pieces_by_cell[cell].append(piece)

	_assign_piece_neighbors(pieces_by_cell, edge_defs, cols, rows, source_scale, alpha_image)
	_assign_piece_cut_lines(pieces_by_cell, edge_defs, board_origin, source_scale, alpha_image)

	return {
		"pieces": pieces,
		"board_origin": board_origin,
		"board_size": board_size,
		"source_scale": source_scale,
	}


static func inspect_components(texture_size: Vector2, cols: int, rows: int, piece_size: float, piece_mode: String, alpha_image: Image, level_config := {}) -> Array[Dictionary]:
	var source_scale := (piece_size * float(cols)) / texture_size.x
	var edge_defs := _create_edge_defs(cols, rows, piece_mode, piece_size)
	var result: Array[Dictionary] = []
	for row in rows:
		for col in cols:
			var cell := Vector2i(col, row)
			var polygon := _build_piece_polygon(edge_defs, col, row)
			var components := _visible_components_for_polygon_raw(polygon, source_scale, alpha_image, cell)
			var overrides: Dictionary = level_config.get("component_overrides", {})
			for component in components:
				var rect: Rect2 = component["rect"]
				var default_action := _default_component_action(component)
				result.append({
					"key": component["component_key"],
					"cell": [cell.x, cell.y],
					"rect": [roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)],
					"samples": component["count"],
					"default_action": default_action,
					"action": str(overrides.get(component["component_key"], default_action)),
				})
	return result


static func _find_visible_components(edge_defs: Dictionary, cols: int, rows: int, source_scale: float, alpha_image: Image, level_config: Dictionary) -> Dictionary:
	var components_by_cell := {}
	for row in rows:
		for col in cols:
			var cell := Vector2i(col, row)
			var polygon := _build_piece_polygon(edge_defs, col, row)
			var components := [{ "rect": Rect2(), "samples": {}, "count": 0 }] if alpha_image == null else _visible_components_for_polygon(polygon, source_scale, alpha_image, cell, level_config)
			if not components.is_empty():
				components_by_cell[cell] = components
	return components_by_cell


static func _create_edge_defs(cols: int, rows: int, piece_mode: String, piece_size: float) -> Dictionary:
	var h: Array = []
	var v: Array = []
	for row in rows + 1:
		var line: Array[PackedVector2Array] = []
		for col in cols:
			var start := Vector2(col, row) * piece_size
			var end := start + Vector2(piece_size, 0.0)
			var sign := 0 if row == 0 or row == rows else _edge_sign(col, row, piece_mode)
			line.append(_build_edge_path(start, end, sign, piece_mode))
		h.append(line)
	for col in cols + 1:
		var line: Array[PackedVector2Array] = []
		for row in rows:
			var start := Vector2(col, row) * piece_size
			var end := start + Vector2(0.0, piece_size)
			var sign := 0 if col == 0 or col == cols else _edge_sign(col, row, piece_mode)
			line.append(_build_edge_path(start, end, sign, piece_mode))
		v.append(line)
	return { "h": h, "v": v }


static func _edge_sign(a: int, b: int, piece_mode: String) -> int:
	var n := a * 31 + b * 17 + (3 if piece_mode == "classic" else 11)
	return 1 if n % 2 == 0 else -1


static func _build_piece_polygon(edge_defs: Dictionary, col: int, row: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	_append_path(points, edge_defs["h"][row][col], false)
	_append_path(points, edge_defs["v"][col + 1][row], false)
	_append_path(points, edge_defs["h"][row + 1][col], true)
	_append_path(points, edge_defs["v"][col][row], true)
	return points


static func _build_edge_path(start: Vector2, end: Vector2, sign: int, piece_mode: String) -> PackedVector2Array:
	return _classic_edge(start, end, sign) if piece_mode == "classic" else _irregular_edge(start, end, sign)


static func _piece_id(cell: Vector2i, component_index: int, component_count: int) -> String:
	if component_count == 1:
		return "p_%d_%d" % [cell.x, cell.y]
	return "p_%d_%d_%d" % [cell.x, cell.y, component_index]


static func _assign_piece_neighbors(pieces_by_cell: Dictionary, edge_defs: Dictionary, cols: int, rows: int, source_scale: float, alpha_image: Image) -> void:
	for row in rows:
		for col in cols:
			var cell := Vector2i(col, row)
			if not pieces_by_cell.has(cell):
				continue
			var cell_pieces: Array = pieces_by_cell[cell]
			var right := cell + Vector2i(1, 0)
			if right.x < cols and pieces_by_cell.has(right):
				_connect_touching_piece_arrays(cell_pieces, pieces_by_cell[right], edge_defs["v"][cell.x + 1][cell.y], source_scale, alpha_image)
			var bottom := cell + Vector2i(0, 1)
			if bottom.y < rows and pieces_by_cell.has(bottom):
				_connect_touching_piece_arrays(cell_pieces, pieces_by_cell[bottom], edge_defs["h"][cell.y + 1][cell.x], source_scale, alpha_image)


static func _connect_touching_piece_arrays(a_pieces: Array, b_pieces: Array, edge_path: PackedVector2Array, source_scale: float, alpha_image: Image) -> void:
	for a in a_pieces:
		for b in b_pieces:
			if _component_rects_share_edge_path(a["source_rect"], b["source_rect"], edge_path, source_scale, alpha_image):
				if not a["neighbors"].has(b["id"]):
					a["neighbors"].append(b["id"])
				if not b["neighbors"].has(a["id"]):
					b["neighbors"].append(a["id"])


static func _assign_piece_cut_lines(pieces_by_cell: Dictionary, edge_defs: Dictionary, board_origin: Vector2, source_scale: float, alpha_image: Image) -> void:
	for cell in pieces_by_cell.keys():
		for piece in pieces_by_cell[cell]:
			piece["cut_lines"] = _cut_lines_for_piece(edge_defs, piece, pieces_by_cell, board_origin, source_scale, alpha_image)


static func _component_rects_share_edge_path(a: Rect2, b: Rect2, edge_path: PackedVector2Array, source_scale: float, alpha_image: Image) -> bool:
	var shared_points := 0
	var expanded_a := a.grow(COMPONENT_SAMPLE_STEP)
	var expanded_b := b.grow(COMPONENT_SAMPLE_STEP)
	for point in edge_path:
		var source_point := point / source_scale
		if not expanded_a.has_point(source_point) or not expanded_b.has_point(source_point):
			continue
		if alpha_image != null and not _has_alpha_near(source_point, alpha_image, EDGE_ALPHA_RADIUS):
			continue
		shared_points += 1
		if shared_points >= 2:
			return true
	return false


static func _cut_lines_for_piece(edge_defs: Dictionary, piece: Dictionary, pieces_by_cell: Dictionary, board_origin: Vector2, source_scale: float, alpha_image: Image) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	var cell: Vector2i = piece["cell"]
	var home: Vector2 = piece["home"]
	var source_rect: Rect2 = piece["source_rect"]
	var edge_specs := [
		{ "neighbor": cell + Vector2i(0, -1), "path": edge_defs["h"][cell.y][cell.x], "reversed": false },
		{ "neighbor": cell + Vector2i(1, 0), "path": edge_defs["v"][cell.x + 1][cell.y], "reversed": false },
		{ "neighbor": cell + Vector2i(0, 1), "path": edge_defs["h"][cell.y + 1][cell.x], "reversed": true },
		{ "neighbor": cell + Vector2i(-1, 0), "path": edge_defs["v"][cell.x][cell.y], "reversed": true },
	]
	for spec in edge_specs:
		if not pieces_by_cell.has(spec["neighbor"]) or not _has_neighbor_in_cell(piece, pieces_by_cell[spec["neighbor"]]):
			continue
		var segments := _visible_edge_segments(spec["path"], spec["reversed"], board_origin, home, source_scale, alpha_image, source_rect)
		for segment in segments:
			lines.append(segment)
	return lines


static func _has_neighbor_in_cell(piece: Dictionary, other_pieces: Array) -> bool:
	for other in other_pieces:
		if piece["neighbors"].has(other["id"]):
			return true
	return false


static func _visible_edge_segments(edge_points: PackedVector2Array, reversed: bool, board_origin: Vector2, home: Vector2, source_scale: float, alpha_image: Image, source_rect: Rect2 = Rect2()) -> Array[PackedVector2Array]:
	var ordered := _ordered_points(edge_points, reversed)
	var segments: Array[PackedVector2Array] = []
	var current := PackedVector2Array()
	for i in ordered.size():
		var point: Vector2 = ordered[i]
		var source_point := point / source_scale
		var is_visible := (source_rect.size == Vector2.ZERO or source_rect.has_point(source_point)) and (alpha_image == null or _has_alpha_near(source_point, alpha_image, EDGE_ALPHA_RADIUS))
		if is_visible:
			current.append(board_origin + point - home)
		elif current.size() > 1:
			segments.append(current)
			current = PackedVector2Array()
		else:
			current = PackedVector2Array()
	if current.size() > 1:
		segments.append(current)
	return segments


static func _ordered_points(edge_points: PackedVector2Array, reversed: bool) -> PackedVector2Array:
	var ordered := PackedVector2Array()
	if reversed:
		for i in range(edge_points.size() - 1, -1, -1):
			ordered.append(edge_points[i])
		return ordered
	for point in edge_points:
		ordered.append(point)
	return ordered


static func _append_path(points: PackedVector2Array, edge_points: PackedVector2Array, reversed := false) -> void:
	if reversed:
		for i in range(edge_points.size() - 1, -1, -1):
			if points.size() > 0 and i == edge_points.size() - 1:
				continue
			points.append(edge_points[i])
		return
	for i in edge_points.size():
		if points.size() > 0 and i == 0:
			continue
		points.append(edge_points[i])


static func _clip_polygon_to_rect(polygon: PackedVector2Array, source_rect: Rect2, source_scale: float) -> PackedVector2Array:
	var rect := Rect2(source_rect.position * source_scale, source_rect.size * source_scale)
	var points: Array[Vector2] = []
	for point in polygon:
		points.append(point)
	points = _clip_points_to_half_plane(points, Vector2(1, 0), rect.position.x)
	points = _clip_points_to_half_plane(points, Vector2(-1, 0), -rect.end.x)
	points = _clip_points_to_half_plane(points, Vector2(0, 1), rect.position.y)
	points = _clip_points_to_half_plane(points, Vector2(0, -1), -rect.end.y)
	return PackedVector2Array(points)


static func _clip_points_to_half_plane(points: Array[Vector2], normal: Vector2, limit: float) -> Array[Vector2]:
	var clipped: Array[Vector2] = []
	if points.is_empty():
		return clipped
	var previous := points[points.size() - 1]
	var previous_inside := previous.dot(normal) >= limit
	for current in points:
		var current_inside := current.dot(normal) >= limit
		if current_inside != previous_inside:
			clipped.append(_line_half_plane_intersection(previous, current, normal, limit))
		if current_inside:
			clipped.append(current)
		previous = current
		previous_inside = current_inside
	return clipped


static func _line_half_plane_intersection(a: Vector2, b: Vector2, normal: Vector2, limit: float) -> Vector2:
	var da := a.dot(normal) - limit
	var db := b.dot(normal) - limit
	var denom := da - db
	if is_zero_approx(denom):
		return a
	return a.lerp(b, da / denom)


static func _visible_components_for_polygon(polygon: PackedVector2Array, source_scale: float, alpha_image: Image, cell: Vector2i, level_config: Dictionary) -> Array[Dictionary]:
	var all_components := _visible_components_for_polygon_raw(polygon, source_scale, alpha_image, cell)
	var components := _apply_component_overrides(all_components, level_config)
	components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ar: Rect2 = a["rect"]
		var br: Rect2 = b["rect"]
		return ar.position.y < br.position.y if not is_equal_approx(ar.position.y, br.position.y) else ar.position.x < br.position.x
	)
	return components


static func _visible_components_for_polygon_raw(polygon: PackedVector2Array, source_scale: float, alpha_image: Image, cell: Vector2i) -> Array[Dictionary]:
	var bounds := _source_bounds_for_polygon(polygon, source_scale, alpha_image.get_size())
	var visible_points := {}
	for y in range(int(bounds.position.y), int(bounds.end.y), COMPONENT_SAMPLE_STEP):
		for x in range(int(bounds.position.x), int(bounds.end.x), COMPONENT_SAMPLE_STEP):
			var source_point := Vector2(x, y)
			if not Geometry2D.is_point_in_polygon(source_point * source_scale, polygon):
				continue
			if alpha_image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				visible_points[Vector2i(x, y)] = true

	var visited := {}
	var all_components: Array[Dictionary] = []
	for start in visible_points.keys():
		if visited.has(start):
			continue
		var component := _flood_visible_component(start, visible_points, visited, alpha_image.get_size())
		var rect: Rect2 = component["rect"]
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			all_components.append(component)
	all_components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ar: Rect2 = a["rect"]
		var br: Rect2 = b["rect"]
		return ar.position.y < br.position.y if not is_equal_approx(ar.position.y, br.position.y) else ar.position.x < br.position.x
	)
	for i in all_components.size():
		all_components[i]["component_key"] = _component_key(cell, i)
	return all_components


static func _component_key(cell: Vector2i, component_index: int) -> String:
	return "%d,%d:%d" % [cell.x, cell.y, component_index]


static func _apply_component_overrides(all_components: Array[Dictionary], level_config: Dictionary) -> Array[Dictionary]:
	if all_components.is_empty():
		return []
	var overrides: Dictionary = level_config.get("component_overrides", {})
	var playable: Array[Dictionary] = []
	var merge_later: Array[Dictionary] = []
	for component in all_components:
		var action := str(overrides.get(component["component_key"], _default_component_action(component)))
		component["action"] = action
		if action == "drop":
			continue
		if action == "merge_nearest":
			merge_later.append(component)
			continue
		if action == "keep" or _is_playable_component(component):
			playable.append(component)
		else:
			merge_later.append(component)
	if playable.is_empty():
		var largest := all_components[0]
		for component in all_components:
			if _component_area(component) > _component_area(largest):
				largest = component
		playable.append(largest)
		merge_later.erase(largest)
	for component in merge_later:
		var target := _nearest_component(component, playable)
		_merge_component_into(target, component)
	return playable


static func _default_component_action(component: Dictionary) -> String:
	return "keep" if _is_playable_component(component) else "drop"


static func _is_playable_component(component: Dictionary) -> bool:
	var rect: Rect2 = component["rect"]
	return component["count"] >= MIN_COMPONENT_SAMPLES and rect.size.x >= MIN_COMPONENT_SOURCE_SIZE and rect.size.y >= MIN_COMPONENT_SOURCE_SIZE


static func _nearest_component(component: Dictionary, candidates: Array[Dictionary]) -> Dictionary:
	var nearest := candidates[0]
	var center: Vector2 = component["rect"].get_center()
	var best_distance := INF
	for candidate in candidates:
		var distance := center.distance_squared_to(candidate["rect"].get_center())
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	return nearest


static func _merge_component_into(target: Dictionary, source: Dictionary) -> void:
	var target_samples: Dictionary = target["samples"]
	for sample in source["samples"].keys():
		target_samples[sample] = true
	target["samples"] = target_samples
	target["rect"] = target["rect"].merge(source["rect"])
	target["count"] += source["count"]


static func _component_area(component: Dictionary) -> float:
	var rect: Rect2 = component["rect"]
	return rect.size.x * rect.size.y


static func _flood_visible_component(start: Vector2i, visible_points: Dictionary, visited: Dictionary, image_size: Vector2i) -> Dictionary:
	var stack: Array[Vector2i] = [start]
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	var samples := {}
	var count := 0
	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()
		if visited.has(point):
			continue
		visited[point] = true
		samples[point] = true
		count += 1
		min_point = min_point.min(Vector2(point))
		max_point = max_point.max(Vector2(point))
		for neighbor in [
			point + Vector2i(COMPONENT_SAMPLE_STEP, 0),
			point + Vector2i(-COMPONENT_SAMPLE_STEP, 0),
			point + Vector2i(0, COMPONENT_SAMPLE_STEP),
			point + Vector2i(0, -COMPONENT_SAMPLE_STEP),
		]:
			if visible_points.has(neighbor) and not visited.has(neighbor):
				stack.append(neighbor)
	min_point -= Vector2.ONE * COMPONENT_RECT_PADDING
	max_point += Vector2.ONE * (COMPONENT_SAMPLE_STEP + COMPONENT_RECT_PADDING)
	min_point.x = clampf(min_point.x, 0.0, float(image_size.x - 1))
	min_point.y = clampf(min_point.y, 0.0, float(image_size.y - 1))
	max_point.x = clampf(max_point.x, min_point.x + 1.0, float(image_size.x))
	max_point.y = clampf(max_point.y, min_point.y + 1.0, float(image_size.y))
	var rect := Rect2(min_point, max_point - min_point)
	return { "rect": rect, "samples": samples, "count": count }


static func _source_bounds_for_polygon(polygon: PackedVector2Array, source_scale: float, image_size: Vector2i) -> Rect2:
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for point in polygon:
		var source_point := point / source_scale
		min_point = min_point.min(source_point)
		max_point = max_point.max(source_point)
	min_point.x = clampf(floorf(min_point.x), 0.0, float(image_size.x - 1))
	min_point.y = clampf(floorf(min_point.y), 0.0, float(image_size.y - 1))
	max_point.x = clampf(ceilf(max_point.x) + 1.0, 1.0, float(image_size.x))
	max_point.y = clampf(ceilf(max_point.y) + 1.0, 1.0, float(image_size.y))
	return Rect2(min_point, max_point - min_point)


static func _has_alpha_near(source_point: Vector2, alpha_image: Image, radius: int) -> bool:
	var center := Vector2i(roundi(source_point.x), roundi(source_point.y))
	var image_size := alpha_image.get_size()
	for y in range(center.y - radius, center.y + radius + 1):
		if y < 0 or y >= image_size.y:
			continue
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= image_size.x:
				continue
			if alpha_image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				return true
	return false


static func _classic_edge(start: Vector2, end: Vector2, sign: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir := end - start
	var normal := Vector2(dir.y, -dir.x).normalized()
	var amp := 32.0 * float(sign)

	for i in EDGE_POINTS + 1:
		var t := float(i) / float(EDGE_POINTS)
		var p := start.lerp(end, t)
		var bulge := 0.0
		if sign != 0 and t > 0.30 and t < 0.70:
			var k := (t - 0.30) / 0.40
			bulge = sin(k * PI) * amp
			bulge += sin(k * PI * 3.0) * amp * 0.12
		pts.append(p + normal * bulge)
	return pts


static func _irregular_edge(start: Vector2, end: Vector2, sign: int) -> PackedVector2Array:
	if sign == 0:
		return _straight_edge(start, end)
	var template := _edge_template_index(start, end)
	match template:
		0:
			return _wave_edge(start, end, sign)
		1:
			return _round_tab_edge(start, end, sign)
		2:
			return _star_tab_edge(start, end, sign)
		3:
			return _blob_edge(start, end, sign)
		4:
			return _zigzag_edge(start, end, sign)
		_:
			return _crescent_edge(start, end, sign)


static func _edge_template_index(start: Vector2, end: Vector2) -> int:
	var seed := sin(start.x * 12.9898 + start.y * 78.233 + end.x * 37.719 + end.y * 11.137) * 43758.5453
	return int(abs(floori(seed))) % EDGE_TEMPLATE_COUNT


static func _straight_edge(start: Vector2, end: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in EDGE_POINTS + 1:
		var t := float(i) / float(EDGE_POINTS)
		pts.append(start.lerp(end, t))
	return pts


static func _wave_edge(start: Vector2, end: Vector2, sign: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir := end - start
	var normal := Vector2(dir.y, -dir.x).normalized()
	var amp := 20.0 * float(sign)

	for i in EDGE_POINTS + 1:
		var t := float(i) / float(EDGE_POINTS)
		var p := start.lerp(end, t)
		var taper := sin(t * PI)
		var wave := sin(t * PI * 2.0 + 0.8) * amp * taper
		var wobble := sin(t * PI * 5.0) * amp * 0.22 * taper
		pts.append(p + normal * (wave + wobble))
	return pts


static func _round_tab_edge(start: Vector2, end: Vector2, sign: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir := end - start
	var normal := Vector2(dir.y, -dir.x).normalized()
	var amp := 34.0 * float(sign)
	for i in EDGE_POINTS + 1:
		var t := float(i) / float(EDGE_POINTS)
		var p := start.lerp(end, t)
		var offset := 0.0
		if t >= 0.28 and t <= 0.72:
			var u := (t - 0.50) / 0.22
			offset = sqrt(maxf(0.0, 1.0 - u * u)) * amp
		pts.append(p + normal * offset)
	return pts


static func _star_tab_edge(start: Vector2, end: Vector2, sign: int) -> PackedVector2Array:
	var dir := end - start
	var normal := Vector2(dir.y, -dir.x).normalized()
	var amp := 34.0 * float(sign)
	var controls := [
		Vector2(0.00, 0.00),
		Vector2(0.26, 0.00),
		Vector2(0.34, 0.42),
		Vector2(0.41, 0.16),
		Vector2(0.50, 1.08),
		Vector2(0.59, 0.16),
		Vector2(0.66, 0.42),
		Vector2(0.74, 0.00),
		Vector2(1.00, 0.00),
	]
	var pts := PackedVector2Array()
	for control in controls:
		var p := start.lerp(end, control.x)
		pts.append(p + normal * control.y * amp)
	return pts


static func _blob_edge(start: Vector2, end: Vector2, sign: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir := end - start
	var normal := Vector2(dir.y, -dir.x).normalized()
	var amp := 24.0 * float(sign)
	for i in EDGE_POINTS + 1:
		var t := float(i) / float(EDGE_POINTS)
		var p := start.lerp(end, t)
		var taper := sin(t * PI)
		var offset := (
			sin(t * PI * 1.35 + 0.25) * 0.64
			+ sin(t * PI * 3.1 + 1.4) * 0.22
			+ sin(t * PI * 5.2 + 0.8) * 0.12
		) * amp * taper
		pts.append(p + normal * offset)
	return pts


static func _zigzag_edge(start: Vector2, end: Vector2, sign: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir := end - start
	var normal := Vector2(dir.y, -dir.x).normalized()
	var amp := 22.0 * float(sign)
	var controls := [
		Vector2(0.00, 0.00),
		Vector2(0.20, 0.00),
		Vector2(0.30, 0.70),
		Vector2(0.40, -0.28),
		Vector2(0.50, 0.82),
		Vector2(0.60, -0.22),
		Vector2(0.70, 0.58),
		Vector2(0.80, 0.00),
		Vector2(1.00, 0.00),
	]
	for control in controls:
		var p := start.lerp(end, control.x)
		pts.append(p + normal * control.y * amp)
	return pts


static func _crescent_edge(start: Vector2, end: Vector2, sign: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir := end - start
	var normal := Vector2(dir.y, -dir.x).normalized()
	var amp := 28.0 * float(sign)
	for i in EDGE_POINTS + 1:
		var t := float(i) / float(EDGE_POINTS)
		var p := start.lerp(end, t)
		var taper := sin(t * PI)
		var wide_arc := sin(t * PI) * 0.92
		var inner_bite := sin(clampf((t - 0.40) / 0.32, 0.0, 1.0) * PI) * 0.55
		var offset := (wide_arc - inner_bite) * amp * taper
		pts.append(p + normal * offset)
	return pts
