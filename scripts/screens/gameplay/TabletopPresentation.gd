class_name TabletopPresentation
extends ColorRect
## A single paper canvas keeps navigation and modal transitions visually quiet.

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")

@export var navigator_path: NodePath


func _ready() -> void:
	color = Clean.PAPER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
