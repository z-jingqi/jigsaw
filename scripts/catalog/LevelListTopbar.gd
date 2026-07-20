extends RefCounted
class_name LevelListTopbar

const UiKitScript := preload("res://scripts/ui/JigcatUiKit.gd")
const BACK_ICON := "res://assets/ui/topic-home/chevron-left.png"
const PROGRESS_ICON := "res://assets/ui/topic-home/progress-puzzle.png"

var game: Node
var ui


func _init(owner: Node) -> void:
	game = owner
	ui = UiKitScript.new(owner)


func build(topic: Dictionary, viewport_size: Vector2, scale: float) -> Control:
	var bar := Control.new()
	bar.name = "level_list_topbar"
	bar.position = Vector2.ZERO
	bar.size = Vector2(viewport_size.x, 104.0 * scale)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := 18.0 * scale
	var top := 18.0 * scale
	var button_size := 52.0 * scale
	var back: Button = ui.icon_button(BACK_ICON, button_size, Callable(game, "_show_topics"))
	back.name = "level_list_back_button"
	back.position = Vector2(margin, top)
	bar.add_child(back)
	var progress_width := 106.0 * scale
	var progress := _build_progress(topic, Vector2(progress_width, button_size), scale)
	progress.position = Vector2(viewport_size.x - margin - progress_width, top)
	bar.add_child(progress)
	var title_left: float = back.position.x + button_size + 10.0 * scale
	var title_right: float = progress.position.x - 10.0 * scale
	var title := Label.new()
	title.name = "level_list_title"
	title.position = Vector2(title_left, top)
	title.size = Vector2(maxf(1.0, title_right - title_left), button_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiKitScript.DEEP_TEAL)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title)
	ui.fit_label(title, str(topic.get("name", "")), maxi(24, int(30.0 * scale)), maxi(18, int(20.0 * scale)))
	return bar


func _build_progress(topic: Dictionary, size: Vector2, scale: float) -> Control:
	var row := Control.new()
	row.name = "level_list_progress"
	row.size = size
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_size := 30.0 * scale
	var icon := TextureRect.new()
	icon.name = "level_list_progress_icon"
	icon.texture = game.repository.cached_texture(PROGRESS_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(0.0, (size.y - icon_size) * 0.5)
	icon.size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.name = "level_list_progress_label"
	label.text = "%d/%d" % [game._topic_available_done_count(topic), game._topic_available_mode_total(topic)]
	label.position = Vector2(icon_size + 6.0 * scale, 0.0)
	label.size = Vector2(size.x - icon_size - 6.0 * scale, size.y)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", maxi(16, int(20.0 * scale)))
	label.add_theme_color_override("font_color", UiKitScript.DEEP_TEAL)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row
