extends Control
signal close_requested
signal theme_selected(theme_id: String)

const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")
const CoverShader := preload("res://shaders/ui/theme_cover.gdshader")
const TitleLayout := preload("res://scripts/screens/home/ThemeTitleLayout.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
var _themes: Array = []
var _scroll_position := 0


func _ready() -> void:
	$Title.text = GameStrings.ui_text("all_themes")
	$EmptyState.text = GameStrings.ui_text("library_empty")
	$CloseButton.tooltip_text = GameStrings.ui_text("close_themes")
	$CloseButton.accessibility_name = $CloseButton.tooltip_text
	$CloseButton.pressed.connect(close_requested.emit)
	resized.connect(_layout)


func navigation_enter(payload: Dictionary, _context: Dictionary) -> void:
	_themes = payload.view_model.themes
	_scroll_position = int(payload.get("scroll_position", 0))
	_build()
	_layout()
	_restore_scroll.call_deferred()


func _restore_scroll() -> void:
	$Scroll.scroll_vertical = _scroll_position


func navigation_set_active(enabled: bool) -> void:
	visible = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	$Scroll.set_interaction_enabled(enabled)


func scroll_position() -> int:
	return $Scroll.scroll_vertical


func _build() -> void:
	for child in $Scroll/Grid.get_children():
		$Scroll/Grid.remove_child(child)
		child.queue_free()
	$EmptyState.visible = _themes.is_empty()
	$Subtitle.text = (
		GameStrings.ui_text("library_subtitle")
		if not _themes.is_empty()
		else GameStrings.ui_text("library_empty_subtitle")
	)
	var palette := [Clean.SAGE, Clean.APRICOT, Clean.LAVENDER]
	for index in _themes.size():
		var model: Variant = _themes[index]
		var tile := Button.new()
		tile.name = str(model.theme_id)
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.focus_mode = Control.FOCUS_ALL
		tile.disabled = not model.playable
		tile.tooltip_text = (
			"%s · %s"
			% [
				model.title,
				(
					GameStrings.ui_text("enter_topic")
					if model.playable
					else GameStrings.ui_text("coming_soon")
				)
			]
		)
		tile.accessibility_name = tile.tooltip_text
		Clean.button(tile)
		var color: Color = palette[index % palette.size()]
		for state in ["normal", "hover", "pressed", "disabled"]:
			var fill := color.darkened(0.05) if state == "pressed" else color
			tile.add_theme_stylebox_override(state, Clean.panel(fill, 20))
		var cover := TextureRect.new()
		cover.name = "Cover"
		cover.texture = model.cover_texture
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if cover.texture != null:
			var mat := ShaderMaterial.new()
			mat.shader = CoverShader
			mat.set_shader_parameter(
				"texture_aspect", cover.texture.get_size().x / cover.texture.get_size().y
			)
			cover.material = mat
		if not model.playable:
			cover.modulate = Color(1, 1, 1, 0.68)
		tile.add_child(cover)
		var label := Label.new()
		label.name = "Title"
		label.text = model.title
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(label)
		var status := Label.new()
		status.name = "Status"
		status.text = (
			GameStrings.ui_text("enter_topic") + "  →"
			if model.playable
			else GameStrings.ui_text("coming_soon")
		)
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(status)
		tile.pressed.connect(func() -> void: theme_selected.emit(str(model.theme_id)))
		$Scroll/Grid.add_child(tile)


func _layout() -> void:
	var u := minf(size.x / 390.0, size.y / 844.0)
	var canvas := Clean.canvas_scale(size, get_window())
	var safe := Clean.safe_insets(size)
	Buttons.place_navigation($CloseButton, self, true)
	var usable_width := size.x - safe.x - safe.z
	var width := minf(usable_width - 48.0 * u, 680.0 * u)
	var left := safe.x + (usable_width - width) * 0.5
	var top := safe.y + maxf(93.0 * u, Buttons.header_center_y(size) + 48.0 * u)
	$Title.position = Vector2(left, top)
	$Title.size = Vector2(width, 46 * u)
	Clean.label($Title, roundi(maxf(30.0 * u, 24.0 * canvas)))
	$Subtitle.position = Vector2(left, top + 55.0 * u)
	$Subtitle.size = Vector2(width, maxf(28.0 * u, 24.0 * canvas))
	Clean.label($Subtitle, roundi(maxf(13.0 * u, 14.0 * canvas)), true)
	var scroll_top := top + 106.0 * u
	$Scroll.position = Vector2(left, scroll_top)
	$Scroll.size = Vector2(width, size.y - safe.w - scroll_top - 28.0 * u)
	$EmptyState.position = Vector2(left, scroll_top + 80.0 * u)
	$EmptyState.size = Vector2(width, 100.0 * u)
	Clean.label($EmptyState, roundi(maxf(18.0 * u, 14.0 * canvas)), true)
	var grid := $Scroll/Grid as GridContainer
	grid.columns = 2 if size.x / size.y < 0.8 else 3
	var gap := 14.0 * u
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", int(18 * u))
	var tile_width := (width - float(grid.columns - 1) * gap) / float(grid.columns)
	for tile in grid.get_children():
		var image_width := tile_width - 20.0 * u
		var image_height := image_width * 1.3
		var title_height := maxf(28.0 * u, 24.0 * canvas)
		var status_top := image_height + 17.0 * u + title_height + 4.0 * canvas
		var status_height := maxf(23.0 * u, 20.0 * canvas)
		tile.custom_minimum_size = Vector2(tile_width, status_top + status_height + 12.0 * u)
		var cover := tile.get_node("Cover") as TextureRect
		cover.position = Vector2.ONE * 10.0 * u
		cover.size = Vector2(image_width, image_height)
		if cover.material != null:
			cover.material.set_shader_parameter("aspect", image_width / image_height)
		var title := tile.get_node("Title") as Label
		title.position = Vector2(14.0 * u, image_height + 17.0 * u)
		title.size = Vector2(tile_width - 28.0 * u, title_height)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Clean.label(title, roundi(maxf(18.0 * u, 14.0 * canvas)))
		TitleLayout.fit(title, title.size, roundi(maxf(18.0 * u, 14.0 * canvas)))
		var status := tile.get_node("Status") as Label
		status.position = Vector2(14.0 * u, status_top)
		status.size = Vector2(tile_width - 28.0 * u, status_height)
		Clean.label(status, roundi(maxf(12.0 * u, 12.0 * canvas)), true)
