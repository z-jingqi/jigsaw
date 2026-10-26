extends Node3D
## Flat printed surfaces on the existing authored carton. No extra viewport.

const RevealShader := preload("res://scripts/ui/box/CartonArtwork.gdshader")
const Packaging := preload("res://scripts/ui/box/ThemePackaging.gd")
const TitleFont := preload("res://assets/fonts/noto/NotoSerifSC[wght].ttf")
var _top_print: Node3D


func configure(carton: Node3D, lid: Node3D, texture: Texture2D, data: Dictionary) -> void:
	for child in get_children():
		child.free()
	if is_instance_valid(_top_print):
		_top_print.free()
	_top_print = Node3D.new()
	_top_print.name = "TopPrinting"
	lid.add_child(_top_print)
	var old_art := carton.find_child("FrontArtwork", true, false) as GeometryInstance3D
	old_art.visible = false
	var colors := Packaging.palette(str(data.get("theme_id", "")))
	var ink := _ink(colors.ink)
	var accent := _ink(colors.accent)
	_print_wrap(ink)
	_print_motif(StringName(colors.motif), accent)
	var title := Label3D.new()
	title.name = "PrintedLevelTitle"
	title.text = str(data.get("title", ""))
	title.font = TitleFont
	title.font_size = 64
	title.pixel_size = 0.003
	title.outline_size = 0
	title.modulate = colors.ink
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.position = Vector3(-1.0, 2.78, 0.255)
	title.shaded = false
	# Long localized titles stay inside the white field without colliding with binding.
	var text_width := TitleFont.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	var title_scale := minf(1.0, 1.74 / maxf(0.01, text_width * title.pixel_size))
	title.scale = Vector3.ONE * title_scale
	add_child(title)
	var revealed := bool(data.get("preview_revealed", true))
	if texture != null:
		var dimensions := texture.get_size()
		var factor := minf(1.72 / dimensions.x, (1.72 * 4.0 / 3.0) / dimensions.y)
		var material: Material = _image(texture)
		if not revealed:
			var faded := ShaderMaterial.new()
			faded.shader = RevealShader
			faded.set_shader_parameter("artwork", texture)
			material = faded
		var art := _quad("FullArtwork", dimensions * factor, material, self)
		art.position = Vector3(-0.145, 1.45, 0.253)
	else:
		var placeholder := _quad(
			"MissingArtwork", Vector2(1.72, 1.72 * 4.0 / 3.0), _ink(Color("efede7")), self
		)
		placeholder.position = Vector3(-0.145, 1.45, 0.253)
	var modes: Array = data.get("modes", [])
	for index in 3:
		var mode: StringName = [&"polygon", &"knob", &"swap"][index]
		var status := _quad(
			"Status_" + str(mode),
			Vector2(0.25, 0.25),
			_image(Packaging.status_texture(mode, modes), true),
			self
		)
		status.position = Vector3(-0.16 + index * 0.32, 0.148, 0.255)


func _print_wrap(ink: Material) -> void:
	var front := _quad("FrontBinding", Vector2(0.27, 3), ink, self)
	front.position = Vector3(0.99, 1.5, 0.253)
	var spine := _quad("SpineBinding", Vector2(0.48, 3), ink, self)
	spine.position = Vector3(1.136, 1.5, 0)
	spine.rotation.y = PI / 2
	var top := _quad("TopBinding", Vector2(2.25, 0.48), ink, _top_print)
	top.position = Vector3(0, 0.010, 0.24)
	top.rotation.x = -PI / 2


func _print_motif(motif: StringName, material: Material) -> void:
	_stroke([Vector2(0.888, 0.08), Vector2(0.888, 2.91)], material, self)
	for index in 6:
		var offset := -0.91 + index * 0.32
		var points: Array[Vector2] = []
		if motif == &"meander":
			points = [
				Vector2(0, 0),
				Vector2(0.25, 0),
				Vector2(0.25, 0.16),
				Vector2(0.065, 0.16),
				Vector2(0.065, 0.07),
				Vector2(0.17, 0.07)
			]
		else:
			for step in 13:
				var x := float(step) / 12 * 0.25
				points.append(Vector2(x, sin(float(step) / 12 * PI) * 0.10))
		for point_index in points.size():
			points[point_index] += Vector2(offset, 0.16)
		_stroke(points, material, _top_print, true)
	if motif == &"paw":
		_disk(Vector2(0.99, 2.62), Vector2(0.045, 0.035), material)
		for point in [
			Vector2(0.93, 2.68), Vector2(0.97, 2.71), Vector2(1.01, 2.71), Vector2(1.05, 2.68)
		]:
			_disk(point, Vector2(0.018, 0.024), material)
	elif motif == &"meander":
		for index in 2:
			var y := 2.56 + index * 0.17
			_stroke(
				[
					Vector2(0.94, y),
					Vector2(1.06, y),
					Vector2(1.06, y + 0.125),
					Vector2(0.98, y + 0.125),
					Vector2(0.98, y + 0.055),
					Vector2(1.025, y + 0.055)
				],
				material,
				self
			)
	else:
		for index in 2:
			var points: Array[Vector2] = []
			for step in 13:
				points.append(
					Vector2(
						0.94 + sin(float(step) / 12 * PI) * 0.09, 2.53 + step * 0.023 + index * 0.03
					)
				)
			_stroke(points, material, self)
		if motif == &"mural":
			var red := _ink(Color("a45c48"))
			for index in 3:
				var mark := _quad("OchreAccent", Vector2(0.10, 0.028), red, self)
				mark.position = Vector3(0.99, 0.24 + index * 0.10, 0.255)


func _stroke(points: Array[Vector2], material: Material, parent: Node3D, on_top := false) -> void:
	for index in points.size() - 1:
		var delta := points[index + 1] - points[index]
		var midpoint := (points[index] + points[index + 1]) / 2
		var line := _quad("PrintedLine", Vector2(delta.length(), 0.005), material, parent)
		if on_top:
			line.position = Vector3(midpoint.x, 0.012, midpoint.y)
			line.rotation = Vector3(-PI / 2, -delta.angle(), 0)
		else:
			line.position = Vector3(midpoint.x, midpoint.y, 0.255)
			line.rotation.z = delta.angle()


func _disk(center: Vector2, radii: Vector2, material: Material) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 24:
		mesh.surface_add_vertex(Vector3(center.x, center.y, 0.255))
		for angle in [TAU * index / 24, TAU * (index + 1) / 24]:
			mesh.surface_add_vertex(
				Vector3(center.x + cos(angle) * radii.x, center.y + sin(angle) * radii.y, 0.255)
			)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)


func _quad(
	label: String, dimensions: Vector2, material: Material, parent: Node3D
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := QuadMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _ink(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _image(texture: Texture2D, transparent := false) -> StandardMaterial3D:
	var material := _ink(Color.WHITE)
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
