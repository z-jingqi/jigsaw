extends RefCounted
## A single captured piece survives reversible scroll locking.

const PuzzleRulesScript := preload("res://scripts/config/PuzzleRules.gd")

var origin := Vector2.ZERO
var previous := Vector2.ZERO
var active := false
var scroll_locked := false
var config: Dictionary = PuzzleRulesScript.tray_layout()


func begin(pointer: Vector2) -> void:
	origin = pointer
	previous = pointer
	active = true
	scroll_locked = false


func advance(pointer: Vector2, area: Rect2) -> Dictionary:
	var unit := area.size.x / float(config["reference_width"])
	var vertical := absf(pointer.y - origin.y)
	var was_locked := scroll_locked
	if (
		not area.has_point(pointer)
		or vertical >= float(config["scroll_lock_distance_units"]) * unit
	):
		scroll_locked = true
	elif vertical <= float(config["scroll_unlock_distance_units"]) * unit:
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
