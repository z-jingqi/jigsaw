extends Node
## Interruptible crossfade for browsing artworks without rebuilding a page.

var _image: TextureRect
var _texture: Texture2D
var _tween: Tween
var _layers: Array[TextureRect] = []


func show_image(image: TextureRect, texture: Texture2D, animate: bool) -> void:
	if image == _image and texture == _texture:
		return
	_stop()
	_image = image
	_texture = texture
	if not animate or _image.texture == null:
		finish()
		return
	var incoming := TextureRect.new()
	incoming.texture = texture
	incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE
	incoming.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	incoming.modulate.a = 0.0
	_image.add_child(incoming)
	incoming.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layers.append(incoming)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(incoming, "modulate:a", 1.0, 0.22)
	_tween.finished.connect(finish, CONNECT_ONE_SHOT)


func finish() -> void:
	_stop()
	if is_instance_valid(_image):
		_image.texture = _texture
		_image.modulate.a = 1.0
	for layer in _layers:
		if is_instance_valid(layer):
			layer.queue_free()
	_layers.clear()


func active_motion_count() -> int:
	return int(_tween != null and _tween.is_valid() and _tween.is_running())


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _exit_tree() -> void:
	_stop()
	_layers.clear()
