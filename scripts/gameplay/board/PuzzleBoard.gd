extends Node2D
class_name PuzzleBoard

signal completed
signal state_changed(state: Dictionary)
signal undo_available_changed(available: bool)

const SNAP_TOLERANCE := 22.0
const ROTATION_TOLERANCE := 3.0
const HIT_ALPHA_RADIUS := 2
const PIECE_DRAG_PADDING := 8.0
const VIEW_MIN_RATIO := 0.90
const VIEW_MAX_RATIO := 2.40
const TRACKPAD_MAGNIFY_MIN := 0.86
const TRACKPAD_MAGNIFY_MAX := 1.16
const VIEW_FIT_PADDING := 36.0
const BOARD_SCREEN_EDGE_GAP := 5.0
const BOARD_LINE_FRAME_WIDTH := 2
const BOARD_TARGET_BACKGROUND_ALPHA := 0.25
const VIEW_HINT_PADDING := 58.0
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
const TRAY_DRAG_LIFT_MARGIN := 28.0
const TRAY_DRAG_Z_INDEX := 4095
const TRAY_INERTIA_MIN_SPEED := 90.0
const TRAY_INERTIA_FRICTION := 9.0
const TRAY_TOP_BORDER_HEIGHT := 2.0
const TRAY_TOP_BORDER_COLOR := Color(0.39, 0.43, 0.34, 0.46)
const BoardLayoutScript := preload("res://scripts/gameplay/board/BoardLayout.gd")
const BoardStateControllerScript := preload("res://scripts/gameplay/board/BoardStateController.gd")
const BoardViewControllerScript := preload("res://scripts/gameplay/board/BoardViewController.gd")
const BoardDebugAdapterScript := preload("res://scripts/gameplay/board/BoardDebugAdapter.gd")
const BoardGeometryScript := preload("res://scripts/gameplay/board/BoardGeometry.gd")
const BoardAppearanceScript := preload("res://scripts/gameplay/board/BoardAppearance.gd")
const BoardSessionBuilderScript := preload("res://scripts/gameplay/board/BoardSessionBuilder.gd")
const BoardTrayControllerScript := preload("res://scripts/gameplay/board/BoardTrayController.gd")
const BoardInputControllerScript := preload("res://scripts/gameplay/board/BoardInputController.gd")
const BoardHintControllerScript := preload("res://scripts/gameplay/board/BoardHintController.gd")
const BoardSwapControllerScript := preload("res://scripts/gameplay/board/BoardSwapController.gd")
const BoardSnapControllerScript := preload("res://scripts/gameplay/board/BoardSnapController.gd")
const BoardPlacementControllerScript := preload("res://scripts/gameplay/board/BoardPlacementController.gd")
const PieceGroupScript := preload("res://scripts/gameplay/board/PieceGroup.gd")
const PieceVisualFactoryScript := preload("res://scripts/gameplay/board/PieceVisualFactory.gd")
const SnapSolverScript := preload("res://scripts/gameplay/board/SnapSolver.gd")

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
var tray_top_border: ColorRect
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
var tray_pending_group = null
var tray_pending_total_delta := Vector2.ZERO
var tray_scroll_velocity := 0.0
var tray_last_pan_msec := 0
var tray_inertia_active := false
var swap_tiles: Array = []
var swap_history: Array[Dictionary] = []
var dragging = null
var dragging_from_tray := false
var dragging_tray_index := -1
var tray_drag_screen_offset := Vector2.ZERO
var tray_drag_target_screen_offset := Vector2.ZERO
var tray_drag_offset_tween: Tween
var tray_drag_local_grab := Vector2.ZERO
var last_drag_screen_pos := Vector2.ZERO
var swap_dragging = null
var swap_drag_start_slot := -1
var swap_drag_offset := Vector2.ZERO
var swap_target_preview = null
var swap_target_preview_root: Node2D
var swap_target_preview_line: Line2D
var swap_target_preview_tween: Tween
var hint_highlighted_groups: Array = []
var hint_highlighted_lines: Array[Line2D] = []
var hint_highlighted_nodes: Array[Node] = []
var hint_blink_tweens: Array[Tween] = []
var active_touch_index := -1
var active_touches := {}
var drag_offset := Vector2.ZERO
var panning := false
var pan_touch_index := -1
var pinch_active := false
var pinch_start_distance := 0.0
var pinch_start_scale := 1.0
var pinch_start_world_midpoint := Vector2.ZERO
var hud_top_reserved_height := 56.0
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
var state_emit_pending := false
var last_state_emit_msec := 0
var haptics_enabled := true
var reduced_motion := false
var edge_contrast_mode := "auto"
var piece_visual_style := {}
var state_controller
var view_controller
var debug_adapter
var geometry
var appearance
var session_builder
var tray_controller
var input_controller
var hint_controller
var swap_controller
var snap_controller
var placement_controller


