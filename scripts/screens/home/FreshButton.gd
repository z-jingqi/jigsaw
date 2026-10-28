extends Button
## Shared flat controls; vector strokes stay sharp at every display scale.
@export_enum("none", "back", "forward", "grid", "settings", "undo", "close", "album", "more")
var symbol := "none"
@export var primary := false
@export var icon_only := false
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const INK := Clean.INK


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	if accessibility_name.is_empty():
		accessibility_name = text
	if icon_only:
		Clean.icon_button(self)
	else:
		Clean.button(self, primary)
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	if symbol.is_empty():
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.21
	var w := Metrics.ICON_STROKE * minf(size.x, size.y) / Metrics.TOUCH
	if icon_only and has_focus():
		w *= 1.5
	var ink := Clean.MUTED if disabled else (Clean.PAPER if primary else INK)
	match symbol:
		"back", "forward":
			preload("res://scripts/ui/foundation/NavigationGlyph.gd").draw_arrow(
				self, -1.0 if symbol == "back" else 1.0, ink, icon_only
			)
		"more":
			for offset in [-0.8, 0.0, 0.8]:
				draw_circle(c + Vector2(offset * r, 0), w * 0.9, ink, true, -1.0, true)
		"close":
			draw_line(c - Vector2.ONE * r, c + Vector2.ONE * r, ink, w, true)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), ink, w, true)
		"grid":
			for x in [-1, 1]:
				for y in [-1, 1]:
					var center := c + Vector2(x, y) * r * 0.65
					draw_rect(
						Rect2(center - Vector2.ONE * r * 0.4, Vector2.ONE * r * 0.8),
						ink,
						false,
						w,
						true
					)
		"album":
			draw_rect(Rect2(c - Vector2.ONE * r, Vector2.ONE * r * 2.0), ink, false, w, true)
			draw_polyline(
				PackedVector2Array(
					[
						c + Vector2(-0.8, 0.65) * r,
						c + Vector2(-0.2, -0.1) * r,
						c + Vector2(0.2, 0.3) * r,
						c + Vector2(0.6, -0.25) * r,
						c + Vector2(0.9, 0.2) * r,
					]
				),
				ink,
				w,
				true
			)
			draw_circle(c + Vector2(-0.4, -0.5) * r, r * 0.13, ink)
		"undo":
			draw_arc(c, r, -PI * 0.85, PI * 0.75, 32, ink, w, true)
			var tip := c + Vector2.from_angle(-PI * 0.85) * r
			draw_polyline(
				PackedVector2Array([tip + Vector2(0, -r * 0.65), tip, tip + Vector2(r * 0.65, 0)]),
				ink,
				w,
				true
			)
		"settings":
			for i in 3:
				var y := c.y + float(i - 1) * r * 0.75
				draw_line(Vector2(c.x - r, y), Vector2(c.x + r, y), ink, w, true)
				var knob := Vector2(c.x + (-0.35 if i % 2 == 0 else 0.35) * r, y)
				draw_circle(knob, r * 0.22, Clean.PAPER)
				draw_circle(knob, r * 0.22, ink, false, w, true)
