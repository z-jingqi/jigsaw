class_name RuntimeAppCoordinator
extends RefCounted

const AppServicesScript := preload("res://scripts/runtime/AppServices.gd")
const AppStateScript := preload("res://scripts/runtime/state/AppState.gd")
const ContentRepositoryScript := preload("res://scripts/runtime/data/ContentRepository.gd")
const ProgressRepositoryScript := preload("res://scripts/runtime/data/ProgressRepository.gd")
const SessionRepositoryScript := preload("res://scripts/runtime/data/SessionRepository.gd")
const BackgroundJsonStoreScript := preload("res://scripts/runtime/data/BackgroundJsonStore.gd")
const SettingsRepositoryScript := preload("res://scripts/runtime/data/SettingsRepository.gd")
const MotionPreferencesScript := preload("res://scripts/runtime/state/MotionPreferences.gd")
const CatalogPresenterScript := preload("res://scripts/runtime/presentation/CatalogPresenter.gd")
const SystemPresenterScript := preload("res://scripts/runtime/presentation/SystemPresenter.gd")
const GameStringsScript := preload("res://scripts/app/GameStrings.gd")
const PuzzleBoardScene := preload("res://scenes/gameplay/PuzzleBoard.tscn")
const ThemeLibraryScene := preload("res://scenes/screens/home/ThemeLibraryScreen.tscn")
const AlbumCoordinatorScript := preload("res://scripts/runtime/AlbumCoordinator.gd")
const AlbumPresenterScript := preload("res://scripts/runtime/presentation/AlbumPresenter.gd")
const GameplayPreparationScript := preload("res://scripts/runtime/GameplayPreparation.gd")
const CompletionFlowScript := preload("res://scripts/runtime/CompletionFlow.gd")
const AudioPlaybackScript := preload("res://scripts/audio/GameAudioPlayback.gd")
const AudioBindingsScript := preload("res://scripts/audio/GameAudioBindings.gd")

const HomeScene := preload("res://scenes/screens/HomeScreen.tscn")
const LevelsScene := preload("res://scenes/screens/LevelListScreen.tscn")
const GameplayScene := preload("res://scenes/screens/GameplayScreen.tscn")
const ModeSelectScene := preload("res://scenes/modals/BoxModeSelectModal.tscn")
const SettingsScene := preload("res://scenes/modals/SettingsModal.tscn")
const CompletionScene := preload("res://scenes/modals/CompletionModal.tscn")
const HomeGuideScene := preload("res://scenes/overlays/HomeFirstRunGuide.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")

var _edge_back: Node

var _game: Node2D
var _navigator: AppNavigator
var _world_host: Node2D
var _services: AppServices
var _state = AppStateScript.new()
var _catalog: CatalogPresenter
var _system: SystemPresenter
var _album: AlbumCoordinator
var _strings = GameStringsScript.new()
var _board: PuzzleBoard
var _theme_library_scroll := 0
var _current_theme_id := ""
var _current_level_id := ""
var _current_mode := ""
var _completion_event_id := ""
var _debug_viewport := Vector2i.ZERO
var _pending_after_modal: Callable
var _home_guide_timer: SceneTreeTimer
var _home_guide_action: Callable
var _dev_panel: Control
var _returning_to_levels := false
var _gameplay_preparation: Variant
var _completion_flow: Variant
var _audio_bindings: GameAudioBindings


func _init(game: Node2D) -> void:
	_game = game


