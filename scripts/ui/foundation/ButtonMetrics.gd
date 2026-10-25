extends RefCounted
## Top navigation follows the mode-selection back button's reference geometry.

const REFERENCE_SIZE := Vector2(390.0, 844.0)
const SIDE := 44.0
const EDGE := 18.0
const TOP := 22.0
const GAP := 12.0


static func unit(viewport_size: Vector2) -> float:
	return maxf(1.0, minf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y))


static func icon_size(viewport_size: Vector2) -> Vector2:
	return Vector2.ONE * SIDE * unit(viewport_size)


static func navigation_position(viewport_size: Vector2, from_right := false, slot := 0) -> Vector2:
	var u := unit(viewport_size)
	var inset := (EDGE + slot * (SIDE + GAP)) * u
	return Vector2(viewport_size.x - inset - SIDE * u if from_right else inset, TOP * u)


static func header_center_y(viewport_size: Vector2) -> float:
	return (TOP + SIDE * 0.5) * unit(viewport_size)


static func place_navigation(
	button: Button,
	surface: Control,
	from_right := false,
	slot := 0,
	metric_size := Vector2.ZERO,
) -> void:
	var reference := metric_size if metric_size != Vector2.ZERO else surface.size
	var point := navigation_position(reference, from_right, slot)
	var safe := preload("res://scripts/ui/foundation/CleanTheme.gd").safe_insets(surface.size)
	point.y += safe.y
	point.x += -safe.z if from_right else safe.x
	if from_right:
		point.x += surface.size.x - reference.x
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	apply_size(button, icon_size(reference))
	var parent := button.get_parent() as Control
	button.position = (
		parent.get_global_transform().affine_inverse() * (surface.get_global_transform() * point)
	)


static func apply_size(button: Button, dimensions: Vector2) -> void:
	button.custom_minimum_size = dimensions
	button.size = dimensions
	button.pivot_offset = dimensions * 0.5
