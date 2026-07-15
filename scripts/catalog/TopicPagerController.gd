extends RefCounted
class_name TopicPagerController

const PAGE_SIZE := 4
const TAP_THRESHOLD := 12.0
const SNAP_DURATION := 0.24

var game: Node
var track: Control
var page_builder: Callable
var indicator_thumb: Control
var page_count := 0
var page_width := 1.0
var current_page := 0
var rendered_pages: Dictionary = {}
var drag_active := false
var drag_total := Vector2.ZERO
var drag_velocity_x := 0.0
var drag_last_usec := 0
var interrupted_snap := false
var snap_tween: Tween


func _init(owner: Node) -> void:
	game = owner


func configure(
	next_track: Control,
	item_count: int,
	next_page_width: float,
	next_page_builder: Callable,
	next_indicator_thumb: Control = null,
) -> void:
	reset()
	track = next_track
	page_builder = next_page_builder
	indicator_thumb = next_indicator_thumb
	page_width = maxf(1.0, next_page_width)
	page_count = ceili(float(item_count) / float(PAGE_SIZE))
	current_page = 0
	_ensure_render_window(0)
	_set_track_x(0.0)


func reset() -> void:
	_kill_snap()
	drag_active = false
	drag_total = Vector2.ZERO
	drag_velocity_x = 0.0
	drag_last_usec = 0
	interrupted_snap = false
	rendered_pages.clear()
	track = null
	page_builder = Callable()
	indicator_thumb = null
	page_count = 0
	page_width = 1.0
	current_page = 0
	if game != null:
		game.topics_drag_active = false


func handle_gui_input(event: InputEvent) -> void:
	if game.current_screen != "topics" or track == null or page_count <= 0:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				begin_drag(mouse_event.position)
			else:
				end_drag(mouse_event.position)
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			go_to_page(current_page - 1)
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			go_to_page(current_page + 1)
	elif event is InputEventMouseMotion and drag_active:
		var motion := event as InputEventMouseMotion
		drag_by(motion.relative)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			begin_drag(touch.position)
		else:
			end_drag(touch.position)
	elif event is InputEventScreenDrag and drag_active:
		var screen_drag := event as InputEventScreenDrag
		drag_by(screen_drag.relative)


func begin_drag(_screen_position: Vector2) -> void:
	if track == null or page_count <= 0:
		return
	interrupted_snap = snap_tween != null and snap_tween.is_valid()
	_kill_snap()
	drag_active = true
	drag_total = Vector2.ZERO
	drag_velocity_x = 0.0
	drag_last_usec = Time.get_ticks_usec()
	game.topics_drag_active = true
	game.topics_drag_total = Vector2.ZERO


func drag_by(delta: Vector2, elapsed_override := -1.0) -> void:
	if not drag_active or track == null:
		return
	var now := Time.get_ticks_usec()
	var elapsed: float = elapsed_override
	if elapsed <= 0.0:
		elapsed = maxf(0.001, float(now - drag_last_usec) / 1000000.0)
	drag_last_usec = now
	drag_total += delta
	game.topics_drag_total = drag_total
	var instant_velocity := delta.x / elapsed
	drag_velocity_x = lerpf(drag_velocity_x, instant_velocity, 0.45)
	_set_track_x(_drag_constrained_x(track.position.x + delta.x))


func end_drag(screen_position: Vector2) -> void:
	if not drag_active or track == null:
		return
	drag_active = false
	game.topics_drag_active = false
	var page_position := visual_page_position()
	var nearest_page := clampi(roundi(page_position), 0, maxi(0, page_count - 1))
	var settled := absf(page_position - float(nearest_page)) <= 0.015
	if drag_total.length() <= TAP_THRESHOLD * game._topics_ui_scale() and settled and not interrupted_snap:
		current_page = nearest_page
		_activate_item_at(screen_position)
		return
	var target_page := nearest_page
	var fling_threshold := page_width * 0.85
	if drag_velocity_x <= -fling_threshold:
		target_page = floori(page_position) + 1
	elif drag_velocity_x >= fling_threshold:
		target_page = ceili(page_position) - 1
	go_to_page(clampi(target_page, 0, maxi(0, page_count - 1)))


