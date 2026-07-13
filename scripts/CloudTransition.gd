class_name CloudTransition
extends CanvasLayer

signal finished

const DIRECTION_FORWARD := 1
const DIRECTION_BACK := -1

const CLOUD_LEFT := preload("res://assets/ui/transitions/clouds/cloud-left.png")
const CLOUD_RIGHT := preload("res://assets/ui/transitions/clouds/cloud-right.png")
const CLOUD_TOP := preload("res://assets/ui/transitions/clouds/cloud-top.png")
const CLOUD_BOTTOM := preload("res://assets/ui/transitions/clouds/cloud-bottom.png")
const CLOUD_FOREGROUND := preload("res://assets/ui/transitions/clouds/cloud-foreground.png")
const CLOUD_CENTER := preload("res://assets/ui/transitions/clouds/cloud-center.png")

const BASE_COVER_COLOR := Color("f5ead7")
const CLOSE_DURATION := 0.86
const OPEN_DURATION := 0.82
const FULL_COVER_HOLD := 0.14
const NEW_SCREEN_HOLD := 0.10

var _running := false
var _cover: ColorRect
var _clouds: Array[Sprite2D] = []
var _cover_positions: Array[Vector2] = []
var _exit_positions: Array[Vector2] = []
var _base_scales: Array[Vector2] = []


func _init() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(direction: int, color: Color, switch_screen: Callable) -> void:
	if _running:
		return
	_running = true
	_build_overlay(direction, color)

	var close := create_tween().set_parallel(true)
	close.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for index in _clouds.size():
		var cloud := _clouds[index]
		var delay := float(_cloud_specs()[index]["delay"])
		close.tween_property(cloud, "position", _cover_positions[index], CLOSE_DURATION) \
			.set_delay(delay).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		close.tween_property(cloud, "scale", _base_scales[index], CLOSE_DURATION * 0.9) \
			.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		close.tween_property(cloud, "modulate:a", 1.0, 0.46) \
			.set_delay(delay + 0.02).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	close.tween_property(_cover, "modulate:a", 1.0, 0.36) \
		.set_delay(0.60).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await close.finished
	_cover.modulate.a = 1.0
	await get_tree().create_timer(FULL_COVER_HOLD, true, false, true).timeout

	switch_screen.call()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(NEW_SCREEN_HOLD, true, false, true).timeout

	var open := _create_open_tween()
	await open.finished
	_finish()


