extends "res://scripts/screens/album/AlbumFocusPager.gd"


## Reuses seven thumbnail nodes independently of the number of unlocked artworks.
func _init() -> void:
	thumbnail_mode = true
