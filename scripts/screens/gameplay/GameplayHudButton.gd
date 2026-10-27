class_name GameplayHudButton
extends ActionButton
## Shared home-style controls with crisp vector icons and existing press feedback.

@export_enum("back", "hint", "left", "up", "down", "right") var symbol := "back"

const Chevron := preload("res://scripts/ui/foundation/ChevronGeometry.gd")
const Style := preload("res://scripts/screens/gameplay/GameplayStyle.gd")


func _ready() -> void:
	super()
	Style.apply_button(self, symbol == "back")
	if symbol == "hint" or symbol == "back":
		Style.Clean.icon_button(self)
	icon = null
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var ink := Style.INK
	if disabled:
		ink = Style.Clean.MUTED
	var center := size * 0.5
	var unit := minf(size.x, size.y) / 148.0
	var stroke := maxf(2.0, 7.0 * unit)
	if has_focus() and symbol in ["back", "hint"]:
		stroke *= 1.35
	match symbol:
		"hint":
			_draw_hint(center, unit, stroke, ink)
		"back":
			draw_polyline(
				PackedVector2Array(
					[
						center + Vector2(0, -24) * unit,
						center + Vector2(-25, 0) * unit,
						center + Vector2(0, 24) * unit,
					]
				),
				ink,
				stroke,
				true,
			)
			draw_line(
				center + Vector2(-25, 0) * unit, center + Vector2(28, 0) * unit, ink, stroke, true
			)
		_:
			_draw_direction(center, unit, stroke, ink)


func _draw_direction(center: Vector2, unit: float, stroke: float, ink: Color) -> void:
	var angle: float = {"left": 0.0, "up": PI * 0.5, "right": PI, "down": -PI * 0.5}.get(
		symbol, 0.0
	)
	draw_polyline(Chevron.points(center, 27 * unit, angle), ink, stroke, true)


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