func _ready() -> void:
	rng.seed = 7
	state_controller = BoardStateControllerScript.new(self)
	view_controller = BoardViewControllerScript.new(self)
	debug_adapter = BoardDebugAdapterScript.new(self)
	geometry = BoardGeometryScript.new(self)
	appearance = BoardAppearanceScript.new(self)
	session_builder = BoardSessionBuilderScript.new(self)
	tray_controller = BoardTrayControllerScript.new(self)
	input_controller = BoardInputControllerScript.new(self)
	hint_controller = BoardHintControllerScript.new(self)
	swap_controller = BoardSwapControllerScript.new(self)
	snap_controller = BoardSnapControllerScript.new(self)
	placement_controller = BoardPlacementControllerScript.new(self)


func _exit_tree() -> void:
	# Composition helpers are RefCounted; break their back-references so the
	# board and helpers cannot keep each other alive after a test or scene exit.
	_cancel_runtime_animations()
	groups.clear()
	tray_groups.clear()
	locked_groups.clear()
	swap_tiles.clear()
	if state_controller != null:
		state_controller.cancel_pending()
		state_controller.board = null
	for controller in [view_controller, debug_adapter, geometry, appearance, session_builder, tray_controller, input_controller, hint_controller, swap_controller, snap_controller, placement_controller]:
		if controller != null:
			controller.host = null


