extends RefCounted
## A single captured piece survives reversible scroll locking.

var origin := Vector2.ZERO
var previous := Vector2.ZERO
var active := false
var scroll_locked := false


func begin(pointer: Vector2) -> void:
	origin = pointer
	previous = pointer
	active = true
	scroll_locked = false


func advance(pointer: Vector2, area: Rect2) -> Dictionary:
	var unit := area.size.x / 402.0
	var vertical := absf(pointer.y - origin.y)
	var was_locked := scroll_locked
	if not area.has_point(pointer) or vertical >= 24.0 * unit:
		scroll_locked = true
	elif vertical <= 12.0 * unit:
		scroll_locked = false
	var changed := was_locked != scroll_locked
	var delta_x := pointer.x - previous.x if not scroll_locked and not changed else 0.0
	previous = pointer
	return {"changed": changed, "delta_x": delta_x}


func reset() -> void:
	active = false
	scroll_locked = false
	origin = Vector2.ZERO
	previous = Vector2.ZERO
