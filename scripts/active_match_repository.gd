class_name ActiveMatchRepository extends RefCounted

const SAVE_SCHEMA_VERSION := 2
const BACKUP_COUNT := 3
const DEFAULT_SAVE_PATH := "user://darwine_active_match.json"
const SLOT_DIRECTORY := "user://darwine_saves"
const SLOT_FILE_PREFIX := "slot_"
const SLOT_FILE_EXTENSION := ".json"
const LEGACY_SLOT_ID := "legacy"
const AUTOSAVE_SLOT_ID := "autosave"
const MAX_SLOT_NAME_LENGTH := 40

var save_path := DEFAULT_SAVE_PATH
var current_slot_id := ""
var current_slot_name := ""
var _custom_path_mode := false


func configure_path(path: String) -> void:
	save_path = path if not path.strip_edges().is_empty() else DEFAULT_SAVE_PATH
	current_slot_id = ""
	current_slot_name = ""
	_custom_path_mode = save_path != DEFAULT_SAVE_PATH


func configure_slot(slot_id: String, slot_name := "") -> bool:
	var normalized_id := _normalize_slot_id(slot_id)
	if normalized_id.is_empty():
		return false
	current_slot_id = normalized_id
	current_slot_name = _sanitize_slot_name(slot_name)
	save_path = _path_for_slot(normalized_id)
	_custom_path_mode = false
	if current_slot_name.is_empty():
		var status := _inspect_path(save_path, 0)
		current_slot_name = _sanitize_slot_name(str(status.get("slot_name", "")))
		if current_slot_name.is_empty():
			current_slot_name = _sanitize_slot_name(str(status.get("match_name", "")))
		if current_slot_name.is_empty():
			current_slot_name = _fallback_slot_name(normalized_id)
	return true


func is_custom_path() -> bool:
	return _custom_path_mode


func get_current_slot_id() -> String:
	return current_slot_id


func get_current_slot_name() -> String:
	return current_slot_name


func save_snapshot_to_slot(snapshot: Dictionary, slot_name: String, slot_id := "") -> Dictionary:
	var clean_name := _sanitize_slot_name(slot_name)
	if clean_name.is_empty():
		return {"success": false, "error": "Kayıt slotu için bir ad gerekli."}
	var target_id := _normalize_slot_id(slot_id)
	if target_id.is_empty():
		target_id = _allocate_slot_id(clean_name)
	var previous_path := save_path
	var previous_slot_id := current_slot_id
	var previous_slot_name := current_slot_name
	var previous_custom_mode := _custom_path_mode
	if not configure_slot(target_id, clean_name):
		return {"success": false, "error": "Kayıt slotu kimliği geçersiz."}
	var result := save_snapshot(snapshot)
	if not bool(result.get("success", false)):
		save_path = previous_path
		current_slot_id = previous_slot_id
		current_slot_name = previous_slot_name
		_custom_path_mode = previous_custom_mode
		return result
	result["slot_id"] = current_slot_id
	result["slot_name"] = current_slot_name
	return result


func list_slots() -> Array[Dictionary]:
	if _custom_path_mode:
		var custom_status := inspect_save()
		if str(custom_status.get("state", "missing")) == "missing":
			return []
		custom_status["slot_id"] = "configured"
		custom_status["slot_name"] = str(custom_status.get("slot_name", "Test Kaydı"))
		custom_status["path"] = save_path
		return [custom_status]

	var result: Array[Dictionary] = []
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SLOT_DIRECTORY)):
		var file_names := DirAccess.get_files_at(SLOT_DIRECTORY)
		file_names.sort()
		for file_name in file_names:
			if not file_name.begins_with(SLOT_FILE_PREFIX) or not file_name.ends_with(SLOT_FILE_EXTENSION):
				continue
			var slot_id := file_name.trim_prefix(SLOT_FILE_PREFIX).trim_suffix(SLOT_FILE_EXTENSION)
			if _normalize_slot_id(slot_id) != slot_id:
				continue
			result.append(_slot_listing(slot_id, SLOT_DIRECTORY.path_join(file_name)))

	if _save_family_exists(DEFAULT_SAVE_PATH):
		result.append(_slot_listing(LEGACY_SLOT_ID, DEFAULT_SAVE_PATH))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("saved_at_unix", 0)) > int(right.get("saved_at_unix", 0))
	)
	return result


