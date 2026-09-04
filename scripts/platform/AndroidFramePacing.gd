extends Node

## Keep the GLES producer from filling Android's presentation queue.
## Leave Vulkan/Swappy, desktop, and explicit user FPS limits unchanged.
const REFRESH_HEADROOM := 1

var _previous_limit := -1
var _applied_limit := 0


func _ready() -> void:
	_configure()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		_configure.call_deferred()


func _exit_tree() -> void:
	if _previous_limit >= 0 and Engine.max_fps == _applied_limit:
		Engine.max_fps = _previous_limit


func _configure() -> void:
	if not OS.has_feature("android"):
		return
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return
	if _previous_limit < 0:
		_previous_limit = Engine.max_fps
	# Project settings / command-line caps take precedence over this default.
	if _previous_limit > 0 or Engine.max_fps not in [0, _applied_limit]:
		return
	var refresh := DisplayServer.screen_get_refresh_rate(get_window().current_screen)
	if refresh <= 0.0:
		return
	var limit := maxi(1, roundi(refresh) - REFRESH_HEADROOM)
	if Engine.max_fps == limit:
		return
	Engine.max_fps = limit
	_applied_limit = limit
	if OS.is_debug_build():
		print("JIGCAT_FRAME_PACING ", JSON.stringify({"refresh_hz": refresh, "max_fps": limit}))
