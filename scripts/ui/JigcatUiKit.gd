extends RefCounted
class_name JigcatUiKit

const DEEP_TEAL := Color("#10475B")
const CORAL := Color("#F28A70")
const CORAL_PRESSED := Color("#E9745E")
const WARM_MIST := Color("#FFF6E9")
const SURFACE := Color(0.984, 0.980, 0.969, 0.95)
const SURFACE_PRESSED := Color("#F2E9E1")
const MINT := Color("#A8DCC6")
const WHITE_TEXT := Color("#FFF9F4")

var game: Node


func _init(owner: Node) -> void:
	game = owner


func surface_style(color: Color, radius: int, border_color := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border_width > 0:
		style.border_color = border_color
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
	return style


func icon_button(icon_path: String, size: float, action: Callable, tint := DEEP_TEAL) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(size, size)
	button.size = button.custom_minimum_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", surface_style(SURFACE, int(size * 0.5)))
	button.add_theme_stylebox_override("hover", surface_style(SURFACE, int(size * 0.5)))
	button.add_theme_stylebox_override("pressed", surface_style(SURFACE_PRESSED, int(size * 0.5)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.name = "icon"
	icon.texture = game.repository.cached_texture(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(size * 0.26, size * 0.26)
	icon.size = Vector2(size * 0.48, size * 0.48)
	icon.material = game._icon_tint_material(tint)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.pressed.connect(action)
	game._wire_button_animation(button)
	return button


func primary_button(text: String, size: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", maxi(16, int(size.y * 0.32)))
	button.add_theme_color_override("font_color", WHITE_TEXT)
	button.add_theme_color_override("font_hover_color", WHITE_TEXT)
	button.add_theme_color_override("font_pressed_color", WHITE_TEXT)
	button.add_theme_stylebox_override("normal", surface_style(CORAL, int(size.y * 0.5)))
	button.add_theme_stylebox_override("hover", surface_style(CORAL, int(size.y * 0.5)))
	button.add_theme_stylebox_override("pressed", surface_style(CORAL_PRESSED, int(size.y * 0.5)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(action)
	game._wire_button_animation(button)
	return button


func fit_label(label: Label, text: String, preferred_size: int, minimum_size: int, allow_two_lines := false) -> void:
	label.text = text
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = -1
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font := label.get_theme_font("font")
	var font_size := preferred_size
	while font_size > minimum_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	var still_overflows := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x
	if still_overflows and allow_two_lines:
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.max_lines_visible = 2
	label.tooltip_text = text if still_overflows else ""
