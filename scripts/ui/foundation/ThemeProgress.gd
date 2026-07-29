class_name ThemeProgress
extends Control

enum Variant { JOURNEY, NUMERIC_CARD }

const COMPLETION_FISH_WIDTH_RATIO := 0.5

@export var display_variant: Variant = Variant.JOURNEY
@export var reduced_motion := false
@export var motion_tokens: MotionTokens

@onready var journey: Control = $Journey
@onready var cat: TextureRect = $Journey/Cat
@onready var fish: TextureRect = $Journey/Fish
@onready var completion: TextureRect = $Journey/Completion
@onready var numeric: Label = $Numeric
@onready var numeric_completion: TextureRect = $NumericCompletion

var _view_model: Variant
var _paws: Array[TextureRect] = []
var _motion: Tween
var _has_rendered := false
var _last_paw_count := 0
var _last_is_complete := false


func _ready() -> void:
	if motion_tokens == null:
		motion_tokens = preload("res://themes/motion_tokens.tres")
	for child in $Journey/Paws.get_children():
		if child is TextureRect:
			_paws.append(child)
	resized.connect(_render)
	_render()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	_render()


func set_progress_data(value: Dictionary) -> void:
	_view_model = value
	_render()


func _render() -> void:
	if not is_node_ready() or _view_model == null:
		return
	_stop_motion()
	var completed := int(_read("completed_modes"))
	var total := int(_read("total_modes"))
	var paw_count := clampi(int(_read("paw_count")), 0, 5)
	var is_complete := bool(_read("is_complete"))
	journey.visible = display_variant == Variant.JOURNEY
	numeric.visible = display_variant == Variant.NUMERIC_CARD
	numeric.text = "%d / %d" % [completed, total]
	tooltip_text = str(_read("accessibility_text"))
	# Control does not expose Button's native accessibility_name property; retain
	# the equivalent semantic label for the screen-level accessibility adapter.
	set_meta("accessibility_name", tooltip_text)
	if display_variant == Variant.NUMERIC_CARD:
		numeric_completion.visible = is_complete
		if not reduced_motion and _has_rendered:
			numeric.modulate.a = 0.0
			_motion = create_tween()
			_motion.set_trans(motion_tokens.enter_transition).set_ease(motion_tokens.enter_ease)
			_motion.tween_property(
				numeric, "modulate:a", 1.0, motion_tokens.numeric_progress_duration
			)
			if is_complete and not _last_is_complete:
				numeric_completion.scale = Vector2(0.8, 0.8)
				numeric_completion.pivot_offset = numeric_completion.size * 0.5
				numeric_completion.visible = true
				_motion.parallel().tween_property(
					numeric_completion,
					"scale",
					Vector2.ONE,
					motion_tokens.numeric_completion_duration
				)
		else:
			numeric.modulate.a = 1.0
			numeric_completion.scale = Vector2.ONE
		journey.visible = false
		if _motion != null:
			_motion.finished.connect(_stop_motion, CONNECT_ONE_SHOT)
		_commit_state(paw_count, is_complete)
		return
	numeric_completion.visible = false
	var width := maxf(1.0, journey.size.x)
	var height := maxf(1.0, journey.size.y)
	var cat_size := _fit_texture(cat.texture, height * 0.82)
	var completion_size := _fit_texture(completion.texture, cat_size.y)
	var fish_size := _fit_texture_width(
		fish.texture, completion_size.x * COMPLETION_FISH_WIDTH_RATIO
	)
	cat.size = cat_size
	fish.size = fish_size
	completion.size = completion_size
	var cat_y := maxf(0.0, (height - cat_size.y) * 0.5)
	var ground_y := cat_y + cat_size.y
	var fish_position := Vector2(
		maxf(0.0, width - fish_size.x),
		maxf(0.0, ground_y - fish_size.y),
	)
	var final_cat_x := maxf(0.0, fish_position.x - cat_size.x - height * 0.08)
	var stage_progress := float(paw_count) / 5.0
	var cat_target := Vector2(
		lerpf(0.0, final_cat_x, stage_progress),
		cat_y,
	)
	if reduced_motion or not _has_rendered:
		cat.position = cat_target
	fish.position = fish_position
	completion.position = Vector2(
		clampf(
			final_cat_x + cat_size.x * 0.5 - completion_size.x * 0.5,
			0.0,
			maxf(0.0, width - completion_size.x),
		),
		maxf(0.0, ground_y - completion_size.y),
	)
	var completing_now := is_complete and not _last_is_complete and _has_rendered
	cat.visible = not is_complete or completing_now
	fish.visible = not is_complete or completing_now
	completion.visible = is_complete
	cat.modulate.a = 1.0
	fish.modulate.a = 1.0
	completion.modulate.a = 1.0
	for index in _paws.size():
		var paw := _paws[index]
		paw.visible = not is_complete and index < paw_count
		var paw_size := height * 0.225
		paw.size = Vector2(paw_size, paw_size)
		paw.pivot_offset = paw.size * 0.5
		paw.rotation = PI * 0.5
		var trail_progress := float(index) / 5.0
		var paw_stack_top := maxf(0.0, ground_y - paw_size * 2.0)
		paw.position = Vector2(
			lerpf(0.0, final_cat_x, trail_progress),
			paw_stack_top + (0.0 if index % 2 == 0 else paw_size),
		)
		if reduced_motion or not _has_rendered:
			paw.scale = Vector2.ONE
			paw.modulate.a = 1.0
	if not reduced_motion and _has_rendered:
		_motion = create_tween()
		_motion.set_trans(motion_tokens.settle_transition).set_ease(motion_tokens.settle_ease)
		_motion.tween_property(cat, "position", cat_target, motion_tokens.progress_cat_duration)
		for index in mini(paw_count, _paws.size()):
			var paw := _paws[index]
			if index >= _last_paw_count:
				paw.scale = Vector2(0.8, 0.8)
				paw.modulate.a = 0.0
				paw.pivot_offset = paw.size * 0.5
				_motion.parallel().tween_property(
					paw, "scale", Vector2.ONE, motion_tokens.progress_paw_duration
				)
				_motion.parallel().tween_property(
					paw, "modulate:a", 1.0, motion_tokens.progress_paw_duration
				)
		if completing_now:
			completion.modulate.a = 0.0
			completion.scale = Vector2(0.94, 0.94)
			completion.pivot_offset = completion.size * 0.5
			_motion.parallel().tween_property(
				completion, "scale", Vector2.ONE, motion_tokens.progress_completion_duration
			)
			_motion.parallel().tween_property(
				completion, "modulate:a", 1.0, motion_tokens.progress_completion_duration
			)
			_motion.parallel().tween_property(
				cat, "modulate:a", 0.0, motion_tokens.progress_completion_duration
			)
			_motion.parallel().tween_property(
				fish, "modulate:a", 0.0, motion_tokens.progress_completion_duration
			)
			_motion.parallel().tween_callback(_finish_completion_transition).set_delay(
				motion_tokens.progress_completion_duration
			)
	else:
		completion.scale = Vector2.ONE
	if _motion != null:
		_motion.finished.connect(_stop_motion, CONNECT_ONE_SHOT)
	_commit_state(paw_count, is_complete)


