extends RefCounted
## Dismiss the complete gameplay page as one surface, revealing the retained list.


static func configure(tween: Tween, source: Control, target: Control, duration: float) -> void:
	source.z_index = 50
	var final := source.position + Vector2(0, maxf(source.size.y, target.size.y) * 1.08)
	tween.tween_property(source, "position", final, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
