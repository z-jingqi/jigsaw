extends RefCounted
## Shared arrow geometry for every navigation surface.
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")


static func draw_arrow(canvas: Control, direction: float, ink: Color, icon_only := true) -> void:
	var center := canvas.size * 0.5
	var radius := minf(canvas.size.x, canvas.size.y) * 0.21
	var stroke := Metrics.ICON_STROKE * minf(canvas.size.x, canvas.size.y) / Metrics.TOUCH
	if icon_only and canvas.has_focus():
		stroke *= 1.5
	var tip := center + Vector2(radius * direction * (1.0 if icon_only else 0.45), 0)
	var wing := radius * (0.75 if icon_only else 0.9)
	if icon_only:
		canvas.draw_line(center - Vector2(radius * direction, 0), tip, ink, stroke, true)
	canvas.draw_polyline(
		PackedVector2Array(
			[tip + Vector2(-wing * direction, -wing), tip, tip + Vector2(-wing * direction, wing)]
		),
		ink,
		stroke,
		true
	)
