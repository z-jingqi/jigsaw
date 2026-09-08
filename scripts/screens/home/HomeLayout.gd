extends RefCounted
## Responsive home composition, independent of browsing state.

const TitleLayout := preload("res://scripts/screens/home/ThemeTitleLayout.gd")


static func apply(host: Control) -> void:
	var s := host.size
	var u := minf(s.x / 390.0, s.y / 844.0)
	var width := minf(s.x - 40.0 * u, 370.0 * u)
	var left := (s.x - width) * 0.5
	var button := Vector2.ONE * 46.0 * u
	_place(host.get_node("MenuButton"), Vector2(left + width - button.x, 26.0 * u), button)
	_place(
		host.get_node("ThemesButton"),
		Vector2(left + width - button.x * 2.0 - 12.0 * u, 26.0 * u),
		button
	)
	var title := host.get_node("ThemeName") as Label
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	var title_font := title.get_theme_font("font")
	var largest_font_size := maxi(1, int(42.0 * u))
	var ideal_title_width := (
		title_font
		. get_string_size(title.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, largest_font_size)
		. x
	)
	var roomy_cloud_width := 64.0 * u
	var compact_cloud_width := 48.0 * u
	var cloud_gap := 8.0 * u
	var cloud_width := (
		roomy_cloud_width
		if ideal_title_width <= width - 2.0 * (roomy_cloud_width + cloud_gap)
		else compact_cloud_width
	)
	var cloud_size := Vector2(cloud_width, 28.0 * u)
	var title_width := maxf(120.0 * u, width - 2.0 * (cloud_size.x + cloud_gap))
	var title_size := Vector2(title_width, 82.0 * u)
	var group_width := title_width + 2.0 * (cloud_size.x + cloud_gap)
	var group_left := (s.x - group_width) * 0.5
	var title_top := 91.0 * u
	var cloud_top := title_top + (title_size.y - cloud_size.y) * 0.5
	var left_cloud := host.get_node("TitleCloudLeft") as TextureRect
	_place(left_cloud, Vector2(group_left, cloud_top), cloud_size)
	left_cloud.pivot_offset = cloud_size * 0.5
	var right_cloud := host.get_node("TitleCloudRight") as TextureRect
	_place(
		right_cloud,
		Vector2(group_left + cloud_size.x + cloud_gap + title_width + cloud_gap, cloud_top),
		cloud_size
	)
	right_cloud.pivot_offset = cloud_size * 0.5
	right_cloud.rotation = PI
	_place(title, Vector2(group_left + cloud_size.x + cloud_gap, title_top), title_size)
	TitleLayout.fit(title, title_size, largest_font_size, maxi(1, int(22.0 * u)))
	var deck := host.get_node("Deck") as Control
	var deck_h := minf(s.y - 340.0 * u, width * 1.42)
	_place(deck, Vector2(left, 195.0 * u), Vector2(width, deck_h))
	_place(host.get_node("UndoButton"), Vector2(left + 8.0 * u, 206.0 * u + deck_h), button)
	var start := host.get_node("StartButton") as Button
	_place(start, Vector2(s.x * 0.5 - 104.0 * u, s.y - 83.0 * u), Vector2(208.0, 51.0) * u)
	start.add_theme_font_size_override("font_size", int(23.0 * u))


static func _place(node: Control, point: Vector2, dimensions: Vector2) -> void:
	node.position = point
	node.size = dimensions
