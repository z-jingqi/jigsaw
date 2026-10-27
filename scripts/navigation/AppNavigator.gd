class_name AppNavigator
extends Node

signal route_changed(route: StringName, payload: Dictionary)
signal transition_started(route: StringName, kind: StringName)
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
var _handoff_in_progress := false
var _pending_unlock := false
var _preparation_lock_active := false

@onready var _screen_host: Control = get_node(screen_host_path) as Control
@onready var _modal_host: Node = get_node(modal_host_path)
@onready var _transition_host = get_node(transition_host_path)


func _ready() -> void:
	_registry = RouteRegistryScript.new() if _registry == null else _registry
	_transition_host.transition_settled.connect(_on_transition_settled)
	_transition_host.motion_started.connect(_on_motion_started)


func set_route_registry(registry: Variant) -> void:
	_registry = registry


func bind_route_scene(route: StringName, scene: PackedScene) -> Dictionary:
	return _registry.bind_scene(route, scene)


func route_contracts() -> Array[StringName]:
	return _registry.contracts()


func is_input_locked() -> bool:
	return (
		is_instance_valid(_transition_host)
		and _transition_host.snapshot().get("motion_phase") == "preparing"
	)


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
	if (
		route == &"themes"
		and _transition_host.active_count() > 0
		and _transition_host.snapshot().get("transition_kind") == "themes_to_home"
	):
		_transition_host.reverse_active_to_source()
		return _success(route)
	var current := current_screen_entry()
	if _same_destination(current, route, payload):
		_transition_host.resume_active_to_target()
		return _success(route)
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
	_set_entry_transition_background(previous)
	_add_screen_entry(entry)
	_screen_stack.append(entry)
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_set_entry_active(previous, false)
			_emit_route_changed(),
		func() -> void:
			_screen_stack.pop_back()
			_free_entry(entry)
			_set_entry_active(previous, true)
	)
	_begin_transition(
		transaction, transition_kind, "push", previous.get("view"), entry.get("view"), payload
	)
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
	_set_entry_transition_background(previous)
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
	_begin_transition(
		transaction, transition_kind, "replace", previous.get("view"), entry.get("view"), payload
	)
	return _success(route)


func push_from_modal(
	route: StringName, payload: Dictionary = {}, prepared_view: Control = null
) -> Dictionary:
	if _transition_host.active_count() > 0:
		_interrupt_for_navigation()
	if _modal_entry.is_empty():
		return push(route, payload)
	var built := _build_entry(route, payload, prepared_view)
	if not bool(built.get("ok", false)):
		return built
	var entry: Dictionary = built.entry
	var previous := current_screen_entry()
	var outgoing := _modal_entry
	_modal_entry = {}
	_set_entry_active(previous, false)
	_set_entry_transition_background(outgoing)
	_add_screen_entry(entry)
	_screen_stack.append(entry)
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_free_entry(outgoing)
			_emit_route_changed(),
		func() -> void:
			_screen_stack.pop_back()
			_free_entry(entry)
			_modal_entry = outgoing
			_set_entry_active(outgoing, true)
	)
	_begin_transition(
		transaction, _transition_kind(route), "push_from_modal", outgoing.view, entry.view, payload
	)
	return _success(route)


func replace_from_modal(route: StringName, payload: Dictionary = {}) -> Dictionary:
	if _transition_host.active_count() > 0:
		_interrupt_for_navigation()
	if _modal_entry.is_empty():
		return replace(route, payload)
	var built := _build_entry(route, payload)
	if not bool(built.get("ok", false)):
		return built
	var entry: Dictionary = built.entry
	var previous: Dictionary = _screen_stack.pop_back()
	var outgoing := _modal_entry
	_modal_entry = {}
	_set_entry_active(previous, false)
	# Release the persistent board before the replacement page mounts it.
	_invoke(previous.view, &"navigation_exit", [_navigation_context("replace")])
	_set_entry_transition_background(outgoing)
	_add_screen_entry(entry)
	_screen_stack.append(entry)
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_free_entry(previous)
			_free_entry(outgoing)
			_emit_route_changed(),
		func() -> void:
			_screen_stack.pop_back()
			_free_entry(entry)
			_screen_stack.append(previous)
			_modal_entry = outgoing
			_set_entry_modal_background(previous)
			_set_entry_active(outgoing, true)
	)
	_begin_transition(
		transaction, _transition_kind(route), "push_from_modal", outgoing.view, entry.view, payload
	)
	return _success(route)


