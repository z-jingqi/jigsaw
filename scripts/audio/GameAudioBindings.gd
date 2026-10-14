class_name GameAudioBindings
extends Node
## Connects accepted UI actions and board feedback without polling drag frames.

var _game: Node
var _navigator: AppNavigator
var _board: PuzzleBoard
var _audio: GameAudioPlayback
var _scene_tree: SceneTree
var _buttons: Array[Dictionary] = []
var _home_screens: Array[WeakRef] = []
var _previous_route: StringName = &""
var _motion_frame := -1


func configure(
	game: Node, navigator: AppNavigator, board: PuzzleBoard, audio: GameAudioPlayback
) -> void:
	_game = game
	_navigator = navigator
	_board = board
	_audio = audio
	_scene_tree = get_tree()
	_scene_tree.node_added.connect(_on_node_added)
	_navigator.route_changed.connect(_on_route_changed)
	_navigator.transition_started.connect(_on_transition_started)
	_navigator.input_lock_changed.connect(_on_input_lock_changed)
	_board.feedback_requested.connect(_on_board_feedback)
	_bind_subtree(game)


func shutdown() -> void:
	if is_instance_valid(_scene_tree) and _scene_tree.node_added.is_connected(_on_node_added):
		_scene_tree.node_added.disconnect(_on_node_added)
	if is_instance_valid(_navigator) and _navigator.route_changed.is_connected(_on_route_changed):
		_navigator.route_changed.disconnect(_on_route_changed)
	if is_instance_valid(_navigator):
		if _navigator.transition_started.is_connected(_on_transition_started):
			_navigator.transition_started.disconnect(_on_transition_started)
		if _navigator.input_lock_changed.is_connected(_on_input_lock_changed):
			_navigator.input_lock_changed.disconnect(_on_input_lock_changed)
	if is_instance_valid(_board) and _board.feedback_requested.is_connected(_on_board_feedback):
		_board.feedback_requested.disconnect(_on_board_feedback)
	for binding in _buttons:
		var button = binding.node.get_ref()
		if is_instance_valid(button) and button.pressed.is_connected(binding.action):
			button.pressed.disconnect(binding.action)
	_buttons.clear()
	for reference in _home_screens:
		var home = reference.get_ref()
		if is_instance_valid(home):
			home.theme_switch_started.disconnect(_on_theme_switch_started)
	_home_screens.clear()
	_game = null
	_audio = null
	_board = null
	_navigator = null
	_scene_tree = null


func _bind_subtree(node: Node) -> void:
	_bind_button(node)
	_bind_home(node)
	for child in node.get_children():
		_bind_subtree(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton or node is HomeScreen:
		_bind_new_button.call_deferred(weakref(node))


func _bind_new_button(reference: WeakRef) -> void:
	var node = reference.get_ref()
	if is_instance_valid(node):
		_bind_button(node)
		_bind_home(node)


func _bind_home(node: Node) -> void:
	if not is_instance_valid(_game):
		return
	if not node is HomeScreen or not _game.is_ancestor_of(node):
		return
	if node.theme_switch_started.is_connected(_on_theme_switch_started):
		return
	node.theme_switch_started.connect(_on_theme_switch_started)
	_home_screens = _home_screens.filter(
		func(value: WeakRef) -> bool: return value.get_ref() != null
	)
	_home_screens.append(weakref(node))


func _bind_button(node: Node) -> void:
	if not is_instance_valid(node) or not is_instance_valid(_game):
		return
	if not node is BaseButton or not _game.is_ancestor_of(node):
		return
	var button := node as BaseButton
	var action := _on_button_pressed.bind(weakref(button))
	if button.pressed.is_connected(action):
		return
	# Dead button references are removed when the next screen adds controls.
	_buttons = _buttons.filter(func(value: Dictionary) -> bool: return value.node.get_ref() != null)
	button.pressed.connect(action)
	_buttons.append({"node": weakref(button), "action": action})


func _on_button_pressed(reference: WeakRef) -> void:
	var button = reference.get_ref()
	if not is_instance_valid(button) or not is_instance_valid(_audio):
		return
	# Native pressed signals already represent accepted actions. Their handlers
	# may hide or disable the button before this feedback callback runs.
	if _motion_frame != Engine.get_process_frames():
		_audio.play(&"tap")


func _on_board_feedback(kind: StringName) -> void:
	if kind in [&"ready", &"complete"]:
		return
	if _navigator.current_route() == &"gameplay":
		_audio.play(kind)


func _on_route_changed(route: StringName, _payload: Dictionary) -> void:
	_audio.set_context(route)
	if route == &"completion":
		_audio.play(&"complete")
	_previous_route = route


func _on_transition_started(route: StringName, _kind: StringName) -> void:
	_audio.set_context(route)
	if not _previous_route.is_empty() and route not in [&"completion", &"home_guide"]:
		_play_motion(&"page")


func _on_input_lock_changed(is_locked: bool) -> void:
	if not is_locked:
		_audio.set_context(_navigator.current_route())


func _on_theme_switch_started() -> void:
	if _navigator.current_route() == &"home" and not _navigator.is_input_locked():
		_play_motion(&"theme")


func _play_motion(kind: StringName) -> void:
	_motion_frame = Engine.get_process_frames()
	_audio.play(kind)
