extends Node2D

const TopicsScreenScript := preload("res://scripts/catalog/TopicsScreen.gd")
const MODE_TITLE_SIDE_DECORATION_PATH := "res://assets/ui/mode_title_side_decoration.png"
const ICON_MODE_KNOB_DONE_PATH := "res://assets/icons/status/mode_knob_done.png"
const ICON_MODE_KNOB_TODO_PATH := "res://assets/icons/status/mode_knob_todo.png"
const ICON_MODE_POLYGON_DONE_PATH := "res://assets/icons/status/mode_polygon_done.png"
const ICON_MODE_POLYGON_TODO_PATH := "res://assets/icons/status/mode_polygon_todo.png"
const ICON_MODE_SWAP_DONE_PATH := "res://assets/icons/status/mode_swap_done.png"
const ICON_MODE_SWAP_TODO_PATH := "res://assets/icons/status/mode_swap_todo.png"
const MODAL_TUTORIAL_DRAG_PATH := "res://assets/ui/modals/tutorial-drag.png"
const MODAL_TUTORIAL_SWAP_PATH := "res://assets/ui/modals/tutorial-swap.png"
const MODAL_SETTING_VIBRATION_PATH := "res://assets/ui/modals/setting-vibration.png"
const MODAL_SETTING_MUSIC_PATH := "res://assets/ui/modals/setting-music.png"
const MODAL_SETTING_SFX_PATH := "res://assets/ui/modals/setting-sfx.png"
const CatalogScrollControllerScript := preload("res://scripts/catalog/CatalogScrollController.gd")
const TopicPagerControllerScript := preload("res://scripts/catalog/TopicPagerController.gd")
const TopicHomeMotionScript := preload("res://scripts/catalog/TopicHomeMotion.gd")
const DevTestPanelScript := preload("res://scripts/debug/DevTestPanel.gd")
const GameDebugAdapterScript := preload("res://scripts/debug/GameDebugAdapter.gd")
const GameHudScript := preload("res://scripts/gameplay/GameHud.gd")
const GameDialogsScript := preload("res://scripts/gameplay/GameDialogs.gd")
const GameSessionControllerScript := preload("res://scripts/gameplay/GameSessionController.gd")
const GameplayRuntimeHostScript := preload("res://scripts/gameplay/runtime/GameplayRuntimeHost.gd")
const CompletionRuntimeHostScript := preload("res://scripts/gameplay/runtime/CompletionRuntimeHost.gd")
const GameStringsScript := preload("res://scripts/app/GameStrings.gd")
const GameModalHostScript := preload("res://scripts/app/GameModalHost.gd")
const GameTextureServiceScript := preload("res://scripts/catalog/GameTextureService.gd")
const GameUiMotionScript := preload("res://scripts/app/GameUiMotion.gd")
const GameUiFactoryScript := preload("res://scripts/app/GameUiFactory.gd")
const LevelPlayPolicyScript := preload("res://scripts/catalog/LevelPlayPolicy.gd")
const LevelListScreenScript := preload("res://scripts/catalog/LevelListScreen.gd")
const LevelCardFactoryScript := preload("res://scripts/catalog/LevelCardFactory.gd")
const LevelUnlockAnimatorScript := preload("res://scripts/catalog/LevelUnlockAnimator.gd")
const LevelRepositoryScript := preload("res://scripts/catalog/LevelRepository.gd")
const ProgressStoreScript := preload("res://scripts/progress/ProgressStore.gd")
const SessionRepositoryScript := preload("res://scripts/runtime/data/SessionRepository.gd")
const SettingsRepositoryScript := preload("res://scripts/runtime/data/SettingsRepository.gd")
const MotionPreferencesScript := preload("res://scripts/runtime/state/MotionPreferences.gd")
const SystemPresenterScript := preload("res://scripts/runtime/presentation/SystemPresenter.gd")
const SettingsRuntimeHostScript := preload("res://scripts/gameplay/runtime/SettingsRuntimeHost.gd")
const PuzzleBoardScene := preload("res://scenes/gameplay/PuzzleBoard.tscn")
const UnlockRevealEffectScript := preload("res://scripts/effects/UnlockRevealEffect.gd")
## Compatibility alias used by the validation suite and debug tooling.
const LEVEL_LIST_THUMBNAIL_SIZE := Vector2i(450, 600)
const UI_ICON_BUTTON_SIZE := 64.0
const UI_ICON_INSET := 8.0
const HUD_DEBUG_MEASUREMENTS := false
const BUTTON_BOUNDS_DEBUG := false
const BUTTON_BOUNDS_DEBUG_COLOR := Color(0.16, 0.56, 1.0, 0.20)
const HUD_TEXT_BUTTON_FONT_SIZE := 22
var orange := Color("#D9933F")
var deep_orange := Color("#C77C2E")
var brown := Color("#5A3A22")
var soft_brown := Color("#8A6847")
var green := Color("#6f9d67")

