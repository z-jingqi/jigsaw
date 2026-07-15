extends SceneTree

const LevelRepositoryScript := preload("res://scripts/catalog/LevelRepository.gd")
const PuzzleBoardScript := preload("res://scripts/gameplay/board/PuzzleBoard.gd")
const LEVEL_PATH := "res://levels/topic_01/level_01/level.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1206, 2622)
	var repository = LevelRepositoryScript.new()
	var level_config := repository.load_config_path(LEVEL_PATH)
	var media := repository.apply_level_media(level_config)
	var all_ok := true
	for play_mode in ["polygon", "knob", "swap"]:
		var source_board = PuzzleBoardScript.new()
		root.add_child(source_board)
		source_board.set_feedback_preferences(false, true)
		var source_loaded: bool = source_board.start(level_config, play_mode, media["texture"], media["image"], media["source_size"], 64.0)
		await process_frame
		var expected: Dictionary = source_board.debug_prepare_restore_snapshot() if source_loaded else {}
		var persisted_snapshot = JSON.parse_string(JSON.stringify(expected))
		if typeof(persisted_snapshot) == TYPE_DICTIONARY:
			expected = persisted_snapshot
		source_board.queue_free()
		await process_frame
		await process_frame

		var restored_board = PuzzleBoardScript.new()
		root.add_child(restored_board)
		restored_board.set_feedback_preferences(false, true)
		var restored_loaded: bool = restored_board.start(level_config, play_mode, media["texture"], media["image"], media["source_size"], 64.0, false, expected)
		await process_frame
		var result := {"mode": play_mode, "ok": false, "reason": "load_failed"}
		if source_loaded and restored_loaded:
			result = restored_board.debug_validate_restored_snapshot(expected)
		all_ok = all_ok and bool(result.get("ok", false))
		print("STATE_ROUND_TRIP %s" % JSON.stringify(result))
		restored_board.queue_free()
		await process_frame
		await process_frame
	quit(0 if all_ok else 1)
