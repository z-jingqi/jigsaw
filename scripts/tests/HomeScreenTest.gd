extends SceneTree

const HomeScene := preload("res://scenes/screens/HomeScreen.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")
const GlassButtonScript := preload("res://scripts/ui/foundation/GlassButton.gd")
const MotionResource := preload("res://themes/motion_tokens.tres")

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
	var header := home.get_node("SafeArea/SafeContent/Header") as Control
	var page_label := home.get_node("SafeArea/SafeContent/PageLabel") as Control
	var incoming_theme_name := home.get_node("SafeArea/SafeContent/InfoIncoming/ThemeName") as Label
	var gesture_catcher := home.get_node("GestureCatcher") as Control
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
			and all_themes_button.get_theme_font_size(&"font_size") == 44
		),
		"home_glass_button_text_scale"
	)
	_check(
		(
			gesture_catcher.mouse_filter == Control.MOUSE_FILTER_STOP
			and safe_area.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and header.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and logo.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and home.info_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE
		),
		"home_passive_layers_do_not_block_pointer_paging"
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
			home.get_node("SafeArea/SafeContent/InfoPanel/ThemeProgress").visible
			and not home.get_node("SafeArea/SafeContent/InfoIncoming").visible
		),
		"home_progress_visible"
	)
	var home_progress := (
		home.get_node("SafeArea/SafeContent/InfoPanel/ThemeProgress") as ThemeProgress
	)
	var progress_cat := home_progress.get_node("Journey/Cat") as TextureRect
	var progress_fish := home_progress.get_node("Journey/Fish") as TextureRect
	var progress_completion := home_progress.get_node("Journey/Completion") as TextureRect
	var first_paw := home_progress.get_node("Journey/Paws/Paw1") as TextureRect
	var title_font: Font = home.theme_name.get_theme_font(&"font")
	_check(
		(
			home_progress.size.x <= 440.0
			and progress_fish.position.x + progress_fish.size.x <= home_progress.size.x + 0.5
		),
		"home_progress_stays_in_left_column"
	)
	_check(
		(
			absf(progress_fish.size.x - progress_completion.size.x * 0.5) <= 0.5
			and absf(progress_completion.size.y - progress_cat.size.y) <= 0.5
			and title_font is FontVariation
			and float((title_font as FontVariation).variation_opentype.get(&"wght", 0.0)) >= 900.0
			and (title_font as FontVariation).variation_embolden >= 0.8
		),
		"home_progress_fish_scale_and_title_weight"
	)
	_check(
		(
			absf(
				(
					(progress_fish.position.y + progress_fish.size.y)
					- (progress_cat.position.y + progress_cat.size.y)
				)
			)
			<= 0.5
		),
		"home_progress_cat_and_fish_share_ground"
	)
	_check(
		(
			absf(progress_cat.get_global_rect().end.y - all_themes_button.get_global_rect().end.y)
			<= 1.0
		),
		"home_progress_ground_aligns_all_themes_bottom"
	)
	var page_button_gap := (
		all_themes_button.get_global_rect().position.y - page_label.get_global_rect().end.y
	)
	_check(
		(
			home.theme_name.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM
			and incoming_theme_name.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM
			and page_button_gap >= 12.0
			and page_button_gap <= 20.0
		),
		"home_bottom_information_grid"
	)
	_check(
		(
			first_paw.visible
			and first_paw.position.x + first_paw.size.x <= progress_cat.position.x + 0.5
		),
		"home_progress_paw_trails_cat"
	)
	home_progress.reduced_motion = true
	(
		home_progress
		. set_progress_data(
			{
				"completed_modes": 4,
				"total_modes": 5,
				"ratio": 0.8,
				"paw_count": 4,
				"is_complete": false,
				"accessibility_text": "4 / 5",
			}
		)
	)
	var second_paw := home_progress.get_node("Journey/Paws/Paw2") as TextureRect
	var column_gap := second_paw.position.x - (first_paw.position.x + first_paw.size.x)
	_check(
		(
			absf(second_paw.position.y - (first_paw.position.y + first_paw.size.y)) <= 0.5
			and (
				absf(
					(
						(second_paw.position.y + second_paw.size.y)
						- (progress_cat.position.y + progress_cat.size.y)
					)
				)
				<= 0.5
			)
			and column_gap >= 9.0
			and column_gap <= 12.0
		),
		"home_progress_paws_compact_grid"
	)
	var cat_center_80 := progress_cat.position.x + progress_cat.size.x * 0.5
	(
		home_progress
		. set_progress_data(
			{
				"completed_modes": 90,
				"total_modes": 100,
				"ratio": 0.9,
				"paw_count": 5,
				"is_complete": false,
				"accessibility_text": "90 / 100",
			}
		)
	)
	var fifth_paw := home_progress.get_node("Journey/Paws/Paw5") as TextureRect
	var fifth_paw_gap := progress_cat.position.x - (fifth_paw.position.x + fifth_paw.size.x)
	_check(
		fifth_paw.visible and fifth_paw_gap >= 9.0 and fifth_paw_gap <= 12.0,
		"home_progress_fifth_paw_slot"
	)
	(
		home_progress
		. set_progress_data(
			{
				"completed_modes": 3,
				"total_modes": 5,
				"ratio": 0.6,
				"paw_count": 3,
				"is_complete": false,
				"accessibility_text": "3 / 5",
			}
		)
	)
	var cat_center_60 := progress_cat.position.x + progress_cat.size.x * 0.5
	(
		home_progress
		. set_progress_data(
			{
				"completed_modes": 5,
				"total_modes": 5,
				"ratio": 1.0,
				"paw_count": 5,
				"is_complete": true,
				"accessibility_text": "5 / 5",
			}
		)
	)
	var completion_center_100 := progress_completion.position.x + progress_completion.size.x * 0.5
	_check(
		(
			absf((completion_center_100 - cat_center_80) - (cat_center_80 - cat_center_60)) <= 0.5
			and (
				absf(
					(
						(progress_completion.position.y + progress_completion.size.y)
						- (progress_cat.position.y + progress_cat.size.y)
					)
				)
				<= 0.5
			)
		),
		"home_progress_completion_keeps_scale_ground_and_step"
	)
	(
		home_progress
		. set_progress_data(
			{
				"completed_modes": 1,
				"total_modes": 5,
				"ratio": 0.2,
				"paw_count": 1,
				"is_complete": false,
				"accessibility_text": "1 / 5",
			}
		)
	)
	home_progress.reduced_motion = false
	album_button.pressed.emit()
	_check(_album_requested, "home_album_action_exposed")
	var current_page := home.get_node("SafeArea/SafeContent/PageLabel/PageRow/CurrentPage") as Label
	var total_page := home.get_node("SafeArea/SafeContent/PageLabel/PageRow/TotalPage") as Label
	var current_page_font := current_page.get_theme_font(&"font") as FontVariation
	var total_page_font := total_page.get_theme_font(&"font") as FontVariation
	_check(
		(
			current_page.text == "01"
			and total_page.text == " / 02"
			and current_page.get_theme_color(&"font_color").is_equal_approx(Color("F28A70"))
			and all_themes_button.text == "全部主题"
			and current_page.get_theme_font_size(&"font_size") == 46
			and total_page.get_theme_font_size(&"font_size") == 44
			and current_page_font.variation_embolden >= 1.3
			and total_page_font.variation_embolden >= 1.0
			and current_page_font.variation_embolden > total_page_font.variation_embolden
		),
		"home_initial_page"
	)
	_check(home.get_node("CoverSlots/Current").texture != null, "home_current_cover")
	home.play_cold_entry()
	await create_timer(0.30).timeout
	var entry_state: Dictionary = home.debug_state_snapshot()
	_check(
		(
			home.cover_slots.modulate.a > 0.0
			and home.cover_slots.modulate.a < 1.0
			and header.offset_top > 40.0
			and header.offset_top < 64.0
			and home.info_panel.offset_top > -359.0
			and home.info_panel.offset_top <= -319.0
			and not bool(entry_state.entry_interaction_ready)
			and menu_button.mouse_filter == Control.MOUSE_FILTER_IGNORE
		),
		"home_cold_entry_midpoint"
	)
	await create_timer(0.80).timeout
	_check(
		(
			home.active_motion_count() == 0
			and is_equal_approx(header.offset_top, 64.0)
			and is_equal_approx(home.info_panel.offset_top, -359.0)
			and is_equal_approx(page_label.offset_top, -280.0)
			and bool(home.debug_state_snapshot().entry_interaction_ready)
			and menu_button.mouse_filter == Control.MOUSE_FILTER_STOP
		),
		"home_cold_entry_settled"
	)
	var drag_down := InputEventMouseButton.new()
	drag_down.button_index = MOUSE_BUTTON_LEFT
	drag_down.pressed = true
	drag_down.position = home.size * Vector2(0.5, 0.4)
	Input.parse_input_event(drag_down)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.position = drag_down.position - Vector2(home.size.x * 0.30, 0.0)
	drag_motion.relative = Vector2(-home.size.x * 0.30, 0.0)
	drag_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(drag_motion)
	await process_frame
	_check(
		float(home.debug_state_snapshot().gesture_progress) >= 0.29, "home_mouse_drag_reaches_pager"
	)
	var drag_up := InputEventMouseButton.new()
	drag_up.button_index = MOUSE_BUTTON_LEFT
	drag_up.pressed = false
	drag_up.position = drag_motion.position
	Input.parse_input_event(drag_up)
	await create_timer(0.32).timeout
	_check(
		home.debug_state_snapshot().selected_index == 1 and _activated_theme.is_empty(),
		"home_mouse_drag_commits_without_activation"
	)
	home.set_view_model(_home_view_model())
	_changed_theme = ""
	var click_down := InputEventMouseButton.new()
	click_down.button_index = MOUSE_BUTTON_LEFT
	click_down.pressed = true
	click_down.position = home.size * Vector2(0.5, 0.4)
	Input.parse_input_event(click_down)
	var click_up := InputEventMouseButton.new()
	click_up.button_index = MOUSE_BUTTON_LEFT
	click_up.pressed = false
	click_up.position = click_down.position
	Input.parse_input_event(click_up)
	await create_timer(0.14).timeout
	_check(_activated_theme == "topic_01", "home_mouse_click_activates")
	_activated_theme = ""
	var pointer_down := InputEventMouseButton.new()
	pointer_down.button_index = MOUSE_BUTTON_LEFT
	pointer_down.pressed = true
	menu_button.gui_input.emit(pointer_down)
	await create_timer(0.04).timeout
	_check(home.active_motion_count() >= 1, "home_settings_press_active")
	await create_timer(0.06).timeout
	_check(
		is_equal_approx(menu_button.scale.x, MotionResource.icon_press_scale),
		"home_settings_press_scale"
	)
	_check(
		(menu_button as GlassButton).debug_icon_rotation_degrees() >= 7.9,
		"home_settings_press_rotation"
	)
	var pointer_up := InputEventMouseButton.new()
	pointer_up.button_index = MOUSE_BUTTON_LEFT
	pointer_up.pressed = false
	menu_button.gui_input.emit(pointer_up)
	await create_timer(0.16).timeout
	_check(
		(
			menu_button.scale.is_equal_approx(Vector2.ONE)
			and absf((menu_button as GlassButton).debug_icon_rotation_degrees()) <= 0.1
			and home.active_motion_count() == 0
		),
		"home_settings_release_motion"
	)
	all_themes_button.gui_input.emit(pointer_down)
	await create_timer(0.10).timeout
	_check(
		is_equal_approx(all_themes_button.scale.x, MotionResource.primary_press_scale),
		"home_all_themes_press_motion"
	)
	all_themes_button.gui_input.emit(pointer_up)
	await create_timer(0.16).timeout
	_check(all_themes_button.scale.is_equal_approx(Vector2.ONE), "home_all_themes_release_motion")
	home.set_reduced_motion(true)
	menu_button.gui_input.emit(pointer_down)
	await create_timer(0.10).timeout
	_check(
		(
			menu_button.scale.is_equal_approx(Vector2.ONE)
			and absf((menu_button as GlassButton).debug_icon_rotation_degrees()) <= 0.1
		),
		"home_button_reduced_motion"
	)
	menu_button.gui_input.emit(pointer_up)
	home.set_reduced_motion(false)
	home.debug_begin_drag()
	home.debug_drag(home.size.x * 0.30, 1.0)
	var loop_back_state: Dictionary = home.debug_state_snapshot()
	_check(
		(
			float(loop_back_state.gesture_progress) >= 0.29
			and home.incoming_info.visible
			and home.incoming_current_page_label.text == "02"
			and home.current_cover.scale.x < 1.0
			and home.previous_cover.scale.x > 1.0
			and home.current_cover.modulate.a < 1.0
			and home.previous_cover.modulate.a < 1.0
		),
		"home_first_page_wraps_with_cover_depth_motion"
	)
	home.debug_end_drag()
	await create_timer(0.35).timeout
	_check(home.debug_state_snapshot().selected_index == 1, "home_first_page_wraps_to_last")
	_check(_changed_theme == "topic_02", "home_first_page_wrap_emits_theme")
	_check(_activated_theme.is_empty(), "home_first_page_wrap_does_not_activate")
	_check(home.active_motion_count() == 0, "home_first_page_wrap_releases_motion")
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.30, 1.0)
	_check(
		home.incoming_current_page_label.text == "01", "home_last_page_previews_wrapped_first_page"
	)
	home.debug_end_drag()
	await create_timer(0.35).timeout
	_check(
		home.debug_state_snapshot().selected_index == 0 and _changed_theme == "topic_01",
		"home_last_page_wraps_to_first"
	)
	_changed_theme = ""
	var outgoing_name_start_x: float = home.theme_name.position.x
	var incoming_name_start_x: float = incoming_theme_name.position.x
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.20, 1.0)
	_check(
		(
			home.incoming_info.visible
			and home.incoming_current_page_label.text == "02"
			and home.theme_name.modulate.a < 1.0
			and incoming_theme_name.modulate.a <= 0.01
			and home.theme_name.position.x < outgoing_name_start_x
			and incoming_theme_name.position.x > incoming_name_start_x
		),
		"home_information_leaves_before_incoming"
	)
	home.debug_end_drag()
	await create_timer(0.28).timeout
	_check(
		(
			home.debug_state_snapshot().selected_index == 0
			and home.theme_name.modulate.a >= 0.99
			and not home.incoming_info.visible
		),
		"home_drag_below_ratio_cancels"
	)
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.50, 1.0)
	home.debug_end_drag()
	await create_timer(0.06).timeout
	var settling_state: Dictionary = home.debug_state_snapshot()
	home.debug_begin_drag()
	var takeover_state: Dictionary = home.debug_state_snapshot()
	_check(
		(
			float(settling_state.gesture_progress) > 0.5
			and is_equal_approx(
				float(settling_state.gesture_offset), float(takeover_state.gesture_offset)
			)
		),
		"home_reverse_gesture_takes_over_current_visual"
	)
	home.debug_drag(home.size.x * 0.80, 1.0)
	home.debug_end_drag()
	await create_timer(0.28).timeout
	_check(
		home.debug_state_snapshot().selected_index == 0 and _changed_theme == "",
		"home_reverse_gesture_returns_without_commit"
	)
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.25, 1.0)
	_check(
		(
			is_equal_approx(float(home.debug_state_snapshot().gesture_progress), 0.25)
			and home.theme_name.modulate.a > 0.0
			and incoming_theme_name.modulate.a <= 0.01
		),
		"home_drag_quarter_state"
	)
	home.debug_drag(-home.size.x * 0.25, 1.0)
	_check(
		(
			home.get_node("SafeArea/SafeContent/InfoIncoming").visible
			and home.get_node("SafeArea/SafeContent/InfoIncoming/ThemeName").text.begins_with(
				"A Second"
			)
			and home.theme_name.modulate.a <= 0.01
			and incoming_theme_name.modulate.a > 0.1
			and incoming_theme_name.modulate.a < 1.0
			and home.incoming_current_page_label.text == "02"
		),
		"home_incoming_information_layers"
	)
	home.debug_drag(-home.size.x * 0.25, 1.0)
	_check(
		(
			is_equal_approx(float(home.debug_state_snapshot().gesture_progress), 0.75)
			and incoming_theme_name.modulate.a >= 0.99
			and home.incoming_page_label.modulate.a > 0.0
		),
		"home_drag_three_quarter_state"
	)
	home.debug_end_drag()
	await create_timer(0.35).timeout
	_check(
		_changed_theme == "topic_02" and current_page.text == "02" and total_page.text == " / 02",
		"home_drag_commits_once"
	)
	home.debug_begin_drag()
	home.debug_drag(home.size.x * 0.10, 0.03)
	home.debug_end_drag()
	await create_timer(0.35).timeout
	_check(
		_changed_theme == "topic_01" and home.debug_state_snapshot().selected_index == 0,
		"home_velocity_commits_below_ratio"
	)
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.30, 1.0)
	home.debug_end_drag()
	await create_timer(0.35).timeout
	_check(home.debug_state_snapshot().selected_index == 1, "home_restores_second_theme")
	home.debug_begin_drag()
	home.debug_drag(4.0, 0.05)
	home.debug_end_drag()
	await create_timer(0.40).timeout
	_check(_activated_theme == "topic_02", "home_small_drag_activates")
	home.set_reduced_motion(true)
	var reduced_name_position: Vector2 = home.theme_name.position
	var reduced_progress_position: Vector2 = home.progress.position
	home.debug_begin_drag()
	home.debug_drag(home.size.x * 0.30, 0.12)
	_check(
		(
			home.theme_name.position.is_equal_approx(reduced_name_position)
			and home.progress.position.is_equal_approx(reduced_progress_position)
			and home.current_cover.scale.is_equal_approx(Vector2.ONE)
			and home.previous_cover.scale.is_equal_approx(Vector2.ONE)
			and home.current_cover.modulate.a < 1.0
			and home.previous_cover.modulate.a < 1.0
		),
		"home_reduced_motion_uses_crossfade_without_spatial_depth"
	)
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
