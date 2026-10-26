class_name KnobSourceGeometry
extends RefCounted
## Shared source-pixel geometry for gameplay and presentation previews.


static func generate(config: Dictionary, source_size: Vector2) -> Array:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return []
	var cols: int = maxi(1, int(config.get("cols", 6)))
	var rows: int = maxi(1, int(config.get("rows", 8)))
	var cell_size := Vector2(source_size.x / float(cols), source_size.y / float(rows))
	var knob_amount := minf(cell_size.x, cell_size.y) * float(config.get("knob_size", 0.24))
	var pieces := []
	for row in range(rows):
		for col in range(cols):
			var x0 := float(col) * cell_size.x
			var y0 := float(row) * cell_size.y
			var x1 := float(col + 1) * cell_size.x
			var y1 := float(row + 1) * cell_size.y
			var points: Array = []
			_append_knob_edge(
				points,
				Vector2(x0, y0),
				Vector2(x1, y0),
				Vector2(0, -1),
				0 if row == 0 else -_knob_horizontal_sign(col, row),
				knob_amount
			)
			_append_knob_edge(
				points,
				Vector2(x1, y0),
				Vector2(x1, y1),
				Vector2(1, 0),
				0 if col == cols - 1 else _knob_vertical_sign(col + 1, row),
				knob_amount
			)
			_append_knob_edge(
				points,
				Vector2(x1, y1),
				Vector2(x0, y1),
				Vector2(0, 1),
				0 if row == rows - 1 else _knob_horizontal_sign(col, row + 1),
				knob_amount
			)
			_append_knob_edge(
				points,
				Vector2(x0, y1),
				Vector2(x0, y0),
				Vector2(-1, 0),
				0 if col == 0 else -_knob_vertical_sign(col, row),
				knob_amount
			)
			var neighbors := []
			if col > 0:
				neighbors.append("knob_%d_%d" % [row, col - 1])
			if col < cols - 1:
				neighbors.append("knob_%d_%d" % [row, col + 1])
			if row > 0:
				neighbors.append("knob_%d_%d" % [row - 1, col])
			if row < rows - 1:
				neighbors.append("knob_%d_%d" % [row + 1, col])
			(
				pieces
				. append(
					{
						"id": "knob_%d_%d" % [row, col],
						"points": points,
						"home": [x0 + cell_size.x * 0.5, y0 + cell_size.y * 0.5],
						"neighbors": neighbors,
						"visible_bounds":
						[
							x0 - knob_amount,
							y0 - knob_amount,
							cell_size.x + knob_amount * 2.0,
							cell_size.y + knob_amount * 2.0
						],
						"cell": [col, row],
					}
				)
			)
	return pieces


static func _append_knob_edge(
	target: Array, start: Vector2, end: Vector2, normal: Vector2, sign: int, amount: float
) -> void:
	var edge_points: Array[Vector2] = _knob_edge_points(start, end, normal, sign, amount)
	for index in range(edge_points.size()):
		if target.size() > 0 and index == 0:
			continue
		var point: Vector2 = edge_points[index]
		target.append([point.x, point.y])


static func _knob_edge_points(
	start: Vector2, end: Vector2, normal: Vector2, sign: int, amount: float
) -> Array[Vector2]:
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


static func _knob_vertical_sign(edge_col: int, row: int) -> int:
	return 1 if int(edge_col + row) % 2 == 0 else -1


static func _knob_horizontal_sign(col: int, edge_row: int) -> int:
	return 1 if int(col + edge_row) % 2 == 0 else -1
