extends RefCounted
## One shaftless left chevron; rotate for other navigation directions.


static func points(center: Vector2, radius: float, angle: float = 0.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in [Vector2(0.45, -0.9), Vector2(-0.45, 0), Vector2(0.45, 0.9)]:
		result.append(center + (point * radius).rotated(angle))
	return result
