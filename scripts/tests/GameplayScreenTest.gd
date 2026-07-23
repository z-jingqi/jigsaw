extends SceneTree

const ScreenScene := preload("res://scenes/screens/GameplayScreen.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")

var _all_ok := true
var _failures: Array[String] = []
var _back_count := 0
var _hint_count := 0
var _move_up_count := 0
var _move_down_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mode(&"polygon", true, false)
	await _test_mode(&"knob", true, false)
	await _test_mode(&"swap", false, true)
	var result := {"ok": _all_ok, "failures": _failures}
	print("GAMEPLAY_SCREEN %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _test_mode(mode: StringName, expects_tray: bool, expects_swap: bool) -> void:
	var screen := ScreenScene.instantiate() as GameplayScreen
	root.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(393, 852)
	await process_frame
	screen.back_requested.connect(func() -> void: _back_count += 1)
	screen.hint_requested.connect(func() -> void: _hint_count += 1)
	screen.move_swap_up_requested.connect(func() -> void: _move_up_count += 1)
	screen.move_swap_down_requested.connect(func() -> void: _move_down_count += 1)
	screen.navigation_enter({"view_model": _view_model(mode)}, {"reduced_motion": false})
	_check(screen.get_node("Hud/Title").text == "Nine-tailed Fox", "%s_title" % mode)
	_check(screen.get_node("BottomHost/TrayView").visible == expects_tray, "%s_tray_variant" % mode)
	_check(screen.get_node("BottomHost/SwapActionBar").visible == expects_swap, "%s_swap_variant" % mode)
	var expected_blockers := 3 if expects_swap else 2
	_check(screen.board_reserved_rects().size() == expected_blockers, "%s_reserved_input_regions" % mode)
	if expects_tray:
		_check(screen.tray_rect().size.y > 0.0, "%s_tray_rect_available" % mode)
	screen.mark_board_live()
	(screen.get_node("Hud/BackButton") as Button).pressed.emit()
	(screen.get_node("Hud/HintButton") as Button).pressed.emit()
	if expects_swap:
		(screen.get_node("BottomHost/SwapActionBar/Actions/MoveUp") as Button).pressed.emit()
		(screen.get_node("BottomHost/SwapActionBar/Actions/MoveDown") as Button).pressed.emit()
	_check(_back_count > 0 and _hint_count > 0, "%s_hud_signals" % mode)
	if expects_swap:
		_check(_move_up_count == 1 and _move_down_count == 1, "swap_action_signals")
	screen.navigation_exit({})
	_check((screen.get_node("Hud/BackButton") as Button).disabled, "%s_exit_locks_input" % mode)
	screen.queue_free()
	await process_frame


func _view_model(mode: StringName) -> Variant:
	return ViewModels.GameplayViewModel.new({
		"revision": 1,
		"theme_id": "topic_01",
		"level_id": "shanhai_08",
		"level_title": "Nine-tailed Fox",
		"mode": mode,
		"hint_enabled": true,
	})


func _check(condition: bool, name: String) -> void:
	if condition:
		print("GAMEPLAY_SCREEN_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("GAMEPLAY_SCREEN_FAIL %s" % name)
