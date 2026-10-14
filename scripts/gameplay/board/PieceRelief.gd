extends Node2D
## Shared edge treatment; the source polygon and UVs remain unchanged.

const SIDE_COLOR := Color("#795235")
const DEPTH := Vector2(1.2, 3.8)
const SEAM_HALF_WIDTH_PIXELS := 0.65
const EdgeFeatherScript := preload("res://scripts/gameplay/board/PieceEdgeFeather.gd")

var points := PackedVector2Array()
var surface := false
var seam_color := Color(0.0, 0.0, 0.0, 0.22)
var triangles := PackedInt32Array()
var _drawn_canvas_scale := NAN
var _edge := EdgeFeatherScript.new()


func setup(polygon: PackedVector2Array, draw_surface: bool, color := Color(0, 0, 0, 0.22)) -> void:
	points = polygon
	surface = draw_surface
	seam_color = color
	seam_color.a = minf(seam_color.a, 0.26)
	triangles = Geometry2D.triangulate_polygon(points) if not surface else PackedInt32Array()
	if not surface:
		_edge.setup(points, PackedVector2Array(), null, SIDE_COLOR)
	z_index = 2 if surface else -1
	set_notify_transform(true)
	queue_redraw()


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		# Translation and rotation reuse the same drawing commands. Only scale
		# changes the screen-space edge width and depth used by this visual.
		if not is_equal_approx(_canvas_scale(), _drawn_canvas_scale):
			queue_redraw()


func _canvas_scale() -> float:
	return EdgeFeatherScript.pixel_scale(self)


func _draw() -> void:
	if points.size() < 3:
		return
	# Measure in display pixels, including window stretch, for every game mode.
	var canvas_scale := _canvas_scale()
	_drawn_canvas_scale = canvas_scale
	if not surface:
		var side := PackedVector2Array()
		for point in points:
			side.append(point + DEPTH / canvas_scale)
		# Translating a concave outline can make near-collinear knob edges fail
		# triangulation at some viewport scales. Reuse the source triangulation.
		if not triangles.is_empty():
			RenderingServer.canvas_item_add_triangle_array(
				get_canvas_item(), triangles, side, PackedColorArray([SIDE_COLOR])
			)
			_edge.draw(self, 1.0 / EdgeFeatherScript.pixel_scale(self), DEPTH / canvas_scale)
		return
	# Each face owns half the seam inside its outline. A neighboring piece
	# cannot hide it or expose a thick side depending on draw order.
	var width := SEAM_HALF_WIDTH_PIXELS / canvas_scale
	var outlines := Geometry2D.offset_polygon(points, -width * 0.5, Geometry2D.JOIN_ROUND)
	for outline in outlines:
		if outline.size() < 3:
			continue
		outline.append(outline[0])
		draw_polyline(outline, seam_color, width, true)
