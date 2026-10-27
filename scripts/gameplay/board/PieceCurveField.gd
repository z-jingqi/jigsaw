extends RefCounted
## Cached local-space slopes for a curved printed-cardboard rim.
## RG16F stores signed dh/dx, dh/dy directly; (0, 0) is exactly flat.

const MAX_RESOLUTION := 192
const MAX_CACHE_ENTRIES := 64
const DEPTH_RATIO := 0.36
const CORNER_BLEND_RATIO := 0.24
const CACHE_VERSION := 2
const CACHE_DIR := "user://curve_fields"
const MAX_DISK_BYTES := 12 * 1024 * 1024
const MAX_HEADER_BYTES := 2048
const MAX_RECORD_BYTES := MAX_RESOLUTION * MAX_RESOLUTION * 4 + 4096

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


static func key_for(points: PackedVector2Array, width: float) -> String:
	return (
		var_to_bytes(
			[CACHE_VERSION, MAX_RESOLUTION, DEPTH_RATIO, CORNER_BLEND_RATIO, points, width]
		)
		. hex_encode()
		. sha256_text()
	)


static func get_cached(points: PackedVector2Array, width: float) -> Dictionary:
	# Main-thread texture cache only. Workers must use bake_data().
	var key := key_for(points, width)
	if not _cache.has(key):
		return {}
	_lru.erase(key)
	_lru.append(key)
	var cached: Dictionary = _cache[key].duplicate()
	cached["cache_hit"] = true
	cached["bake_usec"] = 0
	return cached


static func publish(points: PackedVector2Array, width: float, data: Dictionary) -> Dictionary:
	# GPU resource publication belongs exclusively to the main thread.
	var key := key_for(points, width)
	var image := data.get("image") as Image
	if data.get("cancelled", false) or image == null or data.get("key", "") != key:
		return {}
	var result := data.duplicate()
	result.erase("image")
	result["texture"] = ImageTexture.create_from_image(image)
	result["cache_hit"] = false
	_lru.erase(key)
	if _lru.size() >= MAX_CACHE_ENTRIES:
		_cache.erase(_lru.pop_front())
	_lru.append(key)
	_cache[key] = result
	return result.duplicate()


static func build(points: PackedVector2Array, width: float) -> Dictionary:
	var cached := get_cached(points, width)
	return cached if not cached.is_empty() else publish(points, width, bake_data(points, width))


static func bake_data(
	points: PackedVector2Array, width: float, cancel_probe: Callable = Callable()
) -> Dictionary:
	# Pure CPU data path: one local Image, no scene access, textures, or memory LRU.
	if _cancelled(cancel_probe):
		return {"image": null, "cancelled": true}
	if points.size() < 3 or width <= 0.0 or not is_finite(width):
		return {"image": null, "bounds": Rect2(), "cancelled": false}
	var key := key_for(points, width)
	var started := Time.get_ticks_usec()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		if not point.is_finite():
			return {"image": null, "cancelled": false}
		bounds = bounds.expand(point)
	if bounds.size.x <= 0.0001 or bounds.size.y <= 0.0001:
		return {"image": null, "bounds": bounds, "bake_usec": 0, "cancelled": false}
	# A small apron keeps bilinear edge samples inside the stored field.
	bounds = bounds.grow(width * 0.1)
	var longest := maxf(bounds.size.x, bounds.size.y)
	var dimensions := Vector2i(
		maxi(8, ceili(MAX_RESOLUTION * bounds.size.x / longest)),
		maxi(8, ceili(MAX_RESOLUTION * bounds.size.y / longest))
	)
	var disk := _read_disk(key, bounds, dimensions)
	if _cancelled(cancel_probe):
		return {"image": null, "cancelled": true}
	if not disk.is_empty():
		disk["bake_usec"] = Time.get_ticks_usec() - started
		return disk
	var edges := _edges(points)
	# Fine conservative cells avoid projecting every texel onto distant knob
	# samples. Keep the complete original blend support, in original edge order.
	var cell_size := maxf(width * 0.5, longest / 64.0)
	var grid_size := Vector2i(ceilf(bounds.size.x / cell_size), ceilf(bounds.size.y / cell_size))
	var bins := _bins(edges, bounds, width * (1.0 + 4.0 * CORNER_BLEND_RATIO), cell_size, grid_size)
	# Beyond the nearest-edge rim the exact field is zero; skip those cells
	# without evaluating the wider corner-blend candidates at every texel.
	var near_bins := _bins(edges, bounds, width, cell_size, grid_size)
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGH)
	image.fill(Color(0, 0, 0, 1))
	var pixel_size := bounds.size / Vector2(dimensions)
	var empty_indices := PackedInt32Array()
	for y in dimensions.y:
		if _cancelled(cancel_probe):
			return {"image": null, "cancelled": true}
		var py := bounds.position.y + (y + 0.5) * pixel_size.y
		var row := mini(grid_size.y - 1, int((py - bounds.position.y) / cell_size))
		for x in dimensions.x:
			var px := bounds.position.x + (x + 0.5) * pixel_size.x
			var column := mini(grid_size.x - 1, int((px - bounds.position.x) / cell_size))
			var cell_index := row * grid_size.x + column
			if not near_bins.has(cell_index):
				continue
			var indices: PackedInt32Array = bins.get(cell_index, empty_indices)
			if indices.is_empty():
				continue
			var slope := _slope(Vector2(px, py), edges, indices, width)
			if slope != Vector2.ZERO:
				image.set_pixel(x, y, Color(slope.x, slope.y, 0, 1))
	var result := {
		"image": image,
		"key": key,
		"bounds": bounds,
		"bake_usec": Time.get_ticks_usec() - started,
		"disk_cache_hit": false,
		"cancelled": false,
		"resolution": dimensions,
		"rim_texels": width / maxf(pixel_size.x, pixel_size.y),
	}
	if _cancelled(cancel_probe):
		return {"image": null, "cancelled": true}
	_write_disk(key, result)
	result["bake_usec"] = Time.get_ticks_usec() - started
	return result


