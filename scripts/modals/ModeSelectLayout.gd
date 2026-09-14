extends RefCounted
## Responsive composition in the same logical units as the home screen.


static func apply(host: Control) -> void:
	var content: Control = host.get_node("SafeArea/Content")
	var available := content.size
	var unit := minf(available.x / 390.0, available.y / 844.0)
	var width := minf(available.x, 390.0 * unit)
	var left := (available.x - width) * 0.5
	var header: Control = content.get_node("Header")
	header.size = Vector2(available.x, 76.0 * unit)
	_place(
		header.get_node("BackButton"), Vector2(left + 18 * unit, 22 * unit), Vector2.ONE * 36 * unit
	)
	var title: Label = header.get_node("Title")
	_place(title, Vector2(left + 80 * unit, 24 * unit), Vector2(width - 160 * unit, 40 * unit))
	title.add_theme_font_size_override("font_size", int(23 * unit))
	for side in ["Left", "Right"]:
		var x := left + (65.0 if side == "Left" else 284.0) * unit
		_place(header.get_node("Cloud" + side), Vector2(x, 41 * unit), Vector2(40, 12) * unit)
	var preview: TextureRect = content.get_node("Preview")
	var preview_height := minf(438 * unit, available.y * 0.52)
	var aspect := 0.75
	if preview.texture != null:
		aspect = preview.texture.get_width() / float(preview.texture.get_height())
	var preview_width := minf(308 * unit, preview_height * aspect)
	preview_height = preview_width / aspect
	_place(
		preview,
		Vector2((available.x - preview_width) * 0.5, 82 * unit),
		Vector2(preview_width, preview_height)
	)
	var material := preview.material as ShaderMaterial
	material.set_shader_parameter("rect_aspect", aspect)
	material.set_shader_parameter("rect_size", preview.size)
	var heading: Label = content.get_node("ModeHeading")
	var heading_y := preview.position.y + preview_height + 14 * unit
	_place(heading, Vector2(left, heading_y), Vector2(width, 40 * unit))
	heading.add_theme_font_size_override("font_size", int(23 * unit))
	var options: Control = content.get_node("Options")
	_place(
		options,
		Vector2(left + 22 * unit, heading_y + 51 * unit),
		Vector2(width - 44 * unit, 144 * unit)
	)
	var count := options.get_child_count()
	var gap := 7 * unit
	var card_width := (options.size.x - gap * (count - 1)) / maxf(1, count)
	for index in count:
		_place(
			options.get_child(index),
			Vector2(index * (card_width + gap), 0),
			Vector2(card_width, options.size.y)
		)
		options.get_child(index).set_layout_origin(Vector2(index * (card_width + gap), 0))
	var start: Control = content.get_node("StartButton")
	_place(
		start,
		Vector2((available.x - 216 * unit) * 0.5, available.y - 120 * unit),
		Vector2(216, 54) * unit
	)
	var start_label: Label = start.get_node("Label")
	start_label.add_theme_font_size_override("font_size", int(25 * unit))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("DDE3CF") if state != "pressed" else Color("BCCDAF")
		style.set_corner_radius_all(int(40 * unit))
		if state == "focus":
			style.set_border_width_all(maxi(1, int(unit)))
			style.border_color = Color("194F47")
		start.add_theme_stylebox_override(state, style)


static func _place(node: Control, position: Vector2, size: Vector2) -> void:
	node.position = position
	node.size = size
