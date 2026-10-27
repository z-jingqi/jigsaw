class_name SessionRepository
extends RefCounted

signal changed(snapshot: Dictionary, revision: int)

const SCHEMA_VERSION := 1
const STATE_VERSION := 1
const DEFAULT_PATH := "user://jigcat/session_v1.json"
const PLAY_MODES := ["polygon", "knob", "swap"]

var _store: AtomicJsonStore
var _path: String
var _data := _defaults()
var _revision := 0


func _init(store: AtomicJsonStore = null, path: String = DEFAULT_PATH) -> void:
	_store = store if store != null else AtomicJsonStore.new()
	_path = path


func load() -> void:
	_data = _validated(_store.load_validated_dictionary(_path, validate_storage))
	_revision += 1
	changed.emit(snapshot(), _revision)


func flush() -> Dictionary:
	if _store.has_method(&"flush"):
		return _store.call(&"flush")
	return {"ok": true}


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func current() -> Dictionary:
	return (_data["current"] as Dictionary).duplicate(true)


func has_stored_play_state(theme_id: String, level_id: String, mode: String) -> bool:
	return not (
		(_data["play_states"] as Dictionary)
		. get(_state_key(theme_id, level_id, mode), {})
		. is_empty()
	)


func set_current(theme_id: String, level_id: String = "", mode: String = "") -> Dictionary:
	if theme_id.is_empty() or (not mode.is_empty() and not PLAY_MODES.has(mode)):
		return {"ok": false, "error": "invalid_argument"}
	var next_data := _data.duplicate(true)
	next_data["current"] = {"theme_id": theme_id, "level_id": level_id, "mode": mode}
	return _commit(next_data)


func play_state(
	theme_id: String, level_id: String, mode: String, piece_ids: Array[String] = []
) -> Dictionary:
	var state: Dictionary = (_data["play_states"] as Dictionary).get(
		_state_key(theme_id, level_id, mode), {}
	)
	if _is_valid_state(state, piece_ids):
		return state.duplicate(true)
	# A read with a different catalog fingerprint must not destroy a saved game.
	# Explicit clear/save operations remain the only mutations.
	return {}


func peek_play_state(
	theme_id: String, level_id: String, mode: String, piece_ids: Array[String]
) -> Dictionary:
	# Preparing a mode is a read-only preview; invalid old saves are left intact.
	var state: Dictionary = (_data["play_states"] as Dictionary).get(
		_state_key(theme_id, level_id, mode), {}
	)
	return state.duplicate(true) if _is_valid_state(state, piece_ids) else {}


func save_play_state(state: Dictionary, piece_ids: Array[String]) -> Dictionary:
	if not _is_valid_state(state, piece_ids):
		return {"ok": false, "error": "invalid_play_state"}
	var next_data := _data.duplicate(true)
	var states: Dictionary = next_data["play_states"]
	states[_state_key(str(state["theme_id"]), str(state["level_id"]), str(state["mode"]))] = (
		state.duplicate(true)
	)
	next_data["play_states"] = states
	next_data["current"] = {
		"theme_id": state["theme_id"], "level_id": state["level_id"], "mode": state["mode"]
	}
	return _commit(next_data)


func clear_play_state(theme_id: String, level_id: String, mode: String) -> Dictionary:
	var next_data := _data.duplicate(true)
	var states: Dictionary = next_data["play_states"]
	if not states.has(_state_key(theme_id, level_id, mode)):
		return {"ok": true, "changed": false}
	states.erase(_state_key(theme_id, level_id, mode))
	next_data["play_states"] = states
	return _commit(next_data)


static func _is_valid_state(state: Dictionary, piece_ids: Array[String]) -> bool:
	if int(state.get("state_version", -1)) != STATE_VERSION:
		return false
	if str(state.get("theme_id", "")).is_empty() or str(state.get("level_id", "")).is_empty():
		return false
	var mode := str(state.get("mode", ""))
	var expected_fingerprint := _expected_fingerprint(piece_ids)
	if (
		not PLAY_MODES.has(mode)
		or expected_fingerprint.is_empty()
		or str(state.get("piece_set_fingerprint", "")) != expected_fingerprint
	):
		return false
	if mode == "swap":
		if typeof(state.get("slot_piece_ids")) != TYPE_ARRAY:
			return false
		var slots: Array = state.slot_piece_ids
		return (
			str(state.get("kind", "")) == "swap" and _is_exact_piece_permutation(slots, piece_ids)
		)
	if (
		typeof(state.get("connected_groups")) != TYPE_ARRAY
		or typeof(state.get("tray_order")) != TYPE_ARRAY
	):
		return false
	var groups: Array = state.connected_groups
	var tray: Array = state.tray_order
	return str(state.get("kind", "")) == "assembly" and _is_valid_assembly(groups, tray, piece_ids)


static func _is_exact_piece_permutation(values: Array, piece_ids: Array[String]) -> bool:
	if piece_ids.is_empty() or values.size() != piece_ids.size():
		return false
	var seen := {}
	for value in values:
		if typeof(value) != TYPE_STRING or not piece_ids.has(value) or seen.has(value):
			return false
		seen[value] = true
	return true


