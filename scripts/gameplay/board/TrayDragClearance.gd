extends RefCounted
## Stable carrying offset; return only when the piece body moves into the tray.

const PuzzleRulesScript := preload("res://scripts/config/PuzzleRules.gd")

var active := false
var lifted := false
var offset := Vector2.ZERO
var target_offset := Vector2.ZERO
var _velocity_y := 0.0
var _lift_distance := 0.0
var _top_from_pointer := 0.0
var _center_from_pointer := Vector2.ZERO
var _previous_pointer := Vector2.ZERO
var _unit := 1.0
var _config: Dictionary = PuzzleRulesScript.tray_layout()


func begin(bounds: Rect2, grab: Vector2, screen_scale: float, area: Rect2) -> void:
	reset()
	active = true
	_unit = area.size.x / float(_config["reference_width"])
	_top_from_pointer = (bounds.position.y - grab.y) * screen_scale
	_center_from_pointer = (bounds.get_center() - grab) * screen_scale
	var clearance := float(_config["drag_clearance_units"]) * _unit
	_lift_distance = maxf(clearance, (bounds.end.y - grab.y) * screen_scale + clearance)


func update_pointer(pointer: Vector2, area: Rect2, reduced_motion: bool) -> void:
	if not active:
		return
	if not lifted:
		lifted = not area.grow(float(_config["drag_exit_margin_units"]) * _unit).has_point(pointer)
	else:
		# Use the carried pose rather than the spring's transient position. The
		# finger may enter the tray while aligning the board's lowest pieces.
		var center := pointer + _center_from_pointer + Vector2(0.0, -_lift_distance)
		var return_area := area.grow(-float(_config["drag_reentry_margin_units"]) * _unit)
		if pointer.y > _previous_pointer.y and return_area.has_point(center):
			lifted = false
	_previous_pointer = pointer
	# Only the top screen boundary can reduce clearance while carrying.
	var available := maxf(0.0, pointer.y + _top_from_pointer - 8.0 * _unit)
	target_offset.y = -minf(_lift_distance, available) if lifted else 0.0
	if reduced_motion:
		offset = target_offset
		_velocity_y = 0.0


func step(delta: float, reduced_motion: bool) -> bool:
	if not active:
		return false
	var previous := offset.y
	if reduced_motion:
		offset = target_offset
		_velocity_y = 0.0
	else:
		# Analytic critically damped spring: reversals retain both position and velocity.
		var frequency := 6.64 / float(_config["drag_lift_settle_time"])
		var displacement := offset.y - target_offset.y
		var coefficient := _velocity_y + frequency * displacement
		var decay := exp(-frequency * maxf(0.0, delta))
		offset.y = target_offset.y + (displacement + coefficient * delta) * decay
		_velocity_y = (_velocity_y - frequency * coefficient * delta) * decay
		if absf(offset.y - target_offset.y) < 0.05 and absf(_velocity_y) < 0.5:
			offset = target_offset
			_velocity_y = 0.0
	return not is_equal_approx(previous, offset.y)


func reset() -> void:
	active = false
	lifted = false
	offset = Vector2.ZERO
	target_offset = Vector2.ZERO
	_velocity_y = 0.0
	_lift_distance = 0.0
	_top_from_pointer = 0.0
	_center_from_pointer = Vector2.ZERO
	_previous_pointer = Vector2.ZERO