static func _cancelled(probe: Callable) -> bool:
	return probe.is_valid() and bool(probe.call())


static func _read_disk(key: String, bounds: Rect2, dimensions: Vector2i) -> Dictionary:
	var path := CACHE_DIR.path_join(key + ".field")
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_RECORD_BYTES or file.get_length() < 32:
		return {}
	var header_length := file.get_32()
	var raw_length := dimensions.x * dimensions.y * 4
	if header_length < 2 or header_length > MAX_HEADER_BYTES:
		return {}
	if file.get_length() != 4 + header_length + raw_length:
		return {}
	var header := file.get_buffer(header_length)
	if header.size() != header_length:
		return {}
	# ASCII is sufficient for this generated metadata and avoids invalid UTF-8 diagnostics.
	for byte in header:
		if byte < 32 or byte > 126:
			return {}
	var json := JSON.new()
	if json.parse(header.get_string_from_ascii()) != OK:
		return {}
	var record: Variant = json.data
	if record is not Dictionary:
		return {}
	if (
		record.get("version") != CACHE_VERSION
		or record.get("key") != key
		or record.get("format") != Image.FORMAT_RGH
		or typeof(record.get("rim_texels")) not in [TYPE_INT, TYPE_FLOAT]
		or not _geometry_matches(record, bounds, dimensions)
		or dimensions.x < 8
		or dimensions.y < 8
		or dimensions.x > MAX_RESOLUTION
		or dimensions.y > MAX_RESOLUTION
	):
		return {}
	if not is_finite(float(record.rim_texels)) or float(record.rim_texels) < 0.0:
		return {}
	var bytes := file.get_buffer(raw_length)
	if bytes.size() != raw_length:
		return {}
	if record.get("checksum") != _checksum(bytes):
		return {}
	var image := Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_RGH, bytes)
	return {
		"image": image,
		"key": key,
		"bounds": bounds,
		"resolution": dimensions,
		"rim_texels": record.get("rim_texels", 0.0),
		"disk_cache_hit": true,
		"cancelled": false,
	}


static func _geometry_matches(record: Dictionary, bounds: Rect2, dimensions: Vector2i) -> bool:
	var size: Variant = record.get("resolution")
	var rect: Variant = record.get("bounds")
	if size is not Array or size.size() != 2 or rect is not Array or rect.size() != 4:
		return false
	var expected := [
		dimensions.x,
		dimensions.y,
		bounds.position.x,
		bounds.position.y,
		bounds.size.x,
		bounds.size.y
	]
	var values: Array = size + rect
	for index in values.size():
		if typeof(values[index]) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		if index < 2 and float(values[index]) != float(expected[index]):
			return false
		if (
			not is_finite(float(values[index]))
			or not is_equal_approx(float(values[index]), float(expected[index]))
		):
			return false
	return true


