extends RefCounted
class_name LevelPagerController

const SNAP_DURATION := 0.28
const RETURN_DURATION := 0.20
const DISTANCE_THRESHOLD := 0.18
const VELOCITY_THRESHOLD := 760.0

var game: Node
var viewport: Control
var track: Control
var indicator_thumb: Control
var page_builder: Callable
var page_changed: Callable
var page_tapped: Callable
var pages: Dictionary = {}
var page_count := 0
var current_page := 0
var page_width := 1.0
var drag_active := false
var drag_distance := 0.0
var drag_velocity := 0.0
var drag_last_msec := 0
var tween: Tween
var input_locked := false


func _init(owner: Node) -> void:
	game = owner


func configure(next_viewport: Control, next_track: Control, count: int, initial_page: int, builder: Callable, thumb: Control, changed := Callable(), tapped := Callable()) -> void:
	reset()
	viewport = next_viewport
	track = next_track
	page_count = maxi(0, count)
	current_page = clampi(initial_page, 0, maxi(0, page_count - 1))
	page_width = maxf(1.0, viewport.size.x)
	page_builder = builder
	indicator_thumb = thumb
	page_changed = changed
	page_tapped = tapped
	_rebuild()


func reset() -> void:
	_cancel_tween()
	drag_active = false
	drag_distance = 0.0
	drag_velocity = 0.0
	for page in pages.values():
		if page is Control and is_instance_valid(page):
			(page as Control).queue_free()
	pages.clear()
	viewport = null
	track = null
	indicator_thumb = null
	page_builder = Callable()
	page_changed = Callable()
	page_tapped = Callable()
	page_count = 0
	current_page = 0
	page_width = 1.0
	input_locked = false


func handle_input(event: InputEvent) -> void:
	if input_locked or page_count <= 1:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
		return
	if event is InputEventScreenDrag:
		_drag_by(event.relative.x)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
		return
	if event is InputEventMouseMotion and drag_active and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag_by(event.relative.x)


func go_to(target_page: int, animated := true) -> void:
	if page_count <= 0 or input_locked:
		return
	target_page = clampi(target_page, 0, page_count - 1)
	if target_page == current_page:
		_snap_back(animated)
		return
	if not animated or game._ui_motion_reduced() or absi(target_page - current_page) > 1:
		current_page = target_page
		_rebuild()
		_notify_changed()
		return
	_settle(1 if target_page > current_page else -1)


func set_locked(value: bool) -> void:
	input_locked = value
	if value:
		drag_active = false


func debug_state() -> Dictionary:
	return {
		"page_count": page_count,
		"current_page": current_page,
		"rendered_page_count": pages.size(),
		"drag_active": drag_active,
		"input_locked": input_locked,
		"visual_page": _visual_page(),
	}


func _begin_drag(_position: Vector2) -> void:
	_cancel_tween()
	drag_active = true
	drag_distance = 0.0
	drag_velocity = 0.0
	drag_last_msec = Time.get_ticks_msec()


func _drag_by(delta_x: float) -> void:
	if not drag_active or track == null:
		return
	var now := Time.get_ticks_msec()
	var elapsed := maxf(0.001, float(now - drag_last_msec) / 1000.0)
	drag_last_msec = now
	drag_distance += delta_x
	drag_velocity = delta_x / elapsed
	var next_x := track.position.x + delta_x
	var min_x := -page_width * 2.0 if current_page < page_count - 1 else -page_width
	var max_x := 0.0 if current_page > 0 else -page_width
	if next_x < min_x:
		next_x = min_x - _rubber(min_x - next_x)
	elif next_x > max_x:
		next_x = max_x + _rubber(next_x - max_x)
	_set_track_x(next_x)


func _end_drag(position: Vector2) -> void:
	if not drag_active:
		return
	drag_active = false
	if absf(drag_distance) <= 8.0 and page_tapped.is_valid():
		page_tapped.call(position, current_page)
		_snap_back(false)
		return
	var direction := 0
	if absf(drag_distance) >= page_width * DISTANCE_THRESHOLD or absf(drag_velocity) >= VELOCITY_THRESHOLD:
		direction = 1 if drag_distance < 0.0 else -1
	if direction > 0 and current_page >= page_count - 1:
		direction = 0
	if direction < 0 and current_page <= 0:
		direction = 0
	if direction == 0:
		_snap_back(true)
	else:
		_settle(direction)


func _settle(direction: int) -> void:
	if track == null:
		return
	_cancel_tween()
	input_locked = true
	var target_x := -page_width - float(direction) * page_width
	if game._ui_motion_reduced():
		_finish_settle(direction)
		return
	tween = game.create_tween()
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_track_x, track.position.x, target_x, SNAP_DURATION)
	tween.finished.connect(func() -> void: _finish_settle(direction))


func _finish_settle(direction: int) -> void:
	tween = null
	current_page = clampi(current_page + direction, 0, page_count - 1)
	input_locked = false
	_rebuild()
	_notify_changed()


func _snap_back(animated: bool) -> void:
	if track == null:
		return
	_cancel_tween()
	if not animated or game._ui_motion_reduced():
		_set_track_x(-page_width)
		return
	input_locked = true
	tween = game.create_tween()
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_track_x, track.position.x, -page_width, RETURN_DURATION)
	tween.finished.connect(func() -> void:
		tween = null
		input_locked = false
	)


func _rebuild() -> void:
	if track == null or not page_builder.is_valid() or page_count <= 0:
		return
	for page in pages.values():
		if page is Control and is_instance_valid(page):
			(page as Control).queue_free()
	pages.clear()
	for offset in [-1, 0, 1]:
		var logical: int = current_page + int(offset)
		if logical < 0 or logical >= page_count:
			continue
		var built = page_builder.call(logical)
		if not built is Control:
			continue
		var page := built as Control
		page.position = Vector2(float(offset + 1) * page_width, 0.0)
		track.add_child(page)
		pages[offset] = page
	track.position.x = -page_width
	_update_indicator()


func _set_track_x(value: float) -> void:
	if track == null:
		return
	track.position.x = value
	_update_indicator()


func _update_indicator() -> void:
	if indicator_thumb == null or not is_instance_valid(indicator_thumb):
		return
	var parent := indicator_thumb.get_parent_control()
	if parent == null:
		return
	var travel := maxf(0.0, parent.size.x - indicator_thumb.size.x)
	var progress := 0.0 if page_count <= 1 else clampf(_visual_page() / float(page_count - 1), 0.0, 1.0)
	indicator_thumb.position.x = travel * progress


func _visual_page() -> float:
	if track == null:
		return float(current_page)
	return float(current_page) - (track.position.x + page_width) / page_width


func _notify_changed() -> void:
	if page_changed.is_valid():
		page_changed.call(current_page)


func _rubber(distance: float) -> float:
	return distance * 0.22 / (1.0 + distance / maxf(1.0, page_width * 0.35))


func _cancel_tween() -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	tween = null
	input_locked = false
