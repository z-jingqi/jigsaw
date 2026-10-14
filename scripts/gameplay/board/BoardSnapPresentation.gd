extends Node2D
## Owns the translucent destination image and brief landing glow, never piece poses.

const Glow := preload("res://scripts/gameplay/board/PieceSnapGlow.gd")
const Surface := preload("res://scripts/gameplay/board/PieceSurface.gd")

var _preview: Node2D
var _ghost: Polygon2D
var _key := ""
var _target_alpha := 0.0
var _reduced_motion := false
var _landings: Array[WeakRef] = []


func _ready() -> void:
	_preview = Node2D.new()
	_preview.name = "SnapPreview"
	_preview.modulate.a = 0.0
	add_child(_preview)
	set_process(false)


func show_preview(match_data: Dictionary) -> void:
	var member: Dictionary = match_data.active_member
	var other: Dictionary = match_data.other_member
	var key := "%s>%s" % [member.id, other.id]
	if key != _key:
		_build_preview(member)
		_key = key
	_ghost.position = member.home
	_retarget(1.0)


func clear_preview() -> void:
	_retarget(0.0)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		_preview.modulate.a = _target_alpha
		set_process(false)
		for reference in _landings:
			var landing: Object = reference.get_ref()
			if is_instance_valid(landing):
				landing.queue_free()
		_landings.clear()


func play_landing(members: Array) -> void:
	if _reduced_motion:
		return
	_landings = _landings.filter(
		func(reference: WeakRef) -> bool: return reference.get_ref() != null
	)
	for member in members:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var visual: Node2D = member.get("visual")
		if not is_instance_valid(visual):
			continue
		var previous := visual.get_node_or_null("snap_shimmer")
		if previous != null:
			visual.remove_child(previous)
			previous.queue_free()
		var glow := Glow.new()
		glow.name = "snap_shimmer"
		glow.z_index = 28
		glow.configure(member.polygon, visual.get_node_or_null("piece_texture") as Polygon2D)
		visual.add_child(glow)
		_landings.append(weakref(glow))


func debug_snapshot() -> Dictionary:
	return {
		"preview_alpha": _preview.modulate.a,
		"preview_target": _target_alpha,
		"preview_node_id": _preview.get_instance_id(),
		"preview_shape_key": _key,
		"preview_children": _preview.get_child_count(),
		"ghost_alpha": _ghost.color.a if is_instance_valid(_ghost) else 0.0,
		"active_landings":
		_landings.filter(func(reference): return reference.get_ref() != null).size(),
		"motion_active": is_processing(),
	}


func _build_preview(member: Dictionary) -> void:
	for child in _preview.get_children():
		_preview.remove_child(child)
		child.queue_free()
	var face := member.visual.get_node_or_null("piece_texture") as Polygon2D
	_ghost = Surface.new()
	_ghost.name = "SnapTargetImprint"
	_ghost.z_index = -1
	_ghost.polygon = member.polygon
	if face != null:
		_ghost.uv = face.uv
		_ghost.texture = face.texture
	_ghost.color = Color(0.94, 0.98, 0.91, 0.22)
	_preview.add_child(_ghost)


func _retarget(alpha: float) -> void:
	_target_alpha = alpha
	if _reduced_motion:
		_preview.modulate.a = alpha
		set_process(false)
	elif not is_equal_approx(_preview.modulate.a, alpha):
		set_process(true)


func _process(delta: float) -> void:
	var rate := 27.0 if _target_alpha > _preview.modulate.a else 34.0
	_preview.modulate.a = lerpf(_preview.modulate.a, _target_alpha, 1.0 - exp(-rate * delta))
	if absf(_preview.modulate.a - _target_alpha) < 0.005:
		_preview.modulate.a = _target_alpha
		set_process(false)
