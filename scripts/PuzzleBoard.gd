extends Node2D
class_name PuzzleBoard

signal status_changed(text: String)
signal zoom_changed(percent: int)
signal completed
signal state_changed(state: Dictionary)
signal undo_available_changed(available: bool)

const SNAP_TOLERANCE := 22.0
const ROTATION_TOLERANCE := 3.0
const HIT_ALPHA_RADIUS := 2
const PIECE_DRAG_PADDING := 8.0
const PIECE_SPAWN_EDGE_PADDING := 22.0
const PIECE_SPAWN_SEPARATION := 34.0
const VIEW_MIN_RATIO := 0.90
const VIEW_MAX_RATIO := 2.40
const VIEW_WHEEL_STEP := 0.08
const TRACKPAD_MAGNIFY_MIN := 0.86
const TRACKPAD_MAGNIFY_MAX := 1.16
const VIEW_FIT_PADDING := 36.0
const BOARD_SCREEN_EDGE_GAP := 10.0
const BOARD_OUTLINE_SHADOW_OUTSET := 5.0
const VIEW_HINT_PADDING := 58.0
const VIEW_HINT_MAX_RATIO := 1.45
const HINT_GLOW_COLOR := Color(0.20, 0.78, 1.0, 0.22)
const HINT_OUTLINE_COLOR := Color(0.20, 0.78, 1.0, 0.98)
const HINT_OUTLINE_SCREEN_WIDTH := 5.0
const HINT_TARGET_COLOR := Color(0.20, 0.78, 1.0, 0.95)
const HINT_TARGET_SCREEN_WIDTH := 5.0
const HINT_TARGET_DASH_LENGTH := 11.0
const HINT_TARGET_DASH_GAP := 7.0
const HINT_DURATION := 6.0
const HINT_BREATHE_SCALE := 1.14
const HINT_BREATHE_CYCLE := 1.5
const HINT_TRAY_SCROLL_TIME := 0.3
const HINT_TARGET_Z_INDEX := 4086
const HINT_GROUP_Z_INDEX := 4088
const SNAP_VISUAL_GAP := 0.0
const SNAP_PREVIEW_PULL := 0.10
const SNAP_PREVIEW_COLOR := Color(0.16, 0.70, 0.62, 0.92)
const SNAP_PREVIEW_SCREEN_WIDTH := 3.0
const SEAM_SCREEN_WIDTH := 1.6
const SHIMMER_DURATION := 0.7
const SWAP_FALLBACK_COLS := 5
const SWAP_FALLBACK_ROWS := 7
const SWAP_ANIMATION_TIME := 0.20
const SWAP_TARGET_PREVIEW_COLOR := Color(0.96, 0.58, 0.20, 0.96)
const SWAP_TARGET_PREVIEW_FILL := Color(1.0, 0.72, 0.30, 0.20)
const SWAP_TARGET_PREVIEW_SCREEN_WIDTH := 4.0
const TABLE_EXTRA_MIN := 180.0
const TABLE_EXTRA_MAX := 620.0
const GROUP_Z_STEP := 64
const TRAY_HEIGHT_RATIO := 1.0 / 6.0
const TRAY_MIN_HEIGHT := 132.0
const TRAY_PADDING := 14.0
const TRAY_VERTICAL_SAFE_GAP := 50.0
const TRAY_GAP := 32.0
const TRAY_ANIMATION_TIME := 0.20
const TRAY_Z_INDEX := 4090
const TRAY_HIT_PADDING := 18.0
const TRAY_EXIT_THRESHOLD := 18.0
const TRAY_GESTURE_DECIDE_THRESHOLD := 12.0
const TRAY_DRAG_SCALE_TIME := 0.16
const TRAY_DRAG_LIFT_MARGIN := 28.0
const TRAY_DRAG_Z_INDEX := 4095
const TRAY_INERTIA_MIN_SPEED := 90.0
const TRAY_INERTIA_FRICTION := 9.0
const BoardLayoutScript := preload("res://scripts/BoardLayout.gd")
const PieceGroupScript := preload("res://scripts/PieceGroup.gd")
const PieceVisualFactoryScript := preload("res://scripts/PieceVisualFactory.gd")
const SnapSolverScript := preload("res://scripts/SnapSolver.gd")

var texture: Texture2D
var source_image: Image
var source_size := Vector2.ZERO
var source_scale := 1.0
var board_origin := Vector2.ZERO
var active_level_config := {}
var current_mode := "knob"
var rng := RandomNumberGenerator.new()
var world_root: Node2D
var tray_root: Node2D
var tray_background: ColorRect
var view_scale := 1.0
var view_target_scale := 1.0
var view_target_ratio := 1.0
var base_view_scale := 1.0
var base_view_offset := Vector2.ZERO
var view_offset := Vector2.ZERO
var view_tween: Tween
var groups: Array = []
var tray_groups: Array = []
var locked_groups: Array = []
var tray_scroll_offset := 0.0
var tray_content_width := 0.0
var tray_panning := false
var tray_pan_last_x := 0.0
var tray_pending_group = null
var tray_pending_start_pos := Vector2.ZERO
var tray_pending_total_delta := Vector2.ZERO
var tray_scroll_velocity := 0.0
var tray_last_pan_msec := 0
var tray_inertia_active := false
var swap_tiles: Array = []
var swap_history: Array[Dictionary] = []
var spawn_bounds: Array[Rect2] = []
var dragging = null
var dragging_from_tray := false
var dragging_tray_index := -1
var dragging_original_tray_slot := Rect2()
var tray_drag_offset := Vector2.ZERO
var tray_drag_screen_offset := Vector2.ZERO
var tray_drag_target_screen_offset := Vector2.ZERO
var tray_drag_offset_tween: Tween
var tray_drag_local_grab := Vector2.ZERO
var tray_drag_scale_tween: Tween
var dragging_at_tray_scale := false
var last_drag_screen_pos := Vector2.ZERO
var swap_dragging = null
var swap_drag_start_slot := -1
var swap_drag_offset := Vector2.ZERO
var swap_target_preview = null
var swap_target_preview_root: Node2D
var swap_target_preview_line: Line2D
var swap_target_preview_tween: Tween
var selected_group = null
var hint_highlighted_groups: Array = []
var hint_highlighted_lines: Array[Line2D] = []
var hint_highlighted_nodes: Array[Node] = []
var hint_original_modulates: Dictionary = {}
var hint_blink_tweens: Array[Tween] = []
var active_touch_index := -1
var active_touches := {}
var drag_offset := Vector2.ZERO
var panning := false
var pan_touch_index := -1
var pan_last_screen := Vector2.ZERO
var pinch_active := false
var pinch_start_distance := 0.0
var pinch_start_scale := 1.0
var pinch_start_world_midpoint := Vector2.ZERO
var hud_icon_size := 56.0
var drag_blockers: Array[Rect2] = []
var completion_emitted := false
var randomize_piece_rotation := false
var hint_highlight_token := 0
var active_hint_key := ""
var hint_expires_at_msec := 0
var hint_pending := false
var hint_tray_scroll_tween: Tween
var hint_clear_timer: Timer
var hint_count := 0
var snap_preview_lines: Array[Line2D] = []
var snap_preview_key := ""
var snap_ready_key := ""
var debug_bounds_overlay_enabled := false
var debug_bounds_overlay: Control
var texts := {}
var state_emit_pending := false
var last_state_emit_msec := 0
var haptics_enabled := true
var reduced_motion := false
var edge_contrast_mode := "auto"
var piece_visual_style := {}


func _ready() -> void:
	rng.seed = 7


func _process(delta: float) -> void:
	if not hint_highlighted_lines.is_empty():
		_refresh_hint_line_widths()
	if swap_target_preview_line != null and is_instance_valid(swap_target_preview_line):
		_update_hint_line_width(swap_target_preview_line)
	if debug_bounds_overlay_enabled:
		_refresh_debug_bounds_overlay()
	if not tray_inertia_active:
		return
	var previous := tray_scroll_offset
	tray_scroll_offset += tray_scroll_velocity * delta
	_clamp_tray_scroll()
	_layout_tray(true)
	if is_equal_approx(previous, tray_scroll_offset):
		_stop_tray_inertia()
		return
	var decay := maxf(0.0, 1.0 - TRAY_INERTIA_FRICTION * delta)
	tray_scroll_velocity *= decay
	if absf(tray_scroll_velocity) < TRAY_INERTIA_MIN_SPEED:
		_stop_tray_inertia()
	_notify_state_changed()


func set_texts(next_texts: Dictionary) -> void:
	texts = next_texts.duplicate()


func set_feedback_preferences(next_haptics_enabled: bool, next_reduced_motion: bool, next_edge_contrast_mode := "auto") -> void:
	haptics_enabled = next_haptics_enabled
	reduced_motion = next_reduced_motion
	edge_contrast_mode = next_edge_contrast_mode if ["auto", "dark", "light"].has(next_edge_contrast_mode) else "auto"


func _bt(key: String) -> String:
	return str(texts.get(key, key))


func _motion_duration(duration: float) -> float:
	return 0.001 if reduced_motion else duration


func _trigger_haptic(kind: String) -> void:
	if not haptics_enabled:
		return
	var duration := 8
	var amplitude := 0.16
	if kind == "ready":
		duration = 12
		amplitude = 0.22
	elif kind == "snap" or kind == "swap":
		duration = 28
		amplitude = 0.48
	elif kind == "complete":
		duration = 70
		amplitude = 0.72
	Input.vibrate_handheld(duration, amplitude)


func state_snapshot() -> Dictionary:
	var tray_max_scroll := maxf(0.0, tray_content_width - _tray_area().size.x + TRAY_PADDING)
	var snapshot := {
		"version": 2,
		"mode": current_mode,
		"hint_count": hint_count,
		"view": {
			"ratio": _view_ratio(),
			"offset": _vector_to_json(view_offset),
		},
		"tray": {
			"scroll": tray_scroll_offset,
			"scroll_ratio": 0.0 if tray_max_scroll <= 0.0 else clampf(tray_scroll_offset / tray_max_scroll, 0.0, 1.0),
		},
	}
	if current_mode == "swap":
		var tiles := []
		for tile in swap_tiles:
			var node: Node2D = tile["node"]
			if not is_instance_valid(node):
				continue
			tiles.append({
				"correct_index": int(tile["correct_index"]),
				"slot_index": int(tile["slot_index"]),
				"position": _vector_to_json(node.position),
				"z": int(node.z_index),
			})
		snapshot["tiles"] = tiles
		snapshot["swap_history"] = swap_history.duplicate(true)
	else:
		var group_states := []
		for group in groups:
			if group == null or not is_instance_valid(group.node) or group.in_tray:
				continue
			var ids := []
			for member in group.members:
				ids.append(str(member["id"]))
			group_states.append({
				"members": ids,
				"position": _vector_to_json(group.node.position),
				"rotation": float(group.node.rotation_degrees),
				"z": int(group.node.z_index),
				"locked": bool(group.locked),
				"seed": bool(group.is_seed),
			})
		snapshot["groups"] = group_states
		var tray_order := []
		for group in tray_groups:
			if group == null:
				continue
			for member in group.members:
				tray_order.append(str(member["id"]))
		snapshot["tray_order"] = tray_order
	return snapshot


func should_persist_state() -> bool:
	if completion_emitted:
		return false
	return not swap_tiles.is_empty() if current_mode == "swap" else not groups.is_empty()


func apply_state_snapshot(snapshot: Dictionary) -> void:
	if str(snapshot.get("mode", current_mode)) != current_mode:
		return
	hint_count = maxi(0, int(snapshot.get("hint_count", 0)))
	if current_mode == "swap":
		_restore_swap_state(snapshot)
	else:
		_restore_group_state(snapshot)
	_restore_view_state(snapshot)
	_check_complete()
	_check_swap_complete()


func _restore_group_state(snapshot: Dictionary) -> void:
	var group_states: Array = snapshot.get("groups", [])
	var piece_to_group := {}
	for group in groups:
		for member in group.members:
			piece_to_group[str(member["id"])] = group
	for item in group_states:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var ids: Array = item.get("members", [])
		if ids.is_empty():
			continue
		var active = piece_to_group.get(str(ids[0]), null)
		if active == null or not groups.has(active):
			continue
		_send_group_to_world(active, active.anchor_home)
		for index in range(1, ids.size()):
			var other = piece_to_group.get(str(ids[index]), null)
			if other != null and other != active and groups.has(other):
				_send_group_to_world(other, other.anchor_home)
				active.absorb(other)
				groups.erase(other)
				tray_groups.erase(other)
				locked_groups.erase(other)
				for member in active.members:
					piece_to_group[str(member["id"])] = active
		active.node.position = active.anchor_home
		active.node.rotation_degrees = 0.0
		active.locked = true
		active.in_tray = false
		PieceVisualFactoryScript.add_seam_outline(active, _seam_line_width())
		if bool(item.get("seed", false)):
			active.is_seed = true
		if not locked_groups.has(active):
			locked_groups.append(active)
	tray_groups.clear()
	var tray_order: Array = snapshot.get("tray_order", [])
	for id_value in tray_order:
		var group = piece_to_group.get(str(id_value), null)
		if group != null and groups.has(group) and not group.locked and not tray_groups.has(group):
			tray_groups.append(group)
	for group in groups:
		if not group.locked and not tray_groups.has(group):
			tray_groups.append(group)
	for index in tray_groups.size():
		_move_group_to_tray(tray_groups[index], index, true)
	tray_scroll_offset = 0.0
	_layout_tray(true)
	var tray_state: Dictionary = snapshot.get("tray", {})
	var max_scroll := maxf(0.0, tray_content_width - _tray_area().size.x + TRAY_PADDING)
	tray_scroll_offset = max_scroll * clampf(float(tray_state.get("scroll_ratio", 0.0)), 0.0, 1.0) if tray_state.has("scroll_ratio") else maxf(0.0, float(tray_state.get("scroll", 0.0)))
	_clamp_tray_scroll()
	_layout_tray(true)
	_refresh_group_z_indices()


func _restore_swap_state(snapshot: Dictionary) -> void:
	var tile_states: Array = snapshot.get("tiles", [])
	if tile_states.is_empty():
		return
	var by_correct := {}
	for tile in swap_tiles:
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
			node.position = _json_vector(item.get("position", _vector_to_json(_swap_slot_position(int(tile["slot_index"]), _swap_cols(), _swap_rows()))))
	var ordered := tile_states.duplicate()
	ordered.sort_custom(func(a, b) -> bool:
		return int(a.get("z", 0)) < int(b.get("z", 0))
	)
	var next_tiles := []
	for item in ordered:
		var tile = by_correct.get(int(item.get("correct_index", -1)), null)
		if tile != null and swap_tiles.has(tile) and not next_tiles.has(tile):
			next_tiles.append(tile)
	for tile in swap_tiles:
		if not next_tiles.has(tile):
			next_tiles.append(tile)
	swap_tiles = next_tiles
	for index in swap_tiles.size():
		swap_tiles[index]["node"].z_index = index * GROUP_Z_STEP
	var history = snapshot.get("swap_history", [])
	swap_history = history.duplicate(true) if typeof(history) == TYPE_ARRAY else []
	undo_available_changed.emit(not swap_history.is_empty())


func _restore_view_state(snapshot: Dictionary) -> void:
	var view: Dictionary = snapshot.get("view", {})
	if view.is_empty():
		return
	view_scale = _clamped_actual_scale(base_view_scale * float(view.get("ratio", 1.0)))
	view_target_scale = view_scale
	view_target_ratio = _view_ratio_for_scale(view_scale)
	view_offset = _json_vector(view.get("offset", _vector_to_json(base_view_offset)))
	_clamp_view_to_table()
	_apply_view_transform()


func _notify_state_changed(immediate := false) -> void:
	if completion_emitted:
		return
	var now := Time.get_ticks_msec()
	if immediate or now - last_state_emit_msec >= 250:
		last_state_emit_msec = now
		state_changed.emit(state_snapshot())
		return
	if state_emit_pending:
		return
	state_emit_pending = true
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		state_emit_pending = false
		last_state_emit_msec = Time.get_ticks_msec()
		if not completion_emitted:
			state_changed.emit(state_snapshot())
	)


func _vector_to_json(value: Vector2) -> Array:
	return [float(value.x), float(value.y)]


