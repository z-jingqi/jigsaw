extends Button
## A shaped title and a separate vector chevron share an optical ink center.
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Chevron := preload("res://scripts/ui/foundation/ChevronGeometry.gd")
var caption := ""
var _line := TextLine.new()
var _ink := Rect2()
var _native := 1.0
var _shape_key := ""
var _shown := ""
var _text_position := Vector2.ZERO
var _chevron_center := Vector2.ZERO


func _ready() -> void:
	Clean.icon_button(self)
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func configure(title: String, font_size: int, native: float) -> void:
	caption = title
	accessibility_name = title
	_native = native
	var key := str([title, font_size, size, native])
	if key == _shape_key:
		return
	_shape_key = key
	var available := maxf(1, size.x - 30 * native)
	_shown = title
	if Clean.FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		var low := 0
		var high := title.length()
		while low < high:
			var middle := (low + high + 1) / 2
			var candidate := title.left(middle) + "…"
			if (
				Clean.FONT.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				<= available
			):
				low = middle
			else:
				high = middle - 1
		_shown = title.left(low) + "…"
	_line.clear()
	_line.add_string(_shown, Clean.FONT, font_size)
	_ink = _ink_bounds(font_size)
	var group_width := _ink.size.x + 10 * native + 11 * native
	var start := (size.x - group_width) * 0.5
	_text_position = Vector2(start - _ink.position.x, size.y * 0.5 - _ink.get_center().y)
	_chevron_center = Vector2(start + _ink.size.x + 15.5 * native, size.y * 0.5)
	queue_redraw()


func _ink_bounds(font_size: int) -> Rect2:
	var server := TextServerManager.get_primary_interface()
	var pen := 0.0
	var result := Rect2()
	var found := false
	for glyph: Dictionary in server.shaped_text_get_glyphs(_line.get_rid()):
		var rid: RID = glyph.font_rid
		var pixel_size := Vector2i(int(glyph.font_size), 0)
		if rid.is_valid():
			server.font_render_glyph(rid, pixel_size, int(glyph.index))
			var offset := server.font_get_glyph_offset(rid, pixel_size, int(glyph.index))
			var dimensions := server.font_get_glyph_size(rid, pixel_size, int(glyph.index))
			if dimensions.x > 0 and dimensions.y > 0:
				var rect := Rect2(
					Vector2(pen, _line.get_line_ascent()) + (glyph.offset as Vector2) + offset,
					dimensions
				)
				result = result.merge(rect) if found else rect
				found = true
		pen += float(glyph.advance) * int(glyph.repeat)
	return result if found else Rect2(Vector2.ZERO, Vector2(_line.get_size().x, font_size))


func _draw() -> void:
	if caption.is_empty():
		return
	_line.draw(get_canvas_item(), _text_position, Clean.INK)
	draw_polyline(
		Chevron.points(_chevron_center, 6.1 * _native, -PI * 0.5), Clean.INK, 1.6 * _native, true
	)
	if has_focus():
		draw_rect(
			Rect2(Vector2.ONE * _native, size - Vector2.ONE * 2 * _native),
			Clean.MUTED,
			false,
			_native,
			true
		)


func debug_alignment() -> Dictionary:
	return {
		"caption": caption,
		"shown": _shown,
		"text_ink": Rect2(_text_position + _ink.position, _ink.size),
		"icon_center": _chevron_center,
		"hit_rect": get_global_rect(),
	}
