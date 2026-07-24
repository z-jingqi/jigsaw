extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const AtomicJsonStoreScript := preload("res://scripts/runtime/data/AtomicJsonStore.gd")
const ProgressRepositoryScript := preload("res://scripts/runtime/data/ProgressRepository.gd")
const SessionRepositoryScript := preload("res://scripts/runtime/data/SessionRepository.gd")
const LevelPlayPolicyScript := preload("res://scripts/catalog/LevelPlayPolicy.gd")
const BoardSessionIdentityScript := preload("res://scripts/gameplay/runtime/BoardSessionIdentity.gd")

const TEST_SESSION_PATH := "user://jigcat-test-runtime-gameplay/session_v1.json"
const TEST_ONBOARDING_PATH := "user://jigcat-test-runtime-gameplay/onboarding_progress_v1.json"

var _all_ok := true
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MainScene.instantiate()
	game.onboarding_progress_repository = ProgressRepositoryScript.new(AtomicJsonStoreScript.new(), TEST_ONBOARDING_PATH)
	root.add_child(game)
	await process_frame
	var topic: Dictionary = game.topics[0]
	var level: Dictionary = topic.levels[0]
	_configure_isolated_runtime_state(game, topic, level)
	game._show_levels(topic, str(level.id))
	game._show_mode_dialog(level)
	await create_timer(0.32).timeout
	var modal: Control = game.modal_root.get_node_or_null("ModeSelectModal") as Control
	_check(modal != null, "level_list_opens_scene_mode_select")
	if modal != null:
		(modal.get_node("ModalShell/Panel/Content/Header/CloseButton") as Button).pressed.emit()
	await create_timer(0.20).timeout
	_check(game.modal_root.get_node_or_null("ModeSelectModal") == null and not game.modal_open and game.current_modal.is_empty(), "mode_close_releases_runtime_modal")
	game._show_mode_dialog(level)
	await create_timer(0.32).timeout
	modal = game.modal_root.get_node_or_null("ModeSelectModal") as Control
	var options: VBoxContainer = modal.get_node("ModalShell/Panel/Content/Options")
	_check(options.get_child_count() > 0, "mode_select_receives_available_modes")
	(options.get_child(0) as Button).pressed.emit()
	await create_timer(0.48).timeout
	_check(game.current_screen == "game", "mode_selection_enters_game")
	var gameplay: GameplayScreen = game.screen_root.get_node_or_null("GameplayScreen") as GameplayScreen
	_check(gameplay != null, "game_uses_scene_gameplay_screen")
	_check(game.puzzle_board.get_node_or_null("WorldRoot") != null and game.puzzle_board.get_node_or_null("TrayRoot") != null, "game_uses_scene_puzzle_board_hosts")
	_check(not (gameplay.get_node("Hud/BackButton") as Button).disabled, "board_live_unlocks_hud")
	_check(game.puzzle_board.drag_blockers.size() == 2, "hud_blocks_board_input_without_blocking_tray")
	_check(game.puzzle_board._tray_area().is_equal_approx(gameplay.tray_rect()), "board_uses_scene_tray_rect")
	var active_mode: String = game.current_mode
	var piece_ids: Array[String] = game.puzzle_board.session_piece_ids()
	_check(piece_ids == BoardSessionIdentityScript.piece_ids(game.repository.load_level_config(level), active_mode), "polygon_stable_piece_ids_match_board")
	(gameplay.get_node("Hud/HintButton") as Button).pressed.emit()
	await process_frame
	(gameplay.get_node("Hud/BackButton") as Button).pressed.emit()
	await create_timer(0.12).timeout
	_check(game.current_screen == "levels", "gameplay_back_returns_to_levels")
	_check(game.screen_root.get_node_or_null("GameplayScreen") == null, "gameplay_screen_released_after_back")
	_check(not game.session_repository.play_state(str(topic.id), str(level.id), active_mode, piece_ids).is_empty(), "back_flushes_session_v1_state")
	_check(game._level_mode_state(topic, level, active_mode) == "active", "level_cards_read_session_v1_state")
	await _verify_continue_flow(game, topic, level, active_mode)
	await _verify_mode_runtime(game, topic, level, "knob")
	await _verify_mode_runtime(game, topic, level, "swap")
	game._clear_ui()
	game._clear_board()
	await process_frame
	game.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	_remove_test_session()
	var result := {"ok": _all_ok, "failures": _failures}
	print("RUNTIME_GAMEPLAY_SLICE %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _configure_isolated_runtime_state(game, topic: Dictionary, level: Dictionary) -> void:
	_remove_test_session()
	var session := SessionRepositoryScript.new(AtomicJsonStoreScript.new(), TEST_SESSION_PATH)
	session.load()
	game.session_repository = session
	game.level_play_policy = LevelPlayPolicyScript.new(game.repository, game.progress_store, session)
	var completed: Dictionary = game.progress_store.progress.get("completed", {})
	completed.erase("%s:polygon" % str(level.id))
	completed.erase("%s:knob" % str(level.id))
	completed.erase("%s:swap" % str(level.id))
	game.progress_store.progress["completed"] = completed
	game.progress_store.progress.erase(str(level.id))
	for mode in ["polygon", "knob", "swap"]:
		game.onboarding_progress_repository.mark_tutorial_seen(&"mode", mode)


func _verify_continue_flow(game, topic: Dictionary, level: Dictionary, active_mode: String) -> void:
	game._show_mode_dialog(level)
	await create_timer(0.32).timeout
	var modal: Control = game.modal_root.get_node_or_null("ModeSelectModal") as Control
	var options: VBoxContainer = modal.get_node("ModalShell/Panel/Content/Options") as VBoxContainer if modal != null else null
	var option: Button = _option_for_mode(options, active_mode)
	_check(option != null and (option.get_node("Margin/Content/Action") as Label).text == "Continue", "saved_mode_offers_continue")
	if option != null:
		option.pressed.emit()
	await create_timer(0.48).timeout
	_check(game.current_screen == "game" and game.current_mode == active_mode, "continue_reenters_saved_mode")
	_check(game.puzzle_board.hint_count == 1, "continue_restores_semantic_hint_count")
	var gameplay: GameplayScreen = game.screen_root.get_node_or_null("GameplayScreen") as GameplayScreen
	if gameplay != null:
		(gameplay.get_node("Hud/BackButton") as Button).pressed.emit()
	await create_timer(0.12).timeout


func _verify_mode_runtime(game, topic: Dictionary, level: Dictionary, mode: String) -> void:
	game._show_game(topic, level, mode, true)
	await create_timer(0.16).timeout
	var gameplay: GameplayScreen = game.screen_root.get_node_or_null("GameplayScreen") as GameplayScreen
	_check(game.current_screen == "game" and gameplay != null and game.current_mode == mode, "%s_enters_scene_gameplay" % mode)
	if gameplay == null:
		return
	var snapshot: Dictionary = game.puzzle_board.session_snapshot(str(topic.id), str(level.id))
	var piece_ids: Array[String] = game.puzzle_board.session_piece_ids()
	var expected_ids: Array[String] = BoardSessionIdentityScript.piece_ids(game.repository.load_level_config(level), mode)
	_check(piece_ids == expected_ids, "%s_stable_piece_ids_match_board" % mode)
	if mode == "swap":
		_check(not gameplay.get_node("BottomHost/TrayView").visible and gameplay.get_node("BottomHost/SwapActionBar").visible, "swap_uses_action_bar")
		_check(str(snapshot.get("kind", "")) == "swap" and (snapshot.get("slot_piece_ids", []) as Array).size() == piece_ids.size(), "swap_snapshot_is_full_permutation")
		var before_slots: Array = snapshot.get("slot_piece_ids", []).duplicate()
		(gameplay.get_node("BottomHost/SwapActionBar/Actions/MoveDown") as Button).pressed.emit()
		await create_timer(0.40).timeout
		var after_slots: Array = game.puzzle_board.session_snapshot(str(topic.id), str(level.id)).get("slot_piece_ids", [])
		_check(after_slots != before_slots, "swap_action_updates_persisted_permutation")
	else:
		_check(gameplay.get_node("BottomHost/TrayView").visible and not gameplay.get_node("BottomHost/SwapActionBar").visible, "%s_uses_tray_view" % mode)
		_check(str(snapshot.get("kind", "")) == "assembly", "%s_snapshot_uses_semantic_groups" % mode)
		_check(game.puzzle_board._tray_area().is_equal_approx(gameplay.tray_rect()), "%s_board_tray_matches_scene" % mode)
	(gameplay.get_node("Hud/BackButton") as Button).pressed.emit()
	await create_timer(0.12).timeout
	_check(not game.session_repository.play_state(str(topic.id), str(level.id), mode, piece_ids).is_empty(), "%s_back_flushes_session" % mode)


func _option_for_mode(options: VBoxContainer, mode: String) -> Button:
	if options == null:
		return null
	for child in options.get_children():
		if child is Button and str(child.call("_read", "mode", "")) == mode:
			return child as Button
	return null


func _remove_test_session() -> void:
	var path := ProjectSettings.globalize_path(TEST_SESSION_PATH)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute("%s.tmp" % path)
	var onboarding_path := ProjectSettings.globalize_path(TEST_ONBOARDING_PATH)
	DirAccess.remove_absolute(onboarding_path)
	DirAccess.remove_absolute("%s.tmp" % onboarding_path)
	DirAccess.remove_absolute(path.get_base_dir())


func _check(condition: bool, name: String) -> void:
	if condition:
		print("RUNTIME_GAMEPLAY_SLICE_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("RUNTIME_GAMEPLAY_SLICE_FAIL %s" % name)
