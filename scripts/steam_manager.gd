extends Node

signal steam_ready_changed(is_ready: bool)
signal status_changed(message: String, is_error: bool)
signal identity_changed(steam_id: int, persona_name: String)
signal overlay_state_changed(is_enabled: bool, is_active: bool)
signal stats_ready_changed(is_ready: bool)
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int, owner_steam_id: int, metadata: Dictionary)
signal lobby_left(lobby_id: int)
signal lobby_members_changed(lobby_id: int, member_ids: Array[int])
signal lobby_list_received(lobbies: Array[Dictionary])
signal join_requested(lobby_id: int, inviter_steam_id: int)
signal p2p_session_requested(remote_steam_id: int)
signal p2p_session_failed(remote_steam_id: int, message: String)
signal stats_stored(success: bool)
signal achievement_progressed(api_name: String, current_progress: int, max_progress: int, unlocked: bool)

const INVITE_CODE := preload("res://scripts/invite_code.gd")
const STEAM_PROFILE_PROVIDER := preload("res://scripts/steam_profile_sync_provider.gd")
const APP_ID_SETTING := "steam/initialization/app_data/app_id"
const INTEGRATION_ENABLED_SETTING := "steam/integration/enabled"
const PUBLIC_LOBBIES_SETTING := "steam/integration/public_lobbies"
const CLOUD_PROFILES_SETTING := "steam/integration/cloud_profiles"
const DEVELOPMENT_APP_ID := 480
const RESULT_OK := 1
const STEAM_INIT_OK := 0
const EMBED_CALLBACKS := false
const CHAT_ROOM_ENTER_SUCCESS := 1
const LOBBY_TYPE_FRIENDS_ONLY := 1
const LOBBY_TYPE_PUBLIC := 2
const LOBBY_COMPARISON_EQUAL := 0
const MAX_LOBBIES := 50
const MAX_CLOUD_JSON_BYTES := 2 * 1024 * 1024
const CLOUD_PROFILE_FILE := "darwine_profile_v1.json"
const CLOUD_PROFILE_BACKUP_FILE := "darwine_profile_v1.backup.json"
const OVERLAY_POLL_INTERVAL_SECONDS := 1.0
const OVERLAY_WARMUP_SECONDS := 15.0
const RICH_PRESENCE_MENU_TOKEN := "#Status_MainMenu"
const RICH_PRESENCE_LOBBY_TOKEN := "#Status_InLobby"
const RICH_PRESENCE_MATCH_TOKEN := "#Status_InMatch"
const LOBBY_METADATA_KEYS := [
	"darwine_game",
	"protocol",
	"app_version",
	"match_name",
	"ruleset",
	"card_pool_mode",
	"turn_duration_seconds",
	"auto_attack_allowed",
	"state",
	"auth_secret",
]
const STEAM_ACHIEVEMENTS := {
	"ilk_zafer": "DARWINE_ACH_FIRST_WIN",
	"tecrubeli_komutan": "DARWINE_ACH_10_MATCHES",
	"kusatma_izi": "DARWINE_ACH_100_HQ_DAMAGE",
	"demir_seri": "DARWINE_ACH_3_WIN_STREAK",
}
const STEAM_STATS := {
	"matches": "DARWINE_STAT_MATCHES",
	"wins": "DARWINE_STAT_WINS",
	"online_matches": "DARWINE_STAT_ONLINE_MATCHES",
	"cards_played": "DARWINE_STAT_CARDS_PLAYED",
	"hq_damage": "DARWINE_STAT_HQ_DAMAGE",
	"best_streak": "DARWINE_STAT_BEST_STREAK",
	"dominion_wins": "DARWINE_STAT_DOMINION_WINS",
}

var is_initialized := false
var is_available := false
var app_id := DEVELOPMENT_APP_ID
var steam_id := 0
var persona_name := ""
var current_lobby_id := 0
var current_lobby_owner_id := 0
var current_lobby_members: Array[int] = []
var last_status := ""
var last_status_is_error := false
var is_overlay_enabled := false
var is_overlay_active := false
var are_stats_ready := false
var last_stats_sync: Dictionary = {}

