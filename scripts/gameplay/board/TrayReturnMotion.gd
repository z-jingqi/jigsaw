extends RefCounted
class_name TrayReturnMotion

const REFLOW_DURATION := 0.22
const ROW_TRANSFER_DURATION := 0.28
const RETURN_DURATION := 0.20
const ROW_TRANSFER_THRESHOLD := 24.0
const ROW_TRANSFER_ARC_HEIGHT := 14.0

## The slot can keep scrolling while the piece settles into it.
static func begin(
	host: Node2D,
	group,
	from_position: Vector2,
	from_scale: float,
	returned_from_world := false
) -> void:
	stop(group)
	var target_scale: float = group.node.scale.x
	var slot_origin: Vector2 = group.node.position - group.tray_slot.position
	var displacement: Vector2 = from_position - group.node.position
	var transfers_row := (
		not returned_from_world and absf(displacement.y) > ROW_TRANSFER_THRESHOLD
	)
	var raised_motion := returned_from_world or transfers_row
	if host.reduced_motion:
		if raised_motion:
			host.tray_controller.restore_group_tray_z(group)
		host._refresh_hint_line_widths()
		return
	group.is_animating = true
	if raised_motion:
		host.tray_controller.raise_group_for_drag(group)
	group.node.position = from_position
	group.node.scale = Vector2.ONE * from_scale
	var tween: Tween = host.create_tween()
	group.tray_tween = tween
	var generation: int = group.tray_motion_generation
	if transfers_row:
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(progress: float) -> void:
			if not is_instance_valid(group.node) or not group.in_tray:
				return
			var position: Vector2 = (
				group.tray_slot.position + slot_origin + displacement * (1.0 - progress)
			)
			if transfers_row:
				# The only cross-row piece is the tail donor. A shallow lift makes the
				# lane change legible without turning replenishment into a flourish.
				position.y -= sin(progress * PI) * ROW_TRANSFER_ARC_HEIGHT
			group.node.position = position
			group.node.scale = Vector2.ONE * lerpf(from_scale, target_scale, progress),
		0.0,
		1.0,
		host._motion_duration(
			RETURN_DURATION
			if returned_from_world
			else (ROW_TRANSFER_DURATION if transfers_row else REFLOW_DURATION)
		)
	)
	tween.finished.connect(
		func() -> void:
			if is_instance_valid(group.node) and group.tray_motion_generation == generation:
				group.is_animating = false
				group.tray_tween = null
				if raised_motion:
					host.tray_controller.restore_group_tray_z(group)
				host._refresh_hint_line_widths()
	)


static func stop(group) -> void:
	group.tray_motion_generation += 1
	if group.tray_tween != null and group.tray_tween.is_valid():
		group.tray_tween.kill()
	group.tray_tween = null
	group.is_animating = false
