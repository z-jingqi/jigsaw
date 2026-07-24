class_name RuntimeAppCoordinator
extends RefCounted

const AppServicesScript := preload("res://scripts/runtime/AppServices.gd")
const AppStateScript := preload("res://scripts/runtime/state/AppState.gd")
const ContentRepositoryScript := preload("res://scripts/runtime/data/ContentRepository.gd")
const ProgressRepositoryScript := preload("res://scripts/runtime/data/ProgressRepository.gd")
const SessionRepositoryScript := preload("res://scripts/runtime/data/SessionRepository.gd")
const SettingsRepositoryScript := preload("res://scripts/runtime/data/SettingsRepository.gd")
const MotionPreferencesScript := preload("res://scripts/runtime/state/MotionPreferences.gd")
const CatalogPresenterScript := preload("res://scripts/runtime/presentation/CatalogPresenter.gd")
const SystemPresenterScript := preload("res://scripts/runtime/presentation/SystemPresenter.gd")
const GameStringsScript := preload("res://scripts/app/GameStrings.gd")
const PuzzleBoardScene := preload("res://scenes/gameplay/PuzzleBoard.tscn")
const HomeScene := preload("res://scenes/screens/HomeScreen.tscn")
const AllThemesScene := preload("res://scenes/screens/AllThemesScreen.tscn")
const LevelsScene := preload("res://scenes/screens/LevelListScreen.tscn")
const GameplayScene := preload("res://scenes/screens/GameplayScreen.tscn")
const ModeSelectScene := preload("res://scenes/modals/ModeSelectModal.tscn")
const SettingsScene := preload("res://scenes/modals/SettingsModal.tscn")
const CompletionScene := preload("res://scenes/modals/CompletionModal.tscn")
const HomeGuideScene := preload("res://scenes/overlays/HomeFirstRunGuide.tscn")
const ModeTutorialScene := preload("res://scenes/modals/ModeTutorialModal.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")

var _game: Node2D
var _navigator: AppNavigator
var _world_host: Node2D
var _services: AppServices
var _state = AppStateScript.new()
var _catalog: CatalogPresenter
var _system: SystemPresenter
var _strings = GameStringsScript.new()
var _board: PuzzleBoard
var _current_theme_id := ""
var _current_level_id := ""
var _current_mode := ""
var _completion_event_id := ""
var _debug_viewport := Vector2i.ZERO
var _pending_after_modal: Callable
var _home_guide_timer: SceneTreeTimer
var _dev_panel: Control


func _init(game: Node2D) -> void:
	_game = game


func start() -> void:
	_strings.set_locale(GameStringsScript.detect_locale())
	var content := ContentRepositoryScript.new()
	var progress := ProgressRepositoryScript.new()
	var session := SessionRepositoryScript.new()
	var settings := SettingsRepositoryScript.new()
	var motion := MotionPreferencesScript.new(settings)
	_services = AppServicesScript.new(content, progress, session, settings, motion)
	_services.load()
	_catalog = CatalogPresenterScript.new(content, progress, session, _strings)
	_system = SystemPresenterScript.new(settings, motion, _strings)
	_navigator = _game.get_node("AppNavigator") as AppNavigator
	_world_host = _game.get_node("WorldHost") as Node2D
	_bind_routes()
	_navigator.route_changed.connect(_on_route_changed)
	_services.motion_preferences.changed.connect(_on_motion_preference_changed)
	_board = PuzzleBoardScene.instantiate() as PuzzleBoard
	_world_host.add_child(_board)
	_board.completed.connect(_on_board_completed)
	_board.state_changed.connect(_on_board_state_changed)
	_apply_feedback_preferences()
	_game.get_viewport().size_changed.connect(_refresh_board_blockers)
	_current_theme_id = _services.initial_home_theme_id()
	show_home(_current_theme_id)


func shutdown() -> void:
	_cancel_home_guide_timer()
	_board = null
	_game = null


