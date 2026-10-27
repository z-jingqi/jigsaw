extends RefCounted
## Draw a bounded set of real gameplay materials before interactive startup.
## The caller owns timeout/cancellation and an active, opaque-covered render target.

const Factory := preload("res://scripts/gameplay/board/PieceVisualFactory.gd")
const Knob := preload("res://scripts/gameplay/board/KnobSourceGeometry.gd")
const Curves := preload("res://scripts/gameplay/board/PieceCurvePreparation.gd")
const SnapPresentation := preload("res://scripts/gameplay/board/BoardSnapPresentation.gd")
const Glow := preload("res://scripts/gameplay/board/PieceSnapGlow.gd")
const FrameGate := preload("res://scripts/runtime/CancellableFrame.gd")
const DRAW_SIZE := Vector2(640, 256)


static func prepare(
	stage: Node2D, texture: Texture2D, level: Dictionary, current: Callable, canceled: Signal
) -> bool:
	if not _active(stage, current) or texture == null or canceled.is_null():
		return false
	var modes: Dictionary = level.get("modes", {})
	var polygon: Array = modes.get("polygon", {}).get("pieces", [])
	if polygon.is_empty() or not modes.has("knob"):
		return false
	var knob: Array = Knob.generate(modes.knob, texture.get_size())
	if knob.is_empty():
		return false
	var pieces: Array = [_piece(polygon[0], "polygon"), _piece(knob[0], "knob")]
	if pieces[0].is_empty() or pieces[1].is_empty():
		return false
	if not await Curves.prepare_many(pieces, stage.get_tree(), current, canceled):
		return false
	if not _active(stage, current):
		return false
	pieces.append(_swap_piece(texture.get_size()))
	var carrier := Node2D.new()
	carrier.name = "GameplayMaterialPreparation"
	stage.add_child(carrier)
	var visuals: Array[Node2D] = []
	for index in pieces.size():
		var curved := index < 2
		var visual := Factory.create_piece_visual(
			pieces[index], texture, {"cardboard": curved, "curve_rendering": curved}
		)
		visual.position = Vector2(106 + index * 210, 128)
		carrier.add_child(visual)
		visuals.append(visual)
	if not await _draw_frame(stage, current, canceled):
		_dispose(carrier)
		return false
	for visual in visuals:
		Factory.set_visual_lifted(visual, true, carrier, false)
	if not await _draw_frame(stage, current, canceled):
		_dispose(carrier)
		return false
	# Exercise the real destination-imprint creation path, including its fringe.
	# Offset the ghost so it has uncovered pixels rather than hiding behind the face.
	for index in 2:
		var presentation := SnapPresentation.new()
		carrier.add_child(presentation)
		presentation.set_reduced_motion(true)
		var member: Dictionary = pieces[index].duplicate()
		member["visual"] = visuals[index]
		member["home"] = Vector2(106 + index * 210, 76)
		presentation.show_preview(
			{"active_member": member, "other_member": {"id": "preparation_neighbor"}}
		)
	if not await _draw_frame(stage, current, canceled):
		_dispose(carrier)
		return false
	# Use the original additive face material, held visibly at its peak only here.
	# No gameplay node, completion event, animation timing or saved state is changed.
	for index in visuals.size():
		var glow := Glow.new()
		glow.configure(pieces[index].polygon, visuals[index].get_node("piece_texture"))
		visuals[index].add_child(glow)
		glow.set_process(false)
		glow.modulate.a = 1.0
	var rendered := await _draw_frame(stage, current, canceled)
	_dispose(carrier)
	return rendered


static func _piece(source: Dictionary, id: String) -> Dictionary:
	var points := PackedVector2Array()
	for value in source.get("points", []):
		points.append(Vector2(value[0], value[1]))
	if points.size() < 3:
		return {}
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var extent := maxf(bounds.size.x, bounds.size.y)
	if extent <= 0.0:
		return {}
	var local := PackedVector2Array()
	for point in points:
		local.append((point - bounds.get_center()) * (144.0 / extent))
	return {"id": id, "polygon": local, "uv": points, "cut_lines": []}


static func _swap_piece(source_size: Vector2) -> Dictionary:
	var points := PackedVector2Array(
		[Vector2(-72, -72), Vector2(72, -72), Vector2(72, 72), Vector2(-72, 72)]
	)
	var uv := PackedVector2Array(
		[Vector2.ZERO, Vector2(source_size.x, 0), source_size, Vector2(0, source_size.y)]
	)
	return {"id": "swap", "polygon": points, "uv": uv, "cut_lines": []}


static func _draw_frame(stage: Node2D, current: Callable, canceled: Signal) -> bool:
	if not _active(stage, current):
		return false
	if not await FrameGate.wait(stage.get_tree().process_frame, canceled):
		return false
	if not _active(stage, current):
		return false
	if not await FrameGate.wait(RenderingServer.frame_post_draw, canceled):
		return false
	return _active(stage, current)


static func _active(stage: Node2D, current: Callable) -> bool:
	return (
		is_instance_valid(stage)
		and stage.is_inside_tree()
		and current.is_valid()
		and current.call()
	)


static func _dispose(carrier: Node2D) -> void:
	if is_instance_valid(carrier):
		carrier.free()
