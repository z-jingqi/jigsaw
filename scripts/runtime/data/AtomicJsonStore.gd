class_name AtomicJsonStore
extends RefCounted
## Verified atomic JSON replacement with a last-known-good recovery copy.

var _validators: Dictionary = {}
var _load_statuses: Dictionary = {}
var _write_protected: Dictionary = {}


func load_dictionary(path: String) -> Dictionary:
	return load_validated_dictionary(path, Callable())


func load_validated_dictionary(path: String, validator: Callable) -> Dictionary:
	if path.is_empty():
		return _block_load(path, "invalid_path")
	_validators[path] = validator
	var primary := _read(path, validator)
	if primary.ok:
		_write_protected.erase(path)
		var backup := _read(path + ".bak", validator)
		var backup_result := {"ok": true}
		if not backup.ok:
			backup_result = (
				_failure("unsupported_backup_schema")
				if backup.error == "unsupported_schema"
				else _replace_verified(path + ".bak", primary.text)
			)
		_load_statuses[path] = {
			"ok": true,
			"state": "loaded",
			"backup_ok": backup_result.ok,
			"backup_error": backup_result.get("error", ""),
		}
		if backup_result.get("error", "") == "unsupported_backup_schema":
			_write_protected[path] = "unsupported_backup_schema"
			_load_statuses[path].merge(
				{"ok": false, "state": "blocked", "error": "unsupported_backup_schema"}, true
			)
		return primary.data
	# A newer-format file is not corruption. Never replace it with an older backup.
	if primary.error == "unsupported_schema":
		return _block_load(path, primary.error)
	for candidate in [path + ".bak", path + ".tmp"]:
		var recovered := _read(candidate, validator)
		if recovered.get("error", "") == "unsupported_schema":
			return _block_load(path, "unsupported_backup_schema")
		if not recovered.ok:
			continue
		_write_protected.erase(path)
		# Recovery itself uses verified atomic replacement and never rotates the
		# corrupt primary over the good backup. Original bytes remain on failure.
		var repaired := _replace_verified(path, recovered.text)
		_load_statuses[path] = {
			"ok": true,
			"state": "recovered",
			"source": candidate,
			"repair_ok": repaired.ok,
			"primary_error": primary.error,
		}
		return recovered.data
	if (
		primary.error == "missing"
		and not FileAccess.file_exists(path + ".bak")
		and not FileAccess.file_exists(path + ".tmp")
	):
		_write_protected.erase(path)
		_load_statuses[path] = {"ok": true, "state": "new"}
		return {}
	return _block_load(path, "save_unreadable")


func load_status(path: String) -> Dictionary:
	return _load_statuses.get(path, {"ok": true, "state": "not_loaded"}).duplicate(true)


func can_write(path: String, data: Dictionary) -> Dictionary:
	if path.is_empty():
		return _failure("invalid_path")
	if _write_protected.has(path):
		return _failure(str(_write_protected[path]))
	var validator: Callable = _validators.get(path, Callable())
	if validator.is_valid():
		var validation: String = validator.call(data)
		if not validation.is_empty():
			return _failure(validation)
	return {"ok": true}


func write_dictionary(path: String, data: Dictionary) -> Dictionary:
	var permitted := can_write(path, data)
	if not permitted.ok:
		return permitted
	var validator: Callable = _validators.get(path, Callable())
	var text := JSON.stringify(data)
	var current := _read(path, validator)
	if _read(path + ".bak", validator).get("error", "") == "unsupported_schema":
		return _failure("unsupported_backup_schema")
	if current.ok:
		var backup := _replace_verified(path + ".bak", current.text)
		if not backup.ok:
			return _failure("backup_write_failed")
	elif current.error != "missing" and not _read(path + ".bak", validator).ok:
		# Also protect files which became corrupt after loading.
		return _failure("save_unreadable")
	elif current.error == "unsupported_schema":
		return _failure("unsupported_schema")
	# A first save also gets a recovery copy. A crash before the main rename
	# can recover it; no previously committed state is lost.
	if not current.ok and not _read(path + ".bak", validator).ok:
		var initial_backup := _replace_verified(path + ".bak", text)
		if not initial_backup.ok:
			return _failure("backup_write_failed")
	return _replace_verified(path, text)


func _block_load(path: String, error: String) -> Dictionary:
	_write_protected[path] = error
	_load_statuses[path] = {"ok": false, "state": "blocked", "error": error}
	return {}


func _read(path: String, validator: Callable) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return _failure("missing")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("read_failed")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return _failure("invalid_json")
	if validator.is_valid():
		var validation: String = validator.call(parser.data)
		if not validation.is_empty():
			return _failure(validation)
	return {"ok": true, "data": parser.data, "text": text}


func _replace_verified(path: String, text: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return _failure("directory_unavailable")
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("temporary_open_failed")
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return _failure("temporary_write_failed")
	var verification := FileAccess.open(temporary, FileAccess.READ)
	if verification == null:
		return _failure("temporary_verify_failed")
	var exact := verification.get_as_text() == text
	verification.close()
	if not exact:
		return _failure("temporary_verify_failed")
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		return _failure("atomic_replace_failed")
	return {"ok": true}


func _failure(code: String) -> Dictionary:
	return {"ok": false, "error": code}