func handle_input(event: InputEvent) -> bool:
	if not is_instance_valid(_board) or _navigator.current_screen_view() == null:
		return false
	if String(_navigator.current_screen_entry().get("route", "")) != "gameplay":
		return false
	return _board.handle_input(event, not String(_navigator.debug_state_snapshot().get("modal", "")).is_empty())


func debug_level_options() -> Array:
	var result: Array = []
	for topic in _services.content.topics():
		for level in topic.get("levels", []):
			if typeof(level) != TYPE_DICTIONARY:
				continue
			var modes := _services.content.available_modes(level)
			if modes.is_empty():
				continue
			result.append({"label": "%s / %s" % [topic.get("name", ""), level.get("title", "")], "topic_id": topic.get("id", ""), "level_id": level.get("id", ""), "modes": modes})
	return result


func settle_navigation() -> void:
	if _navigator.debug_state_snapshot().get("active_motion_count", 0) > 0:
		_navigator.finish_active_transition()


func show_home(theme_id := "") -> Dictionary:
	_clear_board()
	_current_level_id = ""
	_current_mode = ""
	_current_theme_id = _valid_theme_id(theme_id if not theme_id.is_empty() else _current_theme_id)
	_services.session.set_current(_current_theme_id)
	var result := _navigator.set_root(&"home", {"theme_id": _current_theme_id, "view_model": _catalog.home(_current_theme_id)})
	if bool(result.get("ok", false)):
		_bind_home(_navigator.current_screen_view() as HomeScreen)
	return result


func show_all_themes() -> Dictionary:
	var result := _navigator.push(&"all_themes", {"current_theme_id": _current_theme_id, "view_model": _catalog.all_themes(_current_theme_id)})
	if bool(result.get("ok", false)):
		_bind_all_themes(_navigator.current_screen_view() as AllThemesScreen)
	return result


func show_levels(theme_id: String, focus_level_id := "", replace := false) -> Dictionary:
	var topic := _services.content.topic_by_id(theme_id)
	if topic.is_empty():
		return {"ok": false, "error": "not_found"}
	_clear_board()
	_current_theme_id = theme_id
	_current_level_id = focus_level_id
	_current_mode = ""
	_services.session.set_current(theme_id, focus_level_id)
	var payload := {"theme_id": theme_id, "focus_level_id": focus_level_id, "view_model": _catalog.level_list(theme_id, focus_level_id)}
	var result := _navigator.replace(&"levels", payload) if replace else _navigator.push(&"levels", payload)
	if bool(result.get("ok", false)):
		_bind_levels(_navigator.current_screen_view() as RuntimeLevelListScreen)
	return result


func show_mode_select(theme_id: String, level_id: String) -> Dictionary:
	if _services.content.level_by_id(theme_id, level_id).is_empty():
		return {"ok": false, "error": "not_found"}
	_current_theme_id = theme_id
	_current_level_id = level_id
	var result := _navigator.show_modal(&"mode_select", {"theme_id": theme_id, "level_id": level_id, "view_model": _catalog.mode_select(theme_id, level_id)})
	if bool(result.get("ok", false)):
		_bind_mode_select(_navigator.current_route_view() as RuntimeModeSelectModal)
	return result


func enter_level(theme_id: String, level_id: String, mode: String, start_policy := "start") -> Dictionary:
	var level := _services.content.level_by_id(theme_id, level_id)
	if level.is_empty() or not _services.content.available_modes(level).has(mode):
		return {"ok": false, "error": "invalid_argument"}
	_current_theme_id = theme_id
	_current_level_id = level_id
	_current_mode = mode
	_completion_event_id = ""
	if start_policy == "replay":
		_services.session.clear_play_state(theme_id, level_id, mode)
	_services.session.set_current(theme_id, level_id, mode)
	var payload := {"theme_id": theme_id, "level_id": level_id, "mode": mode, "start_policy": start_policy, "view_model": _catalog.gameplay(theme_id, level_id, mode)}
	var result := _navigator.push(&"gameplay", payload)
	if bool(result.get("ok", false)):
		var screen := _navigator.current_screen_view() as GameplayScreen
		_bind_gameplay(screen)
		_game.call_deferred("_start_runtime_board", screen)
	return result


