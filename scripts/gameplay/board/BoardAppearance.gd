extends RefCounted
class_name BoardAppearance

var host: Node2D


func _init(owner: Node2D) -> void:
	host = owner


func _add_level_background(level_config: Dictionary) -> void:
	var viewport_size := host.get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = _level_background_color(level_config)
	bg.position = Vector2.ZERO
	bg.size = viewport_size
	bg.z_index = -101
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)
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
	host.add_child(bg_image)


func _level_background_color(level_config: Dictionary) -> Color:
	if level_config.has("background") and typeof(level_config["background"]) == TYPE_DICTIONARY:
		var bg: Dictionary = level_config["background"]
		return Color(str(bg.get("color", "#ead8bd")))
	return Color("#ead8bd")


func _piece_visual_style() -> Dictionary:
	var configured = host.active_level_config.get("piece_style", {})
	if host.edge_contrast_mode == "auto" and typeof(configured) == TYPE_DICTIONARY:
		var line_value := str(configured.get("line_color", ""))
		if not line_value.is_empty():
			var line_color := Color.from_string(line_value, host.PieceVisualFactoryScript.CUT_LINE_COLOR)
			var seam_color := Color.from_string(str(configured.get("seam_color", line_value)), line_color)
			return {
				"cut_line_color": line_color,
				"cut_line_lift_color": Color("#D98A43"),
				"seam_line_color": seam_color,
			}
	var use_light: bool = host.edge_contrast_mode == "light" or (host.edge_contrast_mode == "auto" and _source_average_luminance() < 0.46)
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
	if host.source_image == null or host.source_image.is_empty():
		return _level_background_color(host.active_level_config).get_luminance()
	var width: int = host.source_image.get_width()
	var height: int = host.source_image.get_height()
	var step_x := maxi(1, int(width / 24.0))
	var step_y := maxi(1, int(height / 24.0))
	var total := 0.0
	var count := 0
	for y in range(0, height, step_y):
		for x in range(0, width, step_x):
			var color: Color = host.source_image.get_pixel(x, y)
			if color.a <= 0.08:
				continue
			total += color.get_luminance()
			count += 1
	return total / float(count) if count > 0 else _level_background_color(host.active_level_config).get_luminance()


func _add_board_outline_shadow() -> void:
	if host.world_root == null or host.source_size.x <= 0.0 or host.source_size.y <= 0.0:
		return
	_add_board_line_frame()


func _add_board_line_frame() -> void:
	var frame := Panel.new()
	frame.name = "board_line_frame"
	frame.position = host.board_origin
	frame.size = host.source_size * host.source_scale
	frame.z_index = -49
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	var surface: Color = _topic_ui_color("surface", Color("#F5F0E3"))
	surface.a = host.BOARD_TARGET_BACKGROUND_ALPHA
	style.bg_color = surface
	var outline: Color = _topic_ui_color("outline", Color("#879174"))
	outline.a = 0.78
	style.border_color = outline
	style.border_width_left = host.BOARD_LINE_FRAME_WIDTH
	style.border_width_top = host.BOARD_LINE_FRAME_WIDTH
	style.border_width_right = host.BOARD_LINE_FRAME_WIDTH
	style.border_width_bottom = host.BOARD_LINE_FRAME_WIDTH
	var radius := maxi(10, int(minf(frame.size.x, frame.size.y) * 0.018))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	frame.add_theme_stylebox_override("panel", style)
	host.world_root.add_child(frame)


func _topic_ui_color(key: String, fallback: Color) -> Color:
	var palette_value = host.active_level_config.get("_topic_ui_palette", {})
	if typeof(palette_value) != TYPE_DICTIONARY:
		return fallback
	var palette: Dictionary = palette_value
	return Color(str(palette.get(key, fallback.to_html())))