func start() -> void:
	_strings.set_locale(GameStringsScript.detect_locale())
	var content := ContentRepositoryScript.new()
	var save_store := BackgroundJsonStoreScript.new()
	var progress := ProgressRepositoryScript.new(save_store)
	var session := SessionRepositoryScript.new(save_store)
	var settings := SettingsRepositoryScript.new()
	var motion := MotionPreferencesScript.new(settings)
	_services = AppServicesScript.new(content, progress, session, settings, motion)
	_services.load()
	_catalog = CatalogPresenterScript.new(content, progress, session, _strings)
	_system = SystemPresenterScript.new(settings, motion, _strings)
	_navigator = _game.get_node("AppNavigator") as AppNavigator
	_edge_back = preload("res://scripts/navigation/EdgeBackGesture.gd").new()
	_edge_back.navigator = _navigator
	_edge_back.commit_back = _commit_edge_back
	_game.add_child(_edge_back)
	_world_host = _game.get_node("WorldHost") as Node2D
	_completion_flow = CompletionFlowScript.new(_navigator, content, self)
	_bind_routes()
	_album = AlbumCoordinatorScript.new(_navigator, AlbumPresenterScript.new(content, _strings))
	_navigator.route_changed.connect(_on_route_changed)
	_navigator.input_lock_changed.connect(_on_navigation_input_lock_changed)
	_services.motion_preferences.changed.connect(_on_motion_preference_changed)
	_board = PuzzleBoardScene.instantiate() as PuzzleBoard
	_world_host.add_child(_board)
	_board.completed.connect(_on_board_completed)
	_board.state_changed.connect(_on_board_state_changed)
	_gameplay_preparation = GameplayPreparationScript.new(
		_navigator, _services, _catalog, _board, _world_host
	)
	var audio := AudioPlaybackScript.new()
	audio.name = "GameAudio"
	_game.add_child(audio)
	_services.audio = audio
	audio.configure(_services.settings)
	_audio_bindings = AudioBindingsScript.new()
	_game.add_child(_audio_bindings)
	_audio_bindings.configure(_game, _navigator, _board, audio)
	_apply_feedback_preferences()
	_game.get_viewport().size_changed.connect(_refresh_gameplay_layout, CONNECT_DEFERRED)
	_current_theme_id = _services.initial_home_theme_id()
	show_home(_current_theme_id)


func shutdown() -> void:
	_cancel_home_guide_timer()
	if is_instance_valid(_audio_bindings):
		_audio_bindings.shutdown()
	if _services != null and is_instance_valid(_services.audio):
		_services.audio.shutdown()
	if _completion_flow != null:
		_completion_flow.shutdown()
	if _gameplay_preparation != null:
		_gameplay_preparation.cancel()
	if _services != null:
		_services.progress.flush()
		_services.session.flush()
	_board = null
	_game = null


func handle_input(event: InputEvent) -> bool:
	if is_instance_valid(_edge_back) and _edge_back.handle_input(event):
		return true
	if not is_instance_valid(_board) or _navigator.is_input_locked():
		return false
	var screen := _navigator.current_screen_view() as GameplayScreen
	if screen == null or not screen.is_board_input_enabled():
		return false
	if String(_navigator.current_screen_entry().get("route", "")) != "gameplay":
		return false
	return _board.handle_input(
		event,
		(
			_board.completion_emitted
			or not String(_navigator.debug_state_snapshot().get("modal", "")).is_empty()
		)
	)


func debug_level_options() -> Array:
	var result: Array = []
	for topic in _services.content.topics():
		for level in topic.get("levels", []):
			if typeof(level) != TYPE_DICTIONARY:
				continue
			var modes := _services.content.available_modes(level)
			if modes.is_empty():
				continue
			result.append(
				{
					"label": "%s / %s" % [topic.get("name", ""), level.get("title", "")],
					"topic_id": topic.get("id", ""),
					"level_id": level.get("id", ""),
					"modes": modes
				}
			)
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
	var result := _navigator.set_root(
		&"home", {"theme_id": _current_theme_id, "view_model": _catalog.home(_current_theme_id)}
	)
	if bool(result.get("ok", false)):
		_bind_home(_navigator.current_screen_view() as HomeScreen)
	return result


func show_levels(
	theme_id: String,
	focus_level_id := "",
	replace := false,
	transition_source_rect := Rect2(),
	transition_source_texture: Texture2D = null
) -> Dictionary:
	var topic := _services.content.topic_by_id(theme_id)
	if topic.is_empty() or topic.get("levels", []).is_empty():
		return {"ok": false, "error": "not_found"}
	_clear_board()
	_current_theme_id = theme_id
	_current_level_id = focus_level_id
	_current_mode = ""
	_services.session.set_current(theme_id, focus_level_id)
	var payload := {
		"theme_id": theme_id,
		"focus_level_id": focus_level_id,
		"view_model": _catalog.level_list(theme_id, focus_level_id),
		"_transition_source_rect": transition_source_rect,
		"_transition_source_texture": transition_source_texture,
	}
	var result := (
		_navigator.replace(&"levels", payload) if replace else _navigator.push(&"levels", payload)
	)
	if bool(result.get("ok", false)):
		_bind_levels(_navigator.current_screen_view() as RuntimeLevelListScreen)
	return result


