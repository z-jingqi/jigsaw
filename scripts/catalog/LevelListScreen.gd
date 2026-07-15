extends RefCounted
class_name LevelListScreen

const LEVEL_LIST_OVERSCAN_ROWS := 1.0
const THEME_ARROW_ICON_PATH := "res://assets/ui/theme-list/arrow-right-icon.png"

var game: Node


func _init(owner: Node) -> void:
	game = owner


func show(topic: Dictionary, focus_level_id := "") -> void:
	game._persist_current_puzzle_state()
	game.current_screen = "levels"
	game.current_topic = topic
	game._clear_ui()
	game._clear_board()
	var scale: float = game._topics_ui_scale()
	var viewport_size: Vector2 = game.get_viewport_rect().size
	add_background(topic)
	game.topics_island_items.clear()
	game.topics_scroll_offset = 0.0
	game.topics_scroll_velocity = 0.0
	game.topics_drag_active = false
	game.topics_content = Control.new()
	game.topics_content.name = "levels_content"
	game.topics_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(game.topics_content)
	var columns := 3 if viewport_size.x / maxf(1.0, viewport_size.y) >= 0.65 else 2
	var side_margin := 14.0 * scale
	var gap := 10.0 * scale
	var card_width: float = (viewport_size.x - side_margin * 2.0 - gap * float(columns - 1)) / float(columns)
	var card_height: float = card_width * 4.0 / 3.0
	var locks: Dictionary = game._compute_level_locks(topic)
	var levels: Array = topic.get("levels", [])
	var count: int = levels.size()
	var top: float = game._grid_top_offset(game._theme_topbar_height(scale), scale)
	var y := top
	var focus_row := -1
	if levels.is_empty():
		var empty: Label = game._empty_level_message()
		empty.position = Vector2((viewport_size.x - empty.custom_minimum_size.x) * 0.5, y)
		game.topics_content.add_child(empty)
		y += empty.custom_minimum_size.y
	for index in count:
		var level: Dictionary = levels[index]
		if typeof(level) != TYPE_DICTIONARY:
			continue
		var col: int = index % columns
		var row: int = index / columns
		var x: float = side_margin + float(col) * (card_width + gap)
		y = top + float(row) * (card_height + gap)
		var unlocked: bool = locks.get(str(level.get("id", "")), false)
		var item_rect := Rect2(Vector2(x, y), Vector2(card_width, card_height))
		game.level_virtual_items.append({
			"rect": item_rect,
			"topic": topic,
			"level": level,
			"unlocked": unlocked,
			"card_width": card_width,
			"ui_scale": scale,
			"animate_unlock": (
				unlocked
				and str(topic.get("id", "")) == game.newly_unlocked_topic_id
				and str(level.get("id", "")) == game.newly_unlocked_level_id
			),
		})
		var item := {"rect": item_rect}
		if unlocked:
			item["action"] = func(l: Dictionary = level) -> void: game._show_mode_dialog(l)
		game.topics_island_items.append(item)
		if str(level.get("id", "")) == focus_level_id:
			focus_row = row
	if not levels.is_empty():
		y += card_height
	game.topics_content_height = y + 32.0 * scale
	game.level_virtual_overscan = (card_height + gap) * LEVEL_LIST_OVERSCAN_ROWS
	var catcher := Control.new()
	catcher.name = "levels_scroll_catcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(Callable(game, "_on_topics_gui_input"))
	game.screen_root.add_child(catcher)
	game.screen_root.add_child(build_topbar(topic, scale))
	if focus_row > 0:
		game.topics_scroll_offset = clampf(top + float(focus_row) * (card_height + gap) - viewport_size.y * 0.30, 0.0, game._topics_max_scroll())
	game._apply_topics_scroll()
	game._fade_control_in(game.topics_content)
	if str(topic.get("id", "")) == game.newly_unlocked_topic_id:
		game.newly_unlocked_topic_id = ""
		game.newly_unlocked_level_id = ""


