extends RefCounted
class_name BoardLayout

const DEFAULT_BOARD_MARGIN_RATIO := 0.70
const DEFAULT_HUD_HEIGHT_RATIO := 0.0
const DEFAULT_SIDE_MARGIN_RATIO := 0.0
const DEFAULT_BOTTOM_MARGIN_RATIO := 0.0
const GAME_EDGE_MARGIN := 20.0
const GAME_HEADER_MARGIN := 20.0
const GAME_FOOTER_MARGIN := 18.0


static func mobile_board_layout(
	source_size: Vector2,
	viewport_size: Vector2,
	level_config: Dictionary,
	piece_count: int,
	icon_button_size: float,
) -> Dictionary:
	var layout_config := runtime_layout_config(level_config)
	var hud_height := game_top_reserved_height(viewport_size, icon_button_size, layout_config)
	var side_margin := maxf(GAME_EDGE_MARGIN, viewport_size.x * float(layout_config["side_margin_ratio"]))
	var bottom_margin := game_bottom_reserved_height(icon_button_size) + viewport_size.y * float(layout_config["bottom_margin_ratio"])
	var play_area := Rect2(
		Vector2(side_margin, hud_height),
		Vector2(
			maxf(240.0, viewport_size.x - side_margin * 2.0),
			maxf(220.0, viewport_size.y - hud_height - bottom_margin)
		)
	)
	var fit_scale := minf(play_area.size.x / source_size.x, play_area.size.y / source_size.y)
	var scale := fit_scale * board_margin_ratio_for_layout(layout_config, play_area, source_size, viewport_size.x, piece_count)
	var board_size := source_size * scale
	var origin := play_area.position + (play_area.size - board_size) * 0.5
	return {
		"source_scale": scale,
		"board_origin": origin,
		"board_size": board_size,
		"play_area": play_area,
	}


static func game_top_reserved_height(viewport_size: Vector2, icon_button_size: float, layout_config: Dictionary) -> float:
	return icon_button_size + GAME_HEADER_MARGIN + viewport_size.y * float(layout_config["hud_height_ratio"])


static func game_bottom_reserved_height(icon_button_size: float) -> float:
	return 0.0


static func board_margin_ratio_for_layout(
	layout_config: Dictionary,
	play_area: Rect2,
	source_size: Vector2,
	viewport_width: float,
	piece_count: int,
) -> float:
	var configured_ratio := float(layout_config["board_margin_ratio"])
	var adaptive_ratio := 0.70
	if viewport_width < 430.0:
		adaptive_ratio = 0.70
	elif viewport_width < 700.0:
		adaptive_ratio = 0.70
	else:
		adaptive_ratio = 0.70
	if source_size.x > 0.0 and source_size.y > 0.0:
		var source_aspect := source_size.x / source_size.y
		var play_aspect := play_area.size.x / play_area.size.y
		if source_aspect > 0.82 and source_aspect < 1.22:
			adaptive_ratio -= 0.04
		elif source_aspect > play_aspect * 1.45 or source_aspect < play_aspect * 0.62:
			adaptive_ratio += 0.04
	if piece_count >= 49:
		adaptive_ratio -= 0.03
	elif piece_count > 0 and piece_count <= 16:
		adaptive_ratio += 0.03
	return clampf(minf(configured_ratio, adaptive_ratio), 0.58, 0.90)


static func runtime_layout_config(level_config: Dictionary) -> Dictionary:
	var config := {
		"board_margin_ratio": DEFAULT_BOARD_MARGIN_RATIO,
		"hud_height_ratio": DEFAULT_HUD_HEIGHT_RATIO,
		"side_margin_ratio": DEFAULT_SIDE_MARGIN_RATIO,
		"bottom_margin_ratio": DEFAULT_BOTTOM_MARGIN_RATIO,
	}
	if level_config.has("runtime_layout") and typeof(level_config["runtime_layout"]) == TYPE_DICTIONARY:
		var source_config: Dictionary = level_config["runtime_layout"]
		config["board_margin_ratio"] = clampf(float(source_config.get("board_margin_ratio", config["board_margin_ratio"])), 0.58, 0.95)
		config["hud_height_ratio"] = clampf(float(source_config.get("hud_height_ratio", config["hud_height_ratio"])), 0.0, 0.18)
		config["side_margin_ratio"] = clampf(float(source_config.get("side_margin_ratio", config["side_margin_ratio"])), 0.0, 0.10)
		config["bottom_margin_ratio"] = clampf(float(source_config.get("bottom_margin_ratio", config["bottom_margin_ratio"])), 0.0, 0.12)
	return config
