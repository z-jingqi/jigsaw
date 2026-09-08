extends Control
## Owns the bounded card pool and its pointer-following, dismissal and recall.
signal selected(index: int)
const CoverShader := preload("res://shaders/ui/theme_cover.gdshader")
var themes: Array = []
var index := 0
var history: Array[Dictionary] = []
var reduced_motion := false
var _cards: Array[TextureRect] = []
var _tween: Tween
var _dragging := false
var _pointer := -2
var _start := Vector2.ZERO
var _offset := Vector2.ZERO
var _velocity := 0.0
var _last_time := 0
var _card_size := Vector2.ZERO


func _ready() -> void:
	for child in get_children():
		if child is TextureRect:
			_cards.append(child)
			var mat := ShaderMaterial.new()
			mat.shader = CoverShader
			child.material = mat
	resized.connect(_resize)


func configure(models: Array, selected_index: int) -> void:
	cancel()
	themes = models
	index = clampi(selected_index, 0, maxi(0, themes.size() - 1))
	history.clear()
	_refresh()


func select_theme(selected_index: int) -> void:
	cancel()
	if index != selected_index:
		history.append({"index": index, "direction": 1.0})
	index = selected_index
	_refresh()
	selected.emit(index)


func _refresh() -> void:
	_card_size = Vector2(size.x * 0.9, size.y * 0.92)
	for depth in _cards.size():
		var card := _cards[depth]
		card.visible = depth < themes.size()
		if themes.is_empty():
			continue
		card.texture = themes[posmod(index + depth, themes.size())].cover_texture
		card.size = _card_size
		card.pivot_offset = _card_size * 0.5
		card.z_index = 3 - depth
		card.material.set_shader_parameter("aspect", _card_size.x / _card_size.y)
		if card.texture != null:
			card.material.set_shader_parameter(
				"texture_aspect", card.texture.get_size().x / card.texture.get_size().y
			)
	_pose(Vector2.ZERO)


func _pose(offset: Vector2) -> void:
	_offset = offset
	for depth in _cards.size():
		var card := _cards[depth]
		card.position = (
			Vector2(size.x * 0.015, size.y * 0.008)
			+ Vector2(size.x * 0.035, size.y * 0.027) * depth
		)
		card.rotation = deg_to_rad(1.7 * depth)
		card.modulate.a = 1.0
		if depth == 0:
			card.position += offset
			card.rotation = 0.0 if reduced_motion else offset.x / maxf(1.0, size.x) * 0.19


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin(event.position, -1)
		elif _pointer == -1:
			end()
	elif event is InputEventMouseMotion and _dragging and _pointer == -1:
		drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			begin(event.position, event.index)
		elif event.index == _pointer:
			end()
	elif event is InputEventScreenDrag and _dragging and event.index == _pointer:
		drag(event.position)
	accept_event()


func begin(point: Vector2, pointer := -1) -> void:
	if _tween != null or themes.size() < 2 or _dragging:
		return
	_dragging = true
	_pointer = pointer
	_start = point
	_offset = Vector2.ZERO
	_velocity = 0.0
	_last_time = Time.get_ticks_usec()


func drag_by(delta: Vector2) -> void:
	drag(_start + Vector2(_offset.x, _offset.y / 0.35) + delta)


func drag(point: Vector2) -> void:
	if not _dragging:
		return
	var now := Time.get_ticks_usec()
	var offset := point - _start
	_velocity = (offset.x - _offset.x) / maxf(0.001, float(now - _last_time) / 1000000.0)
	_last_time = now
	_pose(Vector2(offset.x, offset.y * 0.35))


func end() -> void:
	if not _dragging:
		return
	_dragging = false
	_pointer = -2
	if float(Time.get_ticks_usec() - _last_time) / 1000000.0 > 0.12:
		_velocity = 0.0
	var commit := (
		absf(_offset.x) > size.x * 0.22
		or (absf(_velocity) > size.x * 2.2 and absf(_offset.x) > size.x * 0.025)
	)
	if commit:
		_dismiss(signf(_offset.x))
	else:
		_animate_to(Vector2.ZERO, 0.18, func() -> void: pass)


func _dismiss(direction: float) -> void:
	var previous := index
	var target := Vector2(direction * size.x * 1.45, size.y * 0.42)
	_animate_to(
		target,
		0.28,
		func() -> void:
			history.append({"index": previous, "direction": direction})
			index = posmod(index + 1, themes.size())
			_refresh()
			selected.emit(index),
		true
	)


func undo() -> void:
	if history.is_empty() or _tween != null or _dragging:
		return
	var previous: Dictionary = history.pop_back()
	index = int(previous.index)
	_refresh()
	_pose(Vector2(float(previous.direction) * size.x * 1.45, size.y * 0.42))
	selected.emit(index)
	_animate_to(Vector2.ZERO, 0.32, func() -> void: pass)


func _animate_to(target: Vector2, duration: float, done: Callable, falling := false) -> void:
	_tween = create_tween()
	if reduced_motion:
		_tween.tween_property(_cards[0], "modulate:a", 0.4, 0.08)
	else:
		_tween.set_trans(Tween.TRANS_QUAD if falling else Tween.TRANS_CUBIC)
		_tween.set_ease(Tween.EASE_IN if falling else Tween.EASE_OUT)
		_tween.tween_method(_pose, _offset, target, duration)
	_tween.finished.connect(
		func() -> void:
			_tween = null
			_pose(Vector2.ZERO)
			done.call()
	)


func cancel() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_dragging = false
	_pointer = -2
	_pose(Vector2.ZERO)


func _resize() -> void:
	cancel()
	_refresh()


func active_motion_count() -> int:
	return int(_tween != null)


func source_rect() -> Rect2:
	return _cards[0].get_global_rect()