func show_mode_select(theme_id: String, level_id: String) -> Dictionary:
	if _navigator.current_route() == &"mode_select":
		return {"ok": false, "error": "modal_busy"}
	var level := _services.content.level_by_id(theme_id, level_id)
	if level.is_empty():
		return {"ok": false, "error": "not_found"}
	# Prepare gameplay pixels before either page starts moving.
	_services.content.level_media(_services.content.level_config(level))
	_current_theme_id = theme_id
	_current_level_id = level_id
	var box_payload := preload("res://scripts/runtime/presentation/BoxPreviewData.gd").build(
		_services.content, level
	)
	var box_source := Rect2()
	var list := _navigator.current_screen_view() as RuntimeLevelListScreen
	if list != null:
		box_source = list.debug_box_rect(level_id)
		list.call("set_box_transition_source", level_id, true)
	var result := _navigator.show_modal(
		&"mode_select",
		{
			"theme_id": theme_id,
			"level_id": level_id,
			"view_model": _catalog.mode_select(theme_id, level_id),
			"box_preview": box_payload,
			"box_source_rect": box_source
		}
	)
	if bool(result.get("ok", false)):
		var modal := _navigator.current_route_view() as RuntimeModeSelectModal
		_bind_mode_select(modal)
		if list != null:
			var source: WeakRef = weakref(list)
			var restore_source := func() -> void:
				var screen: Node = source.get_ref()
				if is_instance_valid(screen):
					screen.call("set_box_transition_source", level_id, false)
			modal.tree_exiting.connect(restore_source)
			if modal.has_signal("box_returned"):
				modal.connect("box_returned", restore_source)
			if modal.has_signal("box_closing"):
				modal.connect(
					"box_closing",
					func() -> void:
						var screen: Node = source.get_ref()
						if is_instance_valid(screen):
							# Recenter a clicked moving page only behind an opaque modal.
							# An immediate Back returns to the still-visible frozen source.
							if modal.background.modulate.a >= 0.98:
								screen.prepare_box_return(level_id)
							modal.update_box_source_rect(screen.debug_box_rect(level_id))
				)
		_services.progress.mark_level_visited(theme_id, level_id)
		var levels := _navigator.current_screen_view() as RuntimeLevelListScreen
		if levels != null:
			levels.refresh_view_model(_catalog.level_list(theme_id, level_id))
	elif list != null:
		list.call("set_box_transition_source", level_id, false)
	return result


func enter_level(
	theme_id: String, level_id: String, mode: String, start_policy := "start"
) -> Dictionary:
	# Repeated activation during a handoff must not rebuild or clear the same board.
	if (
		_navigator.current_route() == &"gameplay"
		and _current_theme_id == theme_id
		and _current_level_id == level_id
		and _current_mode == mode
	):
		return {"ok": true, "unchanged": true}
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
	var payload := {
		"theme_id": theme_id,
		"level_id": level_id,
		"mode": mode,
		"start_policy": start_policy,
		"view_model": _catalog.gameplay(theme_id, level_id, mode),
		"_prepare_before_motion":
		(
			_navigator.current_route() in [&"mode_select", &"completion"]
			and not (
				OS.get_environment("JIGSAW_CURVED_EDGE_PREVIEW") == "1"
				and mode in ["polygon", "knob"]
			)
		),
	}
	var result: Dictionary
	if _navigator.current_route() == &"completion":
		result = _navigator.replace_from_modal(&"gameplay", payload)
	elif _navigator.current_route() == &"mode_select":
		result = _navigator.push_from_modal(
			&"gameplay",
			payload,
			_gameplay_preparation.take_screen(theme_id, level_id, mode, start_policy)
		)
	else:
		result = _navigator.push(&"gameplay", payload)
	if bool(result.get("ok", false)):
		var screen := _navigator.current_screen_view() as GameplayScreen
		_bind_gameplay(screen)
		_game.call_deferred("_start_runtime_board", screen)
	return result


