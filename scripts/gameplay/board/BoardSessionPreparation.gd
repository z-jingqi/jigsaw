extends RefCounted
## Prepares a runtime board in small batches before enabling gameplay input.

const CREATION_BUDGET_USEC := 7000

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func configure(options: Dictionary) -> bool:
	host.clear()
	host.active_level_config = options.config
	host.current_mode = host._mode_key(options.mode)
	host.texture = options.texture
	host.source_image = options.image
	host.source_size = options.source_size
	host.piece_visual_style = host._piece_visual_style()
	var curve_preview: bool = (
		OS.get_environment("JIGSAW_CURVED_EDGE_PREVIEW") == "1"
		and host.current_mode in ["polygon", "knob"]
	)
	host.piece_visual_style["curve_preview"] = curve_preview
	host.piece_visual_style["cardboard"] = host.current_mode == "polygon" or curve_preview
	host.hud_top_reserved_height = options.top
	host.hud_bottom_reserved_height = maxf(0.0, options.bottom)
	host.tray_bounds_override = options.tray
	host.completion_emitted = false
	host._add_level_background(host.active_level_config)
	host.world_root = host.get_node_or_null("WorldRoot") as Node2D
	host.tray_root = host.get_node_or_null("TrayRoot") as Node2D
	if host.world_root == null or host.tray_root == null:
		push_error("PuzzleBoard requires WorldRoot and TrayRoot scene hosts.")
		return false
	host.tray_root.z_index = int(host.tray_config["z_index"])
	host.tray_root.z_as_relative = false
	host._reset_view_transform()
	return true


func build_progressive() -> bool:
	var tree: SceneTree = host.get_tree()
	var generation: int = host.state_controller.generation
	await tree.process_frame
	if not _current(generation):
		return false
	if host.current_mode == "swap":
		return host.session_builder._start_play_session("swap")
	var started := Time.get_ticks_usec()
	var prepared: Dictionary = host.session_builder.prepare_pieces(host.current_mode)
	if prepared.is_empty():
		return false
	# Piece data and creation share a budget, rather than forcing an idle frame
	# between cheap stages. Keep layout and saved-state restoration separate.
	if Time.get_ticks_usec() - started >= CREATION_BUDGET_USEC:
		await tree.process_frame
		if not _current(generation):
			return false
		started = Time.get_ticks_usec()
	for piece in prepared.pieces:
		host.session_builder.create_group(piece, prepared.seed_ids.has(str(piece.get("id", ""))))
		host.groups.back().node.modulate.a = 0.0
		if Time.get_ticks_usec() - started >= CREATION_BUDGET_USEC:
			await tree.process_frame
			if not _current(generation):
				return false
			started = Time.get_ticks_usec()
	await tree.process_frame
	if not _current(generation):
		return false
	host.session_builder.finish_pieces()
	# Let layout settle before the coordinator restores saved groups and tray order.
	# Both stages rebuild visual geometry and must not occupy the same frame.
	await tree.process_frame
	if not _current(generation):
		return false
	for group in host.groups:
		group.node.modulate.a = 1.0
	return true


func _current(generation: int) -> bool:
	return (
		is_instance_valid(host)
		and host.is_inside_tree()
		and host.state_controller.generation == generation
	)
