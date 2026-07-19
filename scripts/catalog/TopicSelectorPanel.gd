extends RefCounted
class_name TopicSelectorPanel

var game: Node
var controls: TopicHomeControls
var panel: Panel
var grid: GridContainer
var buttons: Dictionary = {}
var toggle_icon: TextureRect
var select_action: Callable
var ui_scale := 1.0


func _init(owner: Node, control_factory: TopicHomeControls) -> void:
	game = owner
	controls = control_factory


func build(viewport_size: Vector2, scale: float, anchor_bottom: float, topics: Array[Dictionary], current_index: int, action: Callable) -> Panel:
	ui_scale = scale
	select_action = action
	panel = Panel.new()
	panel.name = "topic_selector_panel"
	var width := minf(viewport_size.x - 32.0 * scale, 330.0 * scale)
	var max_height := minf(viewport_size.y * 0.43, 350.0 * scale)
	var row_count := ceili(float(topics.size()) / 2.0)
	var content_height := 24.0 * scale + float(row_count) * 46.0 * scale + float(maxi(0, row_count - 1)) * 5.0 * scale
	var height := minf(max_height, content_height)
	panel.position = Vector2((viewport_size.x - width) * 0.5, anchor_bottom - height)
	panel.size = Vector2(width, height)
	panel.visible = false
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", controls.style_box(Color("#FBFAF7"), int(22.0 * scale)))
	var scroll := ScrollContainer.new()
	scroll.name = "topic_selector_scroll"
	scroll.position = Vector2(10.0 * scale, 12.0 * scale)
	scroll.size = panel.size - Vector2(20.0 * scale, 24.0 * scale)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)
	grid = GridContainer.new()
	grid.name = "topic_selector_grid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(8.0 * scale))
	grid.add_theme_constant_override("v_separation", int(5.0 * scale))
	grid.custom_minimum_size.x = scroll.size.x - 8.0 * scale
	scroll.add_child(grid)
	_style_scrollbar(scroll.get_v_scroll_bar(), scale)
	buttons.clear()
	var item_width := (grid.custom_minimum_size.x - 8.0 * scale) * 0.5
	for topic_index in topics.size():
		var topic: Dictionary = topics[topic_index]
		var button := Button.new()
		button.name = "topic_selector_%s" % str(topic.get("id", ""))
		button.text = str(topic.get("name", ""))
		button.custom_minimum_size = Vector2(item_width, 46.0 * scale)
		button.size = button.custom_minimum_size
		button.clip_text = true
		button.add_theme_font_size_override("font_size", maxi(15, int(18.0 * scale)))
		button.pressed.connect(func(index: int = topic_index) -> void: _select(index))
		game._wire_button_animation(button)
		grid.add_child(button)
		buttons[topic_index] = button
	update_current(current_index)
	return panel


func set_toggle_icon(icon: TextureRect) -> void:
	toggle_icon = icon


func toggle() -> void:
	if panel == null:
		return
	if panel.visible:
		close()
	else:
		open()


func open() -> void:
	if panel == null:
		return
	panel.visible = true
	panel.pivot_offset = Vector2(panel.size.x * 0.5, panel.size.y)
	if toggle_icon != null:
		toggle_icon.rotation = PI
	if game._ui_motion_reduced():
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE
		return
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	panel.position.y += 8.0 * ui_scale
	var final_y := panel.position.y - 8.0 * ui_scale
	var tween := game.create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", final_y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	if panel == null or not panel.visible:
		return
	if toggle_icon != null:
		toggle_icon.rotation = 0.0
	if game._ui_motion_reduced():
		panel.visible = false
		panel.modulate.a = 0.0
		return
	var tween := game.create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "scale", Vector2(0.98, 0.98), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if panel != null and is_instance_valid(panel):
			panel.visible = false
			panel.scale = Vector2.ONE
	)


func update_current(current_index: int) -> void:
	for index_value in buttons.keys():
		var button: Button = buttons[index_value]
		if button != null and is_instance_valid(button):
			controls.apply_selector_style(button, int(index_value) == current_index, ui_scale)


func _select(index: int) -> void:
	close()
	if select_action.is_valid():
		select_action.call(index)


func _style_scrollbar(scrollbar: VScrollBar, scale: float) -> void:
	if scrollbar == null:
		return
	scrollbar.custom_minimum_size.x = maxf(3.0, 3.0 * scale)
	scrollbar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	var thumb := controls.style_box(Color(0.078, 0.306, 0.357, 0.36), int(2.0 * scale))
	scrollbar.add_theme_stylebox_override("grabber", thumb)
	scrollbar.add_theme_stylebox_override("grabber_highlight", thumb)
	scrollbar.add_theme_stylebox_override("grabber_pressed", thumb)
