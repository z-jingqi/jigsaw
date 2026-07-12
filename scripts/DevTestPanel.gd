extends Control
class_name DevTestPanel

const PANEL_MIN_HEIGHT := 560.0
const PANEL_HEIGHT_RATIO := 0.55
const REFRESH_INTERVAL := 0.25

var host: Node
var drawer: PanelContainer
var dim: ColorRect
var level_select: OptionButton
var mode_select: OptionButton
var viewport_select: OptionButton
var metrics_label: Label
var hint_label: Label
var state_label: Label
var status_label: Label
var level_options: Array = []
var viewport_presets: Array[Dictionary] = [
	{"label": "当前窗口", "size": Vector2i.ZERO},
	{"label": "iPhone SE - 750 x 1334", "size": Vector2i(750, 1334)},
	{"label": "iPhone 13/14/15 - 1170 x 2532", "size": Vector2i(1170, 2532)},
	{"label": "iPhone 15 Pro - 1179 x 2556", "size": Vector2i(1179, 2556)},
	{"label": "iPhone 15 Pro Max - 1290 x 2796", "size": Vector2i(1290, 2796)},
	{"label": "iPad mini - 1536 x 2048", "size": Vector2i(1536, 2048)},
	{"label": "iPad Air - 1640 x 2360", "size": Vector2i(1640, 2360)},
	{"label": "iPad Pro 12.9 - 2048 x 2732", "size": Vector2i(2048, 2732)},
]
var refresh_elapsed := 0.0


func setup(owner: Node) -> void:
	host = owner
	_build()
	_refresh_all()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	resized.connect(_layout)


func _process(delta: float) -> void:
	if not visible:
		return
	refresh_elapsed += delta
	if refresh_elapsed >= REFRESH_INTERVAL:
		refresh_elapsed = 0.0
		_refresh_runtime_labels()


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	visible = open
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if open:
		_refresh_all()
		_layout()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	dim = ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.22)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	drawer = PanelContainer.new()
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.10, 0.09, 0.91)
	panel_style.border_color = Color(1.0, 0.82, 0.55, 0.22)
	panel_style.border_width_top = 1
	panel_style.corner_radius_top_left = 28
	panel_style.corner_radius_top_right = 28
	panel_style.content_margin_left = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_right = 22
	panel_style.content_margin_bottom = 18
	drawer.add_theme_stylebox_override("panel", panel_style)
	add_child(drawer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	drawer.add_child(root)
	root.add_child(_header())
	root.add_child(_viewport_row())

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 18)
	root.add_child(tabs)
	tabs.add_child(_tab_levels())
	tabs.add_child(_tab_tray())
	tabs.add_child(_tab_hint())
	tabs.add_child(_tab_state())

	status_label = Label.new()
	status_label.text = "D 打开/关闭"
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.68, 0.76))
	root.add_child(status_label)
	_layout()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 48
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "Dev Test"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#FFF6E6"))
	row.add_child(title)
	row.add_child(_small_button("刷新", _refresh_all))
	row.add_child(_small_button("关闭", func() -> void: set_open(false)))
	return row


func _viewport_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 48
	row.add_theme_constant_override("separation", 12)
	row.add_child(_muted_label("视图预设"))
	viewport_select = OptionButton.new()
	viewport_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_select.add_theme_font_size_override("font_size", 18)
	for preset in viewport_presets:
		viewport_select.add_item(str(preset["label"]))
	viewport_select.item_selected.connect(func(index: int) -> void:
		var preset: Dictionary = viewport_presets[index]
		_call_host("debug_apply_viewport_preset", [preset.get("size", Vector2i.ZERO)])
		_set_status("视图: %s" % str(preset.get("label", "")))
	)
	row.add_child(viewport_select)
	return row


