extends RefCounted
## Owns the selected carton's forward and reverse travel, without moving pages.
var host: Control
var _return_tween: Tween
var _cancelled := false


func _init(owner: Control) -> void:
	host = owner


func configure(tween: Tween) -> bool:
	if not host._prototype:
		return false
	host._phase = "entering"
	if host.content.size.y <= 0:
		host.content.size = host.size
	host._apply_layout()
	host.background.modulate.a = 0.0
	host.options.modulate.a = 0.0
	host.start_button.modulate.a = 0.0
	var initial: Rect2 = host._source_rect
	if not initial.has_area():
		initial = host._destination
	else:
		initial.position -= host.content.global_position
	host._box.position = initial.position
	host._box.size = initial.size
	if host._reduced_motion:
		host._settle_open_box()
		tween.tween_interval(0.001)
		return true
	# Keep the layout from snapping the box to its destination during resizing.
	var duration := 0.42
	tween.tween_property(host.background, "modulate:a", 1.0, duration)
	tween.tween_property(host._box, "position", host._destination.position, duration)
	tween.tween_property(host._box, "size", host._destination.size, duration)
	tween.chain().tween_callback(host._open_lid)
	tween.chain().tween_interval(0.62)
	tween.chain().tween_callback(host._show_choices)
	tween.chain().tween_property(host.options, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(host.start_button, "modulate:a", 1.0, 0.18)
	return true


func close() -> bool:
	_cancelled = false
	host.gesture_resume_motion()
	_return_tween = host.create_tween().set_parallel(true)
	var fade := 0.001 if host._reduced_motion else 0.16
	_return_tween.tween_property(host.options, "modulate:a", 0.0, fade)
	_return_tween.tween_property(host.start_button, "modulate:a", 0.0, fade)
	await host._box.retract_mode(host._reduced_motion)
	if _cancelled:
		return false
	while _return_tween != null and _return_tween.is_valid():
		await host.get_tree().process_frame
		if _cancelled:
			return false
	host._box.set_open(false, host._reduced_motion)
	while host._box.active_motion_count() > 0:
		await host.get_tree().process_frame
		if _cancelled:
			return false
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.kill()
	var target: Rect2 = host._source_rect
	if target.has_area():
		target.position -= host.content.global_position
	else:
		target = host._destination
	var full_distance: float = (
		host._destination.position.distance_to(target.position)
		+ host._destination.size.distance_to(target.size)
	)
	var remaining: float = (
		host._box.position.distance_to(target.position) + host._box.size.distance_to(target.size)
	)
	var duration := (
		0.001
		if host._reduced_motion
		else 0.42 * clampf(remaining / maxf(full_distance, 0.001), 0.05, 1.0)
	)
	_return_tween = host.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	_return_tween.tween_property(host._box, "position", target.position, duration)
	_return_tween.tween_property(host._box, "size", target.size, duration)
	_return_tween.tween_property(host.background, "modulate:a", 0.0, duration)
	_return_tween.tween_property(
		host.get_node("SafeArea/Content/Header"), "modulate:a", 0.0, duration
	)
	while _return_tween != null and _return_tween.is_valid():
		await host.get_tree().process_frame
		if _cancelled:
			return false
	_return_tween = null
	return true


func pause() -> void:
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.pause()


func resume() -> void:
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.play()


func cancel() -> void:
	_cancelled = true
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.kill()
	_return_tween = null


func active_count() -> int:
	return int(_return_tween != null and _return_tween.is_valid())
