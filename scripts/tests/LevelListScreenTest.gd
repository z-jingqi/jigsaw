extends SceneTree

const ScreenScene := preload("res://scenes/screens/LevelListScreen.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")

var _all_ok := true
var _failures: Array[String] = []
var _selected := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var screen = ScreenScene.instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	screen.level_selected.connect(func(level_id: String) -> void: _selected = level_id)
	screen.set_view_model(_view_model(36))
	await process_frame
	_check(screen.grid_column_count_for_width(393.0) == 2, "compact_two_column_grid")
	_check(screen.grid_column_count_for_width(768.0) == 3, "regular_three_column_grid")
	_check(screen.get_node("SafeArea/Content/Header/ThemeTitle").text == "The Classic of Mountains and Seas", "header_title")
	_check(screen.get_node("SafeArea/Content/Scroll/GridContent").get_child_count() < 36, "virtualized_cards")
	var first_card = screen.get_node("SafeArea/Content/Scroll/GridContent").get_child(0)
	first_card.pressed.emit()
	_check(_selected == "level_00", "unlocked_card_selected")
	screen.get_node("SafeArea/Content/Scroll").scroll_vertical = 5000
	await process_frame
	var active_cards := screen.get_node("SafeArea/Content/Scroll/GridContent").get_child_count()
	_check(active_cards > 0 and active_cards < 36, "scroll_keeps_virtualized")
	screen.get_node("SafeArea/Content/Scroll").scroll_vertical = 0
	await process_frame
	screen.refresh_view_model(_view_model(36, false, true))
	await process_frame
	var interrupted_card = screen.get_node("SafeArea/Content/Scroll/GridContent").get_child(0)
	screen.get_node("SafeArea/Content/Scroll").scroll_vertical = 5000
	await process_frame
	_check(interrupted_card.get_node_or_null("unlock_outline") == null and interrupted_card.scale.is_equal_approx(Vector2.ONE), "offscreen_unlock_releases")
	screen.get_node("SafeArea/Content/Scroll").scroll_vertical = 0
	screen.refresh_view_model(_view_model(2, true))
	await process_frame
	_check(screen.get_node("SafeArea/Content/Scroll/GridContent").get_child_count() <= 2, "refresh_without_stack_rebuild")
	_selected = ""
	var locked_card = screen.get_node("SafeArea/Content/Scroll/GridContent").get_child(0)
	locked_card.pressed.emit()
	_check(_selected.is_empty(), "locked_card_does_not_select")
	screen.refresh_view_model(_view_model(2, false, true, 1))
	await process_frame
	var unlocked_card = _card_by_level(screen, "level_01")
	_check(unlocked_card.get_node_or_null("unlock_outline") != null, "unlock_sequence_started")
	await create_timer(1.35).timeout
	_check(unlocked_card.get_node_or_null("unlock_outline") == null and unlocked_card.scale.is_equal_approx(Vector2.ONE), "unlock_sequence_released")
	screen.set_reduced_motion(true)
	screen.refresh_view_model(_view_model(3, false, true, 2))
	await process_frame
	var reduced_card = _card_by_level(screen, "level_02")
	_check(reduced_card.get_node_or_null("unlock_outline") == null and screen.active_motion_count() == 0, "reduced_motion_unlock_finishes_immediately")
	screen.navigation_exit({})
	await create_timer(0.25).timeout
	_check(screen.debug_active_card_count() == 0 and screen.active_motion_count() == 0, "exit_clears_virtual_cards_and_motion")
	screen.navigation_enter({"view_model": _view_model(2)}, {"reduced_motion": true})
	await process_frame
	_check(screen.get_node("SafeArea/Content/Header").modulate.a == 1.0 and screen.debug_active_card_count() > 0, "reentry_restores_visible_screen")
	var result := {"ok": _all_ok, "failures": _failures}
	print("LEVEL_LIST_SCREEN %s" % JSON.stringify(result))
	screen.queue_free()
	quit(0 if _all_ok else 1)

func _view_model(count: int, first_locked := false, first_new := false, newly_unlocked_index := 0) -> Variant:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("A8DCC6"))
	var texture := ImageTexture.create_from_image(image)
	var progress := ViewModels.ThemeProgressViewModel.new({"completed_modes": 4, "total_modes": 5, "ratio": 0.8, "paw_count": 5, "is_complete": false})
	var cards: Array[ViewModels.LevelCardViewModel] = []
	for index in count:
		cards.append(ViewModels.LevelCardViewModel.new({"level_id": "level_%02d" % index, "title": "Level %02d" % index, "thumbnail": texture, "locked": first_locked and index == 0, "recommended": index == 0, "newly_unlocked": first_new and index == newly_unlocked_index, "modes": [ViewModels.ModeStatusViewModel.new(&"polygon", "Polygon", &"completed", &"replay", true), ViewModels.ModeStatusViewModel.new(&"knob", "Knob", &"not_started", &"start", true)]}))
	return ViewModels.LevelListViewModel.new({"revision": 1, "theme_id": "topic_01", "theme_title": "The Classic of Mountains and Seas", "theme_progress": progress, "focus_level_id": "level_00", "levels": cards})

func _check(condition: bool, name: String) -> void:
	if condition:
		print("LEVEL_LIST_SCREEN_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("LEVEL_LIST_SCREEN_FAIL %s" % name)


func _card_by_level(screen: Control, level_id: String) -> Control:
	for card in screen.get_node("SafeArea/Content/Scroll/GridContent").get_children():
		if str(card.get("level_id")) == level_id:
			return card
	return null
