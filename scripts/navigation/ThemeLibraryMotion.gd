extends RefCounted
## Keeps the home screen fixed while the theme library covers or reveals it.


static func configure(
	tween: Tween,
	source: Control,
	target: Control,
	context: Dictionary,
	duration: float,
	reduced_motion: bool
) -> void:
	var closing := str(context.get("reason", "")) == "pop"
	if closing:
		_configure_close(tween, source, target, duration, reduced_motion)
	else:
		_configure_open(tween, source, target, duration, reduced_motion)


static func _configure_open(
	tween: Tween, source: Control, target: Control, duration: float, reduced_motion: bool
) -> void:
	target.z_index = 50
	if reduced_motion:
		tween.tween_interval(duration)
		return
	var final_y := target.position.y
	var distance := maxf(source.size.y, target.size.y)
	target.position.y = final_y - distance
	(
		tween
		. tween_property(target, "position:y", final_y, duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


static func _configure_close(
	tween: Tween, source: Control, target: Control, duration: float, reduced_motion: bool
) -> void:
	source.z_index = 50
	if reduced_motion:
		source.position.y += maxf(source.size.y, target.size.y)
		tween.tween_interval(duration)
		return
	var final_y := source.position.y + maxf(source.size.y, target.size.y)
	(
		tween
		. tween_property(source, "position:y", final_y, duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
