class_name AtomicJsonStore
extends RefCounted

## Owns only safe JSON file I/O. Repositories own defaults and validation.

func load_dictionary(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func write_dictionary(path: String, data: Dictionary) -> Dictionary:
	if path.is_empty():
		return _failure("invalid_path")
	var absolute_path := ProjectSettings.globalize_path(path)
	var directory := absolute_path.get_base_dir()
	var make_directory := DirAccess.make_dir_recursive_absolute(directory)
	if make_directory != OK:
		return _failure("directory_unavailable")
	var temporary_path := "%s.tmp" % absolute_path
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _failure("temporary_open_failed")
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var verified := load_dictionary(temporary_path)
	if verified.is_empty() and not data.is_empty():
		DirAccess.remove_absolute(temporary_path)
		return _failure("temporary_verify_failed")
	var rename_result := DirAccess.rename_absolute(temporary_path, absolute_path)
	if rename_result != OK:
		DirAccess.remove_absolute(temporary_path)
		return _failure("atomic_replace_failed")
	return {"ok": true}


func _failure(code: String) -> Dictionary:
	return {"ok": false, "error": code}
