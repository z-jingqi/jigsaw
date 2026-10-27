extends "res://scripts/screens/album/AlbumImageCache.gd"
## Card lifetimes never own engine load jobs. Reuse the bounded image service.
const SINGLETON_NAME := "LevelThumbnailLoader"


static func shared(tree: SceneTree) -> Node:
	var found := tree.root.get_node_or_null(SINGLETON_NAME)
	if found != null:
		return found
	var service := new()
	service.name = SINGLETON_NAME
	tree.root.add_child(service)
	return service