func active_motion_count() -> int:
	return 1 if _motion != null and _motion.is_valid() and _motion.is_running() else 0


func play_cold_start(delay := 0.0) -> void:
	if reduced_motion or display_variant != Variant.JOURNEY:
		return
	_stop_motion()
	_motion = create_tween().set_parallel(true)
	_motion.set_trans(motion_tokens.enter_transition).set_ease(motion_tokens.enter_ease)
	if completion.visible:
		completion.modulate.a = 0.0
		completion.scale = Vector2(0.96, 0.96)
		completion.pivot_offset = completion.size * 0.5
		(
			_motion
			. tween_property(
				completion, "modulate:a", 1.0, motion_tokens.progress_completion_duration
			)
			. set_delay(delay)
		)
		(
			_motion
			. tween_property(
				completion, "scale", Vector2.ONE, motion_tokens.progress_completion_duration
			)
			. set_delay(delay)
		)
	else:
		var cat_target := cat.position
		cat.position.x = 0.0
		cat.modulate.a = 0.0
		fish.modulate.a = 0.0
		_motion.tween_property(fish, "modulate:a", 1.0, motion_tokens.state_duration).set_delay(
			delay
		)
		_motion.tween_property(cat, "modulate:a", 1.0, motion_tokens.state_duration).set_delay(
			delay + 0.04
		)
		(
			_motion
			. tween_property(cat, "position", cat_target, 0.42)
			. set_delay(delay + 0.01)
			. set_trans(motion_tokens.settle_transition)
			. set_ease(motion_tokens.settle_ease)
		)
		for index in _paws.size():
			var paw := _paws[index]
			if not paw.visible:
				continue
			paw.modulate.a = 0.0
			paw.scale = Vector2(0.8, 0.8)
			paw.pivot_offset = paw.size * 0.5
			var paw_delay := delay + 0.08 + float(index) * 0.05
			(
				_motion
				. tween_property(paw, "modulate:a", 1.0, motion_tokens.progress_paw_duration)
				. set_delay(paw_delay)
			)
			(
				_motion
				. tween_property(paw, "scale", Vector2.ONE, motion_tokens.progress_paw_duration)
				. set_delay(paw_delay)
			)
	_motion.finished.connect(_stop_motion, CONNECT_ONE_SHOT)


func finish_motion() -> void:
	_stop_motion()
	var was_reduced := reduced_motion
	reduced_motion = true
	_render()
	reduced_motion = was_reduced


func _commit_state(paw_count: int, is_complete: bool) -> void:
	_has_rendered = true
	_last_paw_count = paw_count
	_last_is_complete = is_complete


func _stop_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func _finish_completion_transition() -> void:
	cat.visible = false
	fish.visible = false
	cat.modulate.a = 1.0
	fish.modulate.a = 1.0


func _exit_tree() -> void:
	_stop_motion()


func _read(field: String) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, 0)
	return _view_model.get(field)


func _fit_texture(texture: Texture2D, target_height: float) -> Vector2:
	if texture == null or texture.get_height() <= 0:
		return Vector2(target_height, target_height)
	var aspect := float(texture.get_width()) / float(texture.get_height())
	return Vector2(target_height * aspect, target_height)


func _fit_texture_width(texture: Texture2D, target_width: float) -> Vector2:
	if texture == null or texture.get_width() <= 0:
		return Vector2(target_width, target_width)
	var aspect := float(texture.get_width()) / float(texture.get_height())
	return Vector2(target_width, target_width / aspect)
