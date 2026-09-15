class_name GameplayHudButton
extends ActionButton
## Draws the quiet ink icons used by the gameplay header without a button plate.

@export_enum("pause", "hint") var symbol := "pause"

const INK := Color("194F47")


func _ready() -> void:
	super()
	flat = true
	icon = null
	queue_redraw()


func _draw() -> void:
	var ink := INK
	if disabled:
		ink.a = 0.38
	var center := size * 0.5
	var unit := minf(size.x, size.y) / 148.0
	var stroke := maxf(2.0, 7.0 * unit)
	if symbol == "hint":
		_draw_hint(center, unit, stroke, ink)
	else:
		_draw_pause(center, unit, ink)


func _draw_pause(center: Vector2, unit: float, ink: Color) -> void:
	var bar_size := Vector2(15.0, 64.0) * unit
	draw_rect(Rect2(center + Vector2(-28.0, -32.0) * unit, bar_size), ink, true)
	draw_rect(Rect2(center + Vector2(13.0, -32.0) * unit, bar_size), ink, true)


func _draw_hint(center: Vector2, unit: float, stroke: float, ink: Color) -> void:
	var outline := PackedVector2Array()
	outline.append(center + Vector2(-12.0, 26.0) * unit)
	var bulb_center := Vector2(0.0, -7.0)
	for index in 41:
		var angle := lerpf(deg_to_rad(140.0), deg_to_rad(400.0), float(index) / 40.0)
		outline.append(center + (bulb_center + Vector2.from_angle(angle) * 28.0) * unit)
	outline.append(center + Vector2(12.0, 26.0) * unit)
	draw_polyline(outline, ink, stroke, true)
	draw_line(
		center + Vector2(-11.0, 31.0) * unit, center + Vector2(11.0, 31.0) * unit, ink, stroke, true
	)
	draw_line(
		center + Vector2(-7.0, 42.0) * unit, center + Vector2(7.0, 42.0) * unit, ink, stroke, true
	)
