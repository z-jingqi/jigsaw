extends SceneTree

const LevelGeneratorScript := preload("res://scripts/LevelGenerator.gd")
const DEFAULT_IMAGE_PATH := "res://assets/source/cat_moon.png"
const DEFAULT_CONFIG_PATH := "res://levels/cat_moon_01.json"
const DEFAULT_REPORT_PATH := "res://levels/cat_moon_01_components.html"
const COLS := 3
const ROWS := 3
const PIECE_SIZE := 190.0


func _init() -> void:
	var options := _parse_args()
	var image_path: String = options.get("image", DEFAULT_IMAGE_PATH)
	var config_path: String = options.get("config", DEFAULT_CONFIG_PATH)
	var report_path: String = options.get("report", DEFAULT_REPORT_PATH)
	var mode: String = options.get("mode", "irregular")
	var texture: Texture2D = load(image_path)
	if texture == null:
		push_error("Unable to load image: %s" % image_path)
		quit(1)
		return
	var config := _load_config(config_path)
	config["schema"] = config.get("schema", "jigsaw.level.v1")
	config["version"] = 1
	if not config.has("id"):
		config["id"] = "cat_moon_01"
	if not config.has("title"):
		config["title"] = "月亮小睡"
	if not config.has("description"):
		config["description"] = "小猫安静地靠在月亮上，像一段柔软的午后梦。"
	config["image"] = {
		"path": image_path,
		"name": image_path.get_file(),
		"width": texture.get_width(),
		"height": texture.get_height(),
	}
	if not config.has("background"):
		config["background"] = { "type": "color", "color": "#ead8bd", "path": "" }
	if not config.has("grid"):
		config["grid"] = { "cols": COLS, "rows": ROWS }
	config["tool_notes"] = "Edit component_overrides values per component key: drop, keep, or merge_nearest. Re-run this tool after changing the source image or generator."
	if not config.has("component_overrides") or typeof(config["component_overrides"]) != TYPE_DICTIONARY:
		config["component_overrides"] = {}
	var components := LevelGeneratorScript.inspect_components(texture.get_size(), COLS, ROWS, PIECE_SIZE, mode, texture.get_image(), config)
	config["components"] = components
	_save_json(config_path, config)
	_save_report(report_path, image_path, components)
	print("Wrote %s" % ProjectSettings.globalize_path(config_path))
	print("Wrote %s" % ProjectSettings.globalize_path(report_path))
	quit()


func _parse_args() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	var options := {}
	var i := 0
	while i < args.size():
		var key: String = args[i]
		if key.begins_with("--") and i + 1 < args.size():
			options[key.substr(2)] = args[i + 1]
			i += 2
		else:
			i += 1
	return options


func _load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _save_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write config: %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))


func _save_report(path: String, image_path: String, components: Array[Dictionary]) -> void:
	var image_href := _html_escape(ProjectSettings.globalize_path(image_path))
	var html := PackedStringArray([
		"<!doctype html>",
		"<meta charset=\"utf-8\">",
		"<title>Jigsaw Level Components</title>",
		"<style>",
		"body{font-family:system-ui,sans-serif;margin:24px;background:#f7f3ea;color:#2a2018}",
		"table{border-collapse:collapse;margin-top:16px;background:white}",
		"th,td{border:1px solid #d8c8b8;padding:6px 10px;text-align:left}",
		"code{background:#eee2d2;padding:2px 4px;border-radius:3px}",
		".drop{color:#a33}.keep{color:#276b35}.merge_nearest{color:#8a5a00}",
		"</style>",
		"<h1>Jigsaw Level Components</h1>",
		"<p>Edit <code>component_overrides</code> in <code>levels/cat_moon_01.json</code>. Allowed values: <code>drop</code>, <code>keep</code>, <code>merge_nearest</code>.</p>",
		"<p>Source image: <code>%s</code></p>" % image_href,
		"<table>",
		"<thead><tr><th>Key</th><th>Cell</th><th>Rect x,y,w,h</th><th>Samples</th><th>Default</th><th>Current</th></tr></thead>",
		"<tbody>",
	])
	for component in components:
		var current := str(component["action"])
		html.append("<tr>")
		html.append("<td><code>%s</code></td>" % _html_escape(component["key"]))
		html.append("<td>%s</td>" % _html_escape(str(component["cell"])))
		html.append("<td>%s</td>" % _html_escape(str(component["rect"])))
		html.append("<td>%s</td>" % _html_escape(str(component["samples"])))
		html.append("<td class=\"%s\">%s</td>" % [_html_escape(str(component["default_action"])), _html_escape(str(component["default_action"]))])
		html.append("<td class=\"%s\">%s</td>" % [_html_escape(current), _html_escape(current)])
		html.append("</tr>")
	html.append_array(PackedStringArray(["</tbody>", "</table>"]))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write report: %s" % path)
		return
	file.store_string("\n".join(html))


func _html_escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
