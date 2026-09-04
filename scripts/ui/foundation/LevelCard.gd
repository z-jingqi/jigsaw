class_name LevelCard
extends ActionButton

const ModeStatusIconScene := preload("res://scenes/ui/foundation/ModeStatusIcon.tscn")
const TITLE_MAX_FONT_SIZE := 40
const TITLE_MIN_SINGLE_LINE_FONT_SIZE := 28
const TITLE_WRAP_MIN_FONT_SIZE := 18
const LOCKED_SHAKE_OFFSETS := [-14.0, 12.0, -10.0, 8.0, -5.0, 0.0]
const LOCKED_SHAKE_STEP_DURATION := 0.05

@onready var title_label: Label = $Title
@onready var thumbnail: TextureRect = $Thumbnail
@onready var mode_row: HBoxContainer = $ModeRow
@onready var completion_paw: TextureRect = $CompletionPaw

var level_id := ""
var _view_model: Variant
var _focus_variant := false
var _is_locked := false
var _locked_feedback_tween: Tween
var _locked_feedback_origin := Vector2.ZERO
var _locked_feedback_active := false
var _normal_style: StyleBox
var _hover_style: StyleBox
var _pressed_style: StyleBox


func _ready() -> void:
	kind = Kind.CARD
	super._ready()
	_normal_style = get_theme_stylebox(&"normal")
	_hover_style = get_theme_stylebox(&"hover")
	_pressed_style = get_theme_stylebox(&"pressed")
	resized.connect(_apply_layout)
	_apply_layout()
	if _view_model != null:
		_apply_view_model()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if is_node_ready():
		_apply_view_model()


func set_focus_variant(enabled: bool) -> void:
	_focus_variant = enabled
	if not is_node_ready():
		return
	mode_row.visible = not enabled
	var mode_states: Array = _read("modes", [])
	completion_paw.visible = not enabled and not _is_locked and _all_modes_completed(mode_states)
	_apply_layout()


func is_focus_variant() -> bool:
	return _focus_variant


func is_locked() -> bool:
	return _is_locked


func needs_thumbnail() -> bool:
	return (
		is_node_ready()
		and thumbnail.texture == null
		and _view_model != null
		and _view_model is Object
		and _view_model.has_method(&"load_thumbnail")
	)


func load_pending_thumbnail() -> void:
	if needs_thumbnail():
		thumbnail.texture = _view_model.call(&"load_thumbnail") as Texture2D


func play_locked_feedback() -> void:
	if not _is_locked:
		return
	cancel_locked_feedback()
	if _reduced_motion:
		return
	_locked_feedback_origin = position
	_locked_feedback_active = true
	_locked_feedback_tween = create_tween()
	_locked_feedback_tween.set_trans(Tween.TRANS_SINE)
	_locked_feedback_tween.set_ease(Tween.EASE_IN_OUT)
	for offset in LOCKED_SHAKE_OFFSETS:
		_locked_feedback_tween.tween_property(
			self,
			^"position",
			_locked_feedback_origin + Vector2(float(offset), 0.0),
			LOCKED_SHAKE_STEP_DURATION
		)
	_locked_feedback_tween.tween_callback(_finish_locked_feedback)


func cancel_locked_feedback() -> void:
	if _locked_feedback_tween != null and _locked_feedback_tween.is_valid():
		_locked_feedback_tween.kill()
	_locked_feedback_tween = null
	if _locked_feedback_active:
		position = _locked_feedback_origin
	_locked_feedback_active = false


func set_reduced_motion(enabled: bool) -> void:
	super.set_reduced_motion(enabled)
	if enabled:
		cancel_locked_feedback()


func cancel_motion() -> void:
	super.cancel_motion()
	cancel_locked_feedback()


func active_motion_count() -> int:
	return super.active_motion_count() + (1 if _locked_feedback_active else 0)


func _exit_tree() -> void:
	cancel_locked_feedback()
	super._exit_tree()


func _apply_view_model() -> void:
	cancel_locked_feedback()
	var previous_level_id := level_id
	level_id = str(_read("level_id"))
	title_label.text = str(_read("title"))
	_is_locked = bool(_read("locked"))
	disabled = false
	_apply_locked_style()
	var thumbnail_texture := _read("thumbnail") as Texture2D
	if thumbnail_texture != null or previous_level_id != level_id:
		thumbnail.texture = thumbnail_texture
	thumbnail.modulate = Color.WHITE
	mode_row.visible = not _focus_variant
	var mode_states: Array = _read("modes", [])
	completion_paw.visible = (
		not _focus_variant and not _is_locked and _all_modes_completed(mode_states)
	)
	_reconcile_modes(mode_states)
	tooltip_text = title_label.text
	accessibility_name = (
		"%s, %s"
		% [
			title_label.text,
			"Locked" if _is_locked else ("Completed" if completion_paw.visible else "Available")
		]
	)
	accessibility_description = "Locked level" if _is_locked else ""
	_apply_layout()


