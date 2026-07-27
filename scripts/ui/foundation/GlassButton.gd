class_name GlassButton
extends ActionButton

## A warm, translucent action surface for the homepage's persistent actions.
##
## The material is intentionally drawn in code instead of relying on baked UI
## images: it keeps the reflection, edge light and hit area crisp at every
## viewport size while the underlying cover supplies the colour variation.

enum VisualKind { ICON, PILL }

const WARM_TEXT := Color("#8A4E2C")

@export var visual_kind: VisualKind = VisualKind.PILL
@export var icon_texture: Texture2D
@export_range(0.1, 0.8, 0.01) var icon_scale := 0.58


func _ready() -> void:
	super._ready()
	flat = false
	focus_mode = Control.FOCUS_NONE
	add_theme_color_override("font_color", WARM_TEXT)
	add_theme_color_override("font_hover_color", WARM_TEXT)
	add_theme_color_override("font_pressed_color", WARM_TEXT.darkened(0.12))
	add_theme_color_override("font_disabled_color", WARM_TEXT.lightened(0.32))
	resized.connect(_refresh_surface)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	_refresh_surface()


func _refresh_surface() -> void:
	var radius := minf(size.x, size.y) * 0.5
	add_theme_stylebox_override(
		"normal", _surface_style(Color(1.0, 0.955, 0.865, 0.86), radius, 0.96, 0.34)
	)
	add_theme_stylebox_override(
		"hover", _surface_style(Color(1.0, 0.98, 0.92, 0.94), radius, 1.0, 0.42)
	)
	add_theme_stylebox_override(
		"pressed", _surface_style(Color(1.0, 0.90, 0.76, 0.94), radius, 0.94, 0.22)
	)
	add_theme_stylebox_override(
		"disabled", _surface_style(Color(0.98, 0.92, 0.82, 0.20), radius, 0.28, 0.0)
	)
	add_theme_stylebox_override("focus", _focus_style(radius))
	queue_redraw()


func _surface_style(
	fill: Color, radius: float, edge_alpha: float, glow_alpha: float
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.985, 0.93, edge_alpha)
	style.corner_radius_top_left = roundi(radius)
	style.corner_radius_top_right = roundi(radius)
	style.corner_radius_bottom_right = roundi(radius)
	style.corner_radius_bottom_left = roundi(radius)
	style.corner_detail = 16
	style.anti_aliasing = true
	style.shadow_color = Color(0.97, 0.65, 0.34, glow_alpha)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


func _focus_style(radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.98, 0.88, 0.92)
	style.corner_radius_top_left = roundi(radius + 1.0)
	style.corner_radius_top_right = roundi(radius + 1.0)
	style.corner_radius_bottom_right = roundi(radius + 1.0)
	style.corner_radius_bottom_left = roundi(radius + 1.0)
	style.corner_detail = 16
	style.anti_aliasing = true
	return style


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_icon()


func _draw_icon() -> void:
	if visual_kind != VisualKind.ICON or icon_texture == null:
		return
	var icon_side := minf(size.x, size.y) * icon_scale
	var icon_rect := Rect2(
		(size - Vector2(icon_side, icon_side)) * 0.5, Vector2(icon_side, icon_side)
	)
	draw_texture_rect(icon_texture, icon_rect, false, Color.WHITE)
