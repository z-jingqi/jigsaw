class_name HomeCoverMotion
extends RefCounted

## Keeps a bounded five-card carousel pool. Card edges retain a fixed gap while
## the selected card and its neighbours scale continuously with drag distance.

const SIDE_CARD_SCALE := 0.86
const FAR_CARD_SCALE := 0.74
const CARD_CORNER_RADIUS := 0.045
const OFFSETS: Array[int] = [-2, -1, 0, 1, 2]
const CoverShader := preload("res://shaders/ui/home_cover_crossfade.gdshader")

var _covers: Array[TextureRect] = []
var _materials: Array[ShaderMaterial] = []
var _host: Control


func _init(covers: Array) -> void:
	for value in covers:
		var cover := value as TextureRect
		if cover == null:
			continue
		_covers.append(cover)
		var cover_material := ShaderMaterial.new()
		cover_material.shader = CoverShader
		cover_material.set_shader_parameter(&"corner_radius", CARD_CORNER_RADIUS)
		cover_material.set_shader_parameter(&"edge_direction", 0.0)
		cover_material.set_shader_parameter(&"feather_width", 0.001)
		cover.material = cover_material
		_materials.append(cover_material)
	_host = _covers[0].get_parent() as Control if not _covers.is_empty() else null


func apply_layout(
	direction: int,
	progress: float,
	card_size: Vector2,
	viewport_center: Vector2,
	gap: float,
	frame_inset: float,
	reduced_motion: bool
) -> void:
	if _covers.size() != OFFSETS.size() or card_size.x <= 0.0 or card_size.y <= 0.0:
		return
	var amount := clampf(progress, 0.0, 1.0)
	var signed_progress := float(direction) * amount
	var scales: Dictionary = {}
	var widths: Dictionary = {}
	for offset in OFFSETS:
		var distance := absf(float(offset) - signed_progress)
		if reduced_motion and amount > 0.0:
			distance = absf(float(offset - direction))
		var scale_value := _scale_for_distance(distance)
		scales[offset] = scale_value
		widths[offset] = card_size.x * scale_value

	var centers := {0: 0.0}
	for offset in [1, 2]:
		centers[offset] = (
			float(centers[offset - 1])
			+ float(widths[offset - 1]) * 0.5
			+ gap
			+ float(widths[offset]) * 0.5
		)
	for offset in [-1, -2]:
		centers[offset] = (
			float(centers[offset + 1])
			- float(widths[offset + 1]) * 0.5
			- gap
			- float(widths[offset]) * 0.5
		)

	var focus_anchor := 0.0
	if direction != 0 and centers.has(direction):
		focus_anchor = lerpf(0.0, float(centers[direction]), amount)
	for index in _covers.size():
		var cover := _covers[index]
		var offset := OFFSETS[index]
		var scale_value := float(scales[offset])
		cover.size = card_size
		cover.pivot_offset = card_size * 0.5
		cover.scale = Vector2.ONE * scale_value
		cover.position = viewport_center - card_size * 0.5
		cover.position.x += float(centers[offset]) - focus_anchor
		cover.z_index = 100 - roundi(absf(float(offset) - signed_progress) * 10.0)
		cover.modulate = Color.WHITE
		var frame := cover.get_node("CardFrame") as Control
		frame.position = Vector2.ONE * -frame_inset
		frame.size = card_size + Vector2.ONE * frame_inset * 2.0
		_configure_material(index, cover, card_size)


func pool_size() -> int:
	return _covers.size()


func visible_cover_count() -> int:
	if not is_instance_valid(_host):
		return 0
	var viewport_rect := _host.get_global_rect()
	var count := 0
	for cover in _covers:
		if cover.visible and viewport_rect.intersects(cover.get_global_rect()):
			count += 1
	return count


func _scale_for_distance(distance: float) -> float:
	if distance <= 1.0:
		return lerpf(1.0, SIDE_CARD_SCALE, distance)
	if distance <= 2.0:
		return lerpf(SIDE_CARD_SCALE, FAR_CARD_SCALE, distance - 1.0)
	return FAR_CARD_SCALE


func _configure_material(index: int, cover: TextureRect, card_size: Vector2) -> void:
	var material := _materials[index]
	var card_aspect := card_size.x / maxf(1.0, card_size.y)
	var texture_size := cover.texture.get_size() if cover.texture != null else card_size
	material.set_shader_parameter(&"card_aspect", card_aspect)
	material.set_shader_parameter(&"texture_aspect", texture_size.x / maxf(1.0, texture_size.y))
