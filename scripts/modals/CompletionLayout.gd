class_name CompletionLayout
extends RefCounted
## Fixed navigation surrounds a scrollable, centered artwork and subject introduction.

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")


func apply(view: Control) -> Rect2:
	var size: Vector2 = view.size
	var unit: float = Clean.canvas_scale(size, view.get_window())
	var safe: Vector4 = Clean.safe_insets(size)
	var width := size.x - safe.x - safe.z
	var margin := 24.0 * unit
	var header_height := 64.0 * unit
	var footer_height := 76.0 * unit
	view.header.position = Vector2(safe.x, safe.y)
	view.header.size = Vector2(width, header_height)
	view.level_label.position = Vector2(64, 8) * unit
	view.level_label.size = Vector2(width - 128 * unit, 48 * unit)
	_fit_title(view.level_label, roundi(26 * unit), roundi(18 * unit))
	view.return_button.position = Vector2(safe.x + 12 * unit, safe.y + 8 * unit)
	view.return_button.size = Vector2.ONE * 48 * unit
	view.return_button.custom_minimum_size = Clean.minimum_touch_size(view.return_button)
	view.confirm_button.position = Vector2(safe.x + margin, size.y - safe.w - footer_height)
	view.confirm_button.size = Vector2(width - margin * 2, 52 * unit)
	view.confirm_button.custom_minimum_size = Clean.minimum_touch_size(view.confirm_button)
	view.confirm_label.add_theme_font_size_override("font_size", roundi(18 * unit))
	view.body.position = Vector2(safe.x + margin, safe.y + header_height)
	view.body.size = Vector2(
		width - margin * 2, size.y - safe.y - safe.w - header_height - footer_height - 12 * unit
	)
	var content_width: float = view.body.size.x
	var font_size := roundi(16 * unit)
	view.description_label.add_theme_font_size_override("font_size", font_size)
	var font: Font = view.description_label.get_theme_font("font")
	var description_size := font.get_multiline_string_size(
		view.description_label.text,
		HORIZONTAL_ALIGNMENT_CENTER,
		content_width - 8 * unit,
		font_size
	)
	var description_height: float = (
		0.0 if view.description_label.text.is_empty() else description_size.y + 8 * unit
	)
	var cat_height := 96.0 * unit if size.y / unit >= 700 else 72.0 * unit
	var gap := 16.0 * unit
	var image_height := minf(
		(content_width - 8 * unit) / 0.75,
		view.body.size.y - description_height - cat_height - gap * 2
	)
	image_height = maxf(minf(160 * unit, view.body.size.y * .44), image_height)
	var source_size: Vector2 = (
		view.image_rect.texture.get_size() if view.image_rect.texture != null else Vector2(3, 4)
	)
	var fit := minf(content_width / source_size.x, image_height / source_size.y)
	var image_size := source_size * fit
	var target := Rect2(Vector2((content_width - image_size.x) * .5, 0), image_size)
	view.description_label.position = Vector2(4 * unit, image_size.y + gap)
	view.description_label.size = Vector2(content_width - 8 * unit, description_height)
	view.cat.position = Vector2(
		(content_width - cat_height) * .5,
		view.description_label.position.y + description_height + gap * .5
	)
	view.cat.size = Vector2.ONE * cat_height
	view.body_content.custom_minimum_size = Vector2(
		content_width, view.cat.position.y + cat_height + 4 * unit
	)
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