func _cancel_runtime_animations() -> void:
	for group in groups:
		if group == null:
			continue
		if group.tray_tween != null and group.tray_tween.is_valid():
			group.tray_tween.kill()
		group.tray_tween = null
	for tween in [view_tween, tray_drag_offset_tween, swap_target_preview_tween, hint_tray_scroll_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	for tween in hint_blink_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	if hint_controller != null:
		hint_controller._stop_hint_clear_timer()
	view_tween = null
	tray_drag_offset_tween = null
	swap_target_preview_tween = null
	hint_tray_scroll_tween = null
	hint_blink_tweens.clear()


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


func set_feedback_preferences(next_haptics_enabled: bool, next_reduced_motion: bool, next_edge_contrast_mode := "auto") -> void:
	haptics_enabled = next_haptics_enabled
	reduced_motion = next_reduced_motion
	edge_contrast_mode = next_edge_contrast_mode if ["auto", "dark", "light"].has(next_edge_contrast_mode) else "auto"


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
	return state_controller.snapshot()


func should_persist_state() -> bool:
	return state_controller.should_persist()


func apply_state_snapshot(snapshot: Dictionary) -> void:
	state_controller.apply(snapshot)


func _restore_group_state(snapshot: Dictionary) -> void:
	state_controller.restore_group_state(snapshot)


func _restore_swap_state(snapshot: Dictionary) -> void:
	state_controller.restore_swap_state(snapshot)


func _restore_view_state(snapshot: Dictionary) -> void:
	state_controller.restore_view_state(snapshot)


func _notify_state_changed(immediate := false) -> void:
	state_controller.notify_changed(immediate)


func _vector_to_json(value: Vector2) -> Array:
	return state_controller.vector_to_json(value)


func _json_vector(value, fallback := Vector2.ZERO) -> Vector2:
	return state_controller.json_vector(value, fallback)


func start(level_config: Dictionary, play_mode: String, source_texture: Texture2D, image: Image, image_size: Vector2, top_reserved_height: float, random_rotation_enabled := false, restore_state := {}) -> bool:
	clear()
	active_level_config = level_config
	current_mode = _mode_key(play_mode)
	texture = source_texture
	source_image = image
	source_size = image_size
	piece_visual_style = _piece_visual_style()
	hud_top_reserved_height = top_reserved_height
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
	state_controller.cancel_pending()
	_clear_hint_highlights()
	_clear_swap_target_preview()
	_cancel_runtime_animations()
	for child in get_children():
		child.queue_free()
	groups.clear()
	tray_groups.clear()
	locked_groups.clear()
	tray_scroll_offset = 0.0
	tray_content_width = 0.0
	tray_panning = false
	tray_pending_group = null
	tray_pending_total_delta = Vector2.ZERO
	tray_scroll_velocity = 0.0
	tray_last_pan_msec = 0
	tray_inertia_active = false
	swap_tiles.clear()
	swap_history.clear()
	dragging = null
	dragging_from_tray = false
	dragging_tray_index = -1
	tray_drag_screen_offset = Vector2.ZERO
	tray_drag_target_screen_offset = Vector2.ZERO
	tray_drag_offset_tween = null
	tray_drag_local_grab = Vector2.ZERO
	last_drag_screen_pos = Vector2.ZERO
	swap_dragging = null
	swap_drag_start_slot = -1
	swap_drag_offset = Vector2.ZERO
	swap_target_preview = null
	swap_target_preview_root = null
	swap_target_preview_line = null
	swap_target_preview_tween = null
	hint_highlighted_groups.clear()
	hint_highlighted_lines.clear()
	hint_highlighted_nodes.clear()
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
	tray_top_border = null
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
	return input_controller.handle(event, modal_open)


func fit_view_to_pieces(animate := true) -> void:
	view_controller.fit_view_to_pieces(animate)


func reset_view() -> void:
	view_controller.reset_view()


func _reset_view_transform() -> void:
	view_controller._reset_view_transform()


func _apply_view_transform() -> void:
	view_controller._apply_view_transform()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return view_controller._screen_to_world(screen_pos)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return view_controller._world_to_screen(world_pos)


func _view_ratio() -> float:
	return view_controller._view_ratio()


func _view_ratio_for_scale(scale: float) -> float:
	return view_controller._view_ratio_for_scale(scale)


func _clamped_actual_scale(scale: float) -> float:
	return view_controller._clamped_actual_scale(scale)


func _zoom_view_at(screen_anchor: Vector2, target_scale: float) -> void:
	view_controller._zoom_view_at(screen_anchor, target_scale)


func _pan_view(delta: Vector2) -> void:
	view_controller._pan_view(delta)


func _begin_pan(screen_pos: Vector2, touch_index: int) -> void:
	view_controller._begin_pan(screen_pos, touch_index)


func _end_pan() -> void:
	view_controller._end_pan()


func _begin_pinch() -> void:
	view_controller._begin_pinch()


func _update_pinch() -> void:
	view_controller._update_pinch()


func _clamp_view_to_table() -> void:
	view_controller._clamp_view_to_table()


func _world_view_screen_rect() -> Rect2:
	return view_controller._world_view_screen_rect()


func _focus_hint_pair(pair: Array) -> void:
	view_controller._focus_hint_pair(pair)


func show_hint() -> void:
	hint_controller.show_hint()


func set_drag_blockers(blockers: Array[Rect2]) -> void:
	drag_blockers = blockers.duplicate()


func debug_runtime_metrics() -> Dictionary:
	return debug_adapter.debug_runtime_metrics()


func debug_clear_hint() -> void:
	debug_adapter.debug_clear_hint()


func debug_reset_tray() -> void:
	debug_adapter.debug_reset_tray()


func debug_scroll_tray_left() -> void:
	debug_adapter.debug_scroll_tray_left()


func debug_scroll_tray_right() -> void:
	debug_adapter.debug_scroll_tray_right()


func debug_toggle_bounds_overlay() -> void:
	debug_adapter.debug_toggle_bounds_overlay()


func debug_run_interaction_smoke() -> Dictionary:
	return await debug_adapter.debug_run_interaction_smoke()


func debug_force_complete() -> void:
	debug_adapter.debug_force_complete()


func debug_prepare_restore_snapshot() -> Dictionary:
	return debug_adapter.debug_prepare_restore_snapshot()


func debug_validate_restored_snapshot(expected: Dictionary) -> Dictionary:
	return debug_adapter.debug_validate_restored_snapshot(expected)


func _start_play_session(play_mode: String) -> bool:
	return session_builder._start_play_session(play_mode)


func _swap_slot_position(slot_index: int, cols := SWAP_FALLBACK_COLS, rows := SWAP_FALLBACK_ROWS) -> Vector2:
	return session_builder._swap_slot_position(slot_index, cols, rows)


func _mobile_board_layout() -> Dictionary:
	return session_builder._mobile_board_layout()


func _current_mode_piece_count() -> int:
	return session_builder._current_mode_piece_count()


func _swap_grid_config() -> Dictionary:
	return session_builder._swap_grid_config()


func _mode_key(play_mode: String) -> String:
	return geometry._mode_key(play_mode)


func _mode_config(level_config: Dictionary, play_mode: String) -> Dictionary:
	return geometry._mode_config(level_config, play_mode)


func _json_points(value) -> PackedVector2Array:
	return geometry._json_points(value)


func _json_point(value) -> Vector2:
	return geometry._json_point(value)


func _json_cell(value) -> Vector2i:
	return geometry._json_cell(value)


func _json_rect(value, fallback: Rect2) -> Rect2:
	return geometry._json_rect(value, fallback)


func _json_rects(value) -> Array[Rect2]:
	return geometry._json_rects(value)


func _local_rect_points(source_rect: Rect2, home: Vector2, scale: float, origin: Vector2) -> PackedVector2Array:
	return geometry._local_rect_points(source_rect, home, scale, origin)


func _polygon_center(points: PackedVector2Array) -> Vector2:
	return geometry._polygon_center(points)


func _source_rect_for_points(points: PackedVector2Array) -> Rect2:
	return geometry._source_rect_for_points(points)


func _points_bounds_area(points: PackedVector2Array) -> float:
	return geometry._points_bounds_area(points)


func _visible_source_rect_for_polygon(points: PackedVector2Array, fallback: Rect2) -> Rect2:
	return geometry._visible_source_rect_for_polygon(points, fallback)


func _add_level_background(level_config: Dictionary) -> void:
	appearance._add_level_background(level_config)


func _piece_visual_style() -> Dictionary:
	return appearance._piece_visual_style()


func _add_board_outline_shadow() -> void:
	appearance._add_board_outline_shadow()


func _tray_area() -> Rect2:
	return tray_controller._tray_area()


func _layout_tray(instant := false) -> void:
	tray_controller._layout_tray(instant)


func _clamp_tray_scroll() -> void:
	tray_controller._clamp_tray_scroll()


func _pan_tray(delta_x: float, record_velocity := true) -> void:
	tray_controller._pan_tray(delta_x, record_velocity)


func _stop_tray_inertia() -> void:
	tray_controller._stop_tray_inertia()


func _release_tray_pan() -> void:
	tray_controller._release_tray_pan()


func _tray_original_screen_scale() -> float:
	return tray_controller._tray_original_screen_scale()


func _move_group_to_tray(group, index: int, instant := false, forced_x := NAN) -> void:
	tray_controller._move_group_to_tray(group, index, instant, forced_x)


func _tray_group_at_screen(screen_pos: Vector2, exclude = null, hit_padding := TRAY_HIT_PADDING):
	return tray_controller._tray_group_at_screen(screen_pos, exclude, hit_padding)


func _begin_tray_piece_press(group, screen_pos: Vector2) -> void:
	tray_controller._begin_tray_piece_press(group, screen_pos)


func _end_tray_piece_press() -> void:
	tray_controller._end_tray_piece_press()


func _group_local_bounds(group) -> Rect2:
	return tray_controller._group_local_bounds(group)


func _send_group_to_world(group, world_position: Vector2, local_scale := 1.0) -> void:
	tray_controller._send_group_to_world(group, world_position, local_scale)


func _update_pending_tray_drag(screen_pos: Vector2, relative: Vector2) -> void:
	tray_controller._update_pending_tray_drag(screen_pos, relative)


func _update_drag_position(screen_pos: Vector2) -> void:
	tray_controller._update_drag_position(screen_pos)


func _move_group_to(group, target_position: Vector2, use_visible_area := true) -> void:
	placement_controller._move_group_to(group, target_position, use_visible_area)


func _debug_group_id(group) -> String:
	return debug_adapter._debug_group_id(group)


func _refresh_debug_bounds_overlay() -> void:
	debug_adapter._refresh_debug_bounds_overlay()


func _world_rect_to_screen(rect: Rect2) -> Rect2:
	return placement_controller._world_rect_to_screen(rect)


func _piece_drag_area(use_visible_area := false) -> Rect2:
	return placement_controller._piece_drag_area(use_visible_area)


func _virtual_table_area() -> Rect2:
	return placement_controller._virtual_table_area()


func _group_bounds_at(group, target_position: Vector2) -> Rect2:
	return placement_controller._group_bounds_at(group, target_position)


func _member_bounds_points_list(member: Dictionary) -> Array[PackedVector2Array]:
	return placement_controller._member_bounds_points_list(member)


func _end_drag() -> void:
	input_controller._end_drag()


func _group_at_world(world_pos: Vector2):
	return placement_controller._group_at_world(world_pos)


func _source_point_has_alpha(source_point: Vector2, radius := HIT_ALPHA_RADIUS) -> bool:
	return placement_controller._source_point_has_alpha(source_point, radius)


func _visible_cut_line_segments(source_line: PackedVector2Array, home: Vector2, scale: float, origin: Vector2) -> Array[PackedVector2Array]:
	return placement_controller._visible_cut_line_segments(source_line, home, scale, origin)


func _begin_swap_drag(screen_pos: Vector2) -> void:
	swap_controller._begin_swap_drag(screen_pos)


func _end_swap_drag() -> void:
	swap_controller._end_swap_drag()


func _move_swap_tile_to(tile, target_position: Vector2) -> void:
	swap_controller._move_swap_tile_to(tile, target_position)


func _clear_swap_target_preview() -> void:
	swap_controller._clear_swap_target_preview()


func _swap_tile_bounds(tile, target_position: Vector2) -> Rect2:
	return swap_controller._swap_tile_bounds(tile, target_position)


func can_undo_swap() -> bool:
	return swap_controller.can_undo_swap()


func undo_last_swap() -> void:
	swap_controller.undo_last_swap()


func _show_swap_hint() -> void:
	swap_controller._show_swap_hint()


func _find_swap_hint_pair() -> Array:
	return swap_controller._find_swap_hint_pair()


func _check_swap_complete() -> void:
	swap_controller._check_swap_complete()


func _swap_cols() -> int:
	return swap_controller._swap_cols()


func _swap_rows() -> int:
	return swap_controller._swap_rows()


func _rotate_group(group) -> void:
	snap_controller._rotate_group(group)


func _bring_to_front(group) -> void:
	snap_controller._bring_to_front(group)


func _refresh_group_z_indices() -> void:
	snap_controller._refresh_group_z_indices()


func _update_snap_preview(active) -> void:
	snap_controller._update_snap_preview(active)


func _clear_snap_preview() -> void:
	snap_controller._clear_snap_preview()


func _refresh_snap_preview_line_widths() -> void:
	snap_controller._refresh_snap_preview_line_widths()


func _try_snap_chain(active) -> bool:
	return snap_controller._try_snap_chain(active)


func _seam_line_width() -> float:
	return snap_controller._seam_line_width()


func _play_snap_shimmer(members: Array) -> void:
	snap_controller._play_snap_shimmer(members)


func _lock_group(group) -> void:
	snap_controller._lock_group(group)


func _return_group_to_tray(group) -> void:
	snap_controller._return_group_to_tray(group)


func _snap_tolerance() -> float:
	return snap_controller._snap_tolerance()


func _check_complete() -> void:
	snap_controller._check_complete()


func _has_active_hint_highlights() -> bool:
	return hint_controller._has_active_hint_highlights()


func _spawn_dashed_outline(parent: Node2D, polygons: Array, local_position: Vector2, z_index_value: int) -> Node2D:
	return hint_controller._spawn_dashed_outline(parent, polygons, local_position, z_index_value)


func _refresh_hint_line_widths() -> void:
	hint_controller._refresh_hint_line_widths()


func _update_hint_line_width(line) -> void:
	hint_controller._update_hint_line_width(line)


func _auto_clear_hint_highlights(token: int) -> void:
	hint_controller._auto_clear_hint_highlights(token)


func _clear_hint_highlights() -> void:
	hint_controller._clear_hint_highlights()


func _find_hint_pair() -> Array:
	return hint_controller._find_hint_pair()
