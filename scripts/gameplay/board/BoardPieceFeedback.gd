extends RefCounted
class_name BoardPieceFeedback

const MobileHapticsScript := preload("res://scripts/platform/MobileHaptics.gd")
const SNAP_SETTLE_DURATION := 0.16
const SNAP_SETTLE_SCALE := 0.96

var host: Node2D
var _haptics := MobileHapticsScript.new()
var _snap_tween: Tween
var _snap_targets: Array[Dictionary] = []
var _generation := 0


func _init(owner: Node2D) -> void:
	host = owner


func trigger_haptic(kind: String) -> void:
	if not is_instance_valid(host) or not host.haptics_enabled:
		return
	_haptics.play(kind)


func confirm_placement(members: Array, release_displacement := Vector2.ZERO) -> void:
	trigger_haptic("snap")
	if host.reduced_motion:
		return
	_finish_snap_motion()
	_generation += 1
	var ticket := _generation
	_snap_tween = host.create_tween()
	_snap_tween.set_parallel(true)
	var animated := false
	for member in members:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var visual: Node2D = member.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			continue
		var target_position := visual.position
		var target_scale := visual.scale
		_snap_targets.append({"visual": visual, "position": target_position, "scale": target_scale})
		visual.position = target_position + release_displacement
		visual.scale = target_scale * SNAP_SETTLE_SCALE
		(
			_snap_tween
			. tween_property(visual, "position", target_position, SNAP_SETTLE_DURATION)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
		(
			_snap_tween
			. tween_property(visual, "scale", target_scale, SNAP_SETTLE_DURATION)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		animated = true
	if not animated:
		host._play_snap_shimmer(members)
		return
	_snap_tween.finished.connect(
		func() -> void:
			if ticket == _generation and is_instance_valid(host):
				_snap_targets.clear()
				host._play_snap_shimmer(members)
	)


func cancel_all() -> void:
	_generation += 1
	_finish_snap_motion()
	_haptics.cancel_pending()


func _finish_snap_motion() -> void:
	if _snap_tween != null and _snap_tween.is_valid():
		_snap_tween.kill()
	_snap_tween = null
	for target in _snap_targets:
		var visual = target.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			continue
		visual.position = target["position"]
		visual.scale = target["scale"]
	_snap_targets.clear()