func pop() -> Dictionary:
	if _transition_host.active_count() > 0:
		var motion: Dictionary = _transition_host.snapshot()
		if motion.get("transition_kind") == "themes_to_home":
			_transition_host.resume_active_to_target()
			return _success(current_route())
		if motion.get("reason") == "push" and _modal_entry.is_empty():
			_transition_host.reverse_active_to_source()
			return _success(current_route())
		_interrupt_for_navigation()
	if not _modal_entry.is_empty():
		return close_modal({"action": &"dismiss", "payload": {}})
	if _screen_stack.size() < 2:
		return _failure(&"invalid_payload", {"reason": "cannot_pop_root"})
	var outgoing: Dictionary = _screen_stack.pop_back()
	var previous: Dictionary = _screen_stack.back()
	_set_entry_transition_background(outgoing)
	_set_entry_transition_background(previous)
	var transition_kind := _pop_transition_kind(outgoing.route, previous.route)
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_free_entry(outgoing)
			_set_entry_active(previous, true)
			_emit_route_changed(),
		func() -> void:
			_set_entry_active(previous, false)
			_screen_stack.append(outgoing)
			_set_entry_active(outgoing, true)
	)
	_begin_transition(
		transaction,
		transition_kind,
		"pop",
		outgoing.get("view"),
		previous.get("view"),
		outgoing.get("payload", {})
	)
	return _success(current_route())


func show_modal(route: StringName, payload: Dictionary = {}) -> Dictionary:
	if _same_destination(_modal_entry, route, payload):
		return _success(route)
	var preparation := _prepare_navigation(false)
	if not bool(preparation.get("ok", false)):
		return preparation
	if not _modal_entry.is_empty():
		return _failure(&"transition_busy", {"reason": "modal_present"})
	var built := _build_entry(route, payload)
	if not bool(built.get("ok", false)):
		return built
	var definition: Variant = built.definition
	if (
		definition.presentation != RouteDefinitionScript.Presentation.MODAL
		and definition.presentation != RouteDefinitionScript.Presentation.OVERLAY
	):
		return _failure(&"invalid_payload", {"reason": "route_is_not_modal"})
	var entry: Dictionary = built.entry
	_set_entry_modal_background(current_screen_entry())
	_add_modal_entry(entry)
	_modal_entry = entry
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void: _emit_route_changed(),
		func() -> void:
			_modal_entry = {}
			_free_entry(entry)
			_set_entry_active(current_screen_entry(), true)
	)
	var animated_modal: Control = (
		entry.view
		if entry.view.has_method("needs_box_close") and entry.view.needs_box_close()
		else null
	)
	_begin_transition(transaction, &"modal", "show_modal", null, animated_modal)
	return _success(route)


func pop_from_modal() -> Dictionary:
	if _transition_host.active_count() > 0:
		_interrupt_for_navigation()
	if _modal_entry.is_empty():
		return pop()
	if _screen_stack.size() < 2:
		return _failure(&"invalid_payload", {"reason": "cannot_pop_root"})
	var outgoing: Dictionary = _screen_stack.pop_back()
	var previous := current_screen_entry()
	var modal := _modal_entry
	_modal_entry = {}
	_set_entry_active(outgoing, false)
	_set_entry_transition_background(modal)
	_set_entry_transition_background(previous)
	var transaction: Variant = NavigationTransactionScript.new(
		func() -> void:
			_free_entry(modal)
			_free_entry(outgoing)
			_set_entry_active(previous, true)
			_emit_route_changed(),
		func() -> void:
			_screen_stack.append(outgoing)
			_modal_entry = modal
			_set_entry_active(previous, false)
			_set_entry_modal_background(outgoing)
			_set_entry_active(modal, true)
	)
	_begin_transition(
		transaction,
		_pop_transition_kind(outgoing.route, previous.route),
		"pop",
		modal.view,
		previous.view
	)
	return _success(current_route())


