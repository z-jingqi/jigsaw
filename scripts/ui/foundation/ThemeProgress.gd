class_name ThemeProgress
extends Control

enum Variant { JOURNEY, NUMERIC_CARD }

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
	var ratio := clampf(float(_read("ratio")), 0.0, 1.0)
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
			_motion.tween_property(numeric, "modulate:a", 1.0, motion_tokens.numeric_progress_duration)
			if is_complete and not _last_is_complete:
				numeric_completion.scale = Vector2(0.8, 0.8)
				numeric_completion.pivot_offset = numeric_completion.size * 0.5
				numeric_completion.visible = true
				_motion.parallel().tween_property(numeric_completion, "scale", Vector2.ONE, motion_tokens.numeric_completion_duration)
		else:
			numeric.modulate.a = 1.0
			numeric_completion.scale = Vector2.ONE
		journey.visible = false
		_commit_state(paw_count, is_complete)
		return
	numeric_completion.visible = false
	var width := maxf(1.0, journey.size.x)
	var icon_size := minf(42.0, journey.size.y)
	cat.size = Vector2(icon_size, icon_size)
	var cat_target := Vector2((width - icon_size) * ratio, maxf(0.0, (journey.size.y - icon_size) * 0.5))
	if reduced_motion or not _has_rendered:
		cat.position = cat_target
	fish.size = Vector2(icon_size, icon_size)
	fish.position = Vector2(width - icon_size, maxf(0.0, (journey.size.y - icon_size) * 0.5))
	completion.size = Vector2(icon_size, icon_size)
	completion.position = fish.position
	fish.visible = not is_complete
	completion.visible = is_complete
	for index in _paws.size():
		var paw := _paws[index]
		paw.visible = index < paw_count
		paw.size = Vector2(18.0, 18.0)
		var progress := float(index + 1) / 6.0
		paw.position = Vector2((width - icon_size) * progress, journey.size.y * (0.20 if index % 2 == 0 else 0.56))
		if reduced_motion or not _has_rendered:
			paw.scale = Vector2.ONE
	if not reduced_motion and _has_rendered:
		_motion = create_tween()
		_motion.set_trans(motion_tokens.settle_transition).set_ease(motion_tokens.settle_ease)
		_motion.tween_property(cat, "position", cat_target, motion_tokens.progress_cat_duration)
		for index in mini(paw_count, _paws.size()):
			var paw := _paws[index]
			if index >= _last_paw_count:
				paw.scale = Vector2(0.8, 0.8)
				paw.pivot_offset = paw.size * 0.5
				_motion.parallel().tween_property(paw, "scale", Vector2.ONE, motion_tokens.progress_paw_duration)
		if is_complete and not _last_is_complete:
			completion.scale = Vector2(0.94, 0.94)
			completion.pivot_offset = completion.size * 0.5
			_motion.parallel().tween_property(completion, "scale", Vector2.ONE, motion_tokens.progress_completion_duration)
	else:
		completion.scale = Vector2.ONE
	_commit_state(paw_count, is_complete)


func active_motion_count() -> int:
	return 1 if _motion != null and _motion.is_valid() and _motion.is_running() else 0


func play_cold_start() -> void:
	if reduced_motion or display_variant != Variant.JOURNEY:
		return
	_stop_motion()
	_motion = create_tween()
	_motion.set_trans(motion_tokens.enter_transition).set_ease(motion_tokens.enter_ease)
	for index in _paws.size():
		var paw := _paws[index]
		if not paw.visible:
			continue
		paw.modulate.a = 0.0
		paw.scale = Vector2(0.8, 0.8)
		paw.pivot_offset = paw.size * 0.5
		_motion.tween_interval(0.05 if index > 0 else 0.0)
		_motion.tween_property(paw, "modulate:a", 1.0, motion_tokens.progress_paw_duration)
		_motion.parallel().tween_property(paw, "scale", Vector2.ONE, motion_tokens.progress_paw_duration)


func _commit_state(paw_count: int, is_complete: bool) -> void:
	_has_rendered = true
	_last_paw_count = paw_count
	_last_is_complete = is_complete


func _stop_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func _exit_tree() -> void:
	_stop_motion()
func _read(field: String) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, 0)
	return _view_model.get(field)