func _json_vector(value, fallback := Vector2.ZERO) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func start(level_config: Dictionary, play_mode: String, source_texture: Texture2D, image: Image, image_size: Vector2, icon_size: float, random_rotation_enabled := false, restore_state := {}) -> bool:
	clear()
	active_level_config = level_config
	current_mode = _mode_key(play_mode)
	texture = source_texture
	source_image = image
	source_size = image_size
	piece_visual_style = _piece_visual_style()
	hud_icon_size = icon_size
	randomize_piece_rotation = random_rotation_enabled and current_mode != "swap"
	completion_emitted = false
	_add_level_background(active_level_config)
	world_root = Node2D.new()
	world_root.name = "world_root"
	add_child(world_root)
	tray_root = Node2D.new()
	tray_root.name = "tray_root"
	tray_root.z_index = TRAY_Z_INDEX
	tray_root.z_as_relative = false
	add_child(tray_root)
	_reset_view_transform()
	var loaded := _start_play_session(current_mode)
	if loaded and typeof(restore_state) == TYPE_DICTIONARY and not restore_state.is_empty():
		apply_state_snapshot(restore_state)
	return loaded


func clear() -> void:
	_clear_swap_target_preview()
	for child in get_children():
		child.queue_free()
	groups.clear()
	tray_groups.clear()
	locked_groups.clear()
	tray_scroll_offset = 0.0
	tray_content_width = 0.0
	tray_panning = false
	tray_pan_last_x = 0.0
	tray_pending_group = null
	tray_pending_start_pos = Vector2.ZERO
	tray_pending_total_delta = Vector2.ZERO
	tray_scroll_velocity = 0.0
	tray_last_pan_msec = 0
	tray_inertia_active = false
	swap_tiles.clear()
	swap_history.clear()
	spawn_bounds.clear()
	dragging = null
	dragging_from_tray = false
	dragging_tray_index = -1
	dragging_original_tray_slot = Rect2()
	tray_drag_offset = Vector2.ZERO
	tray_drag_screen_offset = Vector2.ZERO
	tray_drag_target_screen_offset = Vector2.ZERO
	tray_drag_offset_tween = null
	tray_drag_local_grab = Vector2.ZERO
	tray_drag_scale_tween = null
	dragging_at_tray_scale = false
	last_drag_screen_pos = Vector2.ZERO
	swap_dragging = null
	swap_drag_start_slot = -1
	swap_drag_offset = Vector2.ZERO
	swap_target_preview = null
	swap_target_preview_root = null
	swap_target_preview_line = null
	swap_target_preview_tween = null
	selected_group = null
	hint_highlighted_groups.clear()
	hint_highlighted_lines.clear()
	hint_highlighted_nodes.clear()
	hint_original_modulates.clear()
	hint_blink_tweens.clear()
	hint_highlight_token = 0
	active_hint_key = ""
	hint_expires_at_msec = 0
	hint_pending = false
	hint_tray_scroll_tween = null
	hint_clear_timer = null
	hint_count = 0
	_clear_snap_preview()
	snap_preview_key = ""
	snap_ready_key = ""
	debug_bounds_overlay_enabled = false
	debug_bounds_overlay = null
	drag_blockers.clear()
	active_touch_index = -1
	active_touches.clear()
	panning = false
	pan_touch_index = -1
	pinch_active = false
	world_root = null
	tray_root = null
	tray_background = null
	view_scale = 1.0
	view_target_scale = 1.0
	view_target_ratio = 1.0
	base_view_scale = 1.0
	base_view_offset = Vector2.ZERO
	view_offset = Vector2.ZERO
	view_tween = null
	completion_emitted = false
	randomize_piece_rotation = false
	state_emit_pending = false
	last_state_emit_msec = 0
	undo_available_changed.emit(false)


func handle_input(event: InputEvent, modal_open: bool) -> bool:
	if modal_open:
		return false
	if event is InputEventMagnifyGesture:
		return true
	if event is InputEventPanGesture:
		return false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if _screen_in_drag_blockers(mouse_event.position):
			return false
		if _tray_area().has_point(mouse_event.position) and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_stop_tray_inertia()
			_pan_tray(48.0, false)
			return true
		if _tray_area().has_point(mouse_event.position) and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_stop_tray_inertia()
			_pan_tray(-48.0, false)
			return true
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			return false
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			return false
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			var double_group = _group_at_world(_screen_to_world(mouse_event.position))
			if double_group != null and randomize_piece_rotation:
				_select_group(double_group)
				_rotate_group(double_group)
			elif double_group == null:
				reset_view()
			return true
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_drag(mouse_event.position)
			else:
				_end_drag()
				_end_pan()
			return true
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if tray_pending_group != null:
			_update_pending_tray_drag(motion.position, motion.relative)
			return true
		if tray_panning:
			_pan_tray(motion.relative.x)
			return true
		if swap_dragging != null:
			_move_swap_tile_to(swap_dragging, _screen_to_world(motion.position) + swap_drag_offset)
			return true
		if dragging != null:
			_update_drag_position(motion.position)
			return true
		if panning:
			_pan_view(motion.relative)
			return true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if _screen_in_drag_blockers(touch.position):
			return false
		if touch.pressed:
			_stop_tray_inertia()
			active_touches[touch.index] = touch.position
			if active_touches.size() >= 2:
				pinch_active = false
				return true
			if touch.double_tap:
				var double_group = _group_at_world(_screen_to_world(touch.position))
				if double_group != null and randomize_piece_rotation:
					_select_group(double_group)
					_rotate_group(double_group)
				elif double_group == null:
					reset_view()
			else:
				active_touch_index = touch.index
				_begin_drag(touch.position)
			return true
		active_touches.erase(touch.index)
		if touch.index == active_touch_index:
			_end_drag()
			active_touch_index = -1
		if tray_panning:
			_release_tray_pan()
		if touch.index == pan_touch_index:
			_end_pan()
		if active_touches.size() < 2:
			pinch_active = false
		return true
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		active_touches[drag_event.index] = drag_event.position
		if tray_pending_group != null and drag_event.index == active_touch_index:
			_update_pending_tray_drag(drag_event.position, drag_event.relative)
			return true
		if tray_panning and drag_event.index == active_touch_index:
			_pan_tray(drag_event.relative.x)
			return true
		if pinch_active and active_touches.size() >= 2:
			_update_pinch()
			return true
		if swap_dragging != null and drag_event.index == active_touch_index:
			_move_swap_tile_to(swap_dragging, _screen_to_world(drag_event.position) + swap_drag_offset)
			return true
		if dragging != null and drag_event.index == active_touch_index:
			_update_drag_position(drag_event.position)
			return true
		if panning and drag_event.index == pan_touch_index:
			_pan_view(drag_event.relative)
			return true
	return false


func fit_view_to_pieces(animate := true) -> void:
	if current_mode != "swap":
		_fit_view_to_board_outline(animate, true)
		return
	var bounds := _world_content_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		reset_view()
		return
	_fit_view_to_world_rect(bounds.grow(VIEW_FIT_PADDING), animate, 1.0, true)


func reset_view() -> void:
	_animate_view_to(base_view_scale, base_view_offset, 0.18, current_mode == "swap")


func _reset_view_transform() -> void:
	view_scale = 1.0
	view_target_scale = 1.0
	view_target_ratio = 1.0
	base_view_scale = 1.0
	base_view_offset = Vector2.ZERO
	view_offset = Vector2.ZERO
	_apply_view_transform()


func _apply_view_transform() -> void:
	if world_root == null or not is_instance_valid(world_root):
		return
	world_root.position = view_offset
	world_root.scale = Vector2.ONE * view_scale
	_refresh_hint_line_widths()
	_refresh_snap_preview_line_widths()
	zoom_changed.emit(roundi(_view_ratio() * 100.0))


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - view_offset) / maxf(0.001, view_scale)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return world_pos * view_scale + view_offset


func _view_ratio() -> float:
	return _view_ratio_for_scale(view_scale)


func _view_ratio_for_scale(scale: float) -> float:
	return scale / maxf(0.001, base_view_scale)


func _clamped_actual_scale(scale: float) -> float:
	var min_scale := base_view_scale * VIEW_MIN_RATIO
	var max_scale := base_view_scale * VIEW_MAX_RATIO
	return clampf(scale, min_scale, maxf(min_scale, max_scale))


func _zoom_view_at(screen_anchor: Vector2, target_scale: float) -> void:
	var before := _screen_to_world(screen_anchor)
	view_scale = _clamped_actual_scale(target_scale)
	view_target_scale = view_scale
	view_target_ratio = _view_ratio_for_scale(view_scale)
	view_offset = screen_anchor - before * view_scale
	_clamp_view_to_table()
	_apply_view_transform()
	_notify_state_changed()


func _animate_view_to(target_scale: float, target_offset: Vector2, duration: float, clamp_target := true) -> void:
	if view_tween != null and view_tween.is_valid():
		view_tween.kill()
	view_target_scale = _clamped_actual_scale(target_scale)
	view_target_ratio = _view_ratio_for_scale(view_target_scale)
	var start_scale := view_scale
	var start_offset := view_offset
	var final_scale := view_target_scale
	var final_offset := _clamped_view_offset(target_offset, final_scale) if clamp_target else target_offset
	duration = _motion_duration(duration)
	view_tween = create_tween()
	view_tween.set_ease(Tween.EASE_OUT)
	view_tween.set_trans(Tween.TRANS_CUBIC)
	view_tween.tween_method(func(t: float) -> void:
		view_scale = lerpf(start_scale, final_scale, t)
		view_offset = start_offset.lerp(final_offset, t)
		if clamp_target:
			_clamp_view_to_table()
		_apply_view_transform()
	, 0.0, 1.0, duration)
	view_tween.finished.connect(func() -> void:
		view_scale = final_scale
		view_offset = final_offset
		if clamp_target:
			_clamp_view_to_table()
		_apply_view_transform()
		_notify_state_changed(true)
	)


func _pan_view(delta: Vector2) -> void:
	view_offset += delta
	_clamp_view_to_table()
	_apply_view_transform()
	_notify_state_changed()


func _begin_pan(screen_pos: Vector2, touch_index: int) -> void:
	panning = true
	pan_touch_index = touch_index
	pan_last_screen = screen_pos
	status_changed.emit(_bt("pan_hint"))


func _end_pan() -> void:
	panning = false
	pan_touch_index = -1


func _begin_pinch() -> void:
	_end_drag()
	_end_pan()
	var points := _active_touch_points()
	if points.size() < 2:
		return
	pinch_active = true
	pinch_start_distance = maxf(1.0, points[0].distance_to(points[1]))
	pinch_start_scale = view_scale
	var midpoint := (points[0] + points[1]) * 0.5
	pinch_start_world_midpoint = _screen_to_world(midpoint)


func _update_pinch() -> void:
	var points := _active_touch_points()
	if points.size() < 2:
		return
	var distance := maxf(1.0, points[0].distance_to(points[1]))
	var midpoint := (points[0] + points[1]) * 0.5
	view_scale = _clamped_actual_scale(pinch_start_scale * distance / pinch_start_distance)
	view_target_scale = view_scale
	view_target_ratio = _view_ratio_for_scale(view_scale)
	view_offset = midpoint - pinch_start_world_midpoint * view_scale
	_clamp_view_to_table()
	_apply_view_transform()
	_notify_state_changed()


func _active_touch_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for key in active_touches.keys():
		points.append(active_touches[key])
		if points.size() >= 2:
			break
	return points


func _clamp_view_to_table() -> void:
	view_offset = _clamped_view_offset(view_offset, view_scale)


func _clamped_view_offset(offset: Vector2, scale: float) -> Vector2:
	if current_mode != "swap":
		return _clamped_board_view_offset(offset, scale)
	var view_rect := _world_view_screen_rect()
	var table := _virtual_table_area().grow(VIEW_FIT_PADDING)
	var clamped := offset
	if table.size.x * scale <= view_rect.size.x:
		clamped.x = view_rect.position.x + view_rect.size.x * 0.5 - table.get_center().x * scale
	else:
		var min_x := view_rect.end.x - table.end.x * scale
		var max_x := view_rect.position.x - table.position.x * scale
		clamped.x = clampf(offset.x, min_x, max_x)
	if table.size.y * scale <= view_rect.size.y:
		clamped.y = view_rect.position.y + view_rect.size.y * 0.5 - table.get_center().y * scale
	else:
		var min_y := view_rect.end.y - table.end.y * scale
		var max_y := view_rect.position.y - table.position.y * scale
		clamped.y = clampf(offset.y, min_y, max_y)
	return clamped


func _clamped_board_view_offset(offset: Vector2, scale: float) -> Vector2:
	var view_rect := _world_view_screen_rect()
	var board := _board_outline_world_rect()
	if board.size.x <= 0.0 or board.size.y <= 0.0:
		return offset
	var base_screen := Rect2(board.position * base_view_scale + base_view_offset, board.size * base_view_scale)
	var left_gap := maxf(0.0, base_screen.position.x - view_rect.position.x)
	var right_gap := maxf(0.0, view_rect.end.x - base_screen.end.x)
	var top_gap := maxf(0.0, base_screen.position.y - view_rect.position.y)
	var bottom_gap := maxf(0.0, view_rect.end.y - base_screen.end.y)
	var min_x := view_rect.end.x - right_gap - board.end.x * scale
	var max_x := view_rect.position.x + left_gap - board.position.x * scale
	var min_y := view_rect.end.y - bottom_gap - board.end.y * scale
	var max_y := view_rect.position.y + top_gap - board.position.y * scale
	var clamped := offset
	clamped.x = (min_x + max_x) * 0.5 if min_x > max_x else clampf(offset.x, min_x, max_x)
	clamped.y = (min_y + max_y) * 0.5 if min_y > max_y else clampf(offset.y, min_y, max_y)
	return clamped


func _board_outline_world_rect() -> Rect2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Rect2(board_origin, Vector2.ZERO)
	return Rect2(board_origin, source_size * source_scale).grow(BOARD_OUTLINE_SHADOW_OUTSET)


func _world_view_screen_rect() -> Rect2:
	var viewport := get_viewport_rect().size
	if current_mode == "swap":
		return Rect2(Vector2.ZERO, viewport)
	var tray := _tray_area()
	return Rect2(Vector2.ZERO, Vector2(viewport.x, maxf(120.0, tray.position.y)))


func _fit_view_to_board_outline(animate: bool, set_baseline := false) -> void:
	var board := Rect2(board_origin, source_size * source_scale)
	if board.size.x <= 0.0 or board.size.y <= 0.0:
		return
	var view_rect := _world_view_screen_rect()
	var target_scale := maxf(0.001, (view_rect.size.x - BOARD_SCREEN_EDGE_GAP * 2.0) / maxf(1.0, board.size.x))
	var target_offset := Vector2(
		view_rect.position.x + BOARD_SCREEN_EDGE_GAP - board.position.x * target_scale,
		view_rect.position.y + view_rect.size.y * 0.5 - board.get_center().y * target_scale
	)
	if set_baseline:
		base_view_scale = target_scale
		base_view_offset = target_offset
		view_target_ratio = 1.0
	if animate:
		_animate_view_to(target_scale, target_offset, 0.22, false)
	else:
		view_scale = target_scale
		view_target_scale = target_scale
		view_target_ratio = _view_ratio_for_scale(target_scale)
		view_offset = target_offset
		_apply_view_transform()


func _fit_view_to_world_rect(bounds: Rect2, animate: bool, max_ratio := VIEW_MAX_RATIO, set_baseline := false) -> void:
	var viewport := get_viewport_rect().size
	var target_center := bounds.get_center()
	var target_scale := minf(viewport.x / maxf(1.0, bounds.size.x), viewport.y / maxf(1.0, bounds.size.y))
	target_scale = maxf(0.001, target_scale)
	var target_offset := viewport * 0.5 - target_center * target_scale
	target_offset = _clamped_view_offset(target_offset, target_scale)
	if set_baseline:
		base_view_scale = target_scale
		base_view_offset = target_offset
		view_target_ratio = 1.0
	else:
		target_scale = _clamped_actual_scale(clampf(target_scale, base_view_scale * VIEW_MIN_RATIO, base_view_scale * minf(max_ratio, VIEW_MAX_RATIO)))
		target_offset = viewport * 0.5 - target_center * target_scale
		target_offset = _clamped_view_offset(target_offset, target_scale)
	if animate:
		_animate_view_to(target_scale, target_offset, 0.22)
	else:
		view_scale = target_scale
		view_target_scale = target_scale
		view_target_ratio = _view_ratio_for_scale(target_scale)
		view_offset = target_offset
		_clamp_view_to_table()
		_apply_view_transform()


