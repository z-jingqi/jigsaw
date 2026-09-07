extends RefCounted
class_name GameplayLayout

const DESIGN_SIZE := Vector2(1206.0, 2622.0)
const HEADER_TOP := 70.0
const HEADER_HEIGHT := 220.0
const HEADER_CONTROL_SIZE := 148.0
const HEADER_SIDE_MARGIN := 68.0
const HEADER_TITLE_MAX_WIDTH := 700.0
const HEADER_TITLE_MAX_FONT_SIZE := 74
const HEADER_TITLE_MIN_FONT_SIZE := 38
const TRAY_HEIGHT := 520.0
const SWAP_ACTION_HEIGHT := 400.0


func apply(
	viewport_size: Vector2,
	hud: Control,
	back_shadow: TextureRect,
	back_button: Button,
	title_label: Label,
	hint_shadow: TextureRect,
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
	_apply_header_shadow(back_shadow, back_button.position, control_size, scale)
	_apply_header_control(
		hint_button,
		Vector2(viewport_size.x - side_margin - control_size, control_top),
		control_size,
	)
	_apply_header_shadow(hint_shadow, hint_button.position, control_size, scale)
	var title_width := minf(
		HEADER_TITLE_MAX_WIDTH * scale,
		maxf(
			1.0,
			hint_button.position.x - back_button.position.x - back_button.size.x - 32.0 * scale,
		),
	)
	title_label.position = Vector2((viewport_size.x - title_width) * 0.5, control_top)
	title_label.size = Vector2(title_width, control_size)
	_fit_title(title_label, title_width, scale)
	_configure_bottom_panel(tray_view, TRAY_HEIGHT * scale)
	_configure_bottom_panel(swap_action_bar, SWAP_ACTION_HEIGHT * scale)
	swap_action_bar.configure_layout(scale)


func apply_reference(viewport_size: Vector2, hud: Control, button: Button, unit: float) -> void:
	button.custom_minimum_size = Vector2(280.0, 104.0) * unit
	button.size = button.custom_minimum_size
	button.position = Vector2((viewport_size.x - button.size.x) * 0.5, 226.0 * unit)
	button.add_theme_font_size_override("font_size", roundi(36.0 * unit))
	hud.offset_bottom = maxf(hud.offset_bottom, button.position.y + button.size.y + 24.0 * unit)


func _layout_scale(viewport_size: Vector2) -> float:
	return maxf(
		0.5,
		minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y),
	)


func _apply_header_control(button: Button, position: Vector2, size: float) -> void:
	button.position = position
	button.size = Vector2.ONE * size
	button.custom_minimum_size = Vector2.ONE * size


func _apply_header_shadow(
	shadow: TextureRect, control_position: Vector2, control_size: float, scale: float
) -> void:
	shadow.position = control_position + Vector2(7.0, 10.0) * scale
	shadow.size = Vector2.ONE * control_size


func _fit_title(label: Label, width: float, scale: float) -> void:
	var font := label.get_theme_font("font")
	var font_size := roundi(HEADER_TITLE_MAX_FONT_SIZE * scale)
	var minimum_size := roundi(HEADER_TITLE_MIN_FONT_SIZE * scale)
	while (
		font_size > minimum_size
		and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width
	):
		font_size -= 2
	label.add_theme_font_size_override("font_size", font_size)


func _configure_bottom_panel(panel: Control, height: float) -> void:
	panel.offset_left = 0.0
	panel.offset_top = -height
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.custom_minimum_size.y = height
