extends RefCounted
class_name SnapSolver


static func find_match(active, others: Array, snap_tolerance: float, rotation_tolerance: float):
	var match := find_match_data(active, others, snap_tolerance, rotation_tolerance)
	return match.get("other", null)


static func find_match_data(active, others: Array, snap_tolerance: float, rotation_tolerance: float) -> Dictionary:
	var best := {}
	var best_distance := INF
	for other in others:
		if other == active:
			continue
		if _rotation_delta_abs(active.node.rotation_degrees, other.node.rotation_degrees) > rotation_tolerance:
			continue
		var candidate := _closest_neighbor_match(active, other)
		if candidate.is_empty():
			continue
		var distance := float(candidate["distance"])
		if distance <= snap_tolerance and distance < best_distance:
			best_distance = distance
			best = candidate
			best["other"] = other
	return best


static func _groups_can_snap(a, b, snap_tolerance: float) -> bool:
	var match := _closest_neighbor_match(a, b)
	return not match.is_empty() and float(match["distance"]) <= snap_tolerance


static func _closest_neighbor_match(a, b) -> Dictionary:
	var best := {}
	var best_distance := INF
	for am in a.members:
		for bm in b.members:
			if not _are_declared_neighbors(am, bm):
				continue
			var expected: Vector2 = (bm["home"] - am["home"]).rotated(a.node.rotation)
			var a_anchor: Vector2 = a.node.position + am["visual"].position.rotated(a.node.rotation)
			var b_anchor: Vector2 = b.node.position + bm["visual"].position.rotated(b.node.rotation)
			var actual: Vector2 = b_anchor - a_anchor
			var correction := actual - expected
			var distance := correction.length()
			if distance < best_distance:
				best_distance = distance
				best = {
					"active_member": am,
					"other_member": bm,
					"correction": correction,
					"distance": distance,
				}
	return best


static func _are_declared_neighbors(a_member: Dictionary, b_member: Dictionary) -> bool:
	return a_member["neighbors"].has(b_member["id"]) or b_member["neighbors"].has(a_member["id"])


static func _rotation_delta_abs(a_degrees: float, b_degrees: float) -> float:
	var delta := fposmod(a_degrees - b_degrees + 180.0, 360.0) - 180.0
	return abs(delta)