func _base_view_bounds() -> Rect2:
	var board := Rect2(board_origin, source_size * source_scale).grow(VIEW_FIT_PADDING)
	return board.merge(_virtual_table_area())


func _world_content_bounds() -> Rect2:
	var bounds := Rect2(board_origin, source_size * source_scale)
	var has_bounds := bounds.size.x > 0.0 and bounds.size.y > 0.0
	for tile in swap_tiles:
		var tile_bounds := _swap_tile_bounds(tile, tile["node"].position)
		if tile_bounds.size.x <= 0.0 or tile_bounds.size.y <= 0.0:
			continue
		bounds = bounds.merge(tile_bounds) if has_bounds else tile_bounds
		has_bounds = true
	for group in groups:
		if group.in_tray:
			continue
		var group_bounds := _group_bounds_at(group, group.node.position)
		if group_bounds.size.x <= 0.0 or group_bounds.size.y <= 0.0:
			continue
		bounds = bounds.merge(group_bounds) if has_bounds else group_bounds
		has_bounds = true
	return bounds if has_bounds else _base_view_bounds()


func _focus_hint_pair(pair: Array) -> void:
	if pair.is_empty():
		return
	var hint_group = pair[0]
	var bounds := _group_bounds_at(hint_group, hint_group.anchor_home)
	if not hint_group.in_tray:
		bounds = bounds.merge(_group_bounds_at(hint_group, hint_group.node.position))
	if pair.size() > 1 and not pair[1].in_tray:
		bounds = bounds.merge(_group_bounds_at(pair[1], pair[1].node.position))
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	_pan_hint_bounds_into_view(bounds.grow(VIEW_HINT_PADDING))


func _pan_hint_bounds_into_view(bounds: Rect2) -> void:
	var view_rect := _world_view_screen_rect().grow(-BOARD_SCREEN_EDGE_GAP)
	if view_rect.size.x <= 0.0 or view_rect.size.y <= 0.0:
		return
	var screen_bounds := Rect2(_world_to_screen(bounds.position), bounds.size * view_scale)
	if view_rect.encloses(screen_bounds):
		return
	var target_offset := view_offset
	if screen_bounds.size.x > view_rect.size.x:
		target_offset.x += view_rect.get_center().x - screen_bounds.get_center().x
	elif screen_bounds.position.x < view_rect.position.x:
		target_offset.x += view_rect.position.x - screen_bounds.position.x
	elif screen_bounds.end.x > view_rect.end.x:
		target_offset.x -= screen_bounds.end.x - view_rect.end.x
	if screen_bounds.size.y > view_rect.size.y:
		target_offset.y += view_rect.get_center().y - screen_bounds.get_center().y
	elif screen_bounds.position.y < view_rect.position.y:
		target_offset.y += view_rect.position.y - screen_bounds.position.y
	elif screen_bounds.end.y > view_rect.end.y:
		target_offset.y -= screen_bounds.end.y - view_rect.end.y
	target_offset = _clamped_view_offset(target_offset, view_scale)
	if target_offset.distance_squared_to(view_offset) <= 0.01:
		return
	_animate_view_to(view_scale, target_offset, 0.18)


func show_hint() -> void:
	if _hint_in_progress():
		return
	hint_count += 1
	_notify_state_changed(true)
	if current_mode == "swap":
		_show_swap_hint()
		return
	var pair := _find_hint_pair()
	if pair.is_empty():
		_clear_hint_highlights()
		status_changed.emit(_bt("hint_none"))
		return
	hint_pending = true
	status_changed.emit(_bt("hint_pair"))
	_animate_tray_scroll_to_group(pair[0], func() -> void:
		if not hint_pending:
			return
		hint_pending = false
		_set_hint_highlights(pair)
		_bring_hint_group_to_front(pair[0])
		_focus_hint_pair(pair)
	)


func _hint_in_progress() -> bool:
	if hint_pending:
		return true
	return _has_active_hint_highlights() and Time.get_ticks_msec() < hint_expires_at_msec


func _animate_tray_scroll_to_group(group, on_done: Callable) -> void:
	if group == null or not group.in_tray:
		on_done.call()
		return
	var area := _tray_area().grow(-TRAY_PADDING)
	var target_offset := tray_scroll_offset
	if group.tray_slot.position.x < area.position.x:
		target_offset -= area.position.x - group.tray_slot.position.x
	elif group.tray_slot.end.x > area.end.x:
		target_offset += group.tray_slot.end.x - area.end.x
	target_offset = clampf(target_offset, 0.0, maxf(0.0, tray_content_width - _tray_area().size.x + TRAY_PADDING))
	if absf(target_offset - tray_scroll_offset) < 1.0:
		on_done.call()
		return
	_stop_tray_inertia()
	if hint_tray_scroll_tween != null and hint_tray_scroll_tween.is_valid():
		hint_tray_scroll_tween.kill()
	hint_tray_scroll_tween = create_tween()
	hint_tray_scroll_tween.set_ease(Tween.EASE_OUT)
	hint_tray_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	hint_tray_scroll_tween.tween_method(func(value: float) -> void:
		tray_scroll_offset = value
		_layout_tray(true)
	, tray_scroll_offset, target_offset, HINT_TRAY_SCROLL_TIME)
	hint_tray_scroll_tween.finished.connect(on_done)


func set_drag_blockers(blockers: Array[Rect2]) -> void:
	drag_blockers = blockers.duplicate()


func debug_runtime_metrics() -> Dictionary:
	var area := _tray_area()
	var pieces: Array = []
	for group in tray_groups:
		if group == null or not is_instance_valid(group.node):
			continue
		var bounds := _group_local_bounds(group)
		pieces.append({
			"id": _debug_group_id(group),
			"in_tray": group.in_tray,
			"screen_height": bounds.size.y * _tray_original_screen_scale(),
			"scale": group.tray_scale,
			"slot_x": group.tray_slot.position.x,
			"slot_w": group.tray_slot.size.x,
		})
	return {
		"mode": current_mode,
		"groups": groups.size(),
		"locked_groups": locked_groups.size(),
		"tray_groups": tray_groups.size(),
		"tray": {
			"height": area.size.y,
			"usable_height": maxf(24.0, area.size.y - TRAY_VERTICAL_SAFE_GAP * 2.0),
			"vertical_gap": TRAY_VERTICAL_SAFE_GAP,
			"scroll": tray_scroll_offset,
			"content_width": tray_content_width,
			"velocity": tray_scroll_velocity,
			"count": tray_groups.size(),
			"pieces": pieces,
		},
		"hint": {
			"nodes": hint_highlighted_nodes.size(),
			"lines": hint_highlighted_lines.size(),
			"key": active_hint_key,
		},
	}


func debug_clear_hint() -> void:
	_clear_hint_highlights()


func debug_reset_tray() -> void:
	tray_scroll_offset = 0.0
	tray_scroll_velocity = 0.0
	_layout_tray(false)


func debug_scroll_tray_left() -> void:
	tray_scroll_offset = 0.0
	tray_scroll_velocity = 0.0
	_layout_tray(true)


func debug_scroll_tray_right() -> void:
	tray_scroll_offset = maxf(0.0, tray_content_width - _tray_area().size.x + TRAY_PADDING)
	tray_scroll_velocity = 0.0
	_layout_tray(true)


func debug_toggle_bounds_overlay() -> void:
	debug_bounds_overlay_enabled = not debug_bounds_overlay_enabled
	if not debug_bounds_overlay_enabled:
		_clear_debug_bounds_overlay()
		return
	_refresh_debug_bounds_overlay()


func debug_run_interaction_smoke() -> Dictionary:
	var result := {
		"mode": current_mode,
		"tray_scroll": true,
		"pickup_drop": false,
		"hint": false,
		"snap_preview": true,
		"snap_shimmer_only": true,
		"swap_preview": true,
		"snap": true,
		"undo": true,
		"complete": false,
	}
	if current_mode == "swap":
		await _debug_smoke_swap(result)
	else:
		await _debug_smoke_piece_mode(result)
	var ok := true
	for key in ["tray_scroll", "pickup_drop", "hint", "snap_preview", "snap_shimmer_only", "swap_preview", "snap", "undo", "complete"]:
		ok = ok and bool(result.get(key, false))
	result["ok"] = ok
	return result


func _debug_smoke_piece_mode(result: Dictionary) -> void:
	var tray_wait_started := Time.get_ticks_msec()
	while _debug_tray_animation_active() and Time.get_ticks_msec() - tray_wait_started < 1200:
		await get_tree().create_timer(0.02).timeout
	var max_scroll := maxf(0.0, tray_content_width - _tray_area().size.x + TRAY_PADDING)
	debug_scroll_tray_left()
	if max_scroll > 1.0 and not tray_groups.is_empty():
		var scroll_start: Vector2 = tray_groups[0].tray_slot.get_center()
		var scroll_end := scroll_start + Vector2(-minf(180.0, _tray_area().size.x * 0.28), 0.0)
		handle_input(_debug_mouse_button(scroll_start, true), false)
		handle_input(_debug_mouse_motion(scroll_end, scroll_end - scroll_start), false)
		handle_input(_debug_mouse_button(scroll_end, false), false)
		result["tray_scroll"] = tray_scroll_offset > 0.5
	else:
		result["tray_scroll"] = true
	debug_scroll_tray_left()
	if not tray_groups.is_empty():
		var picked = tray_groups[0]
		var center: Vector2 = picked.tray_slot.get_center()
		var lift_position := Vector2(center.x, _tray_area().position.y - 72.0)
		var drop_position := lift_position + Vector2(0.0, -64.0)
		handle_input(_debug_mouse_button(center, true), false)
		handle_input(_debug_mouse_motion(lift_position, lift_position - center), false)
		handle_input(_debug_mouse_motion(drop_position, drop_position - lift_position), false)
		var lifted: bool = dragging == picked and not picked.in_tray
		handle_input(_debug_mouse_button(drop_position, false), false)
		await get_tree().process_frame
		result["pickup_drop"] = lifted and picked.in_tray and dragging == null
	show_hint()
	var hint_wait_started := Time.get_ticks_msec()
	while hint_pending and Time.get_ticks_msec() - hint_wait_started < 1200:
		await get_tree().create_timer(0.02).timeout
	result["hint"] = _has_active_hint_highlights()
	debug_clear_hint()
	var pair := _find_hint_pair()
	if pair.is_empty():
		result["snap_preview"] = false
		result["snap_shimmer_only"] = false
		result["snap"] = false
	else:
		var active = pair[0]
		_send_group_to_world(active, active.anchor_home + Vector2(_snap_tolerance() * 1.05, 0.0))
		active.node.scale = Vector2.ONE
		_update_snap_preview(active)
		var outside_hidden := snap_preview_lines.is_empty()
		active.node.position = active.anchor_home + Vector2(_snap_tolerance() * 0.92, 0.0)
		_update_snap_preview(active)
		result["snap_preview"] = outside_hidden and not snap_preview_lines.is_empty()
		var group_count_before := groups.size()
		PieceVisualFactoryScript.set_group_lifted(active, true, self, false)
		dragging = active
		dragging_from_tray = false
		_end_drag()
		var scale_reset := true
		var shimmer_visible := false
		for member in active.members:
			var visual: Node2D = member.get("visual", null)
			if visual == null or not is_instance_valid(visual):
				continue
			scale_reset = scale_reset and visual.scale.is_equal_approx(Vector2.ONE)
			shimmer_visible = shimmer_visible or visual.get_node_or_null("snap_shimmer") != null
		result["snap_shimmer_only"] = scale_reset and (reduced_motion or shimmer_visible)
		result["snap"] = groups.size() < group_count_before and active.locked and dragging == null
		_clear_snap_preview()
	debug_force_complete()
	result["complete"] = completion_emitted


func _debug_tray_animation_active() -> bool:
	for group in tray_groups:
		if group != null and group.is_animating:
			return true
	return false


func _debug_mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	return event


