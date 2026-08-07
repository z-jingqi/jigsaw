class_name TestMotionSettle
extends RefCounted

## Polling helpers for motion assertions in the validation scripts.
##
## Sleeping a fixed interval and then asserting that motion has been released
## races the animation: the waits sat only 20-60ms above the durations in
## `motion_tokens.tres`, so a slow frame made the assertion fail even though the
## behaviour was correct. Callers keep their fixed wait so the animation still
## has to run, then poll for the end state instead of assuming it has arrived.

const DEFAULT_TIMEOUT := 1.5


## Poll until `probe` reports zero active motion. Returns false if it never does.
static func released(tree: SceneTree, probe: Callable, timeout := DEFAULT_TIMEOUT) -> bool:
	return await until(tree, func() -> bool: return int(probe.call()) == 0, timeout)


## Poll until `predicate` holds. Returns its final value so callers can assert it.
static func until(tree: SceneTree, predicate: Callable, timeout := DEFAULT_TIMEOUT) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await tree.process_frame
	return bool(predicate.call())
