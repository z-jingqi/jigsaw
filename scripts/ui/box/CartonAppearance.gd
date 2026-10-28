extends Node3D
## Flat printed surfaces on the existing authored carton. No extra viewport.

const InkLineShader := preload("res://scripts/ui/box/CartonInkLine.gdshader")
const RevealShader := preload("res://scripts/ui/box/CartonArtwork.gdshader")
const Packaging := preload("res://scripts/ui/box/ThemePackaging.gd")
const PaperShader := preload("res://scripts/ui/box/CartonPaper.gdshader")
const TitleFont := preload("res://assets/fonts/noto/NotoSerifSC[wght].ttf")
var _top_print: Node3D
var _side_print: Node3D


func configure(carton: Node3D, lid: Node3D, texture: Texture2D, data: Dictionary) -> void:
	for child in get_children():
		child.free()
	if is_instance_valid(_top_print):
		_top_print.free()
	_top_print = Node3D.new()
	_top_print.name = "TopPrinting"
	lid.add_child(_top_print)
	_side_print = Node3D.new()
	_side_print.name = "SpinePrinting"
	# Reuse the theme's authored print coordinates on the side, not the artwork face.
	_side_print.position = Vector3(0.882, 0, 0.99)
	_side_print.rotation.y = PI / 2
	add_child(_side_print)
	var old_art := carton.find_child("FrontArtwork", true, false) as GeometryInstance3D
	old_art.visible = false
	var colors := Packaging.palette(str(data.get("theme_id", "")))
	var ink := _ink(colors.ink)
	var accent := _ink(colors.accent)
	_print_wrap(ink, colors.ink)
	_print_motif(StringName(colors.motif), accent)
	var title := Label3D.new()
	title.name = "PrintedLevelTitle"
	var full_title := str(data.get("title", ""))
	var fitted := _fit_title(full_title, Packaging.title_width(data))
	var wrapped := str(fitted.text).contains("\n")
	title.text = fitted.text
	title.set_meta("full_title", full_title)
	_set_accessible_title(full_title)
	title.font = TitleFont
	title.font_size = fitted.font_size
	title.pixel_size = Packaging.TITLE_PIXEL_SIZE
	title.outline_size = 0
	var title_ink: Color = colors.ink
	title.modulate = title_ink.darkened(0.60) if title_ink.get_luminance() > 0.40 else title_ink
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.position = Vector3(-0.90, 2.76 if wrapped else 2.84, 0.255)
	title.shaded = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(title)
	var revealed := bool(data.get("preview_revealed", true))
	if texture != null:
		var dimensions := texture.get_size()
		var art_height := 2.20 if wrapped else 2.40
		var factor := minf(1.80 / dimensions.x, art_height / dimensions.y)
		var material: Material = _image(texture)
		if not revealed:
			var faded := ShaderMaterial.new()
			faded.shader = RevealShader
			faded.set_shader_parameter("artwork", texture)
			material = faded
		var art := _quad("FullArtwork", dimensions * factor, material, self)
		art.position = Vector3(0, 1.37 if wrapped else 1.47, 0.253)
	else:
		var placeholder := _quad("MissingArtwork", Vector2(1.80, 2.40), _ink(Color("efede7")), self)
		placeholder.position = Vector3(0, 1.47, 0.253)
	var modes: Array = data.get("modes", [])
	for index in 3:
		var mode: StringName = [&"polygon", &"knob", &"swap"][index]
		var status := _quad(
			"Status_" + str(mode),
			Vector2(0.25, 0.25),
			_image(Packaging.status_texture(mode, modes), true),
			self
		)
		status.position = Vector3(0.12 + index * 0.32, 0.148, 0.255)