var _steam: Object = null
var _pending_lobby_metadata: Dictionary = {}
var _lobby_cache: Array[Dictionary] = []
var _launch_lobby_id := 0
var _profile_sync_provider: ProfileSyncProvider = null
var _overlay_poll_elapsed := 0.0
var _overlay_warmup_remaining := OVERLAY_WARMUP_SECONDS
var _stats_sync_queued := false
var _progress_notification_queued := false
var _last_achievement_progress: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("dedicated_server"):
		_set_status("Dedicated sunucu Steam istemci servislerini başlatmaz.")
		return
	if not bool(ProjectSettings.get_setting(INTEGRATION_ENABLED_SETTING, true)):
		_set_status("Steam entegrasyonu proje ayarından kapalı.")
		return
	_initialize_steam()


func _process(delta: float) -> void:
	if not is_initialized or not is_instance_valid(_steam):
		return
	# GodotSteam callbacks are driven explicitly. This keeps lobby, invite,
	# overlay, P2P and stats callbacks alive in menus and while paused.
	if _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")
	if not is_available:
		return
	_overlay_poll_elapsed += delta
	_overlay_warmup_remaining = maxf(0.0, _overlay_warmup_remaining - delta)
	if _overlay_poll_elapsed >= OVERLAY_POLL_INTERVAL_SECONDS:
		_overlay_poll_elapsed = 0.0
		_refresh_overlay_state()


func _exit_tree() -> void:
	if is_available and is_instance_valid(_steam):
		_steam.call("clearRichPresence")
	if is_initialized and is_instance_valid(_steam) and _steam.has_method("shutdown"):
		_steam.call("shutdown")


func get_steam_singleton() -> Object:
	return _steam


func get_account_id() -> String:
	return str(steam_id) if steam_id > 0 else ""


func get_persona_name() -> String:
	return persona_name


func is_cloud_available() -> bool:
	return (
		is_available
		and bool(ProjectSettings.get_setting(CLOUD_PROFILES_SETTING, true))
		and _steam.has_method("isCloudEnabledForAccount")
		and _steam.has_method("isCloudEnabledForApp")
		and bool(_steam.call("isCloudEnabledForAccount"))
		and bool(_steam.call("isCloudEnabledForApp"))
	)


func create_lobby(room_settings: Dictionary) -> Error:
	if not is_available:
		_set_status("Steam bağlantısı olmadan P2P lobisi oluşturulamaz.", true)
		return ERR_UNAVAILABLE
	if current_lobby_id > 0:
		return ERR_ALREADY_IN_USE
	_pending_lobby_metadata = _build_lobby_metadata(room_settings)
	var lobby_type := (
		LOBBY_TYPE_PUBLIC
		if bool(ProjectSettings.get_setting(PUBLIC_LOBBIES_SETTING, true))
		else LOBBY_TYPE_FRIENDS_ONLY
	)
	_steam.call("createLobby", lobby_type, GameRules.PLAYER_IDS.size())
	_set_status("Steam P2P lobisi oluşturuluyor…")
	return OK


func join_lobby(lobby_id: int) -> Error:
	if not is_available:
		_set_status("Steam bağlantısı olmadan P2P lobisine katılınamaz.", true)
		return ERR_UNAVAILABLE
	if lobby_id <= 0:
		return ERR_INVALID_PARAMETER
	if current_lobby_id > 0 and current_lobby_id != lobby_id:
		leave_lobby()
	_steam.call("joinLobby", lobby_id)
	_set_status("Steam lobisine katılınıyor…")
	return OK


func leave_lobby() -> void:
	var leaving_lobby_id := current_lobby_id
	if leaving_lobby_id <= 0:
		return
	if is_instance_valid(_steam):
		_steam.call("leaveLobby", leaving_lobby_id)
		_steam.call("clearRichPresence")
	current_lobby_id = 0
	current_lobby_owner_id = 0
	current_lobby_members.clear()
	_pending_lobby_metadata.clear()
	lobby_left.emit(leaving_lobby_id)
	set_rich_presence_menu()


func request_lobby_list() -> Error:
	if not is_available:
		lobby_list_received.emit([])
		return ERR_UNAVAILABLE
	if _steam.has_method("addRequestLobbyListStringFilter"):
		_steam.call("addRequestLobbyListStringFilter", "darwine_game", "darwine", LOBBY_COMPARISON_EQUAL)
	if _steam.has_method("addRequestLobbyListNumericalFilter"):
		_steam.call(
			"addRequestLobbyListNumericalFilter",
			"protocol",
			INVITE_CODE.PROTOCOL_VERSION,
			LOBBY_COMPARISON_EQUAL
		)
	if _steam.has_method("addRequestLobbyListResultCountFilter"):
		_steam.call("addRequestLobbyListResultCountFilter", MAX_LOBBIES)
	_steam.call("requestLobbyList")
	_set_status("Steam lobileri aranıyor…")
	return OK