func _debug_mouse_motion(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


func _debug_smoke_swap(result: Dictionary) -> void:
	show_hint()
	await get_tree().process_frame
	result["hint"] = _has_active_hint_highlights()
	debug_clear_hint()
	var pair := _find_swap_hint_pair()
	if pair.size() < 2:
		result["pickup_drop"] = false
		result["swap_preview"] = false
		result["undo"] = false
	else:
		var first = pair[0]
		var second = pair[1]
		var first_slot := int(first["slot_index"])
		var second_slot := int(second["slot_index"])
		var first_center: Vector2 = first["node"].position + first["size"] * 0.5
		_begin_swap_drag(_world_to_screen(first_center))
		var lifted: bool = swap_dragging == first
		_move_swap_tile_to(first, second["node"].position)
		result["swap_preview"] = swap_target_preview == second and swap_target_preview_root != null and is_instance_valid(swap_target_preview_root)
		_end_swap_drag()
		await get_tree().create_timer(_motion_duration(SWAP_ANIMATION_TIME) + 0.03).timeout
		var swapped := int(first["slot_index"]) == second_slot and int(second["slot_index"]) == first_slot
		result["pickup_drop"] = lifted and swapped and swap_dragging == null
		var undo_was_available := can_undo_swap()
		undo_last_swap()
		await get_tree().create_timer(_motion_duration(SWAP_ANIMATION_TIME) + 0.03).timeout
		result["undo"] = undo_was_available and int(first["slot_index"]) == first_slot and int(second["slot_index"]) == second_slot
	debug_force_complete()
	result["complete"] = completion_emitted


func debug_force_complete() -> void:
	_clear_hint_highlights()
	_clear_snap_preview()
	if current_mode == "swap":
		for tile in swap_tiles:
			tile["slot_index"] = int(tile["correct_index"])
			tile["node"].position = _swap_slot_position(int(tile["correct_index"]), _swap_cols(), _swap_rows())
		_check_swap_complete()
		return
	for group in groups.duplicate():
		if group.locked:
			continue
		_send_group_to_world(group, group.anchor_home)
		group.locked = true
		group.in_tray = false
		group.node.position = group.anchor_home
		group.node.rotation_degrees = 0.0
		group.node.scale = Vector2.ONE
		PieceVisualFactoryScript.add_seam_outline(group, _seam_line_width())
		if not locked_groups.has(group):
			locked_groups.append(group)
	tray_groups.clear()
	_layout_tray(true)
	_check_complete()


func debug_prepare_restore_snapshot() -> Dictionary:
	hint_count = 2
	_zoom_view_at(_world_view_screen_rect().get_center(), base_view_scale * 1.45)
	if current_mode == "swap":
		var pair := _find_swap_hint_pair()
		if pair.size() >= 2:
			var first = pair[0]
			var second = pair[1]
			var first_slot := int(first["slot_index"])
			var second_slot := int(second["slot_index"])
			swap_history.append({
				"first": int(first["correct_index"]),
				"second": int(second["correct_index"]),
				"first_slot": first_slot,
				"second_slot": second_slot,
			})
			first["slot_index"] = second_slot
			second["slot_index"] = first_slot
			first["node"].position = _swap_slot_position(second_slot, _swap_cols(), _swap_rows())
			second["node"].position = _swap_slot_position(first_slot, _swap_cols(), _swap_rows())
			undo_available_changed.emit(true)
	else:
		var pair := _find_hint_pair()
		if not pair.is_empty():
			var active = pair[0]
			_send_group_to_world(active, active.anchor_home)
			if _try_snap_chain(active):
				_lock_group(active)
		debug_scroll_tray_right()
	return state_snapshot()


func debug_validate_restored_snapshot(expected: Dictionary) -> Dictionary:
	var actual := state_snapshot()
	var checks := {
		"mode": str(actual.get("mode", "")) == str(expected.get("mode", "")),
		"hint_count": int(actual.get("hint_count", -1)) == int(expected.get("hint_count", -2)),
		"view": _debug_view_state_matches(actual.get("view", {}), expected.get("view", {})),
		"tray_scroll": absf(float(actual.get("tray", {}).get("scroll_ratio", 0.0)) - float(expected.get("tray", {}).get("scroll_ratio", 0.0))) <= 0.01,
	}
	if current_mode == "swap":
		checks["pieces"] = _debug_swap_state_matches(actual.get("tiles", []), expected.get("tiles", []))
		checks["history"] = actual.get("swap_history", []).size() == expected.get("swap_history", []).size()
	else:
		checks["pieces"] = _debug_group_state_matches(actual.get("groups", []), expected.get("groups", []))
		checks["tray_order"] = actual.get("tray_order", []) == expected.get("tray_order", [])
	var ok := true
	for value in checks.values():
		ok = ok and bool(value)
	return {
		"mode": current_mode,
		"ok": ok,
		"checks": checks,
		"tray_scroll": {
			"actual": float(actual.get("tray", {}).get("scroll", 0.0)),
			"expected": float(expected.get("tray", {}).get("scroll", 0.0)),
			"actual_ratio": float(actual.get("tray", {}).get("scroll_ratio", 0.0)),
			"expected_ratio": float(expected.get("tray", {}).get("scroll_ratio", 0.0)),
		},
	}


func _debug_view_state_matches(actual, expected) -> bool:
	if typeof(actual) != TYPE_DICTIONARY or typeof(expected) != TYPE_DICTIONARY:
		return false
	return absf(float(actual.get("ratio", 1.0)) - float(expected.get("ratio", 1.0))) <= 0.01 \
		and _json_vector(actual.get("offset", [])).distance_to(_json_vector(expected.get("offset", []))) <= 1.0


func _debug_swap_state_matches(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	var actual_slots := {}
	for item in actual:
		actual_slots[int(item.get("correct_index", -1))] = int(item.get("slot_index", -1))
	for item in expected:
		if int(actual_slots.get(int(item.get("correct_index", -1)), -2)) != int(item.get("slot_index", -1)):
			return false
	return true


func _debug_group_state_matches(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	var actual_keys: Array[String] = []
	var expected_keys: Array[String] = []
	for item in actual:
		var ids: Array = item.get("members", []).duplicate()
		ids.sort()
		actual_keys.append("|".join(ids))
	for item in expected:
		var ids: Array = item.get("members", []).duplicate()
		ids.sort()
		expected_keys.append("|".join(ids))
	actual_keys.sort()
	expected_keys.sort()
	return actual_keys == expected_keys


func _screen_in_drag_blockers(screen_pos: Vector2) -> bool:
	for blocker in drag_blockers:
		if blocker.has_point(screen_pos):
			return true
	return false


func _start_play_session(play_mode: String) -> bool:
	if _mode_key(play_mode) == "swap":
		return _start_swap_session()
	var level := _level_from_mode_pieces(play_mode)
	if level.is_empty():
		return false
	source_scale = level["source_scale"]
	board_origin = level["board_origin"]
	spawn_bounds.clear()
	_add_board_outline_shadow()
	var sorted_pieces: Array = level["pieces"].duplicate()
	sorted_pieces.sort_custom(func(a, b) -> bool:
		return _points_bounds_area(a["bounds_points"]) > _points_bounds_area(b["bounds_points"])
	)
	var seed_ids := _seed_piece_ids(sorted_pieces, _mode_config(active_level_config, play_mode))
	for piece in sorted_pieces:
		var is_seed := seed_ids.has(str(piece.get("id", "")))
		_create_group(piece, is_seed)
	tray_scroll_offset = 0.0
	_layout_tray(true)
	fit_view_to_pieces(false)
	for group in locked_groups:
		PieceVisualFactoryScript.add_seam_outline(group, _seam_line_width())
	return true


func _level_from_mode_pieces(play_mode: String) -> Dictionary:
	var config := _mode_config(active_level_config, play_mode)
	if config.is_empty():
		return {}
	var source_pieces: Array = []
	if config.has("pieces") and typeof(config["pieces"]) == TYPE_ARRAY:
		source_pieces = config["pieces"]
	if source_pieces.is_empty() and _mode_key(play_mode) == "knob":
		source_pieces = _generated_knob_source_pieces(config)
	if source_pieces.is_empty():
		return {}
	var layout := _mobile_board_layout()
	var mode_source_scale: float = layout["source_scale"]
	var mode_board_origin: Vector2 = layout["board_origin"]
	var board_size: Vector2 = layout["board_size"]
	var pieces: Array[Dictionary] = []
	for source_piece in source_pieces:
		if typeof(source_piece) != TYPE_DICTIONARY:
			continue
		var piece_data: Dictionary = source_piece
		var source_polygon := _json_points(piece_data.get("points", []))
		if source_polygon.size() < 3:
			continue
		var home_source := _json_point(piece_data.get("home", _polygon_center(source_polygon)))
		var home := mode_board_origin + home_source * mode_source_scale
		var local_polygon := PackedVector2Array()
		var uvs := PackedVector2Array()
		for source_point in source_polygon:
			var display_point := mode_board_origin + source_point * mode_source_scale
			local_polygon.append(display_point - home)
			uvs.append(source_point)
		var visible_source_rect := _json_rect(
			piece_data.get("visible_bounds", []),
			Rect2()
		)
		if visible_source_rect.size.x <= 0.0 or visible_source_rect.size.y <= 0.0:
			visible_source_rect = _visible_source_rect_for_polygon(source_polygon, _source_rect_for_points(source_polygon))
		var visible_source_rects := _json_rects(piece_data.get("visible_bounds_list", []))
		if visible_source_rects.is_empty():
			visible_source_rects = [visible_source_rect]
		var bounds_points_list: Array[PackedVector2Array] = []
		for source_rect in visible_source_rects:
			bounds_points_list.append(_local_rect_points(source_rect, home, mode_source_scale, mode_board_origin))
		var cut_lines: Array[PackedVector2Array] = []
		if piece_data.has("cut_lines") and typeof(piece_data["cut_lines"]) == TYPE_ARRAY:
			for line_data in piece_data["cut_lines"]:
				var source_line := _json_points(line_data)
				if source_line.size() < 2:
					continue
				for local_line in _visible_cut_line_segments(source_line, home, mode_source_scale, mode_board_origin):
					cut_lines.append(local_line)
		pieces.append({
			"id": str(piece_data.get("id", "piece_%d" % pieces.size())),
			"cell": _json_cell(piece_data.get("cell", [0, 0])),
			"home": home,
			"polygon": local_polygon,
			"uv": uvs,
			"neighbors": piece_data.get("neighbors", []),
			"source_rect": _source_rect_for_points(source_polygon),
			"bounds_points": _local_rect_points(visible_source_rect, home, mode_source_scale, mode_board_origin),
			"bounds_points_list": bounds_points_list,
			"cut_lines": cut_lines,
		})
	return {
		"pieces": pieces,
		"board_origin": mode_board_origin,
		"board_size": board_size,
		"source_scale": mode_source_scale,
		"play_area": layout["play_area"],
	}


func _generated_knob_source_pieces(config: Dictionary) -> Array:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return []
	var cols: int = maxi(1, int(config.get("cols", 6)))
	var rows: int = maxi(1, int(config.get("rows", 8)))
	var cell_size := Vector2(source_size.x / float(cols), source_size.y / float(rows))
	var knob_amount := minf(cell_size.x, cell_size.y) * float(config.get("knob_size", 0.24))
	var pieces := []
	for row in range(rows):
		for col in range(cols):
			var x0 := float(col) * cell_size.x
			var y0 := float(row) * cell_size.y
			var x1 := float(col + 1) * cell_size.x
			var y1 := float(row + 1) * cell_size.y
			var points: Array = []
			_append_knob_edge(points, Vector2(x0, y0), Vector2(x1, y0), Vector2(0, -1), 0 if row == 0 else -_knob_horizontal_sign(col, row), knob_amount)
			_append_knob_edge(points, Vector2(x1, y0), Vector2(x1, y1), Vector2(1, 0), 0 if col == cols - 1 else _knob_vertical_sign(col + 1, row), knob_amount)
			_append_knob_edge(points, Vector2(x1, y1), Vector2(x0, y1), Vector2(0, 1), 0 if row == rows - 1 else _knob_horizontal_sign(col, row + 1), knob_amount)
			_append_knob_edge(points, Vector2(x0, y1), Vector2(x0, y0), Vector2(-1, 0), 0 if col == 0 else -_knob_vertical_sign(col, row), knob_amount)
			var neighbors := []
			if col > 0:
				neighbors.append("knob_%d_%d" % [row, col - 1])
			if col < cols - 1:
				neighbors.append("knob_%d_%d" % [row, col + 1])
			if row > 0:
				neighbors.append("knob_%d_%d" % [row - 1, col])
			if row < rows - 1:
				neighbors.append("knob_%d_%d" % [row + 1, col])
			pieces.append({
				"id": "knob_%d_%d" % [row, col],
				"points": points,
				"home": [x0 + cell_size.x * 0.5, y0 + cell_size.y * 0.5],
				"neighbors": neighbors,
				"visible_bounds": [x0 - knob_amount, y0 - knob_amount, cell_size.x + knob_amount * 2.0, cell_size.y + knob_amount * 2.0],
				"cell": [col, row],
			})
	return pieces


func _append_knob_edge(target: Array, start: Vector2, end: Vector2, normal: Vector2, sign: int, amount: float) -> void:
	var edge_points := _knob_edge_points(start, end, normal, sign, amount)
	for index in range(edge_points.size()):
		if target.size() > 0 and index == 0:
			continue
		var point: Vector2 = edge_points[index]
		target.append([point.x, point.y])


func _knob_edge_points(start: Vector2, end: Vector2, normal: Vector2, sign: int, amount: float) -> Array[Vector2]:
	if sign == 0:
		return [start, end]
	var edge := end - start
	var edge_length := edge.length()
	if edge_length <= 0.0 or amount <= 0.0:
		return [start, end]
	var tangent := edge / edge_length
	var signed_normal := normal * float(sign)
	var center_on_edge := start.lerp(end, 0.5)
	var radius := amount / (1.0 + sqrt(0.5))
	var half_chord := radius * sqrt(0.5)
	var center := center_on_edge + signed_normal * half_chord
	var before := center_on_edge - tangent * half_chord
	var after := center_on_edge + tangent * half_chord
	var points: Array[Vector2] = [start, before]
	var steps := 18
	for step in range(1, steps):
		var t := float(step) / float(steps)
		var angle := PI * 1.25 - PI * 1.5 * t
		points.append(center + tangent * cos(angle) * radius + signed_normal * sin(angle) * radius)
	points.append(after)
	points.append(end)
	return points


func _knob_vertical_sign(edge_col: int, row: int) -> int:
	return 1 if int(edge_col + row) % 2 == 0 else -1


func _knob_horizontal_sign(col: int, edge_row: int) -> int:
	return 1 if int(col + edge_row) % 2 == 0 else -1


func _start_swap_session() -> bool:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return false
	var grid := _swap_grid_config()
	var cols: int = grid["cols"]
	var rows: int = grid["rows"]
	var layout := _mobile_board_layout()
	source_scale = layout["source_scale"]
	board_origin = layout["board_origin"]
	var order := _swap_shuffled_order(cols, rows)
	swap_history.clear()
	undo_available_changed.emit(false)
	for slot_index in range(order.size()):
		_create_swap_tile(int(order[slot_index]), slot_index, cols, rows)
	fit_view_to_pieces(false)
	status_changed.emit(_bt("status_swap"))
	return true


func _create_swap_tile(correct_index: int, slot_index: int, cols: int, rows: int) -> void:
	var tile_source_size := Vector2(source_size.x / float(cols), source_size.y / float(rows))
	var source_col := correct_index % cols
	var source_row := int(correct_index / cols)
	var source_rect := Rect2(Vector2(source_col, source_row) * tile_source_size, tile_source_size)
	var display_size := tile_source_size * source_scale
	var polygon := PackedVector2Array([
		Vector2.ZERO,
		Vector2(display_size.x, 0.0),
		display_size,
		Vector2(0.0, display_size.y),
	])
	var uv := PackedVector2Array([
		source_rect.position,
		Vector2(source_rect.end.x, source_rect.position.y),
		source_rect.end,
		Vector2(source_rect.position.x, source_rect.end.y),
	])
	var node := Node2D.new()
	node.name = "swap_tile_%02d" % correct_index
	node.z_index = swap_tiles.size() * GROUP_Z_STEP
	world_root.add_child(node)
	var piece := {
		"id": node.name,
		"polygon": polygon,
		"uv": uv,
		"cut_lines": [],
	}
	node.add_child(PieceVisualFactoryScript.create_piece_visual(piece, texture, piece_visual_style))
	var tile := {
		"node": node,
		"correct_index": correct_index,
		"slot_index": slot_index,
		"size": display_size,
		"is_animating": false,
	}
	swap_tiles.append(tile)
	node.position = _swap_slot_position(slot_index, cols, rows)


func _swap_shuffled_order(cols: int, rows: int) -> Array:
	var total := cols * rows
	var base := []
	for index in range(total):
		base.append(index)
	var local_rng := RandomNumberGenerator.new()
	local_rng.randomize()
	for attempt in range(3000):
		var candidate := base.duplicate()
		_shuffle_array(candidate, local_rng)
		if _is_valid_swap_order(candidate, cols, rows):
			return candidate
	var fallback := []
	for index in range(total - 1, -1, -2):
		fallback.append(index)
	for index in range(total - 2, -1, -2):
		fallback.append(index)
	return fallback if _is_valid_swap_order(fallback, cols, rows) else base


func _shuffle_array(items: Array, local_rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other := local_rng.randi_range(0, index)
		var value = items[index]
		items[index] = items[other]
		items[other] = value


func _is_valid_swap_order(order: Array, cols: int, rows: int) -> bool:
	for slot in range(order.size()):
		if int(order[slot]) == slot:
			return false
		var col := slot % cols
		var row := int(slot / cols)
		var current := int(order[slot])
		if col < cols - 1:
			var right := int(order[slot + 1])
			if right == current + 1 and int(current / cols) == int(right / cols):
				return false
		if row < rows - 1:
			var below := int(order[slot + cols])
			if below == current + cols:
				return false
	return true


func _swap_slot_position(slot_index: int, cols := SWAP_FALLBACK_COLS, rows := SWAP_FALLBACK_ROWS) -> Vector2:
	var tile_size := Vector2(source_size.x / float(cols), source_size.y / float(rows)) * source_scale
	var col := slot_index % cols
	var row := int(slot_index / cols)
	return board_origin + Vector2(col * tile_size.x, row * tile_size.y)


func _mobile_board_layout() -> Dictionary:
	return BoardLayoutScript.mobile_board_layout(
		source_size,
		get_viewport_rect().size,
		active_level_config,
		_current_mode_piece_count(),
		hud_icon_size
	)


func _current_mode_piece_count() -> int:
	if current_mode == "swap":
		var grid := _swap_grid_config()
		return int(grid["cols"]) * int(grid["rows"])
	var config := _mode_config(active_level_config, current_mode)
	if config.has("pieces") and typeof(config["pieces"]) == TYPE_ARRAY:
		var pieces: Array = config["pieces"]
		if not pieces.is_empty():
			return pieces.size()
	if current_mode == "knob":
		return max(1, int(config.get("cols", 6))) * max(1, int(config.get("rows", 8)))
	return 0


func _swap_grid_config() -> Dictionary:
	var config := _mode_config(active_level_config, "swap")
	var configured_cols := int(config.get("cols", 0))
	var configured_rows := int(config.get("rows", 0))
	if configured_cols > 0 and configured_rows > 0:
		return {
			"cols": configured_cols,
			"rows": configured_rows,
		}
	return _auto_swap_grid()


func _auto_swap_grid() -> Dictionary:
	return {
		"cols": SWAP_FALLBACK_COLS,
		"rows": SWAP_FALLBACK_ROWS,
	}


func _mode_key(play_mode: String) -> String:
	return "knob" if play_mode == "classic" else play_mode


func _mode_config(level_config: Dictionary, play_mode: String) -> Dictionary:
	var mode := _mode_key(play_mode)
	if not level_config.has("modes") or typeof(level_config["modes"]) != TYPE_DICTIONARY:
		return {}
	var modes: Dictionary = level_config["modes"]
	if not modes.has(mode) or typeof(modes[mode]) != TYPE_DICTIONARY:
		return {}
	return modes[mode]


func _json_points(value) -> PackedVector2Array:
	var points := PackedVector2Array()
	if typeof(value) != TYPE_ARRAY:
		return points
	for item in value:
		points.append(_json_point(item))
	return points


func _json_point(value) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO


func _json_cell(value) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _json_rect(value, fallback: Rect2) -> Rect2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 4:
		return Rect2(
			Vector2(float(value[0]), float(value[1])),
			Vector2(maxf(1.0, float(value[2])), maxf(1.0, float(value[3])))
		)
	return fallback


func _json_rects(value) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if typeof(value) != TYPE_ARRAY:
		return rects
	for item in value:
		var rect := _json_rect(item, Rect2())
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			rects.append(rect)
	return rects


func _local_rect_points(source_rect: Rect2, home: Vector2, scale: float, origin: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var source_points := [
		source_rect.position,
		Vector2(source_rect.end.x, source_rect.position.y),
		source_rect.end,
		Vector2(source_rect.position.x, source_rect.end.y),
	]
	for source_point in source_points:
		points.append(origin + source_point * scale - home)
	return points


func _polygon_center(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / max(1, points.size())


func _source_rect_for_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


func _points_bounds_area(points: PackedVector2Array) -> float:
	var bounds := _source_rect_for_points(points)
	return bounds.size.x * bounds.size.y


func _visible_source_rect_for_polygon(points: PackedVector2Array, fallback: Rect2) -> Rect2:
	var bounds := _source_rect_for_points(points)
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	var found := false
	for y in range(floori(bounds.position.y), ceili(bounds.end.y) + 1):
		for x in range(floori(bounds.position.x), ceili(bounds.end.x) + 1):
			var point := Vector2(x, y)
			if not Geometry2D.is_point_in_polygon(point, points):
				continue
			if not _source_point_has_alpha(point, 0):
				continue
			min_point = min_point.min(point)
			max_point = max_point.max(point)
			found = true
	if not found:
		return fallback
	return Rect2(min_point, max_point - min_point).grow(2.0)


func _add_level_background(level_config: Dictionary) -> void:
	var viewport_size := get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = _level_background_color(level_config)
	bg.position = Vector2.ZERO
	bg.size = viewport_size
	bg.z_index = -101
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if not level_config.has("background") or typeof(level_config["background"]) != TYPE_DICTIONARY:
		return
	var bg_config: Dictionary = level_config["background"]
	if str(bg_config.get("type", "color")) != "image":
		return
	var bg_texture: Texture2D = load(str(bg_config.get("path", "")))
	if bg_texture == null:
		return
	var bg_image := TextureRect.new()
	bg_image.texture = bg_texture
	bg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_image.position = Vector2.ZERO
	bg_image.size = viewport_size
	bg_image.z_index = -100
	bg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_image)


func _level_background_color(level_config: Dictionary) -> Color:
	if level_config.has("background") and typeof(level_config["background"]) == TYPE_DICTIONARY:
		var bg: Dictionary = level_config["background"]
		if str(bg.get("type", "color")) == "color":
			return Color(str(bg.get("color", "#ead8bd")))
	return Color("#ead8bd")


func _piece_visual_style() -> Dictionary:
	var configured = active_level_config.get("piece_style", {})
	if edge_contrast_mode == "auto" and typeof(configured) == TYPE_DICTIONARY:
		var line_value := str(configured.get("line_color", ""))
		if not line_value.is_empty():
			var line_color := Color.from_string(line_value, PieceVisualFactoryScript.CUT_LINE_COLOR)
			var seam_color := Color.from_string(str(configured.get("seam_color", line_value)), line_color)
			return {
				"cut_line_color": line_color,
				"cut_line_lift_color": Color("#D98A43"),
				"seam_line_color": seam_color,
			}
	var use_light := edge_contrast_mode == "light" or (edge_contrast_mode == "auto" and _source_average_luminance() < 0.46)
	if use_light:
		return {
			"cut_line_color": Color(1.0, 0.98, 0.91, 0.90),
			"cut_line_lift_color": Color(1.0, 0.78, 0.38, 0.96),
			"seam_line_color": Color(1.0, 0.98, 0.91, 0.40),
		}
	return {
		"cut_line_color": Color(0.16, 0.12, 0.09, 0.78),
		"cut_line_lift_color": Color(0.78, 0.43, 0.12, 0.90),
		"seam_line_color": Color(0.0, 0.0, 0.0, 0.26),
	}


func _source_average_luminance() -> float:
	if source_image == null or source_image.is_empty():
		return _level_background_color(active_level_config).get_luminance()
	var width := source_image.get_width()
	var height := source_image.get_height()
	var step_x := maxi(1, int(width / 24.0))
	var step_y := maxi(1, int(height / 24.0))
	var total := 0.0
	var count := 0
	for y in range(0, height, step_y):
		for x in range(0, width, step_x):
			var color := source_image.get_pixel(x, y)
			if color.a <= 0.08:
				continue
			total += color.get_luminance()
			count += 1
	return total / float(count) if count > 0 else _level_background_color(active_level_config).get_luminance()


func _add_board_outline_shadow() -> void:
	if world_root == null or source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var shadow := ColorRect.new()
	shadow.name = "board_outline_shadow"
	shadow.color = Color(0.36, 0.23, 0.12, 0.12)
	shadow.position = board_origin - Vector2.ONE * BOARD_OUTLINE_SHADOW_OUTSET
	shadow.size = source_size * source_scale + Vector2.ONE * BOARD_OUTLINE_SHADOW_OUTSET * 2.0
	shadow.z_index = -50
	world_root.add_child(shadow)
	var target := ColorRect.new()
	target.name = "board_target_area"
	target.color = Color(1.0, 0.96, 0.86, 0.22)
	target.position = board_origin
	target.size = source_size * source_scale
	target.z_index = -49
	world_root.add_child(target)


func _create_group(piece: Dictionary, locked_seed := false) -> void:
	var group_node := Node2D.new()
	group_node.name = piece["id"]
	group_node.rotation_degrees = 0.0 if locked_seed else ([0, 90, 180, 270][int(rng.randi_range(0, 3))] if randomize_piece_rotation else 0.0)
	group_node.z_index = groups.size() * GROUP_Z_STEP
	world_root.add_child(group_node)
	var visual := PieceVisualFactoryScript.create_piece_visual(piece, texture, piece_visual_style)
	group_node.add_child(visual)
	piece["visual"] = visual
	var group = PieceGroupScript.new(group_node, piece)
	groups.append(group)
	if locked_seed:
		group.locked = true
		group.is_seed = true
		group.node.position = group.anchor_home
		locked_groups.append(group)
	else:
		group.in_tray = true
		tray_groups.append(group)
		_move_group_to_tray(group, tray_groups.size() - 1, true)


func _seed_piece_ids(pieces: Array, mode_config: Dictionary) -> Array[String]:
	var valid := {}
	for piece in pieces:
		valid[str(piece.get("id", ""))] = true
	var assist: Dictionary = mode_config.get("assist", {})
	var seed: Dictionary = assist.get("seed", {}) if typeof(assist) == TYPE_DICTIONARY else {}
	var manual_ids: Array[String] = []
	if str(seed.get("mode", "auto")) == "manual" and seed.has("piece_ids") and typeof(seed["piece_ids"]) == TYPE_ARRAY:
		for id_value in seed["piece_ids"]:
			var id := str(id_value)
			if valid.has(id) and not manual_ids.has(id):
				manual_ids.append(id)
	if not manual_ids.is_empty():
		return manual_ids
	var count := maxi(1, int(seed.get("count", 1)))
	return _auto_seed_piece_ids(pieces, count)


func _auto_seed_piece_ids(pieces: Array, count: int) -> Array[String]:
	var scored := pieces.duplicate()
	scored.sort_custom(func(a, b) -> bool:
		return _seed_score(a) > _seed_score(b)
	)
	var result: Array[String] = []
	if scored.is_empty():
		return result
	var step: int = maxi(1, int(ceil(float(scored.size()) / float(maxi(1, count)))))
	var index: int = 0
	while result.size() < count and index < scored.size():
		var id := str(scored[index].get("id", ""))
		if not id.is_empty():
			result.append(id)
		index += step
	index = 0
	while result.size() < count and index < scored.size():
		var id := str(scored[index].get("id", ""))
		if not id.is_empty() and not result.has(id):
			result.append(id)
		index += 1
	return result


func _seed_score(piece: Dictionary) -> float:
	var home: Vector2 = piece.get("home", Vector2.ZERO)
	var source_center := board_origin + source_size * source_scale * 0.5
	var max_distance := maxf(1.0, (source_size * source_scale * 0.5).length())
	var edge_score := home.distance_to(source_center) / max_distance
	var neighbor_count := 0
	if piece.has("neighbors") and typeof(piece["neighbors"]) == TYPE_ARRAY:
		neighbor_count = piece["neighbors"].size()
	return edge_score + float(4 - mini(4, neighbor_count)) * 0.25


func _tray_area() -> Rect2:
	var viewport := get_viewport_rect().size
	var height := maxf(TRAY_MIN_HEIGHT, viewport.y * TRAY_HEIGHT_RATIO)
	return Rect2(Vector2(0, maxf(0.0, viewport.y - height)), Vector2(viewport.x, height))


func _ensure_tray_background() -> void:
	if tray_root == null or not is_instance_valid(tray_root):
		return
	if tray_background == null or not is_instance_valid(tray_background):
		tray_background = ColorRect.new()
		tray_background.name = "tray_background"
		tray_background.color = Color(0.18, 0.18, 0.18, 0.28)
		tray_background.z_index = -10
		tray_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tray_root.add_child(tray_background)
	var area := _tray_area()
	tray_background.position = area.position
	tray_background.size = area.size


func _layout_tray(instant := false) -> void:
	_ensure_tray_background()
	_layout_tray_items(instant)
	var previous_scroll := tray_scroll_offset
	_clamp_tray_scroll()
	if not is_equal_approx(previous_scroll, tray_scroll_offset):
		_layout_tray_items(instant)


func _layout_tray_items(instant := false) -> void:
	var area := _tray_area()
	var cursor_x := area.position.x + TRAY_PADDING - tray_scroll_offset
	var content_end := area.position.x + TRAY_PADDING
	for index in tray_groups.size():
		var group = tray_groups[index]
		if group == null or not is_instance_valid(group.node):
			continue
		if not group.in_tray:
			if group == dragging and dragging_from_tray:
				var slot_width := maxf(group.tray_slot.size.x, TRAY_GAP)
				cursor_x += slot_width + TRAY_GAP
				content_end = maxf(content_end, cursor_x + tray_scroll_offset)
			continue
		_move_group_to_tray(group, index, instant, cursor_x)
		cursor_x = group.tray_slot.end.x + TRAY_GAP
		content_end = maxf(content_end, cursor_x + tray_scroll_offset)
	tray_content_width = maxf(0.0, content_end - area.position.x)


func _clamp_tray_scroll() -> void:
	var area := _tray_area()
	tray_scroll_offset = clampf(tray_scroll_offset, 0.0, maxf(0.0, tray_content_width - area.size.x + TRAY_PADDING))


func _pan_tray(delta_x: float, record_velocity := true) -> void:
	if not hint_highlighted_groups.is_empty():
		_clear_hint_highlights()
	var now := Time.get_ticks_msec()
	if record_velocity:
		var elapsed := maxf(0.001, float(now - tray_last_pan_msec) / 1000.0) if tray_last_pan_msec > 0 else 0.016
		tray_scroll_velocity = -delta_x / elapsed
		tray_last_pan_msec = now
	tray_scroll_offset -= delta_x
	_clamp_tray_scroll()
	_layout_tray(true)
	_notify_state_changed()


func _start_tray_inertia() -> void:
	if absf(tray_scroll_velocity) < TRAY_INERTIA_MIN_SPEED:
		_stop_tray_inertia()
		return
	tray_inertia_active = true


func _stop_tray_inertia() -> void:
	tray_inertia_active = false
	tray_scroll_velocity = 0.0
	tray_last_pan_msec = 0


func _release_tray_pan() -> void:
	tray_panning = false
	_start_tray_inertia()


func _tray_original_screen_scale() -> float:
	var scale := base_view_scale if base_view_scale > 0.0 else view_scale
	return maxf(0.001, scale)


func _move_group_to_tray(group, index: int, instant := false, forced_x := NAN) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	if group.tray_tween != null and group.tray_tween.is_valid():
		group.tray_tween.kill()
	var current_screen_position: Vector2 = group.node.position
	if group.node.get_parent() == world_root:
		current_screen_position = _world_to_screen(group.node.position)
	if group.node.get_parent() != tray_root:
		if group.node.get_parent() != null:
			group.node.get_parent().remove_child(group.node)
		tray_root.add_child(group.node)
		group.node.position = current_screen_position
	group.in_tray = true
	group.locked = false
	group.tray_index = index
	group.node.rotation_degrees = 0.0
	var bounds := _group_local_bounds(group)
	var area := _tray_area()
	var target_height := maxf(24.0, area.size.y - TRAY_VERTICAL_SAFE_GAP * 2.0)
	var original_screen_scale := _tray_original_screen_scale()
	var original_screen_size := bounds.size * original_screen_scale
	var scale := original_screen_scale
	if original_screen_size.y > target_height + 1.0:
		scale = original_screen_scale * (target_height / maxf(1.0, original_screen_size.y))
	group.tray_scale = scale
	var scaled_size := bounds.size * scale
	var x := forced_x if not is_nan(forced_x) else area.position.x + TRAY_PADDING + float(index) * (scaled_size.x + TRAY_GAP)
	var top_left := Vector2(x, area.position.y + (area.size.y - scaled_size.y) * 0.5)
	group.tray_slot = Rect2(top_left, scaled_size)
	var target_position := top_left - bounds.position * scale
	group.node.z_index = index * GROUP_Z_STEP
	if instant:
		group.is_animating = false
		group.node.scale = Vector2.ONE * scale
		group.node.position = target_position
		_refresh_hint_line_widths()
		return
	group.is_animating = true
	var tween := create_tween()
	group.tray_tween = tween
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	var duration := _motion_duration(TRAY_ANIMATION_TIME)
	tween.parallel().tween_property(group.node, "position", target_position, duration)
	tween.parallel().tween_property(group.node, "scale", Vector2.ONE * scale, duration)
	tween.finished.connect(func(g = group) -> void:
		if is_instance_valid(g.node):
			g.is_animating = false
			g.tray_tween = null
			_refresh_hint_line_widths()
	)


func _tray_group_at_screen(screen_pos: Vector2, exclude = null, hit_padding := TRAY_HIT_PADDING):
	for i in range(tray_groups.size() - 1, -1, -1):
		var group = tray_groups[i]
		if group == exclude:
			continue
		if group != null and group.in_tray and group.tray_slot.grow(hit_padding).has_point(screen_pos):
			return group
	return null


func _begin_tray_piece_press(group, screen_pos: Vector2) -> void:
	tray_pending_group = group
	tray_pending_start_pos = screen_pos
	tray_pending_total_delta = Vector2.ZERO
	group.node.z_index = TRAY_DRAG_Z_INDEX
	PieceVisualFactoryScript.set_group_lifted(group, true, self, not reduced_motion)


func _end_tray_piece_press() -> void:
	var group = tray_pending_group
	tray_pending_group = null
	tray_pending_start_pos = Vector2.ZERO
	tray_pending_total_delta = Vector2.ZERO
	if group != null and is_instance_valid(group.node):
		PieceVisualFactoryScript.set_group_lifted(group, false, self, not reduced_motion)
	_layout_tray(false)


func _group_local_bounds(group) -> Rect2:
	var has_point := false
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for member in group.members:
		var visual_position: Vector2 = member["visual"].position
		for bounds_points in _member_bounds_points_list(member):
			for point in bounds_points:
				var local_point: Vector2 = visual_position + point
				min_point = min_point.min(local_point)
				max_point = max_point.max(local_point)
				has_point = true
	if not has_point:
		return Rect2(Vector2.ZERO, Vector2(1, 1))
	return Rect2(min_point, max_point - min_point)


func _send_group_to_world(group, world_position: Vector2, local_scale := 1.0) -> void:
	if group.node.get_parent() != world_root:
		if group.node.get_parent() != null:
			group.node.get_parent().remove_child(group.node)
		world_root.add_child(group.node)
	group.node.scale = Vector2.ONE * local_scale
	group.node.position = world_position
	group.in_tray = false
	_bring_to_front(group)


func _update_pending_tray_drag(screen_pos: Vector2, relative: Vector2) -> void:
	if tray_pending_group == null:
		return
	tray_pending_total_delta += relative
	var left_tray := screen_pos.y < _tray_area().position.y - TRAY_EXIT_THRESHOLD
	if tray_pending_total_delta.length() < TRAY_GESTURE_DECIDE_THRESHOLD and not left_tray:
		return
	if not left_tray and absf(tray_pending_total_delta.x) > absf(tray_pending_total_delta.y):
		_start_tray_scroll_from_pending(screen_pos)
		return
	_start_tray_world_drag(tray_pending_group, screen_pos)


func _start_tray_scroll_from_pending(screen_pos: Vector2) -> void:
	_clear_hint_highlights()
	var group = tray_pending_group
	var accumulated_x := tray_pending_total_delta.x
	tray_pending_group = null
	tray_pending_start_pos = Vector2.ZERO
	tray_pending_total_delta = Vector2.ZERO
	if group != null and is_instance_valid(group.node):
		PieceVisualFactoryScript.set_group_lifted(group, false, self, not reduced_motion)
	tray_panning = true
	tray_pan_last_x = screen_pos.x
	_pan_tray(accumulated_x)


func _start_tray_world_drag(group, screen_pos: Vector2) -> void:
	if group == null:
		return
	_clear_hint_highlights()
	_stop_tray_inertia()
	tray_pending_group = null
	tray_pending_start_pos = Vector2.ZERO
	tray_pending_total_delta = Vector2.ZERO
	dragging = group
	dragging_from_tray = true
	dragging_tray_index = group.tray_index
	dragging_original_tray_slot = group.tray_slot
	PieceVisualFactoryScript.set_group_lifted(group, true, self, not reduced_motion)
	_trigger_haptic("pickup")
	tray_drag_screen_offset = Vector2.ZERO
	tray_drag_target_screen_offset = Vector2.ZERO
	last_drag_screen_pos = screen_pos
	var initial_scale: float = group.tray_scale / maxf(0.001, view_scale)
	var pointer_world := _screen_to_world(screen_pos)
	var node_world := _screen_to_world(group.node.position)
	_send_group_to_world(group, node_world, initial_scale)
	tray_drag_local_grab = (pointer_world - node_world) / maxf(0.001, initial_scale)
	dragging_at_tray_scale = true
	group.node.z_index = TRAY_DRAG_Z_INDEX
	_set_tray_drag_target_offset(_tray_drag_target_for_screen(screen_pos))
	_update_tray_drag_scale(screen_pos)
	drag_offset = Vector2.ZERO
	_notify_state_changed()


func _update_drag_position(screen_pos: Vector2) -> void:
	last_drag_screen_pos = screen_pos
	if dragging_from_tray:
		_set_tray_drag_target_offset(_tray_drag_target_for_screen(screen_pos))
		_update_tray_drag_scale(screen_pos)
		_place_dragging_from_screen(screen_pos)
		if _tray_area().has_point(screen_pos):
			_clear_snap_preview()
		else:
			_update_snap_preview(dragging)
		return
	_move_group_to(dragging, _screen_to_world(screen_pos) + drag_offset)
	_update_snap_preview(dragging)


func _update_tray_drag_scale(screen_pos: Vector2) -> void:
	if dragging == null or not is_instance_valid(dragging.node):
		return
	var inside_tray := _tray_area().has_point(screen_pos)
	if inside_tray == dragging_at_tray_scale:
		return
	dragging_at_tray_scale = inside_tray
	var target_scale: float = dragging.tray_scale / maxf(0.001, view_scale) if inside_tray else 1.0
	if tray_drag_scale_tween != null and tray_drag_scale_tween.is_valid():
		tray_drag_scale_tween.kill()
	var group = dragging
	tray_drag_scale_tween = create_tween()
	tray_drag_scale_tween.set_ease(Tween.EASE_OUT)
	tray_drag_scale_tween.set_trans(Tween.TRANS_CUBIC)
	var start_scale: float = group.node.scale.x
	tray_drag_scale_tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(group.node):
			return
		group.node.scale = Vector2.ONE * lerpf(start_scale, target_scale, t)
		if group == dragging:
			_place_dragging_from_screen(last_drag_screen_pos)
	, 0.0, 1.0, _motion_duration(TRAY_DRAG_SCALE_TIME))


func _place_dragging_from_screen(screen_pos: Vector2) -> void:
	if dragging == null or not is_instance_valid(dragging.node):
		return
	var pointer_world := _screen_to_world(screen_pos + tray_drag_screen_offset)
	dragging.node.position = pointer_world - tray_drag_local_grab * dragging.node.scale.x
	dragging.node.z_index = TRAY_DRAG_Z_INDEX


func _tray_drag_target_for_screen(screen_pos: Vector2) -> Vector2:
	if dragging == null or _tray_area().has_point(screen_pos):
		return Vector2.ZERO
	var bounds := _group_local_bounds(dragging)
	var bottom_at_pointer := bounds.end.y * view_scale
	return Vector2(0.0, minf(-TRAY_DRAG_LIFT_MARGIN, -TRAY_DRAG_LIFT_MARGIN - bottom_at_pointer))


func _set_tray_drag_target_offset(target: Vector2) -> void:
	if tray_drag_target_screen_offset.is_equal_approx(target):
		return
	tray_drag_target_screen_offset = target
	if tray_drag_offset_tween != null and tray_drag_offset_tween.is_valid():
		tray_drag_offset_tween.kill()
	var start := tray_drag_screen_offset
	tray_drag_offset_tween = create_tween()
	tray_drag_offset_tween.set_ease(Tween.EASE_OUT)
	tray_drag_offset_tween.set_trans(Tween.TRANS_CUBIC)
	tray_drag_offset_tween.tween_method(func(t: float) -> void:
		tray_drag_screen_offset = start.lerp(tray_drag_target_screen_offset, t)
		_place_dragging_from_screen(last_drag_screen_pos)
	, 0.0, 1.0, _motion_duration(0.12))


func _scatter_position_for_group(group) -> Vector2:
	var area := _piece_spawn_area()
	var clamp_area := _piece_drag_area(false)
	var best_position := area.get_center()
	var best_score := INF
	var attempts := 160
	for attempt in range(attempts):
		var candidate := _spawn_candidate(area, attempt, attempts)
		var clamped := _clamped_group_position(group, candidate, false)
		var bounds := _group_bounds_at(group, clamped).grow(PIECE_SPAWN_SEPARATION)
		var score := _spawn_overlap_score(bounds, clamp_area)
		if score <= 0.001:
			return clamped
		if score < best_score:
			best_score = score
			best_position = clamped
	return best_position


func _spawn_candidate(area: Rect2, attempt: int, attempts: int) -> Vector2:
	if attempt < 12:
		var t := float(attempt) / 12.0
		var angle := t * TAU
		var radius := minf(area.size.x, area.size.y) * 0.36
		return area.get_center() + Vector2(cos(angle), sin(angle)) * radius
	if attempt < 28:
		var side := (attempt - 12) % 4
		var offset := float((attempt - 12) / 4 + 1) / 5.0
		if side == 0:
			return Vector2(lerpf(area.position.x, area.end.x, offset), area.position.y)
		if side == 1:
			return Vector2(area.end.x, lerpf(area.position.y, area.end.y, offset))
		if side == 2:
			return Vector2(lerpf(area.end.x, area.position.x, offset), area.end.y)
		return Vector2(area.position.x, lerpf(area.end.y, area.position.y, offset))
	return Vector2(
		rng.randf_range(area.position.x, area.end.x),
		rng.randf_range(area.position.y, area.end.y)
	)


func _spawn_overlap_score(bounds: Rect2, area: Rect2) -> float:
	var score := 0.0
	for existing in spawn_bounds:
		score += _rect_overlap_area(bounds, existing) * 18.0
	score += bounds.get_center().distance_squared_to(area.get_center()) * 0.002
	return score


func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var x0 := maxf(a.position.x, b.position.x)
	var y0 := maxf(a.position.y, b.position.y)
	var x1 := minf(a.end.x, b.end.x)
	var y1 := minf(a.end.y, b.end.y)
	return maxf(0.0, x1 - x0) * maxf(0.0, y1 - y0)


func _move_group_to(group, target_position: Vector2, use_visible_area := true) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	group.node.position = _clamped_group_position(group, target_position, use_visible_area)
	if use_visible_area:
		_notify_state_changed()


func _clamped_group_position(group, target_position: Vector2, use_visible_area := true) -> Vector2:
	var area := _piece_drag_area(use_visible_area)
	var clamped := _clamp_position_to_area(group, target_position, area)
	if use_visible_area:
		clamped = _avoid_drag_blockers(group, clamped, area)
	return clamped


func _clamp_position_to_area(group, target_position: Vector2, area: Rect2) -> Vector2:
	var bounds := _group_bounds_at(group, target_position)
	var delta := Vector2.ZERO
	if bounds.size.x <= area.size.x:
		if bounds.position.x < area.position.x:
			delta.x = area.position.x - bounds.position.x
		elif bounds.end.x > area.end.x:
			delta.x = area.end.x - bounds.end.x
	else:
		delta.x = area.get_center().x - bounds.get_center().x
	if bounds.size.y <= area.size.y:
		if bounds.position.y < area.position.y:
			delta.y = area.position.y - bounds.position.y
		elif bounds.end.y > area.end.y:
			delta.y = area.end.y - bounds.end.y
	else:
		delta.y = area.get_center().y - bounds.get_center().y
	return target_position + delta


func _avoid_drag_blockers(group, target_position: Vector2, area: Rect2) -> Vector2:
	if drag_blockers.is_empty():
		return target_position
	var clamped := target_position
	for iteration in range(3):
		var moved := false
		for blocker in drag_blockers:
			var piece_rect := _world_rect_to_screen(_group_bounds_at(group, clamped))
			if not piece_rect.intersects(blocker):
				continue
			var push := _screen_push_out(piece_rect, blocker)
			if push == Vector2.ZERO:
				continue
			clamped += push / maxf(0.001, view_scale)
			clamped = _clamp_position_to_area(group, clamped, area)
			moved = true
		if not moved:
			break
	return clamped


func _screen_push_out(subject: Rect2, obstacle: Rect2) -> Vector2:
	var viewport := get_viewport_rect().size
	var touches_left := obstacle.position.x <= 0.0
	var touches_top := obstacle.position.y <= 0.0
	var touches_right := obstacle.end.x >= viewport.x
	var touches_bottom := obstacle.end.y >= viewport.y
	var push_left := obstacle.position.x - subject.end.x
	var push_right := obstacle.end.x - subject.position.x
	var push_up := obstacle.position.y - subject.end.y
	var push_down := obstacle.end.y - subject.position.y
	var candidates: Array[Vector2] = []
	if not touches_left:
		candidates.append(Vector2(push_left, 0.0))
	if not touches_right:
		candidates.append(Vector2(push_right, 0.0))
	if not touches_top:
		candidates.append(Vector2(0.0, push_up))
	if not touches_bottom:
		candidates.append(Vector2(0.0, push_down))
	if candidates.is_empty():
		return Vector2.ZERO
	var best: Vector2 = candidates[0]
	for candidate in candidates:
		if candidate.length_squared() < best.length_squared():
			best = candidate
	return best


func _debug_group_id(group) -> String:
	if group == null or group.members.is_empty():
		return "group"
	return str(group.members[0].get("id", "group"))


func _refresh_debug_bounds_overlay() -> void:
	if not debug_bounds_overlay_enabled:
		return
	if debug_bounds_overlay == null or not is_instance_valid(debug_bounds_overlay):
		debug_bounds_overlay = Control.new()
		debug_bounds_overlay.name = "debug_bounds_overlay"
		debug_bounds_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		debug_bounds_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		debug_bounds_overlay.z_index = 5000
		add_child(debug_bounds_overlay)
	for child in debug_bounds_overlay.get_children():
		child.free()
	var tray := _tray_area()
	_debug_add_rect_outline(debug_bounds_overlay, tray, Color(1.0, 0.74, 0.20, 0.88), 4.0)
	var usable := Rect2(
		Vector2(tray.position.x, tray.position.y + TRAY_VERTICAL_SAFE_GAP),
		Vector2(tray.size.x, maxf(1.0, tray.size.y - TRAY_VERTICAL_SAFE_GAP * 2.0))
	)
	_debug_add_rect_outline(debug_bounds_overlay, usable, Color(0.25, 0.85, 1.0, 0.72), 3.0)
	for group in groups:
		if group == null or not is_instance_valid(group.node):
			continue
		var rect: Rect2 = group.tray_slot if group.in_tray else _world_rect_to_screen(_group_bounds_at(group, group.node.position))
		var color := Color(0.38, 1.0, 0.45, 0.72) if group.locked else Color(0.28, 0.72, 1.0, 0.68)
		_debug_add_rect_outline(debug_bounds_overlay, rect, color, 2.0)
	for blocker in drag_blockers:
		_debug_add_rect_outline(debug_bounds_overlay, blocker, Color(1.0, 0.15, 0.15, 0.72), 3.0)


func _clear_debug_bounds_overlay() -> void:
	if debug_bounds_overlay != null and is_instance_valid(debug_bounds_overlay):
		debug_bounds_overlay.queue_free()
	debug_bounds_overlay = null


func _debug_add_rect_outline(parent: Control, rect: Rect2, color: Color, width: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var top := ColorRect.new()
	top.color = color
	top.position = rect.position
	top.size = Vector2(rect.size.x, width)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top)
	var bottom := ColorRect.new()
	bottom.color = color
	bottom.position = Vector2(rect.position.x, rect.end.y - width)
	bottom.size = Vector2(rect.size.x, width)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bottom)
	var left := ColorRect.new()
	left.color = color
	left.position = rect.position
	left.size = Vector2(width, rect.size.y)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(left)
	var right := ColorRect.new()
	right.color = color
	right.position = Vector2(rect.end.x - width, rect.position.y)
	right.size = Vector2(width, rect.size.y)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(right)


func _world_rect_to_screen(rect: Rect2) -> Rect2:
	var top_left := _world_to_screen(rect.position)
	var bottom_right := _world_to_screen(rect.end)
	return Rect2(top_left.min(bottom_right), (bottom_right - top_left).abs())


func _screen_to_world_for_view(screen_pos: Vector2, scale: float, offset: Vector2) -> Vector2:
	return (screen_pos - offset) / maxf(0.001, scale)


func _screen_rect_to_world_for_view(rect: Rect2, scale: float, offset: Vector2) -> Rect2:
	var top_left := _screen_to_world_for_view(rect.position, scale, offset)
	var bottom_right := _screen_to_world_for_view(rect.end, scale, offset)
	return Rect2(top_left.min(bottom_right), (bottom_right - top_left).abs())


func _piece_drag_area(use_visible_area := false) -> Rect2:
	var table := _virtual_table_area().grow(-PIECE_DRAG_PADDING)
	if not use_visible_area:
		return table
	var visible := _visible_world_area().grow(-PIECE_DRAG_PADDING / maxf(0.001, view_scale))
	if visible.size.x >= 48.0 and visible.size.y >= 48.0:
		return visible
	return table


func _visible_world_area() -> Rect2:
	return _visible_world_area_for_view(view_scale, view_offset)


func _visible_world_area_for_view(scale: float, offset: Vector2) -> Rect2:
	var view_rect := _world_view_screen_rect()
	var top_left := _screen_to_world_for_view(view_rect.position, scale, offset)
	var bottom_right := _screen_to_world_for_view(view_rect.end, scale, offset)
	var position := top_left.min(bottom_right)
	var size := (bottom_right - top_left).abs()
	return Rect2(position, size)


func _virtual_table_area() -> Rect2:
	var layout := _mobile_board_layout()
	var play_area: Rect2 = layout["play_area"]
	var piece_count: int = max(1, _current_mode_piece_count())
	var extra := clampf(sqrt(float(piece_count)) * 52.0, TABLE_EXTRA_MIN, TABLE_EXTRA_MAX)
	return play_area.grow_individual(extra, extra * 0.55, extra, extra * 1.15)


func _piece_spawn_area() -> Rect2:
	var drag_area := _piece_drag_area()
	var padding := maxf(PIECE_SPAWN_EDGE_PADDING, minf(drag_area.size.x, drag_area.size.y) * 0.05)
	var spawn_area := drag_area.grow(-padding)
	if spawn_area.size.x < 140.0 or spawn_area.size.y < 140.0:
		return drag_area
	return spawn_area


func _group_bounds_at(group, target_position: Vector2) -> Rect2:
	var has_point := false
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for member in group.members:
		var visual_position: Vector2 = member["visual"].position
		for bounds_points in _member_bounds_points_list(member):
			for point in bounds_points:
				var global_point: Vector2 = target_position + (visual_position + point).rotated(group.node.rotation)
				min_point = min_point.min(global_point)
				max_point = max_point.max(global_point)
				has_point = true
	if not has_point:
		return Rect2(target_position, Vector2.ZERO)
	return Rect2(min_point, max_point - min_point)


func _member_bounds_points_list(member: Dictionary) -> Array[PackedVector2Array]:
	if member.has("bounds_points_list") and typeof(member["bounds_points_list"]) == TYPE_ARRAY and not member["bounds_points_list"].is_empty():
		return member["bounds_points_list"]
	return [member.get("bounds_points", member["polygon"])]


func _begin_drag(screen_pos: Vector2) -> void:
	if current_mode == "swap":
		_begin_swap_drag(screen_pos)
		return
	last_drag_screen_pos = screen_pos
	if _tray_area().has_point(screen_pos):
		_stop_tray_inertia()
	var tray_group = _tray_group_at_screen(screen_pos)
	if tray_group != null:
		if tray_group.is_animating:
			return
		_begin_tray_piece_press(tray_group, screen_pos)
		return
	if _tray_area().has_point(screen_pos):
		tray_panning = true
		tray_pan_last_x = screen_pos.x
		return
	var world_pos := _screen_to_world(screen_pos)
	var group = _group_at_world(world_pos)
	if group == null:
		_begin_pan(screen_pos, active_touch_index)
		return
	if group.is_animating or group.locked:
		_begin_pan(screen_pos, active_touch_index)
		return
	_clear_hint_highlights()
	_select_group(group)
	dragging = group
	drag_offset = group.node.position - world_pos
	_bring_to_front(group)
	PieceVisualFactoryScript.set_group_lifted(group, true, self, not reduced_motion)
	_trigger_haptic("pickup")
	_notify_state_changed()


func _end_drag() -> void:
	if current_mode == "swap":
		_end_swap_drag()
		return
	if tray_pending_group != null:
		_end_tray_piece_press()
		return
	if tray_panning:
		_release_tray_pan()
		return
	if dragging == null:
		return
	var released_group = dragging
	var released_members: Array = released_group.members.duplicate()
	_clear_snap_preview()
	var snapped := _try_snap_chain(dragging)
	if dragging_from_tray and not snapped:
		_return_group_to_tray(released_group)
	elif snapped:
		_lock_group(released_group)
		_play_snap_shimmer(released_members)
	else:
		_trigger_haptic("drop")
	_check_complete()
	PieceVisualFactoryScript.set_group_lifted(released_group, false, self, not reduced_motion and not snapped)
	dragging = null
	dragging_from_tray = false
	dragging_tray_index = -1
	tray_drag_offset = Vector2.ZERO
	tray_drag_screen_offset = Vector2.ZERO
	tray_drag_target_screen_offset = Vector2.ZERO
	if tray_drag_offset_tween != null and tray_drag_offset_tween.is_valid():
		tray_drag_offset_tween.kill()
	tray_drag_offset_tween = null
	if tray_drag_scale_tween != null and tray_drag_scale_tween.is_valid():
		tray_drag_scale_tween.kill()
	tray_drag_scale_tween = null
	tray_drag_local_grab = Vector2.ZERO
	dragging_at_tray_scale = false
	last_drag_screen_pos = Vector2.ZERO
	_notify_state_changed(true)


func _group_at_world(world_pos: Vector2):
	for i in range(groups.size() - 1, -1, -1):
		var group = groups[i]
		if group.locked or group.in_tray:
			continue
		var local_to_group: Vector2 = group.node.transform.affine_inverse() * world_pos
		for member in group.members:
			var local_to_piece: Vector2 = local_to_group - member["visual"].position
			if Geometry2D.is_point_in_polygon(local_to_piece, member["polygon"]) and _local_point_has_alpha(member, local_to_piece):
				return group
	return null


func _local_point_has_alpha(member: Dictionary, local_point: Vector2) -> bool:
	var source_point: Vector2 = (local_point + member["home"] - board_origin) / source_scale
	return _source_point_has_alpha(source_point, HIT_ALPHA_RADIUS)


func _source_point_has_alpha(source_point: Vector2, radius := HIT_ALPHA_RADIUS) -> bool:
	var center := Vector2i(roundi(source_point.x), roundi(source_point.y))
	var image_size := source_image.get_size()
	for y in range(center.y - radius, center.y + radius + 1):
		if y < 0 or y >= image_size.y:
			continue
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= image_size.x:
				continue
			if source_image.get_pixel(x, y).a > 0.08:
				return true
	return false


func _visible_cut_line_segments(source_line: PackedVector2Array, home: Vector2, scale: float, origin: Vector2) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var current := PackedVector2Array()
	for index in range(source_line.size() - 1):
		var a: Vector2 = source_line[index]
		var b: Vector2 = source_line[index + 1]
		var sample_count: int = max(2, ceili(a.distance_to(b) / 6.0))
		for sample_index in range(sample_count + 1):
			if index > 0 and sample_index == 0:
				continue
			var source_point: Vector2 = a.lerp(b, float(sample_index) / float(sample_count))
			if _source_point_has_alpha(source_point, 3):
				current.append(origin + source_point * scale - home)
			else:
				if current.size() >= 2:
					segments.append(current)
				current = PackedVector2Array()
	if current.size() >= 2:
		segments.append(current)
	return segments


func _begin_swap_drag(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var tile = _swap_tile_at_world(world_pos)
	if tile == null:
		_begin_pan(screen_pos, active_touch_index)
		return
	if bool(tile.get("is_animating", false)):
		return
	_clear_swap_target_preview()
	_clear_hint_highlights()
	swap_dragging = tile
	swap_drag_start_slot = int(tile["slot_index"])
	swap_drag_offset = tile["node"].position - world_pos
	_bring_swap_tile_to_front(tile)
	_set_swap_tile_lifted(tile, true)
	_trigger_haptic("pickup")
	_notify_state_changed()


func _end_swap_drag() -> void:
	if swap_dragging == null:
		return
	var released = swap_dragging
	var target = _swap_target_for_drag(released)
	_clear_swap_target_preview()
	if target == null:
		_animate_swap_tile_to(released, _swap_slot_position(swap_drag_start_slot, _swap_cols(), _swap_rows()))
	else:
		var target_slot := int(target["slot_index"])
		swap_history.append({
			"first": int(released["correct_index"]),
			"second": int(target["correct_index"]),
			"first_slot": swap_drag_start_slot,
			"second_slot": target_slot,
		})
		released["slot_index"] = target_slot
		target["slot_index"] = swap_drag_start_slot
		_animate_swap_tile_to(released, _swap_slot_position(target_slot, _swap_cols(), _swap_rows()))
		_animate_swap_tile_to(target, _swap_slot_position(swap_drag_start_slot, _swap_cols(), _swap_rows()))
		status_changed.emit(_bt("swapped"))
		undo_available_changed.emit(true)
		_trigger_haptic("swap")
	_set_swap_tile_lifted(released, false)
	swap_dragging = null
	swap_drag_start_slot = -1
	_notify_state_changed(true)


func _move_swap_tile_to(tile, target_position: Vector2) -> void:
	if tile == null or not is_instance_valid(tile["node"]):
		return
	var area := _piece_drag_area(true)
	var bounds := _swap_tile_bounds(tile, target_position)
	var delta := Vector2.ZERO
	if bounds.position.x < area.position.x:
		delta.x = area.position.x - bounds.position.x
	elif bounds.end.x > area.end.x:
		delta.x = area.end.x - bounds.end.x
	if bounds.position.y < area.position.y:
		delta.y = area.position.y - bounds.position.y
	elif bounds.end.y > area.end.y:
		delta.y = area.end.y - bounds.end.y
	tile["node"].position = target_position + delta
	_update_swap_target_preview(tile)
	_notify_state_changed()


func _swap_target_for_drag(tile):
	if tile == null or not is_instance_valid(tile["node"]):
		return null
	var center: Vector2 = tile["node"].position + tile["size"] * 0.5
	return _swap_tile_at_world(center, tile)


func _update_swap_target_preview(tile) -> void:
	var target = _swap_target_for_drag(tile)
	if target == swap_target_preview:
		return
	_clear_swap_target_preview()
	if target == null:
		return
	swap_target_preview = target
	var size: Vector2 = target.get("size", Vector2.ZERO)
	var polygon := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)])
	var root := Node2D.new()
	root.name = "swap_target_preview"
	root.z_index = 48
	target["node"].add_child(root)
	swap_target_preview_root = root
	var fill := Polygon2D.new()
	fill.polygon = polygon
	fill.color = SWAP_TARGET_PREVIEW_FILL
	root.add_child(fill)
	var line := Line2D.new()
	line.name = "swap_target_preview_outline"
	line.points = polygon
	line.closed = true
	line.default_color = SWAP_TARGET_PREVIEW_COLOR
	line.width = SWAP_TARGET_PREVIEW_SCREEN_WIDTH
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = 1
	line.set_meta("screen_width", SWAP_TARGET_PREVIEW_SCREEN_WIDTH)
	root.add_child(line)
	swap_target_preview_line = line
	_update_hint_line_width(line)
	_trigger_haptic("ready")
	if reduced_motion:
		return
	root.modulate.a = 0.68
	swap_target_preview_tween = create_tween()
	swap_target_preview_tween.bind_node(root)
	swap_target_preview_tween.set_loops()
	swap_target_preview_tween.set_ease(Tween.EASE_IN_OUT)
	swap_target_preview_tween.set_trans(Tween.TRANS_SINE)
	swap_target_preview_tween.tween_property(root, "modulate:a", 1.0, 0.34)
	swap_target_preview_tween.tween_property(root, "modulate:a", 0.68, 0.34)


func _clear_swap_target_preview() -> void:
	if swap_target_preview_tween != null and swap_target_preview_tween.is_valid():
		swap_target_preview_tween.kill()
	swap_target_preview_tween = null
	if swap_target_preview_root != null and is_instance_valid(swap_target_preview_root):
		swap_target_preview_root.queue_free()
	swap_target_preview = null
	swap_target_preview_root = null
	swap_target_preview_line = null


func _swap_tile_at_world(world_pos: Vector2, exclude = null):
	for index in range(swap_tiles.size() - 1, -1, -1):
		var tile = swap_tiles[index]
		if tile == exclude:
			continue
		var node: Node2D = tile["node"]
		if not is_instance_valid(node):
			continue
		var local: Vector2 = node.transform.affine_inverse() * world_pos
		if Rect2(Vector2.ZERO, tile["size"]).has_point(local):
			return tile
	return null


func _swap_tile_bounds(tile, target_position: Vector2) -> Rect2:
	return Rect2(target_position, tile.get("size", Vector2.ZERO))


func _bring_swap_tile_to_front(tile) -> void:
	swap_tiles.erase(tile)
	swap_tiles.append(tile)
	for index in swap_tiles.size():
		swap_tiles[index]["node"].z_index = index * GROUP_Z_STEP
	_notify_state_changed()


func _set_swap_tile_lifted(tile, lifted: bool) -> void:
	if tile == null:
		return
	var node: Node2D = tile["node"]
	if not is_instance_valid(node):
		return
	var target_scale := Vector2(1.025, 1.025) if lifted else Vector2.ONE
	if reduced_motion:
		node.scale = target_scale
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "scale", target_scale, 0.12)


