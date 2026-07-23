extends RefCounted
class_name GameHud

var game: Node


func _init(owner: Node) -> void:
	game = owner


func topic_ui_asset_texture(topic: Dictionary, key: String) -> Texture2D:
	var assets_value = topic.get("ui_assets", {})
	if typeof(assets_value) != TYPE_DICTIONARY:
		return null
	var assets := assets_value as Dictionary
	var path := str(assets.get(key, ""))
	var texture: Texture2D = game.repository.cached_texture(path) if not path.is_empty() else null
	var region_value = assets.get("%s_region" % key, [])
	if texture == null or typeof(region_value) != TYPE_ARRAY or region_value.size() != 4:
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		float(region_value[0]),
		float(region_value[1]),
		float(region_value[2]),
		float(region_value[3]),
	)
	return atlas


func add_topic_title_decorations(
	parent: Control,
	title: Label,
	bar_height: float,
	requested_center_x := -1.0,
	top_offset := 0.0,
	requested_size := Vector2.ZERO,
	requested_gap := -1.0,
	topic_override: Dictionary = {},
) -> void:
	var asset_topic: Dictionary = topic_override if not topic_override.is_empty() else game.current_topic
	var texture := topic_ui_asset_texture(asset_topic, "title_side")
	if texture == null:
		texture = topic_ui_asset_texture(asset_topic, "title_mountains")
	if texture == null:
		return
	var viewport_width: float = game.get_viewport_rect().size.x
	var decoration_size: Vector2 = requested_size if requested_size != Vector2.ZERO else Vector2(clampf(viewport_width * 0.11, 104.0, 136.0), 42.0)
	var font := title.get_theme_font("font")
	var font_size := title.get_theme_font_size("font_size")
	var measured_title_width := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var title_width := maxf(88.0, measured_title_width)
	var gap: float = requested_gap if requested_gap >= 0.0 else 16.0
	var center_x: float = requested_center_x if requested_center_x >= 0.0 else viewport_width * 0.5
	var top := top_offset + (bar_height - decoration_size.y) * 0.5
	var left := topic_title_decoration(texture, false, decoration_size)
	left.name = "topic_title_decoration_left"
	left.position = Vector2(center_x - title_width * 0.5 - gap - decoration_size.x, top)
	parent.add_child(left)
	var right := topic_title_decoration(texture, true, decoration_size)
	right.name = "topic_title_decoration_right"
	right.position = Vector2(center_x + title_width * 0.5 + gap, top)
	parent.add_child(right)
	var ear_texture := topic_ui_asset_texture(asset_topic, "title_ear")
	if ear_texture != null:
		add_topic_title_ears(
			parent,
			ear_texture,
			center_x,
			title_width,
			font_size,
			bar_height,
			top_offset,
			decoration_size,
		)


func add_topic_title_ears(
	parent: Control,
	texture: Texture2D,
	center_x: float,
	title_width: float,
	font_size: float,
	bar_height: float,
	top_offset: float,
	decoration_size: Vector2,
) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var ear_height := minf(decoration_size.y * 0.55, font_size * 0.48)
	var ear_width := ear_height * texture_size.x / texture_size.y
	var ear_size := Vector2(ear_width, ear_height)
	var ear_top := top_offset + (bar_height - font_size) * 0.5 - ear_height
	var ear_center_distance := maxf(ear_width + 2.0, title_width * 0.65)
	var left := topic_title_decoration(texture, false, ear_size)
	left.name = "topic_title_ear_left"
	left.position = Vector2(center_x - ear_center_distance * 0.5 - ear_width * 0.5, ear_top)
	parent.add_child(left)
	var right := topic_title_decoration(texture, true, ear_size)
	right.name = "topic_title_ear_right"
	right.position = Vector2(center_x + ear_center_distance * 0.5 - ear_width * 0.5, ear_top)
	parent.add_child(right)


func topic_title_decoration(texture: Texture2D, flipped: bool, size: Vector2) -> TextureRect:
	var decoration := TextureRect.new()
	decoration.texture = texture
	decoration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	decoration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	decoration.flip_h = flipped
	decoration.size = size
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return decoration


func text_button_width(text: String) -> float:
	return maxf(20.0, float(text.length()) * game.HUD_TEXT_BUTTON_FONT_SIZE * 0.9)


func text_button_height() -> float:
	return float(game.HUD_TEXT_BUTTON_FONT_SIZE) + 8.0