func get_lobby_cache() -> Array[Dictionary]:
	return _lobby_cache.duplicate(true)


func get_lobby_metadata(lobby_id: int = 0) -> Dictionary:
	var resolved_lobby_id := lobby_id if lobby_id > 0 else current_lobby_id
	if not is_available or resolved_lobby_id <= 0:
		return {}
	var metadata := {}
	for key in LOBBY_METADATA_KEYS:
		metadata[key] = str(_steam.call("getLobbyData", resolved_lobby_id, key))
	return metadata


func get_lobby_member_ids(lobby_id: int = 0) -> Array[int]:
	var resolved_lobby_id := lobby_id if lobby_id > 0 else current_lobby_id
	var members: Array[int] = []
	if not is_available or resolved_lobby_id <= 0:
		return members
	var member_count := int(_steam.call("getNumLobbyMembers", resolved_lobby_id))
	for member_index in range(member_count):
		var member_id := int(_steam.call("getLobbyMemberByIndex", resolved_lobby_id, member_index))
		if member_id > 0 and member_id not in members:
			members.append(member_id)
	return members


func is_current_lobby_member(remote_steam_id: int) -> bool:
	return current_lobby_id > 0 and remote_steam_id in current_lobby_members


func invite_friends() -> Error:
	if not is_available or current_lobby_id <= 0:
		return ERR_UNAVAILABLE
	_steam.call("activateGameOverlayInviteDialog", current_lobby_id)
	_set_status(
		"Steam arkadaş daveti açıldı. Pencere görünmezse Shift+Tab ile Steam arayüzünü aç."
		if is_overlay_enabled
		else "Steam daveti istendi; arayüz hazırlanıyor. Birkaç saniye sonra Shift+Tab'i dene."
	)
	return OK


func open_friends_overlay() -> Error:
	return _open_overlay("Friends", "Steam arkadaş listesi açıldı.")


func open_achievements_overlay() -> Error:
	return _open_overlay("Achievements", "Steam başarımları açıldı.")


func get_overlay_status_text() -> String:
	if not is_available:
		return "Steam çevrimdışı"
	if is_overlay_active:
		return "Shift+Tab açık"
	if is_overlay_enabled:
		return "Shift+Tab hazır"
	if _overlay_warmup_remaining > 0.0:
		return "Shift+Tab hazırlanıyor"
	return "Steam Overlay kapalı"


func update_lobby_state(state_name: String) -> void:
	if not _owns_current_lobby():
		return
	var normalized := state_name.strip_edges().to_lower()
	_steam.call("setLobbyData", current_lobby_id, "state", normalized if not normalized.is_empty() else "waiting")
	if _steam.has_method("setLobbyJoinable"):
		# Mid-match strangers are rejected by NetworkManager authentication, while
		# keeping the lobby joinable allows the known reconnect token to return.
		_steam.call("setLobbyJoinable", current_lobby_id, true)


func set_rich_presence_menu() -> void:
	if not is_available:
		return
	_steam.call("clearRichPresence")
	_steam.call("setRichPresence", "status", "Ana Menü")
	_set_rich_presence_display(RICH_PRESENCE_MENU_TOKEN)


func set_rich_presence_lobby() -> void:
	if not is_available or current_lobby_id <= 0:
		return
	_steam.call("clearRichPresence")
	_steam.call("setRichPresence", "status", "Steam P2P Lobisinde")
	_set_rich_presence_display(RICH_PRESENCE_LOBBY_TOKEN)
	_steam.call("setRichPresence", "connect", "+connect_lobby %d" % current_lobby_id)
	_steam.call("setRichPresence", "steam_player_group", str(current_lobby_id))
	_steam.call("setRichPresence", "steam_player_group_size", str(current_lobby_members.size()))


