extends RefCounted
## Editorial home layout: one clear heading, artwork, and one primary action.

const TitleLayout := preload("res://scripts/screens/home/ThemeTitleLayout.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")


static func apply(host: Control) -> void:
	var s := host.size
	var u := minf(s.x / 390.0, s.y / 844.0)
	var canvas := Clean.canvas_scale(s, host.get_window())
	var safe := Clean.safe_insets(s)
	var usable_width := s.x - safe.x - safe.z
	var width := minf(usable_width - 48.0 * u, 370.0 * u)
	var left := safe.x + (usable_width - width) * 0.5
	Buttons.place_navigation(host.get_node("AlbumButton"), host)
	Buttons.place_navigation(host.get_node("MenuButton"), host, true)
	Buttons.place_navigation(host.get_node("ThemesButton"), host, true, 1)
	var top := safe.y + maxf(100.0 * u, Buttons.header_center_y(s) + 50.0 * u)
	for name in ["ThemeName", "IncomingThemeName"]:
		var title := host.get_node(name) as Label
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.max_lines_visible = 1
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_place(title, Vector2(left, top), Vector2(width - 48.0 * u, 54.0 * u))
		Clean.label(title, roundi(maxf(32.0 * u, 24.0 * canvas)))
		TitleLayout.fit(title, title.size, roundi(maxf(32.0 * u, 24.0 * canvas)))
	_place(host.get_node("Botanical"), Vector2(left + width - 43.0 * u, top), Vector2(43, 54) * u)
	var deck_top := top + 76.0 * u
	var pager_side := maxf(44.0 * u, 44.0 * canvas)
	var action_height := maxf(54.0 * u, 44.0 * canvas)
	var footer_height := maxf(170.0 * u, 56.0 * u + pager_side + action_height)
	var deck_height := minf(s.y - safe.w - deck_top - footer_height, width * 1.42)
	var deck := host.get_node("Deck") as Control
	_place(deck, Vector2(left, deck_top), Vector2(width, maxf(100.0 * u, deck_height)))
	var pager_top := deck_top + deck.size.y + 4.0 * u
	var undo := host.get_node("UndoButton") as Button
	_place(undo, Vector2(left, pager_top), Vector2(maxf(96.0 * u, 96.0 * canvas), pager_side))
	undo.add_theme_font_size_override("font_size", roundi(maxf(16.0 * u, 16.0 * canvas)))
	var start := host.get_node("StartButton") as Button
	_place(start, Vector2(left, 0), Vector2(width, action_height))
	start.position.y = s.y - safe.w - 34.0 * u - start.size.y
	start.add_theme_font_size_override("font_size", roundi(maxf(18.0 * u, 16.0 * canvas)))
	var empty := host.get_node("EmptyState") as Label
	_place(empty, Vector2(left, deck_top + deck.size.y * 0.35), Vector2(width, 100.0 * u))
	Clean.label(empty, roundi(maxf(18.0 * u, 16.0 * canvas)), true)


static func _place(node: Control, point: Vector2, dimensions: Vector2) -> void:
	node.position = point
	if node is Button:
		Buttons.apply_size(node, dimensions)
	else:
		node.size = dimensions
