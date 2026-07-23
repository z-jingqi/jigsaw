extends RefCounted
class_name TopicPagerController

const TopicPagerTransitionScript := preload("res://scripts/catalog/TopicPagerTransition.gd")
const TopicPagerGestureScript := preload("res://scripts/catalog/TopicPagerGesture.gd")
const PAGE_SIZE := 1
const SNAP_DURATION := 0.34

var game: Node
var track: Control
var page_builder: Callable
var indicator_thumb: Control
var page_changed: Callable
var page_count := 0
var page_width := 1.0
var current_page := 0
var rendered_pages: Dictionary = {}
var transitioning := false
var transition_motion
var gesture


func _init(owner: Node) -> void:
	game = owner
	transition_motion = TopicPagerTransitionScript.new(owner)
	gesture = TopicPagerGestureScript.new(owner, self)


func configure(
	next_track: Control,
	item_count: int,
	next_page_width: float,
	next_page_builder: Callable,
	next_indicator_thumb: Control = null,
	initial_page: int = 0,
	next_page_changed: Callable = Callable(),
) -> void:
	reset()
	track = next_track
	page_builder = next_page_builder
	indicator_thumb = next_indicator_thumb
	page_changed = next_page_changed
	page_width = maxf(1.0, next_page_width)
	page_count = maxi(0, item_count)
	current_page = clampi(initial_page, 0, maxi(0, page_count - 1))
	_rebuild_slots()
	_update_indicator()


func reset() -> void:
	cancel_transition()
	gesture.reset()
	transitioning = false
	for page in rendered_pages.values():
		if page is Control and is_instance_valid(page):
			(page as Control).queue_free()
	rendered_pages.clear()
	track = null
	page_builder = Callable()
	indicator_thumb = null
	page_changed = Callable()
	page_count = 0
	page_width = 1.0
	current_page = 0


func handle_gui_input(event: InputEvent) -> void:
	gesture.handle_gui_input(event)


func begin_drag(_screen_position: Vector2) -> void:
	gesture.begin(_screen_position)


func drag_by(delta: Vector2, elapsed_override := -1.0) -> void:
	gesture.drag_by(delta, elapsed_override)


func end_drag(_screen_position: Vector2) -> void:
	gesture.end(_screen_position)


func go_relative(direction: int, animated := true) -> void:
	if page_count <= 1 or transitioning:
		return
	direction = 1 if direction > 0 else -1
	if not animated or game._ui_motion_reduced():
		current_page = posmod(current_page + direction, page_count)
		_notify_page_changed()
		_rebuild_slots()
		return
	settle_relative(direction)


func go_to_page(target_page: int, animated := true) -> void:
	if track == null or page_count <= 0 or transitioning:
		return
	target_page = clampi(target_page, 0, page_count - 1)
	if target_page == current_page:
		snap_back(false)
		return
	if not animated or game._ui_motion_reduced():
		current_page = target_page
		_notify_page_changed()
		_rebuild_slots()
		return
	var forward := posmod(target_page - current_page, page_count)
	var backward := posmod(current_page - target_page, page_count)
	var direction := 1 if forward <= backward else -1
	if mini(forward, backward) == 1:
		settle_relative(direction)
	else:
		_direct_switch(target_page, direction)


func visual_page_position() -> float:
	if track == null or page_width <= 0.0:
		return float(current_page)
	return float(current_page) - (track.position.x + page_width) / page_width


func debug_state() -> Dictionary:
	var logical_pages: Array[int] = []
	for page in rendered_pages.values():
		if page is Control and is_instance_valid(page):
			logical_pages.append(int((page as Control).get_meta("topic_index", -1)))
	logical_pages.sort()
	return {
		"page_count": page_count,
		"current_page": current_page,
		"visual_page": visual_page_position(),
		"rendered_pages": logical_pages,
		"rendered_page_count": rendered_pages.size(),
		"rendered_card_count": rendered_pages.size(),
		"drag_active": gesture.active,
		"transitioning": transitioning,
		"track_x": track.position.x if track != null else 0.0,
	}


