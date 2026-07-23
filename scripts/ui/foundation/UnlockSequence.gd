class_name UnlockSequence
extends Panel

signal finished()

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _did_finish := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation_player.play(&"RESET")
	animation_player.advance(0.0)
	animation_player.animation_finished.connect(_on_animation_finished)


func play(reduced_motion: bool) -> void:
	if reduced_motion:
		animation_player.play(&"play")
		animation_player.seek(animation_player.get_animation(&"play").length, true)
		_finish()
		return
	animation_player.play(&"play")


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"play":
		_finish()


func _finish() -> void:
	if _did_finish:
		return
	_did_finish = true
	finished.emit()
