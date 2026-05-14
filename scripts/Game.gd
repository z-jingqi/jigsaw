extends Node2D

const IMAGE_PATH := "res://assets/source/cat_moon.png"
const MENU_BACKGROUND_PATH := "res://assets/source/menu_background.png"
const TITLE_IMAGE_PATH := "res://assets/ui/title.png"
const START_BUTTON_IMAGE_PATH := "res://assets/ui/start-game.png"
const CHOOSE_LEVEL_PANEL_PATH := "res://assets/ui/choose-level.png"
const ICON_ALBUM_PATH := "res://assets/icons/album.svg"
const ICON_LEFT_ARROW_PATH := "res://assets/icons/left-arrow.svg"
const ICON_LIGHTBULB_PATH := "res://assets/icons/lightbulb.svg"
const ICON_PAUSE_PATH := "res://assets/icons/pause.svg"
const ICON_ROTATE_PATH := "res://assets/icons/rotate.svg"
const ICON_SETTING_PATH := "res://assets/icons/setting.svg"
const LEVEL_CONFIG_PATH := "res://levels/cat_moon_01.json"
const COLS := 3
const ROWS := 3
const PIECE_SIZE := 190.0
const SNAP_TOLERANCE := 42.0
const ROTATION_TOLERANCE := 3.0
const HIT_ALPHA_RADIUS := 2
const COMPONENT_MASK_RADIUS := 5
const SAVE_PATH := "user://jigcat_progress.json"
const LevelGeneratorScript := preload("res://scripts/LevelGenerator.gd")
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
var menu_background: Texture2D
var title_texture: Texture2D
var start_button_texture: Texture2D
var choose_level_panel_texture: Texture2D
var icon_album: Texture2D
var icon_left_arrow: Texture2D
var icon_lightbulb: Texture2D
var icon_pause: Texture2D
var icon_rotate: Texture2D
var icon_setting: Texture2D
var source_image: Image
var source_size := Vector2.ZERO
var source_scale := 1.0
var board_origin := Vector2.ZERO
var active_level_config := {}
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
var current_mode := "classic"
var current_screen := "home"
var modal_open := false

var groups: Array = []
var dragging = null
var selected_group = null
var active_touch_index := -1
var drag_offset := Vector2.ZERO
var status_label: Label


func _ready() -> void:
	rng.seed = 7
	texture = load(IMAGE_PATH)
	menu_background = load(MENU_BACKGROUND_PATH)
	title_texture = load(TITLE_IMAGE_PATH)
	start_button_texture = load(START_BUTTON_IMAGE_PATH)
	choose_level_panel_texture = load(CHOOSE_LEVEL_PANEL_PATH)
	icon_album = load(ICON_ALBUM_PATH)
	icon_left_arrow = load(ICON_LEFT_ARROW_PATH)
	icon_lightbulb = load(ICON_LIGHTBULB_PATH)
	icon_pause = load(ICON_PAUSE_PATH)
	icon_rotate = load(ICON_ROTATE_PATH)
	icon_setting = load(ICON_SETTING_PATH)
	source_image = texture.get_image()
	source_size = texture.get_size()
	board_layer = Node2D.new()
	add_child(board_layer)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_build_catalog()
	_load_progress()
	_show_topics()


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
		dragging.node.position = motion.position + drag_offset
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
			dragging.node.position = drag_event.position + drag_offset