func set_rich_presence_match(ruleset_name: String, match_name: String) -> void:
	if not is_available:
		return
	_steam.call("clearRichPresence")
	_steam.call("setRichPresence", "status", "%s • %s" % [ruleset_name, match_name])
	_steam.call("setRichPresence", "darwine_mode", ruleset_name.left(64))
	_steam.call("setRichPresence", "darwine_match", match_name.left(64))
	_set_rich_presence_display(RICH_PRESENCE_MATCH_TOKEN)
	if current_lobby_id > 0:
		_steam.call("setRichPresence", "connect", "+connect_lobby %d" % current_lobby_id)
		_steam.call("setRichPresence", "steam_player_group", str(current_lobby_id))
		_steam.call("setRichPresence", "steam_player_group_size", str(current_lobby_members.size()))


func sync_profile_stats(report_progress: bool = false) -> Dictionary:
	if not is_available:
		return {"success": false, "unavailable": true}
	if not are_stats_ready:
		_stats_sync_queued = true
		_progress_notification_queued = _progress_notification_queued or report_progress
		return {"success": false, "queued": true, "stats_ready": false}
	var profile_manager := get_node_or_null("/root/ProfileManager")
	if not profile_manager:
		return {"success": false, "error": "Profil yöneticisi bulunamadı."}
	var stats := profile_manager.get_stats() as Dictionary
	var changed := false
	var failed_stats: Array[String] = []
	for profile_key in STEAM_STATS:
		var steam_stat_name := str(STEAM_STATS[profile_key])
		var steam_value := int(_steam.call("getStatInt", steam_stat_name))
		var merged_value := maxi(steam_value, int(stats.get(profile_key, 0)))
		if merged_value <= steam_value:
			continue
		if not bool(_steam.call("setStatInt", steam_stat_name, merged_value)):
			failed_stats.append(steam_stat_name)
			continue
		changed = true
	var unlocked: Array[String] = []
	var failed_achievements: Array[String] = []
	for entry_variant in profile_manager.get_achievement_entries():
		var entry := entry_variant as Dictionary
		var achievement_id := str(entry.get("id", ""))
		if not STEAM_ACHIEVEMENTS.has(achievement_id):
			continue
		var api_name := str(STEAM_ACHIEVEMENTS[achievement_id])
		var progress := maxi(0, int(entry.get("progress", 0)))
		var target := maxi(1, int(entry.get("target", 1)))
		var completed := bool(entry.get("completed", false))
		var achievement_state_variant: Variant = _steam.call("getAchievement", api_name)
		var achievement_state := (
			achievement_state_variant as Dictionary
			if achievement_state_variant is Dictionary
			else {}
		)
		var already_unlocked := (
			bool(achievement_state.get("ret", false))
			and bool(achievement_state.get("achieved", false))
		)
		if completed and not already_unlocked:
			if bool(_steam.call("setAchievement", api_name)):
				changed = true
				unlocked.append(api_name)
			else:
				failed_achievements.append(api_name)
		elif (
			report_progress
			and progress > int(_last_achievement_progress.get(api_name, 0))
			and progress > 0
			and progress < target
			and _steam.has_method("indicateAchievementProgress")
		):
			_steam.call("indicateAchievementProgress", api_name, progress, target)
		_last_achievement_progress[api_name] = progress
	if changed:
		_steam.call("storeStats")
	_stats_sync_queued = false
	_progress_notification_queued = false
	last_stats_sync = {
		"success": failed_stats.is_empty() and failed_achievements.is_empty(),
		"stored": changed,
		"failed_stats": failed_stats,
		"failed_achievements": failed_achievements,
		"achievements": unlocked,
	}
	return last_stats_sync.duplicate(true)


func read_cloud_json(file_name: String) -> Dictionary:
	if not is_cloud_available() or file_name.strip_edges().is_empty():
		return {"success": false, "unavailable": true}
	if not bool(_steam.call("fileExists", file_name)):
		return {"success": false, "missing": true}
	var file_size := int(_steam.call("getFileSize", file_name))
	if file_size <= 0 or file_size > MAX_CLOUD_JSON_BYTES:
		return {"success": false, "error": "Steam Cloud dosya boyutu geçersiz."}
	var read_variant: Variant = _steam.call("fileRead", file_name, file_size)
	if not read_variant is Dictionary:
		return {"success": false, "error": "Steam Cloud okuma yanıtı geçersiz."}
	var read_result := read_variant as Dictionary
	var buffer_variant: Variant = read_result.get("buf", PackedByteArray())
	if int(read_result.get("ret", 0)) != file_size or not buffer_variant is PackedByteArray:
		return {"success": false, "error": "Steam Cloud dosyası eksik okundu."}
	var parsed: Variant = JSON.parse_string((buffer_variant as PackedByteArray).get_string_from_utf8())
	if not parsed is Dictionary:
		return {"success": false, "error": "Steam Cloud JSON verisi bozuk."}
	return {"success": true, "data": (parsed as Dictionary).duplicate(true), "size": file_size}