func add_background(topic: Dictionary) -> void:
	var topic_color: Color = game._topic_color(topic)
	var bg := ColorRect.new()
	bg.color = topic_color.darkened(0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(bg)
	var bg_path := str(topic.get("level_background", ""))
	var bg_texture: Texture2D = game.repository.cached_texture(bg_path) if not bg_path.is_empty() else null
	if bg_texture != null:
		var image_bg := TextureRect.new()
		image_bg.texture = bg_texture
		image_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		image_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.screen_root.add_child(image_bg)
		return
	var glow := ColorRect.new()
	glow.color = Color(topic_color.lightened(0.30), 0.16)
	glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	glow.offset_bottom = game.get_viewport_rect().size.y * 0.30
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(glow)


func build_topbar(topic: Dictionary, scale: float) -> Control:
	var viewport_width: float = game.get_viewport_rect().size.x
	var palette: Dictionary = game._topic_ui_palette(topic)
	var foreground: Color = palette.foreground
	var outline: Color = palette.outline
	var accent: Color = palette.accent
	var bar := Control.new()
	bar.name = "level_list_topbar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = game._theme_topbar_height(scale)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_height := 52.0 * scale
	var button_size := 34.0 * scale
	var side_margin := 20.0 * scale
	var top := 20.0 * scale
	var back_button := build_back_button(button_size, palette)
	back_button.position = Vector2(side_margin, top + (title_height - button_size) * 0.5)
	bar.add_child(back_button)
	var progress_size := Vector2(64.0 * scale, title_height)
	var progress := Control.new()
	progress.name = "level_list_progress"
	progress.position = Vector2(viewport_width - side_margin - progress_size.x, top)
	progress.size = progress_size
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(progress)
	var done: int = game._topic_available_done_count(topic)
	var total: int = game._topic_available_mode_total(topic)
	var progress_bar_size := Vector2(56.0 * scale, 7.0 * scale)
	var progress_label_height := 22.0 * scale
	var progress_gap := 3.0 * scale
	var progress_content_top := (progress_size.y - progress_label_height - progress_gap - progress_bar_size.y) * 0.5
	var progress_bar: Panel = game._topic_progress_bar(done, total, progress_bar_size, accent, Color(outline, 0.24))
	progress_bar.name = "level_list_progress_bar"
	progress_bar.position = Vector2((progress_size.x - progress_bar_size.x) * 0.5, progress_content_top + progress_label_height + progress_gap)
	progress.add_child(progress_bar)
	var progress_label := Label.new()
	progress_label.name = "level_list_progress_label"
	progress_label.text = "%d/%d" % [done, total]
	progress_label.position = Vector2(0.0, progress_content_top)
	progress_label.size = Vector2(progress_size.x, progress_label_height)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", int(14.0 * scale))
	progress_label.add_theme_color_override("font_color", foreground)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_child(progress_label)
	var title := Label.new()
	title.name = "level_list_title"
	title.text = str(topic.get("name", ""))
	title.position = Vector2(viewport_width * 0.28, top)
	title.size = Vector2(viewport_width * 0.44, title_height)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.add_theme_font_size_override("font_size", int(28.0 * scale))
	title.add_theme_color_override("font_color", foreground)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title)
	var title_font := title.get_theme_font("font")
	var title_font_size := title.get_theme_font_size("font_size")
	var title_text_width := title_font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_font_size).x
	var decoration_gap := 6.0 * scale
	var decoration_clearance := 4.0 * scale
	var decoration_width := minf(
		42.0 * scale,
		minf(
			viewport_width * 0.5 - title_text_width * 0.5 - decoration_gap - (back_button.position.x + button_size) - decoration_clearance,
			progress.position.x - (viewport_width * 0.5 + title_text_width * 0.5 + decoration_gap) - decoration_clearance,
		),
	)
	game._add_topic_title_decorations(
		bar,
		title,
		title_height,
		viewport_width * 0.5,
		top,
		Vector2(maxf(20.0 * scale, decoration_width), 26.0 * scale),
		decoration_gap,
		topic,
	)
	return bar


func build_back_button(button_size: float, palette: Dictionary, action: Callable = Callable()) -> Button:
	var button := Button.new()
	button.name = "level_list_back_button"
	button.text = ""
	button.custom_minimum_size = Vector2(button_size, button_size)
	button.size = button.custom_minimum_size
	var outline: Color = palette.outline
	apply_outline_nav_button_styles(button, outline, button_size)
	var arrow := TextureRect.new()
	arrow.name = "level_list_back_icon"
	var arrow_texture: Texture2D = game.repository.cached_texture(THEME_ARROW_ICON_PATH)
	if arrow_texture != null:
		var cropped_arrow := AtlasTexture.new()
		cropped_arrow.atlas = arrow_texture
		cropped_arrow.region = Rect2(415.0, 214.0, 500.0, 826.0)
		arrow_texture = cropped_arrow
	arrow.texture = arrow_texture
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.flip_h = true
	var inset := button_size * 0.20
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.offset_left = inset
	arrow.offset_top = inset
	arrow.offset_right = -inset
	arrow.offset_bottom = -inset
	arrow.material = game._icon_tint_material(palette.foreground)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(arrow)
	button.pressed.connect(action if action.is_valid() else Callable(game, "_show_topics"))
	game._wire_button_animation(button)
	return button


func apply_outline_nav_button_styles(button: Button, outline: Color, button_size: float) -> void:
	button.add_theme_stylebox_override("normal", outline_nav_button_style(outline, button_size))
	button.add_theme_stylebox_override("hover", outline_nav_button_style(outline, button_size, 0.08))
	button.add_theme_stylebox_override("pressed", outline_nav_button_style(outline, button_size, 0.14))
	button.add_theme_stylebox_override("disabled", outline_nav_button_style(outline, button_size))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func outline_nav_button_style(outline: Color, button_size: float, background_alpha := 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(outline, background_alpha)
	style.border_color = outline
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	var radius := int(button_size * 0.24)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
