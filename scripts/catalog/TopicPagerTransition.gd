extends RefCounted
class_name TopicPagerTransition

var game: Node
var tween: Tween


func _init(owner: Node) -> void:
	game = owner


func slide(from_x: float, target_x: float, duration: float, setter: Callable, finished: Callable) -> void:
	cancel()
	tween = game.create_tween()
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(setter, from_x, target_x, duration)
	tween.finished.connect(func() -> void:
		tween = null
		finished.call()
	)


func fade_out(page: Control, direction: int, page_width: float, finished: Callable) -> void:
	cancel()
	var start_position := page.position
	tween = game.create_tween().set_parallel(true)
	tween.tween_property(page, "modulate:a", 0.0, 0.17).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(page, "position:x", start_position.x - float(direction) * page_width * 0.08, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		tween = null
		finished.call()
	)


func fade_in(page: Control, direction: int, page_width: float, finished: Callable) -> void:
	cancel()
	var final_position := page.position
	page.position.x += float(direction) * page_width * 0.08
	page.modulate.a = 0.0
	tween = game.create_tween().set_parallel(true)
	tween.tween_property(page, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(page, "position:x", final_position.x, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		tween = null
		finished.call()
	)


func cancel() -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	tween = null


func shutdown() -> void:
	cancel()
	game = null
