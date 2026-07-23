class_name SwapActionBarView
extends Panel

signal move_up_requested()
signal move_down_requested()

@onready var move_up: Button = $Actions/MoveUp
@onready var move_down: Button = $Actions/MoveDown


func _ready() -> void:
	move_up.pressed.connect(move_up_requested.emit)
	move_down.pressed.connect(move_down_requested.emit)


func set_actions_enabled(enabled: bool) -> void:
	move_up.disabled = not enabled
	move_down.disabled = not enabled