func _animate_swap_tile_to(tile, target_position: Vector2) -> void:
	if tile == null or not is_instance_valid(tile["node"]):
		return
	tile["is_animating"] = true
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(tile["node"], "position", target_position, _motion_duration(SWAP_ANIMATION_TIME))
	tween.finished.connect(func(t = tile) -> void:
		if is_instance_valid(t["node"]):
			t["is_animating"] = false
		_check_swap_complete()
		_notify_state_changed(true)
	)


func can_undo_swap() -> bool:
	return current_mode == "swap" and not swap_history.is_empty()


func undo_last_swap() -> void:
	if not can_undo_swap() or swap_dragging != null:
		return
	for tile in swap_tiles:
		if bool(tile.get("is_animating", false)):
			return
	var entry: Dictionary = swap_history.pop_back()
	var first = _swap_tile_by_correct_index(int(entry.get("first", -1)))
	var second = _swap_tile_by_correct_index(int(entry.get("second", -1)))
	if first == null or second == null:
		undo_available_changed.emit(not swap_history.is_empty())
		return
	_clear_hint_highlights()
	first["slot_index"] = int(entry.get("first_slot", first["slot_index"]))
	second["slot_index"] = int(entry.get("second_slot", second["slot_index"]))
	_animate_swap_tile_to(first, _swap_slot_position(int(first["slot_index"]), _swap_cols(), _swap_rows()))
	_animate_swap_tile_to(second, _swap_slot_position(int(second["slot_index"]), _swap_cols(), _swap_rows()))
	status_changed.emit(_bt("undone"))
	undo_available_changed.emit(not swap_history.is_empty())
	_trigger_haptic("swap")
	_notify_state_changed(true)


