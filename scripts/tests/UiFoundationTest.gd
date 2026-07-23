extends SceneTree

const ThemeProgressScene := preload("res://scenes/ui/foundation/ThemeProgress.tscn")
const IconButtonScene := preload("res://scenes/ui/foundation/IconButton.tscn")
const PillButtonScene := preload("res://scenes/ui/foundation/PillButton.tscn")
const ThemeCardScene := preload("res://scenes/ui/foundation/ThemeCard.tscn")
const LevelCardScene := preload("res://scenes/ui/foundation/LevelCard.tscn")
const SettingsRowScene := preload("res://scenes/ui/foundation/SettingsRow.tscn")
const SafeAreaScene := preload("res://scenes/ui/foundation/SafeAreaContainer.tscn")
const ModalShellScene := preload("res://scenes/ui/foundation/ModalShell.tscn")
const FocusNavigationScript := preload("res://scripts/ui/foundation/FocusNavigation.gd")
const ThemeResource := preload("res://themes/jigcat_theme.tres")
const OnDarkThemeResource := preload("res://themes/jigcat_on_dark.tres")
const TokenResource := preload("res://themes/jigcat_tokens.tres")
const MotionResource := preload("res://themes/motion_tokens.tres")

var _all_ok := true
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ThemeResource.default_font != null, "theme_local_font")
	_check(OnDarkThemeResource.default_font != null, "theme_on_dark_local_font")
	_check(ThemeResource.get_stylebox(&"focus", &"Button").border_width_left == 3, "theme_focus_ring")
	_check(ThemeResource.get_stylebox(&"focus", &"CheckButton").border_width_left == 3, "toggle_focus_ring")
	_check(TokenResource.minimum_touch_size >= 44.0, "touch_token")
	_check(TokenResource.theme_for_variant(TokenResource.TextVariant.ON_LIGHT) != null and TokenResource.theme_for_variant(TokenResource.TextVariant.ON_DARK) != null, "theme_variants")
	_check(is_equal_approx(MotionResource.modal_open_duration, 0.24), "motion_token")
	_check(is_equal_approx(MotionResource.progress_cat_duration, 0.26) and is_equal_approx(MotionResource.numeric_completion_duration, 0.22), "progress_motion_tokens")
	var progress = ThemeProgressScene.instantiate()
	root.add_child(progress)
	progress.set_anchors_preset(Control.PRESET_TOP_LEFT)
	progress.size = Vector2(208, 48)
	await process_frame
	progress.set_progress_data(_progress(0, 0, 0.0, 0, false))
	_check(progress.get_node("Journey/Fish").visible, "journey_empty_fish_visible")
	_check(_visible_paws(progress) == 0, "journey_zero_paws")
	progress.set_progress_data(_progress(1, 5, 0.2, 1, false))
	_check(_visible_paws(progress) == 1, "journey_20_paws")
	progress.set_progress_data(_progress(2, 5, 0.4, 2, false))
	_check(progress.active_motion_count() == 1, "journey_progress_motion")
	await create_timer(0.30).timeout
	_check(progress.active_motion_count() == 0, "journey_motion_released")
	progress.set_progress_data(_progress(5, 5, 1.0, 5, true))
	_check(_visible_paws(progress) == 5, "journey_complete_paws")
	_check(not progress.get_node("Journey/Fish").visible and progress.get_node("Journey/Completion").visible, "journey_complete_mark")
	progress.display_variant = progress.Variant.NUMERIC_CARD
	progress.set_progress_data(_progress(1, 5, 0.2, 1, false))
	_check(progress.get_node("Numeric").visible and not progress.get_node("Journey").visible, "numeric_hides_journey")
	_check(progress.get_node("Numeric").text == "1 / 5", "numeric_text")
	progress.display_variant = progress.Variant.NUMERIC_CARD
	progress.set_progress_data(_progress(5, 5, 1.0, 5, true))
	_check(progress.get_node("NumericCompletion").visible, "numeric_completion_state")
	progress.reduced_motion = true
	progress.display_variant = progress.Variant.JOURNEY
	progress.set_progress_data(_progress(1, 5, 0.2, 1, false))
	_check(progress.active_motion_count() == 0, "progress_reduced_motion")
	progress.queue_free()
	await process_frame
	await _test_component_scenes()
	await _test_modal_interruption()
	var result := {"ok": _all_ok, "failures": _failures}
	print("UI_FOUNDATION %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _progress(completed: int, total: int, ratio: float, paws: int, is_complete: bool) -> Dictionary:
	return {"completed_modes": completed, "total_modes": total, "ratio": ratio, "paw_count": paws, "is_complete": is_complete, "accessibility_text": "%d / %d" % [completed, total]}


func _visible_paws(progress: Control) -> int:
	var count := 0
	for paw in progress.get_node("Journey/Paws").get_children():
		if paw.visible:
			count += 1
	return count


func _test_component_scenes() -> void:
	var icon_button = IconButtonScene.instantiate()
	var pill_button = PillButtonScene.instantiate()
	var theme_card = ThemeCardScene.instantiate()
	var level_card = LevelCardScene.instantiate()
	var settings_row = SettingsRowScene.instantiate()
	var safe_area = SafeAreaScene.instantiate()
	var modal_shell = ModalShellScene.instantiate()
	for component in [icon_button, pill_button, theme_card, level_card, settings_row, safe_area, modal_shell]:
		root.add_child(component)
	await process_frame
	_check(icon_button.custom_minimum_size.x >= 44.0 and icon_button.custom_minimum_size.y >= 44.0, "icon_touch_target")
	_check(pill_button.custom_minimum_size.y >= 44.0, "pill_touch_target")
	var pointer_down := InputEventMouseButton.new()
	pointer_down.button_index = MOUSE_BUTTON_LEFT
	pointer_down.pressed = true
	icon_button.gui_input.emit(pointer_down)
	await create_timer(0.10).timeout
	_check(is_equal_approx(icon_button.scale.x, MotionResource.icon_press_scale), "icon_press_feedback")
	var pointer_up := InputEventMouseButton.new()
	pointer_up.button_index = MOUSE_BUTTON_LEFT
	pointer_up.pressed = false
	icon_button.gui_input.emit(pointer_up)
	await create_timer(0.16).timeout
	_check(icon_button.scale.is_equal_approx(Vector2.ONE), "icon_release_feedback")
	theme_card.set_view_model({"theme_id": "shanhai", "title": "The Classic of Mountains and Seas", "progress": _progress(2, 5, 0.4, 2, false)})
	_check(theme_card.theme_id == "shanhai" and theme_card.get_node("Margin/Content/Progress").text == "2 / 5", "theme_card_view_model")
	_check(not theme_card.accessibility_name.is_empty(), "theme_card_accessibility")
	level_card.set_view_model({"level_id": "shanhai_08", "title": "Nine-tailed Fox", "locked": false, "modes": [{"status": "complete"}, {"status": "available"}]})
	_check(level_card.level_id == "shanhai_08" and level_card.get_node("Margin/Content/Status").text == "complete · available", "level_card_view_model")
	settings_row.configure(&"music", "Music", true)
	_check(settings_row.setting_key == &"music" and settings_row.get_node("Toggle").button_pressed, "settings_row_configuration")
	_check(safe_area.get_theme_constant("margin_left") >= 20, "safe_area_compact_margin")
	root.size = Vector2i(768, 1024)
	await process_frame
	var regular_content_width: int = root.size.x - safe_area.get_theme_constant("margin_left") - safe_area.get_theme_constant("margin_right")
	_check(safe_area.get_theme_constant("margin_left") >= 32 and regular_content_width <= 704, "safe_area_regular_max_width")
	FocusNavigationScript.configure_linear([icon_button, pill_button])
	_check(icon_button.focus_next == icon_button.get_path_to(pill_button), "focus_linear_navigation")
	_check(modal_shell.get_node("AnimationPlayer").has_animation(&"RESET") and modal_shell.get_node("AnimationPlayer").has_animation(&"open") and modal_shell.get_node("AnimationPlayer").has_animation(&"close"), "modal_shell_timelines")
	for component in [icon_button, pill_button, theme_card, level_card, settings_row, safe_area, modal_shell]:
		component.queue_free()
	await process_frame


func _test_modal_interruption() -> void:
	var modal_shell = ModalShellScene.instantiate()
	root.add_child(modal_shell)
	await process_frame
	modal_shell.play_open(false)
	await create_timer(0.06).timeout
	modal_shell.play_close(false)
	await create_timer(0.04).timeout
	modal_shell.play_open(false)
	await create_timer(0.30).timeout
	_check(modal_shell.phase == "open" and modal_shell.active_motion_count() == 0, "modal_interrupted_reopen")
	modal_shell.play_close(true)
	await process_frame
	var no_residual_modal := root.find_children("ModalShell", "Control", true, false).is_empty()
	_check(no_residual_modal, "modal_reduced_close_releases")
	for iteration in 5:
		var rapid_modal = ModalShellScene.instantiate()
		rapid_modal.name = "RapidModal%d" % iteration
		root.add_child(rapid_modal)
		await process_frame
		rapid_modal.play_open(true)
		rapid_modal.play_close(true)
		await process_frame
	_check(root.find_children("RapidModal*", "Control", true, false).is_empty(), "modal_rapid_cycles_release")


func _check(condition: bool, name: String) -> void:
	if condition:
		print("UI_FOUNDATION_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("UI_FOUNDATION_FAIL %s" % name)
