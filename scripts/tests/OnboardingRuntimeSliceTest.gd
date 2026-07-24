extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const AtomicJsonStoreScript := preload("res://scripts/runtime/data/AtomicJsonStore.gd")
const ProgressRepositoryScript := preload("res://scripts/runtime/data/ProgressRepository.gd")
const SettingsRepositoryScript := preload("res://scripts/runtime/data/SettingsRepository.gd")

const TEST_ROOT := "user://jigcat-test-onboarding"

var _all_ok := true
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_storage()
	var store := AtomicJsonStoreScript.new()
	var game := MainScene.instantiate()
	game.onboarding_progress_repository = ProgressRepositoryScript.new(store, "%s/progress_v1.json" % TEST_ROOT)
	game.settings_repository = SettingsRepositoryScript.new(store, "%s/settings_v1.json" % TEST_ROOT)
	root.add_child(game)
	await create_timer(1.24).timeout
	var guide: Control = game.screen_root.get_node_or_null("HomeFirstRunGuide") as Control
	_check(guide != null, "home_guide_enters_actual_home_after_intro")
	var guide_panel: Control = guide.get_node_or_null("GuidePanel") as Control if guide != null else null
	var enter_button: Control = game.screen_root.get_node_or_null("topic_home_fixed_ui/topic_enter_button") as Control
	var viewport: Rect2 = game.get_viewport_rect()
	_check(
		guide_panel != null
		and guide_panel.get_global_rect().size.x >= viewport.size.x * 0.75
		and (enter_button == null or guide_panel.get_global_rect().end.y <= enter_button.get_global_rect().position.y),
		"home_guide_is_wide_and_does_not_overlap_enter_action"
	)
	_check((guide.get_node("SkipButton") as Button).text == game._t("guide_skip"), "home_guide_uses_current_locale")
	_check(not game.onboarding_progress_repository.tutorial_seen(&"home_swipe"), "home_swipe_initially_unseen")
	game._record_home_swipe()
	await process_frame
	_check(game.onboarding_progress_repository.tutorial_seen(&"home_swipe"), "real_home_swipe_records_only_swipe_step")
	guide = game.screen_root.get_node_or_null("HomeFirstRunGuide") as Control
	_check(guide != null and (guide.get_node("GuidePanel/Prompt") as Label).text == game._t("guide_enter"), "home_swipe_advances_to_enter_step")
	game._record_home_enter()
	await create_timer(0.16).timeout
	_check(game.onboarding_progress_repository.tutorial_seen(&"home_enter"), "home_enter_records_enter_step")
	_check(game.screen_root.get_node_or_null("HomeFirstRunGuide") == null, "home_guide_releases_after_completion")

	var topic: Dictionary = game.topics[0]
	var level: Dictionary = topic.levels[0]
	game._show_game(topic, level, "polygon", true)
	await create_timer(0.36).timeout
	var tutorial: Control = game.modal_root.get_node_or_null("ModeTutorialModal") as Control
	_check(tutorial != null and game.current_modal == "tutorial" and game.modal_open, "first_polygon_session_opens_scene_tutorial")
	if tutorial != null:
		tutorial.call(&"request_dismiss")
	await create_timer(0.18).timeout
	_check(not game.onboarding_progress_repository.tutorial_seen(&"mode", "polygon"), "dismiss_does_not_mark_mode_seen")
	game._show_tutorial_modal()
	await create_timer(0.28).timeout
	tutorial = game.modal_root.get_node_or_null("ModeTutorialModal") as Control
	if tutorial != null:
		(tutorial.get_node("ModalShell/Panel/Content/Actions/Skip") as Button).pressed.emit()
	await create_timer(0.18).timeout
	_check(game.onboarding_progress_repository.tutorial_seen(&"mode", "polygon"), "skip_marks_only_current_mode_seen")
	_check(not game.onboarding_progress_repository.tutorial_seen(&"mode", "swap"), "mode_tutorials_are_independent")

	game.settings_repository.set_value(&"reduced_motion_enabled", true)
	game.apply_settings_snapshot()
	game._show_tutorial_modal()
	await process_frame
	_check(game.modal_root.get_node_or_null("ModeTutorialModal") == null, "seen_mode_does_not_reopen_tutorial")
	game._show_game(topic, level, "swap", true)
	await process_frame
	tutorial = game.modal_root.get_node_or_null("ModeTutorialModal") as Control
	_check(tutorial != null and int(tutorial.call(&"active_motion_count")) == 0, "reduced_motion_tutorial_is_immediately_stable")
	if tutorial != null:
		(tutorial.get_node("ModalShell/Panel/Content/Actions/Confirm") as Button).pressed.emit()
	await process_frame
	_check(game.onboarding_progress_repository.tutorial_seen(&"mode", "swap"), "confirm_marks_current_mode_seen")
	game._clear_ui()
	game._clear_board()
	await process_frame
	_check(game.modal_root.get_child_count() == 0, "clear_ui_releases_onboarding_modal")
	game.queue_free()
	await process_frame
	_remove_test_storage()
	var result := {"ok": _all_ok, "failures": _failures}
	print("ONBOARDING_RUNTIME_SLICE %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _remove_test_storage() -> void:
	var root_path := ProjectSettings.globalize_path(TEST_ROOT)
	for filename in ["progress_v1.json", "settings_v1.json"]:
		DirAccess.remove_absolute("%s/%s" % [root_path, filename])
		DirAccess.remove_absolute("%s/%s.tmp" % [root_path, filename])
	DirAccess.remove_absolute(root_path)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("ONBOARDING_RUNTIME_SLICE_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("ONBOARDING_RUNTIME_SLICE_FAIL %s" % name)
