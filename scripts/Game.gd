extends Node2D

const DEFAULT_LEVEL_IMAGE_PATH := "res://levels/cat/cat_moon_01/source.png"
const MENU_BACKGROUND_PATH := "res://assets/source/menu_background.png"
const TITLE_IMAGE_PATH := "res://assets/ui/title.png"
const START_BUTTON_IMAGE_PATH := "res://assets/ui/start-game.png"
const CHOOSE_LEVEL_PANEL_PATH := "res://assets/ui/choose-level.png"
const COMPLETE_RIBBON_PATH := "res://assets/ui/complete_ribbon.png"
const ICON_ALBUM_PATH := "res://assets/icons/album.svg"
const ICON_LEFT_ARROW_PATH := "res://assets/icons/left-arrow.svg"
const ICON_LIGHTBULB_PATH := "res://assets/icons/lightbulb.svg"
const ICON_PAUSE_PATH := "res://assets/icons/pause.svg"
const ICON_ROTATE_PATH := "res://assets/icons/rotate.svg"
const ICON_SETTING_PATH := "res://assets/icons/setting.svg"
const ICON_CAT_PAW_PATH := "res://assets/icons/status/cat_paw.png"
const ICON_MODE_PUZZLE_DONE_PATH := "res://assets/icons/status/mode_puzzle_done.png"
const ICON_MODE_PUZZLE_TODO_PATH := "res://assets/icons/status/mode_puzzle_todo.png"
const ICON_MODE_POLYGON_DONE_PATH := "res://assets/icons/status/mode_polygon_done.png"
const ICON_MODE_POLYGON_TODO_PATH := "res://assets/icons/status/mode_polygon_todo.png"
const LEVEL_CATALOG_PATH := "res://levels/catalog.json"
const LEVEL_CONFIG_PATH := "res://levels/cat/cat_moon_01/level.json"
const SNAP_TOLERANCE := 22.0
const ROTATION_TOLERANCE := 3.0
const HIT_ALPHA_RADIUS := 2
const SAVE_PATH := "user://jigcat_progress.json"
const DEFAULT_BOARD_MARGIN_RATIO := 1.0
const DEFAULT_HUD_HEIGHT_RATIO := 0.0
const DEFAULT_SIDE_MARGIN_RATIO := 0.0
const DEFAULT_BOTTOM_MARGIN_RATIO := 0.0
const GAME_EDGE_MARGIN := 20.0
const GAME_HEADER_MARGIN := 20.0
const MIN_ICON_BUTTON_SIZE := 48.0
const MAX_ICON_BUTTON_SIZE := 64.0
const MIN_ICON_ART_SIZE := 28.0
const MAX_ICON_ART_SIZE := 36.0
const PIECE_DRAG_PADDING := 8.0
const PieceGroupScript := preload("res://scripts/PieceGroup.gd")
const SnapSolverScript := preload("res://scripts/SnapSolver.gd")

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
var texture_cache: Dictionary = {}
var source_image_cache: Dictionary = {}
var menu_background: Texture2D
var title_texture: Texture2D
var start_button_texture: Texture2D
var choose_level_panel_texture: Texture2D
var complete_ribbon_texture: Texture2D
var icon_album: Texture2D
var icon_left_arrow: Texture2D
var icon_lightbulb: Texture2D
var icon_pause: Texture2D
var icon_rotate: Texture2D
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
var config_cache: Dictionary = {}
var rng := RandomNumberGenerator.new()
var board_layer: Node2D
var ui_layer: CanvasLayer
var screen_root: Control
var modal_root: Control
var preview_sprite: Sprite2D

var topics: Array[Dictionary] = []
var progress := {}
var current_topic: Dictionary = {}
var current_level: Dictionary = {}
var current_mode := "knob"
var current_screen := "home"
var modal_open := false

var groups: Array = []
var spawn_bounds: Array[Rect2] = []
var dragging = null
var selected_group = null
var hint_highlighted_groups: Array = []
var hint_highlighted_lines: Array[Line2D] = []
var active_touch_index := -1
var drag_offset := Vector2.ZERO
var status_label: Label


func _ready() -> void:
	_lock_portrait_orientation()
	rng.seed = 7
	texture = _cached_texture(DEFAULT_LEVEL_IMAGE_PATH)
	menu_background = load(MENU_BACKGROUND_PATH)
	title_texture = load(TITLE_IMAGE_PATH)
	start_button_texture = load(START_BUTTON_IMAGE_PATH)
	choose_level_panel_texture = load(CHOOSE_LEVEL_PANEL_PATH)
	complete_ribbon_texture = _cached_texture(COMPLETE_RIBBON_PATH)
	icon_album = load(ICON_ALBUM_PATH)
	icon_left_arrow = load(ICON_LEFT_ARROW_PATH)
	icon_lightbulb = load(ICON_LIGHTBULB_PATH)
	icon_pause = load(ICON_PAUSE_PATH)
	icon_rotate = load(ICON_ROTATE_PATH)
	icon_setting = load(ICON_SETTING_PATH)
	icon_cat_paw = _cached_texture(ICON_CAT_PAW_PATH)
	icon_mode_puzzle_done = _cached_texture(ICON_MODE_PUZZLE_DONE_PATH)
	icon_mode_puzzle_todo = _cached_texture(ICON_MODE_PUZZLE_TODO_PATH)
	icon_mode_polygon_done = _cached_texture(ICON_MODE_POLYGON_DONE_PATH)
	icon_mode_polygon_todo = _cached_texture(ICON_MODE_POLYGON_TODO_PATH)
	source_image = texture.get_image()
	source_size = texture.get_size()
	board_layer = Node2D.new()
	add_child(board_layer)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_build_catalog()
	_load_progress()
	_show_last_topic_levels()


func _lock_portrait_orientation() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _unhandled_input(event: InputEvent) -> void:
	if current_screen != "game" or modal_open:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			var double_group = _group_at(mouse_event.position)
			if double_group != null:
				_select_group(double_group)
				_rotate_group(double_group)
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_drag(mouse_event.position)
			else:
				_end_drag()
	elif event is InputEventMouseMotion and dragging != null:
		var motion := event as InputEventMouseMotion
		_move_group_to(dragging, motion.position + drag_offset)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.double_tap:
				var double_group = _group_at(touch.position)
				if double_group != null:
					_select_group(double_group)
					_rotate_group(double_group)
			else:
				active_touch_index = touch.index
				_begin_drag(touch.position)
		elif touch.index == active_touch_index:
			_end_drag()
			active_touch_index = -1
	elif event is InputEventScreenDrag and dragging != null:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == active_touch_index:
			_move_group_to(dragging, drag_event.position + drag_offset)


