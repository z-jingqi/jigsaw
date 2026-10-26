extends Polygon2D
## Preserve the original face mesh and UVs; soften only its outermost pixel.

const EdgeFeatherScript := preload("res://scripts/gameplay/board/PieceEdgeFeather.gd")

var _edge := EdgeFeatherScript.new()
var _drawn_screen_scale := NAN


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_edge.setup(polygon, uv, texture, color)
	set_notify_transform(true)
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if not is_equal_approx(_screen_scale(), _drawn_screen_scale):
			queue_redraw()


func _screen_scale() -> float:
	return EdgeFeatherScript.pixel_scale(self)


func _draw() -> void:
	_drawn_screen_scale = _screen_scale()
	# Native polygon AA already owns face coverage; do not layer a second fringe.
	if antialiased:
		return
	_edge.draw(self, 1.0 / _drawn_screen_scale)
