extends RefCounted
class_name LevelCardFactory

const LEVEL_LIST_THUMBNAIL_SIZE := Vector2i(450, 600)

var game: Node


func _init(owner: Node) -> void:
	game = owner


func build(topic: Dictionary, level: Dictionary, unlocked: bool, card_width: float, scale: float) -> Control:
	var card_height := card_width * 4.0 / 3.0
	var topic_color: Color = game._topic_color(topic)
	var radius := int(card_width * 0.07)
	var card := Control.new()
	card.custom_minimum_size = Vector2(card_width, card_height)
	card.size = card.custom_minimum_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		add_back(card, topic, topic_color, card_width, card_height, radius)
		return card
	var level_config: Dictionary = game.repository.load_level_config(level)
	add_cover(card, level_config, topic_color, card_width, card_height, radius)
	var overlay_height := card_height * 0.27
	var overlay := Panel.new()
	overlay.name = "level_card_overlay"
	overlay.position = Vector2(0.0, card_height - overlay_height)
	overlay.size = Vector2(card_width, overlay_height)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.08, 0.07, 0.06, 0.42)
	overlay_style.corner_radius_bottom_left = radius
	overlay_style.corner_radius_bottom_right = radius
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(overlay)
	var available_modes: Array[String] = game._available_modes_for_config(level_config)
	var name_label := Label.new()
	name_label.text = game._level_display_title(level)
	name_label.position = Vector2(card_width * 0.05, overlay_height * 0.06)
	name_label.size = Vector2(card_width * 0.90, overlay_height * 0.42)
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", maxi(14, int(overlay_height * 0.34)))
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.35))
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(name_label)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", int(card_width * 0.075))
	icons.position = Vector2(0.0, overlay_height * 0.50)
	icons.size = Vector2(card_width, overlay_height * 0.44)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(icons)
	var icon_size := overlay_height * 0.40
	for play_mode in available_modes:
		var state: String = game._level_mode_state(topic, level, play_mode)
		var icon: Control = game._mode_state_icon(play_mode, state, icon_size)
		icons.add_child(icon)
	return card


func add_cover(card: Control, level_config: Dictionary, topic_color: Color, card_width: float, card_height: float, radius: int) -> void:
	var thumb_path: String = game.repository.level_thumbnail_source_path(level_config)
	var cover_texture: Texture2D
	if not thumb_path.is_empty() and (ResourceLoader.exists(thumb_path) or FileAccess.file_exists(game.repository.image_file_path(thumb_path))):
		cover_texture = game.repository.runtime_thumbnail(thumb_path, LEVEL_LIST_THUMBNAIL_SIZE)
	if cover_texture != null:
		var rect := TextureRect.new()
		rect.name = "level_card_cover"
		rect.texture = cover_texture
		rect.material = game._rounded_texture_material(Vector2(card_width, card_height), float(radius))
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(rect)
		return
	var panel := Panel.new()
	panel.name = "level_card_cover"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = game._rounded_panel_style(topic_color.lightened(0.18), radius)
	style.border_color = topic_color.lightened(0.38)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(panel)


func add_back(card: Control, topic: Dictionary, topic_color: Color, card_width: float, card_height: float, radius: int) -> void:
	var back_path := str(topic.get("card_back", ""))
	var back_texture: Texture2D = game.repository.cached_texture(back_path) if not back_path.is_empty() else null
	if back_texture != null:
		var rect := TextureRect.new()
		rect.name = "level_card_back"
		rect.texture = back_texture
		rect.material = game._rounded_texture_material(Vector2(card_width, card_height), float(radius))
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(rect)
		return
	var panel := Panel.new()
	panel.name = "level_card_back"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = game._rounded_panel_style(topic_color.darkened(0.42), radius)
	style.border_color = topic_color.lightened(0.10)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(panel)
	var inner := Panel.new()
	inner.position = Vector2(card_width * 0.06, card_width * 0.06)
	inner.size = Vector2(card_width * 0.88, card_height - card_width * 0.12)
	var inner_style := StyleBoxFlat.new()
	inner_style.draw_center = false
	inner_style.border_color = Color(topic_color.lightened(0.20), 0.55)
	inner_style.border_width_left = 2
	inner_style.border_width_top = 2
	inner_style.border_width_right = 2
	inner_style.border_width_bottom = 2
	inner_style.corner_radius_top_left = int(radius * 0.7)
	inner_style.corner_radius_top_right = int(radius * 0.7)
	inner_style.corner_radius_bottom_left = int(radius * 0.7)
	inner_style.corner_radius_bottom_right = int(radius * 0.7)
	inner.add_theme_stylebox_override("panel", inner_style)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
