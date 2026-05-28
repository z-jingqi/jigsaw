extends Node2D

const MENU_BACKGROUND_PATH := "res://assets/source/menu_background.png"
const TITLE_IMAGE_PATH := "res://assets/ui/title.png"
const START_BUTTON_IMAGE_PATH := "res://assets/ui/start-game.png"
const CHOOSE_LEVEL_PANEL_PATH := "res://assets/ui/choose-level.png"
const COMPLETE_RIBBON_PATH := "res://assets/ui/complete_ribbon.png"
const ICON_ALBUM_PATH := "res://assets/icons/album.svg"
const ICON_LEFT_ARROW_PATH := "res://assets/icons/left-arrow.svg"
const ICON_LIGHTBULB_PATH := "res://assets/icons/lightbulb.svg"
const ICON_PAUSE_PATH := "res://assets/icons/pause.svg"
const ICON_SETTING_PATH := "res://assets/icons/setting.svg"
const ICON_CAT_PAW_PATH := "res://assets/icons/status/cat_paw.png"
const ICON_MODE_PUZZLE_DONE_PATH := "res://assets/icons/status/mode_puzzle_done.png"
const ICON_MODE_PUZZLE_TODO_PATH := "res://assets/icons/status/mode_puzzle_todo.png"
const ICON_MODE_POLYGON_DONE_PATH := "res://assets/icons/status/mode_polygon_done.png"
const ICON_MODE_POLYGON_TODO_PATH := "res://assets/icons/status/mode_polygon_todo.png"
const BoardLayoutScript := preload("res://scripts/BoardLayout.gd")
const LevelRepositoryScript := preload("res://scripts/LevelRepository.gd")
const ProgressStoreScript := preload("res://scripts/ProgressStore.gd")
const PuzzleBoardScript := preload("res://scripts/PuzzleBoard.gd")
const GAME_FOOTER_MARGIN := 18.0
const HUD_BLOCKER_PADDING := 18.0
const HUD_DEBUG_MEASUREMENTS := true
const HUD_TEXT_BUTTON_FONT_SIZE := 22

var cream := Color("#F6EBD4")
var paper := Color("#FFF6E6")
var soft_beige := Color("#F8E7C7")
var orange := Color("#D9933F")
var deep_orange := Color("#C77C2E")
var brown := Color("#5A3A22")
var soft_brown := Color("#8A6847")
var green := Color("#6f9d67")
var muted := Color("#b7aa97")

var texture: Texture2D
var repository = LevelRepositoryScript.new()
var menu_background: Texture2D
var title_texture: Texture2D
var start_button_texture: Texture2D
var choose_level_panel_texture: Texture2D
var complete_ribbon_texture: Texture2D
var icon_album: Texture2D
var icon_left_arrow: Texture2D
var icon_lightbulb: Texture2D
var icon_pause: Texture2D
var icon_setting: Texture2D
var icon_cat_paw: Texture2D
var icon_mode_puzzle_done: Texture2D
var icon_mode_puzzle_todo: Texture2D
var icon_mode_polygon_done: Texture2D
var icon_mode_polygon_todo: Texture2D
var source_image: Image
var source_size := Vector2.ZERO
var source_scale := 1.0
var board_origin := Vector2.ZERO
var active_level_config := {}
var puzzle_board: PuzzleBoard
var ui_layer: CanvasLayer
var screen_root: Control
var modal_root: Control

var topics: Array[Dictionary] = []
var progress_store = ProgressStoreScript.new()
var current_topic: Dictionary = {}
var current_level: Dictionary = {}
var current_mode := "knob"
var current_screen := "home"
var modal_open := false

var status_label: Label
var zoom_label: Label
var hud_blocker_controls: Array[Control] = []


func _ready() -> void:
	_lock_portrait_orientation()
	menu_background = load(MENU_BACKGROUND_PATH)
	title_texture = load(TITLE_IMAGE_PATH)
	start_button_texture = load(START_BUTTON_IMAGE_PATH)
	choose_level_panel_texture = load(CHOOSE_LEVEL_PANEL_PATH)
	complete_ribbon_texture = repository.cached_texture(COMPLETE_RIBBON_PATH)
	icon_album = load(ICON_ALBUM_PATH)
	icon_left_arrow = load(ICON_LEFT_ARROW_PATH)
	icon_lightbulb = load(ICON_LIGHTBULB_PATH)
	icon_pause = load(ICON_PAUSE_PATH)
	icon_setting = load(ICON_SETTING_PATH)
	icon_cat_paw = repository.cached_texture(ICON_CAT_PAW_PATH)
	icon_mode_puzzle_done = repository.cached_texture(ICON_MODE_PUZZLE_DONE_PATH)
	icon_mode_puzzle_todo = repository.cached_texture(ICON_MODE_PUZZLE_TODO_PATH)
	icon_mode_polygon_done = repository.cached_texture(ICON_MODE_POLYGON_DONE_PATH)
	icon_mode_polygon_todo = repository.cached_texture(ICON_MODE_POLYGON_TODO_PATH)
	puzzle_board = PuzzleBoardScript.new()
	puzzle_board.status_changed.connect(_set_game_status)
	puzzle_board.zoom_changed.connect(_set_zoom_label)
	puzzle_board.completed.connect(_on_puzzle_completed)
	add_child(puzzle_board)
	get_viewport().size_changed.connect(_queue_game_drag_blocker_refresh)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_build_catalog()
	_apply_level_media({})
	progress_store.load_from_disk()
	_show_last_topic_levels()


