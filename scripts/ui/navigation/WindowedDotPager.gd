extends Control
## Selection moves first; the bounded window follows without replacing live poses.
signal page_requested(index: int)

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const MAX_DOTS := 5
const SELECT_DURATION := 0.11
const WINDOW_DURATION := 0.17

var _page_count := 0
var _current_page := 0
var _enabled := true
var _reduced_motion := false
var _preview_active := false
var _visible_count := 0
var _selection_visual := 0.0
var _window_visual := 0.0
var _motion: Tween
var _dots: Array[PageDot] = []
var _band: Control
var _previous: ArrowButton
var _next: ArrowButton


class PageDot:
	extends Button
	var page_index := -1
	var weight := 0.0
	var dot_unit := 1.0

	func _draw() -> void:
		var ink := Color("AFB4A8").lerp(Color("272925"), weight)
		var center := size * 0.5
		var radius := 2.5 * (1.0 - weight) * dot_unit
		var dot_ink := ink
		dot_ink.a = 1.0 - weight
		draw_circle(center, radius, dot_ink, true, -1.0, true)
		if weight > 0.0:
			var paw_ink := ink
			paw_ink.a = weight
			_draw_paw(center, dot_unit * lerpf(0.85, 1.0, weight), paw_ink)
		if has_focus():
			var focus_radius := lerpf(5.5, 10.0, weight) * dot_unit
			draw_arc(center, focus_radius, 0, TAU, 48, ink, dot_unit, true)

	func _draw_paw(center: Vector2, unit: float, ink: Color) -> void:
		# Optical small-size version: retain native-pixel gaps between all five pads.
		_draw_toe(center, Vector2(-5.0, -1.9), -0.35, unit, ink)
		_draw_toe(center, Vector2(-2.1, -4.5), -0.12, unit, ink)
		_draw_toe(center, Vector2(2.1, -4.5), 0.12, unit, ink)
		_draw_toe(center, Vector2(5.0, -1.9), 0.35, unit, ink)
		var pad := PackedVector2Array()
		var anchors := [Vector2(0, 0.8), Vector2(3.6, 4.0), Vector2(0, 4.6), Vector2(-3.6, 4.0)]
		var outgoing := [
			Vector2(1.7, 0.8), Vector2(3.5, 5.8), Vector2(-1.6, 4.6), Vector2(-3.7, 2.2)
		]
		var incoming := [
			Vector2(-1.7, 0.8), Vector2(3.7, 2.2), Vector2(1.6, 4.6), Vector2(-3.5, 5.8)
		]
		for segment in 4:
			var next := (segment + 1) % 4
			for sample in 12:
				var point: Vector2 = anchors[segment].bezier_interpolate(
					outgoing[segment], incoming[next], anchors[next], float(sample) / 12.0
				)
				pad.append(center + point * unit)
		draw_colored_polygon(pad, ink)
		pad.append(pad[0])
		draw_polyline(pad, ink, 0.35 * unit, true)

	func _draw_toe(center: Vector2, offset: Vector2, angle: float, unit: float, ink: Color) -> void:
		draw_set_transform(center + offset * unit, angle, Vector2(1.05, 1.25) * unit)
		draw_circle(Vector2.ZERO, 1.0, ink, true, -1.0, true)
		draw_set_transform(Vector2.ZERO)


class ArrowButton:
	extends Button
	const Chevron := preload("res://scripts/ui/foundation/ChevronGeometry.gd")
	var direction := 1.0
	var unit := 1.0

	func _draw() -> void:
		var angle := 0.0 if direction < 0.0 else PI
		draw_polyline(
			Chevron.points(size * 0.5, 7.0 * unit, angle),
			Color("272925"),
			(2.2 if has_focus() else 1.6) * unit,
			true
		)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band = Control.new()
	_band.name = "DotWindow"
	_band.clip_contents = true
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	for index in MAX_DOTS:
		var dot := PageDot.new()
		dot.name = "Dot%d" % index
		_prepare_button(dot)
		dot.pressed.connect(func() -> void: _request(dot.page_index))
		_band.add_child(dot)
		_dots.append(dot)
	_previous = _make_arrow("Previous", -1.0)
	_next = _make_arrow("Next", 1.0)
	resized.connect(_layout)
	_layout()


