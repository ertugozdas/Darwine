extends SceneTree


class FakeSteamMessages extends RefCounted:
	var sent: Array[Dictionary] = []
	var incoming_by_channel: Dictionary = {}
	var closed_sessions: Array[int] = []

	func sendMessageToUser(remote_id: int, data: PackedByteArray, flags: int, channel: int) -> int:
		sent.append({
			"remote_id": remote_id,
			"data": data.duplicate(),
			"flags": flags,
			"channel": channel,
		})
		return 1

	func receiveMessagesOnChannel(channel: int, _max_messages: int) -> Array:
		var messages := (incoming_by_channel.get(channel, []) as Array).duplicate(true)
		incoming_by_channel[channel] = []
		return messages

	func closeSessionWithUser(remote_id: int) -> bool:
		closed_sessions.append(remote_id)
		return true


var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(Engine.has_singleton("Steam"), "GodotSteam GDExtension singleton'i yüklenmedi")
	_expect(
		int(ProjectSettings.get_setting("steam/initialization/app_data/app_id", 0)) == 480,
		"Geliştirme Steam App ID ayarı 480 olmalı"
	)
	var steam := Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	if steam:
		for method_name in [
			"steamInitEx",
			"run_callbacks",
			"restartAppIfNecessary",
			"createLobby",
			"requestLobbyList",
			"sendMessageToUser",
			"receiveMessagesOnChannel",
			"acceptSessionWithUser",
			"closeSessionWithUser",
			"requestUserStats",
			"getAchievement",
			"setAchievement",
			"indicateAchievementProgress",
			"getStatInt",
			"setStatInt",
			"storeStats",
			"setRichPresence",
			"fileRead",
			"fileWrite",
			"isOverlayEnabled",
			"activateGameOverlay",
			"activateGameOverlayInviteDialog",
		]:
			_expect(steam.has_method(method_name), "Steam API yöntemi eksik: %s" % method_name)
		for signal_name in [
			"lobby_created",
			"lobby_joined",
			"lobby_match_list",
			"lobby_chat_update",
			"lobby_data_update",
			"join_requested",
			"join_game_requested",
			"overlay_toggled",
			"network_messages_session_request",
			"network_messages_session_failed",
			"user_stats_received",
			"user_stats_stored",
			"user_achievement_stored",
		]:
			_expect(steam.has_signal(signal_name), "Steam API sinyali eksik: %s" % signal_name)
		var join_game_args := _steam_signal_args(steam, "join_game_requested")
		_expect(join_game_args.size() == 2, "join_game_requested iki parametre taşımalı")
		if join_game_args.size() == 2:
			_expect(str((join_game_args[0] as Dictionary).get("name", "")) == "user", "Rich Presence arkadaş kimliği sözleşmesi değişti")
			_expect(str((join_game_args[1] as Dictionary).get("name", "")) == "connect", "Rich Presence connect string sözleşmesi değişti")
		var signal_contracts := {
			"lobby_created": ["connect", "lobby_id"],
			"lobby_joined": ["lobby", "permissions", "locked", "response"],
			"lobby_data_update": ["success", "lobby_id", "member_id"],
			"lobby_chat_update": ["lobby_id", "changed_id", "making_change_id", "chat_state"],
			"join_requested": ["lobby_id", "steam_id"],
			"overlay_toggled": ["active", "user_initiated", "app_id"],
			"network_messages_session_request": ["remote_steam_id"],
			"network_messages_session_failed": ["reason", "remote_steam_id", "connection_state", "debug_message"],
			"user_stats_received": ["game_id", "result", "user_id"],
			"user_stats_stored": ["game_id", "result"],
			"user_achievement_stored": ["game_id", "group_achieve", "achievement_name", "current_progress", "max_progress"],
		}
		for signal_name in signal_contracts:
			_expect(
				_steam_signal_argument_names(steam, signal_name) == signal_contracts[signal_name],
				"Steam sinyal parametre sözleşmesi değişti: %s" % signal_name
			)

	_test_transport_round_trip()
	_test_cloud_merge_policy()
	_test_achievement_contract()
	_finish()