func write_cloud_json_with_backup(file_name: String, backup_name: String, data: Dictionary) -> Dictionary:
	if not is_cloud_available() or file_name.strip_edges().is_empty():
		return {"success": false, "unavailable": true}
	var serialized := JSON.stringify(data)
	var bytes := serialized.to_utf8_buffer()
	if bytes.is_empty() or bytes.size() > MAX_CLOUD_JSON_BYTES:
		return {"success": false, "error": "Steam Cloud profil verisi boyut sınırını aşıyor."}
	var batch_started := bool(_steam.call("beginFileWriteBatch")) if _steam.has_method("beginFileWriteBatch") else false
	if not backup_name.is_empty() and bool(_steam.call("fileExists", file_name)):
		var previous := read_cloud_json(file_name)
		if bool(previous.get("success", false)):
			var previous_bytes := JSON.stringify(previous.get("data", {})).to_utf8_buffer()
			_steam.call("fileWrite", backup_name, previous_bytes, previous_bytes.size())
	var success := bool(_steam.call("fileWrite", file_name, bytes, bytes.size()))
	if batch_started:
		_steam.call("endFileWriteBatch")
	return {"success": success, "size": bytes.size(), "error": "" if success else "Steam Cloud yazımı başarısız."}


func _initialize_steam() -> void:
	if not Engine.has_singleton("Steam"):
		_set_status("GodotSteam GDExtension yüklenemedi; çevrimdışı özellikler kullanılabilir.", true)
		steam_ready_changed.emit(false)
		return
	_steam = Engine.get_singleton("Steam")
	_connect_steam_signals()
	app_id = int(ProjectSettings.get_setting(APP_ID_SETTING, DEVELOPMENT_APP_ID))
	if app_id <= 0:
		app_id = DEVELOPMENT_APP_ID
	# Restart through the Steam client only for the real product. App ID 480 is
	# Spacewar and relaunching it would start Valve's test app instead of Darwine.
	if (
		app_id != DEVELOPMENT_APP_ID
		and not OS.has_feature("editor")
		and _steam.has_method("restartAppIfNecessary")
		and bool(_steam.call("restartAppIfNecessary", app_id))
	):
		_set_status("Darwine Steam üzerinden yeniden başlatılıyor…")
		get_tree().quit()
		return
	var response_variant: Variant = _steam.call("steamInitEx", app_id, EMBED_CALLBACKS)
	if not response_variant is Dictionary:
		_set_status("Steam başlatma yanıtı geçersiz; çevrimdışı devam ediliyor.", true)
		steam_ready_changed.emit(false)
		return
	var response := response_variant as Dictionary
	is_initialized = int(response.get("status", -1)) == STEAM_INIT_OK
	if not is_initialized:
		print_verbose("Steam initialization failed: %s" % str(response.get("verbal", "unknown error")))
		_set_status("Steam başlatılamadı. İstemcinin açık olduğunu ve App ID ayarını kontrol et; çevrimdışı devam ediliyor.", true)
		steam_ready_changed.emit(false)
		return
	steam_id = int(_steam.call("getSteamID"))
	persona_name = str(_steam.call("getPersonaName")).strip_edges()
	is_available = steam_id > 0
	if not is_available:
		_set_status("Steam kimliği alınamadı; çevrimdışı devam ediliyor.", true)
		steam_ready_changed.emit(false)
		return
	if persona_name.is_empty():
		persona_name = "Steam Komutanı"
	_set_status("Steam bağlı: %s" % persona_name)
	steam_ready_changed.emit(true)
	identity_changed.emit(steam_id, persona_name)
	_overlay_warmup_remaining = OVERLAY_WARMUP_SECONDS
	_refresh_overlay_state(true)
	set_rich_presence_menu()
	_bind_profile_services()
	_request_user_stats()
	_launch_lobby_id = _parse_launch_lobby_id()
	if _launch_lobby_id > 0:
		call_deferred("_emit_launch_join_request")


