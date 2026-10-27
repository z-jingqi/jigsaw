extends CanvasLayer
## Explicit, bounded first-render preparation. Compilation cost is not hidden as gameplay.

signal canceled
signal ready_to_start

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const FrameGate := preload("res://scripts/runtime/CancellableFrame.gd")
const Content := preload("res://scripts/runtime/data/ContentRepository.gd")
const Preview := preload("res://scripts/runtime/presentation/BoxPreviewData.gd")
const BoxWarmup := preload("res://scripts/app/startup/BoxMaterialWarmup.gd")
const GameplayWarmup := preload("res://scripts/app/startup/GameplayMaterialWarmup.gd")
const LOGO := preload("res://assets/ui/brand/jigcat-wordmark.png")
const TIMEOUT_SECONDS := 45.0

var metrics: Dictionary = {}
var prepared_content: ContentRepository
var _generation := 0
var _running := false
var _blocking := true
var _held: Dictionary = {}
var _orphaned: Dictionary = {}
var _box: Control
var _stage: Node2D
var _cover: ColorRect
var _logo: TextureRect
var _status: Label
var _retry: Button
var _timer: Timer


func _ready() -> void:
	layer = 100
	_stage = Node2D.new()
	add_child(_stage)
	_box = BoxWarmup.new()
	add_child(_box)
	_cover = ColorRect.new()
	_cover.color = Clean.PAPER
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(_logo)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_override("font", Clean.FONT)
	_status.add_theme_color_override("font_color", Clean.INK)
	_cover.add_child(_status)
	_retry = Button.new()
	Clean.button(_retry, true)
	_retry.pressed.connect(_begin)
	_cover.add_child(_retry)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_timed_out)
	add_child(_timer)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_begin.call_deferred()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var unit := Clean.canvas_scale(size, get_window())
	_logo.position = Vector2((size.x - 150 * unit) * 0.5, size.y * 0.42 - 26 * unit)
	_logo.size = Vector2(150, 52) * unit
	_status.position = Vector2(24 * unit, size.y * 0.42 + 46 * unit)
	_status.size = Vector2(maxf(0, size.x - 48 * unit), 60 * unit)
	_status.add_theme_font_size_override("font_size", roundi(16 * unit))
	_retry.position = Vector2((size.x - 160 * unit) * 0.5, size.y * 0.42 + 122 * unit)
	_retry.size = Vector2(160, 48) * unit
	_retry.add_theme_font_size_override("font_size", roundi(16 * unit))
	_stage.scale = Vector2.ONE * minf(1.0, size.x / GameplayWarmup.DRAW_SIZE.x)


func _begin() -> void:
	if _running:
		return
	_generation += 1
	var token := _generation
	_running = true
	_status.text = GameStrings.ui_text("startup_preparing")
	_retry.text = GameStrings.ui_text("startup_retry")
	_retry.hide()
	_timer.start(TIMEOUT_SECONDS)
	var started := Time.get_ticks_usec()
	metrics = {"started_usec": started, "ok": false, "stages": []}
	# Paint the honest preparation screen before resource decoding or real draws.
	if not await FrameGate.wait(RenderingServer.frame_post_draw, canceled):
		return
	if not _current(token):
		return
	var content := Content.new()
	prepared_content = content
	var level := content.level_by_id("topic_01", "shanhai_v2_01")
	var config := content.level_config(level)
	if config.is_empty():
		_fail("missing_representative_level", token)
		return
	var texture := content.level_preview_texture(config)
	if texture == null:
		_fail("missing_representative_artwork", token)
		return
	var samples := Preview.build(content, level)
	var box_result: Dictionary = await _box.run(
		texture, {"theme_id": "topic_01", "title": "", "preview_revealed": true}, samples
	)
	if not _current(token):
		return
	metrics["box"] = box_result
	if not box_result.get("ok", false):
		_fail("box_material_preparation_failed", token)
		return
	var gameplay_started := Time.get_ticks_usec()
	var gameplay_ok := await GameplayWarmup.prepare(
		_stage, texture, config, func(): return _current(token), canceled
	)
	if not _current(token):
		return
	metrics["gameplay_ms"] = (Time.get_ticks_usec() - gameplay_started) / 1000.0
	if not gameplay_ok:
		_fail("gameplay_material_preparation_failed", token)
		return
	texture = null
	_timer.stop()
	_running = false
	metrics["ok"] = true
	metrics["elapsed_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	print("STARTUP_PREPARATION ", JSON.stringify(metrics))
	ready_to_start.emit()


func reveal_home() -> void:
	# Runtime is now constructed under the cover. Render the actual Home once.
	if not await FrameGate.wait(RenderingServer.frame_post_draw, canceled):
		return
	if not is_inside_tree():
		return
	_cover.hide()
	_box.hide()
	_stage.hide()
	_blocking = false
	_release_when_idle()


func _input(event: InputEvent) -> void:
	if (
		_blocking
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode in [KEY_ESCAPE, KEY_BACK]
	):
		get_viewport().set_input_as_handled()
		cancel()
		get_tree().quit()
		return
	var pointer := -2
	var down := false
	var up := false
	if event is InputEventScreenTouch:
		pointer = event.index
		down = event.pressed and not event.canceled
		up = not event.pressed or event.canceled
	elif event is InputEventScreenDrag:
		pointer = event.index
	elif event is InputEventMouseButton:
		pointer = -1
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseMotion:
		pointer = -1
	if _orphaned.has(pointer):
		if down:
			_orphaned.erase(pointer)
		elif up or event is InputEventScreenDrag or event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
			if up:
				_orphaned.erase(pointer)
			_release_when_idle()
			return
	if _blocking:
		if down:
			_held[pointer] = true
		if up:
			_held.erase(pointer)
		# Failed preparation deliberately leaves the sole retry button usable.
		if not _retry.visible:
			get_viewport().set_input_as_handled()
	elif _held.has(pointer):
		if up:
			_held.erase(pointer)
		get_viewport().set_input_as_handled()
	_release_when_idle()


func _release_when_idle() -> void:
	if not _blocking and _held.is_empty() and _orphaned.is_empty():
		queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _blocking and is_inside_tree():
		cancel()
		get_tree().quit()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		for pointer in _held:
			_orphaned[pointer] = true
		_held.clear()


func cancel() -> void:
	_generation += 1
	_running = false
	canceled.emit()
	if is_instance_valid(_box):
		_box.cancel()
	if is_instance_valid(_timer):
		_timer.stop()


func _current(token: int) -> bool:
	return token == _generation and is_inside_tree() and _running


func _fail(reason: String, token: int) -> void:
	if token != _generation or not is_inside_tree():
		return
	cancel()
	metrics["error"] = reason
	_status.text = GameStrings.ui_text("startup_failed")
	_retry.show()
	print("STARTUP_PREPARATION_FAILED ", JSON.stringify(metrics))


func _timed_out() -> void:
	_fail("timeout", _generation)


func _exit_tree() -> void:
	cancel()