func close_modal(result: Dictionary = {}) -> Dictionary:
	if _transition_host.active_count() > 0:
		_interrupt_for_navigation()
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


func interrupt_active_transition() -> Dictionary:
	if _transition_host.active_count() == 0:
		return {"ok": true, "interrupted": false}
	_interrupt_for_navigation()
	return {"ok": true, "interrupted": true, "state": debug_state_snapshot()}


func finish_active_transition() -> Dictionary:
	if _transition_host.active_count() == 0:
		return {"ok": true, "finished": false, "state": debug_state_snapshot()}
	_transition_host.finish_active_to_target()
	return {"ok": true, "finished": true, "state": debug_state_snapshot()}


func reveal_prepared_screen(screen: Control) -> void:
	_transition_host.reveal_prepared_view(screen)


func mount_prepared_screen(screen: Control) -> void:
	# Kept behind the opaque mode page, without adding a speculative route.
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_host.add_child(screen)


func wait_until_idle(canceled: Signal = Signal()) -> bool:
	while is_instance_valid(_transition_host) and _transition_host.active_count() > 0:
		if canceled.is_null():
			await _transition_host.transition_settled
		else:
			var continued := await preload("res://scripts/runtime/CancellableFrame.gd").wait(
				get_tree().process_frame, canceled
			)
			if not continued:
				return false
	return true


func edge_back_context() -> Dictionary:
	var view := current_route_view()
	if view != null and view.has_method("edge_back_allowed") and not view.edge_back_allowed():
		return {}
	if current_route() == &"themes":
		return {}
	if is_input_locked():
		return {}
	var behind := current_screen_view() if not _modal_entry.is_empty() else previous_screen_view()
	if not is_instance_valid(behind):
		return {}
	return {"source": current_route_view(), "previous": behind, "transition": _transition_host}


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


func previous_screen_view() -> Control:
	if _screen_stack.size() < 2:
		return null
	return _screen_stack[-2].get("view") as Control


func current_route_view() -> Control:
	if not _modal_entry.is_empty():
		return _modal_entry.get("view") as Control
	return current_screen_view()


func debug_state_snapshot() -> Dictionary:
	var motion: Dictionary = (
		_transition_host.snapshot() if is_instance_valid(_transition_host) else {}
	)
	return {
		"route": String(current_route()),
		"screen_stack":
		_screen_stack.map(func(entry: Dictionary) -> String: return String(entry.route)),
		"modal": String(_modal_entry.get("route", StringName())),
		"input_locked": is_input_locked(),
		"reduced_motion": _reduced_motion,
		"active_motion_count": motion.get("active_motion_count", 0),
		"motion_phase": motion.get("motion_phase", "idle"),
		"transition_kind": motion.get("transition_kind", ""),
		"gesture_progress": motion.get("gesture_progress", 0.0),
	}


func _interrupt_for_navigation() -> void:
	_handoff_in_progress = true
	_transition_host.interrupt_at_current_pose()
	_handoff_in_progress = false
	_pending_unlock = true


func _same_destination(entry: Dictionary, route: StringName, payload: Dictionary) -> bool:
	if entry.is_empty() or entry.route != route:
		return false
	# Fresh view models and moving source rectangles do not make a new route.
	for key in ["theme_id", "level_id", "mode", "focus_level_id"]:
		if entry.payload.get(key) != payload.get(key):
			return false
	return true


func _prepare_navigation(_allow_finish_active: bool) -> Dictionary:
	if _transition_host.active_count() > 0:
		_interrupt_for_navigation()
	return {"ok": true}


