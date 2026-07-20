extends RefCounted
class_name LevelListScreen

const PagerScript := preload("res://scripts/catalog/LevelPagerController.gd")
const TopbarScript := preload("res://scripts/catalog/LevelListTopbar.gd")
const UiKitScript := preload("res://scripts/ui/JigcatUiKit.gd")
const BACK_ICON := "res://assets/ui/topic-home/chevron-left.png"

var game: Node
var pager
var topbar_builder
var ui
var topic: Dictionary = {}
var levels: Array = []
var locks: Dictionary = {}
var layout: Dictionary = {}
var click_targets: Dictionary = {}
var unlock_card: Control


func _init(owner: Node) -> void:
	game = owner
	pager = PagerScript.new(owner)
	topbar_builder = TopbarScript.new(owner)
	ui = UiKitScript.new(owner)


func show(next_topic: Dictionary, focus_level_id := "") -> void:
	game._persist_current_puzzle_state()
	game.current_screen = "levels"
	game.current_topic = next_topic
	game._clear_ui()
	game._clear_board()
	topic = next_topic
	levels = topic.get("levels", [])
	locks = game._compute_level_locks(topic)
	click_targets.clear()
	unlock_card = null
	var scale: float = game._topics_ui_scale()
	var viewport_size: Vector2 = game.get_viewport_rect().size
	layout = _calculate_layout(viewport_size, scale)
	add_background(topic)
	var pages_viewport := _build_pages_viewport()
	var track := Control.new()
	track.name = "level_pages_track"
	track.size = Vector2(pages_viewport.size.x * 3.0, pages_viewport.size.y)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages_viewport.add_child(track)
	var indicator := _build_indicator(_page_count(), viewport_size, scale)
	game.screen_root.add_child(indicator)
	var initial_page := _initial_page(focus_level_id)
	pager.configure(
		pages_viewport,
		track,
		_page_count(),
		initial_page,
		Callable(self, "_build_page"),
		indicator.get_node("level_pager_thumb"),
		Callable(self, "_on_page_changed"),
		Callable(self, "_on_page_tapped"),
	)
	game.screen_root.add_child(build_topbar(topic, scale))
	game._fade_control_in(pages_viewport)
	if unlock_card != null:
		_start_unlock.call_deferred(unlock_card, float(layout.card_width))
	elif str(topic.get("id", "")) == game.newly_unlocked_topic_id:
		_clear_pending_unlock()


func cancel_motion() -> void:
	if pager != null:
		pager.reset()


func debug_state() -> Dictionary:
	var state: Dictionary = pager.debug_state()
	state["columns"] = int(layout.get("columns", 0))
	state["rows"] = int(layout.get("rows", 0))
	state["per_page"] = int(layout.get("per_page", 0))
	state["card_size"] = Vector2(float(layout.get("card_width", 0.0)), float(layout.get("card_height", 0.0)))
	return state


func add_background(current_topic: Dictionary) -> void:
	var topic_color: Color = game._topic_color(current_topic)
	var base := ColorRect.new()
	base.color = UiKitScript.WARM_MIST.lerp(topic_color, 0.10)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(base)
	var path := str(current_topic.get("level_background", ""))
	var texture: Texture2D = game.repository.cached_texture(path) if not path.is_empty() else null
	if texture == null:
		return
	var image := TextureRect.new()
	image.name = "level_list_background"
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.modulate.a = 0.82
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(image)
	var veil := ColorRect.new()
	veil.color = Color(1.0, 0.98, 0.94, 0.12)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.screen_root.add_child(veil)


func build_topbar(current_topic: Dictionary, scale: float) -> Control:
	return topbar_builder.build(current_topic, game.get_viewport_rect().size, scale)


func build_back_button(button_size: float, palette: Dictionary, action: Callable = Callable()) -> Button:
	var tint: Color = palette.get("foreground", UiKitScript.DEEP_TEAL)
	return ui.icon_button(BACK_ICON, button_size, action if action.is_valid() else Callable(game, "_show_topics"), tint)


