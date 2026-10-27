extends RefCounted
## Cached curved cardboard for polygon and knob. No per-frame CPU generation.

const Field := preload("res://scripts/gameplay/board/PieceCurveField.gd")
const Surface := preload("res://shaders/PieceCurvedEdge.gdshader")


static func enabled_for_mode(mode: String) -> bool:
	return mode in ["polygon", "knob"]


static func is_prepared(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var field := Field.get_cached(points, minf(bounds.size.x, bounds.size.y) * 0.065)
	return not field.is_empty() and field.texture != null and field.bounds.has_area()


static func apply(face: Polygon2D) -> bool:
	if face.polygon.size() < 3:
		return false
	var bounds := Rect2(face.polygon[0], Vector2.ZERO)
	for point in face.polygon:
		bounds = bounds.expand(point)
	var field := Field.get_cached(face.polygon, minf(bounds.size.x, bounds.size.y) * 0.065)
	if field.is_empty() or field.texture == null or not field.bounds.has_area():
		return false
	var effect := ShaderMaterial.new()
	effect.shader = Surface
	effect.set_shader_parameter("slope_field", field.texture)
	effect.set_shader_parameter("field_origin", field.bounds.position)
	effect.set_shader_parameter("field_size", field.bounds.size)
	face.set_meta("curve_bake_usec", field.get("bake_usec", 0))
	face.set_meta("curve_cache_hit", field.get("cache_hit", false))
	face.material = effect
	return true
