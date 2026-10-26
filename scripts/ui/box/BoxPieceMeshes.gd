extends RefCounted
## Presentation meshes preserve supplied gameplay outlines and normalized source UVs.


static func textured_polygon(
	points: PackedVector2Array, uv: PackedVector2Array, texture: Texture2D, span := 0.78
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	if points.size() < 3 or uv.size() != points.size():
		return instance
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var factor := span / maxf(bounds.size.x, bounds.size.y)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for point in points:
		var centered := (point - bounds.get_center()) * factor
		vertices.append(Vector3(centered.x, 0, centered.y))
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(points)
	if (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
		return instance
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	instance.mesh = mesh
	instance.material_override = artwork_material(texture)
	return instance


static func artwork_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


static func artwork_plane(texture: Texture2D, dimensions: Vector2) -> MeshInstance3D:
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = dimensions
	plane.mesh = mesh
	plane.material_override = artwork_material(texture)
	return plane