func start_runtime_board(screen: GameplayScreen) -> void:
	if not is_instance_valid(screen) or _current_mode.is_empty():
		return
	var topic := _services.content.topic_by_id(_current_theme_id)
	var level := _services.content.level_by_id(_current_theme_id, _current_level_id)
	if topic.is_empty() or level.is_empty():
		return
	var config := _services.content.config_with_theme_background(_services.content.level_config(level), topic)
	var media := _services.content.level_media(config)
	_apply_feedback_preferences()
	var loaded := _board.start(config, _current_mode, media.get("texture"), media.get("image"), media.get("source_size", Vector2.ZERO), screen.top_reserved_height(), false, {}, screen.bottom_reserved_height(), screen.tray_rect())
	if not loaded:
		return
	var restore := _services.session.play_state(_current_theme_id, _current_level_id, _current_mode, _board.session_piece_ids())
	if not restore.is_empty():
		_board.apply_state_snapshot(restore)
	screen.mark_board_live()
	_refresh_board_blockers()
	if not _services.progress.tutorial_seen(&"mode", _current_mode):
		show_mode_tutorial(_current_mode)


func show_settings() -> Dictionary:
	var labels := {"title": _strings.text("settings_title"), "haptics": _strings.text("haptics"), "music": _strings.text("music"), "sound_effects": _strings.text("sfx")}
	var result := _navigator.show_modal(&"settings", {"view_model": _system.settings(), "labels": labels})
	if bool(result.get("ok", false)):
		_bind_settings(_navigator.current_route_view() as SettingsModal)
	return result


func show_home_guide() -> Dictionary:
	var result := _navigator.show_modal(&"home_guide", {"initial_step": "swipe", "labels": _home_guide_labels()})
	if bool(result.get("ok", false)):
		var guide := _navigator.current_route_view() as HomeFirstRunGuide
		guide.skip_requested.connect(_skip_home_guide)
		guide.show_step(&"swipe", _reduced_motion(), _home_guide_labels())
		var home := _navigator.current_screen_view() as HomeScreen
		if home != null:
			home.navigation_set_active(true)
	return result


func show_mode_tutorial(mode: String) -> Dictionary:
	if _services.progress.tutorial_seen(&"mode", mode):
		return {"ok": true, "skipped": true}
	var description := _strings.text("tutorial_swap") if mode == "swap" else _strings.text("tutorial_drag")
	var result := _navigator.show_modal(&"mode_tutorial", {"mode": mode, "view_model": _system.guide(&"mode", description), "title": _strings.text("tutorial_title"), "skip_text": _strings.text("guide_skip"), "confirm_text": _strings.text("got_it")})
	if bool(result.get("ok", false)):
		var tutorial := _navigator.current_route_view() as ModeTutorialModal
		tutorial.completed.connect(_complete_mode_tutorial.bind(mode))
		tutorial.skipped.connect(_complete_mode_tutorial.bind(mode))
		tutorial.dismissed.connect(_dismiss_modal)
	return result


func close_modal() -> Dictionary:
	return _navigator.close_modal({"action": &"dismiss", "payload": {}})


func set_reduced_motion(enabled: bool) -> Dictionary:
	var result := _services.settings.set_value(&"reduced_motion_enabled", enabled)
	if bool(result.get("ok", false)):
		_apply_feedback_preferences()
		_navigator.set_reduced_motion(enabled)
	return result


func set_viewport(width: int, height: int) -> void:
	_debug_viewport = Vector2i(width, height)
	_game.get_window().size = _debug_viewport