func go_to_page(target_page: int, animated := true) -> void:
	if track == null or page_count <= 0:
		return
	target_page = clampi(target_page, 0, page_count - 1)
	_kill_snap()
	var start_x := track.position.x
	var end_x := -float(target_page) * page_width
	if not animated or game._ui_motion_reduced() or is_equal_approx(start_x, end_x):
		_set_track_x(end_x)
		_complete_snap(target_page)
		return
	_ensure_render_window(clampi(roundi(visual_page_position()), 0, page_count - 1))
	snap_tween = game.create_tween()
	snap_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	snap_tween.tween_method(_set_track_x, start_x, end_x, SNAP_DURATION)
	snap_tween.finished.connect(func() -> void: _complete_snap(target_page))


func visual_page_position() -> float:
	if track == null or page_width <= 0.0:
		return float(current_page)
	return clampf(-track.position.x / page_width, 0.0, float(maxi(0, page_count - 1)))


func debug_state() -> Dictionary:
	var indices: Array = rendered_pages.keys()
	indices.sort()
	return {
		"page_count": page_count,
		"current_page": current_page,
		"visual_page": visual_page_position(),
		"rendered_pages": indices,
		"rendered_page_count": indices.size(),
		"rendered_card_count": _rendered_card_count(),
		"drag_active": drag_active,
		"track_x": track.position.x if track != null else 0.0,
	}


func _drag_constrained_x(raw_x: float) -> float:
	var min_x := -float(maxi(0, page_count - 1)) * page_width
	if raw_x > 0.0:
		return _rubber_band(raw_x)
	if raw_x < min_x:
		return min_x - _rubber_band(min_x - raw_x)
	return raw_x


func _rubber_band(distance: float) -> float:
	var limit := page_width * 0.55
	return distance * 0.32 / (1.0 + distance / maxf(1.0, limit))


func _set_track_x(next_x: float) -> void:
	if track == null or not is_instance_valid(track):
		return
	track.position.x = next_x
	var center_page := clampi(roundi(visual_page_position()), 0, maxi(0, page_count - 1))
	_ensure_render_window(center_page)
	_update_indicator()


func _complete_snap(target_page: int) -> void:
	current_page = clampi(target_page, 0, maxi(0, page_count - 1))
	snap_tween = null
	drag_velocity_x = 0.0
	drag_total = Vector2.ZERO
	interrupted_snap = false
	if track != null:
		track.position.x = -float(current_page) * page_width
	_ensure_render_window(current_page)
	_update_indicator()


func _ensure_render_window(center_page: int) -> void:
	if track == null or not page_builder.is_valid() or page_count <= 0:
		return
	var required: Dictionary = {}
	for page_index in range(maxi(0, center_page - 1), mini(page_count - 1, center_page + 1) + 1):
		required[page_index] = true
	for page_index in rendered_pages.keys():
		if required.has(page_index):
			continue
		var old_page: Control = rendered_pages[page_index]
		rendered_pages.erase(page_index)
		if is_instance_valid(old_page):
			if old_page.get_parent() == track:
				track.remove_child(old_page)
			old_page.queue_free()
	for page_index in required.keys():
		if rendered_pages.has(page_index):
			continue
		var built = page_builder.call(page_index)
		if not built is Control:
			continue
		var page := built as Control
		page.position = Vector2(float(page_index) * page_width, 0.0)
		track.add_child(page)
		rendered_pages[page_index] = page


func _activate_item_at(screen_position: Vector2) -> void:
	if track == null:
		return
	var content_position := screen_position - track.position
	for item in game.topics_island_items:
		var rect: Rect2 = item.get("rect", Rect2())
		if not rect.has_point(content_position):
			continue
		var action = item.get("action", null)
		if action is Callable and action.is_valid():
			action.call()
		return


func _update_indicator() -> void:
	if indicator_thumb == null or not is_instance_valid(indicator_thumb):
		return
	var parent := indicator_thumb.get_parent_control()
	if parent == null:
		return
	var travel := maxf(0.0, parent.size.x - indicator_thumb.size.x)
	var progress := 0.0 if page_count <= 1 else visual_page_position() / float(page_count - 1)
	indicator_thumb.position.x = travel * clampf(progress, 0.0, 1.0)


func _rendered_card_count() -> int:
	var count := 0
	for page in rendered_pages.values():
		if page is Control and is_instance_valid(page):
			count += (page as Control).get_child_count()
	return count


func _kill_snap() -> void:
	if snap_tween != null and snap_tween.is_valid():
		snap_tween.kill()
	snap_tween = null
