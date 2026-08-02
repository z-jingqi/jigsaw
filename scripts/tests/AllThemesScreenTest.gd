extends SceneTree

const ScreenScene := preload("res://scenes/screens/AllThemesScreen.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")

var _all_ok := true
var _failures: Array[String] = []
var _selected_theme := ""
var _source_rect := Rect2()
var _close_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(603, 1311)
	var screen := ScreenScene.instantiate() as AllThemesScreen
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme_activated.connect(
		func(theme_id: String, source_rect: Rect2, _source_texture: Texture2D) -> void:
			_selected_theme = theme_id
			_source_rect = source_rect
	)
	screen.close_requested.connect(func() -> void: _close_count += 1)
	await process_frame
	screen.navigation_enter({"view_model": _view_model(9)}, {"reduced_motion": false})
	await create_timer(0.38).timeout
	_check(screen.active_motion_count() == 0, "enter_animation_releases")
	_check(
		screen.get_node("SafeArea/Content/Header/Title").text == "全部主题",
		"localized_full_screen_title"
	)
	_check(screen.get_node_or_null("SafeArea/Content/Scroll") == null, "old_scroll_path_removed")
	_check(
		screen.get_node("Backdrop").color.is_equal_approx(Color("FFF8ED")),
		"warm_full_screen_surface"
	)
	var phone_state := screen.debug_state_snapshot()
	_check(int(phone_state.page_capacity) == 4, "phone_uses_two_by_two_page")
	_check(int(phone_state.page_count) == 3, "phone_page_count")
	_check(
		screen.debug_page_card_ids() == ["topic_01", "topic_02", "topic_03", "topic_04"],
		"phone_first_page_cards"
	)
	var current_page: Control = screen.get_node("SafeArea/Content/PagerClip/CurrentPage")
	var current_card := _card_by_theme(current_page, "topic_01")
	var complete_card := _card_by_theme(current_page, "topic_04")
	_check(
		current_card.get_node("Information/Content/TitleRow/CurrentIndicator").visible,
		"current_theme_coral_marker"
	)
	_check(
		(
			current_card.get_node("Information/Content/Progress").text == "0 / 5"
			and not current_card.get_node("CompletionMark").visible
		),
		"incomplete_card_is_numeric_only"
	)
	_check(
		(
			complete_card.get_node("Information/Content/Progress").text == "5 / 5"
			and complete_card.get_node("CompletionMark").visible
		),
		"complete_card_keeps_numeric_and_completion_mark"
	)
	var indicators: HBoxContainer = screen.get_node("SafeArea/Content/PageIndicator")
	_check(indicators.visible and indicators.get_child_count() == 3, "paw_page_indicator_count")
	var active_paw := indicators.get_child(0).get_child(0) as TextureRect
	var inactive_paw := indicators.get_child(1).get_child(0) as TextureRect
	_check(active_paw.size == Vector2(38, 38), "active_paw_is_enlarged")
	_check(inactive_paw.size == Vector2(28, 28), "inactive_paw_uses_fixed_outline_size")
	_check(
		inactive_paw.texture.resource_path.ends_with("progress_paw_outline.svg"),
		"inactive_paw_is_outline"
	)
	await _drag_page(screen, -360.0)
	_check(_selected_theme.is_empty(), "drag_does_not_activate_card")
	_check(int(screen.debug_state_snapshot().page_index) == 1, "left_drag_advances_page")
	_check(screen.debug_page_card_ids()[0] == "topic_05", "second_page_content")
	await _drag_page(screen, -360.0)
	await _drag_page(screen, -360.0)
	_check(int(screen.debug_state_snapshot().page_index) == 0, "last_page_wraps_to_first")
	await _drag_page(screen, 360.0)
	_check(int(screen.debug_state_snapshot().page_index) == 2, "first_page_wraps_to_last")
	await _drag_page(screen, -360.0)
	var first_card := (
		screen.get_node("SafeArea/Content/PagerClip/CurrentPage").get_child(0) as ThemeCard
	)
	await _click_card(screen, first_card)
	_check(
		_selected_theme == "topic_01" and _source_rect.size.x > 0.0,
		"click_activates_theme_with_source_rect"
	)
	screen.navigation_set_active(false)
	screen.navigation_set_active(true)
	_check(
		not screen.get_node("SafeArea/Content/Header/CloseButton").disabled, "reactivation_unlocks"
	)
	screen.get_node("SafeArea/Content/Header/CloseButton").pressed.emit()
	_check(_close_count == 1, "close_signal")
	root.size = Vector2i(768, 1024)
	await process_frame
	await process_frame
	screen.set_view_model(_view_model(13))
	await process_frame
	var tablet_state := screen.debug_state_snapshot()
	_check(int(tablet_state.page_capacity) == 6, "tablet_uses_three_by_two_page")
	_check(int(tablet_state.page_count) == 3, "tablet_page_count")
	_check(screen.debug_page_card_ids().size() == 6, "tablet_renders_six_cards")
	screen.set_view_model(_view_model(4))
	await process_frame
	_check(
		int(screen.debug_state_snapshot().page_count) == 1 and not indicators.visible,
		"single_page_hides_indicator"
	)
	screen.set_reduced_motion(true)
	_selected_theme = ""
	first_card = screen.get_node("SafeArea/Content/PagerClip/CurrentPage").get_child(0) as ThemeCard
	await _click_card(screen, first_card)
	_check(
		_selected_theme == "topic_01" and screen.active_motion_count() == 0,
		"reduced_motion_selects_immediately"
	)
	screen.navigation_exit({})
	_check(screen.active_motion_count() == 0, "exit_clears_motion")
	var result := {"ok": _all_ok, "failures": _failures}
	print("ALL_THEMES_SCREEN %s" % JSON.stringify(result))
	screen.queue_free()
	quit(0 if _all_ok else 1)


