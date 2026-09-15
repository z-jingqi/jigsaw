extends RefCounted
class_name PieceVisualFactory

const PieceReliefScript := preload("res://scripts/gameplay/board/PieceRelief.gd")

const CUT_LINE_COLOR := Color(0.26, 0.20, 0.14, 0.70)
const CUT_LINE_LIFT_COLOR := Color(0.72, 0.43, 0.18, 0.78)
const SHADOW_COLOR := Color(0.40, 0.24, 0.10, 0.12)
const SHADOW_OFFSET := Vector2(5.0, 7.0)
const SEAM_LINE_COLOR := Color(0.0, 0.0, 0.0, 0.22)


static func create_piece_visual(piece: Dictionary, texture: Texture2D, style := {}) -> Node2D:
	var node := Node2D.new()
	node.name = piece["id"] + "_visual"
	var cut_line_color: Color = style.get("cut_line_color", CUT_LINE_COLOR)
	var cut_line_lift_color: Color = style.get("cut_line_lift_color", CUT_LINE_LIFT_COLOR)
	node.set_meta("seam_line_color", style.get("seam_line_color", SEAM_LINE_COLOR))
	node.add_child(_piece_lift_shadow(piece["polygon"]))
	var side := PieceReliefScript.new()
	side.name = "piece_side"
	side.setup(piece["polygon"], false)
	node.add_child(side)
	var poly := Polygon2D.new()
	poly.name = "piece_texture"
	poly.texture = texture
	poly.polygon = piece["polygon"]
	poly.uv = piece["uv"]
	poly.z_index = 0
	node.add_child(poly)
	var bevel := PieceReliefScript.new()
	bevel.name = "piece_bevel"
	bevel.setup(piece["polygon"], true)
	node.add_child(bevel)
	cut_line_color.a = minf(cut_line_color.a, 0.24)
	cut_line_lift_color.a = minf(cut_line_lift_color.a, 0.32)
	for cut_line in piece["cut_lines"]:
		node.add_child(_piece_cut_line(cut_line, 0.8, cut_line_color, cut_line_lift_color, 6))
	return node


static func add_seam_outline(group, width: float) -> void:
	if group == null:
		return
	for member in group.members:
		var visual: Node2D = member.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			continue
		if visual.get_node_or_null("piece_seam_line") != null:
			continue
		var line := Line2D.new()
		line.name = "piece_seam_line"
		line.width = width
		var seam_color: Color = visual.get_meta("seam_line_color", SEAM_LINE_COLOR)
		seam_color.a = minf(seam_color.a, 0.18)
		line.default_color = seam_color
		line.closed = true
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		line.z_index = 5
		line.points = member["polygon"]
		visual.add_child(line)


static func set_group_lifted(group, lifted: bool, tween_owner: Node, animate := true) -> void:
	if group == null:
		return
	for member in group.members:
		var visual: Node2D = member.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			continue
		set_visual_lifted(visual, lifted, tween_owner, animate)


static func set_visual_lifted(
	visual: Node2D, lifted: bool, tween_owner: Node, animate := true
) -> void:
	var previous: Tween = visual.get_meta("lift_tween") if visual.has_meta("lift_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	if visual.has_meta("lift_tween"):
		visual.remove_meta("lift_tween")
	visual.scale = Vector2.ONE
	var shadow := visual.get_node_or_null("piece_lift_shadow")
	if not animate:
		if shadow != null:
			shadow.modulate.a = 1.0 if lifted else 0.0
		return
	var tween := tween_owner.create_tween().bind_node(visual)
	visual.set_meta("lift_tween", tween)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if shadow != null:
		tween.parallel().tween_property(shadow, "modulate:a", 1.0 if lifted else 0.0, 0.10)


static func _piece_lift_shadow(points: PackedVector2Array) -> Node2D:
	var shadow := Node2D.new()
	shadow.name = "piece_lift_shadow"
	shadow.position = SHADOW_OFFSET
	shadow.modulate.a = 0.0
	shadow.z_index = -2
	var layers := [
		{"scale": Vector2(1.010, 1.010), "offset": Vector2.ZERO, "alpha": 0.45},
		{"scale": Vector2(1.024, 1.024), "offset": Vector2(3.0, 3.0), "alpha": 0.23},
		{"scale": Vector2(1.044, 1.044), "offset": Vector2(7.0, 7.0), "alpha": 0.10},
	]
	for i in layers.size():
		var layer := Polygon2D.new()
		layer.name = "lift_shadow_%02d" % i
		layer.polygon = points
		layer.color = Color(
			SHADOW_COLOR.r,
			SHADOW_COLOR.g,
			SHADOW_COLOR.b,
			SHADOW_COLOR.a * float(layers[i]["alpha"])
		)
		layer.scale = layers[i]["scale"]
		layer.position = layers[i]["offset"]
		layer.z_index = -2 + i
		shadow.add_child(layer)
	return shadow


static func _piece_cut_line(
	points: PackedVector2Array, width: float, color: Color, lift_color: Color, z_index: int
) -> Line2D:
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
	line.set_meta("base_color", color)
	line.set_meta("lift_color", lift_color)
	return line