func state_snapshot() -> Dictionary:
	var navigation := _navigator.debug_state_snapshot()
	var topic := _services.content.topic_by_id(_current_theme_id)
	var progress := _catalog.theme_progress(topic) if not topic.is_empty() else null
	return {
		"screen": _screen_name(), "modal": navigation.get("modal", ""), "topic_id": _current_theme_id,
		"level_id": _current_level_id, "mode": _current_mode if _screen_name() == "gameplay" else "",
		"viewport": [_reported_viewport().x, _reported_viewport().y], "reduced_motion": _reduced_motion(),
		"active_motion_count": _active_motion_count(), "motion_phase": navigation.get("motion_phase", "idle"),
		"transition_kind": navigation.get("transition_kind", ""), "gesture_progress": navigation.get("gesture_progress", 0.0),
		"completed_modes": progress.completed_modes if progress != null else 0, "total_modes": progress.total_modes if progress != null else 0,
		"progress_ratio": progress.ratio if progress != null else 0.0, "progress_paw_count": progress.paw_count if progress != null else 0,
		"theme_complete": progress.is_complete if progress != null else false,
	}


func runtime_metrics() -> Dictionary:
	var result := {"screen": _screen_name(), "topic": _current_theme_id, "level": _current_level_id, "mode": _current_mode}
	if is_instance_valid(_board):
		result.merge(_board.debug_runtime_metrics(), true)
	return result


func trigger_hint() -> void:
	if _screen_name() == "gameplay" and is_instance_valid(_board):
		_board.show_hint()


func shift_swap_rows(up: bool) -> void:
	if not is_instance_valid(_board):
		return
	if up:
		_board.shift_swap_rows_up()
	else:
		_board.shift_swap_rows_down()


func debug_board(method: StringName) -> void:
	if is_instance_valid(_board) and _board.has_method(method):
		_board.call(method)


func preview_complete() -> Dictionary:
	if _current_level_id.is_empty():
		var options := debug_level_options()
		if options.is_empty():
			return {"ok": false, "error": "not_found"}
		var option: Dictionary = options[0]
		return enter_level(str(option.topic_id), str(option.level_id), str(option.modes[0]))
	_show_completion()
	return {"ok": true}


func _bind_routes() -> void:
	var routes := {&"home": HomeScene, &"all_themes": AllThemesScene, &"levels": LevelsScene, &"gameplay": GameplayScene, &"mode_select": ModeSelectScene, &"settings": SettingsScene, &"home_guide": HomeGuideScene, &"mode_tutorial": ModeTutorialScene, &"completion": CompletionScene}
	for route in routes:
		_navigator.bind_route_scene(route, routes[route])
	_navigator.set_reduced_motion(_reduced_motion())


func _bind_home(screen: HomeScreen) -> void:
	if screen == null:
		return
	screen.selected_theme_changed.connect(_on_home_theme_changed)
	screen.theme_activated.connect(_on_home_theme_activated)
	screen.all_themes_requested.connect(show_all_themes)
	screen.menu_requested.connect(show_settings)
	_schedule_home_guide(screen)


func _bind_all_themes(screen: AllThemesScreen) -> void:
	if screen == null:
		return
	screen.close_requested.connect(_navigator.pop)
	screen.theme_activated.connect(func(theme_id: String, _rect: Rect2) -> void: show_levels(theme_id, "", true))


func _bind_levels(screen: RuntimeLevelListScreen) -> void:
	if screen == null:
		return
	screen.back_requested.connect(_navigator.pop)
	screen.level_selected.connect(func(level_id: String) -> void: show_mode_select(_current_theme_id, level_id))


func _bind_gameplay(screen: GameplayScreen) -> void:
	if screen == null:
		return
	screen.back_requested.connect(_return_to_levels)
	screen.hint_requested.connect(trigger_hint)
	screen.move_swap_up_requested.connect(shift_swap_rows.bind(true))
	screen.move_swap_down_requested.connect(shift_swap_rows.bind(false))


func _bind_mode_select(modal: RuntimeModeSelectModal) -> void:
	if modal == null:
		return
	modal.close_requested.connect(_dismiss_modal)
	modal.mode_selected.connect(_on_mode_selected)