func _build_catalog() -> void:
	var cat_config := _load_config_path(LEVEL_CONFIG_PATH)
	var level_title := _config_string(cat_config, "title", "月亮小睡")
	var level_description := _config_string(cat_config, "description", "小猫安静地靠在月亮上，像一段柔软的午后梦。")
	topics = [{
		"id": "cats",
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
	dragging = null
	selected_group = null


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


func _button(text: String, action: Callable, primary := true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 42)
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
	button.custom_minimum_size = Vector2(76, 76)
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var empty := StyleBoxEmpty.new()
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_color_override("icon_normal_color", brown)
	button.add_theme_color_override("icon_hover_color", deep_orange)
	button.add_theme_color_override("icon_pressed_color", deep_orange)
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
	var target := _first_unfinished_level()
	_show_game(target["topic"], target["level"], "polygon")


func _show_topics() -> void:
	current_screen = "topics"
	var wrap := _base_screen(cream, true)
	_root_title(wrap)
	var top_actions := HBoxContainer.new()
	top_actions.alignment = BoxContainer.ALIGNMENT_END
	top_actions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_actions.offset_left = -130
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
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 24)
	center.add_child(grid)
	for topic in topics:
		var total: int = topic["levels"].size() * 2
		var done: int = _topic_done_count(topic)
		var card := _card_button(
			"%s\n%d/%d" % [topic["name"], done, total],
			Vector2(360, 260),
			func(t: Dictionary = topic) -> void: _show_levels(t)
		)
		grid.add_child(card)


func _show_levels(topic: Dictionary) -> void:
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
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 24)
	center.add_child(grid)
	for level in topic["levels"]:
		var done_poly := _is_done(level["id"], "polygon")
		var done_classic := _is_done(level["id"], "classic")
		var text := "%s\n⬡ %s   🧩 %s" % [
			level["title"],
			"完成" if done_poly else "未完成",
			"完成" if done_classic else "未完成"
		]
		var card := _card_button(
			text,
			Vector2(360, 260),
			func(l: Dictionary = level) -> void: _show_mode_dialog(l)
		)
		grid.add_child(card)
	var footer := Label.new()
	footer.text = "⬡ %d/%d    🧩 %d/%d    全部 %d/%d" % [
		_mode_done_count(topic, "polygon"), topic["levels"].size(),
		_mode_done_count(topic, "classic"), topic["levels"].size(),
		_topic_done_count(topic), topic["levels"].size() * 2
	]
	footer.add_theme_color_override("font_color", brown)
	footer.add_theme_color_override("font_shadow_color", Color(1, 0.96, 0.88, 0.7))
	wrap.add_child(footer)


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
	card.pressed.connect(action)
	_wire_button_animation(card)
	return card


func _show_mode_dialog(level: Dictionary) -> void:
	current_level = level
	_show_modal()
	var box := _modal_box(Vector2(480, 560))
	box.add_child(_image_rect(Vector2(420, 230)))
	var title := Label.new()
	title.text = level["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", brown)
	box.add_child(title)
	box.add_child(_mode_button(level, "polygon", "⬡ 多边形模式"))
	box.add_child(_mode_button(level, "classic", "🧩 经典拼图模式"))
	box.add_child(_button("关闭", _close_modal, false))


func _mode_button(level: Dictionary, play_mode: String, label: String) -> Button:
	var done := _is_done(level["id"], play_mode)
	var text := "%s\n%s · %s" % [label, "已完成 ✓" if done else "未完成", "再玩一次" if done else "开始"]
	var button := _button(text, func() -> void:
		_close_modal()
		_show_game(current_topic, level, play_mode)
	, false)
	button.custom_minimum_size = Vector2(420, 82)
	return button


func _show_game(topic: Dictionary, level: Dictionary, play_mode: String) -> void:
	current_screen = "game"
	current_topic = topic
	current_level = level
	current_mode = play_mode
	active_level_config = _load_level_config(current_level)
	_apply_level_media(active_level_config)
	_clear_ui()
	_clear_board()
	_add_level_background(active_level_config)
	_start_play_session(play_mode)
	_build_game_hud(level["title"])
	if not _tutorial_seen():
		_show_tutorial_modal()


func _build_game_hud(level_title: String) -> void:
	var title := Label.new()
	title.text = level_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18
	title.offset_left = 360
	title.offset_right = -360
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", brown)
	screen_root.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -720
	row.offset_top = 12
	row.offset_right = -18
	row.offset_bottom = 94
	row.add_theme_constant_override("separation", 10)
	screen_root.add_child(row)
	row.add_child(_icon_button(icon_rotate, _align_all, "转正"))
	row.add_child(_icon_button(icon_lightbulb, _show_hint, "提示"))
	row.add_child(_icon_button(icon_album, _toggle_preview, "预览图"))
	row.add_child(_icon_button(icon_pause, _show_pause_modal, "暂停"))
	row.add_child(_icon_button(icon_setting, _show_settings_modal, "设置"))
	status_label = Label.new()
	status_label.text = "拖动碎片。双击碎片旋转。"
	status_label.position = Vector2(20, 740)
	status_label.add_theme_color_override("font_color", brown)
	screen_root.add_child(status_label)
	_animate_screen_in(screen_root)


