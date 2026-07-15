extends RefCounted
class_name TopicsScreen

const THEME_LIST_BG_PATH := "res://assets/ui/theme-list/theme-list-background.png"
const THEME_LOGO_PATH := "res://assets/ui/theme-list/jigcat-logo.png"
const THEME_SQUARE_BUTTON_PATH := "res://assets/ui/theme-list/square-button-base.png"
const THEME_CIRCLE_BUTTON_PATH := "res://assets/ui/theme-list/circle-arrow-button-base.png"
const THEME_SETTINGS_ICON_PATH := "res://assets/ui/theme-list/settings-icon.png"
const THEME_ARROW_ICON_PATH := "res://assets/ui/theme-list/arrow-right-icon.png"

var game: Node


func _init(owner: Node) -> void:
	game = owner


func show() -> void:
	game._persist_current_puzzle_state()
	game.current_screen = "topics"
	game._clear_ui()
	game._clear_board()
	var scale := ui_scale()
	var viewport_size: Vector2 = game.get_viewport_rect().size
	_add_background()
	game.topics_island_items.clear()
	game.topics_scroll_offset = 0.0
	game.topics_scroll_velocity = 0.0
	game.topics_drag_active = false
	game.topics_content = Control.new()
	game.topics_content.name = "topics_content"
	game.topics_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(game.topics_content)
	var columns := 2 if viewport_size.x / maxf(1.0, viewport_size.y) >= 0.65 else 1
	var side_margin := 18.0 * scale
	var gap := 6.0 * scale
	var card_width: float = (viewport_size.x - side_margin * 2.0 - gap * float(columns - 1)) / float(columns)
	var card_height: float = card_width * card_aspect()
	var count: int = game.topics.size()
	var top := grid_top_offset(topbar_height(scale), scale)
	var y := top
	if game.topics.is_empty():
		var empty: Label = game._empty_topic_message()
		empty.position = Vector2((viewport_size.x - empty.custom_minimum_size.x) * 0.5, y)
		game.topics_content.add_child(empty)
		y += empty.custom_minimum_size.y
	for index in count:
		var topic: Dictionary = game.topics[index]
		var col: int = index % columns
		var row: int = index / columns
		var x: float = side_margin + float(col) * (card_width + gap)
		y = top + float(row) * (card_height + gap)
		var card := build_card(topic, card_width, scale)
		card.position = Vector2(x, y)
		game.topics_content.add_child(card)
		game.topics_island_items.append({
			"rect": Rect2(Vector2(x, y), Vector2(card_width, card_height)),
			"action": func(t: Dictionary = topic) -> void: game._open_topic_levels(t),
		})
	if not game.topics.is_empty():
		y += card_height
	game.topics_content_height = y + 32.0 * scale
	var catcher := Control.new()
	catcher.name = "topics_scroll_catcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(Callable(game, "_on_topics_gui_input"))
	game.screen_root.add_child(catcher)
	game.screen_root.add_child(_build_topbar(scale))
	game._apply_topics_scroll()
	game._fade_control_in(game.topics_content)


func ui_scale() -> float:
	return clampf(game.get_viewport_rect().size.x / 390.0, 1.0, 3.3)


func grid_top_offset(topbar_bottom: float, scale: float) -> float:
	return topbar_bottom + 10.0 * scale


func topbar_height(scale: float) -> float:
	return 104.0 * scale