func _lock_portrait_orientation() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _unhandled_input(event: InputEvent) -> void:
	if current_screen != "game":
		return
	if puzzle_board.handle_input(event, modal_open):
		get_viewport().set_input_as_handled()


func _build_catalog() -> void:
	topics = repository.build_catalog()


func _clear_ui() -> void:
	for child in ui_layer.get_children():
		child.queue_free()
	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(screen_root)
	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(modal_root)
	modal_open = false


func _clear_board() -> void:
	if puzzle_board != null:
		puzzle_board.clear()


func _animate_screen_in(control: Control) -> void:
	control.modulate.a = 0.0
	control.position.y = 18.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "modulate:a", 1.0, 0.24)
	tween.tween_property(control, "position:y", 0.0, 0.24)


func _animate_modal_panel(panel: Control) -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18)


func _wire_button_animation(button: BaseButton) -> void:
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.button_down.connect(func() -> void:
		_tween_control_scale(button, Vector2(0.95, 0.95), 0.08)
	)
	button.button_up.connect(func() -> void:
		_tween_control_scale(button, Vector2.ONE, 0.12)
	)
	button.mouse_exited.connect(func() -> void:
		_tween_control_scale(button, Vector2.ONE, 0.12)
	)


func _tween_control_scale(control: Control, target: Vector2, duration: float) -> void:
	if not is_instance_valid(control):
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "scale", target, duration)


func _pulse_node(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "scale", Vector2(1.05, 1.05), 0.08)
	tween.tween_property(node, "scale", Vector2.ONE, 0.12)