var texture: Texture2D
var topics_screen
var catalog_scroll_controller
var topic_pager_controller
var topic_home_motion
var game_strings = GameStringsScript.new()
var modal_host = GameModalHostScript.new()
var repository = LevelRepositoryScript.new()
var texture_service
var mode_title_side_decoration_texture: Texture2D
var icon_mode_knob_done: Texture2D
var icon_mode_knob_todo: Texture2D
var icon_mode_polygon_done: Texture2D
var icon_mode_polygon_todo: Texture2D
var icon_mode_swap_done: Texture2D
var icon_mode_swap_todo: Texture2D
var modal_tutorial_drag_texture: Texture2D
var modal_tutorial_swap_texture: Texture2D
var modal_setting_vibration_texture: Texture2D
var modal_setting_music_texture: Texture2D
var modal_setting_sfx_texture: Texture2D
var source_image: Image
var source_size := Vector2.ZERO
var active_level_config := {}
var puzzle_board: PuzzleBoard
var ui_layer: CanvasLayer
var dev_layer: CanvasLayer
var dev_panel: Control
var debug_adapter
var game_hud
var gameplay_runtime_host
var completion_runtime_host
var settings_runtime_host
var game_dialogs
var game_session = GameSessionControllerScript.new()
var ui_motion
var ui_factory = GameUiFactoryScript.new()
var screen_root: Control
var modal_root: Control
var current_modal := ""

var topics: Array[Dictionary] = []
var progress_store = ProgressStoreScript.new()
var session_repository = SessionRepositoryScript.new()
var settings_repository = SettingsRepositoryScript.new()
var motion_preferences
var system_presenter
var level_play_policy
var level_list_screen
var level_card_factory
var level_unlock_animator
var current_topic: Dictionary = {}
var current_level: Dictionary = {}
var current_mode := "knob"
var current_screen := "home"
var modal_open := false
var topics_content: Control
var topics_content_height := 0.0
var topics_scroll_offset := 0.0
var topics_scroll_velocity := 0.0
var topics_inertia_active := false
var topics_drag_active := false
var topics_drag_total := Vector2.ZERO
var topics_drag_last_msec := 0
var topics_island_items: Array[Dictionary] = []
var level_virtual_items: Array[Dictionary] = []
var level_virtual_nodes: Dictionary = {}
var level_virtual_overscan := 0.0

var unlock_effect_style := "fire" # unlock reveal effect: "fire" or "shatter"
var unlock_reveal_effect = UnlockRevealEffectScript.new()
var active_locale := "en"
var newly_unlocked_topic_id := ""
var newly_unlocked_level_id := ""


