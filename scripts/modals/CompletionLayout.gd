class_name CompletionLayout
extends RefCounted
## Fixed navigation surrounds a single-screen editorial artwork and subject introduction.

const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")


func apply(view: Control) -> Rect2:
	var size: Vector2 = view.size
	var unit: float = Metrics.unit(size)
	var safe: Vector4 = Clean.safe_insets(size)
	var width := size.x - safe.x - safe.z
	var margin := 24.0 * unit
	var compact := size.y / unit < 700
	var header_height := (124.0 if compact else 80.0) * unit
	var footer_height := 76.0 * unit
	view.header.position = Vector2(safe.x, safe.y)
	view.header.size = Vector2(width, header_height)
	view.level_label.position = (
		Vector2(Metrics.EDGE + Metrics.TOUCH + Metrics.SMALL_GAP, Metrics.TOP) * unit
	)
	view.level_label.clip_text = true
	view.level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	view.level_label.size = Vector2(
		width - (Metrics.EDGE + Metrics.TOUCH + Metrics.SMALL_GAP) * unit - margin, 48 * unit
	)
	view.level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fit_title(view.level_label, roundi(Metrics.TITLE * unit), roundi(Metrics.BODY * unit))
	view.return_button.position = Vector2(safe.x + Metrics.EDGE * unit, safe.y + Metrics.TOP * unit)
	view.return_button.size = Vector2.ONE * 48 * unit
	view.return_button.custom_minimum_size = Clean.minimum_touch_size(view.return_button)
	view.confirm_button.position = Vector2(safe.x + margin, size.y - safe.w - footer_height)
	view.confirm_button.size = Vector2(width - margin * 2, 52 * unit)
	view.confirm_button.custom_minimum_size = Clean.minimum_touch_size(view.confirm_button)
	view.confirm_label.add_theme_font_size_override("font_size", roundi(Metrics.BODY * unit))
	# Release the previous content minimum before resizing its scroll container.
	view.body_content.custom_minimum_size = Vector2.ZERO
	view.body.position = Vector2(safe.x + margin, safe.y + header_height)
	view.body.size = Vector2(
		width - margin * 2, size.y - safe.y - safe.w - header_height - footer_height - 12 * unit
	)
	var content_width: float = view.body.size.x
	var font_size := roundi(Metrics.BODY * unit)
	view.description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	view.description_label.add_theme_font_size_override("font_size", font_size)
	var cat_side := 56 * unit if compact else clampf(content_width * .25, 64 * unit, 96 * unit)
	var gap := 16.0 * unit
	var text_width := content_width if compact else content_width - cat_side - gap
	var font: Font = view.description_label.get_theme_font("font")
	# Every locale reserves the same largest translated paragraph, not just the active text.
	var description_height := 0.0
	for text in view.description_variants:
		if not text.is_empty():
			var measured := font.get_multiline_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size
			)
			description_height = maxf(description_height, measured.y + 8 * unit)
	var row_height := description_height if compact else maxf(description_height, cat_side)
	# Reserve readable copy first; the unchanged artwork contains in the remaining space.
	var image_height := maxf(0, view.body.size.y - row_height - gap - 8 * unit)
	var source_size: Vector2 = (
		view.image_rect.texture.get_size() if view.image_rect.texture != null else Vector2(3, 4)
	)
	var fit := minf(content_width / source_size.x, image_height / source_size.y)
	var image_size := source_size * fit
	var target := Rect2(Vector2((content_width - image_size.x) * 0.5, 0), image_size)
	var row_y := image_size.y + gap
	view.description_label.position = Vector2(0, row_y)
	view.description_label.size = Vector2(text_width, description_height)
	view.cat.position = (
		Vector2(safe.x + width - margin - cat_side, safe.y + 60 * unit)
		if compact
		else view.body.position + Vector2(content_width - cat_side, row_y)
	)
	view.cat.size = Vector2.ONE * cat_side
	view.body_content.custom_minimum_size = Vector2(content_width, row_y + row_height + 8 * unit)
	view.body_content.size = view.body_content.custom_minimum_size
	return target


func _fit_title(label: Label, maximum: int, minimum: int) -> void:
	var font := label.get_theme_font("font")
	var font_size := maximum
	while (
		font_size > minimum
		and (
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			> label.size.x
		)
	):
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