func _connect_steam_signals() -> void:
	_connect_steam_signal("lobby_created", _on_lobby_created)
	_connect_steam_signal("lobby_joined", _on_lobby_joined)
	_connect_steam_signal("lobby_match_list", _on_lobby_match_list)
	_connect_steam_signal("lobby_chat_update", _on_lobby_chat_update)
	_connect_steam_signal("lobby_data_update", _on_lobby_data_update)
	_connect_steam_signal("join_requested", _on_join_requested)
	_connect_steam_signal("join_game_requested", _on_join_game_requested)
	_connect_steam_signal("overlay_toggled", _on_overlay_toggled)
	_connect_steam_signal("network_messages_session_request", _on_network_session_request)
	_connect_steam_signal("network_messages_session_failed", _on_network_session_failed)
	_connect_steam_signal("user_stats_received", _on_user_stats_received)
	_connect_steam_signal("user_stats_stored", _on_user_stats_stored)
	_connect_steam_signal("user_achievement_stored", _on_user_achievement_stored)


func _connect_steam_signal(signal_name: StringName, callback: Callable) -> void:
	if _steam.has_signal(signal_name) and not _steam.is_connected(signal_name, callback):
		_steam.connect(signal_name, callback)


func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result != RESULT_OK or lobby_id <= 0:
		_pending_lobby_metadata.clear()
		_set_status("Steam lobisi oluşturulamadı (sonuç %d)." % result, true)
		lobby_created.emit(0)
		return
	current_lobby_id = lobby_id
	for key in _pending_lobby_metadata:
		_steam.call("setLobbyData", lobby_id, str(key), str(_pending_lobby_metadata[key]))
	if _steam.has_method("setLobbyJoinable"):
		_steam.call("setLobbyJoinable", lobby_id, true)
	lobby_created.emit(lobby_id)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != CHAT_ROOM_ENTER_SUCCESS or lobby_id <= 0:
		_set_status("Steam lobisine girilemedi (yanıt %d)." % response, true)
		lobby_joined.emit(0, 0, {})
		return
	current_lobby_id = lobby_id
	current_lobby_owner_id = int(_steam.call("getLobbyOwner", lobby_id))
	current_lobby_members = get_lobby_member_ids(lobby_id)
	var metadata := get_lobby_metadata(lobby_id)
	set_rich_presence_lobby()
	lobby_joined.emit(lobby_id, current_lobby_owner_id, metadata)
	lobby_members_changed.emit(lobby_id, current_lobby_members.duplicate())
	_set_status("Steam P2P lobisine bağlandı.")


func _on_lobby_match_list(lobby_ids: Array) -> void:
	_lobby_cache.clear()
	for lobby_id_variant in lobby_ids:
		var lobby_id := int(lobby_id_variant)
		if lobby_id <= 0:
			continue
		var metadata := get_lobby_metadata(lobby_id)
		if str(metadata.get("darwine_game", "")) != "darwine":
			continue
		if int(metadata.get("protocol", 0)) != INVITE_CODE.PROTOCOL_VERSION:
			continue
		var owner_id := int(_steam.call("getLobbyOwner", lobby_id))
		_lobby_cache.append({
			"lobby_id": lobby_id,
			"owner_steam_id": owner_id,
			"owner_name": get_friend_persona_name(owner_id),
			"member_count": int(_steam.call("getNumLobbyMembers", lobby_id)),
			"max_members": GameRules.PLAYER_IDS.size(),
			"metadata": metadata,
		})
	lobby_list_received.emit(_lobby_cache.duplicate(true))
	_set_status("%d uyumlu Steam lobisi bulundu." % _lobby_cache.size())


func _on_lobby_chat_update(
	lobby_id: int,
	_changed_id: int,
	_making_change_id: int,
	_chat_state: int
) -> void:
	if lobby_id != current_lobby_id:
		return
	current_lobby_owner_id = int(_steam.call("getLobbyOwner", lobby_id))
	current_lobby_members = get_lobby_member_ids(lobby_id)
	lobby_members_changed.emit(lobby_id, current_lobby_members.duplicate())
	set_rich_presence_lobby()


func _on_lobby_data_update(success: bool, lobby_id: int, member_id: int) -> void:
	# LobbyDataUpdate also reports per-member metadata changes. Only re-emit the
	# joined lobby contract when the room metadata itself changed.
	if success and lobby_id == current_lobby_id and member_id == lobby_id:
		lobby_joined.emit(lobby_id, int(_steam.call("getLobbyOwner", lobby_id)), get_lobby_metadata(lobby_id))