func _ready() -> void:
	_lock_portrait_orientation()
	topics_screen = TopicsScreenScript.new(self)
	catalog_scroll_controller = CatalogScrollControllerScript.new(self)
	topic_pager_controller = TopicPagerControllerScript.new(self)
	topic_home_motion = TopicHomeMotionScript.new(self)
	debug_adapter = GameDebugAdapterScript.new(self)
	game_hud = GameHudScript.new(self)
	gameplay_runtime_host = GameplayRuntimeHostScript.new(self)
	completion_runtime_host = CompletionRuntimeHostScript.new(self)
	settings_runtime_host = SettingsRuntimeHostScript.new(self)
	game_dialogs = GameDialogsScript.new(self)
	texture_service = GameTextureServiceScript.new(repository)
	mode_title_side_decoration_texture = repository.cached_texture(MODE_TITLE_SIDE_DECORATION_PATH)
	icon_mode_knob_done = repository.cached_texture(ICON_MODE_KNOB_DONE_PATH)
	icon_mode_knob_todo = repository.cached_texture(ICON_MODE_KNOB_TODO_PATH)
	icon_mode_polygon_done = repository.cached_texture(ICON_MODE_POLYGON_DONE_PATH)
	icon_mode_polygon_todo = repository.cached_texture(ICON_MODE_POLYGON_TODO_PATH)
	icon_mode_swap_done = repository.cached_texture(ICON_MODE_SWAP_DONE_PATH)
	icon_mode_swap_todo = repository.cached_texture(ICON_MODE_SWAP_TODO_PATH)
	modal_tutorial_drag_texture = repository.cached_texture(MODAL_TUTORIAL_DRAG_PATH)
	modal_tutorial_swap_texture = repository.cached_texture(MODAL_TUTORIAL_SWAP_PATH)
	modal_setting_vibration_texture = repository.cached_texture(MODAL_SETTING_VIBRATION_PATH)
	modal_setting_music_texture = repository.cached_texture(MODAL_SETTING_MUSIC_PATH)
	modal_setting_sfx_texture = repository.cached_texture(MODAL_SETTING_SFX_PATH)
	progress_store.load_from_disk()
	session_repository.load()
	settings_repository.load()
	motion_preferences = MotionPreferencesScript.new(settings_repository)
	system_presenter = SystemPresenterScript.new(settings_repository, motion_preferences, game_strings)
	ui_motion = GameUiMotionScript.new(self, motion_preferences)
	level_play_policy = LevelPlayPolicyScript.new(repository, progress_store, session_repository)
	level_list_screen = LevelListScreenScript.new(self)
	level_card_factory = LevelCardFactoryScript.new(self)
	level_unlock_animator = LevelUnlockAnimatorScript.new(self)
	active_locale = _detect_locale()
	game_strings.set_locale(active_locale)
	repository.set_locale(active_locale)
	puzzle_board = PuzzleBoardScene.instantiate() as PuzzleBoard
	puzzle_board.completed.connect(_on_puzzle_completed)
	puzzle_board.state_changed.connect(_on_puzzle_state_changed)
	apply_settings_snapshot()
	add_child(puzzle_board)
	get_viewport().size_changed.connect(_queue_game_drag_blocker_refresh)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_setup_dev_tools()
	_build_catalog()
	_apply_level_media({})
	set_process(false)
	_show_topics()


func _exit_tree() -> void:
	if ui_motion != null:
		ui_motion.host = null
	if topic_home_motion != null:
		topic_home_motion.shutdown()
	for helper in [topics_screen, topic_pager_controller, catalog_scroll_controller, debug_adapter, level_list_screen, level_card_factory, level_unlock_animator, game_hud, game_dialogs, gameplay_runtime_host, completion_runtime_host, settings_runtime_host]:
		if helper == null:
			continue
		if helper.has_method("shutdown"):
			helper.shutdown()
		if "game" in helper:
			helper.game = null


func _lock_portrait_orientation() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var is_dev_key := key_event.keycode == KEY_D or key_event.physical_keycode == KEY_D
		if key_event.pressed and not key_event.echo and is_dev_key and dev_panel != null:
			dev_panel.toggle()
			get_viewport().set_input_as_handled()
			return
	if dev_panel != null and dev_panel.visible:
		return
	if current_screen != "game":
		return
	if puzzle_board.handle_input(event, modal_open):
		get_viewport().set_input_as_handled()


func _setup_dev_tools() -> void:
	if not OS.is_debug_build():
		return
	dev_layer = CanvasLayer.new()
	dev_layer.layer = 128
	add_child(dev_layer)
	dev_panel = DevTestPanelScript.new()
	dev_layer.add_child(dev_panel)
	dev_panel.setup(self)


func debug_level_options() -> Array:
	return debug_adapter.level_options()


func debug_execute(command: String, args: Dictionary = {}) -> Dictionary:
	if debug_adapter == null:
		return {
			"ok": false,
			"command": command,
			"error": {"code": "debug_only", "message": "Debug adapter is not available."},
		}
	return debug_adapter.execute(command, args)


func debug_state_snapshot() -> Dictionary:
	if debug_adapter == null:
		return {
			"ok": false,
			"error": {"code": "debug_only", "message": "Debug adapter is not available."},
		}
	return debug_adapter.state_snapshot()


func debug_enter_level(option_index: int, play_mode: String) -> void:
	debug_adapter.enter_level(option_index, play_mode)


func debug_restart_current_level() -> void:
	debug_adapter.restart_current_level()