func _start_play_session(play_mode: String) -> void:
	var generator_mode := "irregular" if play_mode == "polygon" else "classic"
	var level := LevelGeneratorScript.generate(source_size, COLS, ROWS, PIECE_SIZE, generator_mode, source_image, active_level_config)
	source_scale = level["source_scale"]
	board_origin = level["board_origin"]
	for piece in level["pieces"]:
		_create_group(piece)
	preview_sprite = Sprite2D.new()
	preview_sprite.texture = texture
	preview_sprite.scale = Vector2.ONE * source_scale * 0.42
	preview_sprite.position = Vector2(1050, 430)
	preview_sprite.modulate = Color(1, 1, 1, 0.82)
	preview_sprite.visible = false
	board_layer.add_child(preview_sprite)


func _load_level_config(level: Dictionary) -> Dictionary:
	var config_path: String = level.get("config_path", "")
	return _load_config_path(config_path)


func _load_config_path(config_path: String) -> Dictionary:
	if config_path.is_empty() or not FileAccess.file_exists(config_path):
		return {}
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _apply_level_media(level_config: Dictionary) -> void:
	var image_path := _level_image_path(level_config)
	var next_texture: Texture2D = load(image_path)
	if next_texture == null:
		next_texture = load(IMAGE_PATH)
	texture = next_texture
	source_image = texture.get_image()
	source_size = texture.get_size()


func _level_image_path(level_config: Dictionary) -> String:
	if level_config.has("image") and typeof(level_config["image"]) == TYPE_STRING:
		return level_config["image"]
	if level_config.has("image") and typeof(level_config["image"]) == TYPE_DICTIONARY:
		return str(level_config["image"].get("path", IMAGE_PATH))
	return IMAGE_PATH


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
	group_node.position = _scatter_position()
	group_node.rotation_degrees = [0, 90, 180, 270][int(rng.randi_range(0, 3))]
	group_node.z_index = groups.size()
	board_layer.add_child(group_node)
	var visual := _create_piece_visual(piece)
	group_node.add_child(visual)
	piece["visual"] = visual
	groups.append(PieceGroupScript.new(group_node, piece))