func inspect_slot(slot_id: String) -> Dictionary:
	if slot_id == "configured" and _custom_path_mode:
		var configured_status := inspect_save()
		configured_status["slot_id"] = "configured"
		configured_status["path"] = save_path
		return configured_status
	var normalized_id := _normalize_slot_id(slot_id)
	if normalized_id.is_empty():
		return {"state": "missing", "missing": true, "has_backup": false, "error": "Kayıt slotu geçersiz."}
	var path := _path_for_slot(normalized_id)
	var status := _inspect_path_with_backups(path)
	status["slot_id"] = normalized_id
	status["path"] = path
	if str(status.get("slot_name", "")).is_empty():
		status["slot_name"] = _fallback_slot_name(normalized_id)
	return status


func load_slot(slot_id: String) -> Dictionary:
	if slot_id == "configured" and _custom_path_mode:
		var configured_loaded := load_primary()
		configured_loaded["slot_id"] = "configured"
		configured_loaded["slot_name"] = str(configured_loaded.get("slot_name", "Test Kaydı"))
		return configured_loaded
	var normalized_id := _normalize_slot_id(slot_id)
	if normalized_id.is_empty():
		return {"success": false, "error": "Kayıt slotu geçersiz."}
	if not configure_slot(normalized_id):
		return {"success": false, "error": "Kayıt slotu seçilemedi."}
	var loaded := load_primary()
	loaded["slot_id"] = current_slot_id
	loaded["slot_name"] = current_slot_name
	return loaded


func delete_slot(slot_id: String) -> bool:
	if slot_id == "configured" and _custom_path_mode:
		delete_all()
		return true
	var normalized_id := _normalize_slot_id(slot_id)
	if normalized_id.is_empty():
		return false
	SafeJsonStore.remove_family(_path_for_slot(normalized_id), BACKUP_COUNT)
	if current_slot_id == normalized_id:
		current_slot_id = ""
		current_slot_name = ""
		save_path = DEFAULT_SAVE_PATH
	return true


func save_snapshot(snapshot: Dictionary) -> Dictionary:
	var validation := validate_snapshot(snapshot)
	if not bool(validation.get("success", false)):
		return validation
	var directory_result := _ensure_parent_directory(save_path)
	if not bool(directory_result.get("success", false)):
		return directory_result
	var resolved_slot_name := _sanitize_slot_name(current_slot_name)
	if resolved_slot_name.is_empty():
		resolved_slot_name = str(snapshot.get("match_name", "Otomatik Kayıt")).strip_edges().left(MAX_SLOT_NAME_LENGTH)
	var payload := {
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"game_version": _game_version(),
		"saved_at_utc": Time.get_datetime_string_from_system(true, true),
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"slot_id": current_slot_id,
		"slot_name": resolved_slot_name,
		"snapshot": snapshot.duplicate(true),
	}
	var result := SafeJsonStore.write_dictionary_atomic(save_path, payload, BACKUP_COUNT)
	if not bool(result.get("success", false)):
		return result
	current_slot_name = resolved_slot_name
	return {
		"success": true,
		"path": save_path,
		"saved_at_utc": payload["saved_at_utc"],
		"slot_id": current_slot_id,
		"slot_name": current_slot_name,
	}


func inspect_save() -> Dictionary:
	return _inspect_path_with_backups(save_path)


func load_primary() -> Dictionary:
	var result := _load_path(save_path)
	if bool(result.get("success", false)):
		if current_slot_id.is_empty():
			current_slot_id = str(result.get("slot_id", current_slot_id))
		current_slot_name = str(result.get("slot_name", current_slot_name))
	return result


func load_backup(index: int) -> Dictionary:
	if index < 1 or index > BACKUP_COUNT:
		return {"success": false, "error": "Geçersiz yedek numarası."}
	return _load_path(SafeJsonStore.backup_path(save_path, index))


func recover_backup(index: int = 0) -> Dictionary:
	var chosen_index := index
	if chosen_index == 0:
		var status := inspect_save()
		var backups_variant: Variant = status.get("backups", [])
		if not backups_variant is Array or (backups_variant as Array).is_empty():
			return {"success": false, "error": "Kurtarılabilecek geçerli yedek yok."}
		chosen_index = int(((backups_variant as Array)[0] as Dictionary).get("backup_index", 0))
	var loaded := load_backup(chosen_index)
	if not bool(loaded.get("success", false)):
		return loaded
	var save_result := save_snapshot(loaded.get("snapshot", {}) as Dictionary)
	if not bool(save_result.get("success", false)):
		return save_result
	return {
		"success": true,
		"snapshot": (loaded.get("snapshot", {}) as Dictionary).duplicate(true),
		"backup_index": chosen_index,
	}


func delete_all() -> void:
	SafeJsonStore.remove_family(save_path, BACKUP_COUNT)


