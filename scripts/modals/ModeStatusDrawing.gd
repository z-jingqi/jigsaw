extends Control
## Animated strokes use the same 96-unit geometry as the approved SVGs.

const CLOCK := preload("res://assets/ui/levels/mode-state-clock.svg")
const COMPLETED := preload("res://assets/ui/levels/mode-state-completed.svg")

var status := &"not_started"
var progress := 1.0
var icon_rect := Rect2()


func _draw() -> void:
	var badge_size := Vector2.ONE * size.x * 0.27
	paint(self, Rect2(icon_rect.end - badge_size * 0.72, badge_size), status, progress)


static func paint(canvas: CanvasItem, rect: Rect2, status: StringName, progress: float) -> void:
	if status not in [&"in_progress", &"completed"]:
		return
	if progress >= 1.0:
		canvas.draw_texture_rect(CLOCK if status == &"in_progress" else COMPLETED, rect, false)
		return
	var unit := rect.size.x / 96.0
	var center := rect.position + rect.size * 0.5
	var ink := Color("C58222") if status == &"in_progress" else Color("268573")
	canvas.draw_circle(center, 44 * unit, Color("FAF8EF"), true, -1, true)
	canvas.draw_arc(center, 39 * unit, 0, TAU, 64, ink, 6 * unit, true)
	if status == &"in_progress":
		var angle := -TAU * (1.0 - progress)
		var points := PackedVector2Array(
			[
				center + Vector2(0, -23).rotated(angle) * unit,
				center,
				center + Vector2(17, 9).rotated(angle) * unit,
			]
		)
		_stroke(canvas, points, ink, 6 * unit)
	else:
		var a := center + Vector2(-20, 0) * unit
		var b := center + Vector2(-6, 14) * unit
		var c := center + Vector2(20, -14) * unit
		var first := a.distance_to(b)
		var length := progress * (first + b.distance_to(c))
		if length <= 0:
			return
		var points := PackedVector2Array([a])
		if length <= first:
			points.append(a.lerp(b, length / first))
		else:
			points.append(b)
			points.append(b.lerp(c, (length - first) / b.distance_to(c)))
		_stroke(canvas, points, ink, 7 * unit)


static func _stroke(
	canvas: CanvasItem, points: PackedVector2Array, ink: Color, width: float
) -> void:
	canvas.draw_polyline(points, ink, width, true)
	for point in points:
		canvas.draw_circle(point, width * 0.5, ink, true, -1, true)