func _create_piece_visual(piece: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.name = piece["id"] + "_visual"
	var poly := Polygon2D.new()
	poly.texture = _texture_for_piece(piece)
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


func _texture_for_piece(piece: Dictionary) -> Texture2D:
	if not piece.has("component_samples") or piece["component_samples"].is_empty():
		return texture
	var image_size := source_image.get_size()
	var masked := Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	masked.fill(Color(1, 1, 1, 0))
	var rect: Rect2 = piece["source_rect"]
	var start_x := clampi(floori(rect.position.x), 0, image_size.x - 1)
	var start_y := clampi(floori(rect.position.y), 0, image_size.y - 1)
	var end_x := clampi(ceili(rect.end.x), start_x + 1, image_size.x)
	var end_y := clampi(ceili(rect.end.y), start_y + 1, image_size.y)
	var samples: Dictionary = piece["component_samples"]
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var color := source_image.get_pixel(x, y)
			if color.a <= 0.08:
				continue
			if _component_samples_contain_pixel(samples, Vector2i(x, y)):
				masked.set_pixel(x, y, color)
	return ImageTexture.create_from_image(masked)


func _component_samples_contain_pixel(samples: Dictionary, pixel: Vector2i) -> bool:
	for y in range(pixel.y - COMPONENT_MASK_RADIUS, pixel.y + COMPONENT_MASK_RADIUS + 1):
		for x in range(pixel.x - COMPONENT_MASK_RADIUS, pixel.x + COMPONENT_MASK_RADIUS + 1):
			if samples.has(Vector2i(x, y)):
				return true
	return false


func _scatter_position() -> Vector2:
	var margin := 90.0
	return Vector2(rng.randf_range(margin, get_viewport_rect().size.x - margin), rng.randf_range(130.0, get_viewport_rect().size.y - margin))


func _begin_drag(screen_pos: Vector2) -> void:
	var group = _group_at(screen_pos)
	if group == null:
		return
	if group.is_animating:
		return
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
	var center := Vector2i(roundi(source_point.x), roundi(source_point.y))
	var image_size := source_image.get_size()
	for y in range(center.y - HIT_ALPHA_RADIUS, center.y + HIT_ALPHA_RADIUS + 1):
		if y < 0 or y >= image_size.y:
			continue
		for x in range(center.x - HIT_ALPHA_RADIUS, center.x + HIT_ALPHA_RADIUS + 1):
			if x < 0 or x >= image_size.x:
				continue
			if source_image.get_pixel(x, y).a > 0.08:
				return true
	return false


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
		var other = SnapSolverScript.find_match(active, groups, SNAP_TOLERANCE, ROTATION_TOLERANCE)
		if other != null:
			active.absorb(other)
			groups.erase(other)
			if selected_group == other:
				selected_group = active
			_pulse_node(active.node)
			progressed = true


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
		status_label.text = "暂时没有可提示的相邻碎片。"
		return
	selected_group = pair[0]
	_hint_pulse_node(pair[0].node)
	_hint_pulse_node(pair[1].node)
	status_label.text = "提示：这两个碎片可以拼接。"


func _find_hint_pair() -> Array:
	for i in groups.size():
		for j in range(i + 1, groups.size()):
			if _groups_are_neighbors(groups[i], groups[j]):
				return [groups[i], groups[j]]
	return []


func _groups_are_neighbors(a, b) -> bool:
	for am in a.members:
		for bm in b.members:
			if am["neighbors"].has(bm["id"]) or bm["neighbors"].has(am["id"]):
				return true
	return false


func _toggle_preview() -> void:
	if preview_sprite:
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
		_show_levels(current_topic)
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
	var box := _modal_box(Vector2(500, 610))
	var ribbon := Label.new()
	ribbon.text = "恭喜完成！"
	ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon.add_theme_font_size_override("font_size", 30)
	ribbon.add_theme_color_override("font_color", orange)
	box.add_child(ribbon)
	box.add_child(_image_rect(Vector2(420, 300)))
	box.add_child(_modal_title(current_level["title"]))
	var desc := Label.new()
	desc.text = current_level["description"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", brown)
	box.add_child(desc)
	box.add_child(_button("下一个", _play_next_level))
	box.add_child(_button("换个模式", func() -> void:
		_close_modal()
		_show_game(current_topic, current_level, "classic" if current_mode == "polygon" else "polygon")
	, false))
	box.add_child(_button("返回关卡列表", func() -> void:
		_close_modal()
		_show_levels(current_topic)
	, false))


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
	grid.columns = 3
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


func _show_album_detail(topic: Dictionary, level: Dictionary, modes: Array) -> void:
	var wrap := _base_screen()
	_header(wrap, level["title"], _show_album)
	wrap.add_child(_image_rect(Vector2(560, 420)))
	var desc := Label.new()
	desc.text = "%s\n已完成模式：%s" % [level["description"], " / ".join(modes)]
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", brown)
	wrap.add_child(desc)


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


func _modal_box(size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = paper
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
	return progress.has(level_id) and progress[level_id].get(play_mode, false)


func _mark_completed(level_id: String, play_mode: String) -> void:
	if not progress.has(level_id):
		progress[level_id] = {}
	progress[level_id][play_mode] = true
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
	if _is_done(level_id, "classic"):
		modes.append("经典拼图")
	return modes


func _topic_done_count(topic: Dictionary) -> int:
	var count := 0
	for level in topic["levels"]:
		if _is_done(level["id"], "polygon"):
			count += 1
		if _is_done(level["id"], "classic"):
			count += 1
	return count


func _mode_done_count(topic: Dictionary, play_mode: String) -> int:
	var count := 0
	for level in topic["levels"]:
		if _is_done(level["id"], play_mode):
			count += 1
	return count


func _last_completed_level() -> Dictionary:
	for topic in topics:
		for level in topic["levels"]:
			if _is_done(level["id"], "polygon") or _is_done(level["id"], "classic"):
				return { "topic": topic, "level": level }
	return {}


func _first_unfinished_level() -> Dictionary:
	for topic in topics:
		for level in topic["levels"]:
			if not _is_done(level["id"], "polygon") or not _is_done(level["id"], "classic"):
				return { "topic": topic, "level": level }
	return { "topic": topics[0], "level": topics[0]["levels"][0] }