func _test_transport_round_trip() -> void:
	var host_api := FakeSteamMessages.new()
	var host := SteamP2PPeer.new()
	_expect(host.setup_host(host_api, 9001, 111) == OK, "Steam host peer kurulamadı")
	_expect(host.add_lobby_member(222) == OK, "Steam lobi üyesi peer'e eklenemedi")
	host.set_target_peer(SteamP2PPeer.CLIENT_PEER_ID)
	host.set_transfer_channel(2)
	host.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
	var payload := "darwine-steam-p2p".to_utf8_buffer()
	_expect(host.put_packet(payload) == OK, "Steam P2P paketi çerçevelenemedi")
	_expect(host_api.sent.size() == 1, "Steam P2P paketi tek eşe gönderilmeli")
	var oversized_payload := PackedByteArray()
	oversized_payload.resize(SteamP2PPeer.MAX_PAYLOAD_BYTES + 1)
	_expect(host.put_packet(oversized_payload) == ERR_INVALID_DATA, "Steam P2P paket üst sınırı uygulanmadı")
	_expect(host_api.sent.size() == 1, "Boyut sınırını aşan Steam paketi gönderildi")
	if host_api.sent.is_empty():
		return
	var sent := host_api.sent[0]
	_expect(int(sent.get("remote_id", 0)) == 222, "Steam paketi yanlış kimliğe yönlendirildi")
	_expect(int(sent.get("channel", -1)) == 2, "Steam aktarım kanalı korunmadı")
	_expect(int(sent.get("flags", -1)) == 0, "Sıralı güvenilmez paket Steam'de reliable olmamalı")

	var client_api := FakeSteamMessages.new()
	var client := SteamP2PPeer.new()
	_expect(client.setup_client(client_api, 9001, 222, 111) == OK, "Steam client peer kurulamadı")
	client_api.incoming_by_channel[2] = [{"identity": 111, "payload": sent.get("data", PackedByteArray())}]
	client.poll()
	_expect(client.get_available_packet_count() == 1, "Steam mesajı Godot paket kuyruğuna alınmadı")
	_expect(client.get_packet_peer() == SteamP2PPeer.SERVER_PEER_ID, "Gönderen Godot peer kimliği yanlış")
	_expect(client.get_packet_channel() == 2, "Alınan Steam paket kanalı yanlış")
	_expect(
		client.get_packet_mode() == MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
		"Alınan Steam aktarım modu yanlış"
	)
	_expect(client.get_packet() == payload, "Steam P2P payload gidiş-dönüşte değişti")

	# The same ordered frame must not be delivered twice.
	client_api.incoming_by_channel[2] = [{"identity": 111, "payload": sent.get("data", PackedByteArray())}]
	client.poll()
	_expect(client.get_available_packet_count() == 0, "Tekrarlanan sıralı paket elenmedi")
	client_api.incoming_by_channel[2] = [{"identity": 999, "payload": sent.get("data", PackedByteArray())}]
	client.poll()
	_expect(client.get_available_packet_count() == 0, "Lobi dışı Steam kimliğinin paketi kabul edildi")


func _test_cloud_merge_policy() -> void:
	var provider := SteamProfileSyncProvider.new()
	var remote := {
		"profile_id": "profile-1",
		"total_xp": 100,
		"last_modified_unix": 1000,
		"stats": {"matches": 4, "wins": 1},
		"achievements": {"ilk_zafer": {"progress": 1, "completed": true}},
		"unlocked_titles": ["sancak_tasiyicisi"],
		"unlocked_banners": ["kul_ve_pirinc"],
		"history": [{"match_id": "remote-match"}],
		"settings": {"updated_at_unix": 100, "values": {"music": 0.5}},
		"decks": {"updated_at_unix": 100, "decks": []},
	}
	var client := {
		"profile_id": "profile-1",
		"total_xp": 120,
		"last_modified_unix": 1100,
		"stats": {"matches": 3, "wins": 2},
		"achievements": {"tecrubeli_komutan": {"progress": 3, "completed": false}},
		"unlocked_titles": ["demir_irade"],
		"unlocked_banners": ["kul_ve_pirinc"],
		"history": [{"match_id": "client-match"}],
		"settings": {"updated_at_unix": 200, "values": {"music": 0.8}},
		"decks": {"updated_at_unix": 200, "decks": [{"id": "deck-1"}]},
	}
	var merged := provider.call("_merge_profiles", remote, client) as Dictionary
	var stats := merged.get("stats", {}) as Dictionary
	var achievements := merged.get("achievements", {}) as Dictionary
	_expect(int(stats.get("matches", 0)) == 4, "Cloud merge toplam maç sayısını geriletmemeli")
	_expect(int(stats.get("wins", 0)) == 2, "Cloud merge zafer sayısını geriletmemeli")
	_expect(bool((achievements.get("ilk_zafer", {}) as Dictionary).get("completed", false)), "Cloud merge açılmış başarımı korumalı")
	_expect((merged.get("history", []) as Array).size() == 2, "Cloud merge benzersiz maç geçmişlerini birleştirmeli")
	_expect(int((merged.get("settings", {}) as Dictionary).get("updated_at_unix", 0)) == 200, "Cloud merge en yeni ayarı seçmeli")
	provider.free()


