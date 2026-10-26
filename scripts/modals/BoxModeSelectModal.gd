extends RuntimeModeSelectModal
signal box_closing
signal box_returned
## Shared theme packaging for every playable level, with reversible source transitions.
const BoxScene := preload("res://scenes/ui/box/PuzzleBox3D.tscn")
const BoxOption := preload("res://scripts/modals/BoxModeOption.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
var _prototype := false
var _box: Control
var _info: Label
var _box_data: Dictionary = {}
var _source_rect := Rect2()
var _destination := Rect2()
var _close_tween: Tween
var _closing := false
var _closed := false
var _generation := 0
var _phase := "inactive"


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_prototype = not str(payload.get("level_id", "")).is_empty()
	if _prototype:
		add_to_group("runtime_box_modal")
		get_tree().call_group("runtime_box_cache", "pause_for_modal")
	if _prototype:
		_box_data = payload.get("box_preview", {})
		_source_rect = payload.get("box_source_rect", Rect2())
		_box = BoxScene.instantiate()
		_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(_box)
		_info = Label.new()
		_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(_info)
	super.navigation_enter(payload, context)
	if _prototype:
		preview.hide()
		(
			_box
			. configure(
				preview.texture,
				{
					"theme_id": str(payload.get("theme_id", "")),
					"title": str(_read("level_title", "")),
					"modes": _read("options", []),
					"preview_revealed": true,
					"locked": false,
				}
			)
		)
		_box.set_rendering(true)
		_phase = "entering"


func _reconcile_options() -> void:
	if not _prototype:
		super._reconcile_options()
		return
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	for model in _read("options", []):
		if not bool(model.enabled):
			continue
		var option := BoxOption.new()
		options.add_child(option)
		option.set_view_model(model)
		option.selection_requested.connect(_on_option_selected)
	_selected_option = null
	_refresh_selection()


func opening() -> void:
	if not _prototype:
		super.opening()


func configure_box_transition(tween: Tween, duration: float) -> bool:
	if not _prototype:
		return false
	if content.size.y <= 0:
		content.size = size
	_apply_layout()
	background.modulate.a = 0.0
	options.modulate.a = 0.0
	var initial := _source_rect
	if not initial.has_area():
		initial = _destination
	else:
		initial.position -= content.global_position
	_box.position = initial.position
	_box.size = initial.size
	if _reduced_motion:
		_box.position = _destination.position
		_box.size = _destination.size
		_open_lid()
		background.modulate.a = 1.0
		options.modulate.a = 1.0
		tween.tween_interval(0.001)
		return true
	tween.tween_property(background, "modulate:a", 1.0, duration)
	tween.tween_property(_box, "position", _destination.position, duration)
	tween.tween_property(_box, "size", _destination.size, duration)
	tween.tween_property(options, "modulate:a", 1.0, duration)
	tween.tween_callback(_open_lid).set_delay(duration)
	return true


func _open_lid() -> void:
	if _closing or not is_instance_valid(_box):
		return
	_box.set_open(true, _reduced_motion)
	_phase = "ready"
	_apply_layout()


func _refresh_selection(user_change := false) -> void:
	super._refresh_selection(user_change)
	if not _prototype or not is_instance_valid(_info):
		return
	var mode := StringName(_read_from(_selected_option, "mode", &""))
	start_button.visible = not mode.is_empty()
	$SafeArea/Content/ModeHeading.text = GameStrings.ui_text("choose_mode")
	_info.visible = not mode.is_empty()
	if not mode.is_empty():
		var data: Dictionary = _box_data.get(String(mode), {})
		_info.text = (
			"%s · %d %s"
			% [
				str(_read_from(_selected_option, "label", mode)),
				int(data.get("count", 0)),
				GameStrings.ui_text("box_piece_unit")
			]
		)
		if user_change:
			_box.show_mode(mode, data.get("pieces", []), _reduced_motion)
	_apply_layout()


func _on_option_selected(mode: StringName, policy: StringName) -> void:
	if _prototype and _closing:
		return
	super._on_option_selected(mode, policy)


func _on_start_pressed() -> void:
	if _prototype and _closing:
		return
	super._on_start_pressed()


func needs_box_close() -> bool:
	return _prototype and not _closed


func update_box_source_rect(rect: Rect2) -> void:
	_source_rect = rect


func request_close() -> void:
	if not _prototype:
		super.request_close()
		return
	if _closing:
		return
	_closing = true
	box_closing.emit()
	get_tree().root.get_node("Game/AppNavigator").finish_active_transition()
	_active = false
	_generation += 1
	var generation := _generation
	_phase = "closing"
	start_button.disabled = true
	back_button.disabled = true
	for child in options.get_children():
		child.disabled = true
	await _box.retract_mode(_reduced_motion)
	if generation != _generation or not is_inside_tree():
		return
	_box.set_open(false, _reduced_motion)
	while is_inside_tree() and _box.active_motion_count() > 0:
		await get_tree().process_frame
		if generation != _generation:
			return
	if not is_inside_tree():
		return
	_close_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	var target := _source_rect
	target.position -= content.global_position
	if not target.has_area():
		target = _destination
	var full_distance := (
		_destination.position.distance_to(target.position)
		+ _destination.size.distance_to(target.size)
	)
	var remaining_distance := (
		_box.position.distance_to(target.position) + _box.size.distance_to(target.size)
	)
	var fraction := clampf(remaining_distance / maxf(full_distance, 0.001), 0.004, 1.0)
	var duration := 0.01 if _reduced_motion else 0.36 * fraction
	_close_tween.tween_property(_box, "position", target.position, duration)
	_close_tween.tween_property(_box, "size", target.size, duration)
	_close_tween.tween_property(background, "modulate:a", 0.0, duration)
	_close_tween.tween_property(options, "modulate:a", 0.0, duration)
	_close_tween.tween_property(_info, "modulate:a", 0.0, duration)
	_close_tween.tween_property($SafeArea/Content/ModeHeading, "modulate:a", 0.0, duration)
	_close_tween.tween_property(start_button, "modulate:a", 0.0, duration)
	_close_tween.tween_property($SafeArea/Content/Header, "modulate:a", 0.0, duration)
	await _close_tween.finished
	_close_tween = null
	_closed = true
	# Hand the exact source rectangle back before the navigator's modal fade.
	_box.hide()
	box_returned.emit()
	close_requested.emit()


func _apply_layout() -> void:
	if not _prototype or not is_instance_valid(_box):
		super._apply_layout()
		return
	if not is_node_ready() or content.size.y <= 0:
		return
	Layout.apply(self)
	# Keep navigation above the live viewport's transparent display quad.
	$SafeArea/Content/Header.z_index = 2
	title_label.hide()
	preview.hide()
	var u := Clean.canvas_scale(content.size, get_window())
	var s := content.size
	var width := minf(s.x - 32 * u, (s.y - 320 * u) * 0.75)
	width = maxf(120 * u, width)
	_destination = Rect2(Vector2((s.x - width) * 0.5, 78 * u), Vector2(width, width / 0.75))
	if _phase not in ["entering", "closing"]:
		_box.position = _destination.position
		_box.size = _destination.size
	var heading: Label = $SafeArea/Content/ModeHeading
	heading.position = Vector2(24 * u, _destination.end.y + 4 * u)
	heading.size = Vector2(s.x - 48 * u, 28 * u)
	Clean.label(heading, roundi(18 * u))
	options.position = Vector2(24 * u, heading.position.y + 34 * u)
	options.size = Vector2(s.x - 48 * u, 90 * u)
	var count := options.get_child_count()
	for index in count:
		var option: Control = options.get_child(index)
		option.position = Vector2(float(index) * options.size.x / count, 0)
		option.custom_minimum_size = Vector2(44 * u, 90 * u)
		option.size = Vector2(options.size.x / count - 6 * u, 90 * u)
	_info.position = Vector2(24 * u, options.position.y + 94 * u)
	_info.size = Vector2(s.x - 48 * u, 26 * u)
	Clean.label(_info, roundi(13 * u), true)


func settle_box_transition(committed: bool) -> void:
	if not _prototype or _closing:
		return
	if committed:
		_phase = "ready"
		_apply_layout()
		background.modulate.a = 1.0
		options.modulate.a = 1.0
		_box.set_open(true, _reduced_motion)
	else:
		_box.cancel_motion()
		_box.set_rendering(false)


func set_reduced_motion(enabled: bool) -> void:
	super.set_reduced_motion(enabled)
	if not _prototype or not is_instance_valid(_box) or not enabled:
		return
	_box.set_open(not _closing, true)
	if _selected_option != null and not _closing:
		var mode := StringName(_selected_option.mode)
		_box.show_mode(mode, _box_data.get(String(mode), {}).get("pieces", []), true)
	if _close_tween != null:
		_close_tween.custom_step(10.0)


func navigation_exit(context: Dictionary) -> void:
	_generation += 1
	if _close_tween != null:
		_close_tween.kill()
		_close_tween = null
	if is_instance_valid(_box):
		_box.cancel_motion()
		_box.set_rendering(false)
	if is_in_group("runtime_box_modal"):
		remove_from_group("runtime_box_modal")
	super.navigation_exit(context)


func active_motion_count() -> int:
	return (
		super.active_motion_count()
		+ int(_close_tween != null)
		+ (_box.active_motion_count() if is_instance_valid(_box) else 0)
	)


func box_debug_snapshot() -> Dictionary:
	return {
		"prototype": _prototype,
		"phase": _phase,
		"selected": String(_read_from(_selected_option, "mode", "")),
		"closing": _closing,
		"counts": _box_data.keys(),
		"live_viewports": int(is_instance_valid(_box)),
		"motion": active_motion_count()
	}
