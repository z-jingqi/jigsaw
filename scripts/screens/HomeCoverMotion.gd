class_name HomeCoverMotion
extends RefCounted

const OUTGOING_DEPTH_SCALE := 0.008
const INCOMING_START_SCALE := 1.03
const MAX_OVERLAP_RATIO := 0.1
const CARD_CORNER_RADIUS := 0.082
const CrossfadeShader := preload("res://shaders/ui/home_cover_crossfade.gdshader")

var _previous: TextureRect
var _current: TextureRect
var _next: TextureRect
var _previous_material: ShaderMaterial
var _current_material: ShaderMaterial
var _next_material: ShaderMaterial


func _init(previous: TextureRect, current: TextureRect, next: TextureRect) -> void:
	_previous = previous
	_current = current
	_next = next
	_previous_material = _create_crossfade_material()
	_current_material = _create_crossfade_material()
	_next_material = _create_crossfade_material()
	_previous.material = _previous_material
	_current.material = _current_material
	_next.material = _next_material
	reset()


func set_card_aspect(card_size: Vector2) -> void:
	var aspect := card_size.x / maxf(1.0, card_size.y)
	for pair in [
		[_previous_material, _previous],
		[_current_material, _current],
		[_next_material, _next],
	]:
		var card_material := pair[0] as ShaderMaterial
		var cover := pair[1] as TextureRect
		card_material.set_shader_parameter(&"card_aspect", aspect)
		var texture_size := cover.texture.get_size() if cover.texture != null else card_size
		card_material.set_shader_parameter(
			&"texture_aspect", texture_size.x / maxf(1.0, texture_size.y)
		)


func apply(direction: int, progress: float, reduced_motion := false) -> void:
	reset()
	if direction == 0 or progress <= 0.0:
		return
	var amount := clampf(progress, 0.0, 1.0)
	var incoming := _next if direction > 0 else _previous
	var incoming_material := _next_material if direction > 0 else _previous_material
	incoming.get_parent().move_child(incoming, incoming.get_parent().get_child_count() - 1)
	incoming_material.set_shader_parameter(&"edge_direction", float(direction))
	incoming_material.set_shader_parameter(&"feather_width", overlap_ratio(amount))
	if not reduced_motion:
		var outgoing_scale := 1.0 - sin(amount * PI) * OUTGOING_DEPTH_SCALE
		_current.scale = Vector2.ONE * outgoing_scale
		incoming.scale = Vector2.ONE * lerpf(INCOMING_START_SCALE, 1.0, amount)


func reset() -> void:
	for cover in [_previous, _current, _next]:
		cover.scale = Vector2.ONE
		cover.modulate.a = 1.0
	var cover_parent := _current.get_parent()
	cover_parent.move_child(_previous, 0)
	cover_parent.move_child(_current, 1)
	cover_parent.move_child(_next, 2)
	for crossfade_material in [_previous_material, _current_material, _next_material]:
		crossfade_material.set_shader_parameter(&"edge_direction", 0.0)
		crossfade_material.set_shader_parameter(&"feather_width", 0.001)


func overlap_ratio(progress: float) -> float:
	return maxf(0.001, MAX_OVERLAP_RATIO * sin(clampf(progress, 0.0, 1.0) * PI))


func _create_crossfade_material() -> ShaderMaterial:
	var crossfade_material := ShaderMaterial.new()
	crossfade_material.shader = CrossfadeShader
	crossfade_material.set_shader_parameter(&"corner_radius", CARD_CORNER_RADIUS)
	return crossfade_material
