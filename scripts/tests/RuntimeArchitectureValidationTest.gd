extends SceneTree

const GameScene := preload("res://scenes/app/Game.tscn")
const ThemeProgressScene := preload("res://scenes/ui/foundation/ThemeProgress.tscn")
const ThemeProgressPolicyScript := preload(
	"res://scripts/runtime/presentation/ThemeProgressPolicy.gd"
)

var _all_ok := true
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_progress_policy()
	var game := GameScene.instantiate() as Game
	root.add_child(game)
	await create_timer(0.45).timeout
	await _validate_debug_contract(game)
	await _validate_runtime_routes(game)
	game.queue_free()
	await process_frame
	var result := {"ok": _all_ok, "failures": _failures}
	print("RUNTIME_ARCHITECTURE_VALIDATION %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _validate_progress_policy() -> void:
	for sample in [
		[0, 100, 0],
		[1, 100, 1],
		[20, 100, 1],
		[21, 100, 2],
		[40, 100, 2],
		[41, 100, 3],
		[60, 100, 3],
		[61, 100, 4],
		[80, 100, 4],
		[81, 100, 5],
		[99, 100, 5],
		[100, 100, 5],
		[0, 0, 0]
	]:
		var model := ThemeProgressPolicyScript.build(int(sample[0]), int(sample[1]))
		_check(
			int(model.paw_count) == int(sample[2]),
			"progress_paws_%d_of_%d" % [sample[0], sample[1]]
		)
		_check(
			bool(model.is_complete) == (int(sample[1]) > 0 and int(sample[0]) == int(sample[1])),
			"progress_completion_%d_of_%d" % [sample[0], sample[1]]
		)
	var journey := ThemeProgressScene.instantiate() as ThemeProgress
	var numeric := ThemeProgressScene.instantiate() as ThemeProgress
	root.add_child(journey)
	root.add_child(numeric)
	numeric.display_variant = ThemeProgress.Variant.NUMERIC_CARD
	journey.reduced_motion = true
	numeric.reduced_motion = true
	journey.set_progress_data(ThemeProgressPolicyScript.build(100, 100))
	numeric.set_progress_data(ThemeProgressPolicyScript.build(100, 100))
	_check(
		(
			journey.get_node("Journey/Completion").visible
			and not journey.get_node("Journey/Fish").visible
		),
		"journey_complete_cat_eats_fish"
	)
	_check(
		(
			numeric.get_node("Numeric").text == "100 / 100"
			and numeric.get_node("NumericCompletion").visible
			and not numeric.get_node("Journey").visible
		),
		"numeric_complete_has_number_and_mark_only"
	)
	journey.set_progress_data(ThemeProgressPolicyScript.build(0, 0))
	numeric.set_progress_data(ThemeProgressPolicyScript.build(0, 0))
	_check(
		(
			not journey.get_node("Journey/Completion").visible
			and not numeric.get_node("NumericCompletion").visible
		),
		"zero_total_never_complete"
	)
	journey.queue_free()
	numeric.queue_free()


func _validate_debug_contract(game: Game) -> void:
	var state := game.debug_execute("state")
	_check(bool(state.get("ok", false)) and str(state.state.screen) == "home", "debug_state_home")
	for field in [
		"completed_levels",
		"total_levels",
		"progress_ratio",
		"progress_paw_count",
		"theme_complete",
		"active_motion_count",
		"motion_phase",
		"transition_kind",
		"gesture_progress",
		"reduced_motion"
	]:
		_check(state.state.has(field), "debug_state_%s" % field)
	var unknown := game.debug_execute("missing_command")
	_check(
		not bool(unknown.get("ok", true)) and str(unknown.error.code) == "unknown_command",
		"debug_unknown_command"
	)
	var invalid := game.debug_execute("show_levels", {})
	_check(
		not bool(invalid.get("ok", true)) and str(invalid.error.code) == "invalid_argument",
		"debug_invalid_argument"
	)
	var viewport := game.debug_execute("set_viewport", {"width": 603, "height": 1311})
	await process_frame
	_check(
		bool(viewport.get("ok", false)) and game.debug_state_snapshot().viewport == [603, 1311],
		"debug_phone_viewport"
	)


func _validate_runtime_routes(game: Game) -> void:
	var levels := game.debug_execute("show_levels", {"topic_id": "topic_01"})
	_check(bool(levels.get("ok", false)), "debug_show_levels")
	await create_timer(0.40).timeout
	var mode_select := game.debug_execute(
		"show_mode_select", {"topic_id": "topic_01", "level_id": "shanhai_01"}
	)
	_check(
		bool(mode_select.get("ok", false)) and str(mode_select.state.modal) == "mode_select",
		"debug_show_mode_select"
	)
	game.debug_execute("close_modal")
	await create_timer(0.40).timeout
	var gameplay := game.debug_execute(
		"enter_level", {"topic_id": "topic_01", "level_id": "shanhai_01", "mode": "swap"}
	)
	_check(bool(gameplay.get("ok", false)), "debug_enter_level")
	await create_timer(0.55).timeout
	var game_state := game.debug_state_snapshot()
	_check(
		str(game_state.screen) == "gameplay" and str(game_state.mode) == "swap",
		"gameplay_route_and_mode"
	)
	if not str(game_state.modal).is_empty():
		game.debug_execute("close_modal")
		await create_timer(0.40).timeout
	var reduced := game.debug_execute("set_reduced_motion", {"enabled": true})
	_check(
		bool(reduced.get("ok", false)) and bool(reduced.state.reduced_motion),
		"debug_reduced_motion"
	)
	var tablet := game.debug_execute("set_viewport", {"width": 768, "height": 1024})
	_check(
		bool(tablet.get("ok", false)) and tablet.state.viewport == [768, 1024],
		"debug_tablet_viewport"
	)
	var completion := game.debug_execute("preview_complete")
	_check(bool(completion.get("ok", false)), "debug_preview_completion")
	await create_timer(0.20).timeout
	_check(str(game.debug_state_snapshot().modal) == "completion", "completion_route")


func _check(condition: bool, name: String) -> void:
	if condition:
		print("RUNTIME_ARCHITECTURE_VALIDATION_PASS %s" % name)
		return
	_all_ok = false
	_failures.append(name)
	push_error("RUNTIME_ARCHITECTURE_VALIDATION_FAIL %s" % name)
