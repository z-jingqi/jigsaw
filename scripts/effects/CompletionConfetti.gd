class_name CompletionConfetti
extends Node2D

const COLORS := [Color("F9C74F"), Color("F3722C"), Color("43AA8B"), Color("4D96FF"), Color("F15BB5")]
const PARTICLE_COUNT := 22
const LIFETIME := 2.2

var _rng := RandomNumberGenerator.new()
var _particles: Array[Dictionary] = []
var _elapsed := 0.0


func start(reduced_motion: bool) -> void:
	stop()
	if reduced_motion:
		return
	_rng.randomize()
	var viewport := get_viewport_rect().size
	for index in PARTICLE_COUNT:
		_spawn(viewport, index)
	set_process(true)


func stop() -> void:
	for item in _particles:
		var node: Node2D = item.get("node", null)
		if is_instance_valid(node):
			node.queue_free()
	_particles.clear()
	_elapsed = 0.0
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	for item in _particles:
		var node: Node2D = item["node"]
		if not is_instance_valid(node):
			continue
		var velocity: Vector2 = item["velocity"]
		velocity.y += 980.0 * delta
		item["velocity"] = velocity
		node.position += velocity * delta
		node.rotation += float(item["spin"]) * delta
		node.modulate.a = clampf(1.0 - _elapsed / LIFETIME, 0.0, 1.0)
	if _elapsed >= LIFETIME:
		stop()


func _spawn(viewport: Vector2, index: int) -> void:
	var node := Node2D.new()
	node.position = Vector2(viewport.x * (0.18 + 0.64 * float(index) / float(PARTICLE_COUNT)), viewport.y * 0.28)
	node.rotation = _rng.randf_range(0.0, TAU)
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array([Vector2(-5, -10), Vector2(5, -10), Vector2(5, 10), Vector2(-5, 10)])
	shape.color = COLORS[index % COLORS.size()]
	node.add_child(shape)
	add_child(node)
	_particles.append({"node": node, "velocity": Vector2(_rng.randf_range(-150.0, 150.0), _rng.randf_range(-390.0, -220.0)), "spin": _rng.randf_range(-8.0, 8.0)})
