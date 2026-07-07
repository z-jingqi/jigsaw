extends Node2D
class_name ConfettiEffect

const COLORS := [
	Color("#F94144"), Color("#F3722C"), Color("#F8961E"), Color("#F9C74F"),
	Color("#90BE6D"), Color("#43AA8B"), Color("#4D96FF"), Color("#9B5DE5"),
	Color("#F15BB5"), Color("#00BBF9"), Color("#00F5D4"), Color("#FFD166"),
]
const VOLLEY_COUNT := 1
const VOLLEY_INTERVAL := 0.55
const MAX_AGE := 11.0

var rng := RandomNumberGenerator.new()
var particles: Array[Dictionary] = []
var viewport_size := Vector2.ZERO
var volleys_fired := 0
var volley_timer := 0.0
var unit := 1.0


func _ready() -> void:
	rng.randomize()
	viewport_size = get_viewport_rect().size
	unit = viewport_size.x / 1206.0
	_fire_volley()


func _fire_volley() -> void:
	volleys_fired += 1
	volley_timer = 0.0
	var origin_y := viewport_size.y + 26.0
	_burst(Vector2(viewport_size.x * 0.10, origin_y), -72.0, 110)
	_burst(Vector2(viewport_size.x * 0.90, origin_y), -108.0, 110)
	_burst(Vector2(viewport_size.x * 0.50, origin_y), -90.0, 80)


func _process(delta: float) -> void:
	if volleys_fired < VOLLEY_COUNT:
		volley_timer += delta
		if volley_timer >= VOLLEY_INTERVAL:
			_fire_volley()
	var remaining: Array[Dictionary] = []
	for particle in particles:
		if _update_particle(particle, delta):
			remaining.append(particle)
		else:
			var node: Node2D = particle["node"]
			if is_instance_valid(node):
				node.queue_free()
	particles = remaining
	if particles.is_empty() and volleys_fired >= VOLLEY_COUNT:
		set_process(false)


func _burst(origin: Vector2, angle_degrees: float, count: int) -> void:
	for i in count:
		_spawn_particle(origin, angle_degrees)


func _spawn_particle(origin: Vector2, angle_degrees: float) -> void:
	var node := Node2D.new()
	node.position = origin + Vector2(rng.randf_range(-30.0, 30.0) * unit, rng.randf_range(0.0, 18.0) * unit)
	node.rotation = rng.randf_range(0.0, TAU)
	var shape := Polygon2D.new()
	shape.polygon = _random_shape()
	shape.color = COLORS[rng.randi_range(0, COLORS.size() - 1)]
	node.add_child(shape)
	add_child(node)
	var angle := deg_to_rad(angle_degrees + rng.randf_range(-16.0, 16.0))
	# tuned against linear drag so most pieces reach the top of the screen
	var speed := rng.randf_range(1.7, 2.0) * viewport_size.y
	particles.append({
		"node": node,
		"velocity": Vector2(cos(angle), sin(angle)) * speed,
		"gravity": rng.randf_range(1600.0, 2000.0) * unit,
		"drag": rng.randf_range(0.55, 0.75),
		"terminal": rng.randf_range(260.0, 520.0) * unit,
		"spin": rng.randf_range(-6.0, 6.0),
		"sway_phase": rng.randf_range(0.0, TAU),
		"sway_freq": rng.randf_range(1.6, 4.4),
		"sway_amp": rng.randf_range(26.0, 90.0) * unit,
		"tumble_phase": rng.randf_range(0.0, TAU),
		"tumble_freq": rng.randf_range(3.0, 9.0),
		"age": 0.0,
		"fade_after": rng.randf_range(7.5, 9.5),
		"fade_time": 1.4,
	})


func _random_shape() -> PackedVector2Array:
	var size := rng.randf_range(13.0, 32.0) * unit
	match rng.randi_range(0, 3):
		0:
			var half_w := size * 0.28
			var half_h := size * 0.85
			return PackedVector2Array([
				Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
				Vector2(half_w, half_h), Vector2(-half_w, half_h),
			])
		1:
			var half := size * 0.42
			return PackedVector2Array([
				Vector2(-half, -half * 0.72), Vector2(half, -half * 0.72),
				Vector2(half, half * 0.72), Vector2(-half, half * 0.72),
			])
		2:
			var points := PackedVector2Array()
			var radius := size * 0.42
			for i in 8:
				var a := TAU * float(i) / 8.0
				points.append(Vector2(cos(a), sin(a)) * radius)
			return points
		_:
			var r := size * 0.55
			return PackedVector2Array([
				Vector2(0.0, -r), Vector2(r * 0.9, r * 0.62), Vector2(-r * 0.9, r * 0.62),
			])


func _update_particle(particle: Dictionary, delta: float) -> bool:
	var node: Node2D = particle["node"]
	if not is_instance_valid(node):
		return false
	var velocity: Vector2 = particle["velocity"]
	velocity.y += float(particle["gravity"]) * delta
	velocity -= velocity * minf(0.9, float(particle["drag"]) * delta)
	var terminal: float = particle["terminal"]
	if velocity.y > terminal:
		velocity.y = lerpf(velocity.y, terminal, minf(1.0, 3.0 * delta))
	particle["velocity"] = velocity
	particle["age"] = float(particle["age"]) + delta
	particle["sway_phase"] = float(particle["sway_phase"]) + float(particle["sway_freq"]) * delta
	particle["tumble_phase"] = float(particle["tumble_phase"]) + float(particle["tumble_freq"]) * delta
	var sway := sin(float(particle["sway_phase"])) * float(particle["sway_amp"])
	node.position += (velocity + Vector2(sway, 0.0)) * delta
	node.rotation += float(particle["spin"]) * delta
	node.scale = Vector2(1.0, maxf(0.16, absf(sin(float(particle["tumble_phase"])))))
	var age: float = particle["age"]
	var fade_after: float = particle["fade_after"]
	if age > fade_after:
		node.modulate.a = clampf(1.0 - (age - fade_after) / float(particle["fade_time"]), 0.0, 1.0)
	if node.modulate.a <= 0.01 or age >= MAX_AGE:
		return false
	if age > 1.5 and node.position.y > viewport_size.y + 140.0:
		return false
	return true