func _on_join_requested(lobby_id: int, inviter_steam_id: int) -> void:
	if lobby_id <= 0:
		return
	join_requested.emit(lobby_id, inviter_steam_id)


func _on_join_game_requested(friend_steam_id: int, connect_string: String) -> void:
	var lobby_id := _parse_connect_lobby_id(connect_string)
	if lobby_id <= 0:
		_set_status("Steam arkadaş katılma bilgisi geçersiz veya bu sürümle uyumsuz.", true)
		return
	join_requested.emit(lobby_id, friend_steam_id)


func _on_overlay_toggled(active: bool, _user_initiated: bool, callback_app_id: int) -> void:
	if callback_app_id > 0 and callback_app_id != app_id:
		return
	is_overlay_active = active
	_refresh_overlay_state(true)


func _on_network_session_request(remote_steam_id: int) -> void:
	if not is_current_lobby_member(remote_steam_id):
		current_lobby_members = get_lobby_member_ids(current_lobby_id)
		if not is_current_lobby_member(remote_steam_id):
			return
	_steam.call("acceptSessionWithUser", remote_steam_id)
	p2p_session_requested.emit(remote_steam_id)


func _on_network_session_failed(
	_reason: int,
	remote_steam_id: int,
	_connection_state: int,
	debug_message: String
) -> void:
	var message := debug_message.strip_edges()
	if message.is_empty():
		message = "Steam P2P oturumu başarısız oldu."
	p2p_session_failed.emit(remote_steam_id, message)


func _on_user_stats_received(_game_id: int, result: int, user_id: int) -> void:
	if user_id != steam_id:
		return
	var was_ready := are_stats_ready
	are_stats_ready = result == RESULT_OK
	if are_stats_ready != was_ready or not are_stats_ready:
		stats_ready_changed.emit(are_stats_ready)
	if not are_stats_ready:
		_set_status("Steam başarımları ve istatistikleri yüklenemedi (sonuç %d)." % result, true)
		return
	call_deferred("_flush_queued_stats_sync")


func _on_user_stats_stored(_game_id: int, result: int) -> void:
	var success := result == RESULT_OK
	stats_stored.emit(success)
	if not success:
		_set_status("Steam başarım/istatistik kaydı başarısız oldu (sonuç %d)." % result, true)


func _on_user_achievement_stored(
	_game_id: int,
	_group_achievement: bool,
	achievement_name: String,
	current_progress: int,
	max_progress: int
) -> void:
	achievement_progressed.emit(
		achievement_name,
		current_progress,
		max_progress,
		not _group_achievement or max_progress <= 0 or current_progress >= max_progress
	)


func _request_user_stats() -> void:
	are_stats_ready = false
	stats_ready_changed.emit(false)
	if not is_available or not _steam.has_method("requestUserStats"):
		return
	# Steamworks SDK 1.61+ removed RequestCurrentStats from GodotSteam. The
	# equivalent local-user request still emits user_stats_received.
	_steam.call("requestUserStats", steam_id)


func _flush_queued_stats_sync() -> void:
	if not are_stats_ready:
		return
	var report_progress := _progress_notification_queued
	_stats_sync_queued = false
	_progress_notification_queued = false
	sync_profile_stats(report_progress)


func _refresh_overlay_state(force_emit: bool = false) -> void:
	if not is_available or not is_instance_valid(_steam) or not _steam.has_method("isOverlayEnabled"):
		if force_emit or is_overlay_enabled or is_overlay_active:
			is_overlay_enabled = false
			is_overlay_active = false
			overlay_state_changed.emit(false, false)
		return
	var enabled := bool(_steam.call("isOverlayEnabled"))
	if force_emit or enabled != is_overlay_enabled:
		is_overlay_enabled = enabled
		overlay_state_changed.emit(is_overlay_enabled, is_overlay_active)


func _open_overlay(dialog_name: String, success_message: String) -> Error:
	if not is_available or not is_instance_valid(_steam) or not _steam.has_method("activateGameOverlay"):
		return ERR_UNAVAILABLE
	_steam.call("activateGameOverlay", dialog_name)
	_set_status(
		success_message
		if is_overlay_enabled
		else "Steam Overlay hazırlanıyor. Birkaç saniye sonra Shift+Tab'i yeniden dene."
	)
	return OK


