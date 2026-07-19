extends RefCounted
class_name TopicsScreen

const TopicHomeControlsScript := preload("res://scripts/catalog/TopicHomeControls.gd")
const TopicHomeChromeScript := preload("res://scripts/catalog/TopicHomeChrome.gd")
const TopicSelectorPanelScript := preload("res://scripts/catalog/TopicSelectorPanel.gd")

var game: Node
var controls
var chrome
var selector
var page_layout: Dictionary = {}
var fixed_ui: Control
var pager_indicator: Panel
var selector_panel: Panel
var title_label: Label
var progress_label: Label
var previous_label: Label
var next_label: Label
var current_topic_index := 0
var entering_topic := false
var chrome_initialized := false


func _init(owner: Node) -> void:
	game = owner
	controls = TopicHomeControlsScript.new(owner)
	chrome = TopicHomeChromeScript.new(owner, controls)
	selector = TopicSelectorPanelScript.new(owner, controls)


func show() -> void:
	game._persist_current_puzzle_state()
	game.current_screen = "topics"
	game._clear_ui()
	game._clear_board()
	game.topic_home_motion.begin_screen(game.topics)
	var scale := ui_scale()
	var viewport_size: Vector2 = game.get_viewport_rect().size
	page_layout = _page_layout(viewport_size, scale)
	_reset_scroll_state()
	entering_topic = false
	chrome_initialized = false
	var initial_topic: Dictionary = game.progress_store.current_topic_or_first(game.topics)
	current_topic_index = _topic_index(str(initial_topic.get("id", "")))
	var viewport := _build_pages_viewport(viewport_size)
	if game.topics.is_empty():
		_add_empty_state(viewport_size, scale)
		return
	pager_indicator = chrome.build_indicator(game.topics.size(), viewport_size, scale, page_layout)
	game.screen_root.add_child(pager_indicator)
	game.topic_pager_controller.configure(
		game.topics_content,
		game.topics.size(),
		viewport_size.x,
		Callable(self, "_build_page"),
		pager_indicator.get_node("topic_pager_thumb"),
		current_topic_index,
		Callable(self, "_on_current_topic_changed"),
	)
	_add_gesture_catcher()
	var chrome_nodes: Dictionary = chrome.build(viewport_size, scale, page_layout, {
		"settings": Callable(game, "_show_settings_modal"),
		"enter": Callable(self, "_enter_current_topic"),
		"previous": Callable(self, "_previous_topic"),
		"all": Callable(self, "_toggle_selector"),
		"next": Callable(self, "_next_topic"),
	})
	fixed_ui = chrome_nodes.root
	title_label = chrome_nodes.title
	progress_label = chrome_nodes.progress_label
	previous_label = chrome_nodes.previous_label
	next_label = chrome_nodes.next_label
	game.screen_root.add_child(fixed_ui)
	selector_panel = selector.build(
		viewport_size,
		scale,
		float(page_layout.enter_top) - 12.0 * scale,
		game.topics,
		current_topic_index,
		Callable(self, "_select_topic"),
	)
	selector.set_toggle_icon(chrome_nodes.all_icon)
	game.screen_root.add_child(selector_panel)
	_on_current_topic_changed(current_topic_index)
	game.topics_content_height = viewport_size.y
	var current_page: Control = game.topic_pager_controller.rendered_pages.get(0, null)
	game.topic_home_motion.animate_entrance(fixed_ui, current_page, pager_indicator, scale)


func ui_scale() -> float:
	var viewport: Vector2 = game.get_viewport_rect().size
	return clampf(minf(viewport.x / 390.0, viewport.y / 844.0), 1.0, 3.3)


func grid_top_offset(topbar_bottom: float, scale: float) -> float:
	return topbar_bottom + 10.0 * scale


func topbar_height(scale: float) -> float:
	return 104.0 * scale


func card_aspect() -> float:
	return 0.44


