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
	var screen = ScreenScene.instantiate()
	root.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(393, 852)
	await process_frame
	screen.theme_activated.connect(func(theme_id: String, source_rect: Rect2) -> void:
		_selected_theme = theme_id
		_source_rect = source_rect)
	screen.close_requested.connect(func() -> void: _close_count += 1)
	var view_model: Variant = _view_model()
	screen.navigation_enter({"view_model": view_model}, {"reduced_motion": false})
	await create_timer(0.36).timeout
	_check(screen.active_motion_count() == 0, "enter_animation_releases")
	var animation_player: AnimationPlayer = screen.get_node("AnimationPlayer")
	_check(animation_player.has_animation(&"RESET") and animation_player.has_animation(&"enter") and animation_player.has_animation(&"exit"), "screen_timelines")
	_check(screen.grid_column_count_for_width(393.0) == 2, "compact_two_column_grid")
	_check(screen.grid_column_count_for_width(768.0) == 3, "regular_three_column_grid")
	var grid: Control = screen.get_node("SafeArea/Content/Scroll/GridContent")
	_check(grid.get_child_count() == 4, "renders_theme_cards")
	var incomplete = _card_by_theme(grid, "topic_01")
	var complete = _card_by_theme(grid, "topic_02")
	var empty = _card_by_theme(grid, "topic_03")
	_check(not incomplete.get_node("Margin/Content/Progress/Journey").visible and not incomplete.get_node("Margin/Content/Progress/NumericCompletion").visible, "incomplete_numeric_only")
	_check(complete.get_node("Margin/Content/Progress/Numeric").text == "5 / 5" and complete.get_node("Margin/Content/Progress/NumericCompletion").visible, "complete_numeric_mark")
	_check(empty.get_node("Margin/Content/Progress/Numeric").text == "0 / 0" and not empty.get_node("Margin/Content/Progress/NumericCompletion").visible, "zero_total_not_complete")
	incomplete.pressed.emit()
	await create_timer(0.1).timeout
	_check(_selected_theme == "topic_01" and _source_rect.size.x > 0.0, "theme_activation_source_rect")
	screen.navigation_set_active(false)
	screen.navigation_set_active(true)
	_check(not screen.get_node("SafeArea/Content/Header/CloseButton").disabled and screen.get_node("SafeArea/Content/Header").modulate.a == 1.0, "reactivation_unlocks_after_selection")
	screen.get_node("SafeArea/Content/Header/CloseButton").pressed.emit()
	_check(_close_count == 1, "close_signal")
	screen.set_reduced_motion(true)
	_selected_theme = ""
	complete.pressed.emit()
	_check(_selected_theme == "topic_02" and screen.active_motion_count() == 0, "reduced_motion_selects_immediately")
	screen.navigation_exit({})
	_check(screen.active_motion_count() == 0, "exit_clears_motion")
	var result := {"ok": _all_ok, "failures": _failures}
	print("ALL_THEMES_SCREEN %s" % JSON.stringify(result))
	screen.queue_free()
	quit(0 if _all_ok else 1)


func _view_model() -> Variant:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("A8DCC6"))
	var texture := ImageTexture.create_from_image(image)
	var cards: Array[ViewModels.ThemeCardViewModel] = []
	cards.append(_card("topic_01", "The Classic of Mountains and Seas", texture, 1, 5))
	cards.append(_card("topic_02", "Garden Stories", texture, 5, 5))
	cards.append(_card("topic_03", "Empty Theme", texture, 0, 0))
	cards.append(_card("topic_04", "Long Theme Name for Responsive Layout", texture, 2, 5))
	return ViewModels.AllThemesViewModel.new({"revision": 1, "cards": cards, "current_theme_id": "topic_01"})


func _card(theme_id: String, title: String, texture: Texture2D, completed: int, total: int) -> Variant:
	var ratio := float(completed) / float(total) if total > 0 else 0.0
	var progress := ViewModels.ThemeProgressViewModel.new({"completed_modes": completed, "total_modes": total, "ratio": ratio, "paw_count": 5 if ratio >= 0.8 else 1, "is_complete": total > 0 and completed == total})
	return ViewModels.ThemeCardViewModel.new({"theme_id": theme_id, "title": title, "cover_texture": texture, "progress": progress, "is_current": theme_id == "topic_01", "is_new": completed == 0})


func _card_by_theme(grid: Control, theme_id: String) -> Control:
	for card in grid.get_children():
		if str(card.get("theme_id")) == theme_id:
			return card
	return null


func _check(condition: bool, name: String) -> void:
	if condition:
		print("ALL_THEMES_SCREEN_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("ALL_THEMES_SCREEN_FAIL %s" % name)
