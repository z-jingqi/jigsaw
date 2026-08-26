class_name ModeStatusIcon
extends ActionButton

signal selection_requested(mode: StringName, start_policy: StringName)

const DONE_TEXTURES := {
	&"polygon": preload("res://assets/icons/status/mode_polygon_done.webp"),
	&"knob": preload("res://assets/icons/status/mode_knob_done.webp"),
	&"swap": preload("res://assets/icons/status/mode_swap_done.webp"),
}
const TODO_TEXTURES := {
	&"polygon": preload("res://assets/icons/status/mode_polygon_todo.webp"),
	&"knob": preload("res://assets/icons/status/mode_knob_todo.webp"),
	&"swap": preload("res://assets/icons/status/mode_swap_todo.webp"),
}
const SHADOW_COLOR := Color(0.384314, 0.14902, 0.054902, 0.2)

@onready var icon_shadow: TextureRect = $IconShadow
@onready var icon_rect: TextureRect = $Icon
@onready var progress_dot: Panel = $ProgressDot
@onready var label: Label = $Label
@onready var selection_paw: TextureRect = $SelectionPaw

var _view_model: Variant
var _variant := &"card"
var _interactive := false
var _selected := false
var _show_progress_dot := true


func _ready() -> void:
	kind = Kind.CARD
	super._ready()
	pressed.connect(_on_pressed)
	_apply_layout()
	if _view_model != null:
		_apply_view_model()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if is_node_ready():
		_apply_view_model()


func set_variant(value: StringName) -> void:
	_variant = value if value in [&"selector", &"focus", &"completion"] else &"card"
	if is_node_ready():
		_apply_layout()
		_apply_view_model()


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	if is_node_ready():
		_apply_interaction_state()


func set_selected(value: bool) -> void:
	_selected = value
	if is_node_ready():
		selection_paw.visible = _variant in [&"selector", &"focus"] and value
		_apply_icon_rect()


func set_show_progress_dot(enabled: bool) -> void:
	_show_progress_dot = enabled
	if is_node_ready():
		_apply_view_model()


func mode() -> StringName:
	return StringName(_read("mode", ""))


func start_policy() -> StringName:
	return StringName(_read("action", "start"))


func action_label() -> String:
	return str(_read("action_label", ""))


func _on_pressed() -> void:
	if disabled or not _interactive:
		return
	selection_requested.emit(mode(), start_policy())


func _apply_view_model() -> void:
	if _view_model == null:
		return
	var mode_name := mode()
	var status := StringName(_read("status", &"unavailable"))
	var completed := status == &"completed"
	icon_rect.texture = (DONE_TEXTURES if completed else TODO_TEXTURES).get(mode_name)
	var icon_opacity := 0.38 if status == &"unavailable" else 1.0
	icon_rect.self_modulate = Color(1.0, 1.0, 1.0, icon_opacity)
	icon_shadow.texture = icon_rect.texture
	icon_shadow.self_modulate = Color(
		SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, SHADOW_COLOR.a * icon_opacity
	)
	icon_shadow.visible = icon_rect.texture != null
	progress_dot.visible = _show_progress_dot and status == &"in_progress"
	label.text = str(_read("short_label", _read("label", "")))
	label.visible = _variant == &"selector"
	selection_paw.visible = _variant in [&"selector", &"focus"] and _selected
	accessibility_name = "%s, %s" % [str(_read("label", "")), _status_text(status)]
	tooltip_text = accessibility_name
	_apply_interaction_state()
	_apply_icon_rect()


func _apply_interaction_state() -> void:
	disabled = not _interactive or not bool(_read("enabled", false))
	mouse_filter = Control.MOUSE_FILTER_STOP if _interactive else Control.MOUSE_FILTER_IGNORE


func _apply_layout() -> void:
	if _variant == &"selector":
		custom_minimum_size = Vector2(248, 304)
		size = custom_minimum_size
		label.position = Vector2(0, 214)
		label.size = Vector2(248, 54)
		label.add_theme_font_size_override("font_size", 42)
		progress_dot.position = Vector2(194, 12)
		progress_dot.size = Vector2(34, 34)
		selection_paw.position = Vector2(98, 270)
		selection_paw.size = Vector2(52, 48)
	elif _variant == &"focus":
		custom_minimum_size = Vector2(210, 224)
		size = custom_minimum_size
		label.visible = false
		progress_dot.position = Vector2(166, 2)
		progress_dot.size = Vector2(32, 32)
		selection_paw.position = Vector2(80, 178)
		selection_paw.size = Vector2(50, 46)
	elif _variant == &"completion":
		custom_minimum_size = Vector2(180, 170)
		size = custom_minimum_size
		label.visible = false
		progress_dot.visible = false
		selection_paw.visible = false
	else:
		custom_minimum_size = Vector2(120, 112)
		size = custom_minimum_size
		label.visible = false
		progress_dot.position = Vector2(91, 3)
		progress_dot.size = Vector2(24, 24)
		selection_paw.visible = false
	pivot_offset = custom_minimum_size * 0.5
	_apply_icon_rect()


func _apply_icon_rect() -> void:
	if not is_instance_valid(icon_rect) or not is_instance_valid(icon_shadow):
		return
	if _variant == &"selector":
		var icon_size := Vector2(212, 212) if _selected else Vector2(188, 188)
		icon_rect.size = icon_size
		icon_rect.position = Vector2((248.0 - icon_size.x) * 0.5, (212.0 - icon_size.y) * 0.5)
		icon_shadow.size = icon_size
		icon_shadow.position = icon_rect.position + Vector2(4, 7)
	elif _variant == &"focus":
		var icon_size := Vector2(176, 176) if _selected else Vector2(160, 160)
		icon_rect.size = icon_size
		icon_rect.position = Vector2((210.0 - icon_size.x) * 0.5, (178.0 - icon_size.y) * 0.5)
		icon_shadow.size = icon_size
		icon_shadow.position = icon_rect.position + Vector2(4, 7)
	elif _variant == &"completion":
		icon_rect.position = Vector2(15, 8)
		icon_rect.size = Vector2(150, 150)
		icon_shadow.position = icon_rect.position + Vector2(4, 7)
		icon_shadow.size = icon_rect.size
	else:
		icon_rect.position = Vector2(13, 4)
		icon_rect.size = Vector2(94, 94)
		icon_shadow.position = icon_rect.position + Vector2(2, 4)
		icon_shadow.size = icon_rect.size


func _read(field: String, fallback: Variant = null) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	return _view_model.get(field) if _view_model != null else fallback


func _status_text(status: StringName) -> String:
	match status:
		&"completed":
			return "Completed"
		&"in_progress":
			return "In progress"
		&"not_started":
			return "Not completed"
		_:
			return "Unavailable"