func start_runtime_board(screen: GameplayScreen) -> void:
	if (
		not is_instance_valid(screen)
		or screen.is_queued_for_deletion()
		or _navigator.current_screen_view() != screen
		or _current_mode.is_empty()
	):
		return
	_apply_feedback_preferences()
	var loaded: bool = await _gameplay_preparation.prepare_live(
		screen, _current_theme_id, _current_level_id, _current_mode
	)
	if not loaded or not is_instance_valid(screen) or _navigator.current_screen_view() != screen:
		return
	screen.mark_board_live()
	_refresh_board_blockers()
	# Preparation has already rendered the complete board behind the mode page.
	if is_instance_valid(screen):
		_navigator.reveal_prepared_screen(screen)
	if _board.completion_emitted:
		await _navigator.wait_until_idle()
		if is_instance_valid(screen) and _navigator.current_screen_view() == screen:
			_on_board_completed()


func show_settings() -> Dictionary:
	var labels := {
		"title": _strings.text("settings_title"),
		"haptics": _strings.text("haptics"),
		"music": _strings.text("music"),
		"sound_effects": _strings.text("sfx"),
		"snap_preview": _strings.text("snap_preview"),
		"reduced_motion": _strings.text("reduce_motion")
	}
	var result := _navigator.show_modal(
		&"settings", {"view_model": _system.settings(), "labels": labels}
	)
	if bool(result.get("ok", false)):
		_bind_settings(_navigator.current_route_view() as SettingsModal)
	return result


func show_home_guide() -> Dictionary:
	var result := _navigator.show_modal(
		&"home_guide", {"initial_step": "swipe", "labels": _home_guide_labels()}
	)
	if bool(result.get("ok", false)):
		var guide := _navigator.current_route_view() as HomeFirstRunGuide
		guide.skip_requested.connect(_skip_home_guide)
		guide.show_step(&"swipe", _reduced_motion(), _home_guide_labels())
		var home := _navigator.current_screen_view() as HomeScreen
		if home != null:
			home.navigation_set_active(true)
	return result


func close_modal() -> Dictionary:
	if is_instance_valid(_edge_back):
		_edge_back.cancel()
	var view := _navigator.current_route_view()
	if view != null and view.has_method("needs_box_close") and view.needs_box_close():
		view.request_close()
		return {"ok": true}
	if _navigator.current_route() == &"completion":
		return _return_to_levels()
	if _navigator.current_route() == &"mode_select":
		_gameplay_preparation.cancel()
	return _navigator.close_modal({"action": &"dismiss", "payload": {}})


func set_reduced_motion(enabled: bool) -> Dictionary:
	var result := _services.settings.set_value(&"reduced_motion_enabled", enabled)
	if bool(result.get("ok", false)):
		_apply_feedback_preferences()
		_navigator.set_reduced_motion(enabled)
		_apply_reduced_motion_to_active_views(enabled)
	return result


func set_viewport(width: int, height: int) -> void:
	_debug_viewport = Vector2i(width, height)
	_game.get_window().size = _debug_viewport


func state_snapshot() -> Dictionary:
	var navigation := _navigator.debug_state_snapshot()
	var topic := _services.content.topic_by_id(_current_theme_id)
	var progress := _catalog.theme_progress(topic) if not topic.is_empty() else null
	return {
		"screen": _screen_name(),
		"modal": navigation.get("modal", ""),
		"topic_id": _current_theme_id,
		"level_id": _current_level_id,
		"mode": _current_mode if _screen_name() == "gameplay" else "",
		"viewport": [_reported_viewport().x, _reported_viewport().y],
		"reduced_motion": _reduced_motion(),
		"active_motion_count": _active_motion_count(),
		"motion_phase": navigation.get("motion_phase", "idle"),
		"transition_kind": navigation.get("transition_kind", ""),
		"gesture_progress": navigation.get("gesture_progress", 0.0),
		"completed_modes": progress.completed_modes if progress != null else 0,
		"total_modes": progress.total_modes if progress != null else 0,
		"progress_ratio": progress.ratio if progress != null else 0.0,
		"progress_paw_count": progress.paw_count if progress != null else 0,
		"theme_complete": progress.is_complete if progress != null else false,
	}


