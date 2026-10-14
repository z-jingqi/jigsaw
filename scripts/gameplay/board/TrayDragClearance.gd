extends RefCounted
## Finger clearance with separate exit/reentry thresholds and continuous motion.

const PuzzleRulesScript := preload("res://scripts/config/PuzzleRules.gd")

var active := false
var lifted := false
var offset := Vector2.ZERO
var target_offset := Vector2.ZERO
var _velocity_y := 0.0
var _lift_distance := 0.0
var _top_from_pointer := 0.0
var _unit := 1.0
var _config: Dictionary = PuzzleRulesScript.tray_layout()


func begin(bounds: Rect2, grab: Vector2, screen_scale: float, area: Rect2) -> void:
	reset()
	active = true
	_unit = area.size.x / float(_config["reference_width"])
	_top_from_pointer = (bounds.position.y - grab.y) * screen_scale
	var clearance := float(_config["drag_clearance_units"]) * _unit
	_lift_distance = maxf(clearance, (bounds.end.y - grab.y) * screen_scale + clearance)


func update_pointer(pointer: Vector2, area: Rect2, reduced_motion: bool) -> void:
	if not active:
		return
	if not lifted:
		lifted = not area.grow(float(_config["drag_exit_margin_units"]) * _unit).has_point(pointer)
	elif area.grow(-float(_config["drag_reentry_margin_units"]) * _unit).has_point(pointer):
		lifted = false
	# Reduce clearance near the top of the screen instead of lifting farther out of view.
	var available := maxf(0.0, pointer.y + _top_from_pointer - 8.0 * _unit)
	if pointer.x >= area.position.x and pointer.x <= area.end.x and pointer.y <= area.end.y:
		# A fixed lift can put the finger back in the tray before a bottom-row
		# piece reaches its home. Taper only near the tray's upper edge so every
		# placement remains reachable, keeping the same continuous spring.
		var edge_ratio := float(_config["drag_lift_tray_edge_ratio"])
		available = minf(available, maxf(0.0, area.position.y - pointer.y) * edge_ratio)
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
