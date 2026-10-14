extends Node2D
## Demonstrate a move with translucent image copies, without changing the puzzle.

const Edge := preload("res://scripts/gameplay/board/PieceEdgeFeather.gd")
const Surface := preload("res://scripts/gameplay/board/PieceSurface.gd")
const SOURCE := Color("7C9C80")
const TARGET := Color("C3A567")
const CYCLE := 2.6

var kind := ""
var source_id := ""
var target_id := ""
var _contours: Array = []
var _copies: Array = []
var _age := 0.0
var _duration := 6.0
var _reduced := false


func show_piece(board: Node2D, group) -> void:
	kind = "piece"
	source_id = board._debug_group_id(group)
	_duration = board.HINT_DURATION
	var start: Transform2D = board.global_transform.affine_inverse() * group.node.global_transform
	var destination := Transform2D(
		0.0, Vector2.ONE * board.view_scale, 0.0, board._world_to_screen(group.anchor_home)
	)
	var copy := _new_copy(start, destination)
	var source_polygons: Array = []
	var target_polygons: Array = []
	for member in group.members:
		var original := member["visual"].get_node("piece_texture") as Polygon2D
		var offset: Vector2 = member["visual"].position
		var polygon := PackedVector2Array()
		for point in original.polygon:
			polygon.append(offset + point)
		_add_face(copy, original, polygon)
		source_polygons.append(start * polygon)
		target_polygons.append(destination * polygon)
	_add_contours(source_polygons, SOURCE)
	_add_contours(target_polygons, TARGET)
	_start(board.reduced_motion)


func show_swap(board: Node2D, pair: Array) -> void:
	kind = "swap"
	source_id = str(pair[0]["correct_index"])
	target_id = str(pair[1]["correct_index"])
	_duration = board.SWAP_HINT_DURATION
	for index in 2:
		var tile = pair[index]
		var other = pair[1 - index]
		var start: Transform2D = (
			board.global_transform.affine_inverse() * tile.node.global_transform
		)
		var destination: Transform2D = (
			board.global_transform.affine_inverse() * other.node.global_transform
		)
		var original := tile.node.get_child(0).get_node("piece_texture") as Polygon2D
		var copy := _new_copy(start, destination)
		_add_face(copy, original, original.polygon)
		_add_contours([start * original.polygon], SOURCE if index == 0 else TARGET)
	_start(board.reduced_motion)


func debug_snapshot() -> Dictionary:
	return {
		"kind": kind,
		"source_id": source_id,
		"target_id": target_id,
		"contours": _contours.size(),
		"copies": _copies.size(),
		"animating": is_processing(),
		"age": _age,
		"demo_progress": _demo_progress(),
	}


func extend() -> void:
	_duration = maxf(_duration, _age + 6.0)


func set_reduced_motion(enabled: bool) -> void:
	_reduced = enabled
	set_process(not enabled)
	_update_copies()
	queue_redraw()


func _start(reduced: bool) -> void:
	set_reduced_motion(reduced)


func _new_copy(start: Transform2D, destination: Transform2D) -> Node2D:
	var copy := Node2D.new()
	copy.name = "DemonstrationImage"
	add_child(copy)
	_copies.append({"node": copy, "start": start, "destination": destination})
	return copy


func _add_face(copy: Node2D, original: Polygon2D, polygon: PackedVector2Array) -> void:
	var face := Surface.new()
	face.name = "ImageFace"
	face.polygon = polygon
	face.uv = original.uv
	face.texture = original.texture
	copy.add_child(face)


func _process(delta: float) -> void:
	_age += delta
	_update_copies()
	queue_redraw()


func _demo_progress() -> float:
	return 1.0 if _reduced else smoothstep(0.25, 1.55, fmod(_age, CYCLE))


func _update_copies() -> void:
	var phase := fmod(_age, CYCLE)
	var progress := _demo_progress()
	var opacity := 0.42 if _reduced else minf(phase / 0.18, (2.35 - phase) / 0.4) * 0.78
	modulate.a = 1.0 if _reduced else clampf(minf(_age / 0.15, (_duration - _age) / 0.3), 0.0, 1.0)
	for entry in _copies:
		var start: Transform2D = entry.start
		var destination: Transform2D = entry.destination
		var pose := start.interpolate_with(destination, progress)
		var delta := destination.origin - start.origin
		var bend := delta.normalized().orthogonal() * minf(delta.length() * 0.10, 54.0)
		pose.origin += bend * sin(progress * PI)
		entry.node.transform = pose
		entry.node.modulate.a = clampf(opacity, 0.0, 0.78)


func _draw() -> void:
	var pixel := 1.0 / Edge.pixel_scale(self)
	var pulse := 1.0 if _reduced else 0.80 + 0.20 * sin(_age * TAU / 2.6)
	for contour in _contours:
		var color: Color = contour.color
		var points: PackedVector2Array = contour.points
		draw_colored_polygon(contour.polygon, Color(color, 0.08 * pulse))
		draw_polyline(points, Color(1, 0.98, 0.91, 0.50 * pulse), 4.0 * pixel, true)
		draw_polyline(points, Color(color, 0.75 * pulse), 1.65 * pixel, true)


func _add_contours(polygons: Array, color: Color) -> void:
	for polygon in polygons:
		var points: PackedVector2Array = polygon.duplicate()
		points.append(points[0])
		_contours.append({"points": points, "polygon": polygon, "color": color})