func _tab_levels() -> Control:
	var box := _tab_box("关卡")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	level_select = OptionButton.new()
	level_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_select.add_theme_font_size_override("font_size", 18)
	level_select.item_selected.connect(func(_index: int) -> void:
		_refresh_mode_select()
	)
	row.add_child(level_select)
	mode_select = OptionButton.new()
	mode_select.custom_minimum_size.x = 180
	mode_select.add_theme_font_size_override("font_size", 18)
	row.add_child(mode_select)
	box.add_child(_button_grid([
		{"text": "进入关卡", "action": _enter_selected_level},
		{"text": "重进当前", "action": _restart_current_level},
		{"text": "完成预览", "action": func() -> void: _call_host("debug_preview_complete")},
	]))
	return box


func _tab_tray() -> Control:
	var box := _tab_box("托盘")
	metrics_label = _metric_label()
	box.add_child(metrics_label)
	box.add_child(_button_grid([
		{"text": "重排托盘", "action": func() -> void: _call_host("debug_reset_tray")},
		{"text": "滚到最左", "action": func() -> void: _call_host("debug_scroll_tray_left")},
		{"text": "滚到最右", "action": func() -> void: _call_host("debug_scroll_tray_right")},
		{"text": "显示 Bounds", "action": func() -> void: _call_host("debug_toggle_bounds_overlay")},
	]))
	return box


func _tab_hint() -> Control:
	var box := _tab_box("提示")
	hint_label = _metric_label()
	box.add_child(hint_label)
	box.add_child(_button_grid([
		{"text": "触发提示", "action": func() -> void: _call_host("debug_trigger_hint")},
		{"text": "清除提示", "action": func() -> void: _call_host("debug_clear_hint")},
	]))
	return box


func _tab_state() -> Control:
	var box := _tab_box("状态")
	state_label = _metric_label()
	box.add_child(state_label)
	box.add_child(_button_grid([
		{"text": "运行交互巡检", "action": _run_interaction_smoke},
		{"text": "清当前进度", "action": func() -> void: _call_host("debug_clear_current_progress")},
		{"text": "清全部进度", "action": func() -> void: _call_host("debug_clear_all_progress")},
		{"text": "打印状态", "action": func() -> void: _call_host("debug_dump_state")},
	]))
	return box


func _tab_box(name_value: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = name_value
	box.add_theme_constant_override("separation", 14)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return box


func _button_grid(items: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for item in items:
		grid.add_child(_small_button(str(item["text"]), item["action"]))
	return grid


func _small_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(142, 44)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("#FFF6E6"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.45, 0.18, 0.82)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.94, 0.54, 0.25, 0.92)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(0.74, 0.36, 0.12, 0.98)
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(action)
	return button


func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.68, 0.82))
	return label


func _metric_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("#FFF6E6"))
	return label


func _refresh_all() -> void:
	_refresh_level_select()
	_refresh_runtime_labels()


func _refresh_level_select() -> void:
	if level_select == null:
		return
	level_options = _call_host("debug_level_options", [], [])
	level_select.clear()
	for option in level_options:
		level_select.add_item(str(option.get("label", "")))
	if level_options.is_empty():
		level_select.add_item("暂无可玩关卡")
		level_select.disabled = true
	else:
		level_select.disabled = false
	_refresh_mode_select()


func _refresh_mode_select() -> void:
	if mode_select == null:
		return
	mode_select.clear()
	var option := _selected_level_option()
	var modes: Array = option.get("modes", []) if not option.is_empty() else []
	if modes.is_empty():
		mode_select.add_item("无模式")
		mode_select.disabled = true
		return
	mode_select.disabled = false
	for mode in modes:
		mode_select.add_item(_mode_label(str(mode)))


func _refresh_runtime_labels() -> void:
	var metrics: Dictionary = _call_host("debug_runtime_metrics", [], {})
	if metrics_label != null:
		metrics_label.text = _format_tray_metrics(metrics)
	if hint_label != null:
		hint_label.text = _format_hint_metrics(metrics)
	if state_label != null:
		state_label.text = _format_state_metrics(metrics)