func _fit_title(full_title: String, width: float) -> Dictionary:
	var text := full_title.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	var max_pixels := width / Packaging.TITLE_PIXEL_SIZE
	var font_size := Packaging.TITLE_DEFAULT_SIZE
	while font_size > Packaging.TITLE_MIN_SIZE and _title_measure(text, font_size) > max_pixels:
		font_size -= 1
	if _title_measure(text, font_size) <= max_pixels:
		return {"text": text, "font_size": font_size}
	var wrapped := _wrap_title(text, font_size, max_pixels)
	if not wrapped.is_empty():
		return {"text": wrapped, "font_size": font_size}
	# Preserve a readable floor. Truncate only the printed label; never the model/a11y name.
	var low := 0
	var high := text.length()
	while low < high:
		var middle := ceili(float(low + high) / 2.0)
		if _title_measure(text.left(middle).rstrip(" ") + "…", font_size) <= max_pixels:
			low = middle
		else:
			high = middle - 1
	return {"text": text.left(low).rstrip(" ") + "…", "font_size": font_size}


func _title_measure(text: String, font_size: int) -> float:
	return TitleFont.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _wrap_title(text: String, font_size: int, max_pixels: float) -> String:
	var best := ""
	var balance := INF
	for index in range(1, text.length()):
		if text.contains(" ") and text[index] != " ":
			continue
		var first := text.left(index).strip_edges()
		var second := text.substr(index).strip_edges()
		var left := _title_measure(first, font_size)
		var right := _title_measure(second, font_size)
		if maxf(left, right) <= max_pixels and absf(left - right) < balance:
			balance = absf(left - right)
			best = first + "\n" + second
	return best


func _set_accessible_title(full_title: String) -> void:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is Control:
			ancestor.accessibility_name = full_title
			return
		ancestor = ancestor.get_parent()


func _print_wrap(ink: Material, color: Color) -> void:
	var front := _quad("FrontBinding", Vector2(0.05, 3), ink, self)
	front.position = Vector3(1.10, 1.5, 0.253)
	var spine := _quad("SpineBinding", Vector2(0.48, 3), _paper(color.darkened(0.08)), self)
	spine.position = Vector3(1.136, 1.5, 0)
	spine.rotation.y = PI / 2
	var top := _quad("TopBinding", Vector2(2.25, 0.48), _paper(color), _top_print)
	top.position = Vector3(0, 0.012, 0.24)
	top.rotation.x = -PI / 2
	# A narrow fold alongside the printed spine separates the paper layers.
	var seam := _quad("SpineFold", Vector2(0.010, 2.98), _ink(color.darkened(0.28)), self)
	seam.position = Vector3(1.138, 1.5, 0.218)
	seam.rotation.y = PI / 2
	var lip := _quad("SpineLip", Vector2(0.007, 2.98), _ink(Color("e5dfd2")), self)
	lip.position = Vector3(1.138, 1.5, 0.231)
	lip.rotation.y = PI / 2
	var closure := _quad("LidFold", Vector2(2.22, 0.010), _ink(Color("b1a99a")), self)
	closure.position = Vector3(0, 2.995, 0.251)


func _paper(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PaperShader
	material.set_shader_parameter("paper_color", color)
	return material


func _print_motif(motif: StringName, material: Material) -> void:
	_stroke([Vector2(0.888, 0.08), Vector2(0.888, 2.91)], material, _side_print)
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
				_side_print
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
			_stroke(points, material, _side_print)
		if motif == &"mural":
			var red := _ink(Color("a45c48"))
			for index in 3:
				var mark := _quad("OchreAccent", Vector2(0.10, 0.028), red, _side_print)
				mark.position = Vector3(0.99, 0.24 + index * 0.10, 0.255)


func _stroke(points: Array[Vector2], material: Material, parent: Node3D, on_top := false) -> void:
	for index in points.size() - 1:
		var delta := points[index + 1] - points[index]
		var midpoint := (points[index] + points[index + 1]) / 2
		var line_material: Material = material
		if on_top:
			var antialiased := ShaderMaterial.new()
			antialiased.shader = InkLineShader
			antialiased.set_shader_parameter("ink", (material as StandardMaterial3D).albedo_color)
			line_material = antialiased
		var line := _quad(
			"PrintedLine", Vector2(delta.length(), 0.04 if on_top else 0.005), line_material, parent
		)
		if on_top:
			line.position = Vector3(midpoint.x, 0.014, midpoint.y)
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
	_side_print.add_child(instance)


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
