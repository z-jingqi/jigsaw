extends Control
## One live viewport and an authored thin-paper tuck carton; no gameplay state.

signal sample_motion_stopped

const PaperShader := preload("res://scripts/ui/box/CartonPaper.gdshader")

const Appearance := preload("res://scripts/ui/box/CartonAppearance.gd")

const Pieces := preload("res://scripts/ui/box/BoxPieceMeshes.gd")

@onready var viewport: SubViewport = $Viewport
@onready var display: TextureRect = $Display
@onready var carton: Node3D = $Viewport/World/Carton
@onready var lid: Node3D = carton.find_child("TopFlapPivot", true, false)
@onready var tab: Node3D = carton.find_child("TuckTab", true, false)
@onready var left_ear: Node3D = carton.find_child("SideEarLeft", true, false)
@onready var right_ear: Node3D = carton.find_child("SideEarRight", true, false)
@onready var samples: Node3D = $Viewport/World/Samples
var _texture: Texture2D
var _packaging: Dictionary = {}
var _appearance: Node3D
var _lid_tween: Tween
var _sample_tween: Tween
var _opened := false
var _open_progress := 0.0:
	set(value):
		_open_progress = value
		_apply_fold_pose()


func _ready() -> void:
	display.texture = viewport.get_texture()
	$Viewport/World/Camera.look_at(Vector3(0, 1.8, 0), Vector3.UP)
	_apply_paper_materials(carton)
	_appearance = Appearance.new()
	carton.add_child(_appearance)
	resized.connect(_resize_viewport)
	_resize_viewport()
	if _texture != null:
		configure(_texture, _packaging)


func configure(texture: Texture2D, packaging: Dictionary = {}) -> void:
	_texture = texture
	_packaging = packaging.duplicate(true)
	if not is_node_ready():
		return
	cancel_motion()
	_clear_samples()
	_appearance.configure(carton, lid, texture, _packaging)
	_opened = false
	_open_progress = 0.0


func set_open(opened: bool, reduced_motion := false) -> void:
	_kill_lid_tween()
	_opened = opened
	var target := 1.0 if opened else 0.0
	if not opened:
		_clear_samples()
	if reduced_motion:
		_open_progress = target
		return
	_lid_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_lid_tween.tween_property(self, "_open_progress", target, 0.62)
	_lid_tween.finished.connect(func() -> void: _lid_tween = null)


func show_mode(mode: StringName, piece_data: Array = [], reduced_motion := false) -> void:
	_clear_samples()
	if not _opened or _texture == null:
		return
	if mode == &"swap":
		_create_swap_strip(piece_data)
	else:
		for index in mini(3, piece_data.size()):
			var data: Dictionary = piece_data[index]
			var piece := Pieces.textured_polygon(
				PackedVector2Array(data.get("polygon", [])),
				PackedVector2Array(data.get("uv", [])),
				_texture
			)
			piece.position = Vector3(float(index - 1) * 0.68, 0, float(index % 2) * 0.04)
			piece.rotation = Vector3(deg_to_rad(90), 0, deg_to_rad(float(index - 1) * 8))
			samples.add_child(piece)
	var display_height := 3.16 if mode == &"swap" else 3.38
	samples.position = Vector3(0, display_height if reduced_motion else 2.50, 0)
	if not reduced_motion:
		_sample_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_sample_tween.tween_property(samples, "position:y", display_height, 0.36)
		_sample_tween.finished.connect(func() -> void: _sample_tween = null)


func _create_swap_strip(piece_data: Array) -> void:
	# These are the actual top-row gameplay polygons and UVs, not inferred crops.
	var order := [2, 0, 3, 1]
	for index in order.size():
		var source_index: int = order[index]
		if source_index >= piece_data.size():
			continue
		var data: Dictionary = piece_data[source_index]
		var piece := Pieces.textured_polygon(
			PackedVector2Array(data.get("polygon", [])),
			PackedVector2Array(data.get("uv", [])),
			_texture,
			0.53
		)
		piece.position.x = (float(index) - 1.5) * 0.55
		piece.rotation.x = deg_to_rad(90)
		samples.add_child(piece)


func retract_mode(reduced_motion := false) -> void:
	# Cancellation emits the same completion signal, so an awaiting close never hangs.
	if _sample_tween != null:
		_sample_tween.kill()
		_sample_tween = null
	if samples.get_child_count() == 0:
		return
	if reduced_motion:
		_clear_samples()
		return
	_sample_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_sample_tween.tween_property(samples, "position:y", 2.50, 0.28)
	_sample_tween.finished.connect(_clear_samples, CONNECT_ONE_SHOT)
	await sample_motion_stopped


func set_rendering(enabled: bool) -> void:
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	)


func cancel_motion() -> void:
	_kill_lid_tween()
	_clear_samples()
	if is_instance_valid(lid):
		_open_progress = 1.0 if _opened else 0.0


func active_motion_count() -> int:
	return int(_lid_tween != null) + int(_sample_tween != null)


func _kill_lid_tween() -> void:
	if _lid_tween != null:
		_lid_tween.kill()
		_lid_tween = null


func _clear_samples() -> void:
	if _sample_tween != null:
		_sample_tween.kill()
		_sample_tween = null
	if is_instance_valid(samples):
		for child in samples.get_children():
			child.free()
	sample_motion_stopped.emit()


func _resize_viewport() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var aspect := 0.75
	var height := clampi(roundi(size.y), 256, 1024)
	viewport.size = Vector2i(maxi(1, roundi(height * aspect)), height)


func _exit_tree() -> void:
	cancel_motion()


func _apply_fold_pose() -> void:
	if not is_instance_valid(lid):
		return
	var p := clampf(_open_progress, 0.0, 1.0)
	lid.rotation.x = deg_to_rad(-105.0 * p)
	# Keep the tongue vertical until its bottom clears the fixed front wall.
	var unfold := clampf((p - 0.55) / 0.45, 0.0, 1.0)
	tab.rotation.x = deg_to_rad(105.0 * p if p <= 0.55 else lerpf(57.75, -82.0, unfold))
	left_ear.rotation.z = deg_to_rad(64.0 * unfold)
	right_ear.rotation.z = deg_to_rad(-64.0 * unfold)


func _apply_paper_materials(node: Node) -> void:
	if node is MeshInstance3D and node.name != "FrontArtwork":
		for index in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(index)
			if source is StandardMaterial3D:
				var material := ShaderMaterial.new()
				material.shader = PaperShader
				material.set_shader_parameter("paper_color", source.albedo_color)
				node.set_surface_override_material(index, material)
	for child in node.get_children():
		_apply_paper_materials(child)
