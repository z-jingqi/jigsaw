extends SceneTree

const HomeScene := preload("res://scenes/screens/HomeScreen.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")
const GlassButtonScript := preload("res://scripts/ui/foundation/GlassButton.gd")

var _all_ok := true
var _failures: Array[String] = []
var _changed_theme := ""
var _activated_theme := ""
var _album_requested := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1206, 2622)
	var home = HomeScene.instantiate()
	root.add_child(home)
	await process_frame
	home.selected_theme_changed.connect(func(theme_id: String) -> void: _changed_theme = theme_id)
	home.theme_activated.connect(func(theme_id: String) -> void: _activated_theme = theme_id)
	home.album_requested.connect(func() -> void: _album_requested = true)
	home.set_view_model(_home_view_model())
	var logo: TextureRect = home.get_node("SafeArea/SafeContent/Header/Logo")
	var safe_area: SafeAreaContainer = home.get_node("SafeArea")
	var album_button: Button = home.get_node("SafeArea/SafeContent/Header/AlbumButton")
	var menu_button: Button = home.get_node("SafeArea/SafeContent/Header/MenuButton")
	var all_themes_button: Button = home.get_node("SafeArea/SafeContent/AllThemesButton")
	_check(logo.texture != null, "home_logo_texture")
	_check(is_equal_approx(safe_area.compact_breakpoint, 9999.0), "home_phone_safe_area_width")
	_check(album_button.get_script() == GlassButtonScript, "home_album_glass_button")
	_check(menu_button.get_script() == GlassButtonScript, "home_settings_glass_button")
	_check(all_themes_button.get_script() == GlassButtonScript, "home_all_themes_glass_button")
	_check(
		(
			album_button.custom_minimum_size == Vector2(144.0, 144.0)
			and menu_button.custom_minimum_size == Vector2(144.0, 144.0)
			and all_themes_button.custom_minimum_size == Vector2(420.0, 120.0)
		),
		"home_glass_button_touch_targets"
	)
	_check(
		(
			album_button.get_theme_font_size(&"font_size") == 18
			and all_themes_button.get_theme_font_size(&"font_size") == 42
		),
		"home_glass_button_text_scale"
	)
	_check(
		(
			menu_button.get_theme_stylebox(&"normal").shadow_size >= 8
			and all_themes_button.get_theme_stylebox(&"normal").border_width_top == 1
		),
		"home_glass_button_surface"
	)
	_check(
		(
			album_button.icon_texture != null
			and menu_button.icon_texture != null
			and album_button.icon_texture != menu_button.icon_texture
			and all_themes_button.icon_texture == null
		),
		"home_header_icon_assets"
	)
	_check(
		(
			logo.get_global_rect().end.x <= album_button.get_global_rect().position.x
			and album_button.get_global_rect().end.x <= menu_button.get_global_rect().position.x
		),
		"home_header_actions_do_not_overlap_logo"
	)
	_check(
		(
			album_button.get_global_rect().position.y >= 64.0
			and menu_button.get_global_rect().end.x <= home.size.x - 20.0
		),
		"home_header_actions_use_safe_inset"
	)
	_check(
		(
			not home.get_node("SafeArea/SafeContent/InfoPanel/ThemeProgress").visible
			and not home.get_node("SafeArea/SafeContent/InfoIncoming/ThemeProgress").visible
		),
		"home_progress_deferred"
	)
	album_button.pressed.emit()
	_check(_album_requested, "home_album_action_exposed")
	_check(home.get_node("SafeArea/SafeContent/PageLabel").text == "01 / 02", "home_initial_page")
	_check(home.get_node("CoverSlots/Current").texture != null, "home_current_cover")
	home.play_cold_entry()
	await create_timer(1.10).timeout
	_check(home.active_motion_count() == 0, "home_cold_entry_settled")
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.30, 0.12)
	_check(
		(
			home.get_node("SafeArea/SafeContent/InfoIncoming").visible
			and home.get_node("SafeArea/SafeContent/InfoIncoming/ThemeName").text.begins_with(
				"A Second"
			)
		),
		"home_incoming_information"
	)
	home.debug_end_drag()
	await create_timer(0.35).timeout
	_check(
		(
			_changed_theme == "topic_02"
			and home.get_node("SafeArea/SafeContent/PageLabel").text == "02 / 02"
		),
		"home_drag_commits_once"
	)
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
	_check(
		home.active_motion_count() == 0 and _changed_theme == "topic_01",
		"home_reduced_motion_settles"
	)
	var result := {"ok": _all_ok, "failures": _failures}
	print("HOME_SCREEN %s" % JSON.stringify(result))
	home.queue_free()
	quit(0 if _all_ok else 1)


func _home_view_model() -> Variant:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("F28A70"))
	var texture := ImageTexture.create_from_image(image)
	var progress := ViewModels.ThemeProgressViewModel.new(
		{"completed_modes": 1, "total_modes": 5, "ratio": 0.2, "paw_count": 1, "is_complete": false}
	)
	var first := ViewModels.HomeThemeViewModel.new(
		{
			"theme_id": "topic_01",
			"title": "The Classic of Mountains and Seas",
			"cover_texture": texture,
			"progress": progress,
			"home_ui_variant": "on_dark"
		}
	)
	var second := ViewModels.HomeThemeViewModel.new(
		{
			"theme_id": "topic_02",
			"title": "A Second Theme With A Long English Name",
			"cover_texture": texture,
			"progress": progress,
			"home_ui_variant": "on_dark"
		}
	)
	return ViewModels.HomeViewModel.new(
		{
			"revision": 1,
			"themes": [first, second],
			"selected_theme_id": "topic_01",
			"selected_index": 0,
			"show_home_guide": false
		}
	)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("HOME_SCREEN_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("HOME_SCREEN_FAIL %s" % name)
