extends RefCounted
class_name LevelGenerator

const EDGE_POINTS := 10


static func generate(texture_size: Vector2, cols: int, rows: int, piece_size: float, piece_mode: String) -> Dictionary:
	var source_scale := (piece_size * float(cols)) / texture_size.x
	var board_size := texture_size * source_scale
	var board_origin := -board_size * 0.5
	var edge_defs := _create_edge_defs(cols, rows, piece_mode)
	var pieces: Array[Dictionary] = []

	for row in rows:
		for col in cols:
			var cell := Vector2i(col, row)
			var rect_pos := Vector2(col, row) * piece_size
			var home := board_origin + rect_pos + Vector2.ONE * piece_size * 0.5
			var edges := {
				"top": 0 if row == 0 else -edge_defs["h"][row][col],
				"right": 0 if col == cols - 1 else edge_defs["v"][col + 1][row],
				"bottom": 0 if row == rows - 1 else edge_defs["h"][row + 1][col],
				"left": 0 if col == 0 else -edge_defs["v"][col][row],
			}
			var polygon := _build_piece_polygon(rect_pos, piece_size, edges, piece_mode)
			var local_polygon := PackedVector2Array()
			var uvs := PackedVector2Array()
			var neighbors := _neighbors_for(cell, cols, rows)
			for p in polygon:
				var display_point: Vector2 = board_origin + p
				local_polygon.append(display_point - home)
				uvs.append(p / source_scale)

			pieces.append({
				"id": "p_%d_%d" % [col, row],
				"cell": cell,
				"home": home,
				"polygon": local_polygon,
				"uv": uvs,
				"neighbors": neighbors,
			})

	return {
		"pieces": pieces,
		"board_origin": board_origin,
		"board_size": board_size,
		"source_scale": source_scale,
	}


static func _neighbors_for(cell: Vector2i, cols: int, rows: int) -> Array[String]:
	var neighbors: Array[String] = []
	var offsets: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for offset in offsets:
		var next_cell: Vector2i = cell + offset
		if next_cell.x >= 0 and next_cell.x < cols and next_cell.y >= 0 and next_cell.y < rows:
			neighbors.append("p_%d_%d" % [next_cell.x, next_cell.y])
	return neighbors


static func _create_edge_defs(cols: int, rows: int, piece_mode: String) -> Dictionary:
	var h: Array = []
	var v: Array = []
	for row in rows + 1:
		var line: Array[int] = []
		for col in cols:
			line.append(0 if row == 0 or row == rows else _edge_sign(col, row, piece_mode))
		h.append(line)
	for col in cols + 1:
		var line: Array[int] = []
		for row in rows:
			line.append(0 if col == 0 or col == cols else _edge_sign(col, row, piece_mode))
		v.append(line)
	return { "h": h, "v": v }


static func _edge_sign(a: int, b: int, piece_mode: String) -> int:
	var n := a * 31 + b * 17 + (3 if piece_mode == "classic" else 11)
	return 1 if n % 2 == 0 else -1


static func _build_piece_polygon(rect_pos: Vector2, piece_size: float, edges: Dictionary, piece_mode: String) -> PackedVector2Array:
	var tl := rect_pos
	var tr := rect_pos + Vector2(piece_size, 0)
	var br := rect_pos + Vector2(piece_size, piece_size)
	var bl := rect_pos + Vector2(0, piece_size)
	var points := PackedVector2Array()
	_append_edge(points, tl, tr, edges["top"], piece_mode)
	_append_edge(points, tr, br, edges["right"], piece_mode)
	_append_edge(points, br, bl, edges["bottom"], piece_mode)
	_append_edge(points, bl, tl, edges["left"], piece_mode)
	return points


static func _append_edge(points: PackedVector2Array, start: Vector2, end: Vector2, sign: int, piece_mode: String) -> void:
	var edge_points := _classic_edge(start, end, sign) if piece_mode == "classic" else _irregular_edge(start, end, sign)
	for i in edge_points.size():
		if points.size() > 0 and i == 0:
			continue
		points.append(edge_points[i])


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
