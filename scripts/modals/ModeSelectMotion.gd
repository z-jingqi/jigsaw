extends Node
## Owns finite card entrance and cancellable launch feedback.

@export var reveal := 1.0:
	set(value):
		reveal = value
		_redraw()
@export var status_progress := 1.0:
	set(value):
		status_progress = value
		_redraw()
@export var lift := 0.0:
	set(value):
		lift = value
		_redraw()

@onready var player: AnimationPlayer = $AnimationPlayer

var _card: Control
var _launch: Tween
var _completion := Callable()
var _reduced := false
var _origin := Vector2.ZERO
var _icon: Control
var _selection: Tween


func bind_icon(icon: Control) -> void:
	_icon = icon


func cancel_selection() -> void:
	if _selection != null and _selection.is_valid():
		_selection.kill()
	_selection = null
	status_progress = 1.0
	if is_instance_valid(_icon):
		_icon.modulate.a = 1.0
		_icon.scale = Vector2.ONE


func select() -> void:
	cancel_selection()
	if _reduced:
		return
	_icon.modulate.a = 0.45
	_icon.scale = Vector2.ONE * 0.88
	status_progress = 0.0
	_selection = create_tween().set_parallel(true)
	_selection.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_selection.tween_property(_icon, "modulate:a", 1.0, 0.28)
	_selection.tween_property(_icon, "scale", Vector2.ONE, 0.28)
	_selection.tween_property(self, "status_progress", 1.0, 0.4)


func bind(card: Control) -> void:
	_card = card
	_origin = card.position


func set_origin(origin: Vector2) -> void:
	_origin = origin
	_redraw()


func enter(index: int) -> void:
	cancel()
	if not _reduced:
		player.play("enter_%d" % mini(index, 2))
		player.advance(0)


func set_reduced_motion(enabled: bool) -> void:
	_reduced = enabled
	if enabled:
		# Finishing an accepted launch must not silently discard its navigation.
		var completion := _completion
		cancel()
		if completion.is_valid():
			completion.call()


func launch(completion: Callable) -> void:
	cancel()
	if _reduced:
		completion.call()
		return
	_completion = completion
	_launch = create_tween()
	_launch.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_launch.tween_property(_card, "scale", Vector2.ONE * 0.96, 0.06)
	_launch.tween_property(_card, "scale", Vector2.ONE, 0.08)
	_launch.finished.connect(_finish_launch)


func cancel() -> void:
	cancel_selection()
	if is_instance_valid(player):
		player.stop()
	if _launch != null and _launch.is_valid():
		_launch.kill()
	_launch = null
	_completion = Callable()
	reveal = 1.0
	status_progress = 1.0
	lift = 0.0
	if is_instance_valid(_card):
		_card.scale = Vector2.ONE


func active_count() -> int:
	return (
		int(player.is_playing())
		+ int(_launch != null and _launch.is_running())
		+ int(_selection != null and _selection.is_running())
	)


func _finish_launch() -> void:
	var completion := _completion
	_completion = Callable()
	_launch = null
	if completion.is_valid():
		completion.call()


func _redraw() -> void:
	if is_instance_valid(_card):
		_card.modulate.a = reveal
		_card.position = _origin + Vector2(0, lift * _card.size.x / 112.0)
		_card.queue_redraw()


func _exit_tree() -> void:
	cancel()
	_card = null
