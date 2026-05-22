extends RefCounted
class_name PieceVisualFactory

const SHADOW_REST_OFFSET := Vector2(4.0, 6.0)
const SHADOW_LIFT_OFFSET := Vector2(10.0, 15.0)
const SHADOW_REST_ALPHA := 0.82
const SHADOW_LIFT_ALPHA := 1.0
const SHADOW_REST_SCALE := Vector2(1.004, 1.004)
const SHADOW_LIFT_SCALE := Vector2(1.018, 1.018)
const EDGE_SIDE_OFFSET := Vector2(0.0, 2.8)
const LOWER_BEVEL_OFFSET := Vector2(0.8, 2.4)
const UPPER_HIGHLIGHT_OFFSET := Vector2(-0.7, -1.0)
const EDGE_SIDE_COLOR := Color("#c9a774")
const EDGE_LOWLIGHT_COLOR := Color(0.30, 0.17, 0.08, 0.28)
const EDGE_AMBIENT_COLOR := Color(0.18, 0.10, 0.05, 0.30)
const EDGE_HIGHLIGHT_COLOR := Color(1.0, 0.94, 0.78, 0.58)
const EDGE_CONTACT_COLOR := Color(0.23, 0.13, 0.06, 0.42)


static func create_piece_visual(piece: Dictionary, texture: Texture2D) -> Node2D:
	var node := Node2D.new()
	node.name = piece["id"] + "_visual"
	var shadow := _piece_shadow(piece["polygon"])
	node.add_child(shadow)
	var paper_edge := _piece_side(piece["polygon"])
	node.add_child(paper_edge)
	var poly := Polygon2D.new()
	poly.name = "piece_texture"
	poly.texture = texture
	poly.polygon = piece["polygon"]
	poly.uv = piece["uv"]
	poly.z_index = 0
	node.add_child(poly)
	node.add_child(_piece_outline_line(piece["polygon"], 9.0, EDGE_LOWLIGHT_COLOR, 1, LOWER_BEVEL_OFFSET))
	node.add_child(_piece_outline_line(piece["polygon"], 5.8, EDGE_HIGHLIGHT_COLOR, 2, UPPER_HIGHLIGHT_OFFSET))
	node.add_child(_piece_outline_line(piece["polygon"], 2.2, EDGE_CONTACT_COLOR, 3, Vector2.ZERO))
	for cut_line in piece["cut_lines"]:
		node.add_child(_piece_cut_line(cut_line, 7.5, EDGE_LOWLIGHT_COLOR, 4, LOWER_BEVEL_OFFSET))
		node.add_child(_piece_cut_line(cut_line, 4.0, EDGE_HIGHLIGHT_COLOR, 5, UPPER_HIGHLIGHT_OFFSET))
		node.add_child(_piece_cut_line(cut_line, 1.6, EDGE_CONTACT_COLOR, 6, Vector2.ZERO))
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
		var target_alpha := SHADOW_LIFT_ALPHA if lifted else SHADOW_REST_ALPHA
		var target_scale := SHADOW_LIFT_SCALE if lifted else SHADOW_REST_SCALE
		var tween := tween_owner.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property(shadow, "position", target_offset, 0.12)
		tween.parallel().tween_property(shadow, "modulate:a", target_alpha, 0.12)
		tween.parallel().tween_property(shadow, "scale", target_scale, 0.12)


static func _piece_shadow(points: PackedVector2Array) -> Node2D:
	var shadow := Node2D.new()
	shadow.name = "piece_shadow"
	shadow.position = SHADOW_REST_OFFSET
	shadow.scale = SHADOW_REST_SCALE
	shadow.modulate.a = SHADOW_REST_ALPHA
	shadow.z_index = -6
	var layers := [
		{ "offset": Vector2(-3.0, -2.0), "alpha": 0.035 },
		{ "offset": Vector2(2.0, 1.5), "alpha": 0.055 },
		{ "offset": Vector2(6.0, 5.0), "alpha": 0.060 },
		{ "offset": Vector2(10.0, 9.0), "alpha": 0.038 },
		{ "offset": Vector2(14.0, 13.0), "alpha": 0.020 },
	]
	for i in layers.size():
		var layer := Polygon2D.new()
		layer.name = "shadow_blur_%02d" % i
		layer.polygon = points
		layer.color = Color(0.0, 0.0, 0.0, layers[i]["alpha"])
		layer.position = layers[i]["offset"]
		layer.z_index = -6 + i
		shadow.add_child(layer)
	return shadow


static func _piece_side(points: PackedVector2Array) -> Node2D:
	var side := Node2D.new()
	side.name = "piece_paper_edge"
	side.z_index = -3
	var body := Polygon2D.new()
	body.name = "edge_side_body"
	body.polygon = points
	body.color = EDGE_SIDE_COLOR
	body.position = EDGE_SIDE_OFFSET
	body.z_index = -3
	side.add_child(body)
	side.add_child(_piece_outline_line(points, 8.0, EDGE_AMBIENT_COLOR, -2, EDGE_SIDE_OFFSET + Vector2(0.0, 1.5)))
	side.add_child(_piece_outline_line(points, 4.0, Color(1.0, 0.89, 0.63, 0.20), -1, Vector2(-0.6, -0.4)))
	return side


static func _piece_outline_line(points: PackedVector2Array, width: float, color: Color, z_index: int, offset := Vector2.ZERO) -> Line2D:
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
	line.position = offset
	line.points = points
	return line


static func _piece_cut_line(points: PackedVector2Array, width: float, color: Color, z_index: int, offset := Vector2.ZERO) -> Line2D:
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
	line.position = offset
	line.points = points
	return line
