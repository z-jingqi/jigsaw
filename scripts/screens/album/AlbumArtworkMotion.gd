extends Node
## No stale-image crossfade: each published texture belongs to the current intent.
var _image: TextureRect


func show_image(image: TextureRect, texture: Texture2D, _animate: bool) -> void:
	_image = image
	_image.texture = texture
	_image.modulate.a = 1.0


func finish() -> void:
	if is_instance_valid(_image):
		_image.modulate.a = 1.0


func active_motion_count() -> int:
	return 0