func runtime_metrics() -> Dictionary:
	var result := {
		"screen": _screen_name(),
		"topic": _current_theme_id,
		"level": _current_level_id,
		"mode": _current_mode
	}
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


func shift_swap_columns(direction: int) -> void:
	if is_instance_valid(_board):
		_board.shift_swap_columns(direction)


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
	var routes := {
		&"home": HomeScene,
		&"themes": ThemeLibraryScene,
		&"levels": LevelsScene,
		&"gameplay": GameplayScene,
		&"mode_select": ModeSelectScene,
		&"settings": SettingsScene,
		&"home_guide": HomeGuideScene,
		&"completion": CompletionScene
	}
	for route in routes:
		_navigator.bind_route_scene(route, routes[route])
	_navigator.set_reduced_motion(_reduced_motion())


func _bind_home(screen: HomeScreen) -> void:
	if screen == null or screen.has_meta("runtime_coordinator_bound"):
		return
	screen.set_meta("runtime_coordinator_bound", true)
	screen.selected_theme_changed.connect(_on_home_theme_changed)
	screen.theme_activated.connect(_on_home_theme_activated)
	screen.menu_requested.connect(show_settings)
	screen.themes_requested.connect(_show_theme_library)
	screen.album_requested.connect(show_album)
	_schedule_home_guide(screen)


func show_album() -> Dictionary:
	_cancel_home_guide_timer()
	return _album.open()


func show_album_artwork(theme_id: String, level_id: String) -> Dictionary:
	return _album.open_artwork(theme_id, level_id)


func _show_theme_library() -> void:
	var home := _navigator.current_screen_view() as HomeScreen
	if home == null:
		return
	var result := (
		_navigator
		. push(
			&"themes",
			{
				"view_model": _catalog.home(_current_theme_id),
				"scroll_position": _theme_library_scroll,
			}
		)
	)
	if not bool(result.get("ok", false)):
		return
	var library := _navigator.current_screen_view()
	library.close_requested.connect(
		func() -> void:
			_theme_library_scroll = library.scroll_position()
			_navigator.pop()
	)
	library.theme_selected.connect(
		func(theme_id: String) -> void:
			_theme_library_scroll = library.scroll_position()
			var entered := show_levels(theme_id)
			if bool(entered.get("ok", false)):
				home.select_theme(theme_id)
	)


func _bind_levels(screen: RuntimeLevelListScreen) -> void:
	if screen == null or screen.has_meta("runtime_coordinator_bound"):
		return
	screen.set_meta("runtime_coordinator_bound", true)
	screen.back_requested.connect(_navigator.pop)
	screen.level_selected.connect(_on_level_focused)


func _bind_gameplay(screen: GameplayScreen) -> void:
	if screen == null or screen.has_meta("runtime_coordinator_bound"):
		return
	screen.set_meta("runtime_coordinator_bound", true)
	screen.attach_board_host(_world_host)
	screen.set_reduced_motion(_reduced_motion())
	screen.set_navigation_locked(_navigator.is_input_locked())
	screen.back_requested.connect(_return_to_levels)
	screen.hint_requested.connect(trigger_hint)
	screen.move_swap_up_requested.connect(shift_swap_rows.bind(true))
	screen.move_swap_down_requested.connect(shift_swap_rows.bind(false))
	screen.move_swap_left_requested.connect(shift_swap_columns.bind(-1))
	screen.move_swap_right_requested.connect(shift_swap_columns.bind(1))


