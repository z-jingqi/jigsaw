class_name CompletionLayout
extends RefCounted
## Fits the completed image with the same quiet spacing and palette as gameplay.


func image_target(viewport_size: Vector2, texture: Texture2D, source: Rect2) -> Rect2:
	var area := Rect2(viewport_size * Vector2(0.1, 0.16), viewport_size * Vector2(0.8, 0.62))
	var dimensions := texture.get_size() if texture != null else Vector2(3, 4)
	var fit := minf(area.size.x / dimensions.x, area.size.y / dimensions.y)
	if source.has_area():
		fit = minf(fit, source.size.x * 0.88 / dimensions.x)
	var image_size := dimensions * fit
	return Rect2(area.get_center() - image_size * 0.5, image_size)


func apply_header(viewport_size: Vector2, header: Control, level_label: Label) -> void:
	var scale := minf(viewport_size.x / 1206.0, viewport_size.y / 2680.0)
	header.position = Vector2.ZERO
	header.size = Vector2(viewport_size.x, 250.0 * scale)
	level_label.position = Vector2(viewport_size.x * 0.1, 90 * scale)
	level_label.size = Vector2(viewport_size.x * 0.8, 144 * scale)
	_fit_label(level_label, roundi(78 * scale))


func apply_footer(
	viewport_size: Vector2, confirm: Button, confirm_label: Label, back: Button, back_label: Label
) -> void:
	var scale := minf(viewport_size.x / 1206.0, viewport_size.y / 2680.0)
	var button_size := Vector2(viewport_size.x * 0.34, maxf(48.0, 164 * scale))
	for button in [confirm, back]:
		button.size = button_size
		button.custom_minimum_size = button_size
		button.pivot_offset = button_size * 0.5
	back.position = Vector2(viewport_size.x * 0.14, viewport_size.y - 220 * scale)
	confirm.position = Vector2(viewport_size.x * 0.52, back.position.y)
	for label in [confirm_label, back_label]:
		label.add_theme_font_size_override("font_size", maxi(18, roundi(52 * scale)))


func apply_description(
	viewport_size: Vector2, label: Label, image: Rect2, footer_top: float
) -> void:
	var scale := minf(viewport_size.x / 1206.0, viewport_size.y / 2680.0)
	var width := viewport_size.x * 0.76
	label.add_theme_font_size_override("font_size", maxi(14, roundi(34.0 * scale)))
	label.position = Vector2((viewport_size.x - width) * 0.5, image.end.y + 36.0 * scale)
	label.size = Vector2(width, maxf(0.0, footer_top - label.position.y - 40.0 * scale))


func _fit_label(label: Label, maximum: int) -> void:
	var font := label.get_theme_font("font")
	var font_size := maxi(12, maximum)
	while (
		font_size > 12
		and (
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			> label.size.x
		)
	):
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