func debug_apply_viewport_preset(size: Vector2i) -> void:
	debug_adapter.apply_viewport_preset(size)


func debug_runtime_metrics() -> Dictionary:
	return debug_adapter.runtime_metrics()


func debug_trigger_hint() -> void:
	debug_adapter.trigger_hint()


func debug_clear_hint() -> void:
	debug_adapter.clear_hint()


func debug_reset_tray() -> void:
	debug_adapter.reset_tray()


func debug_scroll_tray_left() -> void:
	debug_adapter.scroll_tray_left()


func debug_scroll_tray_right() -> void:
	debug_adapter.scroll_tray_right()


func debug_toggle_bounds_overlay() -> void:
	debug_adapter.toggle_bounds_overlay()


func debug_preview_complete() -> void:
	debug_adapter.preview_complete()


func debug_clear_current_progress() -> void:
	debug_adapter.clear_current_progress()


func debug_clear_all_progress() -> void:
	debug_adapter.clear_all_progress()


func debug_dump_state() -> void:
	debug_adapter.dump_state()


func debug_run_current_interaction_smoke() -> Dictionary:
	return await debug_adapter.run_current_interaction_smoke()


func _debug_refresh_current_screen() -> void:
	debug_adapter.refresh_current_screen()


func _build_catalog() -> void:
	topics = repository.build_catalog()


func _detect_locale() -> String:
	return GameStringsScript.detect_locale()


func _t(key: String) -> String:
	return game_strings.text(key)


func _clear_ui() -> void:
	if completion_runtime_host != null:
		completion_runtime_host.clear()
	if settings_runtime_host != null:
		settings_runtime_host.clear()
	modal_host.reset()
	if level_list_screen != null:
		level_list_screen.cancel_motion()
	_stop_topics_inertia()
	topics_drag_active = false
	topics_island_items.clear()
	level_virtual_items.clear()
	level_virtual_nodes.clear()
	level_virtual_overscan = 0.0
	topics_content = null
	for child in ui_layer.get_children():
		child.queue_free()
	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.z_index = 0
	ui_layer.add_child(screen_root)
	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.z_index = 100
	ui_layer.add_child(modal_root)
	modal_open = false
	current_modal = ""


func _clear_board() -> void:
	if puzzle_board != null:
		puzzle_board.clear()


func _persist_current_puzzle_state() -> void:
	game_session.persist_current_puzzle_state(self)


func _ui_motion_reduced() -> bool:
	return ui_motion.reduced()


func _reduced_motion_enabled() -> bool:
	return bool(motion_preferences.snapshot().get("reduced_motion", false)) if motion_preferences != null else false


func apply_settings_snapshot() -> Dictionary:
	if settings_repository == null:
		return {"ok": false, "error": "settings_unavailable"}
	var snapshot: Dictionary = settings_repository.snapshot()
	if puzzle_board != null:
		puzzle_board.set_feedback_preferences(
			bool(snapshot.get("haptics_enabled", true)),
			bool(snapshot.get("reduced_motion_enabled", false)),
			progress_store.edge_contrast_mode(),
		)
	return {"ok": true}


func _fade_control_in(control: Control) -> void:
	ui_motion.fade_control_in(control)


func _animate_modal_panel(panel: Control) -> void:
	await ui_motion.animate_modal_panel(panel)


func _wire_button_animation(button: BaseButton) -> void:
	_highlight_button_bounds(button)
	ui_motion.wire_button(button)


func _highlight_button_bounds(button: BaseButton) -> void:
	ui_factory.highlight_button_bounds(self, button)


func _left_rounded_topic_cover_texture(topic: Dictionary, target_size: Vector2i, radius: int) -> Texture2D:
	return texture_service.left_rounded_topic_cover_texture(topic, target_size, radius)


func _rounded_texture_material(target_size: Vector2, radius: float) -> ShaderMaterial:
	return texture_service.rounded_texture_material(target_size, radius)


func _icon_tint_material(color: Color) -> ShaderMaterial:
	return texture_service.icon_tint_material(color)


func _rounded_complete_image_texture(image_path: String, target_size: Vector2i, radius: int) -> Texture2D:
	return texture_service.rounded_complete_image_texture(image_path, target_size, radius)


func _screen_margin() -> float:
	return ui_factory.screen_margin(self)


