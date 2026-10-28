extends Control
## One live viewport and an authored thin-paper tuck carton; no gameplay state.

signal sample_motion_stopped

const PaperShader := preload("res://scripts/ui/box/CartonPaper.gdshader")

const Appearance := preload("res://scripts/ui/box/CartonAppearance.gd")

const SampleMotion := preload("res://scripts/ui/box/BoxSampleMotion.gd")

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
var _gesture_paused := false
var _gesture_lid_tween: Tween
var _sample_motion: RefCounted
var _opened := false
var _open_progress := 0.0:
	set(value):
		_open_progress = value
		_apply_fold_pose()


func _ready() -> void:
	display.texture = viewport.get_texture()
	$Shadow.texture = display.texture
	_sample_motion = SampleMotion.new(self, samples)
	_sample_motion.stopped.connect(func() -> void: sample_motion_stopped.emit())
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
	if reduced_motion or is_equal_approx(_open_progress, target):
		_open_progress = target
		return
	_lid_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_lid_tween.tween_property(self, "_open_progress", target, 0.62 * absf(target - _open_progress))
	_lid_tween.finished.connect(func() -> void: _lid_tween = null)
	_pause_lid_motion()


func show_mode(mode: StringName, piece_data: Array = [], reduced_motion := false) -> void:
	if _texture == null:
		return
	_sample_motion.show(mode, piece_data, _texture, reduced_motion, _samples_can_rise)


func retract_mode(reduced_motion := false) -> void:
	# Back owns the current pose immediately, even while the lid is opening.
	_kill_lid_tween()
	await _sample_motion.retract(reduced_motion)


func sample_motion_phase() -> StringName:
	return _sample_motion.phase if _sample_motion != null else &"idle"


func _samples_can_rise() -> bool:
	return not _gesture_paused and _opened and _open_progress >= 0.999


func set_rendering(enabled: bool) -> void:
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	)


func cancel_motion() -> void:
	_gesture_paused = false
	_gesture_lid_tween = null
	_kill_lid_tween()
	_clear_samples()
	if is_instance_valid(lid):
		_open_progress = 1.0 if _opened else 0.0


func gesture_pause_motion() -> void:
	if _gesture_paused:
		return
	_gesture_paused = true
	_pause_lid_motion()
	if _sample_motion != null:
		_sample_motion.gesture_pause_motion()


func gesture_resume_motion() -> void:
	_gesture_paused = false
	if (
		_gesture_lid_tween != null
		and _gesture_lid_tween == _lid_tween
		and _gesture_lid_tween.is_valid()
	):
		_gesture_lid_tween.play()
	_gesture_lid_tween = null
	if _sample_motion != null:
		_sample_motion.gesture_resume_motion()


func _pause_lid_motion() -> void:
	if _gesture_paused and _lid_tween != null and _lid_tween.is_valid() and _lid_tween.is_running():
		_gesture_lid_tween = _lid_tween
		_lid_tween.pause()


func active_motion_count() -> int:
	return (
		int(_lid_tween != null)
		+ (_sample_motion.active_motion_count() if _sample_motion != null else 0)
	)


func _kill_lid_tween() -> void:
	_gesture_lid_tween = null
	if _lid_tween != null:
		_lid_tween.kill()
		_lid_tween = null


func _clear_samples() -> void:
	if _sample_motion != null:
		_sample_motion.cancel()


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
				material.set_shader_parameter("front_panel", node.name == "FrontBoard")
				node.set_surface_override_material(index, material)
	for child in node.get_children():
		_apply_paper_materials(child)