func _build_catalog() -> void:
	var catalog := _load_config_path(LEVEL_CATALOG_PATH)
	if catalog.has("topics") and typeof(catalog["topics"]) == TYPE_ARRAY:
		var next_topics: Array[Dictionary] = []
		var catalog_topics: Array = catalog["topics"]
		catalog_topics.sort_custom(func(a, b) -> bool:
			return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
		)
		for topic_data in catalog_topics:
			if typeof(topic_data) != TYPE_DICTIONARY:
				continue
			var topic: Dictionary = topic_data
			var levels: Array[Dictionary] = []
			var catalog_levels: Array = topic.get("levels", [])
			catalog_levels.sort_custom(func(a, b) -> bool:
				return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
			)
			for level_data in catalog_levels:
				if typeof(level_data) != TYPE_DICTIONARY:
					continue
				var level_entry: Dictionary = level_data
				var config_path := str(level_entry.get("path", ""))
				var level_config := _load_config_path(config_path)
				levels.append({
					"id": str(level_entry.get("id", level_config.get("id", ""))),
					"title": _config_string(level_config, "title", str(level_entry.get("title", ""))),
					"description": _config_string(level_config, "description", ""),
					"config_path": config_path,
				})
			next_topics.append({
				"id": str(topic.get("id", "")),
				"name": str(topic.get("name", topic.get("id", ""))),
				"levels": levels,
			})
		if not next_topics.is_empty():
			topics = next_topics
			return
	var cat_config := _load_config_path(LEVEL_CONFIG_PATH)
	var level_title := _config_string(cat_config, "title", "月亮小睡")
	var level_description := _config_string(cat_config, "description", "小猫安静地靠在月亮上，像一段柔软的午后梦。")
	topics = [{
		"id": "cat",
		"name": "猫",
		"levels": [{
			"id": "cat_moon_01",
			"title": level_title,
			"description": level_description,
			"config_path": LEVEL_CONFIG_PATH,
		}]
	}]


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		progress = {}
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	progress = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(progress))


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
	for child in board_layer.get_children():
		child.queue_free()
	groups.clear()
	spawn_bounds.clear()
	dragging = null
	selected_group = null
	hint_highlighted_groups.clear()
	hint_highlighted_lines.clear()
	preview_sprite = null


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
	var icon_size := _icon_button_size()
	var art_size := _icon_art_size()
	button.custom_minimum_size = Vector2(icon_size, icon_size)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var empty := StyleBoxEmpty.new()
		button.add_theme_stylebox_override(state, empty)
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(art_size, art_size)
	icon_rect.set_anchors_preset(Control.PRESET_CENTER)
	icon_rect.offset_left = -art_size * 0.5
	icon_rect.offset_top = -art_size * 0.5
	icon_rect.offset_right = art_size * 0.5
	icon_rect.offset_bottom = art_size * 0.5
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
	var has_record := not _last_completed_level().is_empty()
	var play_text := "继续游戏" if has_record else "开始游戏"
	buttons.add_child(_home_image_button(play_text, _start_from_home, start_button_texture, Color.WHITE))
	buttons.add_child(_home_image_button("选择关卡", _show_topics, choose_level_panel_texture, brown))


func _start_from_home() -> void:
	var target := _resume_target()
	if target.is_empty() or target["level"].is_empty():
		_show_topics()
		return
	_show_game(target["topic"], target["level"], target["mode"])


func _show_last_topic_levels() -> void:
	var topic := _last_topic_or_first()
	if topic.is_empty():
		_show_topics()
		return
	_show_levels(topic, _focus_level_id(topic))


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
		var total: int = topic["levels"].size() * 2
		var done: int = _topic_done_count(topic)
		var card := _card_button(
			"%s\n%d/%d" % [topic["name"], done, total],
			Vector2(360, 260),
			func(t: Dictionary = topic) -> void: _show_levels(t, _focus_level_id(t))
		)
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
	footer.add_child(_summary_item(icon_mode_polygon_done, "%d/%d" % [_mode_done_count(topic, "polygon"), topic["levels"].size()]))
	footer.add_child(_summary_item(icon_mode_puzzle_done, "%d/%d" % [_mode_done_count(topic, "knob"), topic["levels"].size()]))
	footer.add_child(_summary_item(icon_cat_paw, "%d/%d" % [_topic_done_count(topic), topic["levels"].size() * 2]))
	wrap.add_child(footer)
	if focus_card != null:
		call_deferred("_scroll_level_card_into_view", scroll, focus_card)


func _level_card_button(level: Dictionary, action: Callable) -> Button:
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
	var preview := TextureRect.new()
	preview.texture = _level_thumbnail(level)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(300, 142)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview)
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
	row.add_child(_status_icon("polygon", _is_done(level["id"], "polygon"), 42))
	row.add_child(_status_icon("knob", _is_done(level["id"], "knob"), 42))
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


func _level_thumbnail(level: Dictionary) -> Texture2D:
	var level_config := _load_level_config(level)
	var image_path := _level_image_path(level_config)
	var thumbnail := _cached_texture(image_path)
	return thumbnail if thumbnail != null else texture


