extends RefCounted
class_name BoardLayout

const BOARD_HORIZONTAL_GAP := 5.0


static func mobile_board_layout(
	source_size: Vector2,
	viewport_size: Vector2,
	top_reserved_height: float,
	bottom_reserved_height: float,
) -> Dictionary:
	var content_top := clampf(top_reserved_height, 0.0, viewport_size.y)
	var content_bottom := clampf(viewport_size.y - bottom_reserved_height, content_top, viewport_size.y)
	var play_area := Rect2(
		Vector2(BOARD_HORIZONTAL_GAP, content_top),
		Vector2(
			maxf(1.0, viewport_size.x - BOARD_HORIZONTAL_GAP * 2.0),
			maxf(1.0, content_bottom - content_top),
		)
	)
	var safe_source_size := Vector2(maxf(1.0, source_size.x), maxf(1.0, source_size.y))
	var scale := minf(play_area.size.x / safe_source_size.x, play_area.size.y / safe_source_size.y)
	var board_size := source_size * scale
	var origin := Vector2(
		(viewport_size.x - board_size.x) * 0.5,
		content_top + (play_area.size.y - board_size.y) * 0.5,
	)
	return {
		"source_scale": scale,
		"board_origin": origin,
		"board_size": board_size,
		"play_area": play_area,
		"top_gap": origin.y - content_top,
		"bottom_gap": content_bottom - origin.y - board_size.y,
	}