func _bind_settings(modal: SettingsModal) -> void:
	if modal == null:
		return
	modal.setting_changed.connect(_on_setting_changed)
	modal.close_requested.connect(_dismiss_modal)


func _on_home_theme_changed(theme_id: String) -> void:
	_current_theme_id = theme_id
	_services.session.set_current(theme_id)
	if not _services.progress.tutorial_seen(&"home_swipe"):
		_services.progress.mark_tutorial_seen(&"home_swipe")
		var guide := _navigator.current_route_view() as HomeFirstRunGuide
		if guide != null:
			guide.set_step(&"enter", _reduced_motion(), _home_guide_labels())


func _on_home_theme_activated(theme_id: String) -> void:
	_record_home_enter()
	if String(_navigator.current_route()) == "home_guide":
		_pending_after_modal = func() -> void: show_levels(theme_id)
		close_modal()
		return
	show_levels(theme_id)


func _on_mode_selected(mode: StringName, policy: StringName) -> void:
	_pending_after_modal = func() -> void: enter_level(_current_theme_id, _current_level_id, String(mode), String(policy))
	close_modal()


func _on_setting_changed(key: StringName, enabled: bool) -> void:
	var changed := _services.settings.set_value(key, enabled)
	var modal := _navigator.current_route_view() as SettingsModal
	if modal == null:
		return
	if bool(changed.get("ok", false)):
		_apply_feedback_preferences()
		modal.render_view_model(_system.settings())
	else:
		modal.render_view_model(_system.settings({}, {key: str(changed.get("error", "save_failed"))}))


func _on_board_state_changed(_snapshot: Dictionary) -> void:
	if _current_theme_id.is_empty() or _current_level_id.is_empty() or _current_mode.is_empty() or not _board.should_persist_state():
		return
	_services.session.save_play_state(_board.session_snapshot(_current_theme_id, _current_level_id), _board.session_piece_ids())


func _on_board_completed() -> void:
	if not _completion_event_id.is_empty():
		return
	_completion_event_id = "%s:%s:%s:%d" % [_current_theme_id, _current_level_id, _current_mode, Time.get_ticks_msec()]
	_services.complete_mode(_current_theme_id, _current_level_id, _current_mode)
	_show_completion()


func _show_completion() -> void:
	if not String(_navigator.debug_state_snapshot().get("modal", "")).is_empty():
		_pending_after_modal = _show_completion
		close_modal()
		return
	if _completion_event_id.is_empty():
		_completion_event_id = "%s:%s:%s:%d" % [_current_theme_id, _current_level_id, _current_mode, Time.get_ticks_msec()]
	var level := _services.content.level_by_id(_current_theme_id, _current_level_id)
	var config := _services.content.level_config(level)
	var media := _services.content.level_media(config)
	var view_model := ViewModels.CompletionViewModel.new({"revision": 1, "theme_id": _current_theme_id, "level_id": _current_level_id, "mode": _current_mode, "completion_event_id": _completion_event_id, "title": _strings.text("complete"), "level_title": level.get("title", ""), "description": level.get("description", ""), "completed_texture": media.get("texture"), "primary_action_text": _strings.text("return_levels")})
	var result := _navigator.show_modal(&"completion", {"theme_id": _current_theme_id, "level_id": _current_level_id, "mode": _current_mode, "completion_event_id": _completion_event_id, "view_model": view_model})
	if bool(result.get("ok", false)):
		var modal := _navigator.current_route_view() as CompletionModal
		modal.confirm_requested.connect(_on_completion_confirmed)
		modal.dismissed.connect(_dismiss_modal)


func _on_completion_confirmed(_event_id: String) -> void:
	_pending_after_modal = _return_to_levels
	close_modal()


func _dismiss_modal() -> void:
	close_modal()


func _complete_mode_tutorial(mode: String) -> void:
	_services.progress.mark_tutorial_seen(&"mode", mode)
	close_modal()


