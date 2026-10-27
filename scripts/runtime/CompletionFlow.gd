extends RefCounted
## Completion actions keep the current mode and replace only the gameplay page.

var _navigator: AppNavigator
var _content: ContentRepository
var _coordinator: WeakRef
var _modal: WeakRef
var _context: Dictionary = {}
var _advancing := false


func _init(navigator: AppNavigator, content: ContentRepository, coordinator: Object) -> void:
	_navigator = navigator
	_content = content
	_coordinator = weakref(coordinator)
	_navigator.input_lock_changed.connect(_on_input_lock_changed)


func shutdown() -> void:
	_navigator.input_lock_changed.disconnect(_on_input_lock_changed)
	_context.clear()
	_modal = null


func next_level(theme_id: String, level_id: String, mode: String) -> Dictionary:
	var levels: Array = _content.topic_by_id(theme_id).get("levels", [])
	for index in levels.size() - 1:
		if str(levels[index].get("id", "")) == level_id:
			var following: Dictionary = levels[index + 1]
			return following if _content.available_modes(following).has(mode) else {}
	return {}


func bind(modal: CompletionModal, model: AppViewModels.CompletionViewModel) -> void:
	_modal = weakref(modal)
	_context = {
		"theme_id": model.theme_id,
		"level_id": model.level_id,
		"mode": String(model.mode),
		"completion_event_id": model.completion_event_id,
	}
	_advancing = false
	modal.confirm_requested.connect(_advance)
	modal.dismissed.connect(_return)


func _advance(event_id: String) -> void:
	if not _valid_action(event_id):
		return
	var coordinator: Object = _coordinator.get_ref()
	if coordinator.has_pending_completion(event_id):
		var saved: Dictionary = coordinator.retry_completion_save(event_id)
		var modal: CompletionModal = _modal.get_ref()
		modal.set_save_pending(
			not bool(saved.get("ok", false)), bool(saved.get("recovery_saved", false))
		)
		modal.restore_actions()
		return
	var following := next_level(_context.theme_id, _context.level_id, _context.mode)
	if following.is_empty():
		_restore()
		return
	_advancing = true
	var result: Dictionary = coordinator.enter_level(
		_context.theme_id, following.id, _context.mode, "resume"
	)
	if not bool(result.get("ok", false)):
		_restore()


func _return(event_id: String) -> void:
	if _valid_action(event_id):
		_coordinator.get_ref().close_modal()


func _valid_action(event_id: String) -> bool:
	return (
		not _advancing
		and _navigator.current_route() == &"completion"
		and event_id == _context.get("completion_event_id", "")
		and _modal != null
		and _modal.get_ref() == _navigator.current_route_view()
		and _coordinator.get_ref() != null
	)


func _on_input_lock_changed(locked: bool) -> void:
	if locked or not _advancing:
		return
	if _navigator.current_route() == &"completion":
		_restore()
	else:
		_advancing = false
		_context.clear()
		_modal = null


func _restore() -> void:
	_advancing = false
	var coordinator: Object = _coordinator.get_ref()
	if coordinator != null:
		coordinator.restore_completion_context(_context)
	var modal: Object = _modal.get_ref() if _modal != null else null
	if is_instance_valid(modal):
		modal.restore_actions()
