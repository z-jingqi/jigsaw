extends SceneTree

const BoardScene := preload("res://scenes/gameplay/PuzzleBoard.tscn")

var _all_ok := true
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var board := BoardScene.instantiate() as PuzzleBoard
	root.add_child(board)
	await process_frame
	_check(board.get_node_or_null("WorldRoot") != null, "world_host_declared")
	_check(board.get_node_or_null("TrayRoot") != null, "tray_host_declared")
	_check(board.get_node_or_null("VisualHost") != null and board.get_node_or_null("InputHost") != null, "static_visual_input_hosts_declared")
	var world := board.get_node("WorldRoot") as Node2D
	var tray := board.get_node("TrayRoot") as Node2D
	world.add_child(Node2D.new())
	tray.add_child(Node2D.new())
	board.clear()
	await process_frame
	_check(board.get_node_or_null("WorldRoot") == world and board.get_node_or_null("TrayRoot") == tray, "clear_preserves_static_hosts")
	_check(world.get_child_count() == 0 and tray.get_child_count() == 0, "clear_releases_dynamic_host_children")
	board.queue_free()
	await process_frame
	var result := {"ok": _all_ok, "failures": _failures}
	print("PUZZLE_BOARD_SCENE %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("PUZZLE_BOARD_SCENE_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("PUZZLE_BOARD_SCENE_FAIL %s" % name)
