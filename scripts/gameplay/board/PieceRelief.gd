extends Node2D
## Shared edge treatment; the source polygon and UVs remain unchanged.

const SIDE_COLOR := Color("#795235")
const LIGHT_COLOR := Color(1.0, 0.94, 0.80, 0.62)
const SHADE_COLOR := Color(0.20, 0.12, 0.07, 0.42)
const LIGHT_DIRECTION := Vector2(-0.6, -0.8)
const DEPTH := Vector2(1.2, 3.8)
const BEVEL_WIDTH := 2.2

var points := PackedVector2Array()
var surface := false
var triangles := PackedInt32Array()


func setup(polygon: PackedVector2Array, draw_surface: bool) -> void:
	points = polygon
	surface = draw_surface
	triangles = Geometry2D.triangulate_polygon(points) if not surface else PackedInt32Array()
	z_index = 2 if surface else -1
	set_notify_transform(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _draw() -> void:
	if points.size() < 3:
		return
	# Keep the edge readable in both the tray and the zoomed board.
	var canvas_scale := maxf(0.1, get_global_transform_with_canvas().x.length())
	if not surface:
		var side := PackedVector2Array()
		for point in points:
			side.append(point + DEPTH / canvas_scale)
		# Translating a concave outline can make near-collinear knob edges fail
		# triangulation at some viewport scales. Reuse the source triangulation.
		for index in range(0, triangles.size(), 3):
			draw_primitive(
				PackedVector2Array(
					[side[triangles[index]], side[triangles[index + 1]], side[triangles[index + 2]]]
				),
				PackedColorArray([SIDE_COLOR]),
				PackedVector2Array(),
			)
		return
	var width := BEVEL_WIDTH / canvas_scale
	var winding := -1.0 if Geometry2D.is_polygon_clockwise(points) else 1.0
	for index in points.size():
		var start := points[index]
		var end := points[(index + 1) % points.size()]
		var tangent := end - start
		if tangent.length_squared() < 0.01:
			continue
		var outward := Vector2(tangent.y, -tangent.x).normalized() * winding
		var light := outward.dot(LIGHT_DIRECTION)
		var color := LIGHT_COLOR if light >= 0.0 else SHADE_COLOR
		color.a *= 0.35 + absf(light) * 0.65
		var inset := outward * width * 0.5
		draw_line(start - inset, end - inset, color, width, true)