func _bind_mode_select(modal: RuntimeModeSelectModal) -> void:
	if modal == null or modal.has_meta("runtime_coordinator_bound"):
		return
	modal.set_meta("runtime_coordinator_bound", true)
	modal.close_requested.connect(_dismiss_modal)
	if modal.has_signal("box_closing"):
		modal.connect("box_closing", _gameplay_preparation.cancel)
	modal.mode_selected.connect(_on_mode_selected)
	modal.selection_changed.connect(_on_mode_preparation_requested)
	var selection := modal.preparation_selection()
	if not selection.is_empty():
		_on_mode_preparation_requested(selection.mode, selection.start_policy)


func _on_mode_preparation_requested(mode: StringName, policy: StringName) -> void:
	var modal := _navigator.current_route_view() as RuntimeModeSelectModal
	if modal != null:
		_gameplay_preparation.request(
			modal, _current_theme_id, _current_level_id, String(mode), String(policy)
		)


func _bind_settings(modal: SettingsModal) -> void:
	if modal == null or modal.has_meta("runtime_coordinator_bound"):
		return
	modal.set_meta("runtime_coordinator_bound", true)
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
	var home := _navigator.current_screen_view() as HomeScreen
	show_levels(
		theme_id,
		"",
		false,
		home.transition_source_rect() if home != null else Rect2(),
		home.transition_source_texture() if home != null else null
	)


func _on_mode_selected(mode: StringName, policy: StringName) -> void:
	enter_level(_current_theme_id, _current_level_id, String(mode), String(policy))


func _on_level_focused(level_id: String) -> void:
	_current_level_id = level_id
	_current_mode = ""
	_services.session.set_current(_current_theme_id, level_id)
	show_mode_select(_current_theme_id, level_id)


func _on_setting_changed(key: StringName, enabled: bool) -> void:
	var changed := _services.settings.set_value(key, enabled)
	var modal := _navigator.current_route_view() as SettingsModal
	if modal == null:
		return
	if bool(changed.get("ok", false)):
		_apply_feedback_preferences()
		modal.render_view_model(_system.settings())
	else:
		modal.render_view_model(
			_system.settings({}, {key: str(changed.get("error", "save_failed"))})
		)


func _on_board_state_changed(_snapshot: Dictionary) -> void:
	var screen := _navigator.current_screen_view() as GameplayScreen
	if screen == null or not screen.has_live_board():
		return
	if (
		_current_theme_id.is_empty()
		or _current_level_id.is_empty()
		or _current_mode.is_empty()
		or not _board.should_persist_state()
	):
		return
	_services.session.save_play_state(
		_board.session_snapshot(_current_theme_id, _current_level_id), _board.session_piece_ids()
	)


func _on_board_completed() -> void:
	var screen := _navigator.current_screen_view() as GameplayScreen
	if (
		not _completion_event_id.is_empty()
		or _current_mode.is_empty()
		or screen == null
		or not screen.is_board_input_enabled()
	):
		return
	_completion_event_id = (
		"%s:%s:%s:%d" % [_current_theme_id, _current_level_id, _current_mode, Time.get_ticks_msec()]
	)
	_services.complete_mode(_current_theme_id, _current_level_id, _current_mode)
	if screen != null:
		screen.prepare_completion()
	var event_id := _completion_event_id
	if not _reduced_motion():
		# Present the final snap before building the completion view on the next frame.
		await RenderingServer.frame_post_draw
	if (
		not is_instance_valid(_game)
		or _completion_event_id != event_id
		or _navigator.current_route() != &"gameplay"
	):
		return
	_show_completion()