func _set_rich_presence_display(token: String) -> void:
	# Spacewar does not contain Darwine localization tokens. Keep the legacy
	# status string visible during App ID 480 tests and use localized tokens in
	# the real Steamworks application.
	if app_id != DEVELOPMENT_APP_ID:
		_steam.call("setRichPresence", "steam_display", token)


func _bind_profile_services() -> void:
	var profile_manager := get_node_or_null("/root/ProfileManager")
	if not profile_manager:
		return
	var match_callback := Callable(self, "_on_profile_match_recorded")
	if not profile_manager.match_recorded.is_connected(match_callback):
		profile_manager.match_recorded.connect(match_callback)
	if is_cloud_available():
		_profile_sync_provider = STEAM_PROFILE_PROVIDER.new()
		_profile_sync_provider.name = "SteamProfileSyncProvider"
		add_child(_profile_sync_provider)
		_profile_sync_provider.configure(self)
		profile_manager.set_sync_provider(_profile_sync_provider)
		profile_manager.call_deferred("begin_online_sync")
	call_deferred("sync_profile_stats")


func _on_profile_match_recorded(_result: Dictionary) -> void:
	sync_profile_stats(true)
	var profile_manager := get_node_or_null("/root/ProfileManager")
	if profile_manager and _profile_sync_provider and _profile_sync_provider.is_available():
		profile_manager.begin_online_sync()


func _build_lobby_metadata(room_settings: Dictionary) -> Dictionary:
	var secret := int(Time.get_ticks_usec() ^ steam_id ^ randi()) & 0x7fffffff
	return {
		"darwine_game": "darwine",
		"protocol": str(INVITE_CODE.PROTOCOL_VERSION),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "0.0")),
		"match_name": str(room_settings.get("match_name", MatchSetup.DEFAULT_MATCH_NAME)).left(MatchSetup.MAX_MATCH_NAME_LENGTH),
		"ruleset": str(int(room_settings.get("ruleset", MatchSetup.Ruleset.SIEGE))),
		"card_pool_mode": str(int(room_settings.get("card_pool_mode", MatchSetup.CardPoolMode.DECK))),
		"turn_duration_seconds": str(int(room_settings.get("turn_duration_seconds", GameRules.TURN_DURATION_SECONDS))),
		"auto_attack_allowed": "1" if bool(room_settings.get("auto_attack_allowed", true)) else "0",
		"state": "waiting",
		"auth_secret": str(maxi(1, secret)),
	}


func get_friend_persona_name(friend_steam_id: int) -> String:
	if not is_available or friend_steam_id <= 0:
		return "Steam Komutanı"
	if friend_steam_id == steam_id:
		return persona_name
	var value := str(_steam.call("getFriendPersonaName", friend_steam_id)).strip_edges()
	return value if not value.is_empty() else "Steam Komutanı"


func _owns_current_lobby() -> bool:
	return current_lobby_id > 0 and current_lobby_owner_id == steam_id


func _parse_launch_lobby_id() -> int:
	var arguments := Array(OS.get_cmdline_args())
	for user_argument in OS.get_cmdline_user_args():
		if user_argument not in arguments:
			arguments.append(user_argument)
	for index in range(arguments.size()):
		var argument := str(arguments[index]).strip_edges().trim_prefix("\"").trim_suffix("\"")
		if argument == "+connect_lobby" and index + 1 < arguments.size():
			return _parse_connect_lobby_id("+connect_lobby %s" % str(arguments[index + 1]))
		var lobby_id := _parse_connect_lobby_id(argument)
		if lobby_id > 0:
			return lobby_id
	return 0


func _parse_connect_lobby_id(connect_string: String) -> int:
	var normalized := connect_string.strip_edges().trim_prefix("\"").trim_suffix("\"")
	for prefix in ["+connect_lobby=", "--connect-lobby="]:
		if normalized.begins_with(prefix):
			return maxi(0, int(normalized.trim_prefix(prefix).strip_edges()))
	if normalized.begins_with("+connect_lobby "):
		return maxi(0, int(normalized.trim_prefix("+connect_lobby ").strip_edges().get_slice(" ", 0)))
	return 0


func _emit_launch_join_request() -> void:
	if _launch_lobby_id <= 0:
		return
	var lobby_id := _launch_lobby_id
	_launch_lobby_id = 0
	join_requested.emit(lobby_id, 0)


func _set_status(message: String, is_error: bool = false) -> void:
	last_status = message
	last_status_is_error = is_error
	status_changed.emit(message, is_error)
