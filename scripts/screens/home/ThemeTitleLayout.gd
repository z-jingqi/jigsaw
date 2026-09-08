extends RefCounted
## Fits complete single-line theme titles using active font metrics.


static func fit(label: Label, bounds: Vector2, max_size: int) -> int:
	var font := label.get_theme_font("font")
	var safe_width := maxf(1.0, bounds.x)
	var safe_height := maxf(1.0, bounds.y)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = 1
	label.clip_text = true
	label.update_minimum_size()
	label.size = Vector2(safe_width, safe_height)
	for font_size in range(max_size, 0, -1):
		var single_line := font.get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size
		)
		if single_line.x <= safe_width and single_line.y <= safe_height:
			label.add_theme_font_size_override("font_size", font_size)
			label.update_minimum_size()
			label.size = Vector2(safe_width, safe_height)
			return font_size
	# Font sizes below one pixel are unsupported. Preserve exceptional text
	# instead of silently clipping it if even the smallest size cannot fit.
	label.clip_text = false
	label.add_theme_font_size_override("font_size", 1)
	label.update_minimum_size()
	label.size = Vector2(safe_width, safe_height)
	return 1