func build_card(topic: Dictionary, card_width: float, _scale: float) -> Control:
	var card := Control.new()
	card.name = "theme_card_%s" % str(topic.get("id", ""))
	card.size = Vector2(card_width, card_width * card_aspect())
	var cover_path := str(topic.get("cover", ""))
	if cover_path.is_empty():
		var fallback := Panel.new()
		fallback.name = "theme_card_cover"
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.add_theme_stylebox_override("panel", controls.style_box(TopicHomeControls.SURFACE, 18))
		card.add_child(fallback)
	else:
		var art := TextureRect.new()
		art.name = "theme_card_cover_art"
		art.texture = game.repository.cached_texture(cover_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(art)
	return card


func _page_layout(viewport_size: Vector2, scale: float) -> Dictionary:
	var nav_height := 58.0 * scale
	var nav_top := viewport_size.y - 18.0 * scale - nav_height
	var enter_height := 58.0 * scale
	var enter_top := minf(viewport_size.y * 0.72, nav_top - enter_height - 70.0 * scale)
	return {
		"viewport": viewport_size,
		"scale": scale,
		"nav_top": nav_top,
		"nav_height": nav_height,
		"enter_top": enter_top,
		"enter_height": enter_height,
	}


func _build_pages_viewport(viewport_size: Vector2) -> Control:
	var viewport := Control.new()
	viewport.name = "topic_pages_viewport"
	viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.clip_contents = true
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(viewport)
	var transition_base := ColorRect.new()
	transition_base.name = "topic_pages_transition_base"
	transition_base.color = Color("#FFF6E9")
	transition_base.size = viewport_size
	transition_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(transition_base)
	game.topics_content = Control.new()
	game.topics_content.name = "topics_content"
	game.topics_content.size = Vector2(viewport_size.x * 3.0, viewport_size.y)
	game.topics_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(game.topics_content)
	return viewport


func _build_page(topic_index: int) -> Control:
	var viewport_size: Vector2 = page_layout.get("viewport", game.get_viewport_rect().size)
	var topic: Dictionary = game.topics[topic_index]
	var page := Control.new()
	page.name = "topic_page_%d" % topic_index
	page.size = viewport_size
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := ColorRect.new()
	base.name = "topic_home_base"
	base.color = Color("#FFF6E9").lerp(Color(str(topic.get("color", "#FFF6E9"))), 0.08)
	base.size = viewport_size
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(base)
	var cover := TextureRect.new()
	cover.name = "topic_home_cover"
	cover.texture = game.repository.cached_texture(str(topic.get("cover", "")))
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.size = viewport_size
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(cover)
	var readability := ColorRect.new()
	readability.name = "topic_home_readability"
	readability.color = Color(1.0, 0.98, 0.94, 0.06)
	readability.size = viewport_size
	readability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(readability)
	return page


func _add_gesture_catcher() -> void:
	var catcher := Control.new()
	catcher.name = "topics_pager_catcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(Callable(game, "_on_topics_gui_input"))
	game.screen_root.add_child(catcher)


func _on_current_topic_changed(topic_index: int) -> void:
	if game.topics.is_empty():
		return
	current_topic_index = clampi(topic_index, 0, game.topics.size() - 1)
	var topic: Dictionary = game.topics[current_topic_index]
	game.current_topic = topic
	game.progress_store.set_current_topic(str(topic.get("id", "")))
	controls.set_fitted_label_text(title_label, str(topic.get("name", "")), maxi(28, int(35.0 * ui_scale())), maxi(20, int(24.0 * ui_scale())))
	progress_label.text = "%d/%d" % [game._topic_available_done_count(topic), game._topic_available_mode_total(topic)]
	var scale := ui_scale()
	controls.set_fitted_label_text(previous_label, str(game.topics[posmod(current_topic_index - 1, game.topics.size())].get("name", "")), maxi(15, int(16.0 * scale)), maxi(12, int(12.0 * scale)))
	controls.set_fitted_label_text(next_label, str(game.topics[posmod(current_topic_index + 1, game.topics.size())].get("name", "")), maxi(15, int(16.0 * scale)), maxi(12, int(12.0 * scale)))
	selector.update_current(current_topic_index)
	if chrome_initialized:
		game.topic_home_motion.animate_topic_text_change([title_label, progress_label, previous_label, next_label])
	chrome_initialized = true


func _previous_topic() -> void:
	selector.close()
	game.topic_pager_controller.go_relative(-1)


func _next_topic() -> void:
	selector.close()
	game.topic_pager_controller.go_relative(1)


func _select_topic(topic_index: int) -> void:
	game.topic_pager_controller.go_to_page(topic_index)


func _toggle_selector() -> void:
	selector.toggle()


func _enter_current_topic() -> void:
	if entering_topic or game.topics.is_empty():
		return
	entering_topic = true
	selector.close()
	var topic: Dictionary = game.topics[current_topic_index]
	var current_page: Control = game.topic_pager_controller.rendered_pages.get(0, null)
	await game.topic_home_motion.animate_enter_theme(fixed_ui, current_page)
	if game != null:
		game._open_topic_levels(topic)


func _reset_scroll_state() -> void:
	game.topics_island_items.clear()
	game.topics_scroll_offset = 0.0
	game.topics_scroll_velocity = 0.0
	game.topics_drag_active = false


func _add_empty_state(viewport_size: Vector2, scale: float) -> void:
	var empty: Label = game._empty_topic_message()
	empty.position = Vector2((viewport_size.x - empty.custom_minimum_size.x) * 0.5, viewport_size.y * 0.45)
	empty.add_theme_font_size_override("font_size", maxi(18, int(22.0 * scale)))
	game.screen_root.add_child(empty)


func _topic_index(topic_id: String) -> int:
	for index in game.topics.size():
		if str(game.topics[index].get("id", "")) == topic_id:
			return index
	return 0
