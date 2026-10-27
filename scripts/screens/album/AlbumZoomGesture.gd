extends Node
## Viewer-only ownership: edge-back wins; zoomed drags pan, never page.
signal changed
signal index_requested(index: int)

const Arena := preload("res://scripts/ui/navigation/GestureArena.gd")
const Paging := preload("res://scripts/ui/navigation/PagingGesture.gd")
var zoom := 1.0
var pan := Vector2.ZERO
var page_offset := 0.0
var index := 0
var total := 0
var enabled := true
var reduced_motion := false
var area := Rect2()
var image_size := Vector2.ZERO
var image_center := Vector2.ZERO
var excluded := Rect2()
var native := 1.0
var _points: Dictionary = {}
var _kind := ""
var _paging := Paging.new()
var _settle: Tween
var _pinch_distance := 1.0
var _pinch_center := Vector2.ZERO


func configure(rect: Rect2, dimensions: Vector2, current: int, count: int, scale: float) -> void:
	area = rect
	image_size = dimensions
	index = current
	total = count
	native = maxf(scale, 0.001)
	_clamp_pan()


func gesture_accepts_secondary(pointer: int, event: InputEvent) -> bool:
	if not enabled or pointer < 0 or _points.is_empty() or _points.has(-1):
		return false
	if _points.has(pointer):
		return event is InputEventScreenTouch or event is InputEventScreenDrag
	if _kind == "page" and (_paging.axis != 0 or not is_zero_approx(page_offset)):
		return false
	return (
		event is InputEventScreenTouch
		and event.pressed
		and not event.canceled
		and _points.size() == 1
		and area.has_point(event.position)
		and not excluded.has_point(event.position)
	)


func _input(event: InputEvent) -> void:
	if not enabled or not is_inside_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_begin(event.index, event.position)
		else:
			_end(event.index, event.position, event.canceled)
	elif event is InputEventScreenDrag:
		_move(event.index, event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin(-1, event.position)
			else:
				_end(-1, event.position, false)
		elif (
			event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
		):
			if _points.is_empty() and area.has_point(event.position) and Arena.reserve(self, -1):
				_zoom_at(
					1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2,
					event.position,
					event.position
				)
				Arena.release(self)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_move(-1, event.position)


func _begin(pointer: int, point: Vector2) -> void:
	if _points.has(pointer) or not area.has_point(point) or excluded.has_point(point):
		return
	if not _points.is_empty():
		if pointer < 0 or _points.has(-1) or _points.size() >= 2:
			return
		if _kind == "page" and (_paging.axis != 0 or not is_zero_approx(page_offset)):
			return
		_points[pointer] = point
		_kind = "pinch"
		page_offset = 0.0
		var pair := _points.values()
		_pinch_distance = maxf(1, pair[0].distance_to(pair[1]))
		_pinch_center = (pair[0] + pair[1]) * 0.5
		changed.emit()
	else:
		if Arena.is_edge_candidate(self, point, native) or not Arena.reserve(self, pointer):
			return
		_stop_settle()
		_points[pointer] = point
		_kind = "pan" if zoom > 1.001 else "page"
		_paging.begin(point, index - page_offset / maxf(area.size.x, 1), area.size.x, native, total)
	get_viewport().set_input_as_handled()


func _move(pointer: int, point: Vector2) -> void:
	if not _points.has(pointer):
		return
	var previous: Vector2 = _points[pointer]
	_points[pointer] = point
	if _kind == "pinch" and _points.size() == 2:
		var pair := _points.values()
		var distance: float = maxf(1, pair[0].distance_to(pair[1]))
		var center: Vector2 = (pair[0] + pair[1]) * 0.5
		_zoom_at(distance / _pinch_distance, center, _pinch_center)
		_pinch_distance = distance
		_pinch_center = center
	elif _kind == "pan":
		pan += point - previous
		_clamp_pan()
		changed.emit()
	elif _kind == "page":
		var visual := _paging.move(point)
		if _paging.axis == 1:
			page_offset = (index - visual) * area.size.x
			changed.emit()
	get_viewport().set_input_as_handled()


func _end(pointer: int, point: Vector2, canceled: bool) -> void:
	if not _points.has(pointer):
		return
	_points.erase(pointer)
	get_viewport().set_input_as_handled()
	Arena.release(self)
	if not _points.is_empty():
		Arena.reserve(self, int(_points.keys()[0]))
		_kind = "pan"
		return
	if _kind == "page" and not canceled:
		var target := _paging.release_target(point)
		if target != index:
			page_offset += (target - index) * area.size.x
			index = target
			index_requested.emit(target)
	_kind = ""
	settle()


func _zoom_at(factor: float, center: Vector2, old_center: Vector2) -> void:
	var previous := zoom
	zoom = clampf(zoom * factor, 1.0, 4.0)
	pan = center - image_center - (old_center - image_center - pan) * zoom / previous
	_clamp_pan()
	changed.emit()


func _clamp_pan() -> void:
	var limit := ((image_size * zoom - area.size) * 0.5).max(Vector2.ZERO)
	pan = pan.clamp(-limit, limit)
	if zoom <= 1.001:
		zoom = 1.0
		pan = Vector2.ZERO


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value and _points.is_empty():
		settle()


func settle() -> void:
	_stop_settle()
	if reduced_motion or is_zero_approx(page_offset):
		page_offset = 0.0
		changed.emit()
		return
	_settle = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_settle.tween_method(_set_page_offset, page_offset, 0.0, 0.22)
	_settle.finished.connect(func() -> void: _settle = null)


func _set_page_offset(value: float) -> void:
	page_offset = value
	changed.emit()


func reset() -> void:
	cancel()
	zoom = 1.0
	pan = Vector2.ZERO
	page_offset = 0.0
	changed.emit()


func cancel() -> void:
	_points.clear()
	_kind = ""
	Arena.release(self)
	_stop_settle()


func _stop_settle() -> void:
	if _settle != null and _settle.is_valid():
		_settle.kill()
	_settle = null


func active_motion_count() -> int:
	return int(_settle != null and _settle.is_valid() and _settle.is_running())


func _exit_tree() -> void:
	cancel()
