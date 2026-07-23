class_name LevelUnlockSequence
extends RefCounted

const UnlockSequenceScene := preload("res://scenes/ui/foundation/UnlockSequence.tscn")

var _active: Dictionary = {}


func play(card: Control, reduced_motion: bool) -> void:
	var level_id := str(card.get("level_id"))
	if level_id.is_empty() or _active.has(level_id):
		return
	var sequence := UnlockSequenceScene.instantiate()
	sequence.name = "unlock_outline"
	card.add_child(sequence)
	_active[level_id] = {"card": card, "sequence": sequence}
	sequence.finished.connect(_finish.bind(level_id, card, sequence), CONNECT_ONE_SHOT)
	sequence.play(reduced_motion)


func cancel(card: Control) -> void:
	var level_id := str(card.get("level_id"))
	var active: Dictionary = _active.get(level_id, {})
	if not active.is_empty():
		_finish(level_id, card, active.get("sequence"))


func clear() -> void:
	for level_id in _active.keys().duplicate():
		var active: Dictionary = _active[level_id]
		_finish(str(level_id), active.get("card"), active.get("sequence"))


func active_count() -> int:
	return _active.size()


func _finish(level_id: String, card: Control, sequence: Node) -> void:
	_active.erase(level_id)
	if is_instance_valid(card):
		card.scale = Vector2.ONE
	if is_instance_valid(sequence):
		sequence.queue_free()
