extends RefCounted
class_name SnapSolver


static func find_match(active, others: Array, snap_tolerance: float, rotation_tolerance: float):
	for other in others:
		if other == active:
			continue
		if _rotation_delta_abs(active.node.rotation_degrees, other.node.rotation_degrees) > rotation_tolerance:
			continue
		if _groups_can_snap(active, other, snap_tolerance):
			return other
	return null


static func _groups_can_snap(a, b, snap_tolerance: float) -> bool:
	for am in a.members:
		for bm in b.members:
			if not _are_declared_neighbors(am, bm):
				continue
			var expected: Vector2 = (bm["home"] - am["home"]).rotated(a.node.rotation)
			var actual: Vector2 = b.node.to_global(bm["visual"].position) - a.node.to_global(am["visual"].position)
			if actual.distance_to(expected) <= snap_tolerance:
				return true
	return false


static func _are_declared_neighbors(a_member: Dictionary, b_member: Dictionary) -> bool:
	return a_member["neighbors"].has(b_member["id"]) or b_member["neighbors"].has(a_member["id"])


static func _rotation_delta_abs(a_degrees: float, b_degrees: float) -> float:
	var delta := fposmod(a_degrees - b_degrees + 180.0, 360.0) - 180.0
	return abs(delta)
