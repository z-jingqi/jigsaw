extends RefCounted
## Quiet artwork-led composition with a separate, thumb-friendly decision area.

const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")


static func apply(host: Control) -> void:
	var content: Control = host.get_node("SafeArea/Content")
	var available := content.size
	var landscape := available.x > available.y * 1.15
	var unit := minf(available.x / 390.0, available.y / 844.0)
	if landscape:
		unit = minf(available.x / 844.0, available.y / 390.0)
	var width := minf(available.x - 48 * unit, 560 * unit)
	var left := (available.x - width) * 0.5
	var header: Control = content.get_node("Header")
	header.size = Vector2(available.x, 80 * unit)
	Buttons.place_navigation(header.get_node("BackButton"), host)
	var title: Label = header.get_node("Title")
	_place(title, Vector2(left + 48 * unit, 22 * unit), Vector2(width - 96 * unit, 40 * unit))
	Clean.label(title, int(24 * unit))
	for side in ["Left", "Right"]:
		header.get_node("Cloud" + side).visible = false
	var preview: TextureRect = content.get_node("Preview")
	var aspect := 0.75
	if preview.texture != null:
		aspect = preview.texture.get_width() / float(preview.texture.get_height())
	var preview_height := minf(410 * unit, available.y * 0.49)
	if landscape:
		preview_height = available.y - 112 * unit
	var preview_width := minf(width, preview_height * aspect)
	preview_height = preview_width / aspect
	var preview_x := (available.x - preview_width) * 0.5
	if landscape:
		preview_x = available.x * 0.27 - preview_width * 0.5
	_place(preview, Vector2(preview_x, 94 * unit), Vector2(preview_width, preview_height))
	var material := preview.material as ShaderMaterial
	material.set_shader_parameter("rect_aspect", aspect)
	material.set_shader_parameter("rect_size", preview.size)
	var heading: Label = content.get_node("ModeHeading")
	var heading_y := preview.position.y + preview_height + 24 * unit
	var controls_left := left
	var controls_width := width
	if landscape:
		controls_left = available.x * 0.53
		controls_width = available.x * 0.42
		heading_y = 102 * unit
	_place(heading, Vector2(controls_left, heading_y), Vector2(controls_width, 34 * unit))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	Clean.label(heading, int(22 * unit))
	var options: Control = content.get_node("Options")
	_place(
		options, Vector2(controls_left, heading_y + 48 * unit), Vector2(controls_width, 136 * unit)
	)
	var count := options.get_child_count()
	var gap := 10 * unit
	var card_width := (options.size.x - gap * (count - 1)) / maxf(1, count)
	for index in count:
		var origin := Vector2(index * (card_width + gap), 0)
		_place(options.get_child(index), origin, Vector2(card_width, options.size.y))
		options.get_child(index).set_layout_origin(origin)
	var start: Button = content.get_node("StartButton")
	_place(
		start, Vector2(controls_left, available.y - 80 * unit), Vector2(controls_width, 54 * unit)
	)
	Clean.button(start, true)
	var start_label: Label = start.get_node("Label")
	Clean.label(start_label, int(20 * unit))
	start_label.add_theme_color_override(
		"font_color", Clean.MUTED if start.disabled else Clean.PAPER
	)


static func _place(node: Control, position: Vector2, size: Vector2) -> void:
	node.position = position
	if node is Button:
		Buttons.apply_size(node as Button, size)
	else:
		node.size = size
