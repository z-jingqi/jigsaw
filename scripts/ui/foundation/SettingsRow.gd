class_name SettingsRow
extends HBoxContainer

signal value_changed(key: StringName, enabled: bool)

@export var setting_key := StringName()
@export var show_divider := true
@onready var glyph: SettingsGlyph = $Glyph
@onready var label: Label = $Label
@onready var toggle: Button = $Toggle

var _toggle_tween: Tween
var _thumb: Panel
var _reduced_motion := false


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func configure(key: StringName, label_text: String, enabled: bool, animate := false) -> void:
	setting_key = key
	label.text = label_text
	glyph.set_kind(_glyph_kind_for_key(key))
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


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		_stop_toggle_motion()
		_move_thumb(toggle.button_pressed, false)


func set_divider_visible(visible: bool) -> void:
	show_divider = visible
	queue_redraw()


func active_motion_count() -> int:
	return (
		1
		if _toggle_tween != null and _toggle_tween.is_valid() and _toggle_tween.is_running()
		else 0
	)


func _ensure_thumb() -> void:
	if is_instance_valid(_thumb):
		return
	_thumb = Panel.new()
	_thumb.name = "Thumb"
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thumb.size = Vector2(64, 64)
	_thumb.custom_minimum_size = Vector2(64, 64)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("F3E5CE")
	style.corner_radius_top_left = 32
	style.corner_radius_top_right = 32
	style.corner_radius_bottom_left = 32
	style.corner_radius_bottom_right = 32
	style.corner_detail = 16
	style.anti_aliasing = true
	style.shadow_color = Color(0.30, 0.14, 0.06, 0.22)
	style.shadow_size = 5
	style.shadow_offset = Vector2(2, 4)
	_thumb.add_theme_stylebox_override("panel", style)
	toggle.add_child(_thumb)


func _apply_toggle_style(enabled: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("D35929") if enabled else Color("D9C5A2")
	style.corner_radius_top_left = 43
	style.corner_radius_top_right = 43
	style.corner_radius_bottom_left = 43
	style.corner_radius_bottom_right = 43
	style.corner_detail = 16
	style.anti_aliasing = true
	style.shadow_color = Color(0.30, 0.14, 0.06, 0.16)
	style.shadow_size = 5
	style.shadow_offset = Vector2(2, 4)
	toggle.add_theme_stylebox_override("normal", style)
	toggle.add_theme_stylebox_override("pressed", style.duplicate())
	toggle.add_theme_stylebox_override("focus", style.duplicate())
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.04)
	toggle.add_theme_stylebox_override("hover", hover)


func _move_thumb(enabled: bool, animate: bool) -> void:
	if not is_instance_valid(_thumb):
		return
	var target := Vector2(82, 11) if enabled else Vector2(10, 11)
	_stop_toggle_motion()
	if not animate or _reduced_motion:
		_thumb.position = target
		return
	_toggle_tween = create_tween()
	_toggle_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toggle_tween.tween_property(_thumb, "position", target, 0.18)
	_toggle_tween.finished.connect(_stop_toggle_motion, CONNECT_ONE_SHOT)


func _stop_toggle_motion() -> void:
	if _toggle_tween != null and _toggle_tween.is_valid():
		_toggle_tween.kill()
	_toggle_tween = null


func _glyph_kind_for_key(key: StringName) -> StringName:
	match key:
		&"music_enabled":
			return &"music"
		&"sound_effects_enabled":
			return &"sound"
		&"haptics_enabled":
			return &"haptics"
		&"reduced_motion_enabled":
			return &"reduced_motion"
	return &"music"


func _draw() -> void:
	if not show_divider or size.x <= 0.0:
		return
	var y := size.y - 1.0
	draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.55, 0.36, 0.20, 0.18), 2.0)


func _exit_tree() -> void:
	_stop_toggle_motion()
