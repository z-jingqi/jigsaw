extends Control
## A bounded image window. Input owns the current offset, never a queued animation.
signal selected(index: int)
signal activated(index: int)
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Gesture := preload("res://scripts/ui/navigation/PagingGesture.gd")
const Arena := preload("res://scripts/ui/navigation/GestureArena.gd")
var thumbnail_mode := false
var items: Array = []
var current := 0
var visual := 0.0
var strip_offset := 0.0
var _strip_target := 0.0
var enabled := true
var reduced := false
var _loader: Node
var _slots: Array[TextureRect] = []
var _indices: Array[int] = []
var _gesture := Gesture.new()
var _pointer := -2
var _motion: Tween
var _generation := 0


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = MOUSE_FILTER_IGNORE
	for index in 7 if thumbnail_mode else 3:
		var slot := TextureRect.new()
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(slot)
		_slots.append(slot)
		_indices.append(-1)
	resized.connect(_resize)


func set_loader(loader: Node) -> void:
	_loader = loader
	_indices.fill(-1)
	_refresh()


func configure(data: Array, index: int) -> void:
	_generation += 1
	_stop()
	_cancel_pointer()
	items = data
	current = clampi(index, 0, maxi(0, items.size() - 1))
	visual = current
	strip_offset = _target_strip_offset()
	_indices.fill(-1)
	_refresh()


func request(index: int, notify := true) -> void:
	if items.is_empty():
		return
	_stop()
	_cancel_pointer()
	current = clampi(index, 0, items.size() - 1)
	if notify:
		selected.emit(current)
	if thumbnail_mode:
		_animate_strip(_target_strip_offset())
		return
	if reduced or is_equal_approx(visual, float(current)):
		_apply(float(current))
		return
	_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_method(
		_apply, visual, float(current), clampf(absf(visual - current) * 0.24, 0.08, 0.36)
	)
	_motion.finished.connect(func() -> void: _motion = null)


func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		_stop()
		_cancel_pointer()
		if is_instance_valid(_loader):
			_loader.unwatch_owner(self)
	else:
		_indices.fill(-1)
		_refresh()
		if thumbnail_mode:
			_animate_strip(clampf(strip_offset, 0, _max_strip_offset()))
		else:
			request(current, false)


func _step() -> float:
	return maxf(1, size.x / 4.4 if thumbnail_mode else size.x)


func _apply(value: float) -> void:
	visual = value
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var middle := clampi(roundi(visual), 0, maxi(0, items.size() - 1))
	var first := floori(strip_offset) - 1 if thumbnail_mode else middle - 1
	for slot_index in _slots.size():
		var index := first + slot_index
		var slot := _slots[slot_index]
		slot.visible = index >= 0 and index < items.size()
		if not slot.visible:
			slot.texture = null
			_indices[slot_index] = -1
			if is_instance_valid(_loader):
				_loader.unwatch(self, str(slot_index))
				_loader.unwatch(self, str(slot_index) + "_preview")
			continue
		var gap := (
			10 * Clean.canvas_scale(get_viewport_rect().size, get_window())
			if thumbnail_mode
			else 0.0
		)
		slot.size = Vector2(_step() - gap, size.y - (8 if thumbnail_mode else 0))
		slot.position = Vector2((index - (strip_offset if thumbnail_mode else visual)) * _step(), 0)
		if _indices[slot_index] != index:
			_indices[slot_index] = index
			slot.texture = null
			_load_slot(slot_index, index)
	queue_redraw()


func _load_slot(slot_index: int, index: int) -> void:
	if not is_instance_valid(_loader) or not enabled:
		return
	var item: Dictionary = items[index]
	var path := str(
		item.get("thumbnail_path", "") if thumbnail_mode else item.get("image_path", "")
	)
	if not thumbnail_mode:
		_loader.watch(
			self,
			str(slot_index) + "_preview",
			str(item.get("thumbnail_path", "")),
			_preview_loaded.bind(slot_index, index, _generation),
			"thumb",
			110 if index == current else 10
		)
	_loader.watch(
		self,
		str(slot_index),
		path,
		_loaded.bind(slot_index, index, _generation),
		"thumb" if thumbnail_mode else "full",
		100 if index == current else 20
	)


func _preview_loaded(
	_path: String, texture: Texture2D, slot_index: int, index: int, generation: int
) -> void:
	if (
		generation == _generation
		and enabled
		and _indices[slot_index] == index
		and _slots[slot_index].texture == null
	):
		_slots[slot_index].texture = texture


func _loaded(
	_path: String, texture: Texture2D, slot_index: int, index: int, generation: int
) -> void:
	if generation != _generation or not enabled or _indices[slot_index] != index:
		return
	if texture != null:
		_slots[slot_index].texture = texture