func _build_entry(
	route: StringName, payload: Dictionary, prepared_view: Control = null
) -> Dictionary:
	var validation: Dictionary = _registry.validate(route, payload)
	if not bool(validation.get("ok", false)):
		return _failure(StringName(validation.get("error", "invalid_payload")), validation)
	var definition: Variant = validation.definition
	var reused := is_instance_valid(prepared_view) and not prepared_view.is_queued_for_deletion()
	var view := prepared_view if reused else definition.scene.instantiate() as Control
	if view == null:
		return _failure(
			&"not_found", {"route": String(route), "reason": "scene_root_is_not_control"}
		)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return {
		"ok": true,
		"definition": definition,
		"entry": {"route": route, "payload": validation.payload, "view": view, "prepared": reused},
	}


func _add_screen_entry(entry: Dictionary) -> void:
	if entry.view.get_parent() != _screen_host:
		_screen_host.add_child(entry.view)
	if not bool(entry.get("prepared", false)):
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


func _set_entry_modal_background(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var view := entry.get("view") as Control
	if not is_instance_valid(view):
		return
	view.visible = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_entry_transition_background(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var view := entry.get("view") as Control
	if not is_instance_valid(view):
		return
	_invoke(view, &"navigation_prepare_transition", [])
	view.visible = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_process(false)
	view.set_process_input(false)
	view.set_process_unhandled_input(false)


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
	view.hide()
	view.queue_free()


func _invoke(target: Object, method: StringName, arguments: Array) -> void:
	if target.has_method(method):
		target.callv(method, arguments)


func _begin_transition(
	transaction: Variant,
	kind: StringName,
	reason: String,
	source_view: Control = null,
	target_view: Control = null,
	payload: Dictionary = {}
) -> void:
	_active_transaction = transaction
	var context := _navigation_context(reason)
	context["source_view"] = source_view
	context["target_view"] = target_view
	context["source_companion"] = (
		payload.get("_transition_source_companion") if reason == "pop" else null
	)
	context["target_companion"] = (
		payload.get("_transition_target_companion") if reason != "pop" else null
	)
	context["source_rect"] = payload.get("_transition_source_rect", Rect2())
	context["source_texture"] = payload.get("_transition_source_texture")
	context["prepare_before_motion"] = (
		reason != "pop" and bool(payload.get("_prepare_before_motion", false))
	)
	_transition_host.play(kind, context)
	if is_input_locked() or _pending_unlock:
		_pending_unlock = false
		_preparation_lock_active = is_input_locked()
		input_lock_changed.emit(_preparation_lock_active)


func _on_motion_started(kind: StringName) -> void:
	# Assets/board are now ready. The following visual entrance is not an input lock.
	if _preparation_lock_active and not is_input_locked():
		_preparation_lock_active = false
		input_lock_changed.emit(false)
	var entry := _modal_entry if not _modal_entry.is_empty() else current_screen_entry()
	if not entry.is_empty():
		transition_started.emit(entry.route, kind)


func _on_transition_settled(committed: bool) -> void:
	var transaction: Variant = _active_transaction
	_active_transaction = null
	if transaction != null:
		transaction.resolve(committed)
	if not _handoff_in_progress:
		_preparation_lock_active = false
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
	if route == &"gameplay":
		return &"gameplay_page"
	if source == "home" and route == &"themes":
		return &"home_to_themes"
	if source == "home" and route == &"levels":
		return &"home_to_levels"
	return &"screen"


func _pop_transition_kind(source: StringName, target: StringName) -> StringName:
	if source == &"gameplay" and target == &"levels":
		return &"gameplay_page"
	if source == &"themes" and target == &"home":
		return &"themes_to_home"
	if source == &"levels" and target == &"home":
		return &"levels_to_home"
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
	return {
		"ok": false, "error": String(error), "details": details, "state": debug_state_snapshot()
	}


func _emit_route_changed() -> void:
	var entry := _modal_entry if not _modal_entry.is_empty() else current_screen_entry()
	if entry.is_empty():
		return
	route_changed.emit(entry.route, entry.payload)
