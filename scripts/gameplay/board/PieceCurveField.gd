extends RefCounted
## Cached local-space slopes for a curved printed-cardboard rim.
## RG16F stores signed dh/dx, dh/dy directly; (0, 0) is exactly flat.

const MAX_RESOLUTION := 192
const MAX_CACHE_ENTRIES := 64
const DEPTH_RATIO := 0.36
const CORNER_BLEND_RATIO := 0.24

static var _cache: Dictionary = {}
static var _lru: Array[String] = []


class EdgeData:
	extends RefCounted
	var starts := PackedVector2Array()
	var deltas := PackedVector2Array()
	var inverse_squared := PackedFloat64Array()
	var normals := PackedVector2Array()
	# Reused per bake, not allocated for every texel/candidate.
	var sample_deltas: Array[Vector2] = []


static func build(points: PackedVector2Array, width: float) -> Dictionary:
	if points.size() < 3 or width <= 0.0:
		return {"texture": null, "bounds": Rect2(), "bake_usec": 0, "cache_hit": false}
	var key := var_to_bytes([points, width]).hex_encode().sha256_text()
	if _cache.has(key):
		_lru.erase(key)
		_lru.append(key)
		var cached: Dictionary = _cache[key].duplicate()
		cached["cache_hit"] = true
		cached["bake_usec"] = 0
		return cached
	var started := Time.get_ticks_usec()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	if bounds.size.x <= 0.0001 or bounds.size.y <= 0.0001:
		return {"texture": null, "bounds": bounds, "bake_usec": 0, "cache_hit": false}
	# A small apron keeps bilinear edge samples inside the stored field.
	bounds = bounds.grow(width * 0.1)
	var longest := maxf(bounds.size.x, bounds.size.y)
	var dimensions := Vector2i(
		maxi(8, ceili(MAX_RESOLUTION * bounds.size.x / longest)),
		maxi(8, ceili(MAX_RESOLUTION * bounds.size.y / longest))
	)
	var edges := _edges(points)
	var cell_size := maxf(width * 2.0, longest / 16.0)
	var grid_size := Vector2i(ceilf(bounds.size.x / cell_size), ceilf(bounds.size.y / cell_size))
	var bins := _bins(edges, bounds, width, cell_size, grid_size)
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGH)
	image.fill(Color(0, 0, 0, 1))
	var pixel_size := bounds.size / Vector2(dimensions)
	for y in dimensions.y:
		var py := bounds.position.y + (y + 0.5) * pixel_size.y
		var row := mini(grid_size.y - 1, int((py - bounds.position.y) / cell_size))
		for x in dimensions.x:
			var px := bounds.position.x + (x + 0.5) * pixel_size.x
			var column := mini(grid_size.x - 1, int((px - bounds.position.x) / cell_size))
			var indices: Array = bins.get(row * grid_size.x + column, [])
			if indices.is_empty():
				continue
			var slope := _slope(Vector2(px, py), edges, indices, width)
			if slope != Vector2.ZERO:
				image.set_pixel(x, y, Color(slope.x, slope.y, 0, 1))
	var result := {
		"texture": ImageTexture.create_from_image(image),
		"bounds": bounds,
		"bake_usec": Time.get_ticks_usec() - started,
		"cache_hit": false,
		"resolution": dimensions,
		"rim_texels": width / maxf(pixel_size.x, pixel_size.y),
	}
	if _lru.size() >= MAX_CACHE_ENTRIES:
		_cache.erase(_lru.pop_front())
	_lru.append(key)
	_cache[key] = result
	return result.duplicate()


static func _edges(points: PackedVector2Array) -> EdgeData:
	var result := EdgeData.new()
	var winding := -1.0 if Geometry2D.is_polygon_clockwise(points) else 1.0
	for index in points.size():
		var a := points[index]
		var delta := points[(index + 1) % points.size()] - a
		if delta.length_squared() <= 0.000001:
			continue
		var direction := delta.normalized()
		result.starts.append(a)
		result.deltas.append(delta)
		result.inverse_squared.append(1.0 / delta.length_squared())
		result.normals.append(Vector2(-direction.y, direction.x) * winding)
	result.sample_deltas.resize(result.starts.size())
	return result


static func _bins(
	edges: EdgeData, bounds: Rect2, width: float, cell: float, grid: Vector2i
) -> Dictionary:
	var bins: Dictionary = {}
	for index in edges.starts.size():
		var a := edges.starts[index]
		var area := Rect2(a, Vector2.ZERO).expand(a + edges.deltas[index]).grow(
			width * (1.0 + 4.0 * CORNER_BLEND_RATIO)
		)
		var first := Vector2i((area.position - bounds.position) / cell)
		var last := Vector2i((area.end - bounds.position) / cell)
		for row in range(maxi(0, first.y), mini(grid.y - 1, last.y) + 1):
			for column in range(maxi(0, first.x), mini(grid.x - 1, last.x) + 1):
				var key := row * grid.x + column
				if not bins.has(key):
					bins[key] = []
				bins[key].append(index)
	return bins


static func _slope(point: Vector2, edges: EdgeData, indices: Array, width: float) -> Vector2:
	var nearest_squared := width * width
	var nearest := -1
	for index in indices:
		var a := edges.starts[index]
		var delta := edges.deltas[index]
		var t := clampf((point - a).dot(delta) * edges.inverse_squared[index], 0.0, 1.0)
		var sample_delta := point - (a + delta * t)
		var distance_squared := sample_delta.length_squared()
		edges.sample_deltas[index] = sample_delta
		if distance_squared < nearest_squared:
			nearest_squared = distance_squared
			nearest = index
	if nearest < 0:
		return Vector2.ZERO
	var distance := sqrt(nearest_squared)
	var blend_radius := width * CORNER_BLEND_RATIO
	var normal_sum := Vector2.ZERO
	var weight_sum := 0.0
	for index in indices:
		var delta := edges.sample_deltas[index]
		var candidate_distance := delta.length()
		if candidate_distance > distance + blend_radius * 4.0:
			continue
		var weight := exp(-(candidate_distance - distance) / blend_radius)
		var normal: Vector2 = (
			delta / candidate_distance if candidate_distance > 0.000001 else edges.normals[index]
		)
		normal_sum += normal * weight
		weight_sum += weight
	# Do not normalize the blend: sharp tips should soften, not form a dark V.
	var normal := normal_sum / maxf(0.000001, weight_sum)
	# h=H(2t-t²), H=.36w: dh/dd=.72(1-t), reaching zero continuously.
	var t := distance / width
	return normal * (2.0 * DEPTH_RATIO * (1.0 - t))
