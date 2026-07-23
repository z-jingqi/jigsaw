extends SceneTree

const AtomicJsonStoreScript := preload("res://scripts/runtime/data/AtomicJsonStore.gd")
const ProgressRepositoryScript := preload("res://scripts/runtime/data/ProgressRepository.gd")
const SessionRepositoryScript := preload("res://scripts/runtime/data/SessionRepository.gd")
const SettingsRepositoryScript := preload("res://scripts/runtime/data/SettingsRepository.gd")
const MotionPreferencesScript := preload("res://scripts/runtime/state/MotionPreferences.gd")
const ThemeProgressPolicyScript := preload("res://scripts/runtime/presentation/ThemeProgressPolicy.gd")
const ContentRepositoryScript := preload("res://scripts/runtime/data/ContentRepository.gd")
const CatalogPresenterScript := preload("res://scripts/runtime/presentation/CatalogPresenter.gd")
const SystemPresenterScript := preload("res://scripts/runtime/presentation/SystemPresenter.gd")
const AppServicesScript := preload("res://scripts/runtime/AppServices.gd")
const GameStringsScript := preload("res://scripts/app/GameStrings.gd")

const TEST_ROOT := "user://jigcat-test-runtime-foundation"

var _all_ok := true
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_root()
	var store = AtomicJsonStoreScript.new()
	var progress = ProgressRepositoryScript.new(store, "%s/progress_v1.json" % TEST_ROOT)
	var session = SessionRepositoryScript.new(store, "%s/session_v1.json" % TEST_ROOT)
	var settings = SettingsRepositoryScript.new(store, "%s/settings_v1.json" % TEST_ROOT)
	progress.load()
	session.load()
	settings.load()

	_check(progress.mark_mode_completed("topic_01", "level_01", "polygon").get("ok", false), "progress_first_completion")
	_check(progress.mark_mode_completed("topic_01", "level_01", "polygon").get("changed", true) == false, "progress_idempotent")
	_check(progress.is_mode_completed("topic_01", "level_01", "polygon"), "progress_completion_read")
	_check(progress.mark_tutorial_seen(&"home_swipe").get("ok", false), "home_tutorial_saved")
	_check(progress.tutorial_seen(&"home_swipe"), "home_tutorial_read")
	_check(progress.mark_tutorial_seen(&"mode", "swap").get("ok", false), "mode_tutorial_saved")
	_check(progress.tutorial_seen(&"mode", "swap"), "mode_tutorial_read")

	var at_20 := ThemeProgressPolicyScript.build(1, 5)
	var after_20 := ThemeProgressPolicyScript.build(2, 9)
	var complete := ThemeProgressPolicyScript.build(5, 5)
	var zero := ThemeProgressPolicyScript.build(0, 0)
	_check(int(at_20["paw_count"]) == 1, "progress_boundary_20")
	_check(int(after_20["paw_count"]) == 2, "progress_after_20")
	_check(int(complete["paw_count"]) == 5 and bool(complete["is_complete"]), "progress_complete")
	_check(float(zero["ratio"]) == 0.0 and not bool(zero["is_complete"]), "progress_zero_total")

	var pieces: Array[String] = ["piece_00", "piece_01", "piece_02"]
	var assembly := {
		"state_version": 1,
		"theme_id": "topic_01",
		"level_id": "level_01",
		"mode": "polygon",
		"piece_set_fingerprint": "sha256:test",
		"kind": "assembly",
		"connected_groups": [["piece_00", "piece_01"]],
		"tray_order": ["piece_02"],
		"hint_count": 1,
	}
	_check(session.save_play_state(assembly, pieces).get("ok", false), "assembly_saved")
	_check(not session.play_state("topic_01", "level_01", "polygon", pieces).is_empty(), "assembly_restored")
	var invalid_swap := assembly.duplicate(true)
	invalid_swap["mode"] = "swap"
	invalid_swap["kind"] = "swap"
	invalid_swap["slot_piece_ids"] = ["piece_00", "piece_00", "piece_02"]
	_check(not bool(session.save_play_state(invalid_swap, pieces).get("ok", true)), "invalid_swap_rejected")
	var services = AppServicesScript.new(ContentRepositoryScript.new(), progress, session, settings, MotionPreferencesScript.new(settings))
	_check(services.complete_mode("topic_01", "level_01", "polygon").get("ok", false), "complete_mode_commit")
	_check(session.play_state("topic_01", "level_01", "polygon", pieces).is_empty(), "complete_clears_session")
	_check(session.set_current("topic_01", "shanhai_01", "swap").get("ok", false), "current_session_saved")
	_check(services.initial_home_theme_id() == "topic_01", "initial_home_theme")
	_check(services.initial_level_focus_id("topic_01") == "shanhai_01", "initial_level_focus")

	var motion = MotionPreferencesScript.new(settings)
	_check(not bool(motion.snapshot()["reduced_motion"]), "motion_default")
	settings.set_value(&"reduced_motion_enabled", true)
	_check(bool(motion.snapshot()["reduced_motion"]), "motion_from_settings")
	motion.set_debug_override(false)
	_check(not bool(motion.snapshot()["reduced_motion"]), "motion_debug_override")
	motion.set_debug_override(null)
	_check(bool(motion.snapshot()["reduced_motion"]), "motion_override_cleared")
	var strings = GameStringsScript.new()
	var content = ContentRepositoryScript.new()
	var presenter = CatalogPresenterScript.new(content, progress, session, strings)
	var catalog_home = presenter.home("topic_01")
	_check(catalog_home.total_themes > 0 and catalog_home.selected_theme_id == "topic_01", "home_view_model")
	var catalog_all_themes = presenter.all_themes("topic_01")
	_check(catalog_all_themes.cards.size() == catalog_home.total_themes, "all_themes_view_model")
	var catalog_levels = presenter.level_list("topic_01")
	_check(not catalog_levels.levels.is_empty() and catalog_levels.theme_progress.total_modes > 0, "level_list_view_model")
	var mode_select = presenter.mode_select("topic_01", catalog_levels.levels[0].level_id)
	_check(not mode_select.options.is_empty(), "mode_select_view_model")
	var system_presenter = SystemPresenterScript.new(settings, motion, strings)
	var settings_model = system_presenter.settings()
	_check(settings_model.music_enabled and settings_model.error_text.is_empty(), "settings_view_model")
	var guide_model = system_presenter.guide(&"swipe", "Swipe between themes")
	_check(guide_model.reduced_motion and guide_model.can_skip, "guide_view_model")

	progress = ProgressRepositoryScript.new(store, "%s/progress_v1.json" % TEST_ROOT)
	progress.load()
	_check(progress.is_mode_completed("topic_01", "level_01", "polygon"), "progress_reloaded")
	_remove_test_root()
	var result := {"ok": _all_ok, "failures": _failures}
	print("RUNTIME_FOUNDATION %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _remove_test_root() -> void:
	var root_path := ProjectSettings.globalize_path(TEST_ROOT)
	for filename in ["progress_v1.json", "session_v1.json", "settings_v1.json"]:
		DirAccess.remove_absolute("%s/%s" % [root_path, filename])
		DirAccess.remove_absolute("%s/%s.tmp" % [root_path, filename])
	DirAccess.remove_absolute(root_path)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("RUNTIME_FOUNDATION_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("RUNTIME_FOUNDATION_FAIL %s" % name)
