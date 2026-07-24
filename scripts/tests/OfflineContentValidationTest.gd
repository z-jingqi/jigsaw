extends SceneTree

const FONT_ROOT := "res://assets/fonts/noto"
const ContentRepositoryScript := preload("res://scripts/runtime/data/ContentRepository.gd")
const FONT_DIGESTS := {
	"NotoSansSC[wght].ttf": "a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da",
	"NotoSerifSC[wght].ttf": "32f10fdf815f8d3f45bf69340d804c53bfcc79c5a256b5dfea5f19c7cd48c17e",
	"OFL.txt": "babcfe66c8a098b2fa279bc724a3a342f8124f77ce18941fbcc1bbb39823cded",
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_level_resources()
	_validate_content_repository()
	_validate_fonts()
	var result := {"failures": _failures, "ok": _failures.is_empty()}
	print("OFFLINE_CONTENT_VALIDATION ", JSON.stringify(result))
	quit(0 if _failures.is_empty() else 1)


func _validate_level_resources() -> void:
	var json_paths: Array[String] = []
	_collect_json_paths("res://levels", json_paths)
	if json_paths.is_empty():
		_fail("levels catalog is empty")
		return
	for path in json_paths:
		var text := FileAccess.get_file_as_string(path)
		var json := JSON.new()
		if json.parse(text) != OK:
			_fail("invalid JSON: %s" % path)
			continue
		_validate_json_value(json.data, path)


func _collect_json_paths(directory_path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_fail("missing content directory: %s" % directory_path)
		return
	for file_name in directory.get_files():
		if file_name.ends_with(".json"):
			paths.append(directory_path.path_join(file_name))
	for child_name in directory.get_directories():
		_collect_json_paths(directory_path.path_join(child_name), paths)


func _validate_json_value(value, source_path: String) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for item in value.values():
			_validate_json_value(item, source_path)
	elif typeof(value) == TYPE_ARRAY:
		for item in value:
			_validate_json_value(item, source_path)
	elif typeof(value) == TYPE_STRING:
		var text := str(value)
		if text.begins_with("http://") or text.begins_with("https://"):
			_fail("remote content URL in %s: %s" % [source_path, text])
		elif text.begins_with("res://") and not FileAccess.file_exists(text):
			_fail("missing resource in %s: %s" % [source_path, text])


func _validate_fonts() -> void:
	for file_name in FONT_DIGESTS:
		var path := FONT_ROOT.path_join(file_name)
		if not FileAccess.file_exists(path):
			_fail("missing font resource: %s" % path)
			continue
		var digest := _sha256(path)
		if digest != FONT_DIGESTS[file_name]:
			_fail("font digest mismatch: %s" % file_name)
	var sources_path := FONT_ROOT.path_join("SOURCES.md")
	var sources := FileAccess.get_file_as_string(sources_path)
	for digest in FONT_DIGESTS.values():
		if not sources.contains(digest):
			_fail("SOURCES.md missing digest: %s" % digest)
	if not sources.contains("SIL Open Font License 1.1"):
		_fail("SOURCES.md missing OFL declaration")


func _validate_content_repository() -> void:
	var repository = ContentRepositoryScript.new()
	var topics := repository.topics()
	if topics.is_empty():
		_fail("ContentRepository returned no themes")
		return
	for topic in topics:
		if repository.topic_cover(topic) == null:
			_fail("ContentRepository could not load theme cover: %s" % topic.get("id", ""))
		for level in topic.get("levels", []):
			if typeof(level) != TYPE_DICTIONARY:
				_fail("ContentRepository returned malformed level entry")
				continue
			if repository.level_thumbnail(level) == null:
				_fail("ContentRepository could not load level thumbnail: %s" % level.get("id", ""))
			var config := repository.level_config(level)
			if config.is_empty() or repository.available_modes(level).is_empty():
				_fail("ContentRepository returned incomplete level: %s" % level.get("id", ""))


func _sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(file.get_buffer(file.get_length()))
	return hasher.finish().hex_encode()


func _fail(message: String) -> void:
	_failures.append(message)
