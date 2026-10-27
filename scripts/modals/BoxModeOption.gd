extends ActionButton
## Compact mode identity; detailed information belongs to the selected mode only.
signal selection_requested(mode: StringName, start_policy: StringName)
const Glyphs := preload("res://scripts/ui/foundation/ModeCompletionGlyphs.gd")
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
var _model: Variant
var _selected := false
var _icon := TextureRect.new()
var _caption := Label.new()
var _status := Label.new()


func _ready() -> void:
	super._ready()
	for child in [_icon, _caption, _status]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(child)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pressed.connect(func() -> void: selection_requested.emit(mode(), StringName(_model.action)))
	resized.connect(_refresh)
	_refresh()


func set_view_model(model: Variant) -> void:
	_model = model
	if is_node_ready():
		_refresh()


func mode() -> StringName:
	return StringName(_model.mode) if _model != null else &""


func set_selected(selected: bool, _user_change := false) -> void:
	_selected = selected
	_refresh()


func set_layout_origin(_origin: Vector2) -> void:
	pass


func enter_motion(_index: int) -> void:
	pass


func _refresh() -> void:
	if not is_node_ready() or _model == null:
		return
	var u := Metrics.unit(get_viewport_rect().size)
	_icon.texture = Glyphs.COMPLETE[mode()]
	_icon.position = Vector2((size.x - 32 * u) * 0.5, 4 * u)
	_icon.size = Vector2.ONE * 32 * u
	_caption.text = str(_model.short_label)
	_status.text = GameStrings.ui_text(
		{"not_started": "todo", "in_progress": "in_progress", "completed": "done"}.get(
			str(_model.status), "todo"
		)
	)
	for label in [_caption, _status]:
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.position = Vector2(0, 38 * u)
	_caption.size = Vector2(size.x, 26 * u)
	_status.position = Vector2(0, 64 * u)
	_status.size = Vector2(size.x, 22 * u)
	Clean.label(_caption, roundi(Metrics.BODY * u))
	Clean.label(_status, roundi(Metrics.CAPTION * u), true)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := Clean.panel(Clean.SAGE if _selected else Color.TRANSPARENT, 18 * u)
		if state == "focus":
			style.border_color = Clean.MUTED
			style.set_border_width_all(maxi(1, roundi(u)))
		add_theme_stylebox_override(state, style)
	accessibility_name = (
		"%s, %s, %s%s"
		% [
			str(_model.short_label),
			str(_model.status),
			str(_model.action_label),
			", " + GameStrings.ui_text("mode_selected") if _selected else ""
		]
	)
	tooltip_text = ""


func icon_visible_rect() -> Rect2:
	if _icon.texture == null:
		return Rect2(_icon.position, _icon.size)
	var image := _icon.texture.get_image()
	if image == null or image.is_empty():
		return Rect2(_icon.position, _icon.size)
	var used := Rect2(image.get_used_rect())
	var scale := _icon.size / Vector2(image.get_size())
	return Rect2(_icon.position + used.position * scale, used.size * scale).merge(
		_status.get_rect()
	)
