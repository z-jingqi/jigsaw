class_name AppRouteDefinition
extends RefCounted

enum Presentation {
	ROOT,
	SCREEN,
	MODAL,
	OVERLAY,
}

var route_id: StringName
var presentation: int
var scene: PackedScene
var required_fields: Dictionary
var optional_defaults: Dictionary
var allowed_values: Dictionary


func _init(
	p_route_id: StringName,
	p_presentation: int,
	p_required_fields: Dictionary = {},
	p_optional_defaults: Dictionary = {},
	p_allowed_values: Dictionary = {}
) -> void:
	route_id = p_route_id
	presentation = p_presentation
	required_fields = p_required_fields.duplicate(true)
	optional_defaults = p_optional_defaults.duplicate(true)
	allowed_values = p_allowed_values.duplicate(true)


func bind_scene(p_scene: PackedScene) -> void:
	scene = p_scene


func validate_payload(payload: Dictionary) -> Dictionary:
	var normalized := optional_defaults.duplicate(true)
	for key in payload:
		normalized[key] = payload[key]
	for field in required_fields:
		if not normalized.has(field):
			return _invalid("missing_%s" % field)
		if typeof(normalized[field]) != int(required_fields[field]):
			return _invalid("invalid_%s" % field)
	for field in optional_defaults:
		if typeof(normalized[field]) != typeof(optional_defaults[field]):
			return _invalid("invalid_%s" % field)
	for field in allowed_values:
		if not normalized.has(field):
			continue
		var allowed: Array = allowed_values[field]
		if not allowed.has(String(normalized[field])):
			return _invalid("invalid_%s" % field)
	return {"ok": true, "payload": normalized}


func _invalid(reason: String) -> Dictionary:
	return {
		"ok": false,
		"error": "invalid_payload",
		"reason": reason,
	}
