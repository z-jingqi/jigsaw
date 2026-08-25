extends SceneTree

const MotionSettle := preload("res://scripts/tests/support/MotionSettle.gd")
const HomeScene := preload("res://scenes/screens/HomeScreen.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")
const GlassButtonScript := preload("res://scripts/ui/foundation/GlassButton.gd")
const MotionResource := preload("res://themes/motion_tokens.tres")

const SURFACE := Color(0.980392, 0.917647, 0.843137)
const PRIMARY := Color(0.917647, 0.321569, 0.145098)
const TRACK := Color(0.776471, 0.839216, 0.788235)
const TEAL := Color(0.0980392, 0.364706, 0.392157)

var _all_ok := true
var _failures: Array[String] = []
var _changed_theme := ""
var _activated_theme := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1206, 2622)
	var home = HomeScene.instantiate()
	root.add_child(home)
	await process_frame
	home.selected_theme_changed.connect(func(theme_id: String) -> void: _changed_theme = theme_id)
	home.theme_activated.connect(func(theme_id: String) -> void: _activated_theme = theme_id)
	home.set_view_model(_home_view_model())
	await process_frame
	var logo: TextureRect = home.get_node("SafeArea/SafeContent/Header/Logo")
	var safe_area: SafeAreaContainer = home.get_node("SafeArea")
	var menu_button: Button = home.get_node("SafeArea/SafeContent/Header/MenuButton")
	var header := home.get_node("SafeArea/SafeContent/Header") as Control
	var gesture_catcher := home.get_node("GestureCatcher") as Control
	var incoming_theme_name := home.get_node("BottomPanel/InfoIncoming/ThemeName") as Label

	# --- header -------------------------------------------------------------
	_check(logo.texture != null, "home_logo_texture")
	_check(is_equal_approx(safe_area.compact_breakpoint, 9999.0), "home_phone_safe_area_width")
	_check(menu_button.get_script() == GlassButtonScript, "home_settings_glass_button")
	_check(menu_button.get_global_rect().size.x >= 44.0, "home_glass_button_touch_targets")
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
	_check(menu_button.icon_texture != null, "home_header_icon_assets")
	_check(
		logo.get_global_rect().end.x <= menu_button.get_global_rect().position.x,
		"home_header_actions_do_not_overlap_logo"
	)
	_check(
		menu_button.get_global_position().x + menu_button.size.x <= home.size.x - 20.0,
		"home_header_actions_use_safe_inset"
	)

	# --- bottom panel palette and composition -------------------------------
	var panel_style := home.bottom_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	var badge_style := home.page_label.get_theme_stylebox(&"panel") as StyleBoxFlat
	var track_style := home.progress_track.get_theme_stylebox(&"panel") as StyleBoxFlat
	var fill_style := home.progress_fill.get_theme_stylebox(&"panel") as StyleBoxFlat
	var start_style := home.start_button.get_theme_stylebox(&"normal") as StyleBoxFlat
	_check(
		(
			panel_style.bg_color.is_equal_approx(SURFACE)
			and start_style.bg_color.is_equal_approx(PRIMARY)
			and fill_style.bg_color.is_equal_approx(PRIMARY)
			and track_style.bg_color.is_equal_approx(TRACK)
			and badge_style.bg_color.is_equal_approx(TEAL)
		),
		"home_panel_base_palette"
	)
	_check(
		(
			panel_style.corner_radius_top_left > 0
			and panel_style.corner_radius_bottom_left == 0
			and panel_style.border_width_top == 0
		),
		"home_panel_rounds_only_its_top"
	)
	_check(
		(
			is_equal_approx(home.bottom_panel.size.x, home.size.x)
			and is_equal_approx(
				home.bottom_panel.position.y + home.bottom_panel.size.y, home.size.y
			)
		),
		"home_panel_is_bottom_anchored_full_bleed"
	)
	_check(
		(
			home.theme_name.get_rect().end.x <= home.page_label.get_rect().position.x
			and home.page_label.get_rect().end.y <= home.progress_track.get_rect().position.y
			and home.progress_track.get_rect().end.y <= home.start_button.get_rect().position.y
			and home.start_button.get_rect().end.y <= home.bottom_panel.size.y
		),
		"home_panel_stacks_title_progress_and_action"
	)
	_check(home.start_button.text == "开始拼图", "home_start_button_label")

	# --- adaptive title, progress readout -----------------------------------
	var title_label := home.get_node("BottomPanel/InfoLive/ThemeName") as Label
	var long_title_size: int = title_label.get_theme_font_size(&"font_size")
	var long_title_font: Font = title_label.get_theme_font(&"font")
	var wrapped_block: Vector2 = long_title_font.get_multiline_string_size(
		home.theme_name.text, HORIZONTAL_ALIGNMENT_LEFT, home.theme_name.size.x, long_title_size
	)
	_check(
		(
			home.theme_name.text == "The Classic of Mountains and Seas"
			and long_title_size < 88
			and home.theme_name.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
			and home.theme_name.max_lines_visible == 2
			and wrapped_block.x <= home.theme_name.size.x + 1.0
			and wrapped_block.y <= home.theme_name.size.y + 1.0
		),
		"home_long_title_shrinks_and_wraps_within_its_box"
	)
	_check(
		home.theme_name.get_rect().end.x <= home.bottom_panel.size.x * 0.5 + 1.0,
		"home_title_never_crosses_panel_midline"
	)
	_check(
		home.theme_name.get_rect().end.x <= home.page_label.get_rect().position.x,
		"home_long_title_never_reaches_page_badge"
	)
	_check(
		home.page_text.text == "01 / 02" and home.caption.text == "已完成 20%",
		"home_page_badge_and_progress_caption"
	)
	await process_frame
	_check(
		(
			is_equal_approx(home.progress_fill.anchor_right, 0.2)
			and home.progress_fill.size.x < home.progress_track.size.x
			and home.progress_fill.size.x > 0.0
		),
		"home_progress_fill_tracks_ratio"
	)
	_check(not home.incoming_info.visible, "home_incoming_hidden_at_rest")
	_check(home.get_node("CoverSlots/Current").texture != null, "home_current_cover")

	# --- cold entry ---------------------------------------------------------
	home.play_cold_entry()
	await create_timer(0.30).timeout
	var entry_state: Dictionary = home.debug_state_snapshot()
	_check(
		(
			home.bottom_panel.modulate.a < 1.0
			and home.bottom_panel.offset_top > -791.0
			and header.offset_top < 71.0
			and not bool(entry_state.entry_interaction_ready)
			and menu_button.mouse_filter == Control.MOUSE_FILTER_IGNORE
		),
		"home_cold_entry_midpoint"
	)
	await create_timer(0.80).timeout
	_check(
		(
			home.active_motion_count() == 0
			and is_equal_approx(header.offset_top, 71.0)
			and is_equal_approx(header.offset_bottom, 207.0)
			and is_equal_approx(home.bottom_panel.modulate.a, 1.0)
			and is_equal_approx(home.bottom_panel.offset_top, -791.0)
			and is_equal_approx(home.bottom_panel.offset_bottom, 0.0)
			and bool(home.debug_state_snapshot().entry_interaction_ready)
			and menu_button.mouse_filter == Control.MOUSE_FILTER_STOP
		),
		"home_cold_entry_settled"
	)

	# --- pointer paging -----------------------------------------------------
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
	await MotionSettle.released(self, func() -> int: return home.active_motion_count())
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
	var act_home_mouse_click_activates: bool = await MotionSettle.until(
		self, func() -> bool: return _activated_theme == "topic_01"
	)
	_check(act_home_mouse_click_activates, "home_mouse_click_activates")

	# The panel and the header own their own presses; the cover area does not.
	# Asserted through the guard rather than synthesized input, because the OS can
	# resize the window mid-run and desynchronize queued event coordinates.
	_check(
		(
			home._is_fixed_action_at(home.bottom_panel.position + Vector2(24.0, 40.0))
			and home._is_fixed_action_at(menu_button.get_global_rect().get_center())
			and not home._is_fixed_action_at(Vector2(home.size.x * 0.5, home.size.y * 0.3))
		),
		"home_panel_press_does_not_page_or_activate"
	)

	_activated_theme = ""
	home.start_button.pressed.emit()
	await create_timer(0.14).timeout
	var act_home_start_button_activates_theme: bool = await MotionSettle.until(
		self, func() -> bool: return _activated_theme == "topic_01"
	)
	_check(act_home_start_button_activates_theme, "home_start_button_activates_theme")

	# --- header button motion ----------------------------------------------
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

	# --- wrap-around paging and cover crossfade -----------------------------
	_activated_theme = ""
	home.debug_begin_drag()
	home.debug_drag(home.size.x * 0.30, 1.0)
	var loop_back_state: Dictionary = home.debug_state_snapshot()
	_check(
		(
			float(loop_back_state.gesture_progress) >= 0.29
			and home.incoming_info.visible
			and home.incoming_page_text.text == "02 / 02"
			and home.current_cover.scale.x < 1.0
			and home.previous_cover.scale.x > 1.0
			and (
				home.previous_cover.position.x + home.previous_cover.size.x
				> home.current_cover.position.x
			)
			and home.previous_cover.get_index() > home.current_cover.get_index()
			and (
				float(
					(home.previous_cover.material as ShaderMaterial).get_shader_parameter(
						&"feather_width"
					)
				)
				> 0.07
			)
		),
		"home_first_page_wraps_with_cover_crossfade"
	)
	home.debug_end_drag()
	await create_timer(0.35).timeout
	await MotionSettle.released(self, func() -> int: return home.active_motion_count())
	_check(home.debug_state_snapshot().selected_index == 1, "home_first_page_wraps_to_last")
	_check(_changed_theme == "topic_02", "home_first_page_wrap_emits_theme")
	_check(_activated_theme.is_empty(), "home_first_page_wrap_does_not_activate")
	_check(
		(
			home.active_motion_count() == 0
			and home.previous_cover.get_index() == 0
			and home.current_cover.get_index() == 1
			and home.next_cover.get_index() == 2
			and is_equal_approx(
				float(
					(home.previous_cover.material as ShaderMaterial).get_shader_parameter(
						&"feather_width"
					)
				),
				0.001
			)
		),
		"home_first_page_wrap_releases_motion"
	)
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.30, 1.0)
	_check(home.incoming_page_text.text == "01 / 02", "home_last_page_previews_wrapped_first_page")
	home.debug_end_drag()
	await create_timer(0.35).timeout
	var wrapped_first: bool = await MotionSettle.until(
		self, func() -> bool: return _changed_theme == "topic_01"
	)
	_check(
		wrapped_first and home.debug_state_snapshot().selected_index == 0,
		"home_last_page_wraps_to_first"
	)

	# --- information crossfade ---------------------------------------------
	_changed_theme = ""
	var outgoing_start_x: float = home.info_panel.position.x
	var incoming_start_x: float = home.incoming_info.position.x
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.20, 1.0)
	_check(
		(
			home.incoming_info.visible
			and home.incoming_page_text.text == "02 / 02"
			and home.info_panel.modulate.a < 1.0
			and home.incoming_info.modulate.a <= 0.01
			and home.info_panel.position.x < outgoing_start_x
			and home.incoming_info.position.x > incoming_start_x
		),
		"home_information_leaves_before_incoming"
	)
	home.debug_end_drag()
	await create_timer(0.28).timeout
	await MotionSettle.released(self, func() -> int: return home.active_motion_count())
	_check(
		(
			home.debug_state_snapshot().selected_index == 0
			and home.info_panel.modulate.a >= 0.99
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
	await MotionSettle.released(self, func() -> int: return home.active_motion_count())
	_check(
		home.debug_state_snapshot().selected_index == 0 and _changed_theme == "",
		"home_reverse_gesture_returns_without_commit"
	)
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.25, 1.0)
	_check(
		(
			is_equal_approx(float(home.debug_state_snapshot().gesture_progress), 0.25)
			and home.info_panel.modulate.a > 0.0
			and home.incoming_info.modulate.a <= 0.01
		),
		"home_drag_quarter_state"
	)
	home.debug_drag(-home.size.x * 0.25, 1.0)
	_check(
		(
			home.incoming_info.visible
			and incoming_theme_name.text.begins_with("A Second")
			and home.info_panel.modulate.a <= 0.01
			and home.incoming_info.modulate.a > 0.1
			and home.incoming_info.modulate.a < 1.0
			and home.incoming_page_text.text == "02 / 02"
		),
		"home_incoming_information_layers"
	)
	home.debug_drag(-home.size.x * 0.25, 1.0)
	_check(
		(
			is_equal_approx(float(home.debug_state_snapshot().gesture_progress), 0.75)
			and home.incoming_info.modulate.a >= 0.99
		),
		"home_drag_three_quarter_state"
	)
	home.debug_end_drag()
	await create_timer(0.35).timeout
	var committed: bool = await MotionSettle.until(
		self, func() -> bool: return _changed_theme == "topic_02"
	)
	_check(committed and home.page_text.text == "02 / 02", "home_drag_commits_once")
	home.debug_begin_drag()
	home.debug_drag(home.size.x * 0.10, 0.03)
	home.debug_end_drag()
	await create_timer(0.35).timeout
	var by_velocity: bool = await MotionSettle.until(
		self, func() -> bool: return _changed_theme == "topic_01"
	)
	_check(
		by_velocity and home.debug_state_snapshot().selected_index == 0,
		"home_velocity_commits_below_ratio"
	)
	home.debug_begin_drag()
	home.debug_drag(-home.size.x * 0.30, 1.0)
	home.debug_end_drag()
	await create_timer(0.35).timeout
	await MotionSettle.released(self, func() -> int: return home.active_motion_count())
	_check(home.debug_state_snapshot().selected_index == 1, "home_restores_second_theme")
	home.debug_begin_drag()
	home.debug_drag(4.0, 0.05)
	home.debug_end_drag()
	await create_timer(0.40).timeout
	var act_home_small_drag_activates: bool = await MotionSettle.until(
		self, func() -> bool: return _activated_theme == "topic_02"
	)
	_check(act_home_small_drag_activates, "home_small_drag_activates")

	# --- reduced motion -----------------------------------------------------
	home.set_reduced_motion(true)
	var reduced_info_position: Vector2 = home.info_panel.position
	home.debug_begin_drag()
	home.debug_drag(home.size.x * 0.30, 0.12)
	_check(
		(
			home.info_panel.position.is_equal_approx(reduced_info_position)
			and home.incoming_info.position.is_equal_approx(reduced_info_position)
			and home.current_cover.scale.is_equal_approx(Vector2.ONE)
			and home.previous_cover.scale.is_equal_approx(Vector2.ONE)
			and (
				home.previous_cover.position.x + home.previous_cover.size.x
				> home.current_cover.position.x
			)
			and (
				float(
					(home.previous_cover.material as ShaderMaterial).get_shader_parameter(
						&"feather_width"
					)
				)
				> 0.07
			)
		),
		"home_reduced_motion_uses_crossfade_without_spatial_depth"
	)
	home.debug_end_drag()
	await create_timer(0.14).timeout
	var reduced_settled: bool = await MotionSettle.released(
		self, func() -> int: return home.active_motion_count()
	)
	_check(reduced_settled and _changed_theme == "topic_01", "home_reduced_motion_settles")

	# --- tablet width -------------------------------------------------------
	root.size = Vector2i(1668, 2388)
	await process_frame
	await process_frame
	_check(
		(
			home.bottom_panel.get_global_rect().end.x >= home.size.x
			and home.start_button.get_global_rect().end.y <= home.size.y
			and (
				home.theme_name.get_global_rect().end.x
				<= home.page_label.get_global_rect().position.x
			)
		),
		"home_panel_survives_tablet_width"
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
