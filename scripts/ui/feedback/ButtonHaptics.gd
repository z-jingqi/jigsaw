class_name ButtonHaptics
extends RefCounted

const MobileHapticsScript := preload("res://scripts/platform/MobileHaptics.gd")

var _scope: Node
var _tree: SceneTree
var _settings: SettingsRepository
var _buttons: Dictionary = {}
var _enabled := true
var _haptics := MobileHapticsScript.new()


func _init(scope: Node, settings: SettingsRepository = null) -> void:
	_scope = scope
	_tree = scope.get_tree()
	_settings = settings
	if _settings == null:
		_settings = SettingsRepository.new()
		_settings.load()
	_on_settings_changed(_settings.snapshot(), _settings.revision())
	_settings.changed.connect(_on_settings_changed)
	_tree.node_added.connect(_on_node_added)
	_tree.node_removed.connect(_on_node_removed)
	for button in scope.find_children("*", "BaseButton", true, false):
		_on_node_added(button)


func dispose() -> void:
	_haptics.cancel_pending()
	if is_instance_valid(_tree):
		_tree.node_added.disconnect(_on_node_added)
		_tree.node_removed.disconnect(_on_node_removed)
	for reference: WeakRef in _buttons.values():
		var button := reference.get_ref() as BaseButton
		if button != null:
			button.pressed.disconnect(_on_button_pressed.bind(button))
	_buttons.clear()
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)
	_settings = null
	_scope = null
	_tree = null


func _on_node_added(node: Node) -> void:
	if not node is BaseButton or not _scope.is_ancestor_of(node):
		return
	var button := node as BaseButton
	if button.pressed.is_connected(_on_button_pressed.bind(button)):
		return
	_buttons[button.get_instance_id()] = weakref(button)
	# One semantic activation, not both touch-down and emulated mouse events.
	# This also covers native toggles, keyboard input and recycled level cards.
	button.pressed.connect(_on_button_pressed.bind(button))


func _on_node_removed(node: Node) -> void:
	if not _buttons.has(node.get_instance_id()):
		return
	var button := node as BaseButton
	button.pressed.disconnect(_on_button_pressed.bind(button))
	_buttons.erase(node.get_instance_id())


func _on_button_pressed(button: BaseButton) -> void:
	# Do not recheck visibility/disabled here: the action handler may already
	# have hidden the screen or disabled its navigation button during this signal.
	if _enabled:
		var locked := button is LevelCard and (button as LevelCard).is_locked()
		_haptics.play("locked" if locked else "button")


func _on_settings_changed(snapshot: Dictionary, _revision: int) -> void:
	_enabled = bool(snapshot.get("haptics_enabled", true))
	if not _enabled:
		_haptics.cancel_pending()
