extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const AtomicJsonStoreScript := preload("res://scripts/runtime/data/AtomicJsonStore.gd")
const SettingsRepositoryScript := preload("res://scripts/runtime/data/SettingsRepository.gd")

const TEST_SETTINGS_PATH := "user://jigcat-test-runtime-settings/settings_v1.json"

var _all_ok := true
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_storage()
	var game := MainScene.instantiate()
	game.settings_repository = SettingsRepositoryScript.new(AtomicJsonStoreScript.new(), TEST_SETTINGS_PATH)
	root.add_child(game)
	await process_frame
	_check(game.current_screen == "topics", "launches_actual_home_flow")
	var settings_button := game.screen_root.get_node_or_null("topic_home_fixed_ui/theme_settings_button") as Button
	_check(settings_button != null, "home_exposes_settings_menu_entry")
	if settings_button != null:
		settings_button.pressed.emit()
	await create_timer(0.30).timeout
	var modal: Control = game.modal_root.get_node_or_null("SettingsModal") as Control
	_check(modal != null and game.current_modal == "settings" and game.modal_open, "home_route_opens_scene_settings_modal")
	if modal != null:
		var rows: VBoxContainer = modal.get_node("ModalShell/Panel/Content/Rows")
		_check(rows.get_child_count() == 3, "settings_shows_exactly_three_rows")
		_check(_row_value(rows, "Haptics"), "default_haptics_matches_repository")
		_toggle_row(rows, "Haptics", false)
		await process_frame
		_check(not bool(game.settings_repository.snapshot()["haptics_enabled"]), "haptics_persists_to_settings_v1")
		_check(not game.puzzle_board.haptics_enabled, "haptics_applies_to_running_board")
		_toggle_row(rows, "Music", false)
		_toggle_row(rows, "Music", true)
		await process_frame
		_check(bool(game.settings_repository.snapshot()["music_enabled"]), "rapid_toggle_keeps_last_confirmed_value")
		(modal.get_node("ModalShell/Panel/Content/Header/Close") as Button).pressed.emit()
	await create_timer(0.20).timeout
	_check(game.modal_root.get_node_or_null("SettingsModal") == null and game.current_modal.is_empty() and not game.modal_open, "close_releases_scene_modal")
	game._show_settings_modal()
	await create_timer(0.30).timeout
	modal = game.modal_root.get_node_or_null("SettingsModal") as Control
	_check(modal != null and not _row_value(modal.get_node("ModalShell/Panel/Content/Rows"), "Haptics"), "reopen_reads_confirmed_settings_value")
	game._show_settings_modal()
	await process_frame
	_check(game.modal_root.get_child_count() == 1, "repeat_open_keeps_one_settings_instance")
	var invalid: Dictionary = game.settings_repository.set_value(&"unknown", true)
	_check(not bool(invalid.get("ok", true)) and str(invalid.get("error", "")) == "invalid_argument", "unknown_setting_is_rejected")
	game._close_modal()
	await create_timer(0.20).timeout
	var reduced_motion_result: Dictionary = game.debug_execute("set_reduced_motion", {"enabled": true})
	_check(bool(reduced_motion_result.get("ok", false)), "debug_updates_reduced_motion_in_settings_v1")
	game._show_settings_modal()
	await process_frame
	modal = game.modal_root.get_node_or_null("SettingsModal") as Control
	_check(modal != null and int(modal.call(&"active_motion_count")) == 0, "reduced_motion_opens_settings_at_final_state")
	game._clear_ui()
	game._clear_board()
	await process_frame
	game.queue_free()
	await process_frame
	_remove_test_storage()
	var result := {"ok": _all_ok, "failures": _failures}
	print("RUNTIME_SETTINGS_SLICE %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _toggle_row(rows: VBoxContainer, row_name: String, value: bool) -> void:
	var row := rows.get_node_or_null(row_name) as SettingsRow
	if row == null:
		return
	var toggle := row.get_node("Toggle") as Button
	toggle.button_pressed = value


func _row_value(rows: VBoxContainer, row_name: String) -> bool:
	var row := rows.get_node_or_null(row_name) as SettingsRow
	if row == null:
		return false
	return (row.get_node("Toggle") as Button).button_pressed


func _remove_test_storage() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	DirAccess.remove_absolute(absolute_path)
	DirAccess.remove_absolute("%s.tmp" % absolute_path)
	DirAccess.remove_absolute(absolute_path.get_base_dir())


func _check(condition: bool, name: String) -> void:
	if condition:
		print("RUNTIME_SETTINGS_SLICE_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("RUNTIME_SETTINGS_SLICE_FAIL %s" % name)
