extends RefCounted
## Editorial home layout: one clear heading, artwork, and one primary action.

const TitleLayout := preload("res://scripts/screens/home/ThemeTitleLayout.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")


static func apply(host: Control) -> void:
	var s := host.size
	var u := minf(s.x / 390.0, s.y / 844.0)
	var safe := Clean.safe_insets(s)
	var width := minf(s.x - 48.0 * u, 370.0 * u)
	var left := (s.x - width) * 0.5
	Buttons.place_navigation(host.get_node("AlbumButton"), host)
	Buttons.place_navigation(host.get_node("MenuButton"), host, true)
	Buttons.place_navigation(host.get_node("ThemesButton"), host, true, 1)
	var top := maxf(100.0 * u, Buttons.header_center_y(s) + 50.0 * u)
	for name in ["ThemeName", "IncomingThemeName"]:
		var title := host.get_node(name) as Label
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.max_lines_visible = 1
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_place(title, Vector2(left, top), Vector2(width - 48.0 * u, 54.0 * u))
		TitleLayout.fit(title, title.size, maxi(1, int(32.0 * u)))
		Clean.label(title, title.get_theme_font_size("font_size"))
	var subtitle := host.get_node("Subtitle") as Label
	_place(subtitle, Vector2(left, top + 59.0 * u), Vector2(width, 26.0 * u))
	Clean.label(subtitle, maxi(1, int(14.0 * u)), true)
	_place(host.get_node("Botanical"), Vector2(left + width - 43.0 * u, top), Vector2(43, 54) * u)
	var deck_top := top + 111.0 * u
	var deck_height := minf(s.y - safe.w - deck_top - 170.0 * u, width * 1.42)
	var deck := host.get_node("Deck") as Control
	_place(deck, Vector2(left, deck_top), Vector2(width, maxf(100.0 * u, deck_height)))
	var detail_top := deck_top + deck.size.y + 12.0 * u
	var undo := host.get_node("UndoButton") as Button
	_place(undo, Vector2(left, detail_top - 8.0 * u), Vector2.ONE * 44.0 * u)
	_place(
		host.get_node("NextButton"),
		Vector2(left + width - 44.0 * u, detail_top - 8.0 * u),
		Vector2.ONE * 44.0 * u
	)
	var counter := host.get_node("Counter") as Label
	_place(counter, Vector2(left + 55.0 * u, detail_top), Vector2(width - 110.0 * u, 28.0 * u))
	Clean.label(counter, maxi(1, int(13.0 * u)), true)
	var start := host.get_node("StartButton") as Button
	_place(start, Vector2(left, s.y - safe.w - 88.0 * u), Vector2(width, 54.0 * u))
	start.add_theme_font_size_override("font_size", maxi(1, int(18.0 * u)))
	var empty := host.get_node("EmptyState") as Label
	_place(empty, Vector2(left, deck_top + deck.size.y * 0.35), Vector2(width, 100.0 * u))
	Clean.label(empty, maxi(1, int(18.0 * u)), true)


static func _place(node: Control, point: Vector2, dimensions: Vector2) -> void:
	node.position = point
	node.size = dimensions