func _test_achievement_contract() -> void:
	var manager := get_root().get_node_or_null("SteamManager")
	_expect(manager != null, "SteamManager autoload bulunamadı")
	if not manager:
		return
	var mappings := manager.STEAM_ACHIEVEMENTS as Dictionary
	var stat_mappings := manager.STEAM_STATS as Dictionary
	_expect(manager.has_signal("overlay_state_changed"), "SteamManager overlay durumunu yayınlamalı")
	_expect(manager.has_signal("stats_ready_changed"), "SteamManager istatistik hazırlığını yayınlamalı")
	_expect(manager.has_signal("achievement_progressed"), "SteamManager başarım ilerlemesini yayınlamalı")
	_expect(manager.has_method("open_friends_overlay"), "Steam arkadaş overlay geçidi eksik")
	_expect(manager.has_method("open_achievements_overlay"), "Steam başarım overlay geçidi eksik")
	_expect(manager.has_method("get_overlay_status_text"), "Steam overlay durum özeti eksik")
	_expect(int(manager.call("_parse_connect_lobby_id", "+connect_lobby 76561199000000001")) == 76561199000000001, "Rich Presence katılma bilgisi çözülemedi")
	_expect(int(manager.call("_parse_connect_lobby_id", "+connect_lobby=76561199000000002")) == 76561199000000002, "Eşittirli Steam katılma bilgisi çözülemedi")
	_expect(not bool(manager.EMBED_CALLBACKS), "Steam callback'leri tek ve açık bir oyun döngüsünden yürütülmeli")
	_expect(str(manager.RICH_PRESENCE_MENU_TOKEN).begins_with("#Status_"), "Ana menü Rich Presence token'ı eksik")
	_expect(str(manager.RICH_PRESENCE_LOBBY_TOKEN).begins_with("#Status_"), "Lobi Rich Presence token'ı eksik")
	_expect(str(manager.RICH_PRESENCE_MATCH_TOKEN).begins_with("#Status_"), "Maç Rich Presence token'ı eksik")
	_expect(mappings.size() == 4, "Dört oyun içi başarım Steam API adına bağlanmalı")
	_expect(stat_mappings.size() == 7, "Yedi oyun içi sayaç Steam istatistiğine bağlanmalı")
	for profile_id in ["ilk_zafer", "tecrubeli_komutan", "kusatma_izi", "demir_seri"]:
		_expect(str(mappings.get(profile_id, "")).begins_with("DARWINE_ACH_"), "Başarım eşlemesi eksik: %s" % profile_id)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _steam_signal_args(steam: Object, signal_name: String) -> Array:
	for signal_variant in steam.get_signal_list():
		var signal_data := signal_variant as Dictionary
		if str(signal_data.get("name", "")) == signal_name:
			return signal_data.get("args", []) as Array
	return []


func _steam_signal_argument_names(steam: Object, signal_name: String) -> Array[String]:
	var names: Array[String] = []
	for argument_variant in _steam_signal_args(steam, signal_name):
		var argument := argument_variant as Dictionary
		names.append(str(argument.get("name", "")))
	return names


func _finish() -> void:
	if _failures.is_empty():
		print("STEAM_INTEGRATION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("STEAM_INTEGRATION_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
