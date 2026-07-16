extends RefCounted
class_name TopicsScreen

const THEME_LIST_BG_PATH := "res://assets/ui/theme-list/theme-list-background.png"
const THEME_LOGO_PATH := "res://assets/ui/theme-list/jigcat-logo.png"
const THEME_SQUARE_BUTTON_PATH := "res://assets/ui/theme-list/square-button-base.png"
const THEME_SETTINGS_ICON_PATH := "res://assets/ui/theme-list/settings-icon.png"

var game: Node
var page_layout: Dictionary = {}


func _init(owner: Node) -> void:
	game = owner


func show() -> void:
	game._persist_current_puzzle_state()
	game.current_screen = "topics"
	game._clear_ui()
	game._clear_board()
	game.topic_home_motion.begin_screen(game.topics)
	var scale := ui_scale()
	var viewport_size: Vector2 = game.get_viewport_rect().size
	_add_background()
	game.topics_island_items.clear()
	game.topics_scroll_offset = 0.0
	game.topics_scroll_velocity = 0.0
	game.topics_drag_active = false
	page_layout = _page_layout(viewport_size, scale)
	var page_count := ceili(float(game.topics.size()) / float(game.topic_pager_controller.PAGE_SIZE))
	var pages_viewport := Control.new()
	pages_viewport.name = "topic_pages_viewport"
	pages_viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages_viewport.clip_contents = true
	pages_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(pages_viewport)
	game.topics_content = Control.new()
	game.topics_content.name = "topics_content"
	game.topics_content.size = Vector2(viewport_size.x * float(maxi(1, page_count)), viewport_size.y)
	game.topics_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages_viewport.add_child(game.topics_content)
	if game.topics.is_empty():
		var empty: Label = game._empty_topic_message()
		empty.position = Vector2(
			(viewport_size.x - empty.custom_minimum_size.x) * 0.5,
			float(page_layout.get("top", 0.0)),
		)
		game.topics_content.add_child(empty)
	else:
		_build_topic_hit_items()
	var pager_indicator := _build_pager_indicator(page_count, viewport_size, scale)
	game.screen_root.add_child(pager_indicator)
	if not game.topics.is_empty():
		game.topic_pager_controller.configure(
			game.topics_content,
			game.topics.size(),
			viewport_size.x,
			Callable(self, "_build_page"),
			pager_indicator.get_node("topic_pager_thumb"),
		)
	game.topics_content_height = viewport_size.y
	var catcher := Control.new()
	catcher.name = "topics_pager_catcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(Callable(game, "_on_topics_gui_input"))
	game.screen_root.add_child(catcher)
	var topbar := _build_topbar(scale)
	game.screen_root.add_child(topbar)
	var first_page: Control = game.topic_pager_controller.rendered_pages.get(0, null)
	game.topic_home_motion.animate_entrance(topbar, first_page, pager_indicator, scale)


func ui_scale() -> float:
	return clampf(game.get_viewport_rect().size.x / 390.0, 1.0, 3.3)


func grid_top_offset(topbar_bottom: float, scale: float) -> float:
	return topbar_bottom + 10.0 * scale


func topbar_height(scale: float) -> float:
	return 104.0 * scale


func card_aspect() -> float:
	return 0.44


func _page_layout(viewport_size: Vector2, scale: float) -> Dictionary:
	var top := grid_top_offset(topbar_height(scale), scale)
	var gap := 7.0 * scale
	var outer_margin := 18.0 * scale
	var bottom_reserve := 44.0 * scale
	var max_card_width := maxf(1.0, viewport_size.x - outer_margin * 2.0)
	var available_cards_height := maxf(
		1.0,
		viewport_size.y - top - bottom_reserve - gap * float(game.topic_pager_controller.PAGE_SIZE - 1),
	)
	var height_limited_width := available_cards_height / float(game.topic_pager_controller.PAGE_SIZE) / card_aspect()
	var card_width := minf(max_card_width, height_limited_width)
	var card_height := card_width * card_aspect()
	return {
		"viewport_size": viewport_size,
		"scale": scale,
		"top": top,
		"gap": gap,
		"card_width": card_width,
		"card_height": card_height,
		"side_margin": (viewport_size.x - card_width) * 0.5,
		"content_bottom": top + card_height * float(game.topic_pager_controller.PAGE_SIZE) + gap * float(game.topic_pager_controller.PAGE_SIZE - 1),
	}


func _build_page(page_index: int) -> Control:
	var page := Control.new()
	page.name = "topic_page_%d" % page_index
	page.size = page_layout.get("viewport_size", game.get_viewport_rect().size)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var first_index: int = page_index * int(game.topic_pager_controller.PAGE_SIZE)
	var last_index: int = mini(game.topics.size(), first_index + int(game.topic_pager_controller.PAGE_SIZE))
	var card_width := float(page_layout.get("card_width", 1.0))
	var card_height := float(page_layout.get("card_height", 1.0))
	var side_margin := float(page_layout.get("side_margin", 0.0))
	var top := float(page_layout.get("top", 0.0))
	var gap := float(page_layout.get("gap", 0.0))
	var scale := float(page_layout.get("scale", 1.0))
	for topic_index in range(first_index, last_index):
		var row: int = topic_index - first_index
		var topic: Dictionary = game.topics[topic_index]
		var card := build_card(topic, card_width, scale)
		card.position = Vector2(side_margin, top + float(row) * (card_height + gap))
		page.add_child(card)
		game.topic_home_motion.register_card(card, topic, page_index, row)
	return page


