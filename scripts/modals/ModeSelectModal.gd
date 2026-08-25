class_name RuntimeModeSelectModal
extends Control

signal close_requested
signal mode_selected(mode: StringName, start_policy: StringName)

const ModeStatusIconScene := preload("res://scenes/ui/foundation/ModeStatusIcon.tscn")

@onready var background: TextureRect = $Background
@onready var content: Control = $SafeArea/Content
@onready var back_button: Button = $SafeArea/Content/Header/BackButton
@onready var title_label: Label = $SafeArea/Content/Header/Title
@onready var preview: TextureRect = $SafeArea/Content/Preview
@onready var options: HBoxContainer = $SafeArea/Content/Options
@onready var start_button: ActionButton = $SafeArea/Content/StartButton
@onready var start_label: Label = $SafeArea/Content/StartButton/Label

var _view_model: Variant
var _selected_option: Variant
var _reduced_motion := false


func _ready() -> void:
	back_button.pressed.connect(request_close)
	start_button.pressed.connect(_on_start_pressed)
	resized.connect(_apply_layout)
	content.resized.connect(_apply_layout)
	_apply_layout()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		set_view_model(payload["view_model"])


func navigation_exit(_context: Dictionary) -> void:
	for child in options.get_children():
		child.cancel_motion()
	start_button.cancel_motion()


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	start_button.set_reduced_motion(enabled)
	for child in options.get_children():
		child.set_reduced_motion(enabled)


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if not is_node_ready():
		return
	background.texture = _read("background_texture") as Texture2D
	preview.texture = _read("preview_texture") as Texture2D
	title_label.text = str(_read("level_title", ""))
	_reconcile_options()
	_apply_layout()


func opening() -> void:
	pass


func request_close() -> void:
	close_requested.emit()


func active_motion_count() -> int:
	var count := start_button.active_motion_count()
	for child in options.get_children():
		count += child.active_motion_count()
	return count


func _reconcile_options() -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var available: Array = []
	for option_model in _read("options", []):
		if not bool(_read_from(option_model, "enabled", false)):
			continue
		var option := ModeStatusIconScene.instantiate() as ModeStatusIcon
		options.add_child(option)
		option.set_variant(&"selector")
		option.set_interactive(true)
		option.set_reduced_motion(_reduced_motion)
		option.set_view_model(option_model)
		option.selection_requested.connect(_on_option_selected)
		available.append(option_model)
	_selected_option = _default_option(available)
	_refresh_selection()


func _default_option(available: Array) -> Variant:
	for status in [&"in_progress", &"not_started", &"completed"]:
		for option_model in available:
			if StringName(_read_from(option_model, "status", &"")) == status:
				return option_model
	return null


func _on_option_selected(mode: StringName, _policy: StringName) -> void:
	for option_model in _read("options", []):
		if StringName(_read_from(option_model, "mode", &"")) == mode:
			_selected_option = option_model
			break
	_refresh_selection()


func _refresh_selection() -> void:
	var selected_mode := StringName(_read_from(_selected_option, "mode", &""))
	for child in options.get_children():
		child.set_selected(child.mode() == selected_mode)
	start_button.disabled = selected_mode.is_empty()
	var action_text := str(_read_from(_selected_option, "action_label", ""))
	start_label.text = action_text if not action_text.is_empty() else "开始拼图"


func _on_start_pressed() -> void:
	if _selected_option == null or start_button.disabled:
		return
	mode_selected.emit(
		StringName(_read_from(_selected_option, "mode", &"")),
		StringName(_read_from(_selected_option, "action", &"start"))
	)


func _apply_layout() -> void:
	if not is_node_ready() or content.size.x <= 0.0 or content.size.y <= 0.0:
		return
	var available := content.size
	$SafeArea/Content/Header.size = Vector2(available.x, 180.0)
	back_button.position = Vector2(8.0, 16.0)
	back_button.size = Vector2(116.0, 116.0)
	title_label.offset_left = 150.0
	title_label.offset_top = 8.0
	title_label.offset_right = -150.0
	title_label.offset_bottom = 140.0
	var top := 300.0
	var preview_width := minf(1040.0, available.x - 24.0)
	var preview_height := preview_width
	preview.size = Vector2(preview_width, preview_height)
	preview.position = Vector2((available.x - preview_width) * 0.5, top)
	var options_width := minf(900.0, available.x - 80.0)
	options.size = Vector2(options_width, 316.0)
	options.position = Vector2(
		(available.x - options_width) * 0.5, preview.position.y + preview_height + 72.0
	)
	var button_width := minf(760.0, available.x - 240.0)
	start_button.size = Vector2(button_width, 184.0)
	start_button.position = Vector2(
		(available.x - button_width) * 0.5,
		minf(available.y - 232.0, options.position.y + options.size.y + 450.0)
	)
	var shader_material := preview.material as ShaderMaterial
	if shader_material != null and preview_height > 0.0:
		shader_material.set_shader_parameter("rect_aspect", 1.0)
		shader_material.set_shader_parameter("rect_size", preview.size)


func _read(field: String, fallback: Variant = null) -> Variant:
	return _read_from(_view_model, field, fallback)


func _read_from(source: Variant, field: String, fallback: Variant) -> Variant:
	if source is Dictionary:
		return source.get(field, fallback)
	if source == null:
		return fallback
	return source.get(field)