func card_aspect() -> float:
	return 0.285


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
	var ratio := 0.0 if total <= 0 else clampf(float(done) / float(total), 0.0, 1.0)
	var card := Control.new()
	card.name = "theme_card_%s" % str(topic.get("id", ""))
	card.custom_minimum_size = Vector2(card_width, card_height)
	card.size = card.custom_minimum_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_radius := int(card_height * 0.10)
	var base := Panel.new()
	base.name = "theme_card_base"
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	var base_style: StyleBoxFlat = game._rounded_panel_style(Color("#FFF8EC").lerp(topic_color, 0.16), card_radius)
	base_style.border_color = topic_color.lightened(0.14)
	base_style.border_color.a = 0.5
	base_style.border_width_left = 1
	base_style.border_width_top = 1
	base_style.border_width_right = 1
	base_style.border_width_bottom = 1
	base_style.shadow_color = Color(0.35, 0.23, 0.13, 0.14)
	base_style.shadow_size = int(5.0 * scale)
	base_style.shadow_offset = Vector2(0, 2.0 * scale)
	base.add_theme_stylebox_override("panel", base_style)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(base)
	var pad := 5.0 * scale
	var top_y := pad
	var bottom_y := card_height - pad
	var cover_height := card_height - pad * 2.0
	var cover_width := cover_height * 1.58
	var cover_radius := int(card_radius * 0.75)
	var cover_texture: Texture2D = game._rounded_topic_cover_texture(topic, Vector2i(int(cover_width), int(cover_height)), cover_radius)
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
		cover.add_theme_stylebox_override("panel", game._rounded_panel_style(Color("#FFF5E3").lerp(topic_color, 0.26), cover_radius))
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cover)
	var text_x := pad + cover_width + card_width * 0.04
	var circle_size := card_height * 0.38
	var right_edge := card_width - pad - card_width * 0.025
	var badge_size := Vector2(card_height * 0.36, card_height * 0.18)
	var badge_position := Vector2(right_edge - badge_size.x, top_y + card_height * 0.07)
	var title := Label.new()
	title.name = "theme_card_title"
	title.text = str(topic.get("name", ""))
	title.position = Vector2(text_x, top_y + card_height * 0.14)
	title.size = Vector2(maxf(0.0, badge_position.x - text_x - card_width * 0.02), card_height * 0.24)
	title.clip_text = true
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", maxi(16, int(card_height * 0.17)))
	title.add_theme_color_override("font_color", game.brown)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)
	var bar_height := card_height * 0.085
	var available_bar_width := right_edge - circle_size - card_width * 0.025 - text_x
	var bar_width := minf(card_width * 0.32, maxf(card_width * 0.22, available_bar_width))
	var bar: Panel = game._topic_progress_bar(done, total, Vector2(bar_width, bar_height), topic_color)
	bar.name = "theme_card_progress"
	bar.position = Vector2(text_x, top_y + card_height * 0.60)
	card.add_child(bar)
	var count_height := card_height * 0.14
	var count := Label.new()
	count.name = "theme_card_progress_count"
	count.text = "%d/%d" % [done, total]
	count.position = Vector2(text_x, top_y + card_height * 0.73)
	count.size = Vector2(bar_width, count_height)
	count.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	count.add_theme_font_size_override("font_size", maxi(12, int(card_height * 0.11)))
	count.add_theme_color_override("font_color", game.soft_brown)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(count)
	var badge := Panel.new()
	badge.name = "theme_card_percent_badge"
	badge.position = badge_position
	badge.size = badge_size
	var badge_style: StyleBoxFlat = game._rounded_panel_style(topic_color, int(badge_size.y * 0.5))
	badge_style.border_color = Color(1.0, 1.0, 1.0, 0.75)
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)
	var percent := Label.new()
	percent.text = "%d%%" % roundi(ratio * 100.0)
	percent.set_anchors_preset(Control.PRESET_FULL_RECT)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent.add_theme_font_size_override("font_size", maxi(12, int(card_height * 0.105)))
	percent.add_theme_color_override("font_color", Color.WHITE)
	percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(percent)
	var circle := TextureRect.new()
	circle.name = "theme_card_arrow_button"
	circle.texture = game.repository.cached_texture(THEME_CIRCLE_BUTTON_PATH)
	circle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	circle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	circle.position = Vector2(right_edge - circle_size, bottom_y - circle_size - card_height * 0.10)
	circle.size = Vector2(circle_size, circle_size)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(circle)
	var arrow := TextureRect.new()
	arrow.texture = game.repository.cached_texture(THEME_ARROW_ICON_PATH)
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var arrow_inset := circle_size * 0.28
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.offset_left = arrow_inset
	arrow.offset_top = arrow_inset
	arrow.offset_right = -arrow_inset
	arrow.offset_bottom = -arrow_inset
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(arrow)
	return card