func _swap_tile_by_correct_index(correct_index: int):
	for tile in swap_tiles:
		if int(tile.get("correct_index", -1)) == correct_index:
			return tile
	return null


func _show_swap_hint() -> void:
	var pair := _find_swap_hint_pair()
	if pair.is_empty():
		_clear_hint_highlights()
		status_changed.emit(_bt("hint_none"))
		return
	var hint_key := "swap:%d:%d" % [int(pair[0]["correct_index"]), int(pair[1]["correct_index"])]
	if hint_key == active_hint_key and _has_active_hint_highlights():
		hint_expires_at_msec = Time.get_ticks_msec() + int(HINT_DURATION * 1000.0)
		return
	_clear_hint_highlights()
	hint_highlight_token += 1
	active_hint_key = hint_key
	hint_expires_at_msec = Time.get_ticks_msec() + int(HINT_DURATION * 1000.0)
	for tile in pair:
		_add_swap_hint_outline(tile)
	_auto_clear_hint_highlights(hint_highlight_token)
	status_changed.emit(_bt("hint_pair"))


func _find_swap_hint_pair() -> Array:
	var by_slot := {}
	for tile in swap_tiles:
		by_slot[int(tile["slot_index"])] = tile
	var fallback: Array = []
	for tile in swap_tiles:
		if int(tile["slot_index"]) == int(tile["correct_index"]):
			continue
		var occupant = by_slot.get(int(tile["correct_index"]), null)
		if occupant == null or occupant == tile:
			continue
		if int(occupant["correct_index"]) == int(tile["slot_index"]):
			return [tile, occupant]
		if fallback.is_empty():
			fallback = [tile, occupant]
	return fallback