func _hint_pulse_node(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	for i in 2:
		tween.tween_property(node, "scale", Vector2(1.08, 1.08), 0.24)
		tween.tween_property(node, "scale", Vector2.ONE, 0.34)


func _base_screen(bg_color: Color = Color("#F6EBD4"), use_menu_background := false) -> VBoxContainer:
	_clear_ui()
	_clear_board()
	if use_menu_background:
		var bg_image := TextureRect.new()
		bg_image.texture = menu_background
		bg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_image.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen_root.add_child(bg_image)
		var veil := ColorRect.new()
		veil.color = Color(0.96, 0.90, 0.80, 0.34)
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen_root.add_child(veil)
	else:
		var bg := ColorRect.new()
		bg.color = bg_color
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen_root.add_child(bg)
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.offset_left = 36
	wrap.offset_top = 28
	wrap.offset_right = -36
	wrap.offset_bottom = -28
	wrap.add_theme_constant_override("separation", 18)
	screen_root.add_child(wrap)
	_animate_screen_in(wrap)
	return wrap


func _header(parent: VBoxContainer, title: String, back: Callable = Callable()) -> void:
	var row := Control.new()
	row.custom_minimum_size.y = 112
	parent.add_child(row)
	if back.is_valid():
		var back_button := _icon_button(icon_left_arrow, back, "返回")
		back_button.position = Vector2(0, 22)
		row.add_child(back_button)
	var panel := TextureRect.new()
	panel.texture = choose_level_panel_texture
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.custom_minimum_size = Vector2(560, 112)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -280
	panel.offset_top = 0
	panel.offset_right = 280
	panel.offset_bottom = 112
	row.add_child(panel)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -220
	label.offset_top = 22
	label.offset_right = 220
	label.offset_bottom = 84
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", brown)
	row.add_child(label)


func _root_title(parent: VBoxContainer) -> void:
	var row := Control.new()
	row.custom_minimum_size.y = 150
	parent.add_child(row)
	var title := TextureRect.new()
	title.texture = title_texture
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size = Vector2(360, 128)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -180
	title.offset_top = 4
	title.offset_right = 180
	title.offset_bottom = 132
	row.add_child(title)


func _button(text: String, action: Callable, primary := true, min_size := Vector2(120, 42)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_color_override("font_color", Color.WHITE if primary else brown)
	button.add_theme_color_override("font_hover_color", Color.WHITE if primary else deep_orange)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = orange if primary else soft_beige
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = deep_orange if primary else paper
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = deep_orange if primary else soft_beige
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button


func _icon_button(icon: Texture2D, action: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = tooltip
	var icon_size := _texture_size(icon)
	button.custom_minimum_size = icon_size
	if _show_hud_debug_measurements():
		_apply_debug_control_background(button, Color(0.18, 0.52, 0.95, 0.24))
	else:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var empty := StyleBoxEmpty.new()
			button.add_theme_stylebox_override(state, empty)
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = icon_size
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = 0
	icon_rect.offset_top = 0
	icon_rect.offset_right = 0
	icon_rect.offset_bottom = 0
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.modulate = soft_brown
	button.add_child(icon_rect)
	button.mouse_entered.connect(func() -> void:
		icon_rect.modulate = deep_orange
	)
	button.mouse_exited.connect(func() -> void:
		icon_rect.modulate = soft_brown
	)
	button.button_down.connect(func() -> void:
		icon_rect.modulate = deep_orange
	)
	button.button_up.connect(func() -> void:
		icon_rect.modulate = soft_brown
	)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button


func _tool_text_button(text: String, action: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(_hud_text_button_width(text), _hud_text_button_height())
	button.add_theme_font_size_override("font_size", HUD_TEXT_BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", soft_brown)
	button.add_theme_color_override("font_hover_color", deep_orange)
	button.add_theme_color_override("font_pressed_color", deep_orange)
	if _show_hud_debug_measurements():
		_apply_debug_control_background(button, Color(0.95, 0.56, 0.18, 0.24))
	else:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var empty := StyleBoxEmpty.new()
			button.add_theme_stylebox_override(state, empty)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button


func _show_hud_debug_measurements() -> bool:
	return HUD_DEBUG_MEASUREMENTS and current_screen == "game"


func _apply_debug_control_background(control: Control, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = Color(0.22, 0.13, 0.04, 0.9)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	control.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "pressed", "disabled", "focus"]:
		control.add_theme_stylebox_override(state, normal.duplicate())


func _image_rect(min_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = min_size
	return rect


func _texture_rect(tex: Texture2D, min_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = min_size
	return rect


func _home_image_button(
	text: String,
	action: Callable,
	bg_texture: Texture2D = null,
	label_color := Color.WHITE,
	min_size := Vector2(420, 94),
) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = min_size
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var empty := StyleBoxEmpty.new()
		button.add_theme_stylebox_override(state, empty)
	var bg := TextureRect.new()
	bg.texture = bg_texture if bg_texture != null else start_button_texture
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(bg)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", label_color)
	label.add_theme_color_override("font_shadow_color", Color(0.36, 0.20, 0.08, 0.28))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button


func _show_home() -> void:
	current_screen = "home"
	var wrap := _base_screen(cream, true)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	wrap.add_child(top)
	top.add_child(_icon_button(icon_album, _show_album, "相册"))
	top.add_child(_icon_button(icon_setting, _show_settings_modal, "设置"))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	wrap.add_child(spacer)
	var title_holder := HBoxContainer.new()
	title_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(title_holder)
	title_holder.add_child(_texture_rect(title_texture, Vector2(430, 154)))
	var title_spacer := Control.new()
	title_spacer.custom_minimum_size.y = 58
	wrap.add_child(title_spacer)
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	wrap.add_child(buttons)
	var has_record := not progress_store.last_completed_level(topics).is_empty()
	var play_text := "继续游戏" if has_record else "开始游戏"
	buttons.add_child(_home_image_button(play_text, _start_from_home, start_button_texture, Color.WHITE))
	buttons.add_child(_home_image_button("选择关卡", _show_topics, choose_level_panel_texture, brown))


func _start_from_home() -> void:
	var target := progress_store.resume_target(topics)
	if target.is_empty() or target["level"].is_empty():
		_show_topics()
		return
	_show_game(target["topic"], target["level"], target["mode"])


func _show_last_topic_levels() -> void:
	var topic := progress_store.last_topic_or_first(topics)
	if topic.is_empty():
		_show_topics()
		return
	_show_levels(topic, progress_store.focus_level_id(topic))


func _show_topics() -> void:
	current_screen = "topics"
	var wrap := _base_screen(cream, true)
	_root_title(wrap)
	var top_actions := HBoxContainer.new()
	top_actions.alignment = BoxContainer.ALIGNMENT_END
	top_actions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_actions.offset_left = -150
	top_actions.offset_top = 28
	top_actions.offset_right = -36
	top_actions.offset_bottom = 82
	top_actions.add_theme_constant_override("separation", 8)
	screen_root.add_child(top_actions)
	top_actions.add_child(_icon_button(icon_album, _show_album, "相册"))
	top_actions.add_child(_icon_button(icon_setting, _show_settings_modal, "设置"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = _wide_grid_columns(2, 1)
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 24)
	center.add_child(grid)
	for topic in topics:
		var total: int = topic["levels"].size() * 3
		var done: int = progress_store.topic_done_count(topic)
		var card := _topic_card_button(topic, "%d/%d" % [done, total], func(t: Dictionary = topic) -> void: _show_levels(t, progress_store.focus_level_id(t)))
		grid.add_child(card)


func _show_levels(topic: Dictionary, focus_level_id := "") -> void:
	current_screen = "levels"
	current_topic = topic
	var wrap := _base_screen(cream, true)
	_header(wrap, topic["name"], _show_topics)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = _wide_grid_columns(2, 1)
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 24)
	center.add_child(grid)
	var focus_card: Control = null
	for level in topic["levels"]:
		var card := _level_card_button(
			level,
			func(l: Dictionary = level) -> void: _show_mode_dialog(l)
		)
		grid.add_child(card)
		if str(level.get("id", "")) == focus_level_id:
			focus_card = card
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	footer.add_child(_summary_item(icon_mode_polygon_done, "%d/%d" % [progress_store.mode_done_count(topic, "polygon"), topic["levels"].size()]))
	footer.add_child(_summary_item(icon_mode_puzzle_done, "%d/%d" % [progress_store.mode_done_count(topic, "knob"), topic["levels"].size()]))
	footer.add_child(_summary_text_item("3x4", "%d/%d" % [progress_store.mode_done_count(topic, "swap"), topic["levels"].size()]))
	footer.add_child(_summary_item(icon_cat_paw, "%d/%d" % [progress_store.topic_done_count(topic), topic["levels"].size() * 3]))
	wrap.add_child(footer)
	if focus_card != null:
		call_deferred("_scroll_level_card_into_view", scroll, focus_card)


func _level_card_button(level: Dictionary, action: Callable) -> Button:
	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(360, 260)
	_apply_card_style(card)
	var preview_texture := repository.level_thumbnail(level)
	if preview_texture == null:
		card.disabled = true
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18
	content.offset_top = 16
	content.offset_right = -18
	content.offset_bottom = -14
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	content.add_child(_preview_panel(preview_texture, Vector2(300, 142), "暂无关卡图片"))
	var title := Label.new()
	title.text = str(level["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", brown)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)
	row.add_child(_status_icon("polygon", progress_store.is_done(level["id"], "polygon"), 42))
	row.add_child(_status_icon("knob", progress_store.is_done(level["id"], "knob"), 42))
	row.add_child(_status_icon("swap", progress_store.is_done(level["id"], "swap"), 42))
	if preview_texture != null:
		card.pressed.connect(action)
		_wire_button_animation(card)
	return card


func _topic_card_button(topic: Dictionary, status_text: String, action: Callable) -> Button:
	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(360, 260)
	_apply_card_style(card)
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18
	content.offset_top = 16
	content.offset_right = -18
	content.offset_bottom = -14
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	content.add_child(_preview_panel(repository.topic_cover_texture(topic), Vector2(300, 142), "暂无主题封面"))
	var title := Label.new()
	title.text = "%s\n%s" % [str(topic["name"]), status_text]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", brown)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	card.pressed.connect(action)
	_wire_button_animation(card)
	return card


func _card_button(text: String, size: Vector2, action: Callable) -> Button:
	var card := Button.new()
	card.text = text
	card.custom_minimum_size = size
	card.icon = texture
	card.expand_icon = true
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.add_theme_font_size_override("font_size", 24)
	card.add_theme_color_override("font_color", brown)
	card.add_theme_color_override("font_hover_color", deep_orange)
	card.add_theme_color_override("font_pressed_color", brown)
	_apply_card_style(card)
	card.pressed.connect(action)
	_wire_button_animation(card)
	return card


func _preview_panel(preview_texture: Texture2D, min_size: Vector2, placeholder_text: String) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = min_size
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if preview_texture != null:
		var preview := TextureRect.new()
		preview.texture = preview_texture
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = min_size
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(preview)
		return holder
	var placeholder := PanelContainer.new()
	placeholder.custom_minimum_size = min_size
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.88, 0.86)
	style.border_color = Color(0.73, 0.50, 0.28, 0.35)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	placeholder.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = placeholder_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", muted)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.add_child(label)
	holder.add_child(placeholder)
	return holder


func _apply_card_style(card: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = paper
	normal.border_color = Color(0.73, 0.50, 0.28, 0.35)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_left = 22
	normal.corner_radius_bottom_right = 22
	normal.content_margin_left = 18
	normal.content_margin_top = 16
	normal.content_margin_right = 18
	normal.content_margin_bottom = 16
	card.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#FFF1DA")
	hover.border_color = orange
	card.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = soft_beige
	pressed.border_color = deep_orange
	card.add_theme_stylebox_override("pressed", pressed)


func _status_icon(mode: String, done: bool, size: float) -> Control:
	if _mode_key(mode) == "swap":
		return _swap_mode_badge(done, size)
	var rect := TextureRect.new()
	rect.texture = _mode_icon_texture(mode, done)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _swap_mode_badge(done: bool, size: float) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(size, size)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#6f9d67") if done else Color("#d0cac0")
	style.border_color = Color("#5f8d55") if done else Color("#aaa49a")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "3x4"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", max(12, int(size * 0.28)))
	label.add_theme_color_override("font_color", Color.WHITE if done else Color("#756e65"))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge


func _mode_icon_texture(mode: String, done: bool) -> Texture2D:
	var key := _mode_key(mode)
	if key == "polygon":
		return icon_mode_polygon_done if done else icon_mode_polygon_todo
	return icon_mode_puzzle_done if done else icon_mode_puzzle_todo


func _mode_label(mode: String) -> String:
	var key := _mode_key(mode)
	if key == "polygon":
		return "多边形模式"
	if key == "swap":
		return "方格交换模式"
	return "凹凸拼图模式"


func _summary_item(icon: Texture2D, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.texture = icon
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(30, 30)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(image)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", brown)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row


func _summary_text_item(mark: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_swap_mode_badge(true, 30))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", brown)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row


func _show_mode_dialog(level: Dictionary) -> void:
	current_level = level
	progress_store.mark_last_played(current_topic, level, progress_store.preferred_mode(level))
	_show_modal()
	var box := _mode_modal_box(Vector2(560, 690))
	box.add_child(_mode_dialog_image(level))
	box.add_child(_mode_title_block(str(level["title"])))
	box.add_child(_mode_choice_card(level, "polygon"))
	box.add_child(_mode_choice_card(level, "knob"))
	box.add_child(_mode_choice_card(level, "swap"))


func _mode_title_block(text: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(472, 70)
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", brown)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 2
	title.offset_bottom = 44
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(title)
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.73, 0.50, 0.28, 0.32)
	line.points = PackedVector2Array([Vector2(114, 58), Vector2(358, 58)])
	holder.add_child(line)
	var left_paw := _decor_paw(Vector2(96, 49), 22, -0.22)
	var right_paw := _decor_paw(Vector2(376, 49), 22, 0.22)
	holder.add_child(left_paw)
	holder.add_child(right_paw)
	return holder


func _decor_paw(position: Vector2, size: float, rotation_value: float) -> TextureRect:
	var paw := TextureRect.new()
	paw.texture = icon_cat_paw
	paw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paw.custom_minimum_size = Vector2(size, size)
	paw.position = position
	paw.rotation = rotation_value
	paw.modulate = Color(0.72, 0.44, 0.20, 0.48)
	paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return paw


func _mode_dialog_image(level: Dictionary) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = repository.level_thumbnail(level)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(472, 210)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _mode_choice_card(level: Dictionary, play_mode: String) -> Panel:
	var done := progress_store.is_done(level["id"], play_mode)
	var accent := _mode_accent_color(play_mode)
	var card := Panel.new()
	card.custom_minimum_size = Vector2(472, 104)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.985, 0.93, 0.96)
	style.border_color = Color(0.78, 0.52, 0.28, 0.28)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.42, 0.25, 0.08, 0.10)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22
	row.offset_top = 16
	row.offset_right = -22
	row.offset_bottom = -16
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(_status_icon(play_mode, done, 66))
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_box)
	var name := Label.new()
	name.text = _mode_label(play_mode)
	name.add_theme_font_size_override("font_size", 25)
	name.add_theme_color_override("font_color", brown)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(name)
	var status := Label.new()
	status.text = "已完成" if done else "未完成"
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color("#6f9d67") if done else orange)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(status)
	row.add_child(_mode_action_button("再玩一次" if done else "开始", play_mode, func() -> void:
		_close_modal()
		_show_game(current_topic, level, play_mode)
	))
	if done:
		card.add_child(_complete_check_badge())
	return card


func _mode_action_button(text: String, play_mode: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 50)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var accent := _mode_accent_color(play_mode)
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent if text == "再玩一次" else Color(1, 0.95, 0.84, 0.94)
	normal.border_color = accent
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_left = 20
	normal.corner_radius_bottom_right = 20
	normal.shadow_color = Color(0.42, 0.25, 0.08, 0.12)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", normal)
	if text != "再玩一次":
		button.add_theme_color_override("font_color", brown)
		button.add_theme_color_override("font_hover_color", brown)
		button.add_theme_color_override("font_pressed_color", brown)
	var hover := normal.duplicate()
	hover.bg_color = accent.lightened(0.08) if text == "再玩一次" else Color(1, 0.91, 0.76, 0.98)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.08)
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button


func _complete_check_badge() -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(42, 42)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -52
	badge.offset_top = -12
	badge.offset_right = -10
	badge.offset_bottom = 30
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#6f9d67")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	badge.add_theme_stylebox_override("panel", style)
	var check := Label.new()
	check.text = "✓"
	check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check.add_theme_font_size_override("font_size", 30)
	check.add_theme_color_override("font_color", Color.WHITE)
	check.set_anchors_preset(Control.PRESET_FULL_RECT)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(check)
	return badge


func _mode_accent_color(mode: String) -> Color:
	var key := _mode_key(mode)
	if key == "polygon":
		return Color("#6f9d67")
	if key == "swap":
		return Color("#7f9fb8")
	return orange


func _show_game(topic: Dictionary, level: Dictionary, play_mode: String) -> void:
	current_screen = "game"
	current_topic = topic
	current_level = level
	current_mode = _mode_key(play_mode)
	progress_store.mark_last_played(topic, level, current_mode)
	active_level_config = repository.load_level_config(current_level)
	_apply_level_media(active_level_config)
	_clear_ui()
	_clear_board()
	var random_rotation := progress_store.random_rotation_enabled() and current_mode != "swap"
	var loaded: bool = puzzle_board.start(active_level_config, play_mode, texture, source_image, source_size, _icon_button_size(), random_rotation)
	_build_game_hud(level["title"])
	if not loaded:
		status_label.text = "关卡 JSON 缺少当前模式配置。"
	elif not progress_store.tutorial_seen():
		_show_tutorial_modal()


func _set_game_status(text: String) -> void:
	if status_label != null and is_instance_valid(status_label):
		status_label.text = text


func _set_zoom_label(percent: int) -> void:
	if zoom_label != null and is_instance_valid(zoom_label):
		zoom_label.text = "%d%%" % percent


func _on_puzzle_completed() -> void:
	progress_store.mark_completed(current_level["id"], current_mode)
	_show_complete_modal()


func _build_game_hud(level_title: String) -> void:
	var viewport_size := get_viewport_rect().size
	var button_separation := _hud_button_separation()
	var title_size := _hud_title_size(level_title)
	var title_area_width := viewport_size.x - _hud_top_icons_width()
	var title_left := maxf(0.0, (title_area_width - title_size.x) * 0.5)
	var title := Label.new()
	title.text = level_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.custom_minimum_size = title_size
	title.offset_left = title_left
	title.offset_top = 0
	title.offset_right = title_left + title_size.x
	title.offset_bottom = title_size.y
	title.visible = _show_hud_debug_measurements() or viewport_size.x >= 640.0
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", brown)
	if _show_hud_debug_measurements():
		_apply_debug_control_background(title, Color(0.36, 0.86, 0.48, 0.22))
	screen_root.add_child(title)
	var top_actions := HBoxContainer.new()
	top_actions.alignment = BoxContainer.ALIGNMENT_END
	top_actions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_actions.offset_left = -_hud_top_icons_width()
	top_actions.offset_top = 0
	top_actions.offset_right = 0
	top_actions.offset_bottom = _icon_button_size()
	top_actions.add_theme_constant_override("separation", button_separation)
	screen_root.add_child(top_actions)
	top_actions.add_child(_icon_button(icon_pause, _show_pause_modal, "暂停"))
	top_actions.add_child(_icon_button(icon_setting, _show_settings_modal, "设置"))
	var bottom_tools := HBoxContainer.new()
	if current_mode != "swap":
		bottom_tools.alignment = BoxContainer.ALIGNMENT_BEGIN
		bottom_tools.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		bottom_tools.offset_left = 0
		bottom_tools.offset_top = -_icon_button_size()
		bottom_tools.offset_right = _hud_bottom_icons_width()
		bottom_tools.offset_bottom = 0
		bottom_tools.add_theme_constant_override("separation", button_separation)
		screen_root.add_child(bottom_tools)
		bottom_tools.add_child(_tool_text_button("整理", puzzle_board.organize_pieces, "整理碎片"))
		bottom_tools.add_child(_icon_button(icon_lightbulb, puzzle_board.show_hint, "提示"))
	zoom_label = null
	status_label = Label.new()
	if current_mode == "swap":
		status_label.text = "拖动图片块到另一块上交换位置。"
	elif progress_store.random_rotation_enabled():
		status_label.text = "拖动碎片。双击碎片旋转，空白处拖动桌布，双指缩放。"
	else:
		status_label.text = "拖动碎片。空白处拖动桌布，双指缩放。"
	status_label.position = Vector2(20, viewport_size.y - _game_bottom_reserved_height() + 10.0)
	status_label.add_theme_color_override("font_color", brown)
	screen_root.add_child(status_label)
	hud_blocker_controls.clear()
	hud_blocker_controls.append(title)
	for control in top_actions.get_children():
		if control is Control:
			hud_blocker_controls.append(control)
	for control in bottom_tools.get_children():
		if control is Control:
			hud_blocker_controls.append(control)
	_queue_game_drag_blocker_refresh()
	_animate_screen_in(screen_root)


func _hud_top_icons_width() -> float:
	return _icon_button_size() * 2.0 + _hud_button_separation()


func _hud_bottom_icons_width() -> float:
	return _icon_button_size() + _hud_text_button_width("整理") + _hud_button_separation()


func _hud_title_size(text: String) -> Vector2:
	return Vector2(maxf(48.0, float(text.length()) * 24.0 * 0.9), _icon_button_size())


func _hud_button_separation() -> float:
	return 3.0 if get_viewport_rect().size.x < 430.0 else 4.0


func _icon_button_size() -> float:
	var size := _texture_size(icon_pause)
	return maxf(size.x, size.y)


func _texture_size(icon: Texture2D) -> Vector2:
	if icon == null:
		return Vector2(48, 48)
	var size := icon.get_size()
	return Vector2(maxf(1.0, size.x), maxf(1.0, size.y))


func _hud_text_button_width(text: String) -> float:
	return maxf(20.0, float(text.length()) * HUD_TEXT_BUTTON_FONT_SIZE * 0.9)


func _hud_text_button_height() -> float:
	return float(HUD_TEXT_BUTTON_FONT_SIZE) + 8.0


func _mode_key(play_mode: String) -> String:
	return "knob" if play_mode == "classic" else play_mode


func _game_bottom_reserved_height() -> float:
	return BoardLayoutScript.game_bottom_reserved_height(_icon_button_size())


func _queue_game_drag_blocker_refresh() -> void:
	call_deferred("_refresh_game_drag_blockers")


func _refresh_game_drag_blockers() -> void:
	if current_screen != "game" or puzzle_board == null:
		return
	var blockers: Array[Rect2] = []
	for control in hud_blocker_controls:
		if not is_instance_valid(control) or not control.visible:
			continue
		var rect := Rect2(control.global_position, control.size).grow(HUD_BLOCKER_PADDING)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			blockers.append(rect)
	puzzle_board.set_drag_blockers(blockers)


func _apply_level_media(level_config: Dictionary) -> void:
	var media := repository.apply_level_media(level_config, current_mode)
	texture = media["texture"]
	source_image = media["image"]
	source_size = media["source_size"]


func _show_pause_modal() -> void:
	_show_modal()
	var box := _modal_box(Vector2(360, 360))
	box.add_child(_modal_title("已暂停"))
	box.add_child(_button("继续游戏", _close_modal))
	box.add_child(_button("重新开始", _show_restart_confirm, false))
	box.add_child(_button("返回关卡列表", func() -> void:
		_close_modal()
		_show_levels(current_topic, str(current_level.get("id", "")))
	, false))
	box.add_child(_button("返回主题选择", func() -> void:
		_close_modal()
		_show_topics()
	, false))


func _show_restart_confirm() -> void:
	_show_modal()
	var box := _modal_box(Vector2(360, 230))
	box.add_child(_modal_title("确认重新开始？"))
	box.add_child(_button("确认", func() -> void:
		_close_modal()
		_show_game(current_topic, current_level, current_mode)
	))
	box.add_child(_button("返回", _show_pause_modal, false))


func _show_settings_modal() -> void:
	_show_modal()
	var box := _modal_box(Vector2(420, 390))
	box.add_child(_modal_title("设置"))
	for name in ["音乐", "音效", "震动反馈"]:
		var check := CheckBox.new()
		check.text = name
		check.button_pressed = true
		check.add_theme_color_override("font_color", brown)
		box.add_child(check)
	var rotation_check := CheckBox.new()
	rotation_check.text = "碎片随机旋转（多边形 / 凹凸）"
	rotation_check.button_pressed = progress_store.random_rotation_enabled()
	rotation_check.add_theme_color_override("font_color", brown)
	rotation_check.toggled.connect(func(enabled: bool) -> void:
		progress_store.set_random_rotation_enabled(enabled)
		if current_screen == "game":
			_set_game_status("随机旋转设置将在重新开始或进入下一关后生效。")
	)
	box.add_child(rotation_check)
	box.add_child(_button("关闭", _close_modal))


func _show_tutorial_modal() -> void:
	_show_modal()
	var box := _modal_box(Vector2(420, 290))
	box.add_child(_modal_title("怎么玩"))
	var text := Label.new()
	if current_mode == "swap":
		text.text = "拖动一块图片到另一块上，可以交换它们的位置。\n\n空白处拖动可以移动桌布，双指可以缩放。\n\n所有方格回到正确顺序后就会通关。"
	elif progress_store.random_rotation_enabled():
		text.text = "单指按住碎片并拖动。\n\n双击碎片可以旋转 90 度。\n\n空白处拖动可以移动桌布，双指可以缩放。\n\n碎片太乱时，点击左下角“整理”。"
	else:
		text.text = "单指按住碎片并拖动。\n\n空白处拖动可以移动桌布，双指可以缩放。\n\n碎片太乱时，点击左下角“整理”。"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 20)
	text.add_theme_color_override("font_color", brown)
	box.add_child(text)
	box.add_child(_button("知道了", func() -> void:
		progress_store.mark_tutorial_seen()
		_close_modal()
	))


func _show_complete_modal() -> void:
	_show_modal()
	var box := _complete_modal_box(Vector2(560, 640))
	box.add_theme_constant_override("separation", 16)
	box.add_child(_complete_ribbon("恭喜完成！"))
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size.y = 16
	box.add_child(top_spacer)
	box.add_child(_image_rect(Vector2(460, 260)))
	box.add_child(_modal_title(current_level["title"]))
	var desc := Label.new()
	desc.text = current_level["description"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", brown)
	box.add_child(desc)
	box.add_child(_complete_actions())


func _complete_ribbon(text: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(500, 86)
	holder.clip_contents = false
	var ribbon := TextureRect.new()
	ribbon.texture = complete_ribbon_texture
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ribbon.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ribbon.offset_left = -260
	ribbon.offset_top = -86
	ribbon.offset_right = 260
	ribbon.offset_bottom = 92
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ribbon)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.48, 0.24, 0.06, 0.46))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -190
	label.offset_top = -40
	label.offset_right = 190
	label.offset_bottom = 42
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	return holder


func _complete_actions() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.add_child(_button("下一个", _play_next_level, true, Vector2(138, 48)))
	row.add_child(_button("换个模式", func() -> void:
		_close_modal()
		_show_game(current_topic, current_level, _next_mode_key(current_mode))
	, false, Vector2(138, 48)))
	row.add_child(_button("返回关卡列表", func() -> void:
		_close_modal()
		_show_levels(current_topic, str(current_level.get("id", "")))
	, false, Vector2(154, 48)))
	return row


func _next_mode_key(mode: String) -> String:
	var modes := ["polygon", "knob", "swap"]
	var key := _mode_key(mode)
	var index := modes.find(key)
	if index < 0:
		return "polygon"
	return modes[(index + 1) % modes.size()]


func _add_complete_paw_marks(panel: Control) -> void:
	var marks := [
		{ "pos": Vector2(34, 110), "size": 34.0, "rot": -0.25, "alpha": 0.16 },
		{ "pos": Vector2(492, 112), "size": 30.0, "rot": 0.22, "alpha": 0.14 },
		{ "pos": Vector2(62, 480), "size": 28.0, "rot": 0.18, "alpha": 0.12 },
		{ "pos": Vector2(462, 448), "size": 36.0, "rot": -0.16, "alpha": 0.12 },
	]
	for item in marks:
		var paw := TextureRect.new()
		paw.texture = icon_cat_paw
		paw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		paw.custom_minimum_size = Vector2(item["size"], item["size"])
		paw.position = item["pos"]
		paw.rotation = item["rot"]
		paw.modulate = Color(0.82, 0.50, 0.22, item["alpha"])
		paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(paw)


func _play_next_level() -> void:
	var levels: Array = current_topic["levels"]
	var idx := levels.find(current_level)
	var next_level: Dictionary = levels[(idx + 1) % levels.size()]
	_close_modal()
	_show_game(current_topic, next_level, current_mode)


func _show_album() -> void:
	current_screen = "album"
	var wrap := _base_screen()
	_header(wrap, "相册", _show_topics)
	var hint := Label.new()
	hint.text = "相册只收录已完成的拼图，继续完成关卡可解锁更多收藏。"
	hint.add_theme_color_override("font_color", brown)
	wrap.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = _wide_grid_columns(3, 2)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for topic in topics:
		for level in topic["levels"]:
			var modes := progress_store.completed_modes(level["id"])
			if modes.is_empty():
				continue
			var card := _card_button(
				"%s\n%s" % [level["title"], " / ".join(modes)],
				Vector2(260, 170),
				func(t: Dictionary = topic, l: Dictionary = level, m: Array = modes) -> void: _show_album_detail(t, l, m)
			)
			grid.add_child(card)


func _wide_grid_columns(wide_columns: int, narrow_columns: int) -> int:
	return narrow_columns if get_viewport_rect().size.x < 900.0 else wide_columns


func _show_album_detail(topic: Dictionary, level: Dictionary, modes: Array) -> void:
	var wrap := _base_screen()
	_header(wrap, level["title"], _show_album)
	wrap.add_child(_image_rect(Vector2(560, 420)))
	var desc := Label.new()
	desc.text = "%s\n已完成模式：%s" % [level["description"], " / ".join(modes)]
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", brown)
	wrap.add_child(desc)


func _scroll_level_card_into_view(scroll: ScrollContainer, card: Control) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(card):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(scroll) or not is_instance_valid(card):
		return
	var target := card.global_position.y - scroll.global_position.y + float(scroll.scroll_vertical) - 24.0
	scroll.scroll_vertical = max(0, int(target))


func _show_modal() -> void:
	for child in modal_root.get_children():
		child.queue_free()
	modal_open = true
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.42)
	shade.modulate.a = 0.0
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(shade)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(shade, "modulate:a", 1.0, 0.14)


