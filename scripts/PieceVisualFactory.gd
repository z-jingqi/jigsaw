extends RefCounted
class_name PieceVisualFactory

const SEPARATOR_COLOR := Color(0.22, 0.17, 0.12, 0.92)
const SEPARATOR_LIFT_COLOR := Color(0.64, 0.35, 0.10, 0.98)
const OUTLINE_COLOR := Color(0.36, 0.27, 0.18, 0.88)
const OUTLINE_LIFT_COLOR := Color("#D9933F")
const INNER_SHADE_COLOR := Color(0.18, 0.13, 0.08, 0.30)
const INNER_HIGHLIGHT_COLOR := Color("#FFF6E6", 0.82)
const CUT_LINE_COLOR := Color(0.26, 0.20, 0.14, 0.70)
const CUT_LINE_LIFT_COLOR := Color(0.72, 0.43, 0.18, 0.78)
const SURFACE_LIGHT_COLOR := Color(1.0, 0.96, 0.88, 0.06)
const SHADOW_COLOR := Color(0.40, 0.24, 0.10, 0.12)
const SHADOW_OFFSET := Vector2(5.0, 7.0)
const LIFTED_SCALE := Vector2(1.014, 1.014)


static func create_piece_visual(piece: Dictionary, texture: Texture2D) -> Node2D:
	var node := Node2D.new()
	node.name = piece["id"] + "_visual"
	node.add_child(_piece_lift_shadow(piece["polygon"]))
	node.add_child(_piece_outline_line(piece["polygon"], 4.4, SEPARATOR_COLOR, -1, "piece_separator"))
	var poly := Polygon2D.new()
	poly.name = "piece_texture"
	poly.texture = texture
	poly.polygon = piece["polygon"]
	poly.uv = piece["uv"]
	poly.z_index = 0
	node.add_child(poly)
	var light := Polygon2D.new()
	light.name = "piece_surface_light"
	light.polygon = piece["polygon"]
	light.color = SURFACE_LIGHT_COLOR
	light.z_index = 1
	node.add_child(light)
	node.add_child(_piece_outline_line(piece["polygon"], 2.4, OUTLINE_COLOR, 3, "piece_outline"))
	node.add_child(_piece_outline_line(piece["polygon"], 1.8, INNER_SHADE_COLOR, 4, "piece_inner_shade", Vector2(0.65, 0.85)))
	node.add_child(_piece_outline_line(piece["polygon"], 1.2, INNER_HIGHLIGHT_COLOR, 5, "piece_inner_highlight", Vector2(-0.55, -0.65)))
	for cut_line in piece["cut_lines"]:
		node.add_child(_piece_cut_line(cut_line, 1.7, CUT_LINE_COLOR, 6))
	return node


static func set_group_lifted(group, lifted: bool, tween_owner: Node) -> void:
	if group == null:
		return
	for member in group.members:
		var visual: Node2D = member.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			continue
		var target_scale := LIFTED_SCALE if lifted else Vector2.ONE
		var tween := tween_owner.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property(visual, "scale", target_scale, 0.12)
		var shadow := visual.get_node_or_null("piece_lift_shadow")
		if shadow != null:
			tween.parallel().tween_property(shadow, "modulate:a", 1.0 if lifted else 0.0, 0.12)
		for child in visual.get_children():
			if child is Line2D:
				var line := child as Line2D
				if line.name == "piece_separator":
					tween.parallel().tween_property(line, "default_color", SEPARATOR_LIFT_COLOR if lifted else SEPARATOR_COLOR, 0.12)
				elif line.name == "piece_outline":
					tween.parallel().tween_property(line, "default_color", OUTLINE_LIFT_COLOR if lifted else OUTLINE_COLOR, 0.12)
				elif line.name == "piece_cut_line":
					tween.parallel().tween_property(line, "default_color", CUT_LINE_LIFT_COLOR if lifted else CUT_LINE_COLOR, 0.12)


static func _piece_lift_shadow(points: PackedVector2Array) -> Node2D:
	var shadow := Node2D.new()
	shadow.name = "piece_lift_shadow"
	shadow.position = SHADOW_OFFSET
	shadow.modulate.a = 0.0
	shadow.z_index = -2
	var layers := [
		{ "scale": Vector2(1.010, 1.010), "offset": Vector2.ZERO, "alpha": 0.45 },
		{ "scale": Vector2(1.024, 1.024), "offset": Vector2(3.0, 3.0), "alpha": 0.23 },
		{ "scale": Vector2(1.044, 1.044), "offset": Vector2(7.0, 7.0), "alpha": 0.10 },
	]
	for i in layers.size():
		var layer := Polygon2D.new()
		layer.name = "lift_shadow_%02d" % i
		layer.polygon = points
		layer.color = Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, SHADOW_COLOR.a * float(layers[i]["alpha"]))
		layer.scale = layers[i]["scale"]
		layer.position = layers[i]["offset"]
		layer.z_index = -2 + i
		shadow.add_child(layer)
	return shadow


static func _piece_outline_line(points: PackedVector2Array, width: float, color: Color, z_index: int, line_name: String, offset := Vector2.ZERO) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.width = width
	line.default_color = color
	line.closed = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = z_index
	line.position = offset
	line.points = points
	return line


static func _piece_cut_line(points: PackedVector2Array, width: float, color: Color, z_index: int) -> Line2D:
	var line := Line2D.new()
	line.name = "piece_cut_line"
	line.width = width
	line.default_color = color
	line.closed = false
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = z_index
	line.points = points
	return line