func _add_swap_hint_outline(tile) -> void:
	var node: Node2D = tile["node"]
	if not is_instance_valid(node):
		return
	var size: Vector2 = tile["size"]
	var rect_polygon := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	_spawn_dashed_outline(node, [rect_polygon], Vector2.ZERO, 30)


func _check_swap_complete() -> void:
	if completion_emitted or swap_tiles.is_empty():
		return
	for tile in swap_tiles:
		if int(tile["slot_index"]) != int(tile["correct_index"]):
			return
	completion_emitted = true
	_trigger_haptic("complete")
	completed.emit()


func _swap_cols() -> int:
	return int(_swap_grid_config()["cols"])


func _swap_rows() -> int:
	return int(_swap_grid_config()["rows"])


func _select_group(group) -> void:
	selected_group = group


func _rotate_group(group) -> void:
	if not randomize_piece_rotation or group == null or group.is_animating:
		return
	group.is_animating = true
	var target: float = snappedf(group.node.rotation_degrees + 90.0, 90.0)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(group.node, "rotation_degrees", target, _motion_duration(0.16))
	tween.finished.connect(func() -> void:
		if not groups.has(group) or not is_instance_valid(group.node):
			return
		group.is_animating = false
		_try_snap_chain(group)
		_check_complete()
		_notify_state_changed(true)
	)


func _bring_to_front(group) -> void:
	groups.erase(group)
	groups.append(group)
	_refresh_group_z_indices()
	_notify_state_changed()


func _refresh_group_z_indices() -> void:
	for i in groups.size():
		groups[i].node.z_index = i * GROUP_Z_STEP


func _update_snap_preview(active) -> void:
	if active == null or active.locked or not is_instance_valid(active.node) or absf(active.node.scale.x - 1.0) > 0.04:
		_clear_snap_preview()
		return
	var match := _snap_match_data(active)
	if match.is_empty():
		_clear_snap_preview()
		return
	var other = match.get("other", null)
	var key := "%s>%s" % [_debug_group_id(active), _debug_group_id(other)]
	if key != snap_preview_key:
		_clear_snap_preview()
		snap_preview_key = key
		_add_snap_preview_outline(match.get("active_member", {}))
		_add_snap_preview_outline(match.get("other_member", {}))
	var distance := float(match.get("distance", _snap_tolerance()))
	var correction: Vector2 = match.get("correction", Vector2.ZERO)
	if distance > 0.5:
		active.node.position += correction * SNAP_PREVIEW_PULL
	if snap_ready_key != key:
		snap_ready_key = key
		_trigger_haptic("ready")


