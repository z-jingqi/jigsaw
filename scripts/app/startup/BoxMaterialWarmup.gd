extends Control
## Real draws behind the startup overlay, not resource preloading or a shader guarantee.
## The host must keep this Control visible on the same canvas as its opaque overlay.

signal canceled

const Batches := preload("res://scripts/app/startup/BoxWarmupBatches.gd")
const BoxScene := preload("res://scenes/ui/box/PuzzleBox3D.tscn")
const FrameGate := preload("res://scripts/runtime/CancellableFrame.gd")
const CACHE_SIZE := Vector2i(512, 683)
const DETAIL_SIZE := Vector2i(768, 1024)
var _box: Control
var _generation := 0
var _running := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func run(
	texture: Texture2D,
	packaging: Dictionary,
	mode_samples: Dictionary,
	progress: Callable = Callable()
) -> Dictionary:
	cancel()
	var token := _generation
	var started := Time.get_ticks_usec()
	if texture == null or not is_inside_tree() or not is_visible_in_tree():
		return {"ok": false, "reason": "missing_texture_or_visible_host"}
	for mode in ["polygon", "knob", "swap"]:
		var data: Dictionary = mode_samples.get(mode, {})
		if data.get("pieces", []).is_empty():
			return {"ok": false, "reason": "missing_representative_geometry", "mode": mode}
	_running = true
	_box = BoxScene.instantiate()
	_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_box.position = Vector2.ZERO
	_box.size = Vector2(CACHE_SIZE)
	add_child(_box)
	# Greek printing exercises the actual derivative-based InkLine shader too;
	# this temporary material fixture never changes catalog/progress/packaging data.
	var printed := packaging.duplicate(true)
	printed["theme_id"] = "topic_02"
	if str(printed.get("title", "")).strip_edges().is_empty():
		# Match the production appearance's `title` key, not the presenter key.
		# Empty text creates no glyph draw and cannot prepare Label3D's material.
		printed["title"] = "九尾狐"
	var stages: Array[Dictionary] = [
		{"name": "closed_artwork", "size": CACHE_SIZE, "revealed": true, "mode": ""},
		{"name": "closed_unrevealed", "size": CACHE_SIZE, "revealed": false, "mode": ""},
		{"name": "open_polygon", "size": DETAIL_SIZE, "revealed": true, "mode": "polygon"},
		{"name": "open_knob", "size": DETAIL_SIZE, "revealed": true, "mode": "knob"},
		{"name": "open_swap", "size": DETAIL_SIZE, "revealed": true, "mode": "swap"},
	]
	var measurements: Array[Dictionary] = []
	var prepared_families: Dictionary = {}
	var total_frames := 0
	for index in stages.size():
		if not _current(token):
			return {"ok": false, "canceled": true}
		var stage := stages[index]
		var stage_started := Time.get_ticks_usec()
		printed["preview_revealed"] = stage.revealed
		_box.configure(texture, printed)
		_box.size = Vector2(stage.size)
		var viewport := _box.get_node("Viewport") as SubViewport
		viewport.size = stage.size
		_box.set_open(not stage.mode.is_empty(), true)
		if not stage.mode.is_empty():
			_box.show_mode(StringName(stage.mode), mode_samples[stage.mode].pieces, true)
		_box.set_rendering(true)
		var batches := Batches.new()
		if not batches.collect(_box):
			var reason: String = batches.failure_reason
			_release_box()
			_running = false
			return {"ok": false, "reason": "batch_collection_failed", "details": reason}
		var family_measurements: Array[Dictionary] = []
		for family: String in batches.families():
			if prepared_families.has(family):
				continue
			batches.show_representative(family)
			var family_started := Time.get_ticks_usec()
			# One real material family per draw/frame, then verify the whole box.
			if not await FrameGate.wait(RenderingServer.frame_post_draw, canceled):
				return {"ok": false, "canceled": true}
			if not _current(token):
				return {"ok": false, "canceled": true}
			total_frames += 1
			var family_calls := viewport.get_render_info(
				Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME
			)
			(
				family_measurements
				. append(
					{
						"family": family,
						"elapsed_ms": (Time.get_ticks_usec() - family_started) / 1000.0,
						"draw_calls": family_calls,
					}
				)
			)
			if family_calls > 0:
				prepared_families[family] = true
		batches.restore()
		# The real viewport renders even while covered. Two full draws allow the
		# newly attached/material-changed instance and canvas compositor to submit.
		var full_frames_ms: Array[float] = []
		for frame in 2:
			var frame_started := Time.get_ticks_usec()
			if not await FrameGate.wait(RenderingServer.frame_post_draw, canceled):
				return {"ok": false, "canceled": true}
			if not _current(token):
				return {"ok": false, "canceled": true}
			full_frames_ms.append((Time.get_ticks_usec() - frame_started) / 1000.0)
		total_frames += 2
		var calls := viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME
		)
		(
			measurements
			. append(
				{
					"stage": stage.name,
					"elapsed_ms": (Time.get_ticks_usec() - stage_started) / 1000.0,
					"draw_calls": calls,
					"frames": 2,
					"viewport_size": stage.size,
					"material_batches": family_measurements,
					"full_frames_ms": full_frames_ms,
				}
			)
		)
		if calls <= 0:
			_release_box()
			_running = false
			return {"ok": false, "reason": "viewport_not_drawn", "stages": measurements}
		if progress.is_valid():
			progress.call(index + 1, stages.size(), stage.name)
	if not _current(token):
		return {"ok": false, "canceled": true}
	_release_box()
	_running = false
	return {
		"ok": true,
		"elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"stages": measurements,
		"frames": total_frames,
		"material_families": prepared_families.size(),
		"scope": "representative real draws; driver caches and later variants are not guaranteed",
	}


func cancel() -> void:
	_generation += 1
	_running = false
	canceled.emit()
	_release_box()


func is_running() -> bool:
	return _running


func _current(token: int) -> bool:
	return token == _generation and is_inside_tree() and is_instance_valid(_box)


func _release_box() -> void:
	if is_instance_valid(_box):
		_box.set_rendering(false)
		_box.cancel_motion()
		_box.free()
	_box = null


func _exit_tree() -> void:
	cancel()
