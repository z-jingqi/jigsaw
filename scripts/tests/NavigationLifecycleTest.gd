extends SceneTree

const GameScene := preload("res://scenes/app/Game.tscn")
const ProbeScene := preload("res://scenes/tests/NavigationProbeScreen.tscn")
const RouteRegistryScript := preload("res://scripts/navigation/RouteRegistry.gd")

var _all_ok := true
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GameScene.instantiate()
	root.add_child(game)
	await process_frame
	var navigator = game.get_node("AppNavigator")
	var transition_host = game.get_node("UiLayer/TransitionHost")
	var registry = RouteRegistryScript.new()
	for route in [&"home", &"all_themes", &"levels", &"gameplay", &"mode_select", &"settings", &"home_guide", &"mode_tutorial", &"completion"]:
		var bound: Dictionary = registry.bind_scene(route, ProbeScene)
		_check(bool(bound.get("ok", false)), "bind_%s" % route)
	navigator.set_route_registry(registry)

	var home: Dictionary = navigator.set_root(&"home", {"theme_id": "topic_01"})
	_check(bool(home.get("ok", false)), "set_root")
	_check(transition_host.active_count() == 1, "root_transition_active")
	transition_host.finish_active_to_target()
	await process_frame
	_check(navigator.current_route() == &"home", "root_route")
	_check(navigator.current_screen_view().active, "home_active")

	var levels: Dictionary = navigator.push(&"levels", {"theme_id": "topic_01"})
	_check(bool(levels.get("ok", false)), "push_levels")
	var duplicate: Dictionary = navigator.push(&"levels", {"theme_id": "topic_01"})
	_check(not bool(duplicate.get("ok", false)) and duplicate.get("error") == "transition_busy", "ignore_duplicate_navigation")
	navigator.cancel_active_transition()
	await process_frame
	_check(navigator.current_route() == &"home", "cancel_restores_source")
	_check(game.get_node("UiLayer/ScreenHost").get_child_count() == 1, "cancel_releases_target")

	levels = navigator.push(&"levels", {"theme_id": "topic_01", "focus_level_id": "shanhai_08"})
	_check(bool(levels.get("ok", false)), "push_levels_after_cancel")
	var motion_before_finish: Dictionary = navigator.debug_state_snapshot()
	_check(motion_before_finish.get("transition_kind") == "home_to_levels", "home_levels_transition")
	transition_host.finish_active_to_target()
	await process_frame
	_check(navigator.current_route() == &"levels", "levels_route")
	var levels_view = navigator.current_screen_view()
	var modal: Dictionary = navigator.show_modal(&"mode_select", {"theme_id": "topic_01", "level_id": "shanhai_08"})
	_check(bool(modal.get("ok", false)), "show_modal")
	transition_host.finish_active_to_target()
	await process_frame
	_check(navigator.current_route() == &"mode_select", "modal_route")
	var close_result: Dictionary = navigator.close_modal({"action": &"select_mode", "payload": {"mode": "polygon"}})
	_check(bool(close_result.get("ok", false)), "close_modal")
	transition_host.finish_active_to_target()
	await process_frame
	_check(navigator.current_route() == &"levels", "close_restores_levels")
	_check(navigator.current_screen_view() == levels_view, "screen_instance_preserved")

	var pop_result: Dictionary = navigator.pop()
	_check(bool(pop_result.get("ok", false)), "pop_levels")
	transition_host.finish_active_to_target()
	await process_frame
	_check(navigator.current_route() == &"home", "pop_restores_home")
	var all_themes: Dictionary = navigator.push(&"all_themes", {"current_theme_id": "topic_01"})
	_check(bool(all_themes.get("ok", false)), "open_all_themes")
	motion_before_finish = navigator.debug_state_snapshot()
	_check(motion_before_finish.get("transition_kind") == "screen", "all_themes_uses_screen_transition")
	transition_host.finish_active_to_target()
	await process_frame
	_check(navigator.current_route() == &"all_themes", "all_themes_route")
	var card_to_levels: Dictionary = navigator.push(&"levels", {"theme_id": "topic_01"})
	_check(bool(card_to_levels.get("ok", false)), "all_themes_selects_topic")
	motion_before_finish = navigator.debug_state_snapshot()
	_check(motion_before_finish.get("transition_kind") == "card_to_levels", "card_levels_transition")
	navigator.cancel_active_transition()
	await process_frame
	_check(navigator.current_route() == &"all_themes", "cancel_card_transition_restores_gallery")
	pop_result = navigator.pop()
	_check(bool(pop_result.get("ok", false)), "close_all_themes")
	transition_host.finish_active_to_target()
	await process_frame
	_check(navigator.current_route() == &"home", "all_themes_returns_home")
	navigator.set_reduced_motion(true)
	all_themes = navigator.push(&"all_themes", {"current_theme_id": "topic_01"})
	_check(bool(all_themes.get("ok", false)), "open_all_themes_reduced_motion")
	motion_before_finish = navigator.debug_state_snapshot()
	_check(bool(motion_before_finish.get("reduced_motion", false)), "reduced_motion_propagated")
	transition_host.finish_active_to_target()
	await process_frame
	pop_result = navigator.pop()
	_check(bool(pop_result.get("ok", false)), "close_all_themes_reduced_motion")
	transition_host.finish_active_to_target()
	await process_frame
	navigator.set_reduced_motion(false)
	var snapshot: Dictionary = navigator.debug_state_snapshot()
	_check(int(snapshot.get("active_motion_count", -1)) == 0, "no_active_motion")
	_check(not bool(snapshot.get("input_locked", true)), "input_unlocked")

	game.queue_free()
	await process_frame
	var result := {"ok": _all_ok, "failures": _failures}
	print("NAVIGATION_LIFECYCLE %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("NAVIGATION_LIFECYCLE_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("NAVIGATION_LIFECYCLE_FAIL %s" % name)
