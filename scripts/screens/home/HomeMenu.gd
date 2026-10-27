extends Control
signal action_requested(action: StringName)
signal closed
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Arena := preload("res://scripts/ui/navigation/GestureArena.gd")
var can_interact: Callable
var _blocked_pointer := -2
var _return_focus: Control


func _ready() -> void:
	var buttons := [$Panel/Themes, $Panel/Album, $Panel/Settings]
	var keys := ["all_themes", "album_title", "settings_title"]
	var actions := [&"themes", &"album", &"settings"]
	$Panel.add_theme_stylebox_override("panel", Clean.panel(Clean.PAPER, 16))
	for index in 3:
		var button: Button = buttons[index]
		button.text = GameStrings.ui_text(keys[index])
		button.accessibility_name = button.text
		Clean.button(button)
		button.pressed.connect(_choose.bind(actions[index]))
		button.focus_neighbor_top = button.get_path_to(buttons[posmod(index - 1, 3)])
		button.focus_neighbor_bottom = button.get_path_to(buttons[(index + 1) % 3])
		button.focus_next = button.focus_neighbor_bottom
		button.focus_previous = button.focus_neighbor_top
		button.focus_neighbor_left = NodePath(".")
		button.focus_neighbor_right = NodePath(".")


func open_menu(anchor: Rect2) -> void:
	if not can_interact.is_valid() or not can_interact.call():
		return
	_return_focus = get_viewport().gui_get_focus_owner()
	visible = true
	reposition(anchor)
	$Panel/Themes.grab_focus()


func reposition(anchor: Rect2) -> void:
	var unit := Clean.canvas_scale(get_viewport_rect().size, get_window())
	var row := 48.0 * unit
	var width := minf(220.0 * unit, size.x - 32.0 * unit)
	$Panel.size = Vector2(width, row * 3 + 16.0 * unit)
	var local := get_global_transform().affine_inverse() * Vector2(anchor.end.x, anchor.end.y)
	$Panel.position = Vector2(
		clampf(local.x - width, 16.0 * unit, size.x - width - 16.0 * unit), local.y + 8.0 * unit
	)
	for index in 3:
		var button: Button = $Panel.get_child(index)
		button.position = Vector2(8, 8 + index * 48) * unit
		button.size = Vector2(width - 16.0 * unit, row)
		button.add_theme_font_size_override("font_size", roundi(16.0 * unit))


func dismiss(restore_focus := true) -> bool:
	if not visible:
		return false
	hide()
	if restore_focus and is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	closed.emit()
	return true


func is_consuming_pointer() -> bool:
	return _blocked_pointer != -2


func _choose(action: StringName) -> void:
	if not visible or not can_interact.call():
		return
	dismiss(false)
	action_requested.emit(action)


func _gui_input(event: InputEvent) -> void:
	var pointer := -2
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pointer = -1
	elif event is InputEventScreenTouch and event.pressed:
		pointer = event.index
	if (
		pointer != -2
		and not $Panel.get_global_rect().has_point(get_global_transform() * event.position)
	):
		if Arena.reserve(self, pointer):
			_blocked_pointer = pointer
			dismiss()
		accept_event()


func _input(event: InputEvent) -> void:
	if _blocked_pointer != -2:
		var released := false
		if event is InputEventMouseButton and _blocked_pointer == -1:
			released = not event.pressed
		elif event is InputEventScreenTouch and event.index == _blocked_pointer:
			released = not event.pressed or event.canceled
		if released:
			Arena.release(self)
			_blocked_pointer = -2
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if Arena.block_secondary(get_viewport(), event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_BACK]:
		dismiss()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		Arena.release(self)
		_blocked_pointer = -2
		dismiss(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		dismiss()


func _exit_tree() -> void:
	Arena.release(self)
