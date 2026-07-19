class_name SteamProfileSyncProvider extends ProfileSyncProvider

## Steam Cloud account storage adapter. The resolved document is written and
## read back before it is returned to ProfileManager. This provides a single
## cross-device account copy; it is not an anti-cheat or trusted game server.

const CLOUD_SCHEMA_VERSION := 1
const MAX_HISTORY := 30

var _steam_manager: Node = null
var _cancelled_requests: Dictionary = {}


func configure(steam_manager: Node) -> void:
	_steam_manager = steam_manager
	availability_changed.emit(is_available())


func is_available() -> bool:
	return (
		is_instance_valid(_steam_manager)
		and _steam_manager.has_method("is_cloud_available")
		and bool(_steam_manager.call("is_cloud_available"))
	)


func get_account_id() -> String:
	if not is_instance_valid(_steam_manager) or not _steam_manager.has_method("get_account_id"):
		return ""
	return str(_steam_manager.call("get_account_id")).strip_edges()


func begin_sync(request_id: String, request: Dictionary) -> bool:
	if not is_available() or request_id.strip_edges().is_empty():
		return false
	if str(request.get("account_id", "")) != get_account_id():
		return false
	_cancelled_requests.erase(request_id)
	call_deferred("_perform_sync", request_id, request.duplicate(true))
	return true


func cancel_sync(request_id: String) -> void:
	_cancelled_requests[request_id] = true


func _perform_sync(request_id: String, request: Dictionary) -> void:
	if _cancelled_requests.erase(request_id):
		sync_completed.emit(request_id, {"success": false, "error": "Steam Cloud eşitlemesi iptal edildi."})
		return
	if not is_available():
		sync_completed.emit(request_id, {"success": false, "error": "Steam Cloud kullanılamıyor."})
		return
	var account_id := get_account_id()
	var client_variant: Variant = request.get("client_profile", {})
	if account_id.is_empty() or not client_variant is Dictionary:
		sync_completed.emit(request_id, {"success": false, "error": "Yerel profil eşitleme verisi geçersiz."})
		return

	var remote_result := _steam_manager.call("read_cloud_json", _steam_manager.CLOUD_PROFILE_FILE) as Dictionary
	var remote_profile: Dictionary = {}
	var remote_revision := 0
	if bool(remote_result.get("success", false)):
		var envelope_variant: Variant = remote_result.get("data", {})
		if not envelope_variant is Dictionary:
			_sync_failed(request_id, "Steam Cloud profil zarfı geçersiz.")
			return
		var envelope := envelope_variant as Dictionary
		var stored_account_id := str(envelope.get("account_id", ""))
		if not stored_account_id.is_empty() and stored_account_id != account_id:
			_sync_failed(request_id, "Steam Cloud profilinin hesap kimliği uyuşmuyor.")
			return
		var stored_profile_variant: Variant = envelope.get("profile", {})
		if stored_profile_variant is Dictionary:
			remote_profile = (stored_profile_variant as Dictionary).duplicate(true)
		remote_revision = maxi(0, int(envelope.get("revision", 0)))
	elif not bool(remote_result.get("missing", false)):
		_sync_failed(request_id, str(remote_result.get("error", "Steam Cloud profili okunamadı.")))
		return

	var client_profile := (client_variant as Dictionary).duplicate(true)
	var merged := _merge_profiles(remote_profile, client_profile)
	var revision := maxi(remote_revision, int(request.get("last_server_revision", 0))) + 1
	var envelope := {
		"schema_version": CLOUD_SCHEMA_VERSION,
		"account_id": account_id,
		"profile_id": str(merged.get("profile_id", request.get("profile_id", ""))),
		"revision": revision,
		"updated_at_utc": Time.get_datetime_string_from_system(true, true),
		"profile": merged,
	}
	var write_result := _steam_manager.call(
		"write_cloud_json_with_backup",
		_steam_manager.CLOUD_PROFILE_FILE,
		_steam_manager.CLOUD_PROFILE_BACKUP_FILE,
		envelope
	) as Dictionary
	if not bool(write_result.get("success", false)):
		_sync_failed(request_id, str(write_result.get("error", "Steam Cloud profili yazılamadı.")))
		return

	# Treat the cloud copy as resolved only after the exact revision is readable.
	var verification := _steam_manager.call("read_cloud_json", _steam_manager.CLOUD_PROFILE_FILE) as Dictionary
	if not bool(verification.get("success", false)):
		_sync_failed(request_id, "Steam Cloud yazımı doğrulanamadı.")
		return
	var verified_envelope := verification.get("data", {}) as Dictionary
	if (
		int(verified_envelope.get("revision", -1)) != revision
		or str(verified_envelope.get("account_id", "")) != account_id
		or not verified_envelope.get("profile", {}) is Dictionary
	):
		_sync_failed(request_id, "Steam Cloud doğrulama verisi uyuşmuyor.")
		return

	var acknowledged_ids: Array[String] = []
	var operations_variant: Variant = request.get("pending_operations", [])
	if operations_variant is Array:
		for operation_variant in operations_variant as Array:
			if operation_variant is Dictionary:
				var operation_id := str((operation_variant as Dictionary).get("operation_id", ""))
				if not operation_id.is_empty():
					acknowledged_ids.append(operation_id)
	sync_completed.emit(request_id, {
		"success": true,
		"server_authoritative": true,
		"authority_kind": "steam_cloud_account_copy",
		"profile": (verified_envelope.get("profile", {}) as Dictionary).duplicate(true),
		"revision": revision,
		"acknowledged_operation_ids": acknowledged_ids,
	})


