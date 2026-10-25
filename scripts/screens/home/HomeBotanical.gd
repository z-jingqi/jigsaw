extends Control
## A small original ink-and-sage sprig, drawn at the current display scale.
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var u := size / Vector2(43, 54)
	var stem := PackedVector2Array(
		[
			Vector2(13, 49) * u,
			Vector2(20, 35) * u,
			Vector2(23, 22) * u,
			Vector2(31, 8) * u,
		]
	)
	draw_polyline(stem, Clean.INK, maxf(1.0, 1.1 * u.x), true)
	_leaf(Vector2(22, 28) * u, Vector2(8, 15) * u, u)
	_leaf(Vector2(20, 35) * u, Vector2(36, 27) * u, u)
	_leaf(Vector2(28, 14) * u, Vector2(25, 2) * u, u)
	_leaf(Vector2(16, 43) * u, Vector2(5, 33) * u, u)


func _leaf(base: Vector2, tip: Vector2, unit: Vector2) -> void:
	var middle := (base + tip) * 0.5
	var cross := (tip - base).normalized().orthogonal() * 4.0 * unit
	var points := PackedVector2Array([base, middle + cross, tip, middle - cross])
	draw_colored_polygon(points, Clean.SAGE.darkened(0.16))
	points.append(base)
	draw_polyline(points, Clean.INK, maxf(1.0, unit.x * 0.8), true)
