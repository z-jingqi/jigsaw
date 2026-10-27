extends Node
## Left-edge input ownership and reversible release motion, independent of routes.

const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const Arena := preload("res://scripts/ui/navigation/GestureArena.gd")
const Visual := preload("res://scripts/navigation/EdgeBackVisual.gd")
var navigator: AppNavigator
var commit_back: Callable
var _last_commit_time := -1000
var _session: RefCounted
var _pointer := -2
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _last_time := 0
var _velocity := 0.0
var _locked := false
var _base_offset := 0.0
var _release: Tween


func _ready() -> void:
	get_tree().quit_on_go_back = false
	add_to_group("runtime_edge_back")
	get_viewport().size_changed.connect(cancel)
	navigator.route_changed.connect(_route_changed)


func _route_changed(_route: StringName, _payload: Dictionary) -> void:
	if _session != null and _session.source != navigator.current_route_view():
		cancel()


func _exit_tree() -> void:
	cancel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if Time.get_ticks_msec() - _last_commit_time < 400:
			return
		cancel()
		_system_back()
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		cancel()


func can_start_edge(point: Vector2, _canvas_units_per_native_pixel: float) -> bool:
	return (
		is_instance_valid(navigator)
		and not navigator.edge_back_context().is_empty()
		and (
			_session != null
			or (
				point.x >= 0.0
				and (
					point.x
					<= Metrics.BACK_EDGE * Metrics.unit(get_viewport().get_visible_rect().size)
				)
			)
		)
	)


func snapshot() -> Dictionary:
	return {
		"pointer": _pointer,
		"locked": _locked,
		"offset": _session.offset() if _session != null else 0.0,
		"source_id":
		(
			_session.source.get_instance_id()
			if _session != null and is_instance_valid(_session.source)
			else 0
		),
		"phase": "release" if _release != null else ("held" if _pointer != -2 else "idle"),
	}


func handle_input(event: InputEvent) -> bool:
	# Touch-to-mouse emulation is the same physical pointer, not a second finger.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return _session != null
	var point := Vector2.ZERO
	var pointer := -1
	var down := false
	var up := false
	var moved := false
	if event is InputEventScreenTouch:
		point = event.position
		pointer = event.index
		down = event.pressed
		up = not down
		if event.canceled:
			if pointer == _pointer:
				cancel()
				return true
			return _pointer != -2
	elif event is InputEventScreenDrag:
		point = event.position
		pointer = event.index
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
		down = event.pressed
		up = not down
	elif event is InputEventMouseMotion:
		point = event.position
		moved = true
	else:
		return false
	if down:
		if _pointer != -2:
			# A second finger cannot cancel or take over the held primary.
			return true
		if not can_start_edge(point, _native_scale()):
			return false
		if not Arena.reserve(self, pointer):
			return false
		# Re-grab a settling page anywhere: preserve its visible pose and make
		# this pointer its new drag origin, rather than snapping to a button.
		_stop_release()
		if _session == null:
			var context := navigator.edge_back_context()
			_session = Visual.new()
			if not _session.begin(context.source, context.previous, context.transition):
				_session = null
				Arena.release(self)
				return false
		_base_offset = _session.offset()
		_pointer = pointer
		_start = point
		_last = point
		_last_time = Time.get_ticks_msec()
		_velocity = 0.0
		_locked = _base_offset > 0.0
		return true
	if _pointer == -2:
		return false
	if pointer != _pointer:
		return true
	if moved:
		var delta := point - _start
		if not _locked:
			if absf(delta.y) * _native_scale() >= 10.0 and absf(delta.y) > absf(delta.x):
				cancel()
				return true
			_locked = delta.x * _native_scale() >= 10.0 and delta.x > absf(delta.y) * 1.2
		var now := Time.get_ticks_msec()
		_velocity = (point.x - _last.x) * _native_scale() / maxf(0.001, (now - _last_time) / 1000.0)
		_last = point
		_last_time = now
		if _locked:
			_session.apply_offset(clampf(_base_offset + delta.x, 0.0, _width()))
		return true
	if up:
		var dx: float = _session.offset()
		var recent := Time.get_ticks_msec() - _last_time < 120
		var accepted := (
			_locked
			and dx > 0.0
			and (
				dx >= _width() * 0.30
				or (dx * _native_scale() >= 50.0 and recent and _velocity > 700.0)
			)
		)
		_pointer = -2
		Arena.release(self)
		_animate_release(accepted)
		return true
	return false


func cancel() -> void:
	_stop_release()
	_pointer = -2
	if _session != null:
		_session.restore()
		_session = null
	Arena.release(self)


func _animate_release(accepted: bool) -> void:
	_stop_release()
	var target := _width() if accepted else 0.0
	var reduced: bool = navigator.debug_state_snapshot().get("reduced_motion", false)
	if reduced:
		_session.apply_offset(target)
		_finish_release(accepted)
		return
	_release = create_tween()
	_release.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var duration := clampf(absf(target - _session.offset()) / _width() * 0.24, 0.06, 0.24)
	_release.tween_method(_session.apply_offset, _session.offset(), target, duration)
	_release.finished.connect(_finish_release.bind(accepted))


func _finish_release(accepted: bool) -> void:
	_release = null
	if _session == null:
		return
	if accepted:
		# Same call stack: restore bookkeeping, resolve prior entry, run semantic
		# Back, finish its visual transition before another frame can expose it.
		_session.restore(false)
		_session = null
		navigator.finish_active_transition()
		_last_commit_time = Time.get_ticks_msec()
		commit_back.call()
		navigator.finish_active_transition()
	else:
		_session.restore()
		_session = null
	Arena.release(self)


func _stop_release() -> void:
	if _release != null:
		_release.kill()
		_release = null


func _width() -> float:
	return maxf(1.0, get_viewport().get_visible_rect().size.x)


func _native_scale() -> float:
	return maxf(0.001, get_viewport().get_screen_transform().get_scale().x)


func _system_back() -> void:
	if not is_instance_valid(navigator) or navigator.is_input_locked():
		return
	var view := navigator.current_route_view()
	if view is SettingsModal:
		view.request_close()
		return
	if view != null and view.has_method("request_back"):
		view.request_back()
		return
	var screen := navigator.current_screen_view()
	if screen != null and screen.has_method("dismiss_menu") and screen.dismiss_menu():
		return
	# The sheet owns its native Back notification; the root has no previous page.
	if navigator.current_route() in [&"home", &"themes"]:
		return
	commit_back.call()
