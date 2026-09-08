extends RefCounted
## Fits theme titles using the active font metrics instead of character counts.


static func fit(label: Label, bounds: Vector2, max_size: int, min_size: int) -> int:
	var font := label.get_theme_font("font")
	var safe_width := maxf(1.0, bounds.x)
	var safe_height := maxf(1.0, bounds.y)
	# A previous short title can leave the Label in single-line mode. Reset that
	# intrinsic minimum before applying the new title's fixed layout bounds.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.clip_text = true
	label.update_minimum_size()
	label.size = Vector2(safe_width, safe_height)
	for font_size in range(max_size, min_size - 1, -1):
		var single_line := font.get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size
		)
		if single_line.x <= safe_width and single_line.y <= safe_height:
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.max_lines_visible = 1
			label.add_theme_font_size_override("font_size", font_size)
			label.update_minimum_size()
			label.size = Vector2(safe_width, safe_height)
			return font_size
	for font_size in range(max_size, min_size - 1, -1):
		if _fits_two_lines(label.text, font, font_size, safe_width, safe_height):
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.max_lines_visible = 2
			label.add_theme_font_size_override("font_size", font_size)
			label.update_minimum_size()
			label.size = Vector2(safe_width, safe_height)
			return font_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Keep every line visible if an exceptional title cannot fit the supported range.
	label.max_lines_visible = -1
	label.clip_text = false
	label.add_theme_font_size_override("font_size", min_size)
	label.update_minimum_size()
	label.size = Vector2(safe_width, safe_height)
	return min_size


static func _fits_two_lines(
	text: String, font: Font, font_size: int, max_width: float, max_height: float
) -> bool:
	var paragraph := TextParagraph.new()
	paragraph.width = max_width
	paragraph.alignment = HORIZONTAL_ALIGNMENT_CENTER
	paragraph.break_flags = (
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	)
	paragraph.add_string(text, font, font_size)
	var line_count := paragraph.get_line_count()
	if line_count < 1 or line_count > 2 or paragraph.get_size().y > max_height:
		return false
	var full_range := paragraph.get_range()
	var final_line_range := paragraph.get_line_range(line_count - 1)
	return final_line_range.y == full_range.y
