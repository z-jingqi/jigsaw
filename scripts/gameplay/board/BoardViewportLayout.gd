extends RefCounted
## Rebuild derived geometry on viewport changes while preserving puzzle progress.

const PENDING := &"viewport_board_rebuild"


static func request(
	board: Node2D,
	screen: Control,
	still_current: Callable,
	persist_current: Callable,
	completed: Callable,
	wait_until_idle: Callable
) -> void:
	if not is_instance_valid(screen):
		return
	if not screen.has_meta(PENDING):
		if not screen.has_live_board():
			return
		persist_current.call()
	refresh(board, screen, still_current, completed, wait_until_idle)


static func refresh(
	board: Node2D,
	screen: Control,
	still_current: Callable,
	completed: Callable,
	wait_until_idle: Callable
) -> void:
	if not is_instance_valid(board) or not is_instance_valid(screen):
		return
	if board.current_mode.is_empty():
		return
	board.input_controller.cancel_interaction()
	var pending: Dictionary = screen.get_meta(PENDING, {})
	if pending.is_empty():
		pending = {
			"saved": board.state_snapshot(),
			"config": board.active_level_config,
			"mode": board.current_mode,
			"texture": board.texture,
			"image": board.source_image,
			"source_size": board.source_size,
			"sequence": 0,
		}
	pending["sequence"] = int(pending.sequence) + 1
	var sequence: int = pending.sequence
	screen.set_meta(PENDING, pending)
	var saved: Dictionary = pending.saved
	var original_config: Dictionary = pending.config
	var layout_config := original_config.duplicate(true)
	# Auto-seed ties can change with floating-point geometry at a new size.
	# Keep the existing anchors rather than introducing an extra locked piece.
	var seed_ids: Array = []
	for group in saved.get("groups", []):
		if bool(group.get("seed", false)):
			seed_ids.append_array(group.get("members", []))
	if not seed_ids.is_empty():
		var mode_config: Dictionary = layout_config["modes"][pending.mode]
		var assist: Dictionary = mode_config.get("assist", {}).duplicate(true)
		assist["seed"] = {"mode": "manual", "piece_ids": seed_ids}
		mode_config["assist"] = assist
	screen.mark_board_preparing()
	# configure() increments generation synchronously before its first await.
	var generation: int = board.state_controller.generation + 1
	var loaded: bool = await (
		board
		. start_runtime(
			layout_config,
			pending.mode,
			pending.texture,
			pending.image,
			pending.source_size,
			screen.top_reserved_height(),
			screen.bottom_reserved_height(),
			screen.tray_rect(),
		)
	)
	if (
		not is_instance_valid(board)
		or not is_instance_valid(screen)
		or not screen.is_inside_tree()
		or not still_current.call()
		or board.state_controller.generation != generation
		or int((screen.get_meta(PENDING, {}) as Dictionary).get("sequence", -1)) != sequence
	):
		return
	board.active_level_config = original_config
	if not loaded:
		# Retain the immutable snapshot for another resize/retry; never capture
		# the incomplete replacement board as the user's saved progress.
		screen.mark_board_failed()
		return
	board.apply_state_snapshot(saved)
	board.set_drag_blockers(screen.board_reserved_rects())
	screen.remove_meta(PENDING)
	screen.mark_board_live()
	# Restoring a solved snapshot emits while board input is deliberately gated.
	# Replay only its completion notification after readiness/navigation settle.
	if board.completion_emitted:
		await wait_until_idle.call()
		if (
			is_instance_valid(board)
			and is_instance_valid(screen)
			and screen.is_inside_tree()
			and still_current.call()
			and board.state_controller.generation == generation
			and board.completion_emitted
		):
			completed.call()
