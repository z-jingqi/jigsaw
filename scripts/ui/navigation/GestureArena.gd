extends RefCounted
## One pointer candidate/owner per viewport. A gesture never changes its purpose.

static var _owners: Dictionary = {}
static var _quarantined: Dictionary = {}


static func block_secondary(viewport: Viewport, event: InputEvent) -> bool:
	var key := viewport.get_instance_id()
	var current := _current(key)
	var pointer := -2
	var pressed := false
	var released := false
	if event is InputEventScreenTouch:
		pointer = event.index
		pressed = event.pressed and not event.canceled
		released = not event.pressed or event.canceled
	elif event is InputEventScreenDrag:
		pointer = event.index
	elif event is InputEventMouse:
		pointer = -1
		if event is InputEventMouseButton:
			pressed = event.pressed
			released = not event.pressed
	else:
		return not current.is_empty() and event is InputEventKey
	var blocked: Dictionary = _quarantined.get(key, {})
	if blocked.has(pointer):
		if released:
			blocked.erase(pointer)
		_quarantined[key] = blocked
		return true
	if not current.is_empty() and int(current.pointer) != pointer:
		var owner: Node = current.owner.get_ref()
		if (
			is_instance_valid(owner)
			and owner.has_method("gesture_accepts_secondary")
			and owner.gesture_accepts_secondary(pointer, event)
		):
			return false
		if pressed:
			blocked[pointer] = true
			_quarantined[key] = blocked
		return true
	return false


static func reserve(owner: Node, pointer: int) -> bool:
	var key := owner.get_viewport().get_instance_id()
	var current := _current(key)
	if not current.is_empty():
		return current.owner.get_ref() == owner and int(current.pointer) == pointer
	_owners[key] = {"owner": weakref(owner), "pointer": pointer}
	return true


static func owns(owner: Node, pointer: int) -> bool:
	var current := _current(owner.get_viewport().get_instance_id())
	return (
		not current.is_empty()
		and current.owner.get_ref() == owner
		and int(current.pointer) == pointer
	)


static func release(owner: Node) -> void:
	# A parent exit hook may release a child after it has left the viewport.
	if owner.get_viewport() == null:
		for existing_key in _owners.keys():
			var entry: Dictionary = _owners[existing_key]
			if entry.owner.get_ref() == owner:
				_owners.erase(existing_key)
		return
	var key := owner.get_viewport().get_instance_id()
	var current := _current(key)
	if not current.is_empty() and current.owner.get_ref() == owner:
		_owners.erase(key)


static func is_edge_candidate(owner: Node, point: Vector2, native_scale: float) -> bool:
	for edge in owner.get_tree().get_nodes_in_group("runtime_edge_back"):
		if edge.get_viewport() == owner.get_viewport() and edge.can_start_edge(point, native_scale):
			return true
	return false


static func _current(key: int) -> Dictionary:
	var current: Dictionary = _owners.get(key, {})
	if current.is_empty():
		return {}
	var owner: Node = current.owner.get_ref()
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		_owners.erase(key)
		return {}
	return current