func _prepare_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.gui_input.connect(_on_key)
	button.focus_entered.connect(button.queue_redraw)
	button.focus_exited.connect(button.queue_redraw)


func _make_arrow(node_name: String, direction: float) -> ArrowButton:
	var arrow := ArrowButton.new()
	arrow.name = node_name
	arrow.direction = direction
	_prepare_button(arrow)
	arrow.pressed.connect(func() -> void: _request(_current_page + int(direction)))
	add_child(arrow)
	return arrow


func configure(page_count: int, current_page: int) -> void:
	var count := maxi(0, page_count)
	var page := clampi(current_page, 0, maxi(0, count - 1))
	if count == _page_count and page == _current_page:
		_layout()
		return
	var structural_change := count != _page_count
	_page_count = count
	_current_page = page
	_preview_active = false
	if structural_change:
		_stop_motion()
		_selection_visual = float(page)
		_visible_count = _desired_count()
		_window_visual = float(_target_window())
		_layout()
	else:
		_start_motion()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		_stop_motion()
		if not _preview_active:
			_selection_visual = float(_current_page)
			_window_visual = float(_target_window())
		_render()


func set_interaction_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_stop_motion()
	elif not _preview_active:
		_start_motion()
	_render()


func active_motion_count() -> int:
	return int(_motion != null and _motion.is_valid() and _motion.is_running())


func preview_gesture(visual_page: float) -> void:
	_stop_motion()
	_preview_active = true
	_selection_visual = clampf(visual_page, 0.0, maxf(0.0, _page_count - 1.0))
	# Do not touch window position or page IDs while a drag is only a preview.
	_render()


func finish_gesture(committed: bool, target: int) -> void:
	_preview_active = false
	if committed:
		_current_page = clampi(target, 0, maxi(0, _page_count - 1))
	_start_motion()


func gesture_progress(visual_page: float) -> void:
	preview_gesture(visual_page)


func gesture_finished(committed: bool, target: int) -> void:
	finish_gesture(committed, target)


func _start_motion() -> void:
	_stop_motion()
	var window := float(_target_window())
	if _reduced_motion or not is_inside_tree():
		_selection_visual = float(_current_page)
		_window_visual = window
		_render()
		return
	var selection_changes := not is_equal_approx(_selection_visual, float(_current_page))
	var window_changes := not is_equal_approx(_window_visual, window)
	if not selection_changes and not window_changes:
		_render()
		return
	_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Interrupted phases always start at their current interpolated values.
	if selection_changes:
		_motion.tween_method(
			_set_selection, _selection_visual, float(_current_page), SELECT_DURATION
		)
	if window_changes:
		_motion.tween_method(_set_window, _window_visual, window, WINDOW_DURATION)
	_motion.finished.connect(func() -> void: _motion = null)
	_render()


func _stop_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func _set_selection(value: float) -> void:
	_selection_visual = value
	_render()


func _set_window(value: float) -> void:
	_window_visual = value
	_render()


func _target_window() -> int:
	return clampi(_current_page - _visible_count / 2, 0, maxi(0, _page_count - _visible_count))


func _desired_count() -> int:
	if not is_inside_tree() or size.x <= 0.0:
		return mini(MAX_DOTS, _page_count)
	var unit := Clean.canvas_scale(get_viewport_rect().size, get_window())
	var available := maxi(1, floori(size.x / (44.0 * unit)) - 2)
	var count := mini(_page_count, mini(MAX_DOTS, available))
	if count == 4 and _page_count > 4:
		count = 3
	return count


func _layout() -> void:
	if _band == null:
		return
	var count := _desired_count()
	if count != _visible_count:
		_stop_motion()
		_visible_count = count
		_window_visual = float(_target_window())
		_selection_visual = float(_current_page)
	_render()