func _build_topic_hit_items() -> void:
	var page_width: float = game.get_viewport_rect().size.x
	var card_width := float(page_layout.get("card_width", 1.0))
	var card_height := float(page_layout.get("card_height", 1.0))
	var side_margin := float(page_layout.get("side_margin", 0.0))
	var top := float(page_layout.get("top", 0.0))
	var gap := float(page_layout.get("gap", 0.0))
	for topic_index in game.topics.size():
		var page_index: int = topic_index / int(game.topic_pager_controller.PAGE_SIZE)
		var row: int = topic_index % int(game.topic_pager_controller.PAGE_SIZE)
		var topic: Dictionary = game.topics[topic_index]
		var position := Vector2(
			float(page_index) * page_width + side_margin,
			top + float(row) * (card_height + gap),
		)
		game.topics_island_items.append({
			"page_index": page_index,
			"topic_id": str(topic.get("id", "")),
			"rect": Rect2(position, Vector2(card_width, card_height)),
			"action": func(t: Dictionary = topic) -> void: game._open_topic_levels(t),
		})


func _build_pager_indicator(page_count: int, viewport_size: Vector2, scale: float) -> Panel:
	var indicator := Panel.new()
	indicator.name = "topic_pager_indicator"
	var track_width := minf(viewport_size.x * 0.38, 150.0 * scale)
	var track_height := maxf(4.0, 4.0 * scale)
	var content_bottom := float(page_layout.get("content_bottom", viewport_size.y - 40.0 * scale))
	indicator.position = Vector2(
		(viewport_size.x - track_width) * 0.5,
		minf(viewport_size.y - 22.0 * scale, content_bottom + 16.0 * scale),
	)
	indicator.size = Vector2(track_width, track_height)
	indicator.visible = page_count > 1
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track_style: StyleBoxFlat = game._capsule_panel_style(Color(0.47, 0.35, 0.24, 0.22), track_height)
	indicator.add_theme_stylebox_override("panel", track_style)
	var thumb := Panel.new()
	thumb.name = "topic_pager_thumb"
	var thumb_width := clampf(track_width / maxf(1.0, float(page_count)), 26.0 * scale, 58.0 * scale)
	thumb.size = Vector2(minf(track_width, thumb_width), track_height)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_theme_stylebox_override("panel", game._capsule_panel_style(game.deep_orange, track_height))
	indicator.add_child(thumb)
	return indicator


func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#FBF0DC")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(bg)
	var paper_bg := TextureRect.new()
	paper_bg.texture = game.repository.cached_texture(THEME_LIST_BG_PATH)
	paper_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	paper_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(paper_bg)


func _build_topbar(scale: float) -> Control:
	var viewport_width: float = game.get_viewport_rect().size.x
	var bar := Control.new()
	bar.name = "theme_topbar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = topbar_height(scale)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button_size := 64.0 * scale
	var side_margin := 20.0 * scale
	var settings_button := _square_button(THEME_SETTINGS_ICON_PATH, Callable(game, "_show_settings_modal"), button_size)
	settings_button.name = "theme_settings_button"
	settings_button.position = Vector2(viewport_width - side_margin - button_size, 18.0 * scale)
	bar.add_child(settings_button)
	var logo := TextureRect.new()
	logo.name = "theme_logo"
	logo.texture = game.repository.cached_texture(THEME_LOGO_PATH)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var logo_width := minf(viewport_width * 0.49, 230.0 * scale)
	var logo_height := logo_width * 0.5
	logo.position = Vector2((viewport_width - logo_width) * 0.5, 4.0 * scale)
	logo.size = Vector2(logo_width, logo_height)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(logo)
	return bar


