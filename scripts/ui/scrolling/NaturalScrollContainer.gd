class_name NaturalScrollContainer
extends ScrollContainer

## Shared touch, pointer, wheel, and trackpad scrolling for page-sized lists.

@export_range(1.0, 24.0, 0.5) var intent_distance := 6.0
@export_range(10.0, 1000.0, 5.0) var stop_speed := 45.0
@export_range(100.0, 20000.0, 50.0) var deceleration := 4200.0
@export_range(0.05, 1.0, 0.05) var edge_resistance := 0.34
@export_range(20.0, 600.0, 10.0) var spring_strength := 180.0
@export_range(1.0, 80.0, 1.0) var spring_damping := 22.0
@export_range(0.0, 160.0, 1.0) var maximum_overscroll := 72.0
@export_range(1.0, 160.0, 1.0) var wheel_step := 56.0
@export_range(1.0, 80.0, 1.0) var pan_step := 28.0
@export var navigator_path: NodePath

var _pointer_id := -2
var _pressed := false
var _scrolling := false
var _pending_delta := Vector2.ZERO
var _velocity := 0.0
var _overscroll := 0.0
var _spring_velocity := 0.0
var _last_event_time := 0
var _suppressed_buttons: Dictionary = {}
var _interaction_enabled := true
var _navigation_locked := false
var _visual_update_queued := false


func _ready() -> void:
	# Drag is owned here. Keeping the native threshold unreachable prevents the
	# built-in touch path from applying the same finger delta a second time.
	scroll_deadzone = 1000000
	visibility_changed.connect(_on_visibility_changed)
	var navigator := get_node_or_null(navigator_path) as AppNavigator
	if navigator != null:
		navigator.input_lock_changed.connect(_on_navigation_input_lock_changed)
	set_process_input(true)
	set_physics_process(false)


func _input(event: InputEvent) -> void:
	if not _can_receive_input():
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		if _pressed and event.index == _pointer_id:
			_handle_drag(event.relative)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_mouse_button(event)
		elif event.pressed:
			_handle_wheel(event)
	elif event is InputEventMouseMotion:
		if _pressed and _pointer_id == -1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_handle_drag(event.relative)
	elif event is InputEventPanGesture:
		# macOS supplies a stream that already includes gesture momentum. Apply it
		# once at a fixed scale and do not add our release inertia on top.
		if not get_global_rect().has_point(event.position):
			return
		_velocity = 0.0
		_spring_velocity = 0.0
		_apply_scroll_delta(event.delta.y * pan_step)
		set_physics_process(absf(_overscroll) > 0.5)
		get_viewport().set_input_as_handled()


func stop_motion() -> void:
	_pressed = false
	_scrolling = false
	_pointer_id = -2
	_pending_delta = Vector2.ZERO
	_velocity = 0.0
	_overscroll = 0.0
	_spring_velocity = 0.0
	_apply_visual_offset()
	set_physics_process(false)
	_restore_child_buttons()


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if not enabled:
		stop_motion()


func is_user_scrolling() -> bool:
	return _scrolling


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and get_global_rect().has_point(event.position):
		_begin_pointer(event.index)
	elif _pressed and event.index == _pointer_id:
		_end_pointer()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and get_global_rect().has_point(event.position):
		_begin_pointer(-1)
	elif _pressed and _pointer_id == -1:
		_end_pointer()


func _begin_pointer(pointer_id: int) -> void:
	_pointer_id = pointer_id
	_pressed = true
	_scrolling = false
	_pending_delta = Vector2.ZERO
	_velocity = 0.0
	_spring_velocity = 0.0
	_last_event_time = Time.get_ticks_usec()
	set_physics_process(false)


func _handle_drag(relative: Vector2) -> void:
	_pending_delta += relative
	if not _scrolling:
		if (
			absf(_pending_delta.y) < intent_distance
			or absf(_pending_delta.y) <= absf(_pending_delta.x)
		):
			return
		_scrolling = true
		_suppress_child_buttons()
		relative = _pending_delta
		_pending_delta = Vector2.ZERO
		get_viewport().set_input_as_handled()
	else:
		get_viewport().set_input_as_handled()
	var now := Time.get_ticks_usec()
	var elapsed := clampf(float(now - _last_event_time) / 1000000.0, 0.001, 0.05)
	_last_event_time = now
	var scroll_delta := -relative.y
	var sample_velocity := scroll_delta / elapsed
	_velocity = lerpf(_velocity, sample_velocity, 0.42)
	_apply_scroll_delta(scroll_delta)