func _show_completion() -> void:
	if not String(_navigator.debug_state_snapshot().get("modal", "")).is_empty():
		_pending_after_modal = _show_completion
		close_modal()
		return
	if _completion_event_id.is_empty():
		_completion_event_id = (
			"%s:%s:%s:%d"
			% [_current_theme_id, _current_level_id, _current_mode, Time.get_ticks_msec()]
		)
	var level := _services.content.level_by_id(_current_theme_id, _current_level_id)
	var presentation := _board.completion_presentation()
	var view_model := (
		ViewModels
		. CompletionViewModel
		. new(
			{
				"revision": 1,
				"theme_id": _current_theme_id,
				"level_id": _current_level_id,
				"mode": _current_mode,
				"completion_event_id": _completion_event_id,
				"level_title": level.get("title", ""),
				"level_description": level.get("description", ""),
				"completed_texture": presentation.get("texture"),
				"source_rect": presentation.get("rect", Rect2()),
				"primary_action_text": _strings.text("completion_next"),
				"secondary_action_text": _strings.text("back"),
				"has_next_level":
				not (
					_completion_flow
					. next_level(_current_theme_id, _current_level_id, _current_mode)
					. is_empty()
				),
			}
		)
	)
	var result := _navigator.show_modal(
		&"completion",
		{
			"theme_id": _current_theme_id,
			"level_id": _current_level_id,
			"mode": _current_mode,
			"completion_event_id": _completion_event_id,
			"view_model": view_model
		}
	)
	if bool(result.get("ok", false)):
		var modal := _navigator.current_route_view() as CompletionModal
		_completion_flow.bind(modal, view_model)


func restore_completion_context(context: Dictionary) -> void:
	_current_theme_id = str(context.get("theme_id", ""))
	_current_level_id = str(context.get("level_id", ""))
	_current_mode = str(context.get("mode", ""))
	_completion_event_id = str(context.get("completion_event_id", ""))
	_services.session.set_current(_current_theme_id, _current_level_id, _current_mode)
	_clear_board()


func _dismiss_modal() -> void:
	close_modal()


func _return_to_levels() -> Dictionary:
	# Resolve entry ownership before marking return, without completing its visual
	# pose. Back must also interrupt a board/HUD that is still entering.
	_navigator.interrupt_active_transition()
	_persist_board()
	_board.cancel_pending_preparation()
	var levels := _navigator.previous_screen_view() as RuntimeLevelListScreen
	if levels != null:
		levels.refresh_view_model(_catalog.level_list(_current_theme_id, _current_level_id))
	_returning_to_levels = true
	var result := (
		_navigator.pop_from_modal()
		if _navigator.current_route() == &"completion"
		else _navigator.pop()
	)
	if not bool(result.get("ok", false)):
		_returning_to_levels = false
	return result


func _persist_board() -> void:
	var screen := _navigator.current_screen_view() as GameplayScreen
	if screen == null or not screen.has_live_board():
		return
	if (
		is_instance_valid(_board)
		and not _current_theme_id.is_empty()
		and not _current_level_id.is_empty()
		and not _current_mode.is_empty()
		and _board.should_persist_state()
	):
		_services.session.save_play_state(
			_board.session_snapshot(_current_theme_id, _current_level_id),
			_board.session_piece_ids()
		)


func _clear_board() -> void:
	if is_instance_valid(_board) and _board.is_node_ready():
		_board.clear()


func _refresh_board_blockers() -> void:
	var screen := _navigator.current_screen_view() as GameplayScreen
	if is_instance_valid(_board) and screen != null:
		_board.set_drag_blockers(screen.board_reserved_rects())


func _refresh_gameplay_layout() -> void:
	var screen := _navigator.current_screen_view() as GameplayScreen
	if screen == null:
		return
	preload("res://scripts/gameplay/board/BoardViewportLayout.gd").refresh(_board, screen)


func _apply_feedback_preferences() -> void:
	if not is_instance_valid(_board):
		return
	var settings := _services.settings.snapshot()
	_board.set_feedback_preferences(bool(settings.get("haptics_enabled", true)), _reduced_motion())
	_board.set_snap_preview_enabled(bool(settings.get("snap_preview_enabled", true)))


func _schedule_home_guide(screen: HomeScreen) -> void:
	_cancel_home_guide_timer()
	if (
		_services.progress.tutorial_seen(&"home_swipe")
		and _services.progress.tutorial_seen(&"home_enter")
	):
		return
	_home_guide_timer = _game.get_tree().create_timer(1.15)
	var screen_ref: WeakRef = weakref(screen)
	_home_guide_action = func() -> void:
		if (
			screen_ref.get_ref() != null
			and _screen_name() == "home"
			and _navigator.current_screen_view() == screen_ref.get_ref()
		):
			show_home_guide()
	_home_guide_timer.timeout.connect(_home_guide_action, CONNECT_ONE_SHOT)


