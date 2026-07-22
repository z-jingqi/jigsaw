extends Control
class_name AnimatedModalShell

signal closed(shell: AnimatedModalShell)

const CAPTURED_OPEN := &"_captured_open"
const CAPTURED_CLOSE := &"_captured_close"
const OPEN_DURATION := 0.24
const CLOSE_DURATION := 0.14

@onready var shade: ColorRect = $Shade
@onready var panel: Panel = $Panel
@onready var content: VBoxContainer = $Panel/Content
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var phase := "idle"
var _has_opened := false


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play(&"RESET")
	animation_player.advance(0.0)


func prepare_reuse() -> void:
	animation_player.stop(true)
	phase = "idle"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_clear_dynamic_children()


func configure_shade(color: Color, material_override: Material = null) -> void:
	shade.material = material_override
	shade.color = Color.WHITE if material_override != null else color


func configure_panel(size: Vector2, style: StyleBox, padding: Vector4) -> VBoxContainer:
	panel.custom_minimum_size = size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	panel.pivot_offset = size * 0.5
	panel.add_theme_stylebox_override("panel", style)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = padding.x
	content.offset_top = padding.y
	content.offset_right = -padding.z
	content.offset_bottom = -padding.w
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	return content


func play_open(reduced_motion: bool) -> void:
	animation_player.stop(true)
	phase = "opening"
	mouse_filter = Control.MOUSE_FILTER_STOP
	if reduced_motion:
		_apply_open_state()
		phase = "open"
		_has_opened = true
		return
	if not _has_opened and _is_reset_state():
		animation_player.play(&"open")
		animation_player.advance(0.0)
	else:
		_install_captured_open()
		animation_player.play(CAPTURED_OPEN)
		animation_player.advance(0.0)
	_has_opened = true


func play_close(reduced_motion: bool) -> void:
	if phase == "closed":
		return
	animation_player.stop(true)
	phase = "closing"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reduced_motion:
		_finish_close()
		return
	_install_captured_close()
	animation_player.play(CAPTURED_CLOSE)
	animation_player.advance(0.0)


func dispose() -> void:
	if animation_player != null:
		animation_player.stop(true)
	phase = "closed"
	queue_free()


func active_motion_count() -> int:
	return 1 if phase in ["opening", "closing"] and animation_player.is_playing() else 0


func debug_state() -> Dictionary:
	return {
		"phase": phase,
		"shade_alpha": shade.modulate.a,
		"panel_alpha": panel.modulate.a,
		"panel_scale": [panel.scale.x, panel.scale.y],
		"animation": str(animation_player.current_animation),
		"active_motion_count": active_motion_count(),
	}


func _clear_dynamic_children() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for child in panel.get_children():
		if child == content:
			continue
		panel.remove_child(child)
		child.queue_free()


func _is_reset_state() -> bool:
	return (
		shade.modulate.a <= 0.001
		and panel.modulate.a <= 0.001
		and panel.scale.is_equal_approx(Vector2(0.965, 0.965))
	)


func _install_captured_open() -> void:
	var animation := Animation.new()
	animation.length = OPEN_DURATION
	_add_track(animation, NodePath("Shade:modulate:a"), shade.modulate.a, 1.0, 0.14, 0.35)
	_add_track(animation, NodePath("Panel:modulate:a"), panel.modulate.a, 1.0, 0.22, 0.35)
	var scale_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(scale_track, NodePath("Panel:scale"))
	animation.track_set_interpolation_type(scale_track, Animation.INTERPOLATION_LINEAR)
	animation.track_insert_key(scale_track, 0.0, panel.scale, 0.35)
	animation.track_insert_key(scale_track, 0.18, Vector2(1.012, 1.012), 1.0)
	animation.track_insert_key(scale_track, OPEN_DURATION, Vector2.ONE, 1.0)
	_replace_runtime_animation(CAPTURED_OPEN, animation)


func _install_captured_close() -> void:
	var animation := Animation.new()
	animation.length = CLOSE_DURATION
	_add_track(animation, NodePath("Shade:modulate:a"), shade.modulate.a, 0.0, CLOSE_DURATION, 2.5)
	_add_track(animation, NodePath("Panel:modulate:a"), panel.modulate.a, 0.0, CLOSE_DURATION, 2.5)
	_add_track(animation, NodePath("Panel:scale"), panel.scale, Vector2(0.98, 0.98), CLOSE_DURATION, 2.5)
	_replace_runtime_animation(CAPTURED_CLOSE, animation)


func _add_track(animation: Animation, path: NodePath, start_value: Variant, end_value: Variant, duration: float, transition: float) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	animation.track_insert_key(track, 0.0, start_value, transition)
	animation.track_insert_key(track, duration, end_value, 1.0)


func _replace_runtime_animation(name: StringName, animation: Animation) -> void:
	var library := animation_player.get_animation_library(&"")
	if library.has_animation(name):
		library.remove_animation(name)
	library.add_animation(name, animation)


func _on_animation_finished(_animation_name: StringName) -> void:
	if phase == "opening":
		_apply_open_state()
		phase = "open"
	elif phase == "closing":
		_finish_close()


func _apply_open_state() -> void:
	shade.modulate.a = 1.0
	panel.modulate.a = 1.0
	panel.scale = Vector2.ONE


func _finish_close() -> void:
	shade.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.98, 0.98)
	phase = "closed"
	closed.emit(self)
	queue_free()
