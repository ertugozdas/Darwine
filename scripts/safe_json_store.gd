class_name SafeJsonStore extends RefCounted

## Small, shared persistence primitive for profile, active-match and dedicated
## server snapshots. Writes are validated in a temporary file before the old
## file is rotated into numbered backups.


static func read_dictionary(path: String) -> Dictionary:
	if path.strip_edges().is_empty() or not FileAccess.file_exists(path):
		return {"success": false, "missing": true, "error": "Kayıt bulunamadı."}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {
			"success": false,
			"error": "Kayıt açılamadı: %s" % error_string(FileAccess.get_open_error()),
		}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		return {
			"success": false,
			"error": "JSON bozuk: %s (satır %d)" % [json.get_error_message(), json.get_error_line()],
		}
	if not json.data is Dictionary:
		return {"success": false, "error": "Kayıt kökü sözlük olmalı."}
	return {"success": true, "data": (json.data as Dictionary).duplicate(true)}


static func write_dictionary_atomic(path: String, data: Dictionary, backup_count: int = 0) -> Dictionary:
	if path.strip_edges().is_empty():
		return {"success": false, "error": "Kayıt yolu boş."}
	var temporary_path := "%s.tmp" % path
	_remove_if_exists(temporary_path)
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if not file:
		return {
			"success": false,
			"error": "Geçici kayıt açılamadı: %s" % error_string(FileAccess.get_open_error()),
		}
	file.store_string(JSON.stringify(data, "\t", false, true))
	file.flush()
	file = null

	var verification := read_dictionary(temporary_path)
	if not bool(verification.get("success", false)):
		_remove_if_exists(temporary_path)
		return {
			"success": false,
			"error": "Geçici kayıt doğrulanamadı: %s" % str(verification.get("error", "bilinmeyen hata")),
		}

	var rotate_error := _rotate_existing(path, maxi(0, backup_count))
	if rotate_error != OK:
		_remove_if_exists(temporary_path)
		return {"success": false, "error": "Kayıt yedeklenemedi: %s" % error_string(rotate_error)}
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(path)
	)
	if rename_error != OK:
		# Best effort: put the newest backup back where the live file belongs.
		var first_backup := backup_path(path, 1)
		if FileAccess.file_exists(first_backup) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(
				ProjectSettings.globalize_path(first_backup),
				ProjectSettings.globalize_path(path)
			)
		_remove_if_exists(temporary_path)
		return {"success": false, "error": "Atomik kayıt tamamlanamadı: %s" % error_string(rename_error)}
	return {"success": true}


static func backup_path(path: String, index: int) -> String:
	return "%s.bak%d" % [path, maxi(1, index)]


static func remove_family(path: String, backup_count: int) -> void:
	_remove_if_exists("%s.tmp" % path)
	_remove_if_exists(path)
	for index in range(1, maxi(0, backup_count) + 1):
		_remove_if_exists(backup_path(path, index))


static func _rotate_existing(path: String, backup_count: int) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	if backup_count <= 0:
		return _remove_if_exists(path)

	_remove_if_exists(backup_path(path, backup_count))
	for index in range(backup_count - 1, 0, -1):
		var source := backup_path(path, index)
		if not FileAccess.file_exists(source):
			continue
		var move_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(source),
			ProjectSettings.globalize_path(backup_path(path, index + 1))
		)
		if move_error != OK:
			return move_error
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path),
		ProjectSettings.globalize_path(backup_path(path, 1))
	)


static func _remove_if_exists(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