func _drag_page(screen: AllThemesScreen, distance: float) -> void:
	var surface: Control = screen.get_node("SafeArea/Content/PagerClip/GestureSurface")
	var center := surface.size * 0.5
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	surface.gui_input.emit(down)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = center + Vector2(distance, 0.0)
	motion.relative = Vector2(distance, 0.0)
	surface.gui_input.emit(motion)
	_check(
		float(screen.debug_state_snapshot().gesture_progress) >= 0.25,
		"drag_exposes_gesture_progress"
	)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = motion.position
	surface.gui_input.emit(up)
	await create_timer(0.34).timeout


func _click_card(screen: AllThemesScreen, card: ThemeCard) -> void:
	var surface: Control = screen.get_node("SafeArea/Content/PagerClip/GestureSurface")
	var point: Vector2 = (
		surface.get_global_transform_with_canvas().affine_inverse()
		* card.get_global_rect().get_center()
	)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = point
	surface.gui_input.emit(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	surface.gui_input.emit(up)
	await create_timer(0.10).timeout


func _view_model(count: int) -> Variant:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("A8DCC6"))
	var texture := ImageTexture.create_from_image(image)
	var cards: Array[ViewModels.ThemeCardViewModel] = []
	for index in count:
		var completed := 5 if index == 3 else (index % 5)
		cards.append(
			_card("topic_%02d" % [index + 1], "主题 %02d" % [index + 1], texture, completed, 5)
		)
	return ViewModels.AllThemesViewModel.new(
		{"revision": 1, "cards": cards, "current_theme_id": "topic_01"}
	)


func _card(
	theme_id: String, title: String, texture: Texture2D, completed: int, total: int
) -> Variant:
	var ratio := float(completed) / float(total) if total > 0 else 0.0
	var progress := (
		ViewModels
		. ThemeProgressViewModel
		. new(
			{
				"completed_modes": completed,
				"total_modes": total,
				"ratio": ratio,
				"paw_count": 5 if ratio >= 0.8 else ceili(ratio * 5.0),
				"is_complete": total > 0 and completed == total,
			}
		)
	)
	return (
		ViewModels
		. ThemeCardViewModel
		. new(
			{
				"theme_id": theme_id,
				"title": title,
				"cover_texture": texture,
				"progress": progress,
				"is_current": theme_id == "topic_01",
				"is_new": completed == 0,
			}
		)
	)


func _card_by_theme(host: Control, theme_id: String) -> ThemeCard:
	for card in host.get_children():
		if card is ThemeCard and (card as ThemeCard).theme_id == theme_id:
			return card as ThemeCard
	return null


func _check(condition: bool, name: String) -> void:
	if condition:
		print("ALL_THEMES_SCREEN_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("ALL_THEMES_SCREEN_FAIL %s" % name)
