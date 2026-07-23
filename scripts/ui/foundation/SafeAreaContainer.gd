class_name SafeAreaContainer
extends MarginContainer

@export var compact_horizontal_margin := 20.0
@export var regular_horizontal_margin := 32.0
@export var compact_breakpoint := 600.0
@export var regular_content_max_width := 704.0

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func _apply_safe_area() -> void:
	var viewport_size := get_viewport_rect().size
	var safe_rect := get_viewport().get_visible_rect()
	var safe_width := maxf(0.0, safe_rect.size.x)
	var side_margin := compact_horizontal_margin
	if safe_width >= compact_breakpoint:
		side_margin = maxf(regular_horizontal_margin, (safe_width - regular_content_max_width) * 0.5)
	add_theme_constant_override("margin_left", int(side_margin + safe_rect.position.x))
	add_theme_constant_override("margin_right", int(side_margin + maxi(0.0, viewport_size.x - safe_rect.end.x)))
	add_theme_constant_override("margin_top", int(safe_rect.position.y))
	add_theme_constant_override("margin_bottom", int(maxi(0.0, viewport_size.y - safe_rect.end.y)))
