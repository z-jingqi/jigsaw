extends RefCounted
class_name UnlockRevealEffect

const BURN_SHADER_CODE := """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 seed_points[4];
uniform float aspect = 0.75;
uniform float field_max = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = vec2(UV.x * aspect, UV.y);
	float d = 1e9;
	for (int i = 0; i < 4; i++) {
		vec2 s = vec2(seed_points[i].x * aspect, seed_points[i].y);
		d = min(d, distance(p, s));
	}
	float n = texture(noise_tex, UV * 1.2).r;
	float fine = texture(noise_tex, UV * 4.0).r;
	float field = d / 1.55 + (n - 0.5) * 0.07;
	float front = mix(-0.04, field_max, progress);
	float edge = 0.05 + 0.02 * n;
	if (field < front) {
		discard;
	}
	float glow = 1.0 - smoothstep(front, front + edge, field);
	float char_band = 1.0 - smoothstep(front + edge * 0.5, front + edge * 2.2, field);
	vec3 color = mix(tex.rgb, tex.rgb * 0.22, char_band * 0.9);
	float flicker = 0.8 + 0.2 * sin(TIME * 7.0 + fine * 12.0);
	vec3 ember = mix(vec3(0.95, 0.25, 0.03), vec3(1.0, 0.85, 0.30), glow * flicker);
	color = mix(color, ember, glow);
	COLOR = vec4(color, tex.a);
}
"""

var burn_shader: Shader
var burn_noise: Texture2D


func animate(card: Control, overlay: Control, back_image: Image, card_width: float, card_height: float, style := "fire") -> void:
	if back_image == null or back_image.is_empty():
		_animate_flip_fallback(card, overlay)
		return
	if style == "shatter":
		_animate_shatter(card, overlay, back_image, card_width, card_height)
	else:
		_animate_burn(card, overlay, back_image, card_width, card_height)


