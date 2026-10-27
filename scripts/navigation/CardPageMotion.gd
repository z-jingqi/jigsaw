extends RefCounted
## Shared horizontal route motion; the previous page stays underneath on Back.


static func configure(
	tween: Tween, source: Control, target: Control, context: Dictionary, duration: float
) -> void:
	var returning := str(context.get("reason", "")) in ["pop", "close_modal"]
	var distance := maxf(source.size.x, target.size.x)
	var front := source if returning else target
	front.z_index = 50
	if returning:
		tween.tween_property(source, "position:x", source.position.x + distance, duration)
	else:
		var destination := target.position.x
		target.position.x += distance
		tween.tween_property(target, "position:x", destination, duration)
		# The outgoing modal lives on a higher canvas than the incoming game.
		if context.get("reason") == "push_from_modal":
			tween.tween_property(source, "position:x", source.position.x - distance, duration)
