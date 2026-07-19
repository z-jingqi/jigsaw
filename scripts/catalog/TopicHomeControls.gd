extends RefCounted
class_name TopicHomeControls

const LOGO_PATH := "res://assets/ui/topic-home/logo.png"
const SETTINGS_PATH := "res://assets/ui/topic-home/settings.png"
const PROGRESS_PATH := "res://assets/ui/topic-home/progress-puzzle.png"
const PAW_PATH := "res://assets/ui/topic-home/paw.png"
const CHEVRON_LEFT_PATH := "res://assets/ui/topic-home/chevron-left.png"
const CHEVRON_DOWN_PATH := "res://assets/ui/topic-home/chevron-down.png"

const DEEP_TEAL := Color("#10475B")
const PRIMARY_CORAL := Color("#F28A70")
const PRIMARY_CORAL_PRESSED := Color("#E9745E")
const PRIMARY_TEXT := Color("#FFF9F4")
const SURFACE := Color(0.984, 0.980, 0.969, 0.94)
const SURFACE_PRESSED := Color("#F2E9E1")
const SELECTOR_CURRENT := Color("#F9D9CF")
const SELECTOR_CURRENT_TEXT := Color("#0E4653")

var game: Node


func _init(owner: Node) -> void:
	game = owner


func text_icon_button(
	text: String,
	icon_path: String,
	size: Vector2,
	scale: float,
	action: Callable,
	primary: bool,
	icon_after := false,
	mirrored := false,
) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = size
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", style_box(PRIMARY_CORAL if primary else SURFACE, int(size.y * 0.5)))
	button.add_theme_stylebox_override("hover", style_box(PRIMARY_CORAL if primary else SURFACE, int(size.y * 0.5)))
	button.add_theme_stylebox_override("pressed", style_box(PRIMARY_CORAL_PRESSED if primary else SURFACE_PRESSED, int(size.y * 0.5)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon_size := minf(size.y * (0.36 if primary else 0.25), 36.0 * scale)
	var icon := TextureRect.new()
	icon.name = "icon"
	icon.texture = game.repository.cached_texture(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(icon_size, icon_size)
	icon.position = Vector2(size.x - icon_size - size.y * 0.22, (size.y - icon_size) * 0.5) if icon_after else Vector2(size.y * 0.22, (size.y - icon_size) * 0.5)
	icon.pivot_offset = icon.size * 0.5
	if mirrored:
		icon.scale.x = -1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var label := Label.new()
	label.name = "label"
	label.text = text
	var left_inset := size.y * (0.14 if icon_after else 0.52)
	var right_inset := size.y * (0.52 if icon_after else 0.14)
	label.position = Vector2(left_inset, 0.0)
	label.size = Vector2(maxf(1.0, size.x - left_inset - right_inset), size.y)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	var preferred_font_size := maxi(15, int((20.0 if primary else 16.0) * scale))
	var minimum_font_size := maxi(12, int((15.0 if primary else 12.0) * scale))
	label.add_theme_font_size_override("font_size", preferred_font_size)
	label.add_theme_color_override("font_color", PRIMARY_TEXT if primary else DEEP_TEAL)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	set_fitted_label_text(label, text, preferred_font_size, minimum_font_size)
	button.pressed.connect(action)
	game._wire_button_animation(button)
	return button


func icon_surface_button(icon_path: String, size: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(size, size)
	button.size = button.custom_minimum_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", style_box(SURFACE, int(size * 0.5)))
	button.add_theme_stylebox_override("hover", style_box(SURFACE, int(size * 0.5)))
	button.add_theme_stylebox_override("pressed", style_box(SURFACE_PRESSED, int(size * 0.5)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.name = "icon"
	icon.texture = game.repository.cached_texture(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(size * 0.25, size * 0.25)
	icon.size = Vector2(size * 0.5, size * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.pressed.connect(action)
	game._wire_button_animation(button)
	return button


func apply_selector_style(button: Button, selected: bool, scale: float) -> void:
	var radius := int(12.0 * scale)
	var normal_color := SELECTOR_CURRENT if selected else Color(1, 1, 1, 0)
	button.add_theme_stylebox_override("normal", style_box(normal_color, radius))
	button.add_theme_stylebox_override("hover", style_box(SELECTOR_CURRENT.lerp(Color.WHITE, 0.25), radius))
	button.add_theme_stylebox_override("pressed", style_box(SURFACE_PRESSED, radius))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", SELECTOR_CURRENT_TEXT if selected else DEEP_TEAL)
	button.add_theme_color_override("font_hover_color", DEEP_TEAL)
	button.add_theme_color_override("font_pressed_color", DEEP_TEAL)


func set_fitted_label_text(label: Label, text: String, preferred_size: int, minimum_size: int) -> void:
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = -1
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font := label.get_theme_font("font")
	var font_size := preferred_size
	while font_size > minimum_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	label.tooltip_text = text if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x else ""


func set_responsive_nav_label_text(label: Label, text: String, preferred_size: int, minimum_size: int) -> void:
	set_fitted_label_text(label, text, preferred_size, minimum_size)
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x:
		return
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = text


func style_box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
