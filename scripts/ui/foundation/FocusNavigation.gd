class_name FocusNavigation
extends RefCounted

## Sets deterministic keyboard focus order without coupling components to pages.
static func configure_linear(controls: Array[Control]) -> void:
	if controls.is_empty():
		return
	for index in controls.size():
		var control := controls[index]
		if not is_instance_valid(control):
			continue
		var previous := controls[index - 1] if index > 0 else controls[controls.size() - 1]
		var next := controls[(index + 1) % controls.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)


static func focus_first(root: Control) -> Control:
	for child in _focusable_descendants(root):
		child.grab_focus()
		return child
	return null


static func _focusable_descendants(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in root.get_children():
		if child is Control:
			var control := child as Control
			if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
				result.append(control)
			result.append_array(_focusable_descendants(control))
	return result
