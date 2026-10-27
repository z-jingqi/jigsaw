extends Control
signal action_requested(action: StringName)
signal closed
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Arena := preload("res://scripts/ui/navigation/GestureArena.gd")
var can_interact: Callable
var _blocked_pointer := -2
var _return_focus: Control
var _keyboard_mode := false


func _ready() -> void:
	var buttons := [$Panel/Themes, $Panel/Album, $Panel/Settings]
	var keys := ["all_themes", "album_title", "settings_title"]
	var actions := [&"themes", &"album", &"settings"]
	for index in 3:
		var button: Button = buttons[index]
		button.text = GameStrings.ui_text(keys[index])
		button.accessibility_name = button.text
		button.configure(actions[index], 1.0)
		button.pressed.connect(_choose.bind(actions[index]))
	set_album_available(false)


func set_album_available(available: bool) -> void:
	var restore_focus: bool = not available and $Panel/Album.has_focus()
	$Panel/Album.visible = available
	$Panel/Album.disabled = not available
	$Panel/Album.focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
	var buttons := _visible_buttons()
	for index in buttons.size():
		var button := buttons[index]
		button.focus_neighbor_top = button.get_path_to(buttons[posmod(index - 1, buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(buttons[(index + 1) % buttons.size()])
		button.focus_next = button.focus_neighbor_bottom
		button.focus_previous = button.focus_neighbor_top
		button.focus_neighbor_left = NodePath(".")
		button.focus_neighbor_right = NodePath(".")
	if restore_focus and visible:
		if _keyboard_mode:
			$Panel/Themes.grab_focus()
		else:
			get_viewport().gui_release_focus()


func _visible_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in $Panel.get_children():
		if child is Button and child.visible:
			buttons.append(child)
	return buttons


func open_menu(anchor: Rect2) -> void:
	if not can_interact.is_valid() or not can_interact.call():
		return
	_return_focus = get_viewport().gui_get_focus_owner()
	visible = true
	reposition(anchor)
	_refresh_labels()
	if _keyboard_mode:
		$Panel/Themes.grab_focus()
	else:
		get_viewport().gui_release_focus()


func reposition(anchor: Rect2) -> void:
	var unit := Metrics.unit(get_viewport_rect().size)
	var panel := Clean.panel(Color("FFFCF5"), 12.0 * unit)
	panel.set_border_width_all(maxi(1, roundi(unit)))
	panel.border_color = Color("E1DDD3")
	panel.shadow_color = Color(0.12, 0.11, 0.08, 0.025)
	panel.shadow_size = roundi(3 * unit)
	panel.shadow_offset = Vector2(0, unit)
	$Panel.add_theme_stylebox_override("panel", panel)
	var row := Metrics.TOUCH * unit
	var width := minf(Metrics.MENU_WIDTH * unit, size.x - 32.0 * unit)
	var buttons := _visible_buttons()
	$Panel.size = Vector2(width, row * buttons.size() + 16.0 * unit)
	var local := get_global_transform().affine_inverse() * Vector2(anchor.end.x, anchor.end.y)
	$Panel.position = Vector2(
		clampf(local.x - width, 16.0 * unit, size.x - width - 16.0 * unit), local.y + 8.0 * unit
	)
	for index in buttons.size():
		var button := buttons[index]
		button.position = Vector2(8, 8 + index * Metrics.TOUCH) * unit
		button.size = Vector2(width - 16.0 * unit, row)
		button.configure(
			[&"themes", &"album", &"settings"][$Panel.get_children().find(button)], unit
		)
		button.set_keyboard_focus_visible(_keyboard_mode)


func dismiss(restore_focus := true) -> bool:
	if not visible:
		return false
	hide()
	if (
		_keyboard_mode
		and restore_focus
		and is_instance_valid(_return_focus)
		and _return_focus.is_visible_in_tree()
	):
		_return_focus.grab_focus()
	elif not _keyboard_mode:
		get_viewport().gui_release_focus()
	closed.emit()
	return true


func is_consuming_pointer() -> bool:
	return _blocked_pointer != -2


func _choose(action: StringName) -> void:
	if action == &"album" and not $Panel/Album.visible:
		return
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


func _set_keyboard_mode(enabled: bool) -> void:
	_keyboard_mode = enabled
	for button in [$Panel/Themes, $Panel/Album, $Panel/Settings]:
		button.set_keyboard_focus_visible(enabled)


func _refresh_labels() -> void:
	var keys := ["all_themes", "album_title", "settings_title"]
	for index in 3:
		var button := $Panel.get_child(index) as Button
		button.text = GameStrings.ui_text(keys[index])
		button.accessibility_name = button.text


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
	if Arena.block_secondary(get_viewport(), event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_set_keyboard_mode(true)
	elif (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	):
		_set_keyboard_mode(false)
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_TAB, KEY_DOWN, KEY_UP]:
		var focused := get_viewport().gui_get_focus_owner()
		if not _visible_buttons().has(focused):
			var buttons := _visible_buttons()
			var backwards: bool = (
				event.keycode == KEY_UP or (event.keycode == KEY_TAB and event.shift_pressed)
			)
			buttons[-1 if backwards else 0].grab_focus()
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
