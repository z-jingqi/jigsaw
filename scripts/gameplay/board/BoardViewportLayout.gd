extends RefCounted
## Rebuild derived geometry on viewport changes while preserving puzzle progress.


static func refresh(board: Node2D, screen: Control) -> void:
	if not is_instance_valid(board) or not is_instance_valid(screen):
		return
	if board.current_mode.is_empty():
		return
	board.input_controller.cancel_interaction()
	var saved: Dictionary = board.state_snapshot()
	var original_config: Dictionary = board.active_level_config
	var layout_config := original_config.duplicate(true)
	# Auto-seed ties can change with floating-point geometry at a new size.
	# Keep the existing anchors rather than introducing an extra locked piece.
	var seed_ids: Array = []
	for group in saved.get("groups", []):
		if bool(group.get("seed", false)):
			seed_ids.append_array(group.get("members", []))
	if not seed_ids.is_empty():
		var mode_config: Dictionary = layout_config["modes"][board.current_mode]
		var assist: Dictionary = mode_config.get("assist", {}).duplicate(true)
		assist["seed"] = {"mode": "manual", "piece_ids": seed_ids}
		mode_config["assist"] = assist
	(
		board
		. start(
			layout_config,
			board.current_mode,
			board.texture,
			board.source_image,
			board.source_size,
			screen.top_reserved_height(),
			saved,
			screen.bottom_reserved_height(),
			screen.tray_rect(),
		)
	)
	board.active_level_config = original_config
	board.set_drag_blockers(screen.board_reserved_rects())
