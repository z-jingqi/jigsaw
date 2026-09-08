extends Control
signal close_requested
signal theme_selected(theme_id: String)
const CoverShader := preload("res://shaders/ui/theme_cover.gdshader")
const TitleFont := preload("res://assets/fonts/douyin/DouyinSansBold.ttf")
var _themes: Array = []
var _selected_id := ""
var _scroll_position := 0


func _ready() -> void:
	$CloseButton.pressed.connect(close_requested.emit)
	resized.connect(_layout)


func navigation_enter(payload: Dictionary, _context: Dictionary) -> void:
	_themes = payload.view_model.themes
	_selected_id = payload.view_model.selected_theme_id
	_scroll_position = int(payload.get("scroll_position", 0))
	_build()
	_layout()
	_restore_scroll.call_deferred()


func _restore_scroll() -> void:
	$Scroll.scroll_vertical = _scroll_position


func navigation_set_active(enabled: bool) -> void:
	visible = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func scroll_position() -> int:
	return $Scroll.scroll_vertical


func _build() -> void:
	for model in _themes:
		var tile := Button.new()
		tile.name = str(model.theme_id)
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color.TRANSPARENT
			box.set_corner_radius_all(20)
			if model.theme_id == _selected_id or state == "focus":
				box.set_border_width_all(3)
				box.border_color = Color("9BB39B")
			tile.add_theme_stylebox_override(state, box)
		var cover := TextureRect.new()
		cover.name = "Cover"
		cover.texture = model.cover_texture
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = CoverShader
		mat.set_shader_parameter(
			"texture_aspect", cover.texture.get_size().x / cover.texture.get_size().y
		)
		cover.material = mat
		tile.add_child(cover)
		var label := Label.new()
		label.name = "Title"
		label.text = model.title
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", TitleFont)
		label.add_theme_color_override("font_color", Color("194F47"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(label)
		var note := Label.new()
		note.name = "Note"
		note.text = (
			"敬请期待" if not model.playable else ("当前" if model.theme_id == _selected_id else "")
		)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_color_override("font_color", Color("7C917B"))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(note)
		tile.pressed.connect(func() -> void: theme_selected.emit(str(model.theme_id)))
		$Scroll/Grid.add_child(tile)


func _layout() -> void:
	var u := minf(size.x / 390.0, size.y / 844.0)
	$CloseButton.position = Vector2(22, 27) * u
	$CloseButton.size = Vector2.ONE * 46 * u
	$Title.position = Vector2(70, 91) * u
	$Title.size = Vector2(size.x - 140 * u, 62 * u)
	$Title.add_theme_font_size_override("font_size", int(34 * u))
	$Scroll.position = Vector2(24, 182) * u
	$Scroll.size = size - Vector2(48, 200) * u
	var grid := $Scroll/Grid as GridContainer
	grid.columns = 2 if size.x / size.y < 0.8 else 3
	grid.add_theme_constant_override("h_separation", int(18 * u))
	grid.add_theme_constant_override("v_separation", int(22 * u))
	var width: float = ($Scroll.size.x - 14 * u - (grid.columns - 1) * 18 * u) / grid.columns
	for tile in grid.get_children():
		tile.custom_minimum_size = Vector2(width, width * 1.5 + 63 * u)
		var cover := tile.get_node("Cover") as TextureRect
		cover.position = Vector2.ONE * 5 * u
		cover.size = Vector2(width - 10 * u, (width - 10 * u) * 1.5)
		var title := tile.get_node("Title") as Label
		title.position = Vector2(0, width * 1.5 + 3 * u)
		title.size = Vector2(width, 29 * u)
		title.add_theme_font_size_override("font_size", int(20 * u))
		var note := tile.get_node("Note") as Label
		note.position = Vector2(0, width * 1.5 + 32 * u)
		note.size = Vector2(width, 23 * u)
		note.add_theme_font_size_override("font_size", int(12 * u))
