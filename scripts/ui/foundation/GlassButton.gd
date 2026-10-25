class_name GlassButton
extends ActionButton

## Compatibility component using the shared flat paper treatment.

enum VisualKind { ICON, PILL }

const WARM_TEXT := Color("#272925")

@export var visual_kind: VisualKind = VisualKind.PILL
@export var icon_texture: Texture2D
@export_range(0.1, 0.8, 0.01) var icon_scale := 0.58
@export_range(-20.0, 20.0, 0.5) var press_icon_rotation_degrees := 0.0

var _icon_rotation := 0.0
var _icon_motion: Tween


func _ready() -> void:
	super._ready()
	flat = false
	focus_mode = Control.FOCUS_ALL
	add_theme_color_override("font_color", WARM_TEXT)
	add_theme_color_override("font_hover_color", WARM_TEXT)
	add_theme_color_override("font_pressed_color", WARM_TEXT.darkened(0.12))
	add_theme_color_override("font_disabled_color", WARM_TEXT.lightened(0.32))
	resized.connect(_refresh_surface)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	mouse_exited.connect(_release_icon)
	gui_input.connect(_on_icon_gui_input)
	_refresh_surface()


func _refresh_surface() -> void:
	pivot_offset = size * 0.5
	preload("res://scripts/ui/foundation/CleanTheme.gd").button(
		self, visual_kind == VisualKind.PILL
	)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_icon()


func _draw_icon() -> void:
	if visual_kind != VisualKind.ICON or icon_texture == null:
		return
	var icon_side := minf(size.x, size.y) * icon_scale
	var icon_size := Vector2(icon_side, icon_side)
	draw_set_transform(size * 0.5, _icon_rotation, Vector2.ONE)
	var icon_rect := Rect2(-icon_size * 0.5, icon_size)
	draw_texture_rect(icon_texture, icon_rect, false, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func set_reduced_motion(enabled: bool) -> void:
	super.set_reduced_motion(enabled)
	if enabled:
		_cancel_icon_motion()
		_set_icon_rotation(0.0)


func cancel_motion() -> void:
	super.cancel_motion()
	_cancel_icon_motion()
	_set_icon_rotation(0.0)


func active_motion_count() -> int:
	var icon_active := (
		1 if _icon_motion != null and _icon_motion.is_valid() and _icon_motion.is_running() else 0
	)
	return super.active_motion_count() + icon_active


func debug_icon_rotation_degrees() -> float:
	return rad_to_deg(_icon_rotation)


func _on_icon_gui_input(event: InputEvent) -> void:
	if disabled or _reduced_motion or is_zero_approx(press_icon_rotation_degrees):
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_play_icon_rotation(
				deg_to_rad(press_icon_rotation_degrees), motion_tokens.press_duration
			)
		else:
			_release_icon()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_play_icon_rotation(
				deg_to_rad(press_icon_rotation_degrees), motion_tokens.press_duration
			)
		else:
			_release_icon()


func _release_icon() -> void:
	if is_zero_approx(_icon_rotation):
		return
	_play_icon_rotation(0.0, motion_tokens.release_duration)


func _play_icon_rotation(value: float, duration: float) -> void:
	_cancel_icon_motion()
	_icon_motion = create_tween()
	_icon_motion.set_trans(motion_tokens.press_transition).set_ease(motion_tokens.press_ease)
	_icon_motion.tween_method(_set_icon_rotation, _icon_rotation, value, duration)
	_icon_motion.finished.connect(_clear_icon_motion, CONNECT_ONE_SHOT)


func _set_icon_rotation(value: float) -> void:
	_icon_rotation = value
	queue_redraw()


func _cancel_icon_motion() -> void:
	if _icon_motion != null and _icon_motion.is_valid():
		_icon_motion.kill()
	_icon_motion = null


func _clear_icon_motion() -> void:
	_icon_motion = null


func _exit_tree() -> void:
	_cancel_icon_motion()
	super._exit_tree()