func _draw() -> void:
	if not thumbnail_mode:
		return
	for slot_index in _slots.size():
		if _indices[slot_index] == current:
			var slot := _slots[slot_index]
			draw_line(
				Vector2(slot.position.x, size.y - 2),
				Vector2(slot.position.x + slot.size.x, size.y - 2),
				Clean.INK,
				2,
				true
			)


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if Arena.block_secondary(get_viewport(), event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and has_focus():
		if event.keycode in [KEY_LEFT, KEY_RIGHT]:
			request(current + (-1 if event.keycode == KEY_LEFT else 1))
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and not thumbnail_mode:
			activated.emit(current)
			get_viewport().set_input_as_handled()
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(event.position, -1)
		elif _pointer == -1:
			_end(event.position)
	elif event is InputEventMouseMotion and _pointer == -1:
		_move(event.position)
	elif event is InputEventScreenTouch:
		if event.canceled and event.index == _pointer:
			_cancel_pointer()
			if thumbnail_mode:
				_animate_strip(clampf(strip_offset, 0, _max_strip_offset()))
			else:
				request(_gesture.origin_page)
		elif event.pressed:
			_begin(event.position, event.index)
		elif event.index == _pointer:
			_end(event.position)
	elif event is InputEventScreenDrag and event.index == _pointer:
		_move(event.position)


func _begin(point: Vector2, pointer: int) -> void:
	if _pointer != -2 or items.is_empty() or not get_global_rect().has_point(point):
		return
	var native := Clean.canvas_scale(get_viewport_rect().size, get_window())
	if Arena.is_edge_candidate(self, point, native) or not Arena.reserve(self, pointer):
		return
	_stop()
	_pointer = pointer
	_gesture.begin(point, strip_offset if thumbnail_mode else visual, _step(), native, items.size())


func _move(point: Vector2) -> void:
	if not Arena.owns(self, _pointer):
		return
	var value: float = _gesture.move(point)
	if _gesture.axis == 1:
		if thumbnail_mode:
			var raw: float = _gesture.origin - _gesture.delta.x / _step()
			var upper := _max_strip_offset()
			if raw < 0:
				raw = -0.15 * (1.0 - exp(raw / 0.15))
			elif raw > upper:
				raw = upper + 0.15 * (1.0 - exp(-(raw - upper) / 0.15))
			_apply_strip(raw)
		else:
			_apply(value)
	if _gesture.axis != 0:
		get_viewport().set_input_as_handled()


func _end(point: Vector2) -> void:
	var target: int = _gesture.release_target(point)
	var axis: int = _gesture.axis

	_cancel_pointer()
	get_viewport().set_input_as_handled()
	if thumbnail_mode and axis != 0:
		_animate_strip(clampf(strip_offset, 0, _max_strip_offset()))
		return
	if axis == 0:
		var local := get_global_transform().affine_inverse() * point
		for slot_index in _slots.size():
			if _indices[slot_index] >= 0 and _slots[slot_index].get_rect().has_point(local):
				target = _indices[slot_index]
				request(target)
				if not thumbnail_mode:
					activated.emit(target)
				return
	request(target)


func _stop() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func _cancel_pointer() -> void:
	Arena.release(self)
	_pointer = -2


func _resize() -> void:
	if _pointer != -2:
		_cancel_pointer()
		request(current, false)
	_refresh()


func active_motion_count() -> int:
	return int(_motion != null and _motion.is_valid() and _motion.is_running())


func debug_state_snapshot() -> Dictionary:
	var live_bytes := 0
	for slot in _slots:
		if slot.texture != null:
			live_bytes += slot.texture.get_width() * slot.texture.get_height() * 4
	return {
		"index": current,
		"visual": visual,
		"strip_offset": strip_offset,
		"slots": _slots.size(),
		"live_texture_bytes_upper_bound": live_bytes,
		"pointer": _pointer,
		"loaded": _slots.filter(func(s): return s.texture != null).size()
	}


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if _pointer != -2:
			_cancel_pointer()
			if thumbnail_mode:
				_animate_strip(clampf(strip_offset, 0, _max_strip_offset()))
			else:
				request(_gesture.origin_page, false)


func _exit_tree() -> void:
	_stop()
	_cancel_pointer()
	if is_instance_valid(_loader):
		_loader.unwatch_owner(self)


func _max_strip_offset() -> float:
	return maxf(0, items.size() - 4.4)


func _target_strip_offset() -> float:
	return clampf(float(current) - 1.7, 0, _max_strip_offset())


func _apply_strip(value: float) -> void:
	strip_offset = value
	_refresh()


func _animate_strip(target: float) -> void:
	_strip_target = target
	_stop()
	if reduced or is_equal_approx(strip_offset, target):
		_apply_strip(target)
		return
	_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_method(
		_apply_strip, strip_offset, target, clampf(absf(strip_offset - target) * 0.18, 0.08, 0.3)
	)
	_motion.finished.connect(func() -> void: _motion = null)


func set_reduced_motion(value: bool) -> void:
	reduced = value
	if value and _pointer == -2 and active_motion_count() > 0:
		_stop()
		if thumbnail_mode:
			_apply_strip(_strip_target)
		else:
			_apply(float(current))


func gesture_pause_motion() -> void:
	set_meta("album_paused_motion", active_motion_count() > 0)
	_stop()


func gesture_resume_motion() -> void:
	if not bool(get_meta("album_paused_motion", false)):
		return
	set_meta("album_paused_motion", false)
	if thumbnail_mode:
		_animate_strip(_strip_target)
	else:
		request(current, false)


func prepare_cached(index: int) -> void:
	# A retained previous view may be exposed by interactive Back. Synchronize it
	# using resources already held by the viewer/cache, never enqueue hidden IO.
	_stop()
	current = clampi(index, 0, maxi(0, items.size() - 1))
	visual = current
	strip_offset = _target_strip_offset()
	var previous_enabled := enabled
	enabled = false
	_indices.fill(-1)
	_refresh()
	if is_instance_valid(_loader):
		for slot_index in _slots.size():
			var item_index := _indices[slot_index]
			if item_index < 0:
				continue
			var item: Dictionary = items[item_index]
			var texture: Texture2D
			if not thumbnail_mode:
				texture = _loader.get_cached(str(item.get("image_path", "")))
			if texture == null:
				texture = _loader.get_cached(str(item.get("thumbnail_path", "")))
			_slots[slot_index].texture = texture
	enabled = previous_enabled
