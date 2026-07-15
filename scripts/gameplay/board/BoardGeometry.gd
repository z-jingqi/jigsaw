extends RefCounted
class_name BoardGeometry

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func _mode_key(play_mode: String) -> String:
	return "knob" if play_mode == "classic" else play_mode


func _mode_config(level_config: Dictionary, play_mode: String) -> Dictionary:
	var mode: String = _mode_key(play_mode)
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
		var rect: Rect2 = _json_rect(item, Rect2())
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
	var bounds: Rect2 = _source_rect_for_points(points)
	return bounds.size.x * bounds.size.y


func _visible_source_rect_for_polygon(points: PackedVector2Array, fallback: Rect2) -> Rect2:
	var bounds: Rect2 = _source_rect_for_points(points)
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	var found := false
	for y in range(floori(bounds.position.y), ceili(bounds.end.y) + 1):
		for x in range(floori(bounds.position.x), ceili(bounds.end.x) + 1):
			var point := Vector2(x, y)
			if not Geometry2D.is_point_in_polygon(point, points):
				continue
			if not host._source_point_has_alpha(point, 0):
				continue
			min_point = min_point.min(point)
			max_point = max_point.max(point)
			found = true
	if not found:
		return fallback
	return Rect2(min_point, max_point - min_point).grow(2.0)