func _end_pointer() -> void:
	_pressed = false
	_pointer_id = -2
	_pending_delta = Vector2.ZERO
	if _scrolling:
		# Consume the release after a drag so a card beneath it cannot activate.
		get_viewport().set_input_as_handled()
	if Time.get_ticks_usec() - _last_event_time > 100000:
		_velocity = 0.0
	_scrolling = false
	_spring_velocity = -_velocity
	set_physics_process(absf(_velocity) > stop_speed or absf(_overscroll) > 0.5)
	_restore_child_buttons.call_deferred()


func _physics_process(delta: float) -> void:
	if _pressed:
		return
	if absf(_overscroll) > 0.01:
		var acceleration := -spring_strength * _overscroll - spring_damping * _spring_velocity
		var previous_sign := signf(_overscroll)
		_spring_velocity += acceleration * delta
		_overscroll += _spring_velocity * delta
		if signf(_overscroll) != previous_sign or absf(_overscroll) < 0.5:
			_overscroll = 0.0
			_spring_velocity = 0.0
			_velocity = 0.0
		_apply_visual_offset()
	elif absf(_velocity) > stop_speed:
		_apply_scroll_delta(_velocity * delta)
		_velocity = move_toward(_velocity, 0.0, deceleration * delta)
	else:
		_velocity = 0.0
		set_physics_process(false)


func _apply_scroll_delta(delta: float) -> void:
	var limit := _vertical_limit()
	var target := float(scroll_vertical) + delta
	if target < 0.0:
		scroll_vertical = 0
		_overscroll = clampf(_overscroll + (-target) * edge_resistance, 0.0, maximum_overscroll)
		_velocity *= edge_resistance
	elif target > limit:
		scroll_vertical = int(round(limit))
		_overscroll = clampf(
			_overscroll - (target - limit) * edge_resistance, -maximum_overscroll, 0.0
		)
		_velocity *= edge_resistance
	else:
		scroll_vertical = int(round(target))
		_overscroll = move_toward(_overscroll, 0.0, absf(delta))
	_apply_visual_offset()
	_queue_visual_offset()


func _vertical_limit() -> float:
	var bar := get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


func _apply_visual_offset() -> void:
	if get_child_count() == 0:
		return
	var content := get_child(0) as Control
	if content == null:
		return
	# ScrollContainer normally places its content at -scroll_vertical. A small
	# resisted offset provides the boundary pull and is returned by the spring.
	content.position.y = -float(scroll_vertical) + _overscroll


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		stop_motion()
		_restore_child_buttons()


func _can_receive_input() -> bool:
	if not _interaction_enabled or _navigation_locked or not is_visible_in_tree():
		return false
	var ancestor := get_parent()
	while ancestor is Control:
		var control := ancestor as Control
		if not control.visible:
			return false
		ancestor = ancestor.get_parent()
	return true


func _handle_wheel(event: InputEventMouseButton) -> void:
	var direction := 0.0
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		direction = 1.0
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = -1.0
	if direction == 0.0 or not get_global_rect().has_point(event.position):
		return
	stop_motion()
	_apply_clamped_scroll_delta(direction * wheel_step * maxf(0.1, event.factor))
	get_viewport().set_input_as_handled()


func _apply_clamped_scroll_delta(delta: float) -> void:
	var target := clampf(float(scroll_vertical) + delta, 0.0, _vertical_limit())
	scroll_vertical = int(round(target))
	_overscroll = 0.0
	_apply_visual_offset()


func _queue_visual_offset() -> void:
	if _visual_update_queued:
		return
	_visual_update_queued = true
	_apply_visual_offset_deferred.call_deferred()


func _apply_visual_offset_deferred() -> void:
	_visual_update_queued = false
	_apply_visual_offset()


func _on_navigation_input_lock_changed(is_locked: bool) -> void:
	_navigation_locked = is_locked
	if is_locked:
		stop_motion()


func _suppress_child_buttons() -> void:
	_suppressed_buttons.clear()
	_collect_and_suppress_buttons(self)


func _collect_and_suppress_buttons(parent: Node) -> void:
	for child in parent.get_children():
		if child is BaseButton:
			_suppressed_buttons[child] = child.mouse_filter
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_collect_and_suppress_buttons(child)


func _restore_child_buttons() -> void:
	for candidate in _suppressed_buttons:
		var button := candidate as BaseButton
		if is_instance_valid(button):
			button.mouse_filter = int(_suppressed_buttons[candidate]) as Control.MouseFilter
	_suppressed_buttons.clear()
