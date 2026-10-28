extends RefCounted
class_name GameplayLayout

const PuzzleRulesScript := preload("res://scripts/config/PuzzleRules.gd")
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const TitleLayout := preload("res://scripts/screens/home/ThemeTitleLayout.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")

var _layout_config: Dictionary = PuzzleRulesScript.gameplay_layout()
var _header_config: Dictionary = _layout_config["header"]
var _tray_config: Dictionary = _layout_config["tray"]


func apply(
	viewport_size: Vector2,
	hud: Control,
	header_buttons: Array[Button],
	title_label: Label,
	title_cloud_left: TextureRect,
	title_cloud_right: TextureRect,
	tray_view: Control,
	swap_action_bar: SwapActionBarView,
	requested_scale := 1.0,
) -> void:
	var safe := Clean.safe_insets(viewport_size)
	var back_button := header_buttons[0]
	var hint_button := header_buttons[1]
	var scale := _layout_scale(viewport_size) * maxf(1.0, requested_scale)
	var control_size := Buttons.icon_size(viewport_size).x
	var ui_unit := Metrics.unit(viewport_size)
	var title_height := Metrics.TOUCH * ui_unit
	var control_top := Metrics.TOP * ui_unit + safe.y
	var side_margin := Metrics.EDGE * ui_unit
	hud.offset_left = 0.0
	hud.offset_top = 0.0
	hud.offset_right = 0.0
	hud.offset_bottom = control_top + float(_header_config["height"]) * scale
	_apply_header_control(
		back_button,
		Buttons.navigation_position(viewport_size) + Vector2(safe.x, safe.y),
		control_size,
	)
	_apply_header_control(
		hint_button,
		Buttons.navigation_position(viewport_size, true) + Vector2(-safe.z, safe.y),
		control_size,
	)
	var center := viewport_size.x * 0.5
	var title_gap := Metrics.SMALL_GAP * ui_unit
	var title_area_width := minf(
		float(_header_config["title_max_width"]) * scale,
		maxf(
			1.0,
			(
				2.0
				* minf(
					center - back_button.position.x - back_button.size.x - title_gap,
					hint_button.position.x - title_gap - center,
				)
			),
		),
	)
	var title_top := Buttons.header_center_y(viewport_size) - title_height * 0.5 + safe.y
	var ornaments_width := 0.0
	var minimum_font := roundi(Metrics.BODY * ui_unit)
	if (
		(
			title_label
			. get_theme_font("font")
			. get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, minimum_font)
			. x
		)
		> title_area_width - ornaments_width * scale
	):
		# Long names use the full-width title row rather than colliding with actions.
		title_top = control_top + title_height + Metrics.SMALL_GAP * ui_unit
		title_area_width = viewport_size.x - side_margin * 2.0
	_layout_title(
		viewport_size.x,
		title_top,
		title_height,
		title_area_width,
		title_label,
		title_cloud_left,
		title_cloud_right,
		ui_unit,
	)
	hud.offset_bottom = maxf(
		hud.offset_bottom, title_top + title_height + board_gap(viewport_size, requested_scale)
	)
	var bottom := float(_layout_config["bottom_margin"]) * scale
	# Preserve the upper edge and use the previously empty bottom margin for pieces.
	_configure_bottom_panel(
		tray_view, float(_tray_config["height"]) * scale + bottom, safe.w, side_margin
	)
	_configure_bottom_panel(
		swap_action_bar, float(_layout_config["swap_action_height"]) * scale, bottom + safe.w, 0.0
	)
	swap_action_bar.configure_layout(scale)


func board_gap(viewport_size: Vector2, requested_scale := 1.0) -> float:
	return (
		float(_layout_config["board_gap"])
		* _layout_scale(viewport_size)
		* maxf(1.0, requested_scale)
	)


func _layout_scale(viewport_size: Vector2) -> float:
	return PuzzleRulesScript.gameplay_scale(viewport_size)


func _apply_header_control(button: Button, position: Vector2, size: float) -> void:
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.position = position
	Buttons.apply_size(button, Vector2.ONE * size)


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
	# Retain the nodes for scene compatibility; remove ornamental title clutter.
	left_cloud.visible = false
	right_cloud.visible = false
	label.position = Vector2((viewport_width - area_width) * 0.5, top)
	TitleLayout.fit(label, Vector2(area_width, height), roundi(Metrics.TITLE * scale))


func _configure_bottom_panel(panel: Control, height: float, bottom: float, margin: float) -> void:
	panel.offset_left = margin
	panel.offset_top = -height - bottom
	panel.offset_right = -margin
	panel.offset_bottom = -bottom
	panel.custom_minimum_size.y = height
