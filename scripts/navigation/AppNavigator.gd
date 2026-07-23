class_name AppNavigator
extends Node

signal route_changed(route: StringName, payload: Dictionary)
signal navigation_failed(error: StringName, details: Dictionary)
signal input_lock_changed(is_locked: bool)

const RouteDefinitionScript := preload("res://scripts/navigation/RouteDefinition.gd")
const RouteRegistryScript := preload("res://scripts/navigation/RouteRegistry.gd")
const NavigationTransactionScript := preload("res://scripts/navigation/NavigationTransaction.gd")

@export var screen_host_path: NodePath
@export var modal_host_path: NodePath
@export var transition_host_path: NodePath

var _registry: Variant
var _screen_stack: Array[Dictionary] = []
var _modal_entry: Dictionary = {}
var _active_transaction: Variant
var _reduced_motion := false

@onready var _screen_host: Control = get_node(screen_host_path) as Control
@onready var _modal_host: Control = get_node(modal_host_path) as Control
@onready var _transition_host = get_node(transition_host_path)


func _ready() -> void:
	_registry = RouteRegistryScript.new() if _registry == null else _registry
	_transition_host.transition_settled.connect(_on_transition_settled)


func set_route_registry(registry: Variant) -> void:
	_registry = registry


func bind_route_scene(route: StringName, scene: PackedScene) -> Dictionary:
	return _registry.bind_scene(route, scene)


func route_contracts() -> Array[StringName]:
	return _registry.contracts()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


func set_root(route: StringName, payload: Dictionary = {}) -> Dictionary:
	var preparation := _prepare_navigation(false)
	if not bool(preparation.get("ok", false)):
		return preparation
	var built := _build_entry(route, payload)
	if not bool(built.get("ok", false)):
		return built
	var entry: Dictionary = built.entry
	var transition_kind := _transition_kind(route)
	var previous_stack := _screen_stack.duplicate()
	var previous_modal := _modal_entry
	_deactivate_all(previous_stack)
	if not previous_modal.is_empty():
		_set_entry_active(previous_modal, false)
	_add_screen_entry(entry)
	_screen_stack = [entry]
	_modal_entry = {}
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_free_entries(previous_stack)
			_free_entry(previous_modal)
			_emit_route_changed(),
		func() -> void:
			_free_entry(entry)
			_screen_stack = previous_stack
			_modal_entry = previous_modal
			_restore_active_view()
	)
	_begin_transition(transaction, transition_kind, "set_root")
	return _success(route)


func push(route: StringName, payload: Dictionary = {}) -> Dictionary:
	var preparation := _prepare_navigation(false)
	if not bool(preparation.get("ok", false)):
		return preparation
	if _screen_stack.is_empty():
		return _failure(&"invalid_payload", {"reason": "missing_root"})
	var built := _build_entry(route, payload)
	if not bool(built.get("ok", false)):
		return built
	var entry: Dictionary = built.entry
	var previous: Dictionary = _screen_stack.back()
	var transition_kind := _transition_kind(route)
	_set_entry_active(previous, false)
	_add_screen_entry(entry)
	_screen_stack.append(entry)
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_emit_route_changed(),
		func() -> void:
			_screen_stack.pop_back()
			_free_entry(entry)
			_set_entry_active(previous, true)
	)
	_begin_transition(transaction, transition_kind, "push")
	return _success(route)


func replace(route: StringName, payload: Dictionary = {}) -> Dictionary:
	var preparation := _prepare_navigation(false)
	if not bool(preparation.get("ok", false)):
		return preparation
	if _screen_stack.is_empty():
		return set_root(route, payload)
	var built := _build_entry(route, payload)
	if not bool(built.get("ok", false)):
		return built
	var entry: Dictionary = built.entry
	var transition_kind := _transition_kind(route)
	var previous: Dictionary = _screen_stack.pop_back()
	_set_entry_active(previous, false)
	_add_screen_entry(entry)
	_screen_stack.append(entry)
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_free_entry(previous)
			_emit_route_changed(),
		func() -> void:
			_screen_stack.pop_back()
			_free_entry(entry)
			_screen_stack.append(previous)
			_set_entry_active(previous, true)
	)
	_begin_transition(transaction, transition_kind, "replace")
	return _success(route)


