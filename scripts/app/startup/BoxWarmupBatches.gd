extends RefCounted
## Select real drawables by material features, never substitute cheaper materials.
var _states: Array[Dictionary] = []
var _groups: Dictionary = {}
var failure_reason := ""


func collect(root: Node) -> bool:
	_states.clear()
	_groups.clear()
	failure_reason = ""
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		_states.append({"node": geometry, "visible": geometry.visible})
		if not geometry.is_visible_in_tree():
			continue
		var key := _family(geometry)
		if not failure_reason.is_empty():
			return false
		if not _groups.has(key):
			_groups[key] = geometry
	for state in _states:
		state.node.hide()
	return not _groups.is_empty()


func families() -> Array:
	return _groups.keys()


func show_representative(key: String) -> void:
	for state in _states:
		state.node.hide()
	var geometry: GeometryInstance3D = _groups[key]
	geometry.show()


func restore() -> void:
	for state in _states:
		if is_instance_valid(state.node):
			state.node.visible = state.visible
	_states.clear()
	_groups.clear()


func _family(geometry: GeometryInstance3D) -> String:
	if geometry is Label3D:
		return "Label3D:production_print"
	var mesh := geometry as MeshInstance3D
	if mesh == null or mesh.mesh == null:
		return geometry.get_class()
	var signatures: Array[String] = []
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface)
		# Mesh exposes these queries only on ArrayMesh, not PrimitiveMesh.
		# The actual uploaded surface dictionary works for both in Godot 4.6.
		var surface_data := RenderingServer.mesh_get_surface(mesh.mesh.get_rid(), surface)
		if not surface_data.has("format") or not surface_data.has("primitive"):
			failure_reason = "missing_uploaded_surface_format:" + mesh.name
			return ""
		var signature := JSON.stringify(
			[_material_signature(material), surface_data.format, surface_data.primitive]
		)
		if not signatures.has(signature):
			signatures.append(signature)
	signatures.sort()
	return JSON.stringify(signatures)


func _material_signature(material: Material) -> String:
	if material is ShaderMaterial:
		return "shader:" + material.shader.resource_path
	if material is BaseMaterial3D:
		# Texture identity/color are uniforms, while these production carton
		# features change generated shader variants. Keep texture-presence flags.
		var features: Dictionary = {}
		for property in [
			"shading_mode",
			"transparency",
			"blend_mode",
			"cull_mode",
			"depth_draw_mode",
			"texture_filter",
			"vertex_color_use_as_albedo",
			"disable_receive_shadows",
			"disable_ambient_light",
			"billboard_mode",
			"albedo_texture_force_srgb",
			"normal_enabled",
			"roughness_texture_channel",
			"metallic_texture_channel"
		]:
			features[property] = material.get(property)
		for property in [
			"albedo_texture", "normal_texture", "roughness_texture", "metallic_texture"
		]:
			features[property] = material.get(property) != null
		return "standard:" + JSON.stringify(features)
	return "material:" + str(material)
