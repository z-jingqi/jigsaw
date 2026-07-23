extends SceneTree

const ModalScene := preload("res://scenes/modals/ModeSelectModal.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")

var _all_ok := true
var _failures: Array[String] = []
var _selection_count := 0
var _selected_mode := StringName()
var _selected_policy := StringName()
var _close_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_available_selection_closes_before_signal()
	await _test_unavailable_and_close()
	await _test_reduced_motion()
	var result := {"ok": _all_ok, "failures": _failures}
	print("MODE_SELECT_MODAL %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _test_available_selection_closes_before_signal() -> void:
	var modal: Control = await _create_modal(false)
	var options: VBoxContainer = modal.get_node("ModalShell/Panel/Content/Options")
	_check(options.get_child_count() == 3, "renders_three_mode_options")
	var polygon := options.get_child(0) as Control
	var knob := options.get_child(1) as Control
	var swap := options.get_child(2) as Control
	_check(not polygon.disabled and not knob.disabled and swap.disabled, "availability_applied")
	_check(polygon.get_node("Margin/Content/Action").text == "Start" and knob.get_node("Margin/Content/Action").text == "Continue", "start_resume_actions")
	await create_timer(0.30).timeout
	_check(int(modal.call(&"active_motion_count")) == 0, "open_motion_released")
	(polygon as Button).pressed.emit()
	_check(_selection_count == 0, "selection_waits_for_close")
	await create_timer(0.20).timeout
	_check(_selection_count == 1 and _selected_mode == &"polygon" and _selected_policy == &"start", "selection_emitted_once_after_close")
	_check(int(modal.call(&"active_motion_count")) == 0, "close_motion_released")
	modal.queue_free()
	await process_frame


func _test_unavailable_and_close() -> void:
	_selection_count = 0
	_close_count = 0
	var modal: Control = await _create_modal(false)
	var options: VBoxContainer = modal.get_node("ModalShell/Panel/Content/Options")
	var unavailable := options.get_child(2) as Control
	(unavailable as Button).pressed.emit()
	await process_frame
	_check(_selection_count == 0, "unavailable_never_selects")
	modal.call(&"request_close")
	await create_timer(0.20).timeout
	_check(_close_count == 1, "close_emits_once")
	modal.queue_free()
	await process_frame


func _test_reduced_motion() -> void:
	_selection_count = 0
	var modal: Control = await _create_modal(true)
	var options: VBoxContainer = modal.get_node("ModalShell/Panel/Content/Options")
	(options.get_child(1) as Button).pressed.emit()
	await process_frame
	_check(_selection_count == 1 and _selected_policy == &"resume", "reduced_motion_selection")
	_check(int(modal.call(&"active_motion_count")) == 0, "reduced_motion_no_residual_motion")
	modal.queue_free()
	await process_frame


func _create_modal(reduced_motion: bool) -> Control:
	var modal := ModalScene.instantiate() as Control
	root.add_child(modal)
	modal.set_anchors_preset(Control.PRESET_TOP_LEFT)
	modal.size = Vector2(393, 852)
	await process_frame
	modal.mode_selected.connect(func(mode: StringName, policy: StringName) -> void:
		_selection_count += 1
		_selected_mode = mode
		_selected_policy = policy)
	modal.close_requested.connect(func() -> void: _close_count += 1)
	modal.call(&"navigation_enter", {"view_model": _view_model()}, {"reduced_motion": reduced_motion})
	return modal


func _view_model() -> Variant:
	return ViewModels.ModeSelectViewModel.new({
		"revision": 1,
		"theme_id": "topic_01",
		"level_id": "shanhai_08",
		"level_title": "Nine-tailed Fox",
		"options": [
			ViewModels.ModeStatusViewModel.new(&"polygon", "Polygon", &"not_started", &"start", true),
			ViewModels.ModeStatusViewModel.new(&"knob", "Classic Knob", &"in_progress", &"resume", true),
			ViewModels.ModeStatusViewModel.new(&"swap", "Swap", &"unavailable", &"start", false),
		],
	})


func _check(condition: bool, name: String) -> void:
	if condition:
		print("MODE_SELECT_MODAL_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("MODE_SELECT_MODAL_FAIL %s" % name)
