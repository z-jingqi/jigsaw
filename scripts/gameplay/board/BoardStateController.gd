extends RefCounted
class_name BoardStateController

const BoardSessionIdentityScript := preload("res://scripts/gameplay/runtime/BoardSessionIdentity.gd")

var board: Node2D
var generation := 0


func _init(owner: Node2D) -> void:
	board = owner


func snapshot() -> Dictionary:
	var tray_max_scroll := maxf(0.0, board.tray_content_width - board._tray_area().size.x + board.TRAY_PADDING)
	var snapshot := {
		"version": 2,
		"mode": board.current_mode,
		"hint_count": board.hint_count,
		"view": {
			"ratio": board._view_ratio(),
			"offset": board._vector_to_json(board.view_offset),
		},
		"tray": {
			"scroll": board.tray_scroll_offset,
			"scroll_ratio": 0.0 if tray_max_scroll <= 0.0 else clampf(board.tray_scroll_offset / tray_max_scroll, 0.0, 1.0),
		},
	}
	if board.current_mode == "swap":
		var tiles := []
		for tile in board.swap_tiles:
			var node: Node2D = tile["node"]
			if not is_instance_valid(node):
				continue
			tiles.append({
				"correct_index": int(tile["correct_index"]),
				"slot_index": int(tile["slot_index"]),
				"z": int(node.z_index),
			})
		snapshot["tiles"] = tiles
	else:
		var group_states := []
		for group in board.groups:
			if group == null or not is_instance_valid(group.node) or group.in_tray:
				continue
			var ids := []
			for member in group.members:
				ids.append(str(member["id"]))
			group_states.append({
				"members": ids,
				"position": board._vector_to_json(group.node.position),
				"rotation": float(group.node.rotation_degrees),
				"z": int(group.node.z_index),
				"locked": bool(group.locked),
				"seed": bool(group.is_seed),
			})
		snapshot["groups"] = group_states
		var tray_order := []
		for group in board.tray_groups:
			if group == null:
				continue
			for member in group.members:
				tray_order.append(str(member["id"]))
		snapshot["tray_order"] = tray_order
	return snapshot


func session_piece_ids() -> Array[String]:
	var ids: Array[String] = []
	if board.current_mode == "swap":
		for tile in board.swap_tiles:
			ids.append(str((tile["node"] as Node).name))
	else:
		for group in board.groups:
			for member in group.members:
				ids.append(str(member["id"]))
	ids.sort()
	return ids


func session_snapshot(theme_id: String, level_id: String) -> Dictionary:
	var ids := session_piece_ids()
	var result := {
		"state_version": 1,
		"theme_id": theme_id,
		"level_id": level_id,
		"mode": board.current_mode,
		"piece_set_fingerprint": BoardSessionIdentityScript.fingerprint(ids),
		"hint_count": board.hint_count,
	}
	if board.current_mode == "swap":
		var slots: Array[String] = []
		var ordered: Array = board.swap_tiles.duplicate()
		ordered.sort_custom(func(left, right) -> bool: return int(left["slot_index"]) < int(right["slot_index"]))
		for tile in ordered:
			slots.append(str((tile["node"] as Node).name))
		result["kind"] = "swap"
		result["columns"] = board._swap_cols()
		result["rows"] = board._swap_rows()
		result["slot_piece_ids"] = slots
		return result
	var connected_groups: Array = []
	for group in board.locked_groups:
		var ids_in_group: Array[String] = []
		for member in group.members:
			ids_in_group.append(str(member["id"]))
		ids_in_group.sort()
		connected_groups.append(ids_in_group)
	var tray_order: Array[String] = []
	for group in board.tray_groups:
		for member in group.members:
			tray_order.append(str(member["id"]))
	result["kind"] = "assembly"
	result["connected_groups"] = connected_groups
	result["tray_order"] = tray_order
	return result


func should_persist() -> bool:
	if board.completion_emitted:
		return false
	return not board.swap_tiles.is_empty() if board.current_mode == "swap" else not board.groups.is_empty()


func apply(snapshot: Dictionary) -> void:
	if int(snapshot.get("state_version", -1)) == 1:
		_apply_session_state(snapshot)
		return
	if str(snapshot.get("mode", board.current_mode)) != board.current_mode:
		return
	board.hint_count = maxi(0, int(snapshot.get("hint_count", 0)))
	if board.current_mode == "swap":
		board._restore_swap_state(snapshot)
	else:
		board._restore_group_state(snapshot)
	board._restore_view_state(snapshot)
	board._check_complete()
	board._check_swap_complete()


func _apply_session_state(snapshot: Dictionary) -> void:
	if str(snapshot.get("mode", "")) != board.current_mode:
		return
	board.hint_count = maxi(0, int(snapshot.get("hint_count", 0)))
	if board.current_mode == "swap":
		var tile_by_id := {}
		for tile in board.swap_tiles:
			tile_by_id[str((tile["node"] as Node).name)] = tile
		var tiles: Array = []
		var slot_ids: Array = snapshot.get("slot_piece_ids", [])
		for slot in slot_ids.size():
			var tile = tile_by_id.get(str(slot_ids[slot]), null)
			if tile != null:
				tiles.append({"correct_index": int(tile["correct_index"]), "slot_index": slot, "z": slot * board.GROUP_Z_STEP})
		restore_swap_state({"tiles": tiles})
	else:
		var groups: Array = []
		for ids in snapshot.get("connected_groups", []):
			groups.append({"members": ids, "seed": false})
		restore_group_state({"groups": groups, "tray_order": snapshot.get("tray_order", [])})
	board._check_complete()
	board._check_swap_complete()


