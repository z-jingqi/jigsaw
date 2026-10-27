extends RuntimeModeSelectModal
signal box_closing
signal box_returned
## Mode content stays local; the navigator owns the page transition.
const OpticalLayout := preload("res://scripts/modals/BoxModeOpticalLayout.gd")
const BoxScene := preload("res://scenes/ui/box/PuzzleBox3D.tscn")
const BoxOption := preload("res://scripts/modals/BoxModeOption.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
var _prototype := false
var _box: Control
var _info: Label
var _box_data: Dictionary = {}
var _source_rect := Rect2()
var _destination := Rect2()
var _closing := false
var _closed := false
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
		_apply_layout()
		_open_lid()
		_refresh_selection(true)


func _reconcile_options() -> void:
	if not _prototype:
		super._reconcile_options()
		return
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var available: Array = []
	for model in _read("options", []):
		if not bool(model.enabled):
			continue
		var option := BoxOption.new()
		options.add_child(option)
		option.set_view_model(model)
		option.set_reduced_motion(_reduced_motion)
		option.selection_requested.connect(_on_option_selected)
		available.append(model)
	_selected_option = _default_option(available)
	_refresh_selection()


func opening() -> void:
	if not _prototype:
		super.opening()


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
	$SafeArea/Content/ModeHeading.hide()
	_info.hide()
	if not mode.is_empty():
		var data: Dictionary = _box_data.get(String(mode), {})
		_info.text = ("%d %s" % [int(data.get("count", 0)), GameStrings.ui_text("box_piece_unit")])
		start_button.accessibility_name += ", " + _info.text
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


func gesture_pause_motion() -> void:
	if is_instance_valid(_box):
		_box.gesture_pause_motion()


func gesture_resume_motion() -> void:
	if is_instance_valid(_box):
		_box.gesture_resume_motion()


func needs_box_close() -> bool:
	return _prototype and not _closed


func update_box_source_rect(rect: Rect2) -> void:
	_source_rect = rect


func request_close() -> void:
	if _closing:
		return
	_closing = true
	# Mark the local close complete before emitting: the coordinator re-enters
	# close_modal() and must proceed to navigation instead of requesting it again.
	_closed = true
	_active = false
	_phase = "closing"
	box_returned.emit()
	close_requested.emit()


func navigation_set_active(is_active: bool) -> void:
	if is_active:
		_closing = false
		_closed = false
		_phase = "ready"
		if is_instance_valid(_box):
			_box.set_rendering(true)
	super.navigation_set_active(is_active)


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
	_destination = OpticalLayout.apply(_box, options, start_button, content.size)
	if _phase not in ["entering", "closing"]:
		_box.position = _destination.position
		_box.size = _destination.size
	$SafeArea/Content/ModeHeading.hide()
	_info.hide()
	Layout.layout_start_content(self)


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


func navigation_exit(context: Dictionary) -> void:
	if is_instance_valid(_box):
		_box.cancel_motion()
		_box.set_rendering(false)
	if is_in_group("runtime_box_modal"):
		remove_from_group("runtime_box_modal")
	super.navigation_exit(context)


func active_motion_count() -> int:
	return (
		super.active_motion_count() + (_box.active_motion_count() if is_instance_valid(_box) else 0)
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