func _render() -> void:
	if _band == null:
		return
	var focus_before := get_viewport().gui_get_focus_owner()
	var focused_page := (focus_before as PageDot).page_index if focus_before is PageDot else -1
	var unit := Clean.canvas_scale(get_viewport_rect().size, get_window())
	var side := 44.0 * unit
	var left := (size.x - side * (_visible_count + 2)) * 0.5
	_band.position = Vector2(left + side, (size.y - side) * 0.5)
	_band.size = Vector2(side * _visible_count, side)
	_previous.position = Vector2(left, (size.y - side) * 0.5)
	_next.position = Vector2(left + side * (_visible_count + 1), (size.y - side) * 0.5)
	for arrow in [_previous, _next]:
		arrow.size = Vector2.ONE * side
		arrow.unit = unit
		arrow.disabled = not _enabled
		arrow.queue_redraw()
	_previous.visible = _page_count > 1 and _current_page > 0
	_next.visible = _page_count > 1 and _current_page < _page_count - 1
	_previous.accessibility_name = (
		GameStrings.ui_text("pager_page") % [maxi(1, _current_page), _page_count]
	)
	_next.accessibility_name = (
		GameStrings.ui_text("pager_page") % [mini(_page_count, _current_page + 2), _page_count]
	)
	var base := floori(_window_visual)
	var fraction := _window_visual - float(base)
	var start := base + (1 if fraction >= 0.5 else 0)
	var pages: Array[int] = []
	for slot in _visible_count:
		pages.append(start + slot)
	# Retain matching controls. Recycle only the fully faded outgoing edge.
	var spare: Array[PageDot] = []
	for dot in _dots:
		if dot.page_index not in pages:
			spare.append(dot)
	for page in pages:
		var dot: PageDot
		for candidate in _dots:
			if candidate.page_index == page:
				dot = candidate
				break
		if dot == null:
			dot = spare.pop_back()
			dot.page_index = page
		var opacity := 1.0
		if fraction > 0.0 and fraction < 0.5 and page == base:
			opacity = 1.0 - fraction * 2.0
		elif fraction >= 0.5 and page == base + _visible_count:
			opacity = (fraction - 0.5) * 2.0
		dot.position = Vector2((float(page) - _window_visual) * side, 0)
		dot.size = Vector2.ONE * side
		dot.dot_unit = unit
		dot.weight = clampf(1.0 - absf(float(page) - _selection_visual), 0.0, 1.0)
		dot.modulate.a = opacity
		dot.visible = _page_count > 1 and opacity > 0.001
		dot.disabled = not _enabled
		dot.accessibility_name = GameStrings.ui_text("pager_page") % [page + 1, _page_count]
		dot.accessibility_description = (
			GameStrings.ui_text("pager_current") if page == _current_page else ""
		)
		dot.queue_redraw()
	for dot in spare:
		dot.visible = false
	if focus_before is PageDot and focus_before in _dots:
		if not focus_before.visible or focus_before.page_index != focused_page:
			_focus_current.call_deferred()
	elif focus_before in [_previous, _next] and not focus_before.visible:
		_focus_current.call_deferred()


func _focus_current() -> void:
	if not is_inside_tree() or not _enabled:
		return
	for dot in _dots:
		if dot.page_index == _current_page and dot.visible:
			dot.grab_focus()
			return
	# A new target can still be entering the window; keep keyboard input live.
	for dot in _dots:
		if dot.visible:
			dot.grab_focus()
			return


func _request(page: int) -> void:
	if _enabled and page >= 0 and page < _page_count and page != _current_page:
		page_requested.emit(page)


func _on_key(event: InputEvent) -> void:
	if not _enabled or not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_left") or event.is_action("ui_right"):
		_request(_current_page + (1 if event.is_action("ui_right") else -1))
		accept_event()


func debug_snapshot() -> Dictionary:
	var dots: Array[Dictionary] = []
	for dot in _dots:
		(
			dots
			. append(
				{
					"page": dot.page_index,
					"x": dot.position.x,
					"alpha": dot.modulate.a,
					"weight": dot.weight,
					"visible": dot.visible,
					"hit_width": dot.size.x,
				}
			)
		)
	return {
		"page_count": _page_count,
		"current_page": _current_page,
		"selection_visual": _selection_visual,
		"window_visual": _window_visual,
		"window_target": _target_window(),
		"visible_count": _visible_count,
		"preview": _preview_active,
		"active_motion_count": active_motion_count(),
		"previous_visible": _previous != null and _previous.visible,
		"next_visible": _next != null and _next.visible,
		"dots": dots,
	}
