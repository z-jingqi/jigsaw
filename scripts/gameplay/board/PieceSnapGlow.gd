extends Node2D
## Light the landed image without changing its color, geometry, or neighbors.

const Surface := preload("res://scripts/gameplay/board/PieceSurface.gd")
const DURATION := 0.34
const ATTACK := 0.045

var _elapsed := 0.0


func configure(shape: PackedVector2Array, face: Polygon2D) -> void:
	var glow := Surface.new()
	glow.name = "FaceGlow"
	glow.polygon = shape
	if face != null:
		glow.uv = face.uv
		glow.texture = face.texture
	glow.color = Color(1.0, 0.96, 0.86, 0.38)
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = blend
	add_child(glow)
	modulate.a = 0.0


func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	var attack := smoothstep(0.0, ATTACK, _elapsed)
	var release := 1.0 - smoothstep(ATTACK, DURATION, _elapsed)
	modulate.a = attack * release
	if _elapsed >= DURATION:
		queue_free()
