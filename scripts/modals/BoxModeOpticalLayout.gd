extends RefCounted
## Optical spacing uses projected carton bounds, not its transparent viewport quad.
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")


static func carton_bottom_fraction(box: Control) -> float:
	var viewport := box.get_node("Viewport") as SubViewport
	var camera := box.get_node("Viewport/World/Camera") as Camera3D
	return maxf(
		0.1, _project_bottom(box.get_node("Viewport/World/Carton"), camera) / viewport.size.y
	)


static func _project_bottom(node: Node, camera: Camera3D) -> float:
	var bottom := 0.0
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null:
		var bounds: AABB = node.get_aabb()
		for corner in 8:
			var world: Vector3 = node.global_transform * bounds.get_endpoint(corner)
			bottom = maxf(bottom, camera.unproject_position(world).y)
	for child in node.get_children():
		bottom = maxf(bottom, _project_bottom(child, camera))
	return bottom


static func apply(box: Control, options: Control, start: Button, available: Vector2) -> Rect2:
	var u := Clean.canvas_scale(available, box.get_window())
	var old_width := maxf(120 * u, minf(available.x - 32 * u, (available.y - 320 * u) * 0.75))
	var old_height := old_width / 0.75
	var top := 78 * u
	var bottom_fraction := carton_bottom_fraction(box)
	var count := options.get_child_count()
	options.size = Vector2(available.x - 48 * u, 60 * u)
	var visual_top := 30 * u
	var visual_bottom := 30 * u
	for index in count:
		var option: Control = options.get_child(index)
		option.custom_minimum_size = Vector2(44, 60) * u
		option.size = Vector2(options.size.x / count - 6 * u, 60 * u)
		option.position = Vector2(float(index) * options.size.x / count, 0)
		var bounds: Rect2 = option.icon_visible_rect()
		visual_top = minf(visual_top, bounds.position.y)
		visual_bottom = maxf(visual_bottom, bounds.end.y)
	# Preserve the approved old upper gap; do not replace it with a spacing token.
	var gap := old_height * (1.0 - bottom_fraction) + 12 * u + visual_top
	var max_bottom := available.y - Clean.SPACE_24 * u - start.size.y
	var height := minf(
		old_height, (max_bottom - top - 2 * gap - visual_bottom + visual_top) / bottom_fraction
	)
	height = maxf(80 * u, height)
	var width := height * 0.75
	var destination := Rect2(Vector2((available.x - width) * 0.5, top), Vector2(width, height))
	options.position = Vector2(24 * u, top + height * bottom_fraction + gap - visual_top)
	start.position.y = options.position.y + visual_bottom + gap
	return destination