func pop() -> Dictionary:
	if _transition_host.active_count() > 0:
		_transition_host.finish_active_to_target()
	if not _modal_entry.is_empty():
		return close_modal({"action": &"dismiss", "payload": {}})
	if _screen_stack.size() < 2:
		return _failure(&"invalid_payload", {"reason": "cannot_pop_root"})
	var outgoing: Dictionary = _screen_stack.pop_back()
	var previous: Dictionary = _screen_stack.back()
	_set_entry_active(outgoing, false)
	_set_entry_active(previous, true)
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_free_entry(outgoing)
			_emit_route_changed(),
		func() -> void:
			_set_entry_active(previous, false)
			_screen_stack.append(outgoing)
			_set_entry_active(outgoing, true)
	)
	_begin_transition(transaction, &"screen", "pop")
	return _success(current_route())


func show_modal(route: StringName, payload: Dictionary = {}) -> Dictionary:
	var preparation := _prepare_navigation(false)
	if not bool(preparation.get("ok", false)):
		return preparation
	if not _modal_entry.is_empty():
		return _failure(&"transition_busy", {"reason": "modal_present"})
	var built := _build_entry(route, payload)
	if not bool(built.get("ok", false)):
		return built
	var definition: Variant = built.definition
	if definition.presentation != RouteDefinitionScript.Presentation.MODAL and definition.presentation != RouteDefinitionScript.Presentation.OVERLAY:
		return _failure(&"invalid_payload", {"reason": "route_is_not_modal"})
	var entry: Dictionary = built.entry
	_set_entry_active(current_screen_entry(), false)
	_add_modal_entry(entry)
	_modal_entry = entry
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_emit_route_changed(),
		func() -> void:
			_modal_entry = {}
			_free_entry(entry)
			_set_entry_active(current_screen_entry(), true)
	)
	_begin_transition(transaction, &"modal", "show_modal")
	return _success(route)


func close_modal(result: Dictionary = {}) -> Dictionary:
	if _transition_host.active_count() > 0:
		_transition_host.finish_active_to_target()
	if _modal_entry.is_empty():
		return _failure(&"invalid_payload", {"reason": "missing_modal"})
	var normalized_result := _normalize_modal_result(result)
	if not bool(normalized_result.get("ok", false)):
		return normalized_result
	var closing := _modal_entry
	_modal_entry = {}
	_set_entry_active(closing, false)
	_set_entry_active(current_screen_entry(), true)
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_free_entry(closing)
			_emit_route_changed(),
		func() -> void:
			_set_entry_active(current_screen_entry(), false)
			_modal_entry = closing
			_set_entry_active(closing, true)
	)
	_begin_transition(transaction, &"modal", "close_modal")
	return {"ok": true, "result": normalized_result.result, "state": debug_state_snapshot()}


func cancel_active_transition() -> Dictionary:
	if _transition_host.active_count() == 0:
		return {"ok": true, "cancelled": false, "state": debug_state_snapshot()}
	_transition_host.cancel_active_to_source()
	return {"ok": true, "cancelled": true, "state": debug_state_snapshot()}


func current_route() -> StringName:
	if not _modal_entry.is_empty():
		return _modal_entry.route
	var entry := current_screen_entry()
	return entry.get("route", StringName())


func current_screen_entry() -> Dictionary:
	return _screen_stack.back() if not _screen_stack.is_empty() else {}


func current_screen_view() -> Control:
	var entry := current_screen_entry()
	return entry.get("view") as Control


func debug_state_snapshot() -> Dictionary:
	var motion: Dictionary = _transition_host.snapshot() if is_instance_valid(_transition_host) else {}
	return {
		"route": String(current_route()),
		"screen_stack": _screen_stack.map(func(entry: Dictionary) -> String: return String(entry.route)),
		"modal": String(_modal_entry.get("route", StringName())),
		"input_locked": _transition_host.active_count() > 0 if is_instance_valid(_transition_host) else false,
		"reduced_motion": _reduced_motion,
		"active_motion_count": motion.get("active_motion_count", 0),
		"motion_phase": motion.get("motion_phase", "idle"),
		"transition_kind": motion.get("transition_kind", ""),
		"gesture_progress": motion.get("gesture_progress", 0.0),
	}


func _prepare_navigation(allow_finish_active: bool) -> Dictionary:
	if _transition_host.active_count() == 0:
		return {"ok": true}
	if allow_finish_active:
		_transition_host.finish_active_to_target()
		return {"ok": true}
	return _failure(&"transition_busy", {})


