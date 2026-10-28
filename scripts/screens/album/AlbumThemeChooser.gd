extends Control
## Local, reversible popup. It does not add a route or an all-artworks collection.
signal theme_selected(theme_id: String)
const LibraryScene := preload("res://scenes/screens/home/ThemeLibraryScreen.tscn")
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
var _sheet: Control
var _shade: ColorRect
var _motion: Tween
var _open := false
var _reduced := false
var _themes: Array = []
var _selected_theme := ""
var _loader: Node
var _generation := 0
var _pending_outside := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.24)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = MOUSE_FILTER_STOP
	_shade.gui_input.connect(_outside)
	add_child(_shade)
	_sheet = LibraryScene.instantiate()
	_sheet.close_as_sheet = true
	_sheet.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_sheet)
	_sheet.resized.connect(_layout_header)
	_sheet.close_requested.connect(close)
	_sheet.theme_selected.connect(
		func(id: String) -> void:
			theme_selected.emit(id)
			close()
	)
	resized.connect(_layout)
	visible = false
	_layout()


func configure(themes: Array, loader: Node, reduced: bool, current_theme := "") -> void:
	_themes = themes
	_selected_theme = current_theme
	_loader = loader
	_reduced = reduced
	if _reduced and visible:
		if _motion != null and _motion.is_valid():
			_motion.kill()
		modulate.a = 1.0 if _open else 0.0
		_finish()


func show_sheet() -> void:
	if not is_node_ready():
		return
	if not visible:
		_generation += 1
		var models: Array = []
		for theme in _themes:
			models.append(
				{
					"theme_id": str(theme.get("theme_id", theme.get("id", ""))),
					"title": str(theme.get("title", "")),
					"playable": true,
					"cover_texture": null
				}
			)
		_sheet.navigation_enter(
			{"view_model": {"themes": models}, "scroll_position": 0}, {"reduced_motion": _reduced}
		)
		_sheet.get_node("Title").text = GameStrings.ui_text("album_choose_theme")
		_sheet.get_node("CloseButton").accessibility_name = GameStrings.ui_text("close")
		_layout()
		modulate.a = 0.0
		visible = true
		for index in _themes.size():
			var theme: Dictionary = _themes[index]
			var path := str(theme.get("thumbnail_path", ""))
			if is_instance_valid(_loader):
				_loader.watch(
					self, str(index), path, _cover_ready.bind(index, _generation), "thumb", 10
				)
	_sheet.navigation_set_active(true)
	_open = true
	_animate(1.0)


func close() -> void:
	if not visible:
		return
	_open = false
	_animate(0.0)


func is_presented() -> bool:
	return visible


func _cover_ready(_path: String, texture: Texture2D, index: int, generation: int) -> void:
	if generation != _generation or not visible:
		return
	var pages := _sheet.get_node("Pages")
	var page_index := index / 4
	if page_index >= pages.get_child_count():
		return
	var page := pages.get_child(page_index)
	if index % 4 >= page.get_child_count():
		return
	page.get_child(index % 4).get_node("Cover").texture = texture
	_sheet._layout()
	_layout_header()


func _animate(target: float) -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	if _reduced:
		modulate.a = target
		_finish()
		return
	_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, "modulate:a", target, 0.18)
	_motion.finished.connect(_finish)


func _finish() -> void:
	_motion = null
	if not _open:
		visible = false
		_sheet.navigation_set_active(false)
		for page in _sheet.get_node("Pages").get_children():
			for card in page.get_children():
				card.get_node("Cover").texture = null
		if is_instance_valid(_loader):
			_loader.unwatch_owner(self)


func _outside(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pending_outside = true
		elif _pending_outside:
			_pending_outside = false
			close()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pending_outside = true
		elif _pending_outside:
			_pending_outside = false
			close()
		accept_event()


func _layout() -> void:
	if _sheet == null:
		return
	_sheet.size = Vector2(size.x, size.y * 0.79)
	_sheet.position.y = (size.y - _sheet.size.y) * 0.5
	_layout_header()


func active_motion_count() -> int:
	return (
		int(_motion != null and _motion.is_valid() and _motion.is_running())
		+ (_sheet.active_motion_count() if visible else 0)
	)


func _exit_tree() -> void:
	if is_instance_valid(_loader):
		_loader.unwatch_owner(self)


func _layout_header() -> void:
	if not is_instance_valid(_sheet) or not _sheet.is_node_ready():
		return
	var native := Metrics.unit(get_viewport_rect().size)
	var button := _sheet.get_node("CloseButton") as Button
	button.position = Vector2(Metrics.EDGE, Metrics.TOP) * native
	Buttons.apply_size(button, Vector2.ONE * Metrics.TOUCH * native)
	var title := _sheet.get_node("Title") as Label
	title.position = Vector2(Metrics.EDGE + Metrics.TOUCH + Metrics.SMALL_GAP, Metrics.TOP) * native
	title.size = Vector2(_sheet.size.x - 140 * native, Metrics.TOUCH * native)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Clean.label(title, roundi(Metrics.TITLE * native))

	var pages := _sheet.get_node("Pages")
	for page_index in pages.get_child_count():
		var page := pages.get_child(page_index)
		for item_index in page.get_child_count():
			var card := page.get_child(item_index) as Control
			var mark := card.get_node_or_null("CurrentTheme") as ColorRect
			if mark == null:
				mark = ColorRect.new()
				mark.name = "CurrentTheme"
				mark.color = Clean.INK
				mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(mark)
			var index := page_index * 4 + item_index
			mark.visible = (
				index < _themes.size()
				and str(_themes[index].get("theme_id", "")) == _selected_theme
			)
			var label := card.get_node("Title") as Label
			mark.position = Vector2(
				card.size.x * 0.5 - 22 * native, label.position.y + label.size.y
			)
			mark.size = Vector2(44, 2) * native
