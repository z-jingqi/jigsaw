class_name CompletionLayout
extends RefCounted

const NavigationControlMetricsScript := preload(
	"res://scripts/ui/foundation/NavigationControlMetrics.gd"
)
const DESIGN_SIZE := Vector2(1206.0, 2622.0)

var _base_card_style: StyleBoxFlat


func apply_header(
	viewport_size: Vector2,
	header: Control,
	back_button: Button,
	level_label: Label,
) -> void:
	var scale := _scale_for(viewport_size)
	var origin_x := _origin_x(viewport_size, scale)
	var extra_height := _extra_height(viewport_size, scale)

	header.position = Vector2(origin_x, _y(54.0, scale, extra_height))
	header.size = Vector2(DESIGN_SIZE.x * scale, 220.0 * scale)
	back_button.position = Vector2(68.0, 16.0) * scale
	back_button.size = Vector2.ONE * NavigationControlMetricsScript.BACK_BUTTON_SIZE * scale
	back_button.custom_minimum_size = back_button.size
	level_label.position = Vector2(246.0, 16.0) * scale
	level_label.size = Vector2(714.0, 148.0) * scale
	_fit_single_line(level_label, 68, 38, scale)


func apply_card(
	viewport_size: Vector2,
	card_stage: Control,
	card_frame: Panel,
	image_rect: TextureRect,
	completion_paw: TextureRect,
) -> void:
	var scale := _scale_for(viewport_size)
	var origin_x := _origin_x(viewport_size, scale)
	var extra_height := _extra_height(viewport_size, scale)
	var card_size := Vector2(976.0, 1301.0) * scale

	card_stage.position = Vector2(origin_x + 115.0 * scale, _y(388.0, scale, extra_height))
	card_stage.size = card_size
	card_stage.pivot_offset = card_size * 0.5
	_apply_card_style(card_frame, scale)
	var inset := 8.0 * scale
	image_rect.position = Vector2.ONE * inset
	image_rect.size = card_size - Vector2.ONE * inset * 2.0
	var shader_material := image_rect.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("rect_aspect", image_rect.size.x / image_rect.size.y)
		shader_material.set_shader_parameter("rect_size", image_rect.size)
		shader_material.set_shader_parameter("corner_radius", 0.032 * scale)
	var paw_size := Vector2(160.0, 149.0) * scale
	completion_paw.size = paw_size
	completion_paw.pivot_offset = paw_size * 0.5
	completion_paw.rotation_degrees = 30.0
	completion_paw.position = Vector2(card_size.x - 148.0 * scale, -30.0 * scale)


func apply_footer(
	viewport_size: Vector2,
	celebration: Control,
	left_leaf: TextureRect,
	completion_title: Label,
	right_leaf: TextureRect,
	mode_row: HBoxContainer,
	confirm_button: Button,
	confirm_label: Label,
) -> void:
	var scale := _scale_for(viewport_size)
	var origin_x := _origin_x(viewport_size, scale)
	var extra_height := _extra_height(viewport_size, scale)

	celebration.position = Vector2(origin_x + 128.0 * scale, _y(1756.0, scale, extra_height))
	celebration.size = Vector2(950.0, 144.0) * scale
	_apply_completion_title(celebration, left_leaf, completion_title, right_leaf, scale)

	mode_row.position = Vector2(origin_x + 303.0 * scale, _y(1910.0, scale, extra_height))
	mode_row.size = Vector2(600.0, 170.0)
	mode_row.scale = Vector2.ONE * scale
	mode_row.add_theme_constant_override("separation", 30)

	var button_size := Vector2(600.0, 185.0) * scale
	confirm_button.position = Vector2(
		origin_x + (DESIGN_SIZE.x * scale - button_size.x) * 0.5,
		_y(2184.0, scale, extra_height),
	)
	confirm_button.size = button_size
	confirm_button.custom_minimum_size = button_size
	confirm_button.pivot_offset = button_size * 0.5
	confirm_label.add_theme_font_size_override("font_size", roundi(58.0 * scale))


func _scale_for(viewport_size: Vector2) -> float:
	return maxf(0.45, minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y))


func _origin_x(viewport_size: Vector2, scale: float) -> float:
	return (viewport_size.x - DESIGN_SIZE.x * scale) * 0.5


func _extra_height(viewport_size: Vector2, scale: float) -> float:
	return maxf(0.0, viewport_size.y - DESIGN_SIZE.y * scale)


func _y(design_y: float, scale: float, extra_height: float) -> float:
	return design_y * scale + extra_height * (design_y / DESIGN_SIZE.y)


func _apply_card_style(panel: Panel, scale: float) -> void:
	if _base_card_style == null:
		_base_card_style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var style := _base_card_style.duplicate() as StyleBoxFlat
	var border := maxi(2, roundi(5.0 * scale))
	style.set_border_width_all(border)
	var radius := maxi(14, roundi(34.0 * scale))
	style.set_corner_radius_all(radius)
	style.shadow_size = maxi(5, roundi(12.0 * scale))
	style.shadow_offset = Vector2(-4.0, 12.0) * scale
	panel.add_theme_stylebox_override("panel", style)


func _apply_completion_title(
	container: Control,
	left_leaf: TextureRect,
	label: Label,
	right_leaf: TextureRect,
	scale: float,
) -> void:
	var container_width := container.size.x
	var leaf_size := Vector2(160.0, 91.0) * scale
	var gap := 26.0 * scale
	var font := label.get_theme_font("font")
	var font_size := roundi(88.0 * scale)
	var minimum_size := roundi(50.0 * scale)
	var max_text_width := maxf(1.0, container_width - (leaf_size.x + gap) * 2.0)
	while (
		font_size > minimum_size
		and (
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x
			> max_text_width
		)
	):
		font_size -= 2
	var text_width := minf(
		max_text_width,
		(
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x
			+ 24.0 * scale
		),
	)
	var total_width := leaf_size.x * 2.0 + gap * 2.0 + text_width
	var start_x := (container_width - total_width) * 0.5
	var leaf_y := (container.size.y - leaf_size.y) * 0.5
	left_leaf.position = Vector2(start_x, leaf_y)
	left_leaf.size = leaf_size
	label.position = Vector2(start_x + leaf_size.x + gap, 0.0)
	label.size = Vector2(text_width, container.size.y)
	label.add_theme_font_size_override("font_size", font_size)
	right_leaf.position = Vector2(label.position.x + text_width + gap, leaf_y)
	right_leaf.size = leaf_size


func _fit_single_line(label: Label, maximum: int, minimum: int, scale: float) -> void:
	var font := label.get_theme_font("font")
	var font_size := roundi(maximum * scale)
	var minimum_size := roundi(minimum * scale)
	while (
		font_size > minimum_size
		and (
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x
			> label.size.x
		)
	):
		font_size -= 2
	label.add_theme_font_size_override("font_size", font_size)
