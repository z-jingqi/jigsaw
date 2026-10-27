extends RefCounted
## Only the sheet moves; the real home remains fixed underneath.


static func configure(
	tween: Tween,
	source: Control,
	target: Control,
	context: Dictionary,
	duration: float,
	reduced_motion: bool,
	opening_from_current := false,
	source_rest := Vector2.ZERO,
	target_rest := Vector2.ZERO
) -> void:
	var closing: bool = context.get("reason") == "pop"
	var sheet := source if closing else target
	var rest := source_rest if closing else target_rest
	var hidden_y := rest.y - maxf(source.size.y, target.size.y)
	sheet.z_index = 50
	var destination := hidden_y if closing else rest.y
	if not closing and not opening_from_current:
		sheet.position.y = hidden_y
	if reduced_motion:
		sheet.position.y = destination
		tween.tween_interval(duration)
	else:
		(
			tween
			. tween_property(sheet, "position:y", destination, duration)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