static func _is_valid_assembly(groups: Array, tray: Array, piece_ids: Array[String]) -> bool:
	if piece_ids.is_empty():
		return false
	var seen := {}
	for group in groups:
		if typeof(group) != TYPE_ARRAY or group.is_empty():
			return false
		for piece_id in group:
			if typeof(piece_id) != TYPE_STRING or not piece_ids.has(piece_id) or seen.has(piece_id):
				return false
			seen[piece_id] = true
	for piece_id in tray:
		if typeof(piece_id) != TYPE_STRING or not piece_ids.has(piece_id) or seen.has(piece_id):
			return false
		seen[piece_id] = true
	return seen.size() == piece_ids.size()


static func _expected_fingerprint(piece_ids: Array[String]) -> String:
	if piece_ids.is_empty():
		return ""
	var seen := {}
	var ordered: Array[String] = []
	for piece_id in piece_ids:
		if piece_id.is_empty() or seen.has(piece_id):
			return ""
		seen[piece_id] = true
		ordered.append(piece_id)
	ordered.sort()
	return "|".join(ordered)


func _commit(next_data: Dictionary) -> Dictionary:
	if next_data == _data:
		return {"ok": true, "changed": false}
	var saved := _store.write_dictionary(_path, next_data)
	if not bool(saved.get("ok", false)):
		return saved
	_data = next_data
	_revision += 1
	changed.emit(snapshot(), _revision)
	return {"ok": true, "changed": true}


func _validated(value: Dictionary) -> Dictionary:
	if int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		return _defaults()
	var result := _defaults()
	if typeof(value.get("current")) == TYPE_DICTIONARY:
		var source_current: Dictionary = value["current"]
		var theme_id: Variant = source_current.get("theme_id", "")
		var level_id: Variant = source_current.get("level_id", "")
		var mode: Variant = source_current.get("mode", "")
		if (
			typeof(theme_id) == TYPE_STRING
			and typeof(level_id) == TYPE_STRING
			and typeof(mode) == TYPE_STRING
			and (mode.is_empty() or PLAY_MODES.has(mode))
		):
			result["current"] = {"theme_id": theme_id, "level_id": level_id, "mode": mode}
	if typeof(value.get("play_states")) == TYPE_DICTIONARY:
		var states: Dictionary = {}
		for key in value["play_states"] as Dictionary:
			var state: Variant = value["play_states"][key]
			if (
				typeof(key) == TYPE_STRING
				and typeof(state) == TYPE_DICTIONARY
				and _has_required_state_shape(state)
			):
				states[key] = state
		result["play_states"] = states
	return result


func _has_required_state_shape(state: Dictionary) -> bool:
	return (
		int(state.get("state_version", -1)) == STATE_VERSION
		and typeof(state.get("theme_id")) == TYPE_STRING
		and typeof(state.get("level_id")) == TYPE_STRING
		and typeof(state.get("mode")) == TYPE_STRING
		and PLAY_MODES.has(str(state.get("mode", "")))
		and typeof(state.get("piece_set_fingerprint")) == TYPE_STRING
	)


func _state_key(theme_id: String, level_id: String, mode: String) -> String:
	return "%s/%s:%s" % [theme_id, level_id, mode]


func _defaults() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "current": {}, "play_states": {}}


func load_status() -> Dictionary:
	return _store.load_status(_path)


static func validate_storage(value: Dictionary) -> String:
	if typeof(value.get("schema_version")) not in [TYPE_INT, TYPE_FLOAT]:
		return "invalid_structure"
	if float(value.schema_version) != SCHEMA_VERSION:
		return "unsupported_schema"
	if typeof(value.get("current")) != TYPE_DICTIONARY:
		return "invalid_structure"
	if typeof(value.get("play_states")) != TYPE_DICTIONARY:
		return "invalid_structure"
	for key in value.current:
		if key in ["theme_id", "level_id", "mode"] and typeof(value.current[key]) != TYPE_STRING:
			return "invalid_structure"
	for key in value.play_states:
		var state: Variant = value.play_states[key]
		if typeof(key) != TYPE_STRING or not state is Dictionary:
			return "invalid_structure"
		if typeof(state.get("state_version")) not in [TYPE_INT, TYPE_FLOAT]:
			return "invalid_structure"
		if float(state.state_version) != STATE_VERSION:
			return "unsupported_schema"
		for field in ["theme_id", "level_id", "mode", "piece_set_fingerprint"]:
			if typeof(state.get(field)) != TYPE_STRING:
				return "invalid_structure"

		var ids: Array[String] = []
		for id in state.piece_set_fingerprint.split("|"):
			ids.append(id)
		if not _is_valid_state(state, ids):
			return "invalid_structure"
		if key != "%s/%s:%s" % [state.theme_id, state.level_id, state.mode]:
			return "invalid_structure"

	return ""
