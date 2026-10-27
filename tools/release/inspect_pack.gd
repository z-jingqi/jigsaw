extends SceneTree


func _init():
	var result = {
		"autoload_absent": not ProjectSettings.has_setting("autoload/_mcp_game_helper"),
		"ai_plugin_absent": not FileAccess.file_exists("res://addons/godot_ai/plugin.gd"),
		"debug_adapter_absent":
		not ResourceLoader.exists("res://scripts/debug/DebugCommandRouter.gd"),
		"main_present": ResourceLoader.exists("res://scenes/app/Game.tscn"),
		"main_parses": load("res://scenes/app/Game.tscn") is PackedScene,
		"catalog_present": FileAccess.file_exists("res://levels/catalog.json"),
		"level_present": FileAccess.file_exists("res://levels/topic_01/shanhai_v2_01/level.json")
	}
	print(JSON.stringify(result))
	quit(0 if result.values().all(func(v): return v) else 1)
