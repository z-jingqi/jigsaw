extends RefCounted
## Shares the assembled image and its current canvas bounds without a GPU readback.


static func describe(board: Node2D) -> Dictionary:
	if not is_instance_valid(board.world_root) or board.texture == null:
		return {}
	var image_rect := Rect2(board.board_origin, board.source_size * board.source_scale)
	return {
		"texture": board.texture,
		"rect": board.world_root.get_global_transform_with_canvas() * image_rect,
	}