func validate_snapshot(snapshot: Dictionary) -> Dictionary:
	for key in ["match_id", "game_version", "seed", "match_mode", "manager", "zones", "rng", "effect_cards"]:
		if not snapshot.has(key):
			return {"success": false, "error": "Aktif maç kaydında '%s' eksik." % key}
	if str(snapshot.get("match_id", "")).strip_edges().is_empty():
		return {"success": false, "error": "Aktif maç kimliği eksik."}
	if not snapshot.get("manager") is Dictionary or not snapshot.get("zones") is Dictionary:
		return {"success": false, "error": "Aktif maç durum bölümleri geçersiz."}
	return {"success": true}


func _inspect_path(path: String, backup_index: int) -> Dictionary:
	var loaded := SafeJsonStore.read_dictionary(path)
	if not bool(loaded.get("success", false)):
		return {
			"state": "missing" if bool(loaded.get("missing", false)) else "corrupt",
			"missing": bool(loaded.get("missing", false)),
			"error": str(loaded.get("error", "Kayıt okunamadı.")),
			"backup_index": backup_index,
		}
	var payload := loaded.get("data", {}) as Dictionary
	var compatibility := _validate_payload(payload)
	if not bool(compatibility.get("success", false)):
		return {
			"state": str(compatibility.get("state", "corrupt")),
			"error": str(compatibility.get("error", "Kayıt doğrulanamadı.")),
			"backup_index": backup_index,
		}
	return {
		"state": "valid",
		"success": true,
		"backup_index": backup_index,
		"saved_at_utc": str(payload.get("saved_at_utc", "")),
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
		"slot_id": str(payload.get("slot_id", "")),
		"slot_name": str(payload.get("slot_name", "")),
		"match_id": str((payload.get("snapshot", {}) as Dictionary).get("match_id", "")),
		"match_name": str((payload.get("snapshot", {}) as Dictionary).get("match_name", "")),
		"ruleset": int((payload.get("snapshot", {}) as Dictionary).get("ruleset", 0)),
		"match_mode": int((payload.get("snapshot", {}) as Dictionary).get("match_mode", 0)),
		"round_count": int(((payload.get("snapshot", {}) as Dictionary).get("manager", {}) as Dictionary).get("round_count", 1)),
		"turn_count": int(((payload.get("snapshot", {}) as Dictionary).get("manager", {}) as Dictionary).get("turn_count", 1)),
		"last_save_reason": str((payload.get("snapshot", {}) as Dictionary).get("last_save_reason", "")),
	}


func _load_path(path: String) -> Dictionary:
	var loaded := SafeJsonStore.read_dictionary(path)
	if not bool(loaded.get("success", false)):
		return loaded
	var payload := loaded.get("data", {}) as Dictionary
	var validation := _validate_payload(payload)
	if not bool(validation.get("success", false)):
		return validation
	return {
		"success": true,
		"snapshot": (payload.get("snapshot", {}) as Dictionary).duplicate(true),
		"saved_at_utc": str(payload.get("saved_at_utc", "")),
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
		"slot_id": str(payload.get("slot_id", current_slot_id)),
		"slot_name": str(payload.get("slot_name", current_slot_name)),
	}


func _validate_payload(payload: Dictionary) -> Dictionary:
	var schema_version := int(payload.get("save_schema_version", 0))
	if schema_version != SAVE_SCHEMA_VERSION:
		return {
			"success": false,
			"state": "incompatible",
			"error": "Kayıt sürümü uyumsuz (kayıt %d, desteklenen %d)." % [schema_version, SAVE_SCHEMA_VERSION],
		}
	if not _is_game_version_compatible(str(payload.get("game_version", ""))):
		return {
			"success": false,
			"state": "incompatible",
			"error": "Kayıt farklı bir oyun sürümüne ait.",
		}
	var snapshot_variant: Variant = payload.get("snapshot", {})
	if not snapshot_variant is Dictionary:
		return {"success": false, "state": "corrupt", "error": "Maç snapshot'ı geçersiz."}
	var snapshot_validation := validate_snapshot(snapshot_variant as Dictionary)
	if not bool(snapshot_validation.get("success", false)):
		snapshot_validation["state"] = "corrupt"
	return snapshot_validation


