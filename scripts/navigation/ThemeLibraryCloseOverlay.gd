extends RefCounted
## Fixed close target remains reachable while the sheet itself is offscreen.
const Fresh := preload("res://scripts/screens/home/FreshButton.gd")
var _button: Button
var _original: Button


func install(host: Control, sheet: Control, rest_position: Vector2) -> void:
	var original := sheet.get_node_or_null("CloseButton") as Button
	if original == null:
		return
	if _original != original or not is_instance_valid(_button):
		clear()
		_original = original
		_button = Fresh.new()
		_button.name = "ThemeLibraryCloseOverlay"
		_button.symbol = "close"
		_button.icon_only = true
		_button.z_index = 100
		_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		_button.accessibility_name = original.accessibility_name
		_button.pressed.connect(
			func() -> void:
				if is_instance_valid(_original):
					_original.pressed.emit()
		)
		host.add_child(_button)
	_original.hide()
	_button.size = original.size
	_button.custom_minimum_size = original.size
	var parent := sheet.get_parent() as Control
	var point := rest_position + original.position
	if parent != null:
		point = parent.get_global_transform() * point
	_button.position = host.get_global_transform().affine_inverse() * point


func clear() -> void:
	if is_instance_valid(_original):
		_original.show()
	if is_instance_valid(_button):
		_button.hide()
		_button.get_parent().remove_child(_button)
		_button.queue_free()
	_button = null
	_original = null
