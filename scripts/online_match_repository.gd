class_name OnlineMatchRepository extends RefCounted

const SAVE_SCHEMA_VERSION := 1
const BACKUP_COUNT := 2

var save_path := "user://darwine_online_match_7777.json"


func configure_port(port: int) -> void:
	save_path = "user://darwine_online_match_%d.json" % clampi(port, 1, 65535)


func save_match(payload: Dictionary) -> Dictionary:
	var validation := validate_payload(payload)
	if not bool(validation.get("success", false)):
		return validation
	var wrapped := payload.duplicate(true)
	wrapped["save_schema_version"] = SAVE_SCHEMA_VERSION
	wrapped["saved_at_utc"] = Time.get_datetime_string_from_system(true, true)
	return SafeJsonStore.write_dictionary_atomic(save_path, wrapped, BACKUP_COUNT)


func load_match() -> Dictionary:
	for path in [save_path, SafeJsonStore.backup_path(save_path, 1), SafeJsonStore.backup_path(save_path, 2)]:
		var loaded := SafeJsonStore.read_dictionary(path)
		if not bool(loaded.get("success", false)):
			continue
		var payload := loaded.get("data", {}) as Dictionary
		var validation := validate_payload(payload)
		if bool(validation.get("success", false)):
			return {"success": true, "payload": payload.duplicate(true), "path": path}
	return {"success": false, "missing": true, "error": "Kurtarılabilir çevrimiçi maç snapshot'ı yok."}


func delete_all() -> void:
	SafeJsonStore.remove_family(save_path, BACKUP_COUNT)


func validate_payload(payload: Dictionary) -> Dictionary:
	if payload.has("save_schema_version") and int(payload.get("save_schema_version", 0)) != SAVE_SCHEMA_VERSION:
		return {"success": false, "error": "Çevrimiçi snapshot sürümü uyumsuz."}
	for key in ["match_id", "session_key", "revision", "seed", "invite_secret", "players", "snapshot"]:
		if not payload.has(key):
			return {"success": false, "error": "Çevrimiçi snapshot alanı eksik: %s" % key}
	var match_id := str(payload.get("match_id", "")).strip_edges()
	var session_key := str(payload.get("session_key", "")).strip_edges()
	if match_id.is_empty() or session_key.length() < 24:
		return {"success": false, "error": "Çevrimiçi snapshot kimliği eksik."}
	if int(payload.get("revision", -1)) < 0:
		return {"success": false, "error": "Çevrimiçi snapshot revizyonu geçersiz."}
	if int(payload.get("seed", 0)) <= 0 or int(payload.get("invite_secret", 0)) <= 0:
		return {"success": false, "error": "Çevrimiçi snapshot oturum bilgisi geçersiz."}
	if not payload.get("players") is Dictionary or not payload.get("snapshot") is Dictionary:
		return {"success": false, "error": "Çevrimiçi snapshot içeriği geçersiz."}

	var players := payload.get("players") as Dictionary
	if players.size() != GameRules.PLAYER_IDS.size():
		return {"success": false, "error": "Çevrimiçi snapshot oyuncu sayısı geçersiz."}
	for player_id in GameRules.PLAYER_IDS:
		var player_variant: Variant = _player_value(players, player_id, {})
		if not player_variant is Dictionary:
			return {"success": false, "error": "Çevrimiçi snapshot oyuncu kaydı eksik."}
		var player := player_variant as Dictionary
		if str(player.get("token", "")).strip_edges().is_empty():
			return {"success": false, "error": "Çevrimiçi snapshot yeniden bağlanma anahtarı eksik."}
		var deck_variant: Variant = player.get("deck_cards", [])
		if not deck_variant is Array or (deck_variant as Array).size() != GameRules.DECK_SIZE:
			return {"success": false, "error": "Çevrimiçi snapshot deste kaydı geçersiz."}

	var snapshot := payload.get("snapshot") as Dictionary
	if (
		str(snapshot.get("match_id", "")) != match_id
		or int(snapshot.get("seed", 0)) != int(payload.get("seed", 0))
		or not snapshot.get("manager") is Dictionary
		or not snapshot.get("zones") is Dictionary
	):
		return {"success": false, "error": "Çevrimiçi snapshot maç durumu kimlikle eşleşmiyor."}
	return {"success": true}


func _player_value(players: Dictionary, player_id: int, fallback: Variant) -> Variant:
	if players.has(player_id):
		return players[player_id]
	var key := str(player_id)
	return players.get(key, fallback)
