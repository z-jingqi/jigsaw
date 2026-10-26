extends RefCounted
## Opt-in cached curvature preview. No save/config changes or per-frame CPU work.

const Field := preload("res://scripts/gameplay/board/PieceCurveField.gd")
const Surface := preload("res://shaders/PieceCurvedEdge.gdshader")


static func apply(face: Polygon2D, piece_id: String, preview_all := false) -> bool:
	if not preview_all and OS.get_environment("JIGSAW_CURVED_EDGE_PIECE") != piece_id:
		return false
	if face.polygon.size() < 3:
		return false
	var bounds := Rect2(face.polygon[0], Vector2.ZERO)
	for point in face.polygon:
		bounds = bounds.expand(point)
	var field := Field.build(face.polygon, minf(bounds.size.x, bounds.size.y) * 0.065)
	if field.texture == null or not field.bounds.has_area():
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
