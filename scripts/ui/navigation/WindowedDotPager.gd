extends Control
## A bounded indicator window; page identity never depends on dot position.
signal page_requested(index: int)

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const MAX_DOTS := 5

var _page_count := 0
var _current_page := 0
var _enabled := true
var _dots: Array[Button] = []


class PageDot:
	extends Button
	var selected := false
	var dot_unit := 1.0

	func _draw() -> void:
		var ink := Color("272925") if selected else Color("AFB4A8")
		var radius := (3.5 if selected else 2.5) * dot_unit
		draw_circle(size * 0.5, radius, ink, true, -1.0, true)
		if has_focus():
			draw_arc(size * 0.5, radius + 3.0 * dot_unit, 0, TAU, 32, ink, dot_unit, true)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_rebuild()


func configure(page_count: int, current_page: int) -> void:
	if (
		_page_count == maxi(0, page_count)
		and _current_page == clampi(current_page, 0, maxi(0, page_count - 1))
	):
		_layout()
		return
	_page_count = maxi(0, page_count)
	_current_page = clampi(current_page, 0, maxi(0, _page_count - 1))
	_rebuild()


func set_reduced_motion(_enabled_motion: bool) -> void:
	pass


func set_interaction_enabled(enabled: bool) -> void:
	_enabled = enabled
	for dot in _dots:
		dot.disabled = not enabled


func active_motion_count() -> int:
	return 0


func _rebuild() -> void:
	var restore_focus := false
	for dot in _dots:
		restore_focus = restore_focus or dot.has_focus()
	for dot in _dots:
		remove_child(dot)
		dot.queue_free()
	_dots.clear()
	var count := mini(MAX_DOTS, _page_count)
	var start := clampi(_current_page - count / 2, 0, maxi(0, _page_count - count))
	for slot in count:
		var page := start + slot
		var dot := PageDot.new()
		dot.name = "Page%d" % (page + 1)
		dot.selected = page == _current_page
		dot.accessibility_name = GameStrings.ui_text("pager_page") % [page + 1, _page_count]
		dot.accessibility_description = GameStrings.ui_text("pager_current") if dot.selected else ""
		dot.disabled = not _enabled
		dot.focus_mode = Control.FOCUS_ALL
		dot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			dot.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		dot.pressed.connect(func() -> void: _request(page))
		dot.gui_input.connect(_on_key)
		dot.focus_entered.connect(dot.queue_redraw)
		dot.focus_exited.connect(dot.queue_redraw)
		add_child(dot)
		_dots.append(dot)
	if restore_focus:
		_focus_current.call_deferred()
	_layout()


func _focus_current() -> void:
	if not is_inside_tree() or not _enabled:
		return
	for dot in _dots:
		if (dot as PageDot).selected:
			dot.grab_focus()
			return


func _layout() -> void:
	if not is_inside_tree():
		return
	var unit := Clean.canvas_scale(get_viewport_rect().size, get_window())
	var side := 44.0 * unit
	var left := (size.x - side * _dots.size()) * 0.5
	for index in _dots.size():
		var dot := _dots[index] as PageDot
		dot.dot_unit = unit
		dot.position = Vector2(left + index * side, (size.y - side) * 0.5)
		dot.size = Vector2.ONE * side
		dot.queue_redraw()


func _request(page: int) -> void:
	if _enabled and page != _current_page and page >= 0 and page < _page_count:
		page_requested.emit(page)


func _on_key(event: InputEvent) -> void:
	if not _enabled or not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_left") or event.is_action("ui_right"):
		_request(_current_page + (1 if event.is_action("ui_right") else -1))
		accept_event()
