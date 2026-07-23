extends SceneTree

const HomeScene := preload("res://scenes/screens/HomeScreen.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")

var _all_ok := true
var _failures: Array[String] = []
var _changed_theme := ""
var _activated_theme := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(393, 852)
	var home = HomeScene.instantiate()
	root.add_child(home)
	await process_frame
	home.selected_theme_changed.connect(func(theme_id: String) -> void: _changed_theme = theme_id)
	home.theme_activated.connect(func(theme_id: String) -> void: _activated_theme = theme_id)
	home.set_view_model(_home_view_model())
	_check(home.get_node("SafeArea/SafeContent/PageLabel").text == "01 / 02", "home_initial_page")
	_check(home.get_node("CoverSlots/Current").texture != null, "home_current_cover")
	home.play_cold_entry()
	await create_timer(1.10).timeout
	_check(home.active_motion_count() == 0, "home_cold_entry_settled")
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.30, 0.12)
	_check(home.get_node("SafeArea/SafeContent/InfoIncoming").visible and home.get_node("SafeArea/SafeContent/InfoIncoming/ThemeName").text.begins_with("A Second"), "home_incoming_information")
	home.debug_end_drag()
	await create_timer(0.35).timeout
	_check(_changed_theme == "topic_02" and home.get_node("SafeArea/SafeContent/PageLabel").text == "02 / 02", "home_drag_commits_once")
	home.debug_begin_drag()
	home.debug_drag(4.0, 0.05)
	home.debug_end_drag()
	await create_timer(0.40).timeout
	_check(_activated_theme == "topic_02", "home_small_drag_activates")
	home.set_reduced_motion(true)
	home.debug_begin_drag()
	home.debug_drag(home.size.x * 0.30, 0.12)
	home.debug_end_drag()
	await create_timer(0.14).timeout
	_check(home.active_motion_count() == 0 and _changed_theme == "topic_01", "home_reduced_motion_settles")
	var result := {"ok": _all_ok, "failures": _failures}
	print("HOME_SCREEN %s" % JSON.stringify(result))
	home.queue_free()
	quit(0 if _all_ok else 1)


func _home_view_model() -> Variant:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("F28A70"))
	var texture := ImageTexture.create_from_image(image)
	var progress := ViewModels.ThemeProgressViewModel.new({"completed_modes": 1, "total_modes": 5, "ratio": 0.2, "paw_count": 1, "is_complete": false})
	var first := ViewModels.HomeThemeViewModel.new({"theme_id": "topic_01", "title": "The Classic of Mountains and Seas", "cover_texture": texture, "progress": progress, "home_ui_variant": "on_dark"})
	var second := ViewModels.HomeThemeViewModel.new({"theme_id": "topic_02", "title": "A Second Theme With A Long English Name", "cover_texture": texture, "progress": progress, "home_ui_variant": "on_dark"})
	return ViewModels.HomeViewModel.new({"revision": 1, "themes": [first, second], "selected_theme_id": "topic_01", "selected_index": 0, "show_home_guide": false})


func _check(condition: bool, name: String) -> void:
	if condition:
		print("HOME_SCREEN_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("HOME_SCREEN_FAIL %s" % name)
