extends RefCounted
## Owns one cancellable, read-only gameplay preparation behind the mode page.

signal preparation_changed

const GameplayScene := preload("res://scenes/screens/GameplayScreen.tscn")

var _navigator: AppNavigator
var _services: Variant
var _catalog: Variant
var _board: PuzzleBoard
var _world_host: Node2D
var _modal: RuntimeModeSelectModal
var _screen: GameplayScreen
var _key := ""
var _generation := 0
var _ready := false
var _failed := false
var _claimed := false
var _layout_size := Vector2.ZERO


func _init(
	navigator: AppNavigator, services: Variant, catalog: Variant, board: PuzzleBoard, host: Node2D
) -> void:
	_navigator = navigator
	_services = services
	_catalog = catalog
	_board = board
	_world_host = host


func request(
	modal: RuntimeModeSelectModal, theme_id: String, level_id: String, mode: String, policy: String
) -> void:
	if _claimed or mode.is_empty():
		return
	var key := _selection_key(theme_id, level_id, mode, policy)
	if _modal == modal and _key == key:
		return
	if _modal != modal:
		cancel()
	_modal = modal
	_key = key
	_generation += 1
	_ready = false
	_failed = false
	preparation_changed.emit()
	_prepare(_generation, theme_id, level_id, mode, policy)


func take_screen(theme_id: String, level_id: String, mode: String, policy: String) -> Control:
	if (
		_key != _selection_key(theme_id, level_id, mode, policy)
		or not is_instance_valid(_screen)
		or _screen.is_queued_for_deletion()
		or _screen.size != _layout_size
	):
		cancel()
		return null
	_claimed = true
	return _screen


func prepare_live(screen: GameplayScreen, theme_id: String, level_id: String, mode: String) -> bool:
	if _claimed and screen == _screen:
		var generation := _generation
		while (
			generation == _generation and not _ready and not _failed and is_instance_valid(screen)
		):
			await preparation_changed
		var loaded := generation == _generation and _ready and is_instance_valid(screen)
		if generation == _generation and screen == _screen:
			_screen = null
			_modal = null
			_key = ""
			_claimed = false
			_ready = false
		return loaded
	var loaded := await _build_board(screen, theme_id, level_id, mode, "resume")
	if loaded:
		await RenderingServer.frame_post_draw
	return loaded


func cancel() -> void:
	_generation += 1
	var screen := _screen
	var claimed := _claimed
	_screen = null
	_modal = null
	_key = ""
	_ready = false
	_failed = false
	_claimed = false
	preparation_changed.emit()
	if is_instance_valid(screen) and not screen.is_queued_for_deletion():
		screen.navigation_exit({})
		screen.hide()
		if not claimed:
			screen.queue_free()
		if is_instance_valid(_board):
			_board.clear()


func debug_snapshot() -> Dictionary:
	return {
		"key": _key,
		"ready": _ready,
		"claimed": _claimed,
		"cached_screens": 1 if is_instance_valid(_screen) else 0,
		"generation": _generation,
	}


func _prepare(
	generation: int, theme_id: String, level_id: String, mode: String, policy: String
) -> void:
	# Wait for the mode card entrance, rather than competing with its first draw.
	await _navigator.wait_until_idle()
	if not _current(generation):
		return
	if not is_instance_valid(_screen):
		_screen = GameplayScene.instantiate() as GameplayScreen
		_navigator.mount_prepared_screen(_screen)
	_screen.navigation_enter(
		{"view_model": _catalog.gameplay(theme_id, level_id, StringName(mode))},
		_services.motion_preferences.snapshot()
	)
	_screen.navigation_set_active(false)
	_screen.show()
	_screen.attach_board_host(_world_host)
	_layout_size = _screen.size
	var screen := _screen
	var loaded := await _build_board(screen, theme_id, level_id, mode, policy)
	if not _current(generation):
		return
	if not loaded:
		_failed = true
		preparation_changed.emit()
		return
	await RenderingServer.frame_post_draw
	if not _current(generation):
		return
	_ready = true
	preparation_changed.emit()


func _build_board(
	screen: GameplayScreen, theme_id: String, level_id: String, mode: String, policy: String
) -> bool:
	var topic: Dictionary = _services.content.topic_by_id(theme_id)
	var level: Dictionary = _services.content.level_by_id(theme_id, level_id)
	if topic.is_empty() or level.is_empty() or not is_instance_valid(screen):
		return false
	var config: Dictionary = _services.content.config_with_theme_background(
		_services.content.level_config(level), topic
	)
	config["_persistent_tabletop_background"] = true
	var media: Dictionary = _services.content.level_media(config)
	var loaded := await _board.start_runtime(
		config,
		mode,
		media.get("texture"),
		media.get("image"),
		media.get("source_size", Vector2.ZERO),
		screen.top_reserved_height(),
		screen.bottom_reserved_height(),
		screen.tray_rect()
	)
	if not loaded or not is_instance_valid(screen):
		return false
	if policy == "resume":
		var restore: Dictionary = _services.session.peek_play_state(
			theme_id, level_id, mode, _board.session_piece_ids()
		)
		if not restore.is_empty():
			_board.apply_state_snapshot(restore)
	return true


func _current(generation: int) -> bool:
	return (
		_generation == generation
		and is_instance_valid(_board)
		and _board.is_inside_tree()
		and (
			(_claimed and is_instance_valid(_screen) and not _screen.is_queued_for_deletion())
			or (is_instance_valid(_modal) and _navigator.current_route_view() == _modal)
		)
	)


func _selection_key(theme_id: String, level_id: String, mode: String, policy: String) -> String:
	return "/".join([theme_id, level_id, mode, policy])
