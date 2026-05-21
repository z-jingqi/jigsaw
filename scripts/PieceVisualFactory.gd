extends RefCounted
class_name PieceVisualFactory

const SHADOW_REST_OFFSET := Vector2(3.0, 4.0)
const SHADOW_LIFT_OFFSET := Vector2(8.0, 12.0)
const EDGE_OFFSET := Vector2(1.8, 2.4)
const OUTER_STROKE_WIDTH := 5.0
const INNER_STROKE_WIDTH := 1.35


static func create_piece_visual(piece: Dictionary, texture: Texture2D) -> Node2D:
	var node := Node2D.new()
	node.name = piece["id"] + "_visual"
	var shadow := Polygon2D.new()
	shadow.name = "piece_shadow"
	shadow.polygon = piece["polygon"]
	shadow.color = Color(0.0, 0.0, 0.0, 0.32)
	shadow.position = SHADOW_REST_OFFSET
	shadow.z_index = -4
	node.add_child(shadow)
	var paper_edge := Polygon2D.new()
	paper_edge.name = "piece_paper_edge"
	paper_edge.polygon = piece["polygon"]
	paper_edge.color = Color("#d7bd94")
	paper_edge.position = EDGE_OFFSET
	paper_edge.z_index = -3
	node.add_child(paper_edge)
	var poly := Polygon2D.new()
	poly.name = "piece_texture"
	poly.texture = texture
	poly.polygon = piece["polygon"]
	poly.uv = piece["uv"]
	poly.z_index = 0
	node.add_child(poly)
	node.add_child(_piece_outline_line(piece["polygon"], OUTER_STROKE_WIDTH, Color(1.0, 0.91, 0.74, 0.92), 1))
	node.add_child(_piece_outline_line(piece["polygon"], INNER_STROKE_WIDTH, Color(0.16, 0.10, 0.05, 0.78), 2))
	for cut_line in piece["cut_lines"]:
		node.add_child(_piece_cut_line(cut_line, 3.2, Color(1.0, 0.91, 0.74, 0.72), 3))
		node.add_child(_piece_cut_line(cut_line, 1.25, Color(0.15, 0.10, 0.06, 0.70), 4))
	return node


static func set_group_lifted(group, lifted: bool, tween_owner: Node) -> void:
	if group == null:
		return
	for member in group.members:
		var visual: Node2D = member.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			continue
		var shadow := visual.get_node_or_null("piece_shadow")
		if shadow == null:
			continue
		var target_offset := SHADOW_LIFT_OFFSET if lifted else SHADOW_REST_OFFSET
		var target_alpha := 0.46 if lifted else 0.32
		var tween := tween_owner.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property(shadow, "position", target_offset, 0.12)
		tween.parallel().tween_property(shadow, "color:a", target_alpha, 0.12)


static func _piece_outline_line(points: PackedVector2Array, width: float, color: Color, z_index: int) -> Line2D:
	var line := Line2D.new()
	line.name = "piece_outline"
	line.width = width
	line.default_color = color
	line.closed = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = z_index
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
