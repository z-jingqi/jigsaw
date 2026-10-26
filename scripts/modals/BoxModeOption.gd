extends ActionButton
## Compact mode identity; detailed information belongs to the selected mode only.
signal selection_requested(mode: StringName, start_policy: StringName)
const Glyphs := preload("res://scripts/ui/foundation/ModeCompletionGlyphs.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
var _model: Variant
var _selected := false
var _icon := TextureRect.new()


func _ready() -> void:
	super._ready()
	for child in [_icon]:
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
	var u := Clean.minimum_touch_size(self).y / 44.0
	_icon.texture = Glyphs.COMPLETE[mode()]
	_icon.position = (size - Vector2.ONE * 38 * u) * 0.5
	_icon.size = Vector2.ONE * 38 * u
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