func _return_to_levels() -> void:
	_persist_board()
	var focus := _current_level_id
	_clear_board()
	_navigator.pop()
	_current_mode = ""
	var view := _navigator.current_screen_view() as RuntimeLevelListScreen
	if view != null:
		view.refresh_view_model(_catalog.level_list(_current_theme_id, focus))


func _persist_board() -> void:
	if is_instance_valid(_board) and not _current_theme_id.is_empty() and not _current_level_id.is_empty() and not _current_mode.is_empty() and _board.should_persist_state():
		_services.session.save_play_state(_board.session_snapshot(_current_theme_id, _current_level_id), _board.session_piece_ids())


func _clear_board() -> void:
	if is_instance_valid(_board) and _board.is_node_ready():
		_board.clear()


func _refresh_board_blockers() -> void:
	var screen := _navigator.current_screen_view() as GameplayScreen
	if is_instance_valid(_board) and screen != null:
		_board.set_drag_blockers(screen.board_reserved_rects())


func _apply_feedback_preferences() -> void:
	if not is_instance_valid(_board):
		return
	var settings := _services.settings.snapshot()
	_board.set_feedback_preferences(bool(settings.get("haptics_enabled", true)), _reduced_motion())


func _schedule_home_guide(screen: HomeScreen) -> void:
	_cancel_home_guide_timer()
	if _services.progress.tutorial_seen(&"home_swipe") and _services.progress.tutorial_seen(&"home_enter"):
		return
	_home_guide_timer = _game.get_tree().create_timer(1.15)
	var show_when_current := func() -> void:
		if is_instance_valid(screen) and _screen_name() == "home" and _navigator.current_screen_view() is HomeScreen:
			show_home_guide()
	_home_guide_timer.timeout.connect(show_when_current, CONNECT_ONE_SHOT)


func _record_home_enter() -> void:
	_services.progress.mark_tutorial_seen(&"home_enter")


func _skip_home_guide() -> void:
	_services.progress.mark_tutorial_seen(&"home_swipe")
	_services.progress.mark_tutorial_seen(&"home_enter")
	close_modal()


func _home_guide_labels() -> Dictionary:
	return {"skip": _strings.text("guide_skip"), "swipe": _strings.text("guide_swipe"), "swipe_hint": _strings.text("guide_swipe_hint"), "enter": _strings.text("guide_enter"), "enter_hint": _strings.text("guide_enter_hint")}


func _cancel_home_guide_timer() -> void:
	_home_guide_timer = null


func _on_route_changed(route: StringName, payload: Dictionary) -> void:
	_state.update(route, payload)
	if not _pending_after_modal.is_valid() or not String(_navigator.debug_state_snapshot().get("modal", "")).is_empty():
		return
	var action := _pending_after_modal
	_pending_after_modal = Callable()
	_game.call_deferred("_run_runtime_action", action)


func run_deferred(action: Callable) -> void:
	if action.is_valid():
		action.call()


func _on_motion_preference_changed(_snapshot: Dictionary, _revision: int) -> void:
	_navigator.set_reduced_motion(_reduced_motion())
	_apply_feedback_preferences()


func _screen_name() -> String:
	return String(_navigator.current_screen_entry().get("route", ""))


func _active_motion_count() -> int:
	var result := int(_navigator.debug_state_snapshot().get("active_motion_count", 0))
	var screen := _navigator.current_screen_view()
	if screen != null and screen.has_method(&"active_motion_count"):
		result += int(screen.call(&"active_motion_count"))
	var modal := _navigator.current_route_view()
	if modal != null and modal.has_method(&"active_motion_count"):
		result += int(modal.call(&"active_motion_count"))
	return result


func _reduced_motion() -> bool:
	return bool(_services.motion_preferences.snapshot().get("reduced_motion", false))


func _reported_viewport() -> Vector2i:
	return _debug_viewport if _debug_viewport.x > 0 and _debug_viewport.y > 0 else _game.get_window().size


func _valid_theme_id(requested: String) -> String:
	return requested if not _services.content.topic_by_id(requested).is_empty() else _services.initial_home_theme_id()
