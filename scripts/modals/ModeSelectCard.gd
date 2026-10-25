extends ActionButton
## Mode identity, saved play state, and selection are independent.

signal selection_requested(mode: StringName, start_policy: StringName)

const ICONS := {
	&"polygon": preload("res://assets/ui/levels/mode-icons/polygon.svg"),
	&"knob": preload("res://assets/ui/levels/mode-icons/knob.svg"),
	&"swap": preload("res://assets/ui/levels/mode-icons/swap.svg"),
}
const IconShader := preload("res://shaders/ui/mode_icon_state.gdshader")
const MotionScene := preload("res://scenes/modals/ModeSelectMotion.tscn")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const FONT := preload("res://assets/fonts/noto/NotoSansSC[wght].ttf")
const INK := Clean.INK

var _model: Variant
var _selected := false
var _name_label := Label.new()
var _status_label := Label.new()
var _motion: Node
var _icon := TextureRect.new()
var _icon_material := ShaderMaterial.new()


func _ready() -> void:
	kind = Kind.CARD
	add_theme_font_override("font", FONT)
	super._ready()
	_motion = MotionScene.instantiate()
	add_child(_motion)
	_motion.bind(self)
	_icon_material.shader = IconShader
	_icon.material = _icon_material
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)
	_motion.bind_icon(_icon)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for label in [_name_label, _status_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", FONT)
		add_child(label)
	_name_label.add_theme_color_override("font_color", INK)
	_status_label.add_theme_color_override("font_color", Clean.MUTED)
	pressed.connect(func(): selection_requested.emit(mode(), StringName(_read("action", &"start"))))
	resized.connect(_layout)
	_refresh()


func set_view_model(model: Variant) -> void:
	_model = model
	if is_node_ready():
		_refresh()


func mode() -> StringName:
	return StringName(_read("mode", &""))


func enter_motion(index: int) -> void:
	cancel_motion()
	_motion.enter(index)


func set_layout_origin(origin: Vector2) -> void:
	_motion.set_origin(origin)


func launch_motion(completion: Callable) -> void:
	cancel_motion()
	_motion.launch(completion)


func set_reduced_motion(enabled: bool) -> void:
	super.set_reduced_motion(enabled)
	if is_instance_valid(_motion):
		_motion.set_reduced_motion(enabled)


func cancel_motion() -> void:
	super.cancel_motion()
	if is_instance_valid(_motion):
		_motion.cancel()


func active_motion_count() -> int:
	return (
		super.active_motion_count() + (_motion.active_count() if is_instance_valid(_motion) else 0)
	)


func set_selected(selected: bool, user_change := false) -> void:
	var changed := selected != _selected
	_selected = selected
	if is_node_ready():
		if not selected:
			_motion.cancel_selection()
		elif changed and user_change:
			_motion.select()
		_refresh()


func presentation_snapshot() -> Dictionary:
	return {
		"mode": mode(),
		"status": _read("status", &"not_started"),
		"selected": _selected,
		"action": _read("action", &"start"),
		"badge": false,
		"label": _status_label.text,
		"rect": str(get_global_rect()),
		"reveal": _motion.reveal,
		"active_motion_count": active_motion_count(),
		"scale": str(scale),
		"background": (get_theme_stylebox("normal") as StyleBoxFlat).bg_color.to_html(),
		"status_color": _status_label.get_theme_color("font_color").to_html(),
		"muted_icon": _icon_material.get_shader_parameter("not_started"),
		"lift": _motion.lift,
		"icon_alpha": _icon.modulate.a,
		"icon_scale": _icon.scale.x,
	}


func _refresh() -> void:
	_name_label.text = str(_read("short_label", _read("label", "")))
	var status := StringName(_read("status", &"not_started"))
	_icon.texture = ICONS.get(mode())
	_icon_material.set_shader_parameter("not_started", status == &"not_started")
	(
		_status_label
		. add_theme_color_override(
			"font_color",
			(
				{
					&"not_started": Clean.MUTED,
					&"in_progress": Color("86613D"),
					&"completed": Color("526447"),
				}
				. get(status, Clean.MUTED)
			)
		)
	)
	_status_label.text = (
		{
			&"not_started": "未开始",
			&"in_progress": "进行中",
			&"completed": "已完成",
		}
		. get(status, "不可用")
	)
	disabled = not bool(_read("enabled", false))
	accessibility_name = (
		"%s，%s%s" % [_name_label.text, _status_label.text, "，已选中" if _selected else ""]
	)
	tooltip_text = accessibility_name
	_layout()


func _layout() -> void:
	var unit := size.x / 112.0
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (
			{&"polygon": Clean.SAGE, &"knob": Clean.APRICOT, &"swap": Clean.LAVENDER}
			. get(mode(), Clean.SAGE)
		)
		style.border_color = INK if _selected or state == "focus" else Color.TRANSPARENT
		style.set_border_width_all(maxi(2, int(2.0 * unit)) if _selected or state == "focus" else 0)
		style.set_corner_radius_all(int(20.0 * unit))
		add_theme_stylebox_override(state, style)
	_name_label.position = Vector2(0, size.y * 0.61)
	_name_label.size = Vector2(size.x, size.y * 0.16)
	_status_label.position = Vector2(0, size.y * 0.81)
	_status_label.size = Vector2(size.x, size.y * 0.13)
	_name_label.add_theme_font_size_override("font_size", maxi(12, int(16.0 * unit)))
	_status_label.add_theme_font_size_override("font_size", maxi(12, int(12.0 * unit)))
	pivot_offset = size * 0.5
	var icon_size := minf(size.x * 0.56, size.y * 0.44)
	_icon.position = Vector2((size.x - icon_size) * 0.5, size.y * 0.15)
	_icon.size = Vector2.ONE * icon_size
	_icon.pivot_offset = _icon.size * 0.5


func _read(field: String, fallback: Variant) -> Variant:
	if _model is Dictionary:
		return _model.get(field, fallback)
	return _model.get(field) if _model != null else fallback
