extends RefCounted
class_name BoardSnapController

var host: Node2D
const READY_EXIT_MARGIN_PIXELS := 4.0

const Presentation := preload("res://scripts/gameplay/board/BoardSnapPresentation.gd")

var _presentation: Node2D
var _preview_enabled := true


func _init(owner: Node2D) -> void:
	host = owner


func _bring_to_front(group) -> void:
	host.groups.erase(group)
	host.groups.append(group)
	_refresh_group_z_indices()
	host._notify_state_changed()


func _refresh_group_z_indices() -> void:
	for index in host.groups.size():
		var group = host.groups[index]
		# World pieces must remain above their page's board frame. Only tray
		# pieces and a tray capture need an absolute Z above the clipped tray.
		group.node.z_as_relative = not (
			group.in_tray or (group == host.dragging and host.dragging_from_tray)
		)
		if group == host.dragging and host.dragging_from_tray:
			group.node.z_index = int(host.tray_config["drag_z_index"])
		elif group.in_tray:
			group.node.z_index = int(host.tray_config["z_index"])
		else:
			group.node.z_index = index * host.GROUP_Z_STEP


func _update_snap_preview(active) -> void:
	if active == null or active.locked or not is_instance_valid(active.node):
		_clear_snap_preview()
		return
	var match := _snap_match_data(active)
	if match.is_empty():
		_clear_snap_preview()
		return
	var other = match.get("other", null)
	var key := "%s>%s" % [host._debug_group_id(active), host._debug_group_id(other)]
	if _preview_enabled:
		host.snap_preview_key = key
		_feedback_owner().show_preview(match)
	else:
		_hide_preview()
	if host.snap_ready_key != key:
		host.snap_ready_key = key
		if _preview_enabled:
			host._trigger_haptic("ready")


func _clear_snap_preview() -> void:
	_hide_preview()
	host.snap_ready_key = ""


func _hide_preview() -> void:
	if is_instance_valid(_presentation):
		_presentation.clear_preview()
	host.snap_preview_key = ""


func set_preview_enabled(enabled: bool) -> void:
	_preview_enabled = enabled
	if not enabled:
		_hide_preview()
	elif host.dragging != null:
		_update_snap_preview(host.dragging)


func has_preview() -> bool:
	return _preview_enabled and not host.snap_preview_key.is_empty()


func debug_snapshot() -> Dictionary:
	var result := {"enabled": _preview_enabled, "visible": has_preview()}
	if is_instance_valid(_presentation):
		result.merge(_presentation.debug_snapshot())
	return result


func set_reduced_motion(enabled: bool) -> void:
	if is_instance_valid(_presentation):
		_presentation.set_reduced_motion(enabled)


func _feedback_owner() -> Node2D:
	if not is_instance_valid(_presentation):
		_presentation = Presentation.new()
		_presentation.name = "SnapPresentation"
		_presentation.z_as_relative = false
		_presentation.z_index = int(host.tray_config["drag_z_index"])
		host.world_root.add_child(_presentation)
		_presentation.set_reduced_motion(host.reduced_motion)
	return _presentation


func _try_snap_chain(active) -> bool:
	if active == null or active.locked:
		return false
	var snapped := false
	var progressed := true
	while progressed:
		progressed = false
		var match := _snap_match_data(active)
		var other = match.get("other", null)
		if other != null:
			host._clear_hint_highlights()
			active.absorb(other, host.SNAP_VISUAL_GAP)
			host.groups.erase(other)
			host.locked_groups.erase(other)
			_refresh_group_z_indices()
			active.node.position = active.anchor_home
			active.node.rotation_degrees = 0.0
			active.node.scale = Vector2.ONE
			host.PieceVisualFactoryScript.settle_group_edges(active)
			snapped = true
			progressed = true
	if snapped:
		host._trigger_haptic("snap")
	return snapped


func _snap_match_data(active) -> Dictionary:
	var candidate: Dictionary = host.SnapSolverScript.find_match_data(
		active, _locked_snap_targets(active), _snap_tolerance()
	)
	if not candidate.is_empty() or host.snap_ready_key.is_empty():
		return candidate
	# A small exit band preserves a visible ready state through finger-up jitter.
	# It applies only to the same neighbor that was already inside the entry band.
	candidate = host.SnapSolverScript.find_match_data(
		active,
		_locked_snap_targets(active),
		_snap_tolerance() * (1.0 + READY_EXIT_MARGIN_PIXELS / host.SNAP_TOLERANCE)
	)
	if not candidate.is_empty():
		var key := "%s>%s" % [host._debug_group_id(active), host._debug_group_id(candidate.other)]
		if key == host.snap_ready_key:
			return candidate
	return {}


func _play_snap_shimmer(members: Array) -> void:
	if not host.reduced_motion:
		_feedback_owner().play_landing(members)


func _locked_snap_targets(active) -> Array:
	var result := []
	for group in host.groups:
		if group != active and group.locked:
			result.append(group)
	return result


func _lock_group(group) -> void:
	if group == null:
		return
	group.locked = true
	group.in_tray = false
	group.node.position = group.anchor_home
	group.node.rotation_degrees = 0.0
	group.node.scale = Vector2.ONE
	host.PieceVisualFactoryScript.settle_group_edges(group)
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
	# Solve in world coordinates with a constant radius in actual display pixels.
	# Include both board zoom and the 1206-unit canvas stretch used on Android.
	var world: Node2D = host.world_root
	var pixels_per_unit := (
		(world.get_viewport_transform() * world.get_global_transform()).x.length()
	)
	return host.SNAP_TOLERANCE / maxf(0.001, pixels_per_unit)


func _check_complete() -> void:
	if host.current_mode == "swap":
		return
	for group in host.groups:
		if not group.locked:
			return
	if not host.completion_emitted:
		host.completion_emitted = true
		host._trigger_haptic("complete")
		host.completed.emit()