func _apply_locked_style() -> void:
	if not is_node_ready():
		return
	if _is_locked:
		var disabled_style := get_theme_stylebox(&"disabled")
		add_theme_stylebox_override(&"normal", disabled_style)
		add_theme_stylebox_override(&"hover", disabled_style)
		add_theme_stylebox_override(&"pressed", disabled_style)
		return
	add_theme_stylebox_override(&"normal", _normal_style)
	add_theme_stylebox_override(&"hover", _hover_style)
	add_theme_stylebox_override(&"pressed", _pressed_style)


func _finish_locked_feedback() -> void:
	if _locked_feedback_active:
		position = _locked_feedback_origin
	_locked_feedback_active = false
	_locked_feedback_tween = null


func _reconcile_modes(states: Array) -> void:
	for child in mode_row.get_children():
		mode_row.remove_child(child)
		child.queue_free()
	for mode_model in states:
		var status_icon := ModeStatusIconScene.instantiate() as ModeStatusIcon
		mode_row.add_child(status_icon)
		status_icon.set_variant(&"card")
		status_icon.set_interactive(false)
		status_icon.set_view_model(mode_model)


func _apply_layout() -> void:
	if not is_node_ready() or size.x <= 0.0:
		return
	if _focus_variant:
		_apply_focus_layout()
		return
	var inset := 9.0
	var image_height := minf(size.y * 0.73, size.x * 0.96)
	thumbnail.position = Vector2(inset, inset)
	thumbnail.size = Vector2(size.x - inset * 2.0, image_height - inset)
	var remaining := maxf(0.0, size.y - image_height)
	var title_height := minf(70.0, maxf(56.0, remaining * 0.32))
	title_label.position = Vector2(32, image_height + 6.0)
	title_label.size = Vector2(maxf(0.0, size.x - 64.0), title_height)
	_fit_title_font(title_label.size.x, title_label.size.y)
	mode_row.position = Vector2(0, image_height + title_height - 1.0)
	mode_row.size = Vector2(size.x, maxf(0.0, size.y - mode_row.position.y - 10.0))
	var paw_width := clampf(size.x * 0.17, 72.0, 90.0)
	completion_paw.size = Vector2(paw_width, paw_width * 0.863)
	completion_paw.pivot_offset = completion_paw.size * 0.5
	completion_paw.rotation_degrees = 30.0
	completion_paw.position = Vector2(size.x - inset - completion_paw.size.x - 12.0, inset + 26.0)
	var shader_material := thumbnail.material as ShaderMaterial
	if shader_material != null and image_height > 0.0:
		shader_material.set_shader_parameter("rect_aspect", thumbnail.size.x / thumbnail.size.y)
		shader_material.set_shader_parameter("rect_size", thumbnail.size)
		shader_material.set_shader_parameter("saturation", 0.16 if _is_locked else 1.0)
		shader_material.set_shader_parameter("opacity", 0.56 if _is_locked else 1.0)


func _apply_focus_layout() -> void:
	var inset := 10.0
	var image_side := minf(size.x - inset * 2.0, maxf(0.0, size.y - 112.0))
	thumbnail.position = Vector2(inset, inset)
	thumbnail.size = Vector2(image_side, image_side)
	var title_top := inset + image_side + 6.0
	title_label.position = Vector2(34.0, title_top)
	title_label.size = Vector2(maxf(0.0, size.x - 68.0), maxf(0.0, size.y - title_top - 12.0))
	_fit_title_font(title_label.size.x, title_label.size.y)
	mode_row.visible = false
	completion_paw.visible = false
	var shader_material := thumbnail.material as ShaderMaterial
	if shader_material != null and thumbnail.size.y > 0.0:
		shader_material.set_shader_parameter("rect_aspect", 1.0)
		shader_material.set_shader_parameter("rect_size", thumbnail.size)
		shader_material.set_shader_parameter("saturation", 1.0)
		shader_material.set_shader_parameter("opacity", 1.0)


func _fit_title_font(max_width: float, max_height: float) -> void:
	var font := title_label.get_theme_font("font")
	var single_line_size := TITLE_MAX_FONT_SIZE
	while single_line_size >= TITLE_MIN_SINGLE_LINE_FONT_SIZE:
		var text_width := (
			font
			. get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, single_line_size)
			. x
		)
		if text_width <= max_width:
			title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			title_label.max_lines_visible = 1
			title_label.add_theme_font_size_override("font_size", single_line_size)
			return
		single_line_size -= 2

	var wrapped_size := TITLE_MAX_FONT_SIZE
	while wrapped_size > TITLE_WRAP_MIN_FONT_SIZE:
		var text_block := font.get_multiline_string_size(
			title_label.text, HORIZONTAL_ALIGNMENT_CENTER, max_width, wrapped_size
		)
		if text_block.x <= max_width and text_block.y <= max_height:
			break
		wrapped_size -= 2
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.add_theme_font_size_override("font_size", wrapped_size)


func _all_modes_completed(states: Array) -> bool:
	if states.size() != 3:
		return false
	for mode_state in states:
		var status: StringName = StringName(
			mode_state.get("status", &"") if mode_state is Dictionary else mode_state.get("status")
		)
		if status != &"completed":
			return false
	return true


func _read(field: String, fallback: Variant = null) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	return _view_model.get(field) if _view_model != null else fallback