func _icon_button(
	icon: Texture2D,
	action: Callable,
	button_size := UI_ICON_BUTTON_SIZE,
	icon_inset := UI_ICON_INSET,
	subtle_shadow := false,
	transparent := false,
	normal_icon_color := soft_brown,
	hover_icon_color := deep_orange,
	outline_only := false,
	outline_color := Color("#879174"),
) -> Button:
	return ui_factory.icon_button(self, icon, action, button_size, icon_inset, subtle_shadow, transparent, normal_icon_color, hover_icon_color, outline_only, outline_color)


func _rounded_panel_style(bg_color: Color, radius: int) -> StyleBoxFlat:
	return ui_factory.rounded_panel_style(bg_color, radius)


func _capsule_panel_style(bg_color: Color, height: float) -> StyleBoxFlat:
	return ui_factory.capsule_panel_style(bg_color, height)


func _tool_text_button(text: String, action: Callable) -> Button:
	return ui_factory.tool_text_button(self, text, action)


func _open_topic_levels(topic: Dictionary) -> void:
	_show_levels(topic, _level_list_focus_level_id(topic))


func _show_topics() -> void:
	topics_screen.show()


func _topics_ui_scale() -> float:
	return topics_screen.ui_scale()


func _grid_top_offset(topbar_bottom: float, ui_scale: float) -> float:
	return topics_screen.grid_top_offset(topbar_bottom, ui_scale)


func _theme_topbar_height(ui_scale: float) -> float:
	return topics_screen.topbar_height(ui_scale)


func _theme_card(topic: Dictionary, card_width: float, ui_scale: float) -> Control:
	return topics_screen.build_card(topic, card_width, ui_scale)


func _on_topics_gui_input(event: InputEvent) -> void:
	if current_screen == "topics":
		topic_pager_controller.handle_gui_input(event)
	else:
		catalog_scroll_controller.handle_gui_input(event)


func _scroll_topics_to(target: float) -> void:
	catalog_scroll_controller.scroll_to(target)


func _topics_max_scroll() -> float:
	return catalog_scroll_controller.max_scroll()


func _apply_topics_scroll() -> void:
	catalog_scroll_controller.apply_scroll()


func _stop_topics_inertia() -> void:
	if topic_pager_controller != null:
		topic_pager_controller.reset()
	if catalog_scroll_controller != null:
		catalog_scroll_controller.stop_inertia()


func _process(delta: float) -> void:
	catalog_scroll_controller.process(delta)


func _show_levels(topic: Dictionary, focus_level_id := "") -> void:
	level_list_screen.show(topic, focus_level_id)


func _level_list_focus_level_id(topic: Dictionary) -> String:
	return level_play_policy.level_list_focus_level_id(topic)


func _compute_level_locks(topic: Dictionary) -> Dictionary:
	return level_play_policy.compute_level_locks(topic)


func _level_back_button(button_size: float, palette: Dictionary, action: Callable = Callable()) -> Button:
	return level_list_screen.build_back_button(button_size, palette, action)


func _apply_topic_outline_nav_button_styles(button: Button, outline: Color, button_size: float) -> void:
	level_list_screen.apply_outline_nav_button_styles(button, outline, button_size)


func _level_grid_card(topic: Dictionary, level: Dictionary, unlocked: bool, card_width: float, ui_scale: float) -> Control:
	return level_card_factory.build(topic, level, unlocked, card_width, ui_scale)


func _add_level_card_back(card: Control, topic: Dictionary, topic_color: Color, card_width: float, card_height: float, radius: int) -> void:
	level_card_factory.add_back(card, topic, topic_color, card_width, card_height, radius)


func _level_mode_state(topic: Dictionary, level: Dictionary, play_mode: String) -> String:
	return level_play_policy.level_mode_state(topic, level, play_mode)


func _mode_state_icon(play_mode: String, state: String, size: float) -> Control:
	return ui_factory.mode_state_icon(self, play_mode, state, size)


func _level_display_title(level: Dictionary) -> String:
	return ui_factory.level_display_title(level)


func _empty_level_message() -> Label:
	return ui_factory.empty_level_message(self)


func _empty_topic_message() -> Label:
	return ui_factory.empty_topic_message(self)


func _topic_color(topic: Dictionary) -> Color:
	return ui_factory.topic_color(self, topic)


