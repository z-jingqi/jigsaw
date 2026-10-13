extends RefCounted
class_name PieceGroup

var node: Node2D
var anchor_home := Vector2.ZERO
var members: Array[Dictionary] = []
var is_animating := false
var locked := false
var is_seed := false
var in_tray := false
var tray_index := -1
var tray_slot := Rect2()
var tray_tween: Tween


func _init(group_node: Node2D, piece: Dictionary) -> void:
	node = group_node
	anchor_home = piece["home"]
	members = [
		{
			"id": piece["id"],
			"cell": piece["cell"],
			"home": piece["home"],
			"polygon": piece["polygon"],
			"bounds_points": piece["bounds_points"],
			"bounds_points_list": piece["bounds_points_list"],
			"visual": piece["visual"],
			"neighbors": piece["neighbors"],
		}
	]


func absorb(other: PieceGroup, visual_gap := 0.0) -> void:
	# Keep the larger visual tree in place while preserving the active group's identity.
	# Moving an assembled board's nodes during the last drop can stall the render frame.
	if other.members.size() > members.size() and is_zero_approx(visual_gap):
		var previous_node := node
		var previous_home := anchor_home
		var previous_members := members
		node = other.node
		anchor_home = other.anchor_home
		members = other.members
		other.node = previous_node
		other.anchor_home = previous_home
		other.members = previous_members
	for member in other.members:
		other.node.remove_child(member["visual"])
		node.add_child(member["visual"])
		var offset: Vector2 = member["home"] - anchor_home
		if visual_gap > 0.0 and offset.length() > 0.001:
			offset += offset.normalized() * visual_gap
		member["visual"].position = offset
		members.append(member)
	other.node.queue_free()
