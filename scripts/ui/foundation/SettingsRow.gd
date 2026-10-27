class_name SettingsRow
extends HBoxContainer

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")

signal value_changed(key: StringName, enabled: bool)

@export var setting_key := StringName()
@export var show_divider := true
@onready var glyph: SettingsGlyph = $Glyph
@onready var label: Label = $Label
@onready var toggle: Button = $Toggle

var _toggle_tween: Tween
var _thumb: Panel
var _reduced_motion := false
var _unit := 1.0


func _ready() -> void:
	resized.connect(queue_redraw)
	toggle.resized.connect(_refresh_toggle_geometry)
	queue_redraw()


func configure(key: StringName, label_text: String, enabled: bool, animate := false) -> void:
	setting_key = key
	label.text = label_text
	glyph.set_kind(_glyph_kind_for_key(key))
	toggle.set_pressed_no_signal(enabled)
	toggle.tooltip_text = ""
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


func set_visual_scale(unit: float) -> void:
	_unit = unit
	custom_minimum_size.y = maxf(66 * unit, Clean.minimum_touch_size(toggle).y + 12 * unit)
	glyph.custom_minimum_size = Vector2.ONE * 28 * unit
	var native_unit := Clean.minimum_touch_size(toggle).y / 44.0
	var switch_unit := maxf(unit, native_unit)
	toggle.custom_minimum_size = Vector2(58, 44) * switch_unit
	label.add_theme_font_size_override("font_size", roundi(16 * unit))
	add_theme_constant_override("separation", roundi(12 * unit))
	_ensure_thumb()
	_thumb.size = Vector2.ONE * 32 * switch_unit
	_thumb.custom_minimum_size = _thumb.size
	_update_thumb_style()
	_apply_toggle_style(toggle.button_pressed)
	_move_thumb(toggle.button_pressed, false)


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
	toggle.add_child(_thumb)
	_update_thumb_style()


func _update_thumb_style() -> void:
	var style := Clean.panel(Clean.PAPER, _thumb.size.x * 0.5)
	_thumb.add_theme_stylebox_override("panel", style)


func _refresh_toggle_geometry() -> void:
	if not is_instance_valid(_thumb):
		return
	_update_thumb_style()
	_apply_toggle_style(toggle.button_pressed)
	_move_thumb(toggle.button_pressed, false)


func _apply_toggle_style(enabled: bool) -> void:
	var radius := maxf(toggle.size.y, toggle.custom_minimum_size.y) * 0.5
	var style := Clean.panel(Clean.INK if enabled else Clean.SAGE, radius)
	toggle.add_theme_stylebox_override("normal", style)
	toggle.add_theme_stylebox_override("pressed", style.duplicate())
	toggle.add_theme_stylebox_override("disabled", style.duplicate())
	var focus := Clean.panel(Color.TRANSPARENT, radius)
	focus.set_border_width_all(2)
	focus.border_color = Clean.INK
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	toggle.add_theme_stylebox_override("focus", focus)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.04)
	toggle.add_theme_stylebox_override("hover", hover)
	toggle.add_theme_stylebox_override("hover_pressed", hover.duplicate())


func _move_thumb(enabled: bool, animate: bool) -> void:
	if not is_instance_valid(_thumb):
		return
	var track := toggle.size.max(toggle.custom_minimum_size)
	var inset := 4 * maxf(_unit, Clean.minimum_touch_size(toggle).y / 44.0)
	var target := Vector2(
		track.x - _thumb.size.x - inset if enabled else inset, (track.y - _thumb.size.y) * 0.5
	)
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
		&"snap_preview_enabled":
			return &"snap_preview"
		&"reduced_motion_enabled":
			return &"reduced_motion"
	return &"music"


func _draw() -> void:
	if not show_divider or size.x <= 0.0:
		return
	var y := size.y - 1.0
	draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.10, 0.31, 0.28, 0.12), _unit)


func _exit_tree() -> void:
	_stop_toggle_motion()