func _format_tray_metrics(metrics: Dictionary) -> String:
	if metrics.is_empty():
		return "当前没有运行中的拼图。"
	var tray: Dictionary = metrics.get("tray", {})
	var sample: Array = tray.get("pieces", [])
	var lines: Array[String] = [
		"托盘高度: %.1f" % float(tray.get("height", 0.0)),
		"可用高度: %.1f" % float(tray.get("usable_height", 0.0)),
		"上下间隙: %.1f" % float(tray.get("vertical_gap", 0.0)),
		"滚动: %.1f / 内容 %.1f" % [float(tray.get("scroll", 0.0)), float(tray.get("content_width", 0.0))],
		"速度: %.1f" % float(tray.get("velocity", 0.0)),
		"托盘碎片: %d" % int(tray.get("count", 0)),
	]
	for piece in sample.slice(0, mini(sample.size(), 5)):
		lines.append("%s  h %.1f  scale %.3f" % [str(piece.get("id", "")), float(piece.get("screen_height", 0.0)), float(piece.get("scale", 0.0))])
	return "\n".join(lines)


func _format_hint_metrics(metrics: Dictionary) -> String:
	if metrics.is_empty():
		return "当前没有运行中的拼图。"
	var hint: Dictionary = metrics.get("hint", {})
	return "\n".join([
		"当前模式: %s" % str(metrics.get("mode", "")),
		"高亮节点: %d" % int(hint.get("nodes", 0)),
		"高亮线条: %d" % int(hint.get("lines", 0)),
		"active key: %s" % str(hint.get("key", "")),
		"点击“触发提示”可直接调用现有 hint 流程。",
	])


func _format_state_metrics(metrics: Dictionary) -> String:
	if metrics.is_empty():
		return "当前没有运行中的拼图。"
	return "\n".join([
		"屏幕: %s" % str(metrics.get("screen", "")),
		"主题: %s" % str(metrics.get("topic", "")),
		"关卡: %s" % str(metrics.get("level", "")),
		"模式: %s" % str(metrics.get("mode", "")),
		"碎片组: %d" % int(metrics.get("groups", 0)),
		"锁定组: %d" % int(metrics.get("locked_groups", 0)),
		"托盘组: %d" % int(metrics.get("tray_groups", 0)),
	])


func _enter_selected_level() -> void:
	var option_index := level_select.selected if level_select != null else -1
	var mode_index := mode_select.selected if mode_select != null else -1
	if option_index < 0 or option_index >= level_options.size():
		_set_status("没有可进入的关卡")
		return
	var modes: Array = level_options[option_index].get("modes", [])
	if mode_index < 0 or mode_index >= modes.size():
		_set_status("没有可进入的模式")
		return
	_call_host("debug_enter_level", [option_index, str(modes[mode_index])])
	_set_status("进入: %s" % str(level_options[option_index].get("label", "")))


func _restart_current_level() -> void:
	_call_host("debug_restart_current_level")
	_set_status("已重进当前关卡")


func _run_interaction_smoke() -> void:
	_set_status("正在运行当前模式巡检...")
	var result: Dictionary = await _call_host("debug_run_current_interaction_smoke", [], {"ok": false})
	_set_status("巡检通过: %s" % str(result.get("mode", "")) if bool(result.get("ok", false)) else "巡检失败: %s" % JSON.stringify(result))
	_refresh_runtime_labels()


func _selected_level_option() -> Dictionary:
	if level_select == null:
		return {}
	var index := level_select.selected
	if index < 0 or index >= level_options.size():
		return {}
	return level_options[index]


func _mode_label(mode: String) -> String:
	if mode == "polygon":
		return "多边形"
	if mode == "knob":
		return "凹凸"
	if mode == "swap":
		return "交换"
	return mode


func _call_host(method: String, args := [], fallback = null):
	if host == null or not is_instance_valid(host) or not host.has_method(method):
		return fallback
	return host.callv(method, args)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _layout() -> void:
	if drawer == null or not is_instance_valid(drawer):
		return
	var height := _panel_height()
	drawer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	drawer.offset_left = 0
	drawer.offset_right = 0
	drawer.offset_top = -height
	drawer.offset_bottom = 0


func _panel_height() -> float:
	return maxf(PANEL_MIN_HEIGHT, get_viewport_rect().size.y * PANEL_HEIGHT_RATIO)
