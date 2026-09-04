extends RefCounted
class_name BoardSnapController

const SNAP_DISTANCE_CM := 0.3
const CENTIMETERS_PER_INCH := 2.54
const FALLBACK_DPI := 160

var host: Node2D

static var _shimmer_shader_cache: Shader = null
static var _shimmer_uv_texture_cache: Texture2D = null


func _init(owner: Node2D) -> void:
	host = owner


func _rotate_group(group) -> void:
	if not host.randomize_piece_rotation or group == null or group.is_animating:
		return
	group.is_animating = true
	var target: float = snappedf(group.node.rotation_degrees + 90.0, 90.0)
	var tween := host.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(group.node, "rotation_degrees", target, host._motion_duration(0.16))
	tween.finished.connect(
		func() -> void:
			if not host.groups.has(group) or not is_instance_valid(group.node):
				return
			group.is_animating = false
			host._notify_state_changed(true)
	)


func _bring_to_front(group) -> void:
	host.groups.erase(group)
	host.groups.append(group)
	_refresh_group_z_indices()


func _refresh_group_z_indices() -> void:
	for index in host.groups.size():
		var group = host.groups[index]
		if group.in_tray:
			host.tray_controller.restore_group_tray_z(group)
		else:
			group.node.z_index = index * host.GROUP_Z_STEP


func _try_snap_chain(active) -> bool:
	if active == null or active.locked:
		return false
	var snapped := false
	var progressed := true
	while progressed:
		progressed = false
		# Placement is evaluated at the current release position.
		var candidate := _snap_match_data(active)
		var other = candidate.get("other", null)
		if other != null and host.groups.has(other) and other.locked:
			host._clear_hint_highlights()
			active.absorb(other, host.SNAP_VISUAL_GAP)
			host.groups.erase(other)
			host.locked_groups.erase(other)
			_refresh_group_z_indices()
			active.node.position = active.anchor_home
			active.node.rotation_degrees = 0.0
			active.node.scale = Vector2.ONE
			host.PieceVisualFactoryScript.add_seam_outline(active, _seam_line_width())
			snapped = true
			progressed = true
	return snapped


func _snap_match_data(active) -> Dictionary:
	if (
		active == null
		or active.locked
		or active.in_tray
		or not is_instance_valid(active.node)
		or not active.node.scale.is_equal_approx(Vector2.ONE)
	):
		return {}
	return host.SnapSolverScript.find_match_data(
		active,
		_locked_snap_targets(active),
		_snap_radius_pixels(),
		host.ROTATION_TOLERANCE,
		_world_to_screen_transform()
	)


func _seam_line_width() -> float:
	return (
		host.SEAM_SCREEN_WIDTH
		/ maxf(0.001, host.base_view_scale if host.base_view_scale > 0.0 else host.view_scale)
	)


func _play_snap_shimmer(members: Array) -> void:
	if host.reduced_motion:
		return
	var material := ShaderMaterial.new()
	material.shader = _shimmer_shader()
	material.set_shader_parameter("progress", 0.0)
	var overlays: Array[Polygon2D] = []
	for member in members:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var visual: Node2D = member.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			continue
		var polygon: PackedVector2Array = member["polygon"]
		var bounds: Rect2 = host._source_rect_for_points(polygon)
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			continue
		var overlay := Polygon2D.new()
		overlay.name = "snap_shimmer"
		overlay.polygon = polygon
		var uv := PackedVector2Array()
		for point in polygon:
			uv.append((point - bounds.position) / bounds.size)
		overlay.uv = uv
		overlay.texture = _shimmer_uv_texture()
		overlay.material = material
		overlay.z_index = 24
		visual.add_child(overlay)
		overlays.append(overlay)
	if overlays.is_empty():
		return
	var tween := host.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(
		func(t: float) -> void: material.set_shader_parameter("progress", t),
		0.0,
		1.0,
		host.SHIMMER_DURATION
	)
	tween.finished.connect(
		func() -> void:
			for overlay in overlays:
				if is_instance_valid(overlay):
					overlay.queue_free()
	)


static func _shimmer_shader() -> Shader:
	if _shimmer_shader_cache != null:
		return _shimmer_shader_cache
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float band_center = mix(-0.4, 1.4, progress);
	float d = (UV.x + UV.y) * 0.5;
	float band = 1.0 - smoothstep(0.0, 0.26, abs(d - band_center));
	float alpha = band * band * 0.8;
	COLOR = vec4(1.0, 1.0, 1.0, alpha);
}
"""
	_shimmer_shader_cache = shader
	return shader


static func _shimmer_uv_texture() -> Texture2D:
	if _shimmer_uv_texture_cache != null:
		return _shimmer_uv_texture_cache
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_shimmer_uv_texture_cache = ImageTexture.create_from_image(image)
	return _shimmer_uv_texture_cache


func _locked_snap_targets(active) -> Array:
	var result := []
	for group in host.groups:
		if group != active and group.locked:
			result.append(group)
	return result


func _lock_group(group) -> void:
	if group == null:
		return
	group.clear_tray_return_pose()
	group.locked = true
	group.in_tray = false
	group.node.position = group.anchor_home
	group.node.rotation_degrees = 0.0
	group.node.scale = Vector2.ONE
	host.PieceVisualFactoryScript.add_seam_outline(group, _seam_line_width())
	if not host.locked_groups.has(group):
		host.locked_groups.append(group)
	if host.tray_groups.has(group):
		host.tray_groups.erase(group)
		_reindex_tray()
		host._layout_tray(false)


func _return_group_to_tray(group) -> void:
	if group == null:
		return
	group.locked = false
	group.in_tray = true
	group.node.rotation_degrees = 0.0
	if not host.tray_groups.has(group):
		var index := clampi(host.dragging_tray_index, 0, host.tray_groups.size())
		host.tray_groups.insert(index, group)
	_reindex_tray()
	host._layout_tray(false)


func _reindex_tray() -> void:
	for index in host.tray_groups.size():
		var group = host.tray_groups[index]
		if group != null:
			group.tray_index = index


func _snap_tolerance() -> float:
	# Horizontal world-space equivalent for existing debug placement helpers.
	var screen_transform := _world_to_screen_transform()
	return _snap_radius_pixels() / maxf(0.001, screen_transform.x.length())


func _world_to_screen_transform() -> Transform2D:
	# CanvasItem.get_screen_transform() omits root viewport stretch. Include it
	# explicitly so a 1206-wide canvas on a 720-pixel phone still measures pixels.
	return (
		host.get_viewport().get_screen_transform()
		* host.world_root.get_global_transform_with_canvas()
	)


func _snap_radius_pixels() -> float:
	var dpi := DisplayServer.screen_get_dpi(host.get_window().current_screen)
	if dpi <= 0:
		dpi = FALLBACK_DPI
	# Android reports a density bucket, so physical centimeters are approximate.
	return SNAP_DISTANCE_CM * float(dpi) / CENTIMETERS_PER_INCH


func distance_metrics() -> Dictionary:
	return {
		"radius_cm": SNAP_DISTANCE_CM,
		"radius_screen_px": _snap_radius_pixels(),
		"radius_world_x": _snap_tolerance(),
		"trigger": "release",
		"duration_seconds": 0.0,
		"animating": false,
	}


func _check_complete() -> void:
	if host.current_mode == "swap":
		return
	for group in host.groups:
		if not group.locked:
			return
	if not host.completion_emitted:
		host.completion_emitted = true
		host.completed.emit()
