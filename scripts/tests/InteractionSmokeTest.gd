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
		var board = PuzzleBoardScript.new()
		root.add_child(board)
		board.set_feedback_preferences(false, true)
		var loaded: bool = board.start(
			level_config,
			play_mode,
			media["texture"],
			media["image"],
			media["source_size"],
			64.0,
			false,
		)
		await process_frame
		var result := {"mode": play_mode, "loaded": loaded, "ok": false}
		if loaded:
			result = await board.debug_run_interaction_smoke()
			result["loaded"] = true
		all_ok = all_ok and bool(result.get("ok", false))
		print("INTERACTION_SMOKE %s" % JSON.stringify(result))
		board.queue_free()
		await process_frame
		await process_frame
	quit(0 if all_ok else 1)
