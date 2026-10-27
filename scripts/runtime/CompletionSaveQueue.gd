extends RefCounted
## Failed completion writes keep their immutable context until a confirmed retry.
var _services: AppServices
var _pending: Dictionary = {}


func _init(services: AppServices) -> void:
	_services = services


func submit(context: Dictionary, board_state: Dictionary, piece_ids: Array[String]) -> Dictionary:
	var event_id := str(context.completion_event_id)
	# Re-entering the same solved board after a failed write replaces its pending
	# event, rather than retaining another copy of the full recovery snapshot.
	for pending_id in _pending.keys():
		var previous: Dictionary = _pending[pending_id].context
		if (
			previous.theme_id == context.theme_id
			and previous.level_id == context.level_id
			and previous.mode == context.mode
		):
			_pending.erase(pending_id)
	_pending[event_id] = {
		"context": context.duplicate(true),
		"board_state": board_state.duplicate(true),
		"piece_ids": piece_ids.duplicate(),
		"recovery_saved": false,
	}
	return retry(event_id)


func has_pending(event_id: String) -> bool:
	return _pending.has(event_id)


func recovery_saved(event_id: String) -> bool:
	return bool((_pending.get(event_id, {}) as Dictionary).get("recovery_saved", false))


func retry(event_id: String) -> Dictionary:
	if not _pending.has(event_id):
		return {"ok": true, "unchanged": true}
	var entry: Dictionary = _pending[event_id]
	var context: Dictionary = entry.context
	var result := _services.complete_mode(context.theme_id, context.level_id, context.mode)
	if bool(result.get("ok", false)):
		_pending.erase(event_id)
		return result
	# The solved board is a valid v1 play state, not a new save schema. When
	# progress alone is unavailable, resume can reconstruct and retry completion.
	var recovery := _services.session.save_play_state(entry.board_state, entry.piece_ids)
	if bool(recovery.get("ok", false)):
		recovery = _services.session.flush()
	entry.recovery_saved = bool(recovery.get("ok", false))
	entry.error = str(result.get("error", "save_failed"))
	return {"ok": false, "error": entry.error, "recovery_saved": entry.recovery_saved}


func retry_pending() -> void:
	for event_id in _pending.keys():
		retry(str(event_id))


func snapshot() -> Dictionary:
	var result := {}
	for event_id in _pending:
		var entry: Dictionary = _pending[event_id]
		result[event_id] = {
			"context": entry.context.duplicate(true),
			"recovery_saved": entry.recovery_saved,
			"error": entry.get("error", ""),
		}
	return result