func _build_entry(route: StringName, payload: Dictionary) -> Dictionary:
	var validation: Dictionary = _registry.validate(route, payload)
	if not bool(validation.get("ok", false)):
		return _failure(StringName(validation.get("error", "invalid_payload")), validation)
	var definition: Variant = validation.definition
	var view := definition.scene.instantiate() as Control
	if view == null:
		return _failure(&"not_found", {"route": String(route), "reason": "scene_root_is_not_control"})
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return {
		"ok": true,
		"definition": definition,
		"entry": {"route": route, "payload": validation.payload, "view": view},
	}


func _add_screen_entry(entry: Dictionary) -> void:
	_screen_host.add_child(entry.view)
	_invoke(entry.view, &"navigation_enter", [entry.payload, _navigation_context("enter")])
	_set_entry_active(entry, true)


func _add_modal_entry(entry: Dictionary) -> void:
	_modal_host.add_child(entry.view)
	_invoke(entry.view, &"navigation_enter", [entry.payload, _navigation_context("enter")])
	_set_entry_active(entry, true)


func _set_entry_active(entry: Dictionary, is_active: bool) -> void:
	if entry.is_empty():
		return
	var view := entry.get("view") as Control
	if not is_instance_valid(view):
		return
	if view.has_method(&"navigation_set_active"):
		view.call(&"navigation_set_active", is_active)
	else:
		view.visible = is_active
		view.mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
		view.set_process(is_active)
		view.set_process_input(is_active)
		view.set_process_unhandled_input(is_active)


func _deactivate_all(entries: Array) -> void:
	for entry in entries:
		_set_entry_active(entry, false)


func _restore_active_view() -> void:
	if not _modal_entry.is_empty():
		_set_entry_active(current_screen_entry(), false)
		_set_entry_active(_modal_entry, true)
	else:
		_set_entry_active(current_screen_entry(), true)


func _free_entries(entries: Array) -> void:
	for entry in entries:
		_free_entry(entry)


func _free_entry(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var view := entry.get("view") as Control
	if not is_instance_valid(view):
		return
	_invoke(view, &"navigation_exit", [_navigation_context("exit")])
	view.queue_free()


func _invoke(target: Object, method: StringName, arguments: Array) -> void:
	if target.has_method(method):
		target.callv(method, arguments)


func _begin_transition(transaction: Variant, kind: StringName, reason: String) -> void:
	_active_transaction = transaction
	_transition_host.play(kind, _navigation_context(reason))
	input_lock_changed.emit(true)


func _on_transition_settled(committed: bool) -> void:
	var transaction: Variant = _active_transaction
	_active_transaction = null
	if transaction != null:
		transaction.resolve(committed)
	input_lock_changed.emit(false)


func _navigation_context(reason: String) -> Dictionary:
	return {
		"direction": 0,
		"source_rect": Rect2(),
		"source_texture": null,
		"reason": reason,
		"reduced_motion": _reduced_motion,
		"gesture_progress": 0.0,
	}


func _transition_kind(route: StringName) -> StringName:
	var source := String(current_screen_entry().get("route", StringName()))
	if source == "home" and route == &"levels":
		return &"home_to_levels"
	if source == "all_themes" and route == &"levels":
		return &"card_to_levels"
	return &"screen"


func _normalize_modal_result(result: Dictionary) -> Dictionary:
	var action := StringName(result.get("action", &"dismiss"))
	if action not in [&"dismiss", &"select_mode", &"return_to_levels"]:
		return _failure(&"invalid_payload", {"reason": "invalid_modal_action"})
	var payload: Variant = result.get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		return _failure(&"invalid_payload", {"reason": "invalid_modal_result_payload"})
	return {"ok": true, "result": {"action": action, "payload": payload}}


func _success(route: StringName) -> Dictionary:
	return {"ok": true, "route": String(route), "state": debug_state_snapshot()}


func _failure(error: StringName, details: Dictionary) -> Dictionary:
	navigation_failed.emit(error, details)
	return {"ok": false, "error": String(error), "details": details, "state": debug_state_snapshot()}


func _emit_route_changed() -> void:
	var entry := _modal_entry if not _modal_entry.is_empty() else current_screen_entry()
	if entry.is_empty():
		return
	route_changed.emit(entry.route, entry.payload)