func restore_group_state(snapshot: Dictionary) -> void:
	var group_states: Array = snapshot.get("groups", [])
	var piece_to_group := {}
	for group in board.groups:
		for member in group.members:
			piece_to_group[str(member["id"])] = group
	for item in group_states:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var ids: Array = item.get("members", [])
		if ids.is_empty():
			continue
		var active = piece_to_group.get(str(ids[0]), null)
		if active == null or not board.groups.has(active):
			continue
		board._send_group_to_world(active, active.anchor_home)
		for index in range(1, ids.size()):
			var other = piece_to_group.get(str(ids[index]), null)
			if other != null and other != active and board.groups.has(other):
				board._send_group_to_world(other, other.anchor_home)
				active.absorb(other)
				board.groups.erase(other)
				board.tray_groups.erase(other)
				board.locked_groups.erase(other)
				for member in active.members:
					piece_to_group[str(member["id"])] = active
		active.node.position = active.anchor_home
		active.node.rotation_degrees = 0.0
		active.locked = true
		active.in_tray = false
		board.PieceVisualFactoryScript.add_seam_outline(active, board._seam_line_width())
		if bool(item.get("seed", false)):
			active.is_seed = true
		if not board.locked_groups.has(active):
			board.locked_groups.append(active)
	board.tray_groups.clear()
	var tray_order: Array = snapshot.get("tray_order", [])
	for id_value in tray_order:
		var group = piece_to_group.get(str(id_value), null)
		if group != null and board.groups.has(group) and not group.locked and not board.tray_groups.has(group):
			board.tray_groups.append(group)
	for group in board.groups:
		if not group.locked and not board.tray_groups.has(group):
			board.tray_groups.append(group)
	for index in board.tray_groups.size():
		board._move_group_to_tray(board.tray_groups[index], index, true)
	board.tray_scroll_offset = 0.0
	board._layout_tray(true)
	var tray_state: Dictionary = snapshot.get("tray", {})
	var max_scroll := maxf(0.0, board.tray_content_width - board._tray_area().size.x + board.TRAY_PADDING)
	board.tray_scroll_offset = max_scroll * clampf(float(tray_state.get("scroll_ratio", 0.0)), 0.0, 1.0) if tray_state.has("scroll_ratio") else maxf(0.0, float(tray_state.get("scroll", 0.0)))
	board._clamp_tray_scroll()
	board._layout_tray(true)
	board._refresh_group_z_indices()


func restore_swap_state(snapshot: Dictionary) -> void:
	var tile_states: Array = snapshot.get("tiles", [])
	if tile_states.is_empty():
		return
	var by_correct := {}
	for tile in board.swap_tiles:
		by_correct[int(tile["correct_index"])] = tile
	for item in tile_states:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var tile = by_correct.get(int(item.get("correct_index", -1)), null)
		if tile == null:
			continue
		tile["slot_index"] = int(item.get("slot_index", tile["slot_index"]))
		var node: Node2D = tile["node"]
		if is_instance_valid(node):
			node.position = board._swap_slot_position(int(tile["slot_index"]), board._swap_cols(), board._swap_rows())
	var ordered := tile_states.duplicate()
	ordered.sort_custom(func(a, b) -> bool:
		return int(a.get("z", 0)) < int(b.get("z", 0))
	)
	var next_tiles := []
	for item in ordered:
		var tile = by_correct.get(int(item.get("correct_index", -1)), null)
		if tile != null and board.swap_tiles.has(tile) and not next_tiles.has(tile):
			next_tiles.append(tile)
	for tile in board.swap_tiles:
		if not next_tiles.has(tile):
			next_tiles.append(tile)
	board.swap_tiles = next_tiles
	for index in board.swap_tiles.size():
		board.swap_tiles[index]["node"].z_index = index * board.GROUP_Z_STEP


func restore_view_state(snapshot: Dictionary) -> void:
	var view: Dictionary = snapshot.get("view", {})
	if view.is_empty():
		return
	board.view_scale = board._clamped_actual_scale(board.base_view_scale * float(view.get("ratio", 1.0)))
	board.view_target_scale = board.view_scale
	board.view_target_ratio = board._view_ratio_for_scale(board.view_scale)
	board.view_offset = board._json_vector(view.get("offset", board._vector_to_json(board.base_view_offset)))
	board._clamp_view_to_table()
	board._apply_view_transform()


func notify_changed(immediate := false) -> void:
	if board.completion_emitted:
		return
	var now := Time.get_ticks_msec()
	if immediate or now - board.last_state_emit_msec >= 250:
		board.last_state_emit_msec = now
		board.state_changed.emit(snapshot())
		return
	if board.state_emit_pending:
		return
	board.state_emit_pending = true
	var expected_generation := generation
	board.get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if board == null or not is_instance_valid(board) or expected_generation != generation:
			return
		board.state_emit_pending = false
		board.last_state_emit_msec = Time.get_ticks_msec()
		if not board.completion_emitted:
			board.state_changed.emit(snapshot())
	)


func cancel_pending() -> void:
	generation += 1
	if board != null and is_instance_valid(board):
		board.state_emit_pending = false


func vector_to_json(value: Vector2) -> Array:
	return [float(value.x), float(value.y)]


func json_vector(value, fallback := Vector2.ZERO) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
