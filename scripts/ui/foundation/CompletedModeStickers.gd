class_name CompletedModeStickers
extends HBoxContainer
## Projects completed play modes as a compact, card-only sticker row.

const TEXTURES := {
	&"polygon": preload("res://assets/ui/levels/mode-stickers/mode_polygon_sticker.webp"),
	&"knob": preload("res://assets/ui/levels/mode-stickers/mode_knob_sticker.webp"),
	&"swap": preload("res://assets/ui/levels/mode-stickers/mode_swap_sticker.webp"),
}
const MODE_ORDER := [&"polygon", &"knob", &"swap"]

var _icon_size := 48.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 8)


func configure(icon_size: float, separation: float) -> void:
	_icon_size = icon_size
	add_theme_constant_override("separation", int(round(separation)))
	for child in get_children():
		_apply_icon_size(child as TextureRect)


func set_modes(states: Array, enabled := true) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not enabled:
		visible = false
		return
	var completed: Dictionary = {}
	for state in states:
		if StringName(_read(state, "status", &"")) != &"completed":
			continue
		completed[StringName(_read(state, "mode", &""))] = true
	for mode in MODE_ORDER:
		if not completed.has(mode):
			continue
		var sticker := TextureRect.new()
		sticker.name = "%sSticker" % String(mode).capitalize()
		sticker.texture = TEXTURES.get(mode)
		sticker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sticker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sticker.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_icon_size(sticker)
		add_child(sticker)
	visible = get_child_count() > 0


func completed_count() -> int:
	return get_child_count()


func _apply_icon_size(sticker: TextureRect) -> void:
	if sticker == null:
		return
	sticker.custom_minimum_size = Vector2.ONE * _icon_size
	sticker.size = sticker.custom_minimum_size


func _read(source: Variant, field: String, fallback: Variant) -> Variant:
	if source is Dictionary:
		return source.get(field, fallback)
	return source.get(field) if source != null else fallback