func _inspect_path_with_backups(path: String) -> Dictionary:
	var primary := _inspect_path(path, 0)
	if str(primary.get("state", "")) == "valid":
		primary["has_backup"] = _has_valid_backup(path)
		return primary
	var valid_backups: Array[Dictionary] = []
	for index in range(1, BACKUP_COUNT + 1):
		var backup := _inspect_path(SafeJsonStore.backup_path(path, index), index)
		if str(backup.get("state", "")) == "valid":
			valid_backups.append(backup)
	if bool(primary.get("missing", false)) and valid_backups.is_empty():
		return {"state": "missing", "missing": true, "has_backup": false}
	var result := {
		"state": "recoverable" if not valid_backups.is_empty() else str(primary.get("state", "corrupt")),
		"error": str(primary.get("error", "Aktif maç kaydı okunamadı.")),
		"has_backup": not valid_backups.is_empty(),
		"backups": valid_backups,
		"primary_state": str(primary.get("state", "corrupt")),
	}
	if not valid_backups.is_empty():
		var newest_backup := valid_backups[0]
		for key in ["saved_at_utc", "saved_at_unix", "slot_id", "slot_name", "match_id", "match_name", "ruleset", "match_mode", "round_count", "turn_count", "last_save_reason"]:
			result[key] = newest_backup.get(key)
	return result


func _slot_listing(slot_id: String, path: String) -> Dictionary:
	var status := _inspect_path_with_backups(path)
	status["slot_id"] = slot_id
	status["path"] = path
	var listed_name := _sanitize_slot_name(str(status.get("slot_name", "")))
	if listed_name.is_empty():
		listed_name = _sanitize_slot_name(str(status.get("match_name", "")))
	status["slot_name"] = listed_name if not listed_name.is_empty() else _fallback_slot_name(slot_id)
	return status


func _has_valid_backup(path: String) -> bool:
	for index in range(1, BACKUP_COUNT + 1):
		if str(_inspect_path(SafeJsonStore.backup_path(path, index), index).get("state", "")) == "valid":
			return true
	return false


func _save_family_exists(path: String) -> bool:
	if FileAccess.file_exists(path):
		return true
	for index in range(1, BACKUP_COUNT + 1):
		if FileAccess.file_exists(SafeJsonStore.backup_path(path, index)):
			return true
	return false


func _path_for_slot(slot_id: String) -> String:
	if slot_id == LEGACY_SLOT_ID:
		return DEFAULT_SAVE_PATH
	return SLOT_DIRECTORY.path_join("%s%s%s" % [SLOT_FILE_PREFIX, slot_id, SLOT_FILE_EXTENSION])


func _normalize_slot_id(slot_id: String) -> String:
	var value := slot_id.strip_edges().to_lower()
	if value == LEGACY_SLOT_ID:
		return value
	if value.is_empty() or value.length() > 80:
		return ""
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return ""
	return value


func _allocate_slot_id(slot_name: String) -> String:
	var slug := ""
	for character in slot_name.to_lower():
		if character in "abcdefghijklmnopqrstuvwxyz0123456789":
			slug += character
		elif character in " -_" and not slug.ends_with("-"):
			slug += "-"
	slug = slug.trim_prefix("-").trim_suffix("-").left(18)
	if slug.is_empty():
		slug = "kayit"
	var timestamp := int(Time.get_unix_time_from_system())
	var serial := int(Time.get_ticks_usec() % 1000000)
	var candidate := "%s-%d-%06d" % [slug, timestamp, serial]
	var attempt := 1
	while _save_family_exists(_path_for_slot(candidate)):
		candidate = "%s-%d-%06d-%d" % [slug, timestamp, serial, attempt]
		attempt += 1
	return candidate


func _sanitize_slot_name(slot_name: String) -> String:
	return slot_name.replace("\n", " ").replace("\r", " ").strip_edges().left(MAX_SLOT_NAME_LENGTH)


func _fallback_slot_name(slot_id: String) -> String:
	if slot_id == AUTOSAVE_SLOT_ID:
		return "Otomatik Kayıt"
	if slot_id == LEGACY_SLOT_ID:
		return "Eski Otomatik Kayıt"
	return "Kayıt Slotu"


func _ensure_parent_directory(path: String) -> Dictionary:
	var directory := path.get_base_dir()
	if directory.is_empty() or directory == "user:/" or directory == "user://":
		return {"success": true}
	var absolute_directory := ProjectSettings.globalize_path(directory)
	if DirAccess.dir_exists_absolute(absolute_directory):
		return {"success": true}
	var error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK:
		return {"success": false, "error": "Kayıt klasörü oluşturulamadı: %s" % error_string(error)}
	return {"success": true}


func _game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0"))


func _is_game_version_compatible(saved_version: String) -> bool:
	var current_parts := _game_version().split(".")
	var saved_parts := saved_version.split(".")
	if current_parts.size() < 2 or saved_parts.size() < 2:
		return saved_version == _game_version()
	return current_parts[0] == saved_parts[0] and current_parts[1] == saved_parts[1]
