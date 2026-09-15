class_name RuntimeModeSelectModal
extends Control

signal close_requested
signal mode_selected(mode: StringName, start_policy: StringName)

const ModeCard := preload("res://scripts/modals/ModeSelectCard.gd")
const Layout := preload("res://scripts/modals/ModeSelectLayout.gd")
const DebugPreview := preload("res://scripts/modals/ModeSelectPreview.gd")

@onready var background: TextureRect = $Background
@onready var content: Control = $SafeArea/Content
@onready var back_button: Button = $SafeArea/Content/Header/BackButton
@onready var title_label: Label = $SafeArea/Content/Header/Title
@onready var preview: TextureRect = $SafeArea/Content/Preview
@onready var options: Control = $SafeArea/Content/Options
@onready var start_button: ActionButton = $SafeArea/Content/StartButton
@onready var start_label: Label = $SafeArea/Content/StartButton/Label

var _view_model: Variant
var _selected_option: Variant
var _reduced_motion := false
var _launching := false
var _active := true
var _preview_only := false


func _ready() -> void:
	back_button.pressed.connect(request_close)
	start_button.pressed.connect(_on_start_pressed)
	resized.connect(_apply_layout)
	content.resized.connect(_apply_layout)
	_apply_layout()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		var preview_model: Variant = DebugPreview.consume(payload["view_model"])
		_preview_only = preview_model != null
		set_view_model(preview_model if _preview_only else payload["view_model"])
	_active = true
	opening()


func navigation_exit(_context: Dictionary) -> void:
	_active = false
	_launching = false
	for child in options.get_children():
		child.cancel_motion()
	start_button.cancel_motion()


func navigation_set_active(is_active: bool) -> void:
	_active = is_active
	if not is_active:
		navigation_exit({})
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	start_button.set_reduced_motion(enabled)
	for child in options.get_children():
		child.set_reduced_motion(enabled)


func set_view_model(view_model: Variant) -> void:
	_launching = false
	_view_model = view_model
	if not is_node_ready():
		return
	preview.texture = _read("preview_texture") as Texture2D
	title_label.text = str(_read("level_title", ""))
	_reconcile_options()
	_apply_layout()


func opening() -> void:
	for index in options.get_child_count():
		options.get_child(index).enter_motion(index)


func request_close() -> void:
	navigation_exit({})
	close_requested.emit()


func active_motion_count() -> int:
	var count := start_button.active_motion_count()
	for child in options.get_children():
		count += child.active_motion_count()
	return count


func _reconcile_options() -> void:
	for child in options.get_children():
		child.cancel_motion()
		options.remove_child(child)
		child.queue_free()
	var available: Array = []
	for option_model in _read("options", []):
		if not bool(_read_from(option_model, "enabled", false)):
			continue
		var option := ModeCard.new()
		options.add_child(option)
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
	if _launching or not _active:
		return
	if StringName(_read_from(_selected_option, "mode", &"")) == mode:
		return
	for option_model in _read("options", []):
		if StringName(_read_from(option_model, "mode", &"")) == mode:
			_selected_option = option_model
			break
	_refresh_selection(true)


func _refresh_selection(user_change := false) -> void:
	var selected_mode := StringName(_read_from(_selected_option, "mode", &""))
	for child in options.get_children():
		child.set_selected(child.mode() == selected_mode, user_change)
	start_button.disabled = selected_mode.is_empty() or _preview_only
	var action_text := str(_read_from(_selected_option, "action_label", ""))
	start_label.text = (
		"开始拼图"
		if StringName(_read_from(_selected_option, "action", &"start")) == &"start"
		else action_text
	)
	start_button.accessibility_name = start_label.text
	if _preview_only:
		start_label.text = "临时预览 · 返回退出"
		start_button.accessibility_name = start_label.text


func _on_start_pressed() -> void:
	if _selected_option == null or start_button.disabled or _launching or not _active:
		return
	_launching = true
	start_button.disabled = true
	var mode := StringName(_read_from(_selected_option, "mode", &""))
	var policy := StringName(_read_from(_selected_option, "action", &"start"))
	for child in options.get_children():
		child.cancel_motion()
		if child.mode() == mode:
			child.launch_motion(_finish_start.bind(mode, policy))


func _finish_start(mode: StringName, policy: StringName) -> void:
	if not _launching or not _active:
		return
	_launching = false
	mode_selected.emit(mode, policy)


func _apply_layout() -> void:
	if is_node_ready() and content.size.x > 0 and content.size.y > 0:
		Layout.apply(self)
		if _preview_only:
			start_label.add_theme_font_size_override("font_size", int(start_button.size.y * 0.3))


func _read(field: String, fallback: Variant = null) -> Variant:
	return _read_from(_view_model, field, fallback)


func _read_from(source: Variant, field: String, fallback: Variant) -> Variant:
	if source is Dictionary:
		return source.get(field, fallback)
	if source == null:
		return fallback
	return source.get(field)
