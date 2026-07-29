class_name HomeCoverMotion
extends RefCounted

const OUTGOING_DEPTH_SCALE := 0.008
const INCOMING_START_SCALE := 1.03
const OUTGOING_END_ALPHA := 0.82
const INCOMING_START_ALPHA := 0.82
const EDGE_FEATHER_WIDTH := 0.08
const EdgeBlendShader := preload("res://shaders/ui/home_cover_edge_blend.gdshader")

var _previous: TextureRect
var _current: TextureRect
var _next: TextureRect
var _previous_material: ShaderMaterial
var _next_material: ShaderMaterial


func _init(previous: TextureRect, current: TextureRect, next: TextureRect) -> void:
	_previous = previous
	_current = current
	_next = next
	_previous_material = _create_edge_material()
	_next_material = _create_edge_material()
	_previous.material = _previous_material
	_next.material = _next_material
	reset()


func apply(direction: int, progress: float, reduced_motion := false) -> void:
	reset()
	if direction == 0 or progress <= 0.0:
		return
	var amount := clampf(progress, 0.0, 1.0)
	var incoming := _next if direction > 0 else _previous
	var incoming_material := _next_material if direction > 0 else _previous_material
	if not reduced_motion:
		var outgoing_scale := 1.0 - sin(amount * PI) * OUTGOING_DEPTH_SCALE
		_current.scale = Vector2.ONE * outgoing_scale
		incoming.scale = Vector2.ONE * lerpf(INCOMING_START_SCALE, 1.0, amount)
		incoming_material.set_shader_parameter(&"edge_direction", float(direction))
		incoming_material.set_shader_parameter(&"feather_strength", sin(amount * PI))
	_current.modulate.a = lerpf(1.0, OUTGOING_END_ALPHA, amount)
	incoming.modulate.a = lerpf(INCOMING_START_ALPHA, 1.0, amount)


func reset() -> void:
	for cover in [_previous, _current, _next]:
		cover.scale = Vector2.ONE
		cover.modulate.a = 1.0
	for edge_material in [_previous_material, _next_material]:
		edge_material.set_shader_parameter(&"edge_direction", 0.0)
		edge_material.set_shader_parameter(&"feather_strength", 0.0)


func _create_edge_material() -> ShaderMaterial:
	var edge_material := ShaderMaterial.new()
	edge_material.shader = EdgeBlendShader
	edge_material.set_shader_parameter(&"feather_width", EDGE_FEATHER_WIDTH)
	return edge_material
