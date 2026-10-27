extends Node2D
## A restrained contact shadow measured in display pixels, never baked into art.

const Feather := preload("res://scripts/gameplay/board/PieceEdgeFeather.gd")
const INK := Color(0.20, 0.19, 0.17, 0.13)

var lift := 0.0:
	set(value):
		lift = clampf(value, 0.0, 1.0)
		queue_redraw()
var _points := PackedVector2Array()
var _triangles := PackedInt32Array()
var _edge := Feather.new()
var _drawn_scale := NAN


func setup(points: PackedVector2Array) -> void:
	_points = points
	_triangles = Geometry2D.triangulate_polygon(points)
	_edge.setup(points, PackedVector2Array(), null, INK)
	z_index = -2
	set_notify_transform(true)


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if not is_equal_approx(Feather.pixel_scale(self), _drawn_scale):
			queue_redraw()


func _draw() -> void:
	if _triangles.is_empty():
		return
	_drawn_scale = Feather.pixel_scale(self)
	var offset := Vector2(0.35, 1.1).lerp(Vector2(1.3, 4.0), lift) / _drawn_scale
	var translated := PackedVector2Array()
	for point in _points:
		translated.append(point + offset)
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), _triangles, translated, PackedColorArray([INK])
	)
	_edge.draw(self, lerpf(0.8, 2.5, lift) / _drawn_scale, offset)