func _status_icon(mode: String, done: bool, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _mode_icon_texture(mode, done)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _mode_icon_texture(mode: String, done: bool) -> Texture2D:
	var key := _mode_key(mode)
	if key == "polygon":
		return icon_mode_polygon_done if done else icon_mode_polygon_todo
	return icon_mode_puzzle_done if done else icon_mode_puzzle_todo


func _mode_label(mode: String) -> String:
	return "多边形模式" if _mode_key(mode) == "polygon" else "凹凸拼图模式"


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


func _show_mode_dialog(level: Dictionary) -> void:
	current_level = level
	_mark_last_played(current_topic, level, _preferred_mode(level))
	_show_modal()
	var box := _mode_modal_box(Vector2(560, 690))
	box.add_child(_mode_dialog_image(level))
	box.add_child(_mode_title_block(str(level["title"])))
	box.add_child(_mode_choice_card(level, "polygon"))
	box.add_child(_mode_choice_card(level, "knob"))


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
	rect.texture = _level_thumbnail(level)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(472, 210)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _mode_choice_card(level: Dictionary, play_mode: String) -> Panel:
	var done := _is_done(level["id"], play_mode)
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
	return Color("#6f9d67") if _mode_key(mode) == "polygon" else orange


func _show_game(topic: Dictionary, level: Dictionary, play_mode: String) -> void:
	current_screen = "game"
	current_topic = topic
	current_level = level
	current_mode = _mode_key(play_mode)
	_mark_last_played(topic, level, current_mode)
	active_level_config = _load_level_config(current_level)
	_apply_level_media(active_level_config)
	_clear_ui()
	_clear_board()
	_add_level_background(active_level_config)
	var loaded := _start_play_session(play_mode)
	_build_game_hud(level["title"])
	if not loaded:
		status_label.text = "关卡 JSON 缺少当前模式的预生成碎片。"
	elif not _tutorial_seen():
		_show_tutorial_modal()


func _build_game_hud(level_title: String) -> void:
	var viewport_size := get_viewport_rect().size
	var button_separation := _hud_button_separation()
	var row_width := minf(_hud_icons_width(), viewport_size.x - 24.0)
	var title := Label.new()
	title.text = level_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.offset_left = 20
	title.offset_top = 18
	title.offset_right = maxf(220.0, viewport_size.x - row_width - 38.0)
	title.offset_bottom = 56
	title.visible = viewport_size.x >= 560.0
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", brown)
	screen_root.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -row_width
	row.offset_top = 4
	row.offset_right = -8
	row.offset_bottom = 4 + _icon_button_size() + 8
	row.add_theme_constant_override("separation", button_separation)
	screen_root.add_child(row)
	row.add_child(_icon_button(icon_rotate, _align_all, "转正"))
	row.add_child(_icon_button(icon_lightbulb, _show_hint, "提示"))
	row.add_child(_icon_button(icon_album, _toggle_preview, "预览图"))
	row.add_child(_icon_button(icon_pause, _show_pause_modal, "暂停"))
	row.add_child(_icon_button(icon_setting, _show_settings_modal, "设置"))
	status_label = Label.new()
	status_label.text = "拖动碎片。双击碎片旋转。"
	status_label.position = Vector2(20, viewport_size.y - 42.0)
	status_label.add_theme_color_override("font_color", brown)
	screen_root.add_child(status_label)
	_animate_screen_in(screen_root)


func _hud_icons_width() -> float:
	return _icon_button_size() * 5.0 + _hud_button_separation() * 4.0


func _hud_button_separation() -> float:
	return 6.0 if get_viewport_rect().size.x < 430.0 else 8.0


func _icon_button_size() -> float:
	var viewport_width := get_viewport_rect().size.x
	var available_width := maxf(240.0, viewport_width - 32.0)
	var separation := 6.0 if viewport_width < 430.0 else 8.0
	var fitting_size := floorf((available_width - separation * 4.0) / 5.0)
	return clampf(fitting_size, MIN_ICON_BUTTON_SIZE, MAX_ICON_BUTTON_SIZE)


func _icon_art_size() -> float:
	return clampf(_icon_button_size() * 0.56, MIN_ICON_ART_SIZE, MAX_ICON_ART_SIZE)


func _start_play_session(play_mode: String) -> bool:
	var mode_key := _mode_key(play_mode)
	var level := _level_from_mode_pieces(mode_key)
	if level.is_empty():
		return false
	source_scale = level["source_scale"]
	board_origin = level["board_origin"]
	spawn_bounds.clear()
	var sorted_pieces: Array = level["pieces"].duplicate()
	sorted_pieces.sort_custom(func(a, b) -> bool:
		return _points_bounds_area(a["bounds_points"]) > _points_bounds_area(b["bounds_points"])
	)
	for piece in sorted_pieces:
		_create_group(piece)
	_add_preview_sprite(level["play_area"])
	return true


func _add_preview_sprite(play_area: Rect2) -> void:
	preview_sprite = Sprite2D.new()
	preview_sprite.texture = texture
	var preview_max := Vector2(play_area.size.x * 0.24, play_area.size.y * 0.24)
	var preview_scale := minf(preview_max.x / source_size.x, preview_max.y / source_size.y)
	preview_sprite.scale = Vector2.ONE * preview_scale
	preview_sprite.position = play_area.end - source_size * preview_scale * 0.5 - Vector2(16, 16)
	preview_sprite.modulate = Color(1, 1, 1, 0.82)
	preview_sprite.visible = false
	board_layer.add_child(preview_sprite)


func _load_level_config(level: Dictionary) -> Dictionary:
	var config_path: String = level.get("config_path", "")
	return _load_config_path(config_path)


func _load_config_path(config_path: String) -> Dictionary:
	if config_path.is_empty() or not FileAccess.file_exists(config_path):
		return {}
	if config_cache.has(config_path):
		return config_cache[config_path]
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	var config: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if not config.is_empty():
		config_cache[config_path] = config
	return config


func _mode_key(play_mode: String) -> String:
	return "knob" if play_mode == "classic" else play_mode


func _mode_config(level_config: Dictionary, play_mode: String) -> Dictionary:
	var mode := _mode_key(play_mode)
	if not level_config.has("modes") or typeof(level_config["modes"]) != TYPE_DICTIONARY:
		return {}
	var modes: Dictionary = level_config["modes"]
	if not modes.has(mode) or typeof(modes[mode]) != TYPE_DICTIONARY:
		return {}
	return modes[mode]


func _level_from_mode_pieces(play_mode: String) -> Dictionary:
	var config := _mode_config(active_level_config, play_mode)
	if config.is_empty() or not config.has("pieces") or typeof(config["pieces"]) != TYPE_ARRAY:
		return {}
	if str(config.get("source", "")) != "precomputed":
		return {}
	var source_pieces: Array = config["pieces"]
	if source_pieces.is_empty():
		return {}
	var layout := _mobile_board_layout()
	var mode_source_scale: float = layout["source_scale"]
	var mode_board_origin: Vector2 = layout["board_origin"]
	var board_size: Vector2 = layout["board_size"]
	var pieces: Array[Dictionary] = []
	for source_piece in source_pieces:
		if typeof(source_piece) != TYPE_DICTIONARY:
			continue
		var piece_data: Dictionary = source_piece
		var source_polygon := _json_points(piece_data.get("points", []))
		if source_polygon.size() < 3:
			continue
		var home_source := _json_point(piece_data.get("home", _polygon_center(source_polygon)))
		var home := mode_board_origin + home_source * mode_source_scale
		var local_polygon := PackedVector2Array()
		var uvs := PackedVector2Array()
		for source_point in source_polygon:
			var display_point := mode_board_origin + source_point * mode_source_scale
			local_polygon.append(display_point - home)
			uvs.append(source_point)
		var visible_source_rect := _json_rect(
			piece_data.get("visible_bounds", []),
			Rect2()
		)
		if visible_source_rect.size.x <= 0.0 or visible_source_rect.size.y <= 0.0:
			visible_source_rect = _visible_source_rect_for_polygon(source_polygon, _source_rect_for_points(source_polygon))
		var visible_source_rects := _json_rects(piece_data.get("visible_bounds_list", []))
		if visible_source_rects.is_empty():
			visible_source_rects = [visible_source_rect]
		var bounds_points_list: Array[PackedVector2Array] = []
		for source_rect in visible_source_rects:
			bounds_points_list.append(_local_rect_points(source_rect, home, mode_source_scale, mode_board_origin))
		var cut_lines: Array[PackedVector2Array] = []
		if piece_data.has("cut_lines") and typeof(piece_data["cut_lines"]) == TYPE_ARRAY:
			for line_data in piece_data["cut_lines"]:
				var source_line := _json_points(line_data)
				if source_line.size() < 2:
					continue
				for local_line in _visible_cut_line_segments(source_line, home, mode_source_scale, mode_board_origin):
					cut_lines.append(local_line)
		pieces.append({
			"id": str(piece_data.get("id", "piece_%d" % pieces.size())),
			"cell": _json_cell(piece_data.get("cell", [0, 0])),
			"home": home,
			"polygon": local_polygon,
			"uv": uvs,
			"neighbors": piece_data.get("neighbors", []),
			"source_rect": _source_rect_for_points(source_polygon),
			"bounds_points": _local_rect_points(visible_source_rect, home, mode_source_scale, mode_board_origin),
			"bounds_points_list": bounds_points_list,
			"cut_lines": cut_lines,
		})
	return {
		"pieces": pieces,
		"board_origin": mode_board_origin,
		"board_size": board_size,
		"source_scale": mode_source_scale,
		"play_area": layout["play_area"],
	}


func _mobile_board_layout() -> Dictionary:
	var layout_config := _runtime_layout_config()
	var viewport_size := get_viewport_rect().size
	var hud_height := _icon_button_size() + GAME_HEADER_MARGIN
	var side_margin := GAME_EDGE_MARGIN
	var bottom_margin := GAME_EDGE_MARGIN
	var play_area := Rect2(
		Vector2(side_margin, hud_height),
		Vector2(
			maxf(240.0, viewport_size.x - side_margin * 2.0),
			maxf(220.0, viewport_size.y - hud_height - bottom_margin)
		)
	)
	var scale := minf(play_area.size.x / source_size.x, play_area.size.y / source_size.y) * float(layout_config["board_margin_ratio"])
	var board_size := source_size * scale
	var origin := play_area.position + (play_area.size - board_size) * 0.5
	return {
		"source_scale": scale,
		"board_origin": origin,
		"board_size": board_size,
		"play_area": play_area,
	}


func _runtime_layout_config() -> Dictionary:
	var config := {
		"board_margin_ratio": DEFAULT_BOARD_MARGIN_RATIO,
		"hud_height_ratio": DEFAULT_HUD_HEIGHT_RATIO,
		"side_margin_ratio": DEFAULT_SIDE_MARGIN_RATIO,
		"bottom_margin_ratio": DEFAULT_BOTTOM_MARGIN_RATIO,
	}
	if active_level_config.has("runtime_layout") and typeof(active_level_config["runtime_layout"]) == TYPE_DICTIONARY:
		var source_config: Dictionary = active_level_config["runtime_layout"]
		config["board_margin_ratio"] = clampf(float(source_config.get("board_margin_ratio", config["board_margin_ratio"])), 0.98, 1.0)
		config["hud_height_ratio"] = clampf(float(source_config.get("hud_height_ratio", config["hud_height_ratio"])), 0.0, 0.18)
		config["side_margin_ratio"] = clampf(float(source_config.get("side_margin_ratio", config["side_margin_ratio"])), 0.0, 0.10)
		config["bottom_margin_ratio"] = clampf(float(source_config.get("bottom_margin_ratio", config["bottom_margin_ratio"])), 0.0, 0.12)
	return config


func _json_points(value) -> PackedVector2Array:
	var points := PackedVector2Array()
	if typeof(value) != TYPE_ARRAY:
		return points
	for item in value:
		points.append(_json_point(item))
	return points


func _json_point(value) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO


func _json_cell(value) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _json_rect(value, fallback: Rect2) -> Rect2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 4:
		return Rect2(
			Vector2(float(value[0]), float(value[1])),
			Vector2(maxf(1.0, float(value[2])), maxf(1.0, float(value[3])))
		)
	return fallback


func _json_rects(value) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if typeof(value) != TYPE_ARRAY:
		return rects
	for item in value:
		var rect := _json_rect(item, Rect2())
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			rects.append(rect)
	return rects


func _local_rect_points(source_rect: Rect2, home: Vector2, scale: float, origin: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [
		source_rect.position,
		Vector2(source_rect.end.x, source_rect.position.y),
		source_rect.end,
		Vector2(source_rect.position.x, source_rect.end.y),
	]
	for source_point in corners:
		points.append(origin + source_point * scale - home)
	return points


func _polygon_center(points: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in points:
		center += point
	return center / float(max(points.size(), 1))


func _source_rect_for_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


func _points_bounds_area(points: PackedVector2Array) -> float:
	var bounds := _source_rect_for_points(points)
	return bounds.size.x * bounds.size.y


func _visible_source_rect_for_polygon(points: PackedVector2Array, fallback: Rect2) -> Rect2:
	if points.is_empty() or source_image == null:
		return fallback
	var image_size: Vector2i = source_image.get_size()
	var x0: int = max(0, floori(fallback.position.x))
	var y0: int = max(0, floori(fallback.position.y))
	var x1: int = min(image_size.x - 1, ceili(fallback.end.x))
	var y1: int = min(image_size.y - 1, ceili(fallback.end.y))
	var has_alpha := false
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if source_image.get_pixel(x, y).a <= 0.08:
				continue
			var point := Vector2(x, y)
			if not Geometry2D.is_point_in_polygon(point, points):
				continue
			has_alpha = true
			min_point = min_point.min(point)
			max_point = max_point.max(point)
	if not has_alpha:
		return fallback
	return Rect2(min_point, Vector2(maxf(1.0, max_point.x - min_point.x + 1.0), maxf(1.0, max_point.y - min_point.y + 1.0)))


func _apply_level_media(level_config: Dictionary) -> void:
	var image_path := _level_image_path(level_config, current_mode)
	var next_texture := _cached_texture(image_path)
	if next_texture == null:
		image_path = DEFAULT_LEVEL_IMAGE_PATH
		next_texture = _cached_texture(image_path)
	texture = next_texture
	source_image = _cached_source_image(image_path, texture)
	source_size = texture.get_size()


func _cached_texture(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]
	var loaded: Texture2D = load(path)
	if loaded != null:
		texture_cache[path] = loaded
		return loaded
	var image := Image.new()
	if image.load(path) == OK:
		var image_texture := ImageTexture.create_from_image(image)
		texture_cache[path] = image_texture
		return image_texture
	return loaded


func _cached_source_image(path: String, source_texture: Texture2D) -> Image:
	if source_image_cache.has(path):
		return source_image_cache[path]
	var image := source_texture.get_image()
	source_image_cache[path] = image
	return image


func _level_image_path(level_config: Dictionary, mode := "") -> String:
	if not mode.is_empty():
		var mode_config := _mode_config(level_config, mode)
		var mode_image_path := _image_path_from_value(mode_config.get("image", null), "")
		if not mode_image_path.is_empty():
			return mode_image_path
		mode_image_path = _image_path_from_value(mode_config.get("source_image", null), "")
		if not mode_image_path.is_empty():
			return mode_image_path
	return _default_level_image_path(level_config)


func _default_level_image_path(level_config: Dictionary) -> String:
	if level_config.has("assets") and typeof(level_config["assets"]) == TYPE_DICTIONARY:
		var assets: Dictionary = level_config["assets"]
		var default_image_path := _image_path_from_value(assets.get("default_image", null), "")
		if not default_image_path.is_empty():
			return default_image_path
	return _image_path_from_value(level_config.get("image", null), DEFAULT_LEVEL_IMAGE_PATH)


func _image_path_from_value(value, fallback: String) -> String:
	if typeof(value) == TYPE_STRING:
		return str(value)
	if typeof(value) == TYPE_DICTIONARY:
		return str(value.get("path", fallback))
	return fallback


func _level_background_color(level_config: Dictionary) -> Color:
	if level_config.has("background") and typeof(level_config["background"]) == TYPE_DICTIONARY:
		var bg: Dictionary = level_config["background"]
		if str(bg.get("type", "color")) == "color":
			return Color(str(bg.get("color", "#ead8bd")))
	return Color("#ead8bd")


func _add_level_background(level_config: Dictionary) -> void:
	var bg := ColorRect.new()
	bg.color = _level_background_color(level_config)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -101
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_layer.add_child(bg)
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
	bg_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_image.z_index = -100
	bg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_layer.add_child(bg_image)


func _config_string(config: Dictionary, key: String, fallback: String) -> String:
	if config.has(key):
		return str(config[key])
	if config.has("metadata") and typeof(config["metadata"]) == TYPE_DICTIONARY:
		return str(config["metadata"].get(key, fallback))
	return fallback


func _create_group(piece: Dictionary) -> void:
	var group_node := Node2D.new()
	group_node.name = piece["id"]
	group_node.rotation_degrees = [0, 90, 180, 270][int(rng.randi_range(0, 3))]
	group_node.z_index = groups.size()
	board_layer.add_child(group_node)
	var visual := _create_piece_visual(piece)
	group_node.add_child(visual)
	piece["visual"] = visual
	var group = PieceGroupScript.new(group_node, piece)
	groups.append(group)
	_move_group_to(group, _scatter_position_for_group(group))
	spawn_bounds.append(_group_bounds_at(group, group.node.position).grow(8.0))


func _create_piece_visual(piece: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.name = piece["id"] + "_visual"
	var poly := Polygon2D.new()
	poly.texture = texture
	poly.polygon = piece["polygon"]
	poly.uv = piece["uv"]
	node.add_child(poly)
	for cut_line in piece["cut_lines"]:
		var line := Line2D.new()
		line.width = 1.25
		line.default_color = Color(0.15, 0.10, 0.06, 0.62)
		line.closed = false
		line.points = cut_line
		node.add_child(line)
	return node


func _scatter_position_for_group(group) -> Vector2:
	var area := _piece_drag_area()
	var best_position := area.get_center()
	var best_score := INF
	var attempts := 96
	for attempt in range(attempts):
		var candidate := _spawn_candidate(area, attempt, attempts)
		var clamped := _clamped_group_position(group, candidate)
		var bounds := _group_bounds_at(group, clamped).grow(8.0)
		var score := _spawn_overlap_score(bounds, area)
		if score <= 0.001:
			return clamped
		if score < best_score:
			best_score = score
			best_position = clamped
	return best_position


func _spawn_candidate(area: Rect2, attempt: int, attempts: int) -> Vector2:
	if attempt < 12:
		var t := float(attempt) / 12.0
		var angle := t * TAU
		var radius := minf(area.size.x, area.size.y) * 0.36
		return area.get_center() + Vector2(cos(angle), sin(angle)) * radius
	if attempt < 28:
		var side := (attempt - 12) % 4
		var offset := float((attempt - 12) / 4 + 1) / 5.0
		if side == 0:
			return Vector2(lerpf(area.position.x, area.end.x, offset), area.position.y)
		if side == 1:
			return Vector2(area.end.x, lerpf(area.position.y, area.end.y, offset))
		if side == 2:
			return Vector2(lerpf(area.end.x, area.position.x, offset), area.end.y)
		return Vector2(area.position.x, lerpf(area.end.y, area.position.y, offset))
	return Vector2(
		rng.randf_range(area.position.x, area.end.x),
		rng.randf_range(area.position.y, area.end.y)
	)


func _spawn_overlap_score(bounds: Rect2, area: Rect2) -> float:
	var score := 0.0
	for existing in spawn_bounds:
		score += _rect_overlap_area(bounds, existing) * 18.0
	score += bounds.get_center().distance_squared_to(area.get_center()) * 0.002
	return score


func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var x0 := maxf(a.position.x, b.position.x)
	var y0 := maxf(a.position.y, b.position.y)
	var x1 := minf(a.end.x, b.end.x)
	var y1 := minf(a.end.y, b.end.y)
	return maxf(0.0, x1 - x0) * maxf(0.0, y1 - y0)


func _move_group_to(group, target_position: Vector2) -> void:
	if group == null or not is_instance_valid(group.node):
		return
	group.node.position = _clamped_group_position(group, target_position)


func _clamped_group_position(group, target_position: Vector2) -> Vector2:
	var bounds := _group_bounds_at(group, target_position)
	var area := _piece_drag_area()
	var delta := Vector2.ZERO
	if bounds.size.x <= area.size.x:
		if bounds.position.x < area.position.x:
			delta.x = area.position.x - bounds.position.x
		elif bounds.end.x > area.end.x:
			delta.x = area.end.x - bounds.end.x
	else:
		delta.x = area.get_center().x - bounds.get_center().x
	if bounds.size.y <= area.size.y:
		if bounds.position.y < area.position.y:
			delta.y = area.position.y - bounds.position.y
		elif bounds.end.y > area.end.y:
			delta.y = area.end.y - bounds.end.y
	else:
		delta.y = area.get_center().y - bounds.get_center().y
	return target_position + delta


func _piece_drag_area() -> Rect2:
	var play_area: Rect2 = _mobile_board_layout()["play_area"]
	return play_area.grow(-PIECE_DRAG_PADDING)


func _group_bounds_at(group, target_position: Vector2) -> Rect2:
	var has_point := false
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for member in group.members:
		var visual_position: Vector2 = member["visual"].position
		for bounds_points in _member_bounds_points_list(member):
			for point in bounds_points:
				var global_point: Vector2 = target_position + (visual_position + point).rotated(group.node.rotation)
				min_point = min_point.min(global_point)
				max_point = max_point.max(global_point)
				has_point = true
	if not has_point:
		return Rect2(target_position, Vector2.ZERO)
	return Rect2(min_point, max_point - min_point)


func _member_bounds_points_list(member: Dictionary) -> Array[PackedVector2Array]:
	if member.has("bounds_points_list") and typeof(member["bounds_points_list"]) == TYPE_ARRAY and not member["bounds_points_list"].is_empty():
		return member["bounds_points_list"]
	return [member.get("bounds_points", member["polygon"])]


func _begin_drag(screen_pos: Vector2) -> void:
	var group = _group_at(screen_pos)
	if group == null:
		return
	if group.is_animating:
		return
	_clear_hint_highlights()
	_select_group(group)
	dragging = group
	drag_offset = group.node.position - screen_pos
	_bring_to_front(group)


func _end_drag() -> void:
	if dragging == null:
		return
	_try_snap_chain(dragging)
	_check_complete()
	dragging = null


func _group_at(screen_pos: Vector2):
	for i in range(groups.size() - 1, -1, -1):
		var group = groups[i]
		var local_to_group: Vector2 = group.node.to_local(screen_pos)
		for member in group.members:
			var local_to_piece: Vector2 = local_to_group - member["visual"].position
			if Geometry2D.is_point_in_polygon(local_to_piece, member["polygon"]) and _local_point_has_alpha(member, local_to_piece):
				return group
	return null


func _local_point_has_alpha(member: Dictionary, local_point: Vector2) -> bool:
	var source_point: Vector2 = (local_point + member["home"] - board_origin) / source_scale
	return _source_point_has_alpha(source_point, HIT_ALPHA_RADIUS)


func _source_point_has_alpha(source_point: Vector2, radius := HIT_ALPHA_RADIUS) -> bool:
	var center := Vector2i(roundi(source_point.x), roundi(source_point.y))
	var image_size := source_image.get_size()
	for y in range(center.y - radius, center.y + radius + 1):
		if y < 0 or y >= image_size.y:
			continue
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= image_size.x:
				continue
			if source_image.get_pixel(x, y).a > 0.08:
				return true
	return false


func _visible_cut_line_segments(source_line: PackedVector2Array, home: Vector2, scale: float, origin: Vector2) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var current := PackedVector2Array()
	for index in range(source_line.size() - 1):
		var a: Vector2 = source_line[index]
		var b: Vector2 = source_line[index + 1]
		var sample_count: int = max(2, ceili(a.distance_to(b) / 6.0))
		for sample_index in range(sample_count + 1):
			if index > 0 and sample_index == 0:
				continue
			var source_point: Vector2 = a.lerp(b, float(sample_index) / float(sample_count))
			if _source_point_has_alpha(source_point, 3):
				current.append(origin + source_point * scale - home)
			else:
				if current.size() >= 2:
					segments.append(current)
				current = PackedVector2Array()
	if current.size() >= 2:
		segments.append(current)
	return segments


func _select_group(group) -> void:
	selected_group = group
	status_label.text = "已选中碎片。"


func _rotate_group(group) -> void:
	if group == null or group.is_animating:
		return
	group.is_animating = true
	var target: float = snappedf(group.node.rotation_degrees + 90.0, 90.0)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(group.node, "rotation_degrees", target, 0.16)
	tween.finished.connect(func() -> void:
		if not groups.has(group) or not is_instance_valid(group.node):
			return
		group.is_animating = false
		_try_snap_chain(group)
		_check_complete()
	)


func _rotate_selected_group() -> void:
	if selected_group == null or not groups.has(selected_group):
		status_label.text = "先选中一个碎片。"
		return
	_rotate_group(selected_group)


func _bring_to_front(group) -> void:
	groups.erase(group)
	groups.append(group)
	for i in groups.size():
		groups[i].node.z_index = i


func _try_snap_chain(active) -> void:
	var progressed := true
	while progressed:
		progressed = false
		var other = SnapSolverScript.find_match(active, groups, _snap_tolerance(), ROTATION_TOLERANCE)
		if other != null:
			_clear_hint_highlights()
			active.absorb(other)
			groups.erase(other)
			_move_group_to(active, active.node.position)
			if selected_group == other:
				selected_group = active
			_pulse_node(active.node)
			progressed = true


func _snap_tolerance() -> float:
	return clampf(SNAP_TOLERANCE * maxf(0.75, source_scale), 16.0, 24.0)


func _check_complete() -> void:
	if groups.size() == 1:
		_mark_completed(current_level["id"], current_mode)
		_show_complete_modal()
	else:
		status_label.text = "剩余碎片组：%d" % groups.size()


func _align_all() -> void:
	for group in groups:
		if group.is_animating:
			continue
		group.is_animating = true
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(group.node, "rotation_degrees", 0.0, 0.16)
		tween.finished.connect(func(g = group) -> void:
			if is_instance_valid(g.node):
				g.is_animating = false
		)
	status_label.text = "所有碎片已转正。"


func _show_hint() -> void:
	if groups.size() <= 1:
		return
	var pair := _find_hint_pair()
	if pair.is_empty():
		_clear_hint_highlights()
		status_label.text = "暂时没有可提示的相邻碎片。"
		return
	selected_group = pair[0]
	_bring_to_front(pair[0])
	_bring_to_front(pair[1])
	_set_hint_highlights(pair)
	_hint_pulse_node(pair[0].node)
	_hint_pulse_node(pair[1].node)
	status_label.text = "提示：这两个碎片可以拼接。"


func _set_hint_highlights(pair: Array) -> void:
	_clear_hint_highlights()
	if pair.size() < 4:
		return
	_add_hint_edge_highlights(pair[2], pair[3])
	hint_highlighted_groups.append(pair[0])
	hint_highlighted_groups.append(pair[1])


func _add_hint_edge_highlights(a_member: Dictionary, b_member: Dictionary) -> void:
	if a_member.is_empty() or b_member.is_empty():
		return
	var a_segments := _shared_edge_segments(a_member, b_member)
	var b_segments := _shared_edge_segments(b_member, a_member)
	if a_segments.is_empty() and b_segments.is_empty():
		a_segments = _nearest_edge_segments(a_member, b_member)
		b_segments = _nearest_edge_segments(b_member, a_member)
	_add_hint_lines_to_member(a_member, a_segments)
	_add_hint_lines_to_member(b_member, b_segments)


func _shared_edge_segments(member: Dictionary, other_member: Dictionary) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var polygon: PackedVector2Array = member["polygon"]
	var other_solved := _member_solved_polygon(other_member)
	if polygon.size() < 2 or other_solved.size() < 2:
		return segments
	var tolerance := maxf(5.0, source_scale * 8.0)
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		var edge_length := a.distance_to(b)
		if edge_length < 1.0:
			continue
		var sample_count: int = max(3, ceili(edge_length / 8.0))
		var current := PackedVector2Array()
		for sample_index in range(sample_count + 1):
			var t := float(sample_index) / float(sample_count)
			var local_point := a.lerp(b, t)
			var solved_point: Vector2 = member["home"] + local_point
			if _point_to_polygon_boundary_distance(solved_point, other_solved) <= tolerance:
				current.append(local_point)
			else:
				if current.size() >= 2:
					segments.append(current)
				current = PackedVector2Array()
		if current.size() >= 2:
			segments.append(current)
	return segments


func _nearest_edge_segments(member: Dictionary, other_member: Dictionary) -> Array[PackedVector2Array]:
	var polygon: PackedVector2Array = member["polygon"]
	var other_solved := _member_solved_polygon(other_member)
	var best_edge := PackedVector2Array()
	var best_distance := INF
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		var midpoint := a.lerp(b, 0.5)
		var solved_midpoint: Vector2 = member["home"] + midpoint
		var distance := _point_to_polygon_boundary_distance(solved_midpoint, other_solved)
		if distance < best_distance:
			best_distance = distance
			best_edge = PackedVector2Array([a, b])
	return [best_edge] if best_edge.size() >= 2 else []


func _add_hint_lines_to_member(member: Dictionary, segments: Array[PackedVector2Array]) -> void:
	var visual: Node2D = member["visual"]
	if not is_instance_valid(visual):
		return
	for segment in segments:
		var line := Line2D.new()
		line.name = "hint_highlight"
		line.width = 6.0
		line.default_color = Color(1.0, 0.73, 0.18, 0.96)
		line.closed = false
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.z_index = 20
		line.points = segment
		visual.add_child(line)
		hint_highlighted_lines.append(line)


func _member_solved_polygon(member: Dictionary) -> PackedVector2Array:
	var solved := PackedVector2Array()
	for point in member["polygon"]:
		solved.append(member["home"] + point)
	return solved


func _point_to_polygon_boundary_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	var best := INF
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		best = minf(best, _point_to_segment_distance(point, a, b))
	return best


func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _clear_hint_highlights() -> void:
	for line in hint_highlighted_lines:
		if line == null:
			continue
		if is_instance_valid(line):
			line.queue_free()
	hint_highlighted_groups.clear()
	hint_highlighted_lines.clear()


func _find_hint_pair() -> Array:
	for i in groups.size():
		for j in range(i + 1, groups.size()):
			var member_pair := _neighbor_member_pair(groups[i], groups[j])
			if not member_pair.is_empty():
				return [groups[i], groups[j], member_pair[0], member_pair[1]]
	return []


func _groups_are_neighbors(a, b) -> bool:
	return not _neighbor_member_pair(a, b).is_empty()


func _neighbor_member_pair(a, b) -> Array:
	for am in a.members:
		for bm in b.members:
			if am["neighbors"].has(bm["id"]) or bm["neighbors"].has(am["id"]):
				return [am, bm]
	return []


func _toggle_preview() -> void:
	if is_instance_valid(preview_sprite):
		var show := not preview_sprite.visible
		preview_sprite.visible = true
		var target_alpha := 0.82 if show else 0.0
		var start_alpha := 0.0 if show else preview_sprite.modulate.a
		preview_sprite.modulate.a = start_alpha
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(preview_sprite, "modulate:a", target_alpha, 0.18)
		if not show:
			tween.finished.connect(func() -> void:
				if is_instance_valid(preview_sprite):
					preview_sprite.visible = false
			)


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
	var box := _modal_box(Vector2(380, 330))
	box.add_child(_modal_title("设置"))
	for name in ["音乐", "音效", "震动反馈"]:
		var check := CheckBox.new()
		check.text = name
		check.button_pressed = true
		check.add_theme_color_override("font_color", brown)
		box.add_child(check)
	box.add_child(_button("关闭", _close_modal))


func _show_tutorial_modal() -> void:
	_show_modal()
	var box := _modal_box(Vector2(420, 290))
	box.add_child(_modal_title("怎么玩"))
	var text := Label.new()
	text.text = "单指按住碎片并拖动。\n\n双击碎片可以旋转 90 度。\n\n把相邻碎片靠近正确位置，它们会自动吸附。"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 20)
	text.add_theme_color_override("font_color", brown)
	box.add_child(text)
	box.add_child(_button("知道了", func() -> void:
		_mark_tutorial_seen()
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
		_show_game(current_topic, current_level, "knob" if _mode_key(current_mode) == "polygon" else "polygon")
	, false, Vector2(138, 48)))
	row.add_child(_button("返回关卡列表", func() -> void:
		_close_modal()
		_show_levels(current_topic, str(current_level.get("id", "")))
	, false, Vector2(154, 48)))
	return row


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
			var modes := _completed_modes(level["id"])
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


func _is_done(level_id: String, play_mode: String) -> bool:
	var key := _mode_key(play_mode)
	if not progress.has(level_id):
		return false
	if typeof(progress[level_id]) != TYPE_DICTIONARY:
		return false
	if progress[level_id].get(key, false):
		return true
	return key == "knob" and progress[level_id].get("classic", false)


func _mark_completed(level_id: String, play_mode: String) -> void:
	if not progress.has(level_id) or typeof(progress[level_id]) != TYPE_DICTIONARY:
		progress[level_id] = {}
	progress[level_id][_mode_key(play_mode)] = true
	_save_progress()


func _mark_last_played(topic: Dictionary, level: Dictionary, play_mode: String) -> void:
	progress["_last_topic_id"] = str(topic.get("id", ""))
	progress["_last_level_id"] = str(level.get("id", ""))
	progress["_last_mode"] = _mode_key(play_mode)
	_save_progress()


func _tutorial_seen() -> bool:
	return progress.get("_tutorial_seen", false)


func _mark_tutorial_seen() -> void:
	progress["_tutorial_seen"] = true
	_save_progress()


func _completed_modes(level_id: String) -> Array:
	var modes := []
	if _is_done(level_id, "polygon"):
		modes.append("多边形")
	if _is_done(level_id, "knob"):
		modes.append("凹凸拼图")
	return modes


func _topic_done_count(topic: Dictionary) -> int:
	var count := 0
	for level in topic["levels"]:
		if _is_done(level["id"], "polygon"):
			count += 1
		if _is_done(level["id"], "knob"):
			count += 1
	return count


func _mode_done_count(topic: Dictionary, play_mode: String) -> int:
	var count := 0
	for level in topic["levels"]:
		if _is_done(level["id"], play_mode):
			count += 1
	return count


func _last_topic_or_first() -> Dictionary:
	var last_topic := _topic_by_id(str(progress.get("_last_topic_id", "")))
	if not last_topic.is_empty():
		return last_topic
	return topics[0] if not topics.is_empty() else {}


func _topic_by_id(topic_id: String) -> Dictionary:
	if topic_id.is_empty():
		return {}
	for topic in topics:
		if str(topic.get("id", "")) == topic_id:
			return topic
	return {}


func _level_by_id(topic: Dictionary, level_id: String) -> Dictionary:
	if topic.is_empty() or level_id.is_empty():
		return {}
	for level in topic.get("levels", []):
		if str(level.get("id", "")) == level_id:
			return level
	return {}


func _focus_level_id(topic: Dictionary) -> String:
	var level := _focus_level(topic)
	return str(level.get("id", "")) if not level.is_empty() else ""


func _focus_level(topic: Dictionary) -> Dictionary:
	if topic.is_empty():
		return {}
	var last_level := _level_by_id(topic, str(progress.get("_last_level_id", "")))
	if not last_level.is_empty() and _level_has_unfinished_mode(last_level):
		return last_level
	for level in topic.get("levels", []):
		if _level_has_unfinished_mode(level):
			return level
	if not last_level.is_empty():
		return last_level
	var levels: Array = topic.get("levels", [])
	return levels[0] if not levels.is_empty() else {}


func _level_has_unfinished_mode(level: Dictionary) -> bool:
	var level_id := str(level.get("id", ""))
	return not _is_done(level_id, "polygon") or not _is_done(level_id, "knob")


func _preferred_mode(level: Dictionary) -> String:
	var level_id := str(level.get("id", ""))
	var last_mode := _mode_key(str(progress.get("_last_mode", "polygon")))
	if last_mode in ["polygon", "knob"] and not _is_done(level_id, last_mode):
		return last_mode
	if not _is_done(level_id, "polygon"):
		return "polygon"
	if not _is_done(level_id, "knob"):
		return "knob"
	return last_mode if last_mode in ["polygon", "knob"] else "polygon"


func _resume_target() -> Dictionary:
	var topic := _last_topic_or_first()
	if topic.is_empty():
		return {}
	var level := _focus_level(topic)
	return {
		"topic": topic,
		"level": level,
		"mode": _preferred_mode(level),
	}


func _last_completed_level() -> Dictionary:
	for topic in topics:
		for level in topic["levels"]:
			if _is_done(level["id"], "polygon") or _is_done(level["id"], "knob"):
				return { "topic": topic, "level": level }
	return {}


func _first_unfinished_level() -> Dictionary:
	for topic in topics:
		for level in topic["levels"]:
			if not _is_done(level["id"], "polygon") or not _is_done(level["id"], "knob"):
				return { "topic": topic, "level": level }
	return { "topic": topics[0], "level": topics[0]["levels"][0] }
