class_name AlbumScreen
extends Control
## The album's only collection screen: one unlocked artwork and a bounded filmstrip.
signal back_requested
signal theme_selected(theme_id: String)
signal artwork_selected(theme_id: String, level_id: String)
signal index_selected(index: int)
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")
const FreshButton := preload("res://scripts/screens/home/FreshButton.gd")
const ThemeButton := preload("res://scripts/screens/album/AlbumThemeButton.gd")
const FocusPager := preload("res://scripts/screens/album/AlbumFocusPager.gd")
const ThumbnailStrip := preload("res://scripts/screens/album/AlbumThumbnailStrip.gd")
const Chooser := preload("res://scripts/screens/album/AlbumThemeChooser.gd")
var _model: Dictionary = {}
var _loader: Node
var _active := true
var _reduced := false
var _back: Button
var _theme: Button
var _title: Label
var _position: Label
var _focus: Control
var _strip: Control
var _chooser: Control


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Clean.PAPER
	background.mouse_filter = MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_focus = FocusPager.new()
	_focus.name = "FocusPager"
	add_child(_focus)
	_strip = ThumbnailStrip.new()
	_strip.name = "ThumbnailStrip"
	add_child(_strip)
	_focus.selected.connect(_selected.bind(false))
	_strip.selected.connect(_selected.bind(true))
	_focus.activated.connect(_open_artwork)
	_back = FreshButton.new()
	_back.name = "BackButton"
	_back.symbol = "back"
	_back.icon_only = true
	add_child(_back)
	_back.pressed.connect(request_back)
	_theme = ThemeButton.new()
	_theme.name = "ThemeButton"
	Clean.icon_button(_theme)
	add_child(_theme)
	_theme.pressed.connect(_show_chooser)
	_title = _label("ArtworkTitle")
	_position = _label("Position")
	_position.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chooser = Chooser.new()
	_chooser.name = "ThemeChooser"
	add_child(_chooser)
	_chooser.theme_selected.connect(theme_selected.emit)
	resized.connect(_layout)


func _label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	return label


func set_image_loader(loader: Node) -> void:
	_loader = loader
	_focus.set_loader(loader)
	_strip.set_loader(loader)
	_chooser.configure(_model.get("themes", []), loader, _reduced, str(_model.get("theme_id", "")))


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_reduced = bool(context.get("reduced_motion", false))
	render(payload.get("view_model", {}))


func render(model: Dictionary, _legacy_position := 0) -> void:
	var changed: bool = (
		str(_model.get("theme_id", "")) != str(model.get("theme_id", ""))
		or _model.get("artworks", []) != model.get("artworks", [])
	)
	_model = model
	var items: Array = model.get("artworks", [])
	var index := clampi(int(model.get("index", 0)), 0, maxi(0, items.size() - 1))
	if changed or _focus.items.is_empty():
		_focus.configure(items, index)
		_strip.configure(items, index)
	elif _focus.current != index:
		_focus.request(index, false)
		_strip.request(index, false)
	_focus.set_reduced_motion(_reduced)
	_strip.set_reduced_motion(_reduced)
	_back.accessibility_name = str(model.get("back_label", GameStrings.ui_text("back")))
	_theme.caption = str(model.get("theme_title", ""))
	_theme.accessibility_name = str(model.get("theme_title", ""))
	var has_art := not items.is_empty()
	for control in [_theme, _title, _position, _focus, _strip]:
		control.visible = has_art
	_chooser.configure(model.get("themes", []), _loader, _reduced, str(model.get("theme_id", "")))
	_update_caption(index)
	_layout()


func _selected(index: int, from_strip: bool) -> void:
	_model.index = index
	if from_strip:
		_focus.request(index, false)
	else:
		_strip.request(index, false)
	_update_caption(index)
	index_selected.emit(index)


func _update_caption(index: int) -> void:
	var items: Array = _model.get("artworks", [])
	_title.text = str(items[index].get("title", "")) if index < items.size() else ""
	_position.text = "%d / %d" % [index + 1, items.size()]


func _open_artwork(index: int) -> void:
	var items: Array = _model.get("artworks", [])
	if index >= 0 and index < items.size():
		artwork_selected.emit(
			str(items[index].get("theme_id", _model.get("theme_id", ""))),
			str(items[index].get("level_id", ""))
		)


