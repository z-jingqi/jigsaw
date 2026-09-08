extends RefCounted
## Responsive home composition, independent of browsing state.


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
	_place(title, Vector2(left, 95.0 * u), Vector2(width, 65.0 * u))
	title.add_theme_font_size_override("font_size", int(42.0 * u))
	var subtitle := host.get_node("Subtitle") as Label
	_place(subtitle, Vector2(left, 163.0 * u), Vector2(width, 30.0 * u))
	subtitle.add_theme_font_size_override("font_size", int(17.0 * u))
	var deck := host.get_node("Deck") as Control
	var deck_h := minf(s.y - 340.0 * u, width * 1.42)
	_place(deck, Vector2(left, 218.0 * u), Vector2(width, deck_h))
	_place(host.get_node("UndoButton"), Vector2(left + 8.0 * u, 229.0 * u + deck_h), button)
	var start := host.get_node("StartButton") as Button
	_place(start, Vector2(s.x * 0.5 - 104.0 * u, s.y - 83.0 * u), Vector2(208.0, 51.0) * u)
	start.add_theme_font_size_override("font_size", int(23.0 * u))


static func _place(node: Control, point: Vector2, dimensions: Vector2) -> void:
	node.position = point
	node.size = dimensions
