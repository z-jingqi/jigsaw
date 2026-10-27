extends RefCounted
## Shrink before truncating, with a shared readable floor and optional wrapping.
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")


static func fit(label: Label, bounds: Vector2, max_size: int, lines := 1) -> int:
	var font := label.get_theme_font("font")
	var area := bounds.max(Vector2.ONE)
	var minimum := mini(
		max_size, maxi(1, roundi(Metrics.CAPTION * Metrics.unit(label.get_viewport_rect().size)))
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if lines > 1 else TextServer.AUTOWRAP_OFF
	label.max_lines_visible = lines
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = label.text
	var chosen := minimum
	for font_size in range(max_size, minimum - 1, -1):
		var measured := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		if lines > 1:
			measured = font.get_multiline_string_size(
				label.text, HORIZONTAL_ALIGNMENT_CENTER, area.x, font_size
			)
		if measured.x <= area.x and measured.y <= minf(area.y, font.get_height(font_size) * lines):
			chosen = font_size
			break
	label.add_theme_font_size_override("font_size", chosen)
	label.update_minimum_size()
	label.size = area
	return chosen