func _show_chooser() -> void:
	_focus.set_enabled(false)
	_strip.set_enabled(false)
	_chooser.show_sheet()
	set_process(true)


func _process(_delta: float) -> void:
	if _active and not _chooser.is_presented() and not _focus.enabled:
		_focus.set_enabled(true)
		_strip.set_enabled(true)
		set_process(false)


func dismiss_menu() -> bool:
	if _chooser.is_presented():
		_chooser.close()
		return true
	return false


func edge_back_allowed() -> bool:
	return not _chooser.is_presented()


func request_back() -> void:
	if not dismiss_menu():
		back_requested.emit()


func navigation_set_active(value: bool) -> void:
	_active = value
	visible = value
	_focus.set_enabled(value and not _chooser.is_presented())
	_strip.set_enabled(value and not _chooser.is_presented())


func navigation_prepare_transition() -> void:
	_focus.set_enabled(false)
	_strip.set_enabled(false)


func navigation_exit(_context: Dictionary) -> void:
	navigation_prepare_transition()


func set_reduced_motion(value: bool) -> void:
	_reduced = value
	_focus.set_reduced_motion(value)
	_strip.set_reduced_motion(value)
	_chooser.configure(_model.get("themes", []), _loader, value, str(_model.get("theme_id", "")))


func scroll_position() -> int:
	return int(_model.get("index", 0))


func active_motion_count() -> int:
	return (
		_focus.active_motion_count() + _strip.active_motion_count() + _chooser.active_motion_count()
	)


func debug_state_snapshot() -> Dictionary:
	return {
		"kind": "focus",
		"theme_id": _model.get("theme_id", ""),
		"index": _model.get("index", 0),
		"total": _model.get("artworks", []).size(),
		"chooser": _chooser.is_presented(),
		"focus": _focus.debug_state_snapshot(),
		"thumbnails": _strip.debug_state_snapshot(),
		"active_motion_count": active_motion_count()
	}


func _layout() -> void:
	if not is_node_ready():
		return
	var native := Metrics.unit(size)
	var u := Metrics.unit(size)
	var safe := Clean.safe_insets(size)
	var margin := Metrics.EDGE * u
	Buttons.place_navigation(_back, self)
	_theme.position = Vector2(_back.position.x + _back.size.x + 8 * u, _back.position.y)
	_theme.size = Vector2(size.x - safe.z - margin - _theme.position.x, _back.size.y)
	_theme.configure(str(_model.get("theme_title", "")), roundi(Metrics.TITLE * native), native)
	var strip_h := minf(116 * u, 104 * native)
	_strip.position = Vector2(margin, size.y - safe.w - 24 * u - strip_h)
	_strip.size = Vector2(size.x - 2 * margin, strip_h)
	var caption_h := 36 * native
	_title.position = Vector2(margin, _strip.position.y - caption_h - 12 * u)
	_title.size = Vector2((size.x - 2 * margin) * 0.73, caption_h)
	_position.position = Vector2(_title.position.x + _title.size.x, _title.position.y)
	_position.size = Vector2((size.x - 2 * margin) * 0.27, caption_h)
	Clean.label(_title, roundi(Metrics.BODY * native))
	preload("res://scripts/screens/home/ThemeTitleLayout.gd").fit(
		_title, _title.size, roundi(Metrics.BODY * u), 2
	)
	Clean.label(_position, roundi(Metrics.CAPTION * native), true)
	var top := _back.position.y + _back.size.y + 24 * u
	_focus.position = Vector2(margin, top)
	_focus.size = Vector2(size.x - 2 * margin, maxf(1, _title.position.y - top - 12 * u))
	_chooser.position = Vector2.ZERO
	_chooser.size = size


func gesture_pause_motion() -> void:
	_focus.gesture_pause_motion()
	_strip.gesture_pause_motion()


func gesture_resume_motion() -> void:
	_focus.gesture_resume_motion()
	_strip.gesture_resume_motion()


func prepare_return(index: int) -> void:
	_model.index = index
	_update_caption(index)
	_focus.prepare_cached(index)
	_strip.prepare_cached(index)