func _sync_failed(request_id: String, message: String) -> void:
	sync_completed.emit(request_id, {"success": false, "error": message})


func _merge_profiles(remote: Dictionary, client: Dictionary) -> Dictionary:
	if remote.is_empty():
		return client.duplicate(true)
	if client.is_empty():
		return remote.duplicate(true)
	var remote_total_xp := int(remote.get("total_xp", 0))
	var client_total_xp := int(client.get("total_xp", 0))
	var remote_modified := int(remote.get("last_modified_unix", 0))
	var client_modified := int(client.get("last_modified_unix", 0))
	var remote_is_primary := (
		remote_total_xp > client_total_xp
		or (remote_total_xp == client_total_xp and remote_modified > client_modified)
	)
	var merged := (remote if remote_is_primary else client).duplicate(true)
	var secondary := client if remote_is_primary else remote

	merged["stats"] = _merge_numeric_dictionary(
		remote.get("stats", {}) as Dictionary,
		client.get("stats", {}) as Dictionary
	)
	merged["achievements"] = _merge_progress_dictionary(
		remote.get("achievements", {}) as Dictionary,
		client.get("achievements", {}) as Dictionary
	)
	merged["missions"] = _merge_missions(
		remote.get("missions", {}) as Dictionary,
		client.get("missions", {}) as Dictionary
	)
	merged["unlocked_titles"] = _union_strings(
		remote.get("unlocked_titles", []) as Array,
		client.get("unlocked_titles", []) as Array
	)
	merged["unlocked_banners"] = _union_strings(
		remote.get("unlocked_banners", []) as Array,
		client.get("unlocked_banners", []) as Array
	)
	merged["history"] = _merge_history(
		merged.get("history", []) as Array,
		secondary.get("history", []) as Array
	)
	merged["decks"] = _latest_section(
		remote.get("decks", {}) as Dictionary,
		client.get("decks", {}) as Dictionary
	)
	merged["settings"] = _latest_section(
		remote.get("settings", {}) as Dictionary,
		client.get("settings", {}) as Dictionary
	)
	if int(secondary.get("commander_updated_at_unix", 0)) > int(merged.get("commander_updated_at_unix", 0)):
		merged["commander_name"] = str(secondary.get("commander_name", merged.get("commander_name", "Komutan")))
		merged["commander_updated_at_unix"] = int(secondary.get("commander_updated_at_unix", 0))
	merged["last_modified_unix"] = maxi(remote_modified, client_modified)
	merged.erase("sync")
	return merged


func _merge_numeric_dictionary(left: Dictionary, right: Dictionary) -> Dictionary:
	var merged := left.duplicate(true)
	for key_variant in right.keys():
		var key := str(key_variant)
		merged[key] = maxi(int(merged.get(key, 0)), int(right[key_variant]))
	return merged


func _merge_progress_dictionary(left: Dictionary, right: Dictionary) -> Dictionary:
	var merged := left.duplicate(true)
	for key_variant in right.keys():
		var key := str(key_variant)
		var left_state := merged.get(key, {}) as Dictionary
		var right_state := right[key_variant] as Dictionary if right[key_variant] is Dictionary else {}
		var state := left_state.duplicate(true)
		state["progress"] = maxi(int(left_state.get("progress", 0)), int(right_state.get("progress", 0)))
		state["completed"] = bool(left_state.get("completed", false)) or bool(right_state.get("completed", false))
		if left_state.has("rewarded") or right_state.has("rewarded"):
			state["rewarded"] = bool(left_state.get("rewarded", false)) or bool(right_state.get("rewarded", false))
		merged[key] = state
	return merged


func _merge_missions(left: Dictionary, right: Dictionary) -> Dictionary:
	var merged := left.duplicate(true)
	for period in ["daily", "weekly"]:
		var left_period := left.get(period, {}) as Dictionary
		var right_period := right.get(period, {}) as Dictionary
		var left_key := str(left.get("%s_key" % period, ""))
		var right_key := str(right.get("%s_key" % period, ""))
		if left_key == right_key:
			merged[period] = _merge_progress_dictionary(left_period, right_period)
			merged["%s_key" % period] = left_key
		elif not right_key.is_empty() and right_key > left_key:
			merged[period] = right_period.duplicate(true)
			merged["%s_key" % period] = right_key
	return merged


func _union_strings(left: Array, right: Array) -> Array[String]:
	var result: Array[String] = []
	for value_variant in left + right:
		var value := str(value_variant)
		if not value.is_empty() and value not in result:
			result.append(value)
	return result


func _merge_history(primary: Array, secondary: Array) -> Array:
	var seen := {}
	var result: Array = []
	for entry_variant in primary + secondary:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var match_id := str(entry.get("match_id", ""))
		if match_id.is_empty() or seen.has(match_id):
			continue
		seen[match_id] = true
		result.append(entry.duplicate(true))
		if result.size() >= MAX_HISTORY:
			break
	return result


func _latest_section(left: Dictionary, right: Dictionary) -> Dictionary:
	return (
		right.duplicate(true)
		if int(right.get("updated_at_unix", 0)) > int(left.get("updated_at_unix", 0))
		else left.duplicate(true)
	)
