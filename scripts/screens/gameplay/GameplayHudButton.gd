class_name GameplayHudButton
extends ActionButton
## Shared home-style controls with crisp vector icons and existing press feedback.

@export_enum("back", "hint", "left", "up", "down", "right") var symbol := "back"

const Style := preload("res://scripts/screens/gameplay/GameplayStyle.gd")


func _ready() -> void:
	super()
	Style.apply_button(self, symbol == "back")
	if symbol == "hint":
		Style.Clean.button(self, true)
	icon = null
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var ink := Style.Clean.PAPER if symbol == "hint" else Style.INK
	if disabled:
		ink.a = 0.38
	var center := size * 0.5
	var unit := minf(size.x, size.y) / 148.0
	var stroke := maxf(2.0, 7.0 * unit)
	match symbol:
		"hint":
			_draw_hint(center, unit, stroke, ink)
		"back":
			draw_polyline(
				PackedVector2Array(
					[
						center + Vector2(12, -27) * unit,
						center + Vector2(-14, 0) * unit,
						center + Vector2(12, 27) * unit,
					]
				),
				ink,
				stroke,
				true,
			)
		_:
			_draw_direction(center, unit, stroke, ink)


func _draw_direction(center: Vector2, unit: float, stroke: float, ink: Color) -> void:
	var angle := 0.0
	match symbol:
		"left":
			angle = -PI * 0.5
		"down":
			angle = PI
		"right":
			angle = PI * 0.5
	var points := PackedVector2Array()
	for point in [Vector2(-23, -5), Vector2(0, -28), Vector2(23, -5)]:
		points.append(center + point.rotated(angle) * unit)
	draw_polyline(points, ink, stroke, true)
	draw_line(
		center + Vector2(0, -27).rotated(angle) * unit,
		center + Vector2(0, 28).rotated(angle) * unit,
		ink,
		stroke,
		true,
	)


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
