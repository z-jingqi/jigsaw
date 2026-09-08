extends RefCounted
## Viewport-dependent page-card motion. Transaction host restores every property.


static func configure(
	tween: Tween, source: Control, target: Control, context: Dictionary, duration: float
) -> void:
	var returning := str(context.get("reason", "")) == "pop"
	var distance := maxf(source.size.y, target.size.y) * 1.12
	var lift := minf(source.size.y * 0.012, 32.0)
	var front := target if returning else source
	front.z_index = 50
	front.pivot_offset = front.size * Vector2(0.5, 0.8)
	if returning:
		var final := target.position
		target.position += Vector2(0, distance)
		target.rotation = 0.015
		(
			tween
			. tween_property(target, "position", final, duration)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
		tween.tween_property(target, "rotation", 0.0, duration)
		_companion(tween, context.get("target_companion"), distance, duration, true, lift)
	else:
		var start := source.position
		var lead := 0.09
		(
			tween
			. tween_property(source, "position:y", start.y - lift, lead)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)
		(
			tween
			. tween_property(source, "position:y", start.y + distance, duration - lead)
			. from(start.y - lift)
			. set_delay(lead)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)
		tween.tween_property(source, "rotation", 0.015, duration - lead).set_delay(lead)
		target.pivot_offset = target.size * 0.5
		target.scale = Vector2.ONE * 0.975
		tween.tween_property(target, "scale", Vector2.ONE, duration)
		_companion(tween, context.get("source_companion"), distance, duration, false, lift)


static func _companion(
	tween: Tween, companion: Variant, distance: float, duration: float, entering: bool, lift: float
) -> void:
	if not is_instance_valid(companion):
		return
	var end: Vector2 = companion.position
	if entering:
		companion.position.y += distance
		(
			tween
			. tween_property(companion, "position", end, duration)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
	else:
		tween.tween_property(companion, "position:y", end.y - lift, 0.09)
		(
			tween
			. tween_property(companion, "position:y", end.y + distance, duration - 0.09)
			. from(end.y - lift)
			. set_delay(0.09)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)