func _square_button(icon_path: String, action: Callable, button_size: float) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(button_size, button_size)
	button.size = button.custom_minimum_size
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var base := TextureRect.new()
	base.texture = game.repository.cached_texture(THEME_SQUARE_BUTTON_PATH)
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(base)
	var icon := TextureRect.new()
	icon.texture = game.repository.cached_texture(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var inset := button_size * 0.24
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.pressed.connect(action)
	game._wire_button_animation(button)
	return button


func build_card(topic: Dictionary, card_width: float, scale: float) -> Control:
	var card_height := card_width * card_aspect()
	var topic_color: Color = game._topic_color(topic)
	var done: int = game._topic_available_done_count(topic)
	var total: int = game._topic_available_mode_total(topic)
	var card := Control.new()
	card.name = "theme_card_%s" % str(topic.get("id", ""))
	card.custom_minimum_size = Vector2(card_width, card_height)
	card.size = card.custom_minimum_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("topic_progress_done", done)
	card.set_meta("topic_progress_total", total)
	var card_radius := int(card_height * 0.10)
	var shadow := Panel.new()
	shadow.name = "theme_card_shadow"
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shadow_style: StyleBoxFlat = game._rounded_panel_style(Color("#FFF8EC"), card_radius)
	shadow_style.shadow_color = Color(0.35, 0.23, 0.13, 0.14)
	shadow_style.shadow_size = int(5.0 * scale)
	shadow_style.shadow_offset = Vector2(0, 2.0 * scale)
	shadow.add_theme_stylebox_override("panel", shadow_style)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shadow)
	var background_texture := _topic_card_background_texture(topic)
	if background_texture != null:
		var base := TextureRect.new()
		base.name = "theme_card_base"
		base.texture = background_texture
		base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		base.stretch_mode = TextureRect.STRETCH_SCALE
		base.set_anchors_preset(Control.PRESET_FULL_RECT)
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(base)
	else:
		var fallback := Panel.new()
		fallback.name = "theme_card_base"
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.add_theme_stylebox_override("panel", game._rounded_panel_style(Color("#FFF8EC").lerp(topic_color, 0.12), card_radius))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(fallback)
	var pad := maxf(5.0 * scale, card_height * 0.035)
	var top_y := pad
	var cover_height := card_height - pad * 2.0
	var cover_width := cover_height * 1.58
	var cover_radius := int(card_radius * 0.75)
	var cover_texture: Texture2D = game._left_rounded_topic_cover_texture(topic, Vector2i(int(cover_width), int(cover_height)), cover_radius)
	if cover_texture != null:
		var cover_rect := TextureRect.new()
		cover_rect.name = "theme_card_cover"
		cover_rect.texture = cover_texture
		cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover_rect.stretch_mode = TextureRect.STRETCH_SCALE
		cover_rect.position = Vector2(pad, top_y)
		cover_rect.size = Vector2(cover_width, cover_height)
		cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cover_rect)
	else:
		var cover := Panel.new()
		cover.name = "theme_card_cover"
		cover.position = Vector2(pad, top_y)
		cover.size = Vector2(cover_width, cover_height)
		var cover_style := StyleBoxFlat.new()
		cover_style.bg_color = Color("#FFF5E3").lerp(topic_color, 0.26)
		cover_style.corner_radius_top_left = cover_radius
		cover_style.corner_radius_bottom_left = cover_radius
		cover.add_theme_stylebox_override("panel", cover_style)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cover)
	var text_x := pad + cover_width + card_width * 0.04
	var right_edge := card_width - pad - card_width * 0.035
	var info_width := maxf(0.0, right_edge - text_x)
	var decoration_texture := _topic_card_decoration_texture(topic)
	if decoration_texture != null:
		var decoration := TextureRect.new()
		decoration.name = "theme_card_decoration"
		decoration.texture = decoration_texture
		decoration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		decoration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var decoration_size := Vector2(info_width * 0.50, card_height * 0.36)
		decoration.position = Vector2(right_edge - decoration_size.x, top_y + card_height * 0.08)
		decoration.size = decoration_size
		decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(decoration)
	var title := Label.new()
	title.name = "theme_card_title"
	title.text = str(topic.get("name", ""))
	title.position = Vector2(text_x, top_y + card_height * 0.13)
	title.size = Vector2(info_width, card_height * 0.25)
	title.clip_text = true
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", maxi(16, int(card_height * 0.145)))
	title.add_theme_color_override("font_color", game.brown)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)
	var bar_height := card_height * 0.055
	var bar_width := minf(card_width * 0.30, maxf(card_width * 0.20, info_width * 0.58))
	var bar: Panel = game._topic_progress_bar(done, total, Vector2(bar_width, bar_height), topic_color)
	bar.name = "theme_card_progress"
	bar.position = Vector2(text_x, top_y + card_height * 0.58)
	card.add_child(bar)
	var count_height := card_height * 0.14
	var count := Label.new()
	count.name = "theme_card_progress_count"
	count.text = "%d/%d" % [done, total]
	count.position = Vector2(text_x, top_y + card_height * 0.72)
	count.size = Vector2(bar_width, count_height)
	count.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	count.add_theme_font_size_override("font_size", maxi(12, int(card_height * 0.09)))
	count.add_theme_color_override("font_color", game.soft_brown)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(count)
	return card


func _topic_card_background_texture(topic: Dictionary) -> Texture2D:
	var assets_value = topic.get("ui_assets", {})
	if typeof(assets_value) != TYPE_DICTIONARY:
		return null
	var path := str((assets_value as Dictionary).get("topic_card_background", ""))
	return game.repository.cached_texture(path) if not path.is_empty() else null


func _topic_card_decoration_texture(topic: Dictionary) -> Texture2D:
	var assets_value = topic.get("ui_assets", {})
	if typeof(assets_value) != TYPE_DICTIONARY:
		return null
	var path := str((assets_value as Dictionary).get("topic_card_decoration", ""))
	return game.repository.cached_texture(path) if not path.is_empty() else null