func _modal_box(size: Vector2, bg_color := Color("#FFF6E6")) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", style)
	modal_root.add_child(panel)
	_animate_modal_panel(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func _mode_modal_box(size: Vector2) -> VBoxContainer:
	var panel := Panel.new()
	panel.custom_minimum_size = size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = paper
	style.border_color = Color(0.78, 0.52, 0.28, 0.55)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	panel.add_theme_stylebox_override("panel", style)
	modal_root.add_child(panel)
	_animate_modal_panel(panel)
	var close := _mode_close_button()
	panel.add_child(close)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 44
	box.offset_top = 64
	box.offset_right = -44
	box.offset_bottom = -36
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box


func _mode_close_button() -> Button:
	var button := Button.new()
	button.text = "×"
	button.custom_minimum_size = Vector2(52, 52)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -72
	button.offset_top = 20
	button.offset_right = -20
	button.offset_bottom = 72
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", brown)
	button.add_theme_color_override("font_hover_color", deep_orange)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 0.96, 0.88, 0.92)
	normal.border_color = Color(0.78, 0.52, 0.28, 0.35)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 26
	normal.corner_radius_top_right = 26
	normal.corner_radius_bottom_left = 26
	normal.corner_radius_bottom_right = 26
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = paper
	hover.border_color = orange
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(_close_modal)
	_wire_button_animation(button)
	return button


func _complete_modal_box(size: Vector2) -> VBoxContainer:
	var panel := Panel.new()
	panel.custom_minimum_size = size
	panel.clip_contents = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = cream
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", style)
	modal_root.add_child(panel)
	_animate_modal_panel(panel)
	_add_complete_paw_marks(panel)
	var box := VBoxContainer.new()
	box.clip_contents = false
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 32
	box.offset_top = 0
	box.offset_right = -32
	box.offset_bottom = -28
	panel.add_child(box)
	return box


func _modal_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", brown)
	return label


func _close_modal() -> void:
	for child in modal_root.get_children():
		child.queue_free()
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_open = false