func play_launch(color: Color, title_texture: Texture2D) -> void:
	if _running:
		return
	_running = true
	_build_overlay(DIRECTION_FORWARD, color)
	_cover.modulate.a = 1.0
	for index in _clouds.size():
		_clouds[index].position = _cover_positions[index]
		_clouds[index].scale = _base_scales[index]
		_clouds[index].modulate.a = 1.0
	var title := _add_launch_title(title_texture)
	await get_tree().create_timer(0.38, true, false, true).timeout

	var reveal := _create_open_tween()
	if title != null:
		reveal.parallel().tween_property(title, "modulate:a", 0.0, 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await reveal.finished
	_finish()


func _build_overlay(direction: int, color: Color) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var blocker := Control.new()
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.position = Vector2.ZERO
	blocker.size = viewport_size
	add_child(blocker)

	_cover = ColorRect.new()
	_cover.color = BASE_COVER_COLOR.lerp(color.lightened(0.72), 0.08)
	_cover.modulate.a = 0.0
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.position = Vector2.ZERO
	_cover.size = viewport_size
	add_child(_cover)

	var base_width := maxf(viewport_size.x, viewport_size.y * 0.58)
	var specs := _cloud_specs()
	for index in specs.size():
		var spec: Dictionary = specs[index]
		var cloud := Sprite2D.new()
		cloud.texture = spec["texture"] as Texture2D
		cloud.centered = true
		cloud.z_index = index + 1
		cloud.modulate = Color(1.0, 1.0, 1.0, 0.0)
		add_child(cloud)

		var texture_size := cloud.texture.get_size()
		var scale_factor := base_width * float(spec["width"]) / maxf(1.0, texture_size.x)
		var base_scale := Vector2.ONE * scale_factor
		var sprite_size := texture_size * scale_factor
		var cover_normalized: Vector2 = spec["cover"]
		if direction == DIRECTION_BACK:
			cover_normalized.x = 1.0 - cover_normalized.x
		var cover_position := cover_normalized * viewport_size
		var entry_edge: Vector2 = spec["edge"]
		if direction == DIRECTION_BACK:
			entry_edge = -entry_edge
		var drift: Vector2 = spec["drift"]
		if direction == DIRECTION_BACK:
			drift.x = -drift.x
		var start_position := _offscreen_position(entry_edge, sprite_size, cover_position, -drift)
		var exit_position := _offscreen_position(-entry_edge, sprite_size, cover_position, drift)

		cloud.position = start_position
		cloud.scale = base_scale * 0.96
		_clouds.append(cloud)
		_cover_positions.append(cover_position)
		_exit_positions.append(exit_position)
		_base_scales.append(base_scale)


func _create_open_tween() -> Tween:
	var open := create_tween().set_parallel(true)
	open.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for index in _clouds.size():
		var cloud := _clouds[index]
		var delay := float(_cloud_specs()[index]["exit_delay"])
		open.tween_property(cloud, "position", _exit_positions[index], OPEN_DURATION) \
			.set_delay(delay).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		open.tween_property(cloud, "scale", _base_scales[index] * 1.035, OPEN_DURATION) \
			.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		open.tween_property(cloud, "modulate:a", 0.0, 0.54) \
			.set_delay(delay + 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	open.tween_property(_cover, "modulate:a", 0.0, 0.70) \
		.set_delay(0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return open


func _offscreen_position(edge: Vector2, sprite_size: Vector2, cover_position: Vector2, drift: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := maxf(48.0, minf(viewport_size.x, viewport_size.y) * 0.05)
	var position := cover_position + drift * viewport_size
	if absf(edge.x) > 0.5:
		position.x = -sprite_size.x * 0.5 - margin if edge.x < 0.0 else viewport_size.x + sprite_size.x * 0.5 + margin
	else:
		position.y = -sprite_size.y * 0.5 - margin if edge.y < 0.0 else viewport_size.y + sprite_size.y * 0.5 + margin
	return position


func _cloud_specs() -> Array[Dictionary]:
	return [
		{
			"texture": CLOUD_TOP,
			"cover": Vector2(0.50, 0.12),
			"edge": Vector2.UP,
			"drift": Vector2(0.04, 0.03),
			"width": 1.26,
			"delay": 0.00,
			"exit_delay": 0.04,
		},
		{
			"texture": CLOUD_BOTTOM,
			"cover": Vector2(0.50, 0.88),
			"edge": Vector2.DOWN,
			"drift": Vector2(-0.04, -0.03),
			"width": 1.30,
			"delay": 0.08,
			"exit_delay": 0.00,
		},
		{
			"texture": CLOUD_LEFT,
			"cover": Vector2(0.14, 0.35),
			"edge": Vector2.LEFT,
			"drift": Vector2(0.02, -0.04),
			"width": 1.34,
			"delay": 0.04,
			"exit_delay": 0.08,
		},
		{
			"texture": CLOUD_RIGHT,
			"cover": Vector2(0.86, 0.64),
			"edge": Vector2.RIGHT,
			"drift": Vector2(-0.02, 0.04),
			"width": 1.32,
			"delay": 0.12,
			"exit_delay": 0.03,
		},
		{
			"texture": CLOUD_CENTER,
			"cover": Vector2(0.64, 0.43),
			"edge": Vector2.RIGHT,
			"drift": Vector2(-0.03, -0.03),
			"width": 1.02,
			"delay": 0.16,
			"exit_delay": 0.10,
		},
		{
			"texture": CLOUD_FOREGROUND,
			"cover": Vector2(0.38, 0.59),
			"edge": Vector2.LEFT,
			"drift": Vector2(0.03, 0.03),
			"width": 1.12,
			"delay": 0.20,
			"exit_delay": 0.12,
		},
	]


func _add_launch_title(texture: Texture2D) -> TextureRect:
	if texture == null:
		return null
	var viewport_size := get_viewport().get_visible_rect().size
	var title := TextureRect.new()
	title.texture = texture
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var title_width := minf(viewport_size.x * 0.58, 620.0)
	var title_height := title_width * float(texture.get_height()) / maxf(1.0, float(texture.get_width()))
	title.position = Vector2((viewport_size.x - title_width) * 0.5, viewport_size.y * 0.16)
	title.size = Vector2(title_width, title_height)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.z_index = 20
	add_child(title)
	return title


func _finish() -> void:
	_running = false
	finished.emit()
	queue_free()
