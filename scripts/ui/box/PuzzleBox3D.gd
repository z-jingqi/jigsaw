extends Control
## One live viewport, one shallow shell, one hinged lid. No gameplay state is owned here.

signal sample_motion_stopped

const Pieces := preload("res://scripts/ui/box/BoxPieceMeshes.gd")

@onready var viewport: SubViewport = $Viewport
@onready var display: TextureRect = $Display
@onready var lid: Node3D = $Viewport/World/LidPivot
@onready var samples: Node3D = $Viewport/World/Samples
var _texture: Texture2D
var _lid_art: MeshInstance3D
var _lid_tween: Tween
var _sample_tween: Tween
var _opened := false


func _ready() -> void:
	display.texture = viewport.get_texture()
	$Viewport/World/Camera.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	resized.connect(_resize_viewport)
	_resize_viewport()
	if _texture != null:
		configure(_texture)


func configure(texture: Texture2D) -> void:
	_texture = texture
	if not is_node_ready():
		return
	cancel_motion()
	_clear_samples()
	if is_instance_valid(_lid_art):
		_lid_art.free()
	_lid_art = Pieces.artwork_plane(texture, Vector2(2.25, 3.0))
	_lid_art.position = Vector3(0, 0.045, 1.5)
	lid.add_child(_lid_art)
	_opened = false
	lid.rotation.x = 0.0


func set_open(opened: bool, reduced_motion := false) -> void:
	_kill_lid_tween()
	_opened = opened
	var target := deg_to_rad(-78.0) if opened else 0.0
	if not opened:
		_clear_samples()
	if reduced_motion:
		lid.rotation.x = target
		return
	_lid_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_lid_tween.tween_property(lid, "rotation:x", target, 0.46)
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
			piece.position = Vector3(float(index - 1) * 0.68, 0, float(index % 2) * 0.18)
			piece.rotation = Vector3(deg_to_rad(20), deg_to_rad(float(index - 1) * 12), 0)
			samples.add_child(piece)
	samples.position = Vector3(0, 1.02 if reduced_motion else 0.32, -0.2)
	if not reduced_motion:
		_sample_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_sample_tween.tween_property(samples, "position:y", 1.02, 0.36)
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
		piece.rotation.x = deg_to_rad(-35)
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
	_sample_tween.tween_property(samples, "position:y", 0.2, 0.28)
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
		lid.rotation.x = deg_to_rad(-78.0) if _opened else 0.0


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
