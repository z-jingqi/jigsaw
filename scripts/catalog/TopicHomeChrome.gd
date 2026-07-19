extends RefCounted
class_name TopicHomeChrome

const TRACK_COLOR := Color(0.063, 0.278, 0.357, 0.22)

var game: Node
var controls: TopicHomeControls


func _init(owner: Node, control_factory: TopicHomeControls) -> void:
	game = owner
	controls = control_factory


func build(viewport_size: Vector2, scale: float, layout: Dictionary, actions: Dictionary) -> Dictionary:
	var root := Control.new()
	root.name = "topic_home_fixed_ui"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side_margin := 18.0 * scale
	var top_margin := 20.0 * scale
	var logo := _texture(TopicHomeControls.LOGO_PATH, Vector2(144.0, 42.0) * scale)
	logo.name = "theme_logo"
	logo.position = Vector2(side_margin, top_margin)
	root.add_child(logo)
	var settings_size := 54.0 * scale
	var settings := controls.icon_surface_button(TopicHomeControls.SETTINGS_PATH, settings_size, actions.settings)
	settings.name = "theme_settings_button"
	settings.position = Vector2(viewport_size.x - side_margin - settings_size, top_margin)
	settings.set_meta("button_motion_kind", "settings")
	root.add_child(settings)
	var info_width := minf(viewport_size.x * 0.48, 174.0 * scale)
	var info_right := viewport_size.x - side_margin
	var title := Label.new()
	title.name = "topic_home_title"
	title.position = Vector2(info_right - info_width, 92.0 * scale)
	title.size = Vector2(info_width, 48.0 * scale)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.add_theme_font_size_override("font_size", maxi(28, int(35.0 * scale)))
	title.add_theme_color_override("font_color", TopicHomeControls.DEEP_TEAL)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	var progress_nodes := _build_progress(info_width, scale)
	var progress: Control = progress_nodes.root
	progress.position = Vector2(info_right - info_width, 142.0 * scale)
	root.add_child(progress)
	var enter_width := minf(viewport_size.x - 72.0 * scale, 184.0 * scale)
	var enter := controls.text_icon_button(game._t("enter_topic"), TopicHomeControls.PAW_PATH, Vector2(enter_width, float(layout.enter_height)), scale, actions.enter, true)
	enter.name = "topic_enter_button"
	enter.position = Vector2((viewport_size.x - enter_width) * 0.5, float(layout.enter_top))
	enter.set_meta("button_motion_kind", "primary")
	root.add_child(enter)
	var nav_nodes := _build_navigation(viewport_size, scale, layout, actions)
	root.add_child(nav_nodes.previous)
	root.add_child(nav_nodes.all)
	root.add_child(nav_nodes.next)
	return {
		"root": root,
		"title": title,
		"progress_label": progress_nodes.label,
		"previous_label": nav_nodes.previous.get_node("label"),
		"next_label": nav_nodes.next.get_node("label"),
		"all_icon": nav_nodes.all.get_node("icon"),
	}


func build_indicator(page_count: int, viewport_size: Vector2, scale: float, layout: Dictionary) -> Panel:
	var indicator := Panel.new()
	indicator.name = "topic_pager_indicator"
	var width := minf(viewport_size.x * 0.28, 112.0 * scale)
	var height := maxf(3.0, 3.0 * scale)
	indicator.position = Vector2((viewport_size.x - width) * 0.5, float(layout.nav_top) - 22.0 * scale)
	indicator.size = Vector2(width, height)
	indicator.visible = page_count > 1
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.add_theme_stylebox_override("panel", game._capsule_panel_style(TRACK_COLOR, height))
	var thumb := Panel.new()
	thumb.name = "topic_pager_thumb"
	thumb.size = Vector2(maxf(16.0 * scale, width / float(maxi(1, page_count))), height)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_theme_stylebox_override("panel", game._capsule_panel_style(TopicHomeControls.DEEP_TEAL, height))
	indicator.add_child(thumb)
	return indicator


func _build_progress(info_width: float, scale: float) -> Dictionary:
	var row := Control.new()
	row.name = "topic_home_progress"
	row.size = Vector2(info_width, 38.0 * scale)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _texture(TopicHomeControls.PROGRESS_PATH, Vector2(32.0, 32.0) * scale)
	icon.name = "topic_home_progress_icon"
	icon.position = Vector2(info_width - 98.0 * scale, 2.0 * scale)
	row.add_child(icon)
	var label := Label.new()
	label.name = "topic_home_progress_count"
	label.position = Vector2(info_width - 64.0 * scale, 0.0)
	label.size = Vector2(64.0 * scale, 36.0 * scale)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", maxi(18, int(23.0 * scale)))
	label.add_theme_color_override("font_color", TopicHomeControls.DEEP_TEAL)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return {"root": row, "label": label}


func _build_navigation(viewport_size: Vector2, scale: float, layout: Dictionary, actions: Dictionary) -> Dictionary:
	var height := float(layout.nav_height)
	var top := float(layout.nav_top)
	var gap := 6.0 * scale
	var total_width := minf(viewport_size.x - 24.0 * scale, 520.0 * scale)
	var usable_width := total_width - gap * 2.0
	var center_width := clampf(usable_width * 0.27, 96.0 * scale, 140.0 * scale)
	var side_width := (usable_width - center_width) * 0.5
	var left := (viewport_size.x - total_width) * 0.5
	var previous := controls.text_icon_button("", TopicHomeControls.CHEVRON_LEFT_PATH, Vector2(side_width, height), scale, actions.previous, false)
	previous.name = "topic_previous_button"
	previous.position = Vector2(left, top)
	previous.set_meta("button_motion_kind", "direction")
	previous.set_meta("direction_sign", -1.0)
	var all_topics := controls.text_icon_button(game._t("all_topics"), TopicHomeControls.CHEVRON_DOWN_PATH, Vector2(center_width, height), scale, actions.all, false, true)
	all_topics.name = "topic_all_button"
	all_topics.position = Vector2(left + side_width + gap, top)
	var next := controls.text_icon_button("", TopicHomeControls.CHEVRON_LEFT_PATH, Vector2(side_width, height), scale, actions.next, false, true, true)
	next.name = "topic_next_button"
	next.position = Vector2(left + side_width + gap + center_width + gap, top)
	next.set_meta("button_motion_kind", "direction")
	next.set_meta("direction_sign", 1.0)
	return {"previous": previous, "all": all_topics, "next": next}


func _texture(path: String, size: Vector2) -> TextureRect:
	var texture := TextureRect.new()
	texture.texture = game.repository.cached_texture(path)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.size = size
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture
