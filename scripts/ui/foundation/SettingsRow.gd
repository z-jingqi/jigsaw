class_name SettingsRow
extends HBoxContainer

signal value_changed(key: StringName, enabled: bool)

@export var setting_key := StringName()
@onready var label: Label = $Label
@onready var toggle: Button = $Toggle

var _toggle_tween: Tween
var _thumb: Panel

func configure(key: StringName, label_text: String, enabled: bool, animate := false) -> void:
	setting_key = key
	label.text = label_text
	toggle.set_pressed_no_signal(enabled)
	toggle.tooltip_text = label_text
	toggle.accessibility_name = label_text
	_ensure_thumb()
	_apply_toggle_style(enabled)
	if animate:
		_move_thumb(enabled, true)
	else:
		_move_thumb(enabled, false)


func _on_toggle_toggled(enabled: bool) -> void:
	_apply_toggle_style(enabled)
	_move_thumb(enabled, true)
	value_changed.emit(setting_key, enabled)


func set_interaction_enabled(enabled: bool) -> void:
	toggle.disabled = not enabled


func _ensure_thumb() -> void:
	if is_instance_valid(_thumb):
		return
	_thumb = Panel.new()
	_thumb.name = "Thumb"
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thumb.size = Vector2(46, 46)
	_thumb.custom_minimum_size = Vector2(46, 46)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("FFFDF8")
	style.corner_radius_top_left = 23
	style.corner_radius_top_right = 23
	style.corner_radius_bottom_left = 23
	style.corner_radius_bottom_right = 23
	style.shadow_color = Color(0.24, 0.14, 0.07, 0.22)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	_thumb.add_theme_stylebox_override("panel", style)
	toggle.add_child(_thumb)


func _apply_toggle_style(enabled: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("6F9D67") if enabled else Color("D8CDBB")
	style.border_color = Color(0.35, 0.23, 0.13, 0.12)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 31
	style.corner_radius_top_right = 31
	style.corner_radius_bottom_left = 31
	style.corner_radius_bottom_right = 31
	toggle.add_theme_stylebox_override("normal", style)
	toggle.add_theme_stylebox_override("pressed", style.duplicate())
	toggle.add_theme_stylebox_override("focus", style.duplicate())
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.04)
	toggle.add_theme_stylebox_override("hover", hover)


func _move_thumb(enabled: bool, animate: bool) -> void:
	if not is_instance_valid(_thumb):
		return
	var target := Vector2(58, 8) if enabled else Vector2(8, 8)
	if _toggle_tween != null and _toggle_tween.is_valid():
		_toggle_tween.kill()
	if not animate:
		_thumb.position = target
		return
	_toggle_tween = create_tween()
	_toggle_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toggle_tween.tween_property(_thumb, "position", target, 0.16)
