extends RefCounted
## Opt-in single-piece prototype. No save/config changes and no per-frame CPU work.

const Surface := preload("res://shaders/PieceCurvedEdge.gdshader")


static func apply(face: Polygon2D, piece_id: String) -> bool:
	if OS.get_environment("JIGSAW_CURVED_EDGE_PIECE") != piece_id:
		return false
	if face.polygon.size() < 3 or face.polygon.size() > 64:
		return false
	var bounds := Rect2(face.polygon[0], Vector2.ZERO)
	for point in face.polygon:
		bounds = bounds.expand(point)
	var points := face.polygon.duplicate()
	points.resize(64)
	var effect := ShaderMaterial.new()
	effect.shader = Surface
	effect.set_shader_parameter("outline", points)
	effect.set_shader_parameter("outline_count", face.polygon.size())
	effect.set_shader_parameter("curve_width", minf(bounds.size.x, bounds.size.y) * 0.065)
	face.material = effect
	return true
