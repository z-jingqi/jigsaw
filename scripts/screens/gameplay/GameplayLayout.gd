extends RefCounted
class_name GameplayLayout

const DESIGN_SIZE := Vector2(1206.0, 2622.0)
const HEADER_TOP := 70.0
const HEADER_HEIGHT := 220.0
const HEADER_CONTROL_SIZE := 148.0
const HEADER_SIDE_MARGIN := 68.0
const HEADER_TITLE_MAX_WIDTH := 700.0
const HEADER_TITLE_MAX_FONT_SIZE := 74
const HEADER_CLOUD_WIDTH := 112.0
const HEADER_CLOUD_GAP := 20.0
const TRAY_HEIGHT := 520.0
const SWAP_ACTION_HEIGHT := 400.0


func apply(
	viewport_size: Vector2,
	hud: Control,
	back_button: Button,
	title_label: Label,
	title_cloud_left: TextureRect,
	title_cloud_right: TextureRect,
	hint_button: Button,
	tray_view: Control,
	swap_action_bar: SwapActionBarView,
	requested_scale := 1.0,
) -> void:
	var scale := _layout_scale(viewport_size) * maxf(1.0, requested_scale)
	var control_size := HEADER_CONTROL_SIZE * scale
	var control_top := HEADER_TOP * scale
	var side_margin := HEADER_SIDE_MARGIN * scale
	hud.offset_left = 0.0
	hud.offset_top = 0.0
	hud.offset_right = 0.0
	hud.offset_bottom = control_top + HEADER_HEIGHT * scale
	_apply_header_control(back_button, Vector2(side_margin, control_top), control_size)
	_apply_header_control(
		hint_button,
		Vector2(viewport_size.x - side_margin - control_size, control_top),
		control_size,
	)
	var title_area_width := minf(
		HEADER_TITLE_MAX_WIDTH * scale,
		maxf(
			1.0,
			hint_button.position.x - back_button.position.x - back_button.size.x - 32.0 * scale,
		),
	)
	_layout_title(
		viewport_size.x,
		control_top,
		control_size,
		title_area_width,
		title_label,
		title_cloud_left,
		title_cloud_right,
		scale,
	)
	_configure_bottom_panel(tray_view, TRAY_HEIGHT * scale)
	_configure_bottom_panel(swap_action_bar, SWAP_ACTION_HEIGHT * scale)
	swap_action_bar.configure_layout(scale)


func _layout_scale(viewport_size: Vector2) -> float:
	return maxf(
		0.5,
		minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y),
	)


func _apply_header_control(button: Button, position: Vector2, size: float) -> void:
	button.position = position
	button.size = Vector2.ONE * size
	button.custom_minimum_size = Vector2.ONE * size


func _layout_title(
	viewport_width: float,
	top: float,
	height: float,
	area_width: float,
	label: Label,
	left_cloud: TextureRect,
	right_cloud: TextureRect,
	scale: float,
) -> void:
	var cloud_width := HEADER_CLOUD_WIDTH * scale
	var cloud_texture_size := left_cloud.texture.get_size()
	var cloud_size := Vector2(
		cloud_width, cloud_width * cloud_texture_size.y / cloud_texture_size.x
	)
	var gap := HEADER_CLOUD_GAP * scale
	var text_limit := maxf(1.0, area_width - 2.0 * (cloud_width + gap))
	var font := label.get_theme_font("font")
	var font_size := roundi(HEADER_TITLE_MAX_FONT_SIZE * scale)
	while (
		font_size > 1
		and (
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x
			> text_limit
		)
	):
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	var text_width := minf(
		text_limit,
		font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x,
	)
	var group_width := text_width + 2.0 * (cloud_width + gap)
	var group_left := (viewport_width - group_width) * 0.5
	var cloud_top := top + (height - cloud_size.y) * 0.5
	left_cloud.position = Vector2(group_left, cloud_top)
	left_cloud.size = cloud_size
	label.position = Vector2(group_left + cloud_width + gap, top)
	label.size = Vector2(text_width, height)
	right_cloud.position = Vector2(label.position.x + text_width + gap, cloud_top)
	right_cloud.size = cloud_size


func _configure_bottom_panel(panel: Control, height: float) -> void:
	panel.offset_left = 0.0
	panel.offset_top = -height
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.custom_minimum_size.y = height
