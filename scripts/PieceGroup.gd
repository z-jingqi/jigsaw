extends RefCounted
class_name PieceGroup

var node: Node2D
var anchor_home := Vector2.ZERO
var members: Array[Dictionary] = []
var is_animating := false


func _init(group_node: Node2D, piece: Dictionary) -> void:
	node = group_node
	anchor_home = piece["home"]
	members = [{
		"id": piece["id"],
		"cell": piece["cell"],
		"home": piece["home"],
		"polygon": piece["polygon"],
		"bounds_points": piece["bounds_points"],
		"bounds_points_list": piece["bounds_points_list"],
		"visual": piece["visual"],
		"neighbors": piece["neighbors"],
	}]


func contains_piece(piece_id: String) -> bool:
	for member in members:
		if member["id"] == piece_id:
			return true
	return false


func absorb(other: PieceGroup) -> void:
	for member in other.members:
		other.node.remove_child(member["visual"])
		node.add_child(member["visual"])
		member["visual"].position = member["home"] - anchor_home
		members.append(member)
	other.node.queue_free()
