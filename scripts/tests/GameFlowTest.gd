extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const AtomicJsonStoreScript := preload("res://scripts/runtime/data/AtomicJsonStore.gd")
const ProgressRepositoryScript := preload("res://scripts/runtime/data/ProgressRepository.gd")
const SessionRepositoryScript := preload("res://scripts/runtime/data/SessionRepository.gd")

const TEST_PROGRESS_PATH := "user://jigcat-test-game-flow-progress.json"
const TEST_SESSION_PATH := "user://jigcat-test-game-flow/session_v1.json"
const TEST_ONBOARDING_PATH := "user://jigcat-test-game-flow/onboarding_progress_v1.json"

var _all_ok := true
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_storage()
	var game := MainScene.instantiate()
	game.progress_store.save_path = TEST_PROGRESS_PATH
	game.session_repository = SessionRepositoryScript.new(AtomicJsonStoreScript.new(), TEST_SESSION_PATH)
	game.onboarding_progress_repository = ProgressRepositoryScript.new(AtomicJsonStoreScript.new(), TEST_ONBOARDING_PATH)
	root.add_child(game)
	await process_frame
	for mode in ["polygon", "knob", "swap"]:
		game.onboarding_progress_repository.mark_tutorial_seen(&"mode", mode)
	_check(game.current_screen == "topics" and not game.topics.is_empty(), "launches_catalog_flow")
	var topic: Dictionary = game.topics[0]
	var level: Dictionary = topic.levels[0]
	game._show_levels(topic, str(level.id))
	await process_frame
	_check(game.current_screen == "levels" and game.screen_root.get_node_or_null("level_list_topbar") != null, "topics_enter_level_list")
	game._show_mode_dialog(level)
	await create_timer(0.32).timeout
	var modal: Control = game.modal_root.get_node_or_null("ModeSelectModal") as Control
	_check(modal != null and (modal.get_node("ModalShell/Panel/Content/Options") as VBoxContainer).get_child_count() > 0, "level_list_opens_scene_mode_select")
	if modal != null:
		modal.call("request_close")
	await create_timer(0.16).timeout

	for mode in ["polygon", "knob", "swap"]:
		await _exercise_mode(game, topic, level, mode)

	game._clear_ui()
	game._clear_board()
	await process_frame
	game.queue_free()
	await process_frame
	_remove_test_storage()
	var result := {"ok": _all_ok, "failures": _failures}
	print("GAME_FLOW %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _exercise_mode(game, topic: Dictionary, level: Dictionary, mode: String) -> void:
	if not game._available_modes_for_level(level).has(mode):
		_check(false, "%s_available" % mode)
		return
	game._show_game(topic, level, mode, true)
	await create_timer(0.16).timeout
	var gameplay: GameplayScreen = game.screen_root.get_node_or_null("GameplayScreen") as GameplayScreen
	_check(game.current_screen == "game" and game.current_mode == mode and gameplay != null, "%s_enters_runtime_gameplay" % mode)
	if gameplay == null:
		return
	_check(game.puzzle_board.get_node_or_null("WorldRoot") != null and game.puzzle_board.get_node_or_null("TrayRoot") != null, "%s_uses_scene_board_hosts" % mode)
	var snapshot: Dictionary = game.puzzle_board.session_snapshot(str(topic.id), str(level.id))
	var piece_ids: Array[String] = game.puzzle_board.session_piece_ids()
	if mode == "swap":
		_check(gameplay.get_node("BottomHost/SwapActionBar").visible and not gameplay.get_node("BottomHost/TrayView").visible, "swap_uses_action_bar")
		_check(str(snapshot.get("kind", "")) == "swap" and (snapshot.get("slot_piece_ids", []) as Array).size() == piece_ids.size(), "swap_records_full_permutation")
	else:
		_check(gameplay.get_node("BottomHost/TrayView").visible and not gameplay.get_node("BottomHost/SwapActionBar").visible, "%s_uses_scene_tray" % mode)
		_check(str(snapshot.get("kind", "")) == "assembly" and game.puzzle_board._tray_area().is_equal_approx(gameplay.tray_rect()), "%s_uses_scene_tray_geometry" % mode)
	game._persist_current_puzzle_state()
	_check(not game.session_repository.play_state(str(topic.id), str(level.id), mode, piece_ids).is_empty(), "%s_persists_session_v1" % mode)
	game.puzzle_board.debug_force_complete()
	await create_timer(0.24).timeout
	_check(game.progress_store.is_done(str(level.id), mode), "%s_marks_completion_once" % mode)
	_check(game.session_repository.play_state(str(topic.id), str(level.id), mode, piece_ids).is_empty(), "%s_clears_completed_session" % mode)
	_check(game.current_modal == "complete", "%s_opens_completion_flow" % mode)
	var completion: Control = game.modal_root.get_node_or_null("CompletionModal") as Control
	_check(completion != null and completion.get_node("ModalShell/Panel/Content/Confirm") is Button, "%s_uses_scene_completion_modal" % mode)
	_check(completion != null and completion.get_node("CompletionConfetti").get_child_count() == 22, "%s_uses_bounded_confetti" % mode)
	game.game_session.on_puzzle_completed(game)
	_check(game.modal_root.get_child_count() == 1, "%s_completion_is_idempotent" % mode)
	if completion != null:
		(completion.get_node("ModalShell/Panel/Content/Confirm") as Button).pressed.emit()
	await create_timer(0.20).timeout
	_check(game.current_screen == "levels" and game.current_modal.is_empty() and game.modal_root.get_child_count() == 0, "%s_confirmation_returns_to_levels" % mode)


func _remove_test_storage() -> void:
	for path in [TEST_PROGRESS_PATH, TEST_SESSION_PATH, TEST_ONBOARDING_PATH]:
		var absolute_path := ProjectSettings.globalize_path(path)
		DirAccess.remove_absolute(absolute_path)
		DirAccess.remove_absolute("%s.tmp" % absolute_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SESSION_PATH).get_base_dir())


func _check(condition: bool, name: String) -> void:
	if condition:
		print("GAME_FLOW_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("GAME_FLOW_FAIL %s" % name)
