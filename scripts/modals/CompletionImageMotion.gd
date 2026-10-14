extends Node
## Resolves the fixed completion timeline against the actual board's current bounds.

@export_range(0.0, 1.0) var image_progress := 0.0:
	set(value):
		image_progress = clampf(value, 0.0, 1.0)
		_apply_image_rect()

var _stage: Control
var _image: TextureRect
var _source: Rect2
var _target: Rect2


func configure(stage: Control, image: TextureRect, source: Rect2, target: Rect2) -> void:
	_stage = stage
	_image = image
	_source = source if source.has_area() else target
	_target = target
	_apply_image_rect()


func _apply_image_rect() -> void:
	if not is_instance_valid(_stage) or not is_instance_valid(_image):
		return
	var progress := smoothstep(0.0, 1.0, image_progress)
	_stage.position = _source.position.lerp(_target.position, progress)
	_stage.size = _source.size.lerp(_target.size, progress)
	_image.position = Vector2.ZERO
	_image.size = _stage.size
	var material := _image.material as ShaderMaterial
	if material != null and _image.size.y > 0:
		material.set_shader_parameter("rect_size", _image.size)
		material.set_shader_parameter("rect_aspect", _image.size.x / _image.size.y)
		material.set_shader_parameter("corner_radius", 0.024 * progress)