func _add_snap_preview_outline(member) -> void:
	if typeof(member) != TYPE_DICTIONARY:
		return
	var visual: Node2D = member.get("visual", null)
	if visual == null or not is_instance_valid(visual):
		return
	var line := Line2D.new()
	line.name = "snap_preview_outline"
	line.points = member.get("polygon", PackedVector2Array())
	line.closed = true
	line.default_color = SNAP_PREVIEW_COLOR
	line.width = SNAP_PREVIEW_SCREEN_WIDTH
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = 42
	line.set_meta("screen_width", SNAP_PREVIEW_SCREEN_WIDTH)
	visual.add_child(line)
	snap_preview_lines.append(line)
	_update_hint_line_width(line)


func _clear_snap_preview() -> void:
	for line in snap_preview_lines:
		if line != null and is_instance_valid(line):
			line.queue_free()
	snap_preview_lines.clear()
	snap_preview_key = ""
	snap_ready_key = ""


func _refresh_snap_preview_line_widths() -> void:
	var valid: Array[Line2D] = []
	for line in snap_preview_lines:
		if line != null and is_instance_valid(line):
			_update_hint_line_width(line)
			valid.append(line)
	snap_preview_lines = valid


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
			_clear_hint_highlights()
			active.absorb(other, SNAP_VISUAL_GAP)
			groups.erase(other)
			locked_groups.erase(other)
			_refresh_group_z_indices()
			active.node.position = active.anchor_home
			active.node.rotation_degrees = 0.0
			if selected_group == other:
				selected_group = active
			active.node.scale = Vector2.ONE
			PieceVisualFactoryScript.add_seam_outline(active, _seam_line_width())
			snapped = true
			progressed = true
	if snapped:
		_trigger_haptic("snap")
	return snapped


func _snap_match_data(active) -> Dictionary:
	return SnapSolverScript.find_match_data(active, _locked_snap_targets(active), _snap_tolerance(), ROTATION_TOLERANCE)


func _seam_line_width() -> float:
	return SEAM_SCREEN_WIDTH / maxf(0.001, base_view_scale if base_view_scale > 0.0 else view_scale)


func _play_snap_shimmer(members: Array) -> void:
	if reduced_motion:
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
		var bounds := _source_rect_for_points(polygon)
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
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(t: float) -> void:
		material.set_shader_parameter("progress", t)
	, 0.0, 1.0, SHIMMER_DURATION)
	tween.finished.connect(func() -> void:
		for overlay in overlays:
			if is_instance_valid(overlay):
				overlay.queue_free()
	)


static var _shimmer_shader_cache: Shader = null
static var _shimmer_uv_texture_cache: Texture2D = null


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
	for group in groups:
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
	PieceVisualFactoryScript.add_seam_outline(group, _seam_line_width())
	if not locked_groups.has(group):
		locked_groups.append(group)
	if tray_groups.has(group):
		tray_groups.erase(group)
		_reindex_tray()
		_layout_tray(false)


func _return_group_to_tray(group) -> void:
	if group == null:
		return
	group.locked = false
	group.in_tray = true
	group.node.rotation_degrees = 0.0
	if not tray_groups.has(group):
		var index := clampi(dragging_tray_index, 0, tray_groups.size())
		tray_groups.insert(index, group)
	_reindex_tray()
	_layout_tray(false)


func _reindex_tray() -> void:
	for index in tray_groups.size():
		var group = tray_groups[index]
		if group != null:
			group.tray_index = index


func _snap_tolerance() -> float:
	return clampf(SNAP_TOLERANCE * maxf(0.75, source_scale), 16.0, 24.0)


func _check_complete() -> void:
	if current_mode == "swap":
		return
	for group in groups:
		if not group.locked:
			return
	if not completion_emitted:
		completion_emitted = true
		_trigger_haptic("complete")
		completed.emit()


func _set_hint_highlights(pair: Array) -> void:
	var hint_key := _hint_pair_key(pair)
	if hint_key == active_hint_key and _has_active_hint_highlights():
		hint_expires_at_msec = Time.get_ticks_msec() + int(HINT_DURATION * 1000.0)
		_bring_hint_group_to_front(pair[0])
		return
	_clear_hint_highlights()
	hint_highlight_token += 1
	active_hint_key = hint_key
	hint_expires_at_msec = Time.get_ticks_msec() + int(HINT_DURATION * 1000.0)
	var token := hint_highlight_token
	var first = pair[0]
	_bring_hint_group_to_front(first)
	hint_highlighted_groups.append(first)
	_add_hint_target_outline(first)
	_add_hint_outline_to_group(first)
	_auto_clear_hint_highlights(token)


func _has_active_hint_highlights() -> bool:
	for line in hint_highlighted_lines:
		if line != null and is_instance_valid(line):
			return true
	for node in hint_highlighted_nodes:
		if node != null and is_instance_valid(node):
			return true
	return false


func _bring_hint_group_to_front(group) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	if group.in_tray:
		group.node.z_index = HINT_GROUP_Z_INDEX
		return
	_bring_to_front(group)
	group.node.z_index = HINT_GROUP_Z_INDEX


func _add_hint_outline_to_group(group) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	var center := _hint_outline_local_center(group)
	var outline_root := Node2D.new()
	outline_root.name = "hint_group_outline"
	outline_root.position = center
	outline_root.z_index = 31
	group.node.add_child(outline_root)
	hint_highlighted_nodes.append(outline_root)
	for member in group.members:
		var visual: Node2D = member["visual"]
		var polygon: PackedVector2Array = member["polygon"]
		var outline := PackedVector2Array()
		for point in polygon:
			outline.append(visual.position + point - center)
		_add_hint_outline_line(outline_root, outline, HINT_OUTLINE_SCREEN_WIDTH, HINT_OUTLINE_COLOR, 0, false)
	_hint_breathe_group(group)


func _hint_outline_local_center(group) -> Vector2:
	var bounds := _group_local_bounds(group)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.ZERO
	return bounds.get_center()


func _add_hint_target_outline(group) -> void:
	if world_root == null or group == null:
		return
	var polygons: Array = []
	for member in group.members:
		var visual_position: Vector2 = member["visual"].position
		var polygon: PackedVector2Array = member["polygon"]
		var outline := PackedVector2Array()
		for point in polygon:
			outline.append(visual_position + point)
		polygons.append(outline)
	_spawn_dashed_outline(world_root, polygons, group.anchor_home, HINT_TARGET_Z_INDEX)


func _spawn_dashed_outline(parent: Node2D, polygons: Array, local_position: Vector2, z_index_value: int) -> Node2D:
	var root := Node2D.new()
	root.name = "hint_dashed_outline"
	root.position = local_position
	root.z_index = z_index_value
	parent.add_child(root)
	hint_highlighted_nodes.append(root)
	_redraw_dashed_outline(root, polygons, 0.0)
	if reduced_motion:
		return root
	var tween := create_tween()
	tween.bind_node(root)
	tween.set_loops()
	tween.set_trans(Tween.TRANS_LINEAR)
	var dash_cycle := HINT_TARGET_DASH_LENGTH + HINT_TARGET_DASH_GAP
	tween.tween_method(func(phase: float) -> void:
		_redraw_dashed_outline(root, polygons, phase)
	, 0.0, dash_cycle, 0.64)
	return root


func _redraw_dashed_outline(root: Node2D, polygons: Array, phase: float) -> void:
	if not is_instance_valid(root):
		return
	for child in root.get_children():
		child.free()
	for polygon in polygons:
		for dash in _dashed_polygon_segments(polygon, HINT_TARGET_DASH_LENGTH, HINT_TARGET_DASH_GAP, phase):
			_add_hint_outline_line(root, dash, HINT_TARGET_SCREEN_WIDTH, HINT_TARGET_COLOR, 0, false, false)


func _dashed_polygon_segments(points: PackedVector2Array, dash_length: float, gap_length: float, phase: float) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	if points.size() < 2:
		return segments
	var cycle := maxf(1.0, dash_length + gap_length)
	var distance_cursor := -fposmod(phase, cycle)
	for index in range(points.size()):
		var start := points[index]
		var end := points[(index + 1) % points.size()]
		var edge := end - start
		var edge_length := edge.length()
		if edge_length <= 0.001:
			continue
		var direction := edge / edge_length
		var local := 0.0
		while local < edge_length:
			var cycle_position := fposmod(distance_cursor, cycle)
			var until_next := cycle - cycle_position
			# fposmod can return the divisor itself due to float error, which
			# would make the step zero and hang this loop
			var step := maxf(0.01, minf(edge_length - local, until_next))
			if cycle_position < dash_length:
				var dash_remaining := dash_length - cycle_position
				var dash_step := minf(step, dash_remaining)
				var dash := PackedVector2Array()
				dash.append(start + direction * local)
				dash.append(start + direction * (local + dash_step))
				segments.append(dash)
			local += step
			distance_cursor += step
	return segments


func _hint_breathe_group(group) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	if reduced_motion:
		return
	var node: Node2D = group.node
	var base_scale: float = node.scale.x
	var base_position: Vector2 = node.position
	var local_center := _hint_outline_local_center(group)
	var pinned_center := base_position + local_center * base_scale
	var apply_factor := func(factor: float) -> void:
		if not is_instance_valid(node):
			return
		node.scale = Vector2.ONE * base_scale * factor
		node.position = pinned_center - local_center * base_scale * factor
	var tween := create_tween()
	tween.bind_node(node)
	tween.set_loops(int(ceil(HINT_DURATION / HINT_BREATHE_CYCLE)))
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(apply_factor, 1.0, HINT_BREATHE_SCALE, HINT_BREATHE_CYCLE * 0.5)
	tween.tween_method(apply_factor, HINT_BREATHE_SCALE, 1.0, HINT_BREATHE_CYCLE * 0.5)
	tween.finished.connect(func() -> void:
		apply_factor.call(1.0)
	)
	hint_blink_tweens.append(tween)


func _add_hint_outline_line(visual: Node2D, polygon: PackedVector2Array, width: float, color: Color, z_index: int, animate := true, track := true) -> Line2D:
	var line := Line2D.new()
	line.name = "hint_highlight"
	line.width = width
	line.default_color = color
	line.closed = polygon.size() > 2
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.points = polygon
	line.z_index = z_index
	line.set_meta("screen_width", width)
	visual.add_child(line)
	_update_hint_line_width(line)
	if track:
		hint_highlighted_lines.append(line)
	if not animate or reduced_motion:
		return line
	var tween := create_tween()
	tween.set_loops(5)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(line, "modulate:a", 0.42, 0.30)
	tween.tween_property(line, "modulate:a", 1.0, 0.30)
	return line


func _refresh_hint_line_widths() -> void:
	var valid_lines: Array[Line2D] = []
	for line in hint_highlighted_lines:
		if line != null and is_instance_valid(line):
			_update_hint_line_width(line)
			valid_lines.append(line)
	hint_highlighted_lines = valid_lines


func _update_hint_line_width(line) -> void:
	if line == null or not is_instance_valid(line) or not line is Line2D:
		return
	var hint_line := line as Line2D
	var screen_width := float(hint_line.get_meta("screen_width", hint_line.width))
	var transform := hint_line.get_global_transform()
	var scale := maxf(transform.x.length(), transform.y.length())
	hint_line.width = screen_width / maxf(0.001, scale)


func _auto_clear_hint_highlights(token: int) -> void:
	_stop_hint_clear_timer()
	if token != hint_highlight_token:
		return
	var remaining_msec := hint_expires_at_msec - Time.get_ticks_msec()
	if remaining_msec <= 0:
		_clear_hint_highlights()
		return
	hint_clear_timer = Timer.new()
	hint_clear_timer.one_shot = true
	hint_clear_timer.wait_time = maxf(0.01, float(remaining_msec) / 1000.0)
	add_child(hint_clear_timer)
	hint_clear_timer.timeout.connect(func() -> void:
		if token == hint_highlight_token:
			_auto_clear_hint_highlights(token)
	)
	hint_clear_timer.start()


func _stop_hint_clear_timer() -> void:
	if hint_clear_timer != null and is_instance_valid(hint_clear_timer):
		hint_clear_timer.stop()
		hint_clear_timer.queue_free()
	hint_clear_timer = null


func _clear_hint_highlights() -> void:
	_stop_hint_clear_timer()
	hint_highlight_token += 1
	active_hint_key = ""
	hint_expires_at_msec = 0
	hint_pending = false
	if hint_tray_scroll_tween != null and hint_tray_scroll_tween.is_valid():
		hint_tray_scroll_tween.kill()
	hint_tray_scroll_tween = null
	for line in hint_highlighted_lines:
		if is_instance_valid(line):
			line.queue_free()
	for node in hint_highlighted_nodes:
		if is_instance_valid(node):
			node.queue_free()
	for tween in hint_blink_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	for node in hint_original_modulates.keys():
		if is_instance_valid(node):
			node.modulate = hint_original_modulates[node]
	hint_highlighted_groups.clear()
	hint_highlighted_lines.clear()
	hint_highlighted_nodes.clear()
	hint_original_modulates.clear()
	hint_blink_tweens.clear()
	if current_mode != "swap":
		_refresh_group_z_indices()
		if tray_root != null and is_instance_valid(tray_root):
			_layout_tray(true)


func _find_hint_pair() -> Array:
	var tray_pair := _find_hint_pair_for_candidates(_sorted_hint_groups(tray_groups))
	if not tray_pair.is_empty():
		return tray_pair
	return _find_hint_pair_for_candidates(_sorted_hint_groups(groups))


func _find_hint_pair_for_candidates(candidates: Array) -> Array:
	var locked_candidates := _sorted_hint_groups(locked_groups)
	if locked_candidates.is_empty():
		locked_candidates = _sorted_locked_hint_groups()
	for a in candidates:
		if a == null or not is_instance_valid(a.node):
			continue
		if a.locked:
			continue
		for b in locked_candidates:
			if a == b:
				continue
			if b == null or not is_instance_valid(b.node):
				continue
			if not b.locked:
				continue
			if not _groups_are_neighbors(a, b):
				continue
			var pair := _neighbor_member_pair(a, b)
			if not pair.is_empty():
				return [a, b, pair[0], pair[1]]
	return []


func _sorted_locked_hint_groups() -> Array:
	var result := []
	for group in groups:
		if group != null and group.locked:
			result.append(group)
	return _sorted_hint_groups(result)


func _sorted_hint_groups(source_groups: Array) -> Array:
	var result := source_groups.duplicate()
	result.sort_custom(func(a, b) -> bool:
		return _hint_group_sort_key(a) < _hint_group_sort_key(b)
	)
	return result


func _hint_group_sort_key(group) -> String:
	if group == null:
		return "~"
	var ids: Array[String] = []
	for member in group.members:
		ids.append(str(member.get("id", "")))
	ids.sort()
	return "|".join(ids)


func _hint_pair_key(pair: Array) -> String:
	if pair.is_empty():
		return ""
	var parts: Array[String] = [_hint_group_sort_key(pair[0])]
	if pair.size() > 1:
		parts.append(_hint_group_sort_key(pair[1]))
	if pair.size() > 2:
		parts.append(str(pair[2].get("id", "")))
	if pair.size() > 3:
		parts.append(str(pair[3].get("id", "")))
	return "->".join(parts)


func _groups_are_neighbors(a, b) -> bool:
	return not _neighbor_member_pair(a, b).is_empty()


func _neighbor_member_pair(a, b) -> Array:
	var a_members: Array = a.members.duplicate()
	var b_members: Array = b.members.duplicate()
	a_members.sort_custom(func(first, second) -> bool:
		return str(first.get("id", "")) < str(second.get("id", ""))
	)
	b_members.sort_custom(func(first, second) -> bool:
		return str(first.get("id", "")) < str(second.get("id", ""))
	)
	for am in a_members:
		for bm in b_members:
			if am["neighbors"].has(bm["id"]) or bm["neighbors"].has(am["id"]):
				return [am, bm]
	return []


func _hint_pulse_node(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	for i in 2:
		tween.tween_property(node, "scale", Vector2(1.5, 1.5), 0.30)
		tween.tween_property(node, "scale", Vector2.ONE, 0.30)