func _record_home_enter() -> void:
	_services.progress.mark_tutorial_seen(&"home_enter")


func _skip_home_guide() -> void:
	_services.progress.mark_tutorial_seen(&"home_swipe")
	_services.progress.mark_tutorial_seen(&"home_enter")
	close_modal()


func _home_guide_labels() -> Dictionary:
	return {
		"skip": _strings.text("guide_skip"),
		"swipe": _strings.text("guide_swipe"),
		"swipe_hint": _strings.text("guide_swipe_hint"),
		"enter": _strings.text("guide_enter"),
		"enter_hint": _strings.text("guide_enter_hint")
	}


func _cancel_home_guide_timer() -> void:
	if _home_guide_timer != null and _home_guide_action.is_valid():
		if _home_guide_timer.timeout.is_connected(_home_guide_action):
			_home_guide_timer.timeout.disconnect(_home_guide_action)
	_home_guide_action = Callable()
	_home_guide_timer = null


func _on_navigation_input_lock_changed(is_locked: bool) -> void:
	var screen := _navigator.current_screen_view() as GameplayScreen
	if screen != null:
		screen.set_navigation_locked(is_locked)
	if is_locked and is_instance_valid(_board):
		_board.cancel_interaction()
	if not is_locked and _navigator.current_route() != &"levels":
		_returning_to_levels = false
	if (
		not is_locked
		and _navigator.current_route() == &"mode_select"
		and _navigator.current_screen_entry().get("route") == &"levels"
		and not _current_mode.is_empty()
	):
		# A cancelled entrance has released its page; invalidate unfinished build
		# batches so they cannot leave a second board behind the mode picker.
		_clear_board()
		_current_mode = ""
		_gameplay_preparation.cancel()
		var modal := _navigator.current_route_view() as RuntimeModeSelectModal
		if modal != null:
			var selection := modal.preparation_selection()
			if not selection.is_empty():
				_on_mode_preparation_requested(selection.mode, selection.start_policy)


func _on_route_changed(route: StringName, payload: Dictionary) -> void:
	_state.update(route, payload)
	if route not in [&"mode_select", &"gameplay"]:
		_gameplay_preparation.cancel()
	if route == &"levels" and _returning_to_levels:
		_returning_to_levels = false
		_clear_board()
		_current_mode = ""
	if (
		not _pending_after_modal.is_valid()
		or not String(_navigator.debug_state_snapshot().get("modal", "")).is_empty()
	):
		return
	var action := _pending_after_modal
	_pending_after_modal = Callable()
	_game.call_deferred("_run_runtime_action", action)


func run_deferred(action: Callable) -> void:
	if action.is_valid():
		action.call()


func _on_motion_preference_changed(_snapshot: Dictionary, _revision: int) -> void:
	var enabled := _reduced_motion()
	_navigator.set_reduced_motion(enabled)
	_apply_reduced_motion_to_active_views(enabled)
	_apply_feedback_preferences()


func _apply_reduced_motion_to_active_views(enabled: bool) -> void:
	var screen := _navigator.current_screen_view()
	if screen != null and screen.has_method(&"set_reduced_motion"):
		screen.call(&"set_reduced_motion", enabled)
	var route_view := _navigator.current_route_view()
	if route_view != null and route_view != screen and route_view.has_method(&"set_reduced_motion"):
		route_view.call(&"set_reduced_motion", enabled)


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
	return (
		_debug_viewport
		if _debug_viewport.x > 0 and _debug_viewport.y > 0
		else _game.get_window().size
	)


func _valid_theme_id(requested: String) -> String:
	return (
		requested
		if not _services.content.topic_by_id(requested).is_empty()
		else _services.initial_home_theme_id()
	)


func _commit_edge_back() -> void:
	match _navigator.current_route():
		&"gameplay", &"completion":
			_return_to_levels()
		&"mode_select":
			_gameplay_preparation.cancel()
			_navigator.close_modal({"action": &"dismiss", "payload": {}})
		_:
			if not String(_navigator.debug_state_snapshot().get("modal", "")).is_empty():
				close_modal()
			else:
				_navigator.pop()