func _animate_burn(card: Control, overlay: Control, back_image: Image, card_width: float, card_height: float) -> void:
	for child in overlay.get_children():
		child.queue_free()
	var burn := TextureRect.new()
	burn.texture = ImageTexture.create_from_image(back_image)
	burn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burn.stretch_mode = TextureRect.STRETCH_SCALE
	burn.set_anchors_preset(Control.PRESET_FULL_RECT)
	burn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _burn_shader_resource()
	material.set_shader_parameter("noise_tex", _burn_noise_texture())
	material.set_shader_parameter("aspect", card_width / maxf(1.0, card_height))
	var seeds := _burn_seed_points()
	material.set_shader_parameter("seed_points", seeds)
	material.set_shader_parameter("field_max", _burn_field_max(seeds, card_width / maxf(1.0, card_height)))
	material.set_shader_parameter("progress", 0.0)
	burn.material = material
	overlay.add_child(burn)
	var tween := card.create_tween()
	tween.tween_interval(0.55)
	tween.tween_method(
		func(value: float) -> void: material.set_shader_parameter("progress", value),
		0.0, 1.0, 3.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(overlay.queue_free)


func _animate_shatter(card: Control, overlay: Control, back_image: Image, card_width: float, card_height: float) -> void:
	for child in overlay.get_children():
		child.queue_free()
	var texture := ImageTexture.create_from_image(back_image)
	var intact := TextureRect.new()
	intact.texture = texture
	intact.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intact.stretch_mode = TextureRect.STRETCH_SCALE
	intact.set_anchors_preset(Control.PRESET_FULL_RECT)
	intact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(intact)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var impact := Vector2(card_width * rng.randf_range(0.36, 0.64), card_height * rng.randf_range(0.34, 0.62))
	var geometry := _crack_geometry(impact, card_width, card_height, rng)
	var tween := card.create_tween()
	tween.tween_interval(0.45)
	tween.tween_callback(func() -> void: _crack_stage(overlay, geometry))
	tween.tween_interval(0.7)
	tween.tween_callback(func() -> void:
		if is_instance_valid(intact):
			intact.queue_free()
		_shatter_stage(overlay, geometry, texture, impact, card_width, rng)
	)
	tween.tween_interval(1.0)
	tween.tween_callback(overlay.queue_free)


func _crack_geometry(impact: Vector2, card_width: float, card_height: float, rng: RandomNumberGenerator) -> Dictionary:
	var rect_points := PackedVector2Array([
		Vector2.ZERO, Vector2(card_width, 0.0), Vector2(card_width, card_height), Vector2(0.0, card_height)
	])
	var far := (card_width + card_height) * 4.0
	var ray_count := rng.randi_range(7, 9)
	var angles: Array[float] = []
	for i in range(ray_count):
		angles.append(TAU * (float(i) + rng.randf_range(-0.28, 0.28)) / float(ray_count))
	var dirs: Array[Vector2] = []
	var ring1 := PackedVector2Array()
	var ring2 := PackedVector2Array()
	var rays: Array[PackedVector2Array] = []
	for i in range(ray_count):
		var dir := Vector2.from_angle(angles[i])
		dirs.append(dir)
		var exit_distance := _rect_ray_exit_distance(impact, dir, card_width, card_height)
		var r1 := impact + dir * exit_distance * 0.32 * rng.randf_range(0.8, 1.2)
		var r2 := impact + dir * exit_distance * 0.64 * rng.randf_range(0.85, 1.15)
		ring1.append(r1)
		ring2.append(r2)
		rays.append(PackedVector2Array([impact, r1, r2, impact + dir * exit_distance]))
	var shards: Array[PackedVector2Array] = []
	var min_area := card_width * card_height * 0.0008
	for i in range(ray_count):
		var j := (i + 1) % ray_count
		var angle_next := angles[j] + (TAU if j == 0 else 0.0)
		var mid := Vector2.from_angle((angles[i] + angle_next) * 0.5)
		var wedge := PackedVector2Array([impact, impact + dirs[i] * far, impact + mid * far, impact + dirs[j] * far])
		for wedge_part in Geometry2D.intersect_polygons(wedge, rect_points):
			for poly in Geometry2D.intersect_polygons(wedge_part, ring1):
				if _polygon_points_area(poly) >= min_area:
					shards.append(poly)
			for band in Geometry2D.clip_polygons(ring2, ring1):
				for poly in Geometry2D.intersect_polygons(wedge_part, band):
					if _polygon_points_area(poly) >= min_area:
						shards.append(poly)
			for poly in Geometry2D.clip_polygons(wedge_part, ring2):
				if _polygon_points_area(poly) >= min_area:
					shards.append(poly)
	return {"rays": rays, "rings": [ring1, ring2], "shards": shards}


func _rect_ray_exit_distance(origin: Vector2, dir: Vector2, width: float, height: float) -> float:
	var best := width + height
	if absf(dir.x) > 0.0001:
		var tx := ((width if dir.x > 0.0 else 0.0) - origin.x) / dir.x
		if tx > 0.0:
			best = minf(best, tx)
	if absf(dir.y) > 0.0001:
		var ty := ((height if dir.y > 0.0 else 0.0) - origin.y) / dir.y
		if ty > 0.0:
			best = minf(best, ty)
	return best


func _polygon_points_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area * 0.5)


func _crack_stage(overlay: Control, geometry: Dictionary) -> void:
	if not is_instance_valid(overlay):
		return
	var cracks := Node2D.new()
	cracks.name = "crack_lines"
	overlay.add_child(cracks)
	for ray in geometry["rays"]:
		_add_crack_line(cracks, ray, false)
	for ring in geometry["rings"]:
		_add_crack_line(cracks, ring, true)
	cracks.modulate.a = 0.0
	var fade := cracks.create_tween()
	fade.tween_property(cracks, "modulate:a", 1.0, 0.07)
	var shake := overlay.create_tween()
	shake.tween_property(overlay, "position", Vector2(3.0, -2.0), 0.03).as_relative()
	shake.tween_property(overlay, "position", Vector2(-5.0, 3.0), 0.05).as_relative()
	shake.tween_property(overlay, "position", Vector2(2.0, -1.0), 0.04).as_relative()