func settle_relative(direction: int) -> void:
	if track == null:
		return
	cancel_transition()
	transitioning = true
	var target_x := -page_width - float(direction) * page_width
	if game._ui_motion_reduced():
		_complete_relative(direction)
		return
	transition_motion.slide(track.position.x, target_x, SNAP_DURATION, Callable(self, "set_track_x"), func() -> void: _complete_relative(direction))


func _complete_relative(direction: int) -> void:
	current_page = posmod(current_page + direction, page_count)
	transitioning = false
	gesture.clear_momentum()
	_notify_page_changed()
	_rebuild_slots()


func snap_back(animated := true) -> void:
	if track == null:
		return
	cancel_transition()
	if not animated or game._ui_motion_reduced() or is_equal_approx(track.position.x, -page_width):
		set_track_x(-page_width)
		return
	transitioning = true
	transition_motion.slide(track.position.x, -page_width, 0.22, Callable(self, "set_track_x"), func() -> void:
		transitioning = false
	)


func _direct_switch(target_page: int, direction: int) -> void:
	cancel_transition()
	transitioning = true
	var current: Control = rendered_pages.get(0, null)
	if current == null or game._ui_motion_reduced():
		_complete_direct_switch(target_page, direction)
		return
	transition_motion.fade_out(current, direction, page_width, func() -> void: _complete_direct_switch(target_page, direction))


func _complete_direct_switch(target_page: int, direction: int) -> void:
	current_page = target_page
	_notify_page_changed()
	_rebuild_slots()
	var current: Control = rendered_pages.get(0, null)
	if current == null or game._ui_motion_reduced():
		transitioning = false
		return
	transition_motion.fade_in(current, direction, page_width, func() -> void:
		transitioning = false
	)


func _rebuild_slots() -> void:
	if track == null or not page_builder.is_valid() or page_count <= 0:
		return
	for page in rendered_pages.values():
		if page is Control and is_instance_valid(page):
			(page as Control).queue_free()
	rendered_pages.clear()
	var offsets: Array[int] = []
	if page_count == 1:
		offsets.append(0)
	else:
		offsets.assign([-1, 0, 1])
	for offset in offsets:
		var logical_index := posmod(current_page + offset, page_count)
		var built = page_builder.call(logical_index)
		if not built is Control:
			continue
		var page := built as Control
		page.set_meta("topic_index", logical_index)
		page.position = Vector2(float(offset + 1) * page_width, 0.0)
		track.add_child(page)
		rendered_pages[offset] = page
	track.position.x = -page_width
	_update_indicator()
	game.topic_home_motion.update_page_transition(rendered_pages, 0.0)


func constrained_track_x(raw_x: float) -> float:
	var min_x := -page_width * 2.0
	var max_x := 0.0
	if raw_x > max_x:
		return max_x + _rubber_band(raw_x - max_x)
	if raw_x < min_x:
		return min_x - _rubber_band(min_x - raw_x)
	return raw_x


func _rubber_band(distance: float) -> float:
	return distance * 0.24 / (1.0 + distance / maxf(1.0, page_width * 0.35))


func set_track_x(next_x: float) -> void:
	if track == null or not is_instance_valid(track):
		return
	track.position.x = next_x
	var visual_offset := -(next_x + page_width) / page_width
	game.topic_home_motion.update_page_transition(rendered_pages, visual_offset)
	_update_indicator()


func _update_indicator() -> void:
	if indicator_thumb == null or not is_instance_valid(indicator_thumb):
		return
	var parent := indicator_thumb.get_parent_control()
	if parent == null:
		return
	var travel := maxf(0.0, parent.size.x - indicator_thumb.size.x)
	var visual := clampf(visual_page_position(), 0.0, float(maxi(0, page_count - 1)))
	var progress := 0.0 if page_count <= 1 else visual / float(page_count - 1)
	indicator_thumb.position.x = travel * progress


func _notify_page_changed() -> void:
	_update_indicator()
	if page_changed.is_valid():
		page_changed.call(current_page)


func cancel_transition() -> void:
	transition_motion.cancel()
	transitioning = false


func shutdown() -> void:
	reset()
	if transition_motion != null:
		transition_motion.shutdown()
	if gesture != null:
		gesture.shutdown()
	transition_motion = null
	gesture = null
	game = null