func _topic_ui_palette(topic: Dictionary) -> Dictionary:
	return ui_factory.topic_ui_palette(self, topic)


func _topic_ui_color(palette: Dictionary, key: String, fallback: Color) -> Color:
	return ui_factory.topic_ui_color(palette, key, fallback)


func _topic_progress_bar(done: int, total: int, size: Vector2, fill_color: Color, track_color := Color(0.78, 0.64, 0.48, 0.22)) -> Panel:
	return ui_factory.topic_progress_bar(done, total, size, fill_color, track_color)


func _status_icon(mode: String, done: bool, size: float) -> Control:
	return ui_factory.status_icon(self, mode, done, size)


func _mode_label(mode: String) -> String:
	return ui_factory.mode_label(self, mode)


func _show_mode_dialog(level: Dictionary) -> void:
	gameplay_runtime_host.show_mode_select(level)


func _animate_new_unlock_card(card: Control, topic: Dictionary, card_width: float) -> void:
	await level_unlock_animator.animate(card, topic, card_width)


func _show_game(topic: Dictionary, level: Dictionary, play_mode: String, discard_current_state := false) -> void:
	game_session.show_game(self, topic, level, play_mode, discard_current_state)


func _on_puzzle_completed() -> void:
	game_session.on_puzzle_completed(self)


func _on_puzzle_state_changed(state: Dictionary) -> void:
	game_session.on_puzzle_state_changed(self, state)


func _add_topic_title_decorations(
	parent: Control,
	title: Label,
	bar_height: float,
	requested_center_x := -1.0,
	top_offset := 0.0,
	requested_size := Vector2.ZERO,
	requested_gap := -1.0,
	topic_override: Dictionary = {},
) -> void:
	game_hud.add_topic_title_decorations(parent, title, bar_height, requested_center_x, top_offset, requested_size, requested_gap, topic_override)


func _hud_text_button_width(text: String) -> float:
	return game_hud.text_button_width(text)


func _hud_text_button_height() -> float:
	return game_hud.text_button_height()


func _mode_key(play_mode: String) -> String:
	return LevelPlayPolicyScript.mode_key(play_mode)


func _available_modes_for_level(level: Dictionary) -> Array[String]:
	return level_play_policy.available_modes_for_level(level)


func _available_modes_for_config(level_config: Dictionary) -> Array[String]:
	return level_play_policy.available_modes_for_config(level_config)


func _topic_available_mode_total(topic: Dictionary) -> int:
	return level_play_policy.topic_available_mode_total(topic)


func _topic_available_done_count(topic: Dictionary) -> int:
	return level_play_policy.topic_available_done_count(topic)


func _queue_game_drag_blocker_refresh() -> void:
	if gameplay_runtime_host != null:
		gameplay_runtime_host.refresh_board_blockers()


func _refresh_game_drag_blockers() -> void:
	if gameplay_runtime_host != null:
		gameplay_runtime_host.refresh_board_blockers()


func _apply_level_media(level_config: Dictionary) -> void:
	game_session.apply_level_media(self, level_config)


func _return_to_current_level_list() -> void:
	game_session.return_to_current_level_list(self)


func _show_settings_modal() -> void:
	if settings_runtime_host != null:
		settings_runtime_host.show()


func _show_tutorial_modal() -> void:
	current_modal = "tutorial"
	game_dialogs.show_tutorial()


func _show_complete_modal() -> void:
	game_session.show_completion(self)


func _stop_complete_confetti() -> void:
	if completion_runtime_host != null:
		completion_runtime_host.clear()


func _show_modal(shade_color := Color(0, 0, 0, 0.42), blur_background := false) -> void:
	if current_modal.is_empty():
		current_modal = "generic"
	modal_host.show(self, shade_color, blur_background)


func _modal_box(
	size: Vector2,
	bg_color := Color("#FFF6E6"),
	padding := 52.0,
	close_action := Callable(),
) -> VBoxContainer:
	return modal_host.box(self, size, bg_color, padding, close_action)


func _modal_title(text: String, font_size := 44) -> Label:
	return modal_host.title(self, text, font_size)


func _close_modal() -> void:
	if current_modal == "complete" and completion_runtime_host != null:
		completion_runtime_host.request_close()
		return
	if current_modal == "settings" and settings_runtime_host != null:
		settings_runtime_host.request_close()
		return
	current_modal = ""
	modal_host.close(self)