func apply_outline_nav_button_styles(button: Button, _outline: Color, button_size: float) -> void:
	button.add_theme_stylebox_override("normal", ui.surface_style(UiKitScript.SURFACE, int(button_size * 0.5)))
	button.add_theme_stylebox_override("hover", ui.surface_style(UiKitScript.SURFACE, int(button_size * 0.5)))
	button.add_theme_stylebox_override("pressed", ui.surface_style(UiKitScript.SURFACE_PRESSED, int(button_size * 0.5)))
	button.add_theme_stylebox_override("disabled", ui.surface_style(Color(UiKitScript.SURFACE, 0.55), int(button_size * 0.5)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _calculate_layout(viewport_size: Vector2, scale: float) -> Dictionary:
	var columns := 3 if viewport_size.x / maxf(1.0, viewport_size.y) >= 0.65 else 2
	var rows := 3
	var topbar_height := 104.0 * scale
	var indicator_height := 48.0 * scale
	var page_top := topbar_height
	var page_height := maxf(1.0, viewport_size.y - page_top - indicator_height)
	var side_margin := 14.0 * scale
	var gap := 10.0 * scale
	var width_limit := (viewport_size.x - side_margin * 2.0 - gap * float(columns - 1)) / float(columns)
	var height_limit := (page_height - 16.0 * scale - gap * float(rows - 1)) * 0.75 / float(rows)
	var card_width := maxf(1.0, minf(width_limit, height_limit))
	return {
		"viewport_size": viewport_size,
		"scale": scale,
		"columns": columns,
		"rows": rows,
		"per_page": columns * rows,
		"page_top": page_top,
		"page_height": page_height,
		"side_margin": side_margin,
		"gap": gap,
		"card_width": card_width,
		"card_height": card_width * 4.0 / 3.0,
	}


func _build_pages_viewport() -> Control:
	var viewport := Control.new()
	viewport.name = "level_pages_viewport"
	viewport.position = Vector2(0.0, float(layout.page_top))
	viewport.size = Vector2((layout.viewport_size as Vector2).x, float(layout.page_height))
	viewport.clip_contents = true
	viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport.gui_input.connect(Callable(pager, "handle_input"))
	game.screen_root.add_child(viewport)
	return viewport


func _build_page(page_index: int) -> Control:
	var page := Control.new()
	page.name = "level_page_%d" % page_index
	page.size = Vector2((layout.viewport_size as Vector2).x, float(layout.page_height))
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var targets: Array[Dictionary] = []
	click_targets[page_index] = targets
	var start := page_index * int(layout.per_page)
	var end := mini(start + int(layout.per_page), levels.size())
	if start >= end:
		_add_empty_state(page)
		return page
	for index in range(start, end):
		var level = levels[index]
		if typeof(level) != TYPE_DICTIONARY:
			continue
		var local_index := index - start
		var col := local_index % int(layout.columns)
		var row := local_index / int(layout.columns)
		var position := Vector2(
			float(layout.side_margin) + float(col) * (float(layout.card_width) + float(layout.gap)),
			8.0 * float(layout.scale) + float(row) * (float(layout.card_height) + float(layout.gap)),
		)
		var unlocked: bool = locks.get(str(level.get("id", "")), false)
		var card: Control = game._level_grid_card(topic, level, unlocked, float(layout.card_width), float(layout.scale))
		card.name = "level_card_%s" % str(level.get("id", ""))
		card.position = position
		page.add_child(card)
		if unlocked:
			targets.append({"rect": Rect2(position, card.size), "level": level})
		if (
			unlocked
			and str(topic.get("id", "")) == game.newly_unlocked_topic_id
			and str(level.get("id", "")) == game.newly_unlocked_level_id
		):
			unlock_card = card
	return page


func _build_indicator(count: int, viewport_size: Vector2, scale: float) -> Panel:
	var track := Panel.new()
	track.name = "level_pager_indicator"
	var width := minf(viewport_size.x * 0.36, 148.0 * scale)
	var height := maxf(3.0, 3.0 * scale)
	track.position = Vector2((viewport_size.x - width) * 0.5, viewport_size.y - 25.0 * scale)
	track.size = Vector2(width, height)
	track.visible = count > 1
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", ui.surface_style(Color(UiKitScript.DEEP_TEAL, 0.20), int(height * 0.5)))
	var thumb := Panel.new()
	thumb.name = "level_pager_thumb"
	thumb.size = Vector2(maxf(14.0 * scale, width / float(maxi(1, count))), height)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_theme_stylebox_override("panel", ui.surface_style(UiKitScript.DEEP_TEAL, int(height * 0.5)))
	track.add_child(thumb)
	return track


func _page_count() -> int:
	return maxi(1, ceili(float(levels.size()) / float(maxi(1, int(layout.per_page)))))


func _initial_page(focus_level_id: String) -> int:
	if focus_level_id.is_empty():
		return 0
	for index in levels.size():
		var level = levels[index]
		if typeof(level) == TYPE_DICTIONARY and str(level.get("id", "")) == focus_level_id:
			return index / maxi(1, int(layout.per_page))
	return 0


func _on_page_tapped(position: Vector2, page_index: int) -> void:
	for target in click_targets.get(page_index, []):
		if (target.rect as Rect2).has_point(position):
			game._show_mode_dialog(target.level)
			return


func _on_page_changed(_page_index: int) -> void:
	pass


func _start_unlock(card: Control, card_width: float) -> void:
	if card == null or not is_instance_valid(card):
		_clear_pending_unlock()
		return
	pager.set_locked(true)
	await game._animate_new_unlock_card(card, topic, card_width)
	if pager != null:
		pager.set_locked(false)
	_clear_pending_unlock()


func _clear_pending_unlock() -> void:
	game.newly_unlocked_topic_id = ""
	game.newly_unlocked_level_id = ""


func _add_empty_state(page: Control) -> void:
	var empty: Label = game._empty_level_message()
	empty.position = Vector2(float(layout.side_margin), 12.0 * float(layout.scale))
	page.add_child(empty)