static func _write_disk(key: String, data: Dictionary) -> void:
	if DirAccess.make_dir_recursive_absolute(CACHE_DIR) != OK:
		return
	var image := data.image as Image
	var bytes := image.get_data()
	var record := {
		"version": CACHE_VERSION,
		"key": key,
		"format": Image.FORMAT_RGH,
		"resolution": [data.resolution.x, data.resolution.y],
		"bounds":
		[data.bounds.position.x, data.bounds.position.y, data.bounds.size.x, data.bounds.size.y],
		"rim_texels": data.rim_texels,
		"checksum": _checksum(bytes),
	}
	var path := CACHE_DIR.path_join(key + ".field")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return
	var header := JSON.stringify(record).to_ascii_buffer()
	file.store_32(header.size())
	file.store_buffer(header)
	file.store_buffer(bytes)
	file.close()
	if DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
	_prune_disk()


static func _checksum(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _prune_disk() -> void:
	# This directory is disposable derived data, never puzzle/save progress.
	var entries: Array[Dictionary] = []
	var total := 0
	for filename in DirAccess.get_files_at(CACHE_DIR):
		if not filename.ends_with(".field"):
			continue
		var path := CACHE_DIR.path_join(filename)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var length := file.get_length()
		file.close()
		total += length
		entries.append({"path": path, "bytes": length, "time": FileAccess.get_modified_time(path)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	while entries.size() > MAX_CACHE_ENTRIES or total > MAX_DISK_BYTES:
		var oldest: Dictionary = entries.pop_front()
		total -= int(oldest.bytes)
		DirAccess.remove_absolute(oldest.path)


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
	edges: EdgeData, bounds: Rect2, reach: float, cell: float, grid: Vector2i
) -> Dictionary:
	var bins: Dictionary = {}
	for index in edges.starts.size():
		var a := edges.starts[index]
		var delta := edges.deltas[index]
		var diagonal := absf(delta.x) > cell and absf(delta.y) > cell
		var area := Rect2(a, Vector2.ZERO).expand(a + delta).grow(reach)
		var first := Vector2i((area.position - bounds.position) / cell)
		var last := Vector2i((area.end - bounds.position) / cell)
		for row in range(maxi(0, first.y), mini(grid.y - 1, last.y) + 1):
			for column in range(maxi(0, first.x), mini(grid.x - 1, last.x) + 1):
				var tile := Rect2(bounds.position + Vector2(column, row) * cell, Vector2.ONE * cell)
				if diagonal and not _segment_meets_box(a, delta, tile.grow(reach)):
					continue
				var key := row * grid.x + column
				if not bins.has(key):
					bins[key] = PackedInt32Array()
				bins[key].append(index)
	return bins


static func _segment_meets_box(start: Vector2, delta: Vector2, box: Rect2) -> bool:
	# Expanded square is a conservative superset of the circular distance band.
	# Slab clipping rejects only distant cells, including long diagonal AABB gaps.
	var low := 0.0
	var high := 1.0
	for axis in 2:
		if absf(delta[axis]) <= 0.000001:
			if start[axis] < box.position[axis] or start[axis] > box.end[axis]:
				return false
			continue
		var first: float = (box.position[axis] - start[axis]) / delta[axis]
		var last: float = (box.end[axis] - start[axis]) / delta[axis]
		low = maxf(low, minf(first, last))
		high = minf(high, maxf(first, last))
		if low > high:
			return false
	return true


static func _slope(
	point: Vector2, edges: EdgeData, indices: PackedInt32Array, width: float
) -> Vector2:
	var starts := edges.starts
	var deltas := edges.deltas
	var inverse_squared := edges.inverse_squared
	var sample_deltas := edges.sample_deltas
	var nearest_squared := width * width
	var nearest := -1
	for index: int in indices:
		var a := starts[index]
		var delta := deltas[index]
		var t := clampf((point - a).dot(delta) * inverse_squared[index], 0.0, 1.0)
		var sample_delta := point - (a + delta * t)
		var distance_squared := sample_delta.length_squared()
		sample_deltas[index] = sample_delta
		if distance_squared < nearest_squared:
			nearest_squared = distance_squared
			nearest = index
	if nearest < 0:
		return Vector2.ZERO
	var distance := sqrt(nearest_squared)
	var blend_radius := width * CORNER_BLEND_RATIO
	var normal_sum := Vector2.ZERO
	var weight_sum := 0.0
	for index: int in indices:
		var delta := sample_deltas[index]
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
