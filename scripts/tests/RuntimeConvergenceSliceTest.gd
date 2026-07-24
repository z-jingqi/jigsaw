extends SceneTree

const GameScene := preload("res://scenes/app/Game.tscn")

var _all_ok := true
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GameScene.instantiate() as Game
	root.add_child(game)
	await create_timer(0.45).timeout
	_check(str(game.debug_state_snapshot().get("screen", "")) == "home", "project_main_enters_scene_home")
	var all_themes := game.debug_execute("show_all_themes")
	_check(bool(all_themes.get("ok", false)), "debug_opens_all_themes")
	await create_timer(0.40).timeout
	_check(str(game.debug_state_snapshot().get("screen", "")) == "all_themes", "all_themes_is_real_scene_route")
	var gallery := game.get_node("UiLayer/ScreenHost").get_child(-1) as AllThemesScreen
	if gallery != null:
		gallery.close_button.pressed.emit()
	await create_timer(0.40).timeout
	_check(str(game.debug_state_snapshot().get("screen", "")) == "home", "all_themes_returns_to_home")
	if not str(game.debug_state_snapshot().get("modal", "")).is_empty():
		game.debug_execute("close_modal")
		await create_timer(0.40).timeout
	var settings := game.debug_execute("show_settings")
	_check(bool(settings.get("ok", false)), "debug_opens_settings")
	await create_timer(0.40).timeout
	_check(str(game.debug_state_snapshot().get("modal", "")) == "settings", "settings_is_navigator_modal")
	var settings_close := game.debug_execute("close_modal")
	_check(bool(settings_close.get("ok", false)), "debug_closes_settings")
	await create_timer(0.40).timeout
	_check(str(game.debug_state_snapshot().get("modal", "")).is_empty(), "settings_releases_modal")
	var levels := game.debug_execute("show_levels", {"topic_id": "topic_01"})
	_check(bool(levels.get("ok", false)), "debug_enters_levels")
	await create_timer(0.40).timeout
	var state := game.debug_state_snapshot()
	_check(str(state.get("screen", "")) == "levels", "levels_is_real_scene_route")
	var modal := game.debug_execute("show_mode_select", {"topic_id": "topic_01", "level_id": "shanhai_01"})
	_check(bool(modal.get("ok", false)), "debug_opens_mode_modal")
	await create_timer(0.40).timeout
	state = game.debug_state_snapshot()
	_check(str(state.get("modal", "")) == "mode_select", "mode_select_is_navigator_modal")
	var close := game.debug_execute("close_modal")
	_check(bool(close.get("ok", false)), "debug_closes_modal")
	await create_timer(0.40).timeout
	state = game.debug_state_snapshot()
	_check(str(state.get("screen", "")) == "levels" and str(state.get("modal", "")).is_empty(), "modal_restores_levels")
	var enter := game.debug_execute("enter_level", {"topic_id": "topic_01", "level_id": "shanhai_01", "mode": "polygon"})
	_check(bool(enter.get("ok", false)), "debug_enters_gameplay")
	await create_timer(0.55).timeout
	state = game.debug_state_snapshot()
	_check(str(state.get("screen", "")) == "gameplay", "gameplay_is_real_scene_route")
	_check(str(state.get("topic_id", "")) == "topic_01" and str(state.get("level_id", "")) == "shanhai_01", "gameplay_state_is_deterministic")
	if not str(state.get("modal", "")).is_empty():
		game.debug_execute("close_modal")
		await create_timer(0.40).timeout
	var completion := game.debug_execute("preview_complete")
	_check(bool(completion.get("ok", false)), "debug_previews_completion")
	await create_timer(0.40).timeout
	_check(str(game.debug_state_snapshot().get("modal", "")) == "completion", "completion_is_navigator_modal")
	var completion_modal := game.get_node("UiLayer/ModalHost").get_child(-1) as CompletionModal
	if completion_modal != null:
		completion_modal.confirm_button.pressed.emit()
	await create_timer(0.70).timeout
	_check(str(game.debug_state_snapshot().get("screen", "")) == "levels", "completion_returns_to_levels")
	_check(int(state.get("active_motion_count", -1)) >= 0, "motion_snapshot_available")
	game.queue_free()
	await process_frame
	var result := {"ok": _all_ok, "failures": _failures}
	print("RUNTIME_CONVERGENCE_SLICE %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("RUNTIME_CONVERGENCE_SLICE_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("RUNTIME_CONVERGENCE_SLICE_FAIL %s" % name)
