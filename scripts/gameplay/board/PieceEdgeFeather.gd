extends RefCounted
## A one-pixel coverage fringe for polygon fills in the Compatibility renderer.

var _points := PackedVector2Array()
var _offsets := PackedVector2Array()
var _uvs := PackedVector2Array()
var _uv_transform := Transform2D.IDENTITY
var _indices := PackedInt32Array()
var _colors := PackedColorArray()
var _texture: Texture2D


static func pixel_scale(item: CanvasItem) -> float:
	# CanvasItem.get_screen_transform() omits the root window's stretch in 4.6.
	return maxf(0.001, (item.get_viewport_transform() * item.get_global_transform()).x.length())


func setup(
	points: PackedVector2Array,
	uvs := PackedVector2Array(),
	texture: Texture2D = null,
	color := Color.WHITE
) -> void:
	_points = points
	_texture = texture
	_offsets.clear()
	_indices.clear()
	_colors.clear()
	_uvs.clear()
	if points.size() < 3:
		return
	var winding := -1.0 if Geometry2D.is_polygon_clockwise(points) else 1.0
	for index in points.size():
		var previous := points[index] - points[(index - 1 + points.size()) % points.size()]
		var next := points[(index + 1) % points.size()] - points[index]
		var a := Vector2(previous.y, -previous.x).normalized() * winding
		var b := Vector2(next.y, -next.x).normalized() * winding
		var normal := (a + b).normalized()
		# Limit acute corners so the fringe cannot become a visible spike.
		_offsets.append(normal / maxf(0.5, normal.dot(b)))
		(
			_indices
			. append_array(
				PackedInt32Array(
					[
						index * 2,
						((index + 1) % points.size()) * 2,
						index * 2 + 1,
						index * 2 + 1,
						((index + 1) % points.size()) * 2,
						((index + 1) % points.size()) * 2 + 1,
					]
				)
			)
		)
		_colors.append(color)
		_colors.append(Color(color.r, color.g, color.b, 0.0))
	if texture != null and uvs.size() == points.size():
		var size := Vector2(texture.get_size())
		for uv in uvs:
			_uvs.append(uv / size)
		_uv_transform = _texture_transform(points, _uvs)


func draw(item: CanvasItem, width: float, translation := Vector2.ZERO) -> void:
	if _indices.is_empty():
		return
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for index in _points.size():
		var extension := _offsets[index] * width
		vertices.append(_points[index] + translation)
		vertices.append(_points[index] + translation + extension)
		if not _uvs.is_empty():
			uvs.append(_uvs[index])
			uvs.append(_uvs[index] + _uv_transform.basis_xform(extension))
	RenderingServer.canvas_item_add_triangle_array(
		item.get_canvas_item(),
		_indices,
		vertices,
		_colors,
		uvs,
		PackedInt32Array(),
		PackedFloat32Array(),
		_texture.get_rid() if _texture != null else RID()
	)


static func _texture_transform(points: PackedVector2Array, uvs: PackedVector2Array) -> Transform2D:
	# Piece UVs are affine. Use a non-collinear pair, including concave knob shapes.
	var axis := 1
	while axis < points.size() and points[axis].distance_squared_to(points[0]) < 0.001:
		axis += 1
	if axis == points.size():
		return Transform2D.IDENTITY
	for index in range(axis + 1, points.size()):
		var a := points[axis] - points[0]
		var b := points[index] - points[0]
		if absf(a.cross(b)) > 0.001:
			return (
				Transform2D(uvs[axis] - uvs[0], uvs[index] - uvs[0], Vector2.ZERO)
				* Transform2D(a, b, Vector2.ZERO).affine_inverse()
			)
	return Transform2D.IDENTITY
