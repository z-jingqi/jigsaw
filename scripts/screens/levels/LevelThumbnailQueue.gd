class_name LevelThumbnailQueue
extends RefCounted

## Keep cold image decoding and resizing out of the grid construction frame.
var _host: Control
var _pending: Array[Dictionary] = []
var _scheduled := false
var _generation := 0


func _init(host: Control) -> void:
	_host = host


func request(card: LevelCard) -> void:
	if not is_instance_valid(card) or not card.needs_thumbnail():
		return
	cancel(card)
	_pending.append({"card": weakref(card), "level_id": card.level_id})
	_schedule_next_frame()


func cancel(card: Control) -> void:
	for index in range(_pending.size() - 1, -1, -1):
		if (_pending[index].card as WeakRef).get_ref() == card:
			_pending.remove_at(index)


func clear() -> void:
	_generation += 1
	_pending.clear()
	_scheduled = false


func pending_count() -> int:
	return _pending.size()


func _schedule_next_frame() -> void:
	if _scheduled or _pending.is_empty():
		return
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		clear()
		return
	_scheduled = true
	_host.get_tree().process_frame.connect(_load_next.bind(_generation), CONNECT_ONE_SHOT)


func _load_next(generation: int) -> void:
	if generation != _generation:
		return
	_scheduled = false
	while not _pending.is_empty():
		var request_data: Dictionary = _pending.pop_front()
		var card := (request_data.card as WeakRef).get_ref() as LevelCard
		if not is_instance_valid(card) or not card.is_inside_tree():
			continue
		if card.level_id != str(request_data.level_id) or not card.needs_thumbnail():
			continue
		card.load_pending_thumbnail()
		break
	_schedule_next_frame()
