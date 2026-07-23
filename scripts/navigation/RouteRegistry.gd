class_name AppRouteRegistry
extends RefCounted

const RouteDefinitionScript := preload("res://scripts/navigation/RouteDefinition.gd")

var _definitions: Dictionary = {}


func _init() -> void:
	_register_runtime_contracts()


func register_definition(definition: Variant) -> void:
	_definitions[definition.route_id] = definition


func bind_scene(route_id: StringName, scene: PackedScene) -> Dictionary:
	var definition: Variant = get_definition(route_id)
	if definition == null:
		return {"ok": false, "error": "unknown_route"}
	definition.bind_scene(scene)
	return {"ok": true}


func get_definition(route_id: StringName) -> Variant:
	return _definitions.get(route_id)


func validate(route_id: StringName, payload: Dictionary) -> Dictionary:
	var definition: Variant = get_definition(route_id)
	if definition == null:
		return {"ok": false, "error": "unknown_route"}
	var validation: Dictionary = definition.validate_payload(payload)
	if not bool(validation.get("ok", false)):
		return validation
	if definition.scene == null:
		return {"ok": false, "error": "not_found", "route": String(route_id)}
	return {
		"ok": true,
		"definition": definition,
		"payload": validation["payload"],
	}


func contracts() -> Array[StringName]:
	var result: Array[StringName] = []
	for route_id in _definitions:
		result.append(route_id)
	return result


func _register_runtime_contracts() -> void:
	register_definition(RouteDefinitionScript.new(&"home", RouteDefinitionScript.Presentation.ROOT, {}, {"theme_id": ""}))
	register_definition(RouteDefinitionScript.new(&"all_themes", RouteDefinitionScript.Presentation.SCREEN, {"current_theme_id": TYPE_STRING}))
	register_definition(RouteDefinitionScript.new(&"levels", RouteDefinitionScript.Presentation.SCREEN, {"theme_id": TYPE_STRING}, {"focus_level_id": ""}))
	register_definition(RouteDefinitionScript.new(
		&"gameplay",
		RouteDefinitionScript.Presentation.SCREEN,
		{"theme_id": TYPE_STRING, "level_id": TYPE_STRING, "mode": TYPE_STRING, "start_policy": TYPE_STRING},
		{},
		{"mode": ["polygon", "knob", "swap"], "start_policy": ["start", "resume", "replay"]}
	))
	register_definition(RouteDefinitionScript.new(&"mode_select", RouteDefinitionScript.Presentation.MODAL, {"theme_id": TYPE_STRING, "level_id": TYPE_STRING}))
	register_definition(RouteDefinitionScript.new(&"settings", RouteDefinitionScript.Presentation.MODAL))
	register_definition(RouteDefinitionScript.new(&"home_guide", RouteDefinitionScript.Presentation.OVERLAY, {}, {"initial_step": "swipe"}))
	register_definition(RouteDefinitionScript.new(
		&"mode_tutorial",
		RouteDefinitionScript.Presentation.OVERLAY,
		{"mode": TYPE_STRING},
		{},
		{"mode": ["polygon", "knob", "swap"]}
	))
	register_definition(RouteDefinitionScript.new(
		&"completion",
		RouteDefinitionScript.Presentation.MODAL,
		{"theme_id": TYPE_STRING, "level_id": TYPE_STRING, "mode": TYPE_STRING, "completion_event_id": TYPE_STRING},
		{},
		{"mode": ["polygon", "knob", "swap"]}
	))