func _add_crack_line(parent: Node2D, points: PackedVector2Array, closed: bool) -> void:
	var glow := Line2D.new()
	glow.points = points
	glow.closed = closed
	glow.width = 5.0
	glow.default_color = Color(1.0, 1.0, 1.0, 0.22)
	parent.add_child(glow)
	var line := Line2D.new()
	line.points = points
	line.closed = closed
	line.width = 2.0
	line.default_color = Color(1.0, 1.0, 1.0, 0.85)
	parent.add_child(line)


func _shatter_stage(overlay: Control, geometry: Dictionary, texture: Texture2D, impact: Vector2, card_width: float, rng: RandomNumberGenerator) -> void:
	if not is_instance_valid(overlay):
		return
	var cracks := overlay.get_node_or_null("crack_lines")
	if cracks != null:
		cracks.queue_free()
	var jolt := overlay.create_tween()
	jolt.tween_property(overlay, "position", Vector2(-4.0, 3.0), 0.03).as_relative()
	jolt.tween_property(overlay, "position", Vector2(4.0, -3.0), 0.05).as_relative()
	for shard_points in geometry["shards"]:
		var centroid := Vector2.ZERO
		for point in shard_points:
			centroid += point
		centroid /= float(shard_points.size())
		var local := PackedVector2Array()
		for point in shard_points:
			local.append(point - centroid)
		var shard := Polygon2D.new()
		shard.polygon = local
		shard.uv = shard_points
		shard.texture = texture
		shard.position = centroid
		overlay.add_child(shard)
		var direction := centroid - impact
		direction = direction.normalized() if direction.length() > 0.001 else Vector2.from_angle(rng.randf_range(0.0, TAU))
		direction = (direction + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))).normalized()
		var fly_distance := card_width * rng.randf_range(0.45, 0.95)
		var duration := rng.randf_range(0.55, 0.85)
		var target := centroid + direction * fly_distance + Vector2(0.0, card_width * 0.18)
		var tween := shard.create_tween().set_parallel(true)
		tween.tween_property(shard, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "rotation", rng.randf_range(-1.6, 1.6), duration)
		tween.tween_property(shard, "modulate:a", 0.0, duration * 0.7).set_delay(duration * 0.3)


func _burn_seed_points() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := rng.randi_range(3, 4)
	var seeds := PackedVector2Array()
	for attempt in range(64):
		if seeds.size() >= count:
			break
		var candidate := Vector2(rng.randf_range(0.06, 0.94), rng.randf_range(0.06, 0.94))
		var separated := true
		for seed in seeds:
			if candidate.distance_to(seed) < 0.30:
				separated = false
				break
		if separated:
			seeds.append(candidate)
	if seeds.is_empty():
		seeds.append(Vector2(0.5, 0.5))
	while seeds.size() < 4:
		var base: Vector2 = seeds[rng.randi_range(0, seeds.size() - 1)]
		seeds.append(base + Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05)))
	return seeds


func _burn_field_max(seeds: PackedVector2Array, aspect: float) -> float:
	var max_distance := 0.0
	for gy in range(7):
		for gx in range(7):
			var point := Vector2(aspect * float(gx) / 6.0, float(gy) / 6.0)
			var nearest := 1e9
			for seed in seeds:
				nearest = minf(nearest, point.distance_to(Vector2(seed.x * aspect, seed.y)))
			max_distance = maxf(max_distance, nearest)
	return max_distance / 1.55 + 0.09


func _burn_shader_resource() -> Shader:
	if burn_shader == null:
		burn_shader = Shader.new()
		burn_shader.code = BURN_SHADER_CODE
	return burn_shader


func _burn_noise_texture() -> Texture2D:
	if burn_noise == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.045
		noise.fractal_octaves = 2
		burn_noise = ImageTexture.create_from_image(noise.get_seamless_image(192, 192))
	return burn_noise


func _animate_flip_fallback(card: Control, overlay: Control) -> void:
	card.pivot_offset = card.size * 0.5
	overlay.pivot_offset = card.size * 0.5
	var tween := card.create_tween()
	tween.tween_interval(0.45)
	tween.tween_property(overlay, "scale:x", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(overlay.queue_free)
	tween.tween_property(card, "scale:x", 1.0, 0.26).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
