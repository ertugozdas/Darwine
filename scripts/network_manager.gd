extends Node

signal status_changed(message: String, is_error: bool)
signal lobby_changed(players: Dictionary)
signal match_starting(local_player_id: int)
signal action_pending_changed(is_pending: bool)
signal connection_closed(message: String)
signal room_hosted(invite_code: String)
signal steam_room_hosted(lobby_id: int)
signal steam_lobbies_changed(lobbies: Array[Dictionary])
signal reconnect_available(invite_code: String, player_name: String, seconds_remaining: int)
signal opponent_connection_changed(player_id: int, connected: bool, seconds_remaining: int)
signal rematch_status_changed(votes: int, required_votes: int, message: String)

enum NetworkState { OFFLINE, CONNECTING, LOBBY, STARTING, MATCH, RECONNECTING }

const INVITE_CODE := preload("res://scripts/invite_code.gd")
const STEAM_P2P_PEER := preload("res://scripts/steam_p2p_peer.gd")
const BATTLEFIELD_SCENE := "res://battlefield.tscn"
const SERVER_LOBBY_SCENE := "res://server/server_lobby.tscn"
const MAIN_MENU_SCENE := "res://main_menu.tscn"
const DEFAULT_PORT := 7777
const MAX_PLAYERS := 2
const AUTH_TIMEOUT_SECONDS := 6.0
const CLOCK_SYNC_INTERVAL := 0.25
const MAX_AUTH_BYTES := 16384
const MAX_PLAYER_NAME_LENGTH := 24
const RECONNECT_GRACE_SECONDS := 90

var state: NetworkState = NetworkState.OFFLINE
var local_player_id := 0
var last_status := ""
var last_status_is_error := false

var _is_server := false
var _public_ip := ""
var _server_port := DEFAULT_PORT
var _invite_secret := 0
var _invite_code := ""
var _player_name := "Komutan"
var _pending_auth: Dictionary = {}
var _peer_to_player: Dictionary = {}
var _players: Dictionary = {}
var _ready_peers: Dictionary = {}
var _match_seed := 0
var _match_id := ""
var _session_key := ""
var _expected_match_id := ""
var _expected_session_key := ""
var _room_ruleset := MatchSetup.Ruleset.SIEGE
var _room_match_name := MatchSetup.DEFAULT_MATCH_NAME
var _room_card_pool_mode := MatchSetup.CardPoolMode.DECK
var _room_turn_duration_seconds := GameRules.TURN_DURATION_SECONDS
var _room_auto_attack_allowed := true
var _match_started := false
var _battlefield: Node = null
var _pending_snapshot: Dictionary = {}
var _last_snapshot_revision := -1
var _snapshot_revision := 0
var _snapshot_dirty := false
var _clock_sync_elapsed := 0.0
var _action_pending := false
var _server_action_busy := false
var _intentional_disconnect := false
var _smoke_client := false
var _smoke_server := false
var _smoke_host := false
var _smoke_online_flow := false
var _smoke_server_restart := false
var _smoke_restart_initial_ready := false
var _smoke_restart_disconnected := false
var _smoke_restart_retry_running := false
var _smoke_restart_recovered := false
var _smoke_host_finished := false
var _smoke_client_finished := false
var _smoke_match_generation := 0
var _smoke_disconnect_started := false
var _smoke_reconnect_restored := false
var _smoke_reconnect_accepted := false
var _smoke_reconnect_peer_ready := false
var _smoke_forced_game_over := false
var _smoke_rematch_vote_sent := false
var _smoke_initial_turn_player_id := 0
var _smoke_turn_handoff_host_logged := false
var _smoke_turn_handoff_client_logged := false
var _smoke_ready_generation_logged := 0
var _smoke_snapshot_generation_logged := 0
var _dedicated_boot_requested := false
var _is_hosting_player := false
var _reconnect_token := ""
var _last_join_code := ""
var _last_steam_lobby_id := 0
var _last_join_name := ""
var _last_deck_cards: Array = []
var _last_deck_name := ""
var _last_assigned_player_id := 0
var _reconnect_allowed := false
var _reconnect_deadline_msec := 0
var _disconnected_players: Dictionary = {}
var _waiting_for_reconnect := false
var _rematch_votes: Dictionary = {}
var _paused_turn_timer_for_reconnect := false
var _online_match_repository := OnlineMatchRepository.new()
var _restored_server_payload: Dictionary = {}
var _server_event_log: Array[Dictionary] = []
var _is_steam_transport := false
var _steam_lobby_id := 0
var _steam_peer: SteamP2PPeer = null
var _pending_steam_host := false
var _pending_steam_join := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_multiplayer_signals()
	_bind_steam_signals()
	var arguments := _parse_user_arguments(OS.get_cmdline_user_args())
	_smoke_online_flow = bool(arguments.get("smoke-online-flow", false))
	_smoke_server_restart = bool(arguments.get("smoke-server-restart", false))
	if bool(arguments.get("server", false)) or OS.has_feature("dedicated_server"):
		_dedicated_boot_requested = true
		_smoke_server = bool(arguments.get("smoke-server", false))
		var public_ip := str(arguments.get("public-ip", "")).strip_edges()
		var port := int(arguments.get("port", DEFAULT_PORT))
		var secret := int(arguments.get("secret", 0))
		var dedicated_ruleset := _parse_ruleset_argument(arguments.get("ruleset", "siege"))
		call_deferred("start_dedicated_server", public_ip, port, secret, dedicated_ruleset)
	elif bool(arguments.get("smoke-host", false)):
		_smoke_server = true
		_smoke_host = true
		var public_ip := str(arguments.get("public-ip", "127.0.0.1")).strip_edges()
		var port := int(arguments.get("port", DEFAULT_PORT))
		var secret := int(arguments.get("secret", 0))
		var host_name := str(arguments.get("name", "Host Commander"))
		var hosted_ruleset := _parse_ruleset_argument(arguments.get("ruleset", "siege"))
		var hosted_match_name := str(arguments.get("match-name", ""))
		var hosted_card_pool := _parse_card_pool_argument(arguments.get("card-pool", "deck"))
		var hosted_turn_duration := float(arguments.get("turn-duration", GameRules.TURN_DURATION_SECONDS))
		var hosted_auto_attack := _parse_bool_argument(arguments.get("auto-attack", true), true)
		call_deferred(
			"start_hosted_room",
			public_ip,
			host_name,
			port,
			secret,
			hosted_ruleset,
			hosted_match_name,
			hosted_card_pool,
			hosted_turn_duration,
			hosted_auto_attack
		)
	elif bool(arguments.get("smoke-client", false)):
		_smoke_client = true
		var code := str(arguments.get("invite", ""))
		var client_name := str(arguments.get("name", "SmokeClient"))
		call_deferred("join_with_invite", code, client_name)


func _process(delta: float) -> void:
	if _is_server:
		_expire_disconnected_players()
	if not _is_server or not _match_started or not is_instance_valid(_battlefield):
		return
	if _smoke_host:
		_drive_smoke_host()

	if _snapshot_dirty and not _server_action_busy:
		_broadcast_full_state()

	_clock_sync_elapsed += delta
	if _clock_sync_elapsed < CLOCK_SYNC_INTERVAL:
		return
	_clock_sync_elapsed = 0.0
	_broadcast_clock()


func start_dedicated_server(
	public_ip: String,
	port: int = DEFAULT_PORT,
	secret: int = 0,
	match_ruleset: int = MatchSetup.Ruleset.SIEGE
) -> Error:
	if state != NetworkState.OFFLINE:
		return ERR_ALREADY_IN_USE
	if INVITE_CODE.decode(INVITE_CODE.encode_ipv4(public_ip, port, maxi(1, secret))).get("success", false) != true:
		_set_status("Geçerli bir --public-ip IPv4 adresi gerekli.", true)
		return ERR_INVALID_PARAMETER
	if port < 1 or port > 65535:
		_set_status("Sunucu portu 1-65535 arasında olmalı.", true)
		return ERR_INVALID_PARAMETER

	_is_server = true
	_is_hosting_player = false
	_set_room_settings(match_ruleset)
	_public_ip = public_ip
	_server_port = port
	_online_match_repository.configure_port(_server_port)
	var persisted := _online_match_repository.load_match()
	_restored_server_payload.clear()
	if bool(persisted.get("success", false)):
		var persisted_payload := persisted.get("payload", {}) as Dictionary
		var persisted_secret := int(persisted_payload.get("invite_secret", 0))
		if (
			int(persisted_payload.get("server_port", _server_port)) == _server_port
			and str(persisted_payload.get("public_ip", _public_ip)) == _public_ip
			and (secret <= 0 or secret == persisted_secret)
		):
			_restored_server_payload = persisted_payload.duplicate(true)
	_invite_secret = (
		int(_restored_server_payload.get("invite_secret", 0))
		if not _restored_server_payload.is_empty()
		else secret if secret > 0 else _generate_invite_secret()
	)
	_invite_code = INVITE_CODE.encode_ipv4(_public_ip, _server_port, _invite_secret)
	_configure_authentication()

	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("0.0.0.0")
	var create_error := peer.create_server(_server_port, MAX_PLAYERS)
	if create_error != OK:
		_is_server = false
		_set_status("Dedicated sunucu açılamadı: %s" % error_string(create_error), true)
		return create_error

	multiplayer.multiplayer_peer = peer
	state = NetworkState.STARTING if not _restored_server_payload.is_empty() else NetworkState.LOBBY
	_set_status(
		"Dedicated aktif maç snapshot'ı geri yükleniyor."
		if not _restored_server_payload.is_empty()
		else "Dedicated %s sunucusu hazır; iki oyuncu bekleniyor." % get_room_ruleset_name()
	)
	print("DARWINE_SERVER_READY udp=%d" % _server_port)
	print("DARWINE_INVITE_CODE=%s" % _invite_code)
	print("Davet kodu: %s" % _invite_code)
	if not _restored_server_payload.is_empty():
		_restore_dedicated_match_from_disk()
	elif get_tree().current_scene == null or get_tree().current_scene.scene_file_path != SERVER_LOBBY_SCENE:
		get_tree().change_scene_to_file(SERVER_LOBBY_SCENE)
	return OK


func start_hosted_room(
	public_ip: String,
	player_name: String,
	port: int = DEFAULT_PORT,
	secret: int = 0,
	match_ruleset: int = MatchSetup.Ruleset.SIEGE,
	match_name: String = "",
	card_pool_mode: int = MatchSetup.CardPoolMode.DECK,
	turn_duration_seconds: float = GameRules.TURN_DURATION_SECONDS,
	auto_attack_allowed: bool = true
) -> Error:
	if state != NetworkState.OFFLINE:
		return ERR_ALREADY_IN_USE
	var normalized_ip := public_ip.strip_edges()
	if INVITE_CODE.decode(INVITE_CODE.encode_ipv4(normalized_ip, port, maxi(1, secret))).get("success", false) != true:
		_set_status("Oda kurmak için geçerli bir IPv4 adresi gerekli.", true)
		return ERR_INVALID_PARAMETER
	if port < 1 or port > 65535:
		_set_status("Sunucu portu 1-65535 arasında olmalı.", true)
		return ERR_INVALID_PARAMETER

	_is_server = true
	_is_hosting_player = true
	_set_room_settings(
		match_ruleset,
		match_name,
		card_pool_mode,
		turn_duration_seconds,
		auto_attack_allowed
	)
	_intentional_disconnect = false
	_public_ip = normalized_ip
	_server_port = port
	_invite_secret = secret if secret > 0 else _generate_invite_secret()
	_invite_code = INVITE_CODE.encode_ipv4(_public_ip, _server_port, _invite_secret)
	_player_name = _sanitize_player_name(player_name)
	local_player_id = 1
	_reconnect_token = "host-%d" % _invite_secret
	_configure_authentication()

	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("0.0.0.0")
	var create_error := peer.create_server(_server_port, MAX_PLAYERS)
	if create_error != OK:
		_is_server = false
		_is_hosting_player = false
		_set_status("Oda açılamadı: %s" % error_string(create_error), true)
		return create_error

	multiplayer.multiplayer_peer = peer
	state = NetworkState.LOBBY
	var deck_payload := _get_local_deck_payload()
	_players[1] = {
		"peer_id": 1,
		"name": _player_name,
		"token": _reconnect_token,
		"deck_name": str(deck_payload.get("deck_name", "")),
		"deck_cards": (deck_payload.get("deck_cards", []) as Array).duplicate(true),
		"connected": true,
		"local_host": true,
	}
	_set_status("%s odası hazır; davet kodunu rakibinle paylaş." % get_room_ruleset_name())
	print("DARWINE_HOST_READY udp=%d" % _server_port)
	print("DARWINE_HOST_INVITE_CODE=%s" % _invite_code)
	_broadcast_lobby_state()
	room_hosted.emit(_invite_code)
	return OK


func is_steam_available() -> bool:
	var steam_manager := _get_steam_manager()
	return steam_manager != null and bool(steam_manager.get("is_available"))


func is_using_steam_transport() -> bool:
	return _is_steam_transport


func get_steam_lobby_id() -> int:
	return _steam_lobby_id


func request_steam_lobbies() -> Error:
	var steam_manager := _get_steam_manager()
	if steam_manager == null:
		steam_lobbies_changed.emit([])
		return ERR_UNAVAILABLE
	return int(steam_manager.call("request_lobby_list")) as Error


func invite_steam_friends() -> Error:
	var steam_manager := _get_steam_manager()
	if steam_manager == null or not _is_steam_transport or _steam_lobby_id <= 0:
		return ERR_UNAVAILABLE
	return int(steam_manager.call("invite_friends")) as Error


func start_steam_hosted_room(
	player_name: String,
	match_ruleset: int = MatchSetup.Ruleset.SIEGE,
	match_name: String = "",
	card_pool_mode: int = MatchSetup.CardPoolMode.DECK,
	turn_duration_seconds: float = GameRules.TURN_DURATION_SECONDS,
	auto_attack_allowed: bool = true
) -> Error:
	if state != NetworkState.OFFLINE:
		return ERR_ALREADY_IN_USE
	var steam_manager := _get_steam_manager()
	if steam_manager == null or not bool(steam_manager.get("is_available")):
		_set_status("Steam istemcisi bağlı olmadığı için P2P odası açılamadı.", true)
		return ERR_UNAVAILABLE
	_is_server = true
	_is_hosting_player = true
	_is_steam_transport = true
	_pending_steam_host = true
	_pending_steam_join = false
	_intentional_disconnect = false
	_set_room_settings(
		match_ruleset,
		match_name,
		card_pool_mode,
		turn_duration_seconds,
		auto_attack_allowed
	)
	_player_name = _sanitize_player_name(
		player_name if not player_name.strip_edges().is_empty() else str(steam_manager.call("get_persona_name"))
	)
	local_player_id = 1
	_reconnect_token = "steam-host-%s" % str(steam_manager.call("get_account_id"))
	state = NetworkState.CONNECTING
	var create_error := int(steam_manager.call("create_lobby", get_room_settings())) as Error
	if create_error != OK:
		_reset_network_state(false)
		return create_error
	_set_status("Steam P2P odası hazırlanıyor…")
	return OK


func join_steam_lobby(lobby_id: int, player_name: String) -> Error:
	if lobby_id <= 0:
		return ERR_INVALID_PARAMETER
	if state != NetworkState.OFFLINE:
		leave_network(false)
	_reconnect_token = _generate_reconnect_token()
	_reconnect_allowed = false
	_last_assigned_player_id = 0
	var deck_payload := _get_local_deck_payload()
	_last_deck_cards = (deck_payload.get("deck_cards", []) as Array).duplicate(true)
	_last_deck_name = str(deck_payload.get("deck_name", ""))
	return _connect_with_steam_lobby(lobby_id, player_name, false)


func join_with_invite(raw_code: String, player_name: String) -> Error:
	if state != NetworkState.OFFLINE:
		leave_network(false)
	_reconnect_token = _generate_reconnect_token()
	_reconnect_allowed = false
	_last_assigned_player_id = 0
	var deck_payload := _get_local_deck_payload()
	_last_deck_cards = (deck_payload.get("deck_cards", []) as Array).duplicate(true)
	_last_deck_name = str(deck_payload.get("deck_name", ""))
	return _connect_with_invite(raw_code, player_name, false)


func reconnect_last_session() -> Error:
	if not can_reconnect():
		_set_status("Yeniden bağlanma süresi doldu veya kayıtlı maç yok.", true)
		return ERR_UNAVAILABLE
	if state != NetworkState.OFFLINE:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_reset_client_runtime(true)
	if _last_steam_lobby_id > 0:
		return _connect_with_steam_lobby(_last_steam_lobby_id, _last_join_name, true)
	return _connect_with_invite(_last_join_code, _last_join_name, true)


func can_reconnect() -> bool:
	return (
		_reconnect_allowed
		and (not _last_join_code.is_empty() or _last_steam_lobby_id > 0)
		and not _reconnect_token.is_empty()
		and Time.get_ticks_msec() < _reconnect_deadline_msec
	)


func _reconnect_descriptor() -> String:
	return "STEAM:%d" % _last_steam_lobby_id if _last_steam_lobby_id > 0 else _last_join_code


func get_reconnect_descriptor() -> String:
	return _reconnect_descriptor()


func get_reconnect_seconds_remaining() -> int:
	if not can_reconnect():
		return 0
	return maxi(0, int(ceil(float(_reconnect_deadline_msec - Time.get_ticks_msec()) / 1000.0)))


func get_suggested_host_ipv4() -> String:
	for address_variant in IP.get_local_addresses():
		var address := str(address_variant)
		if ":" in address or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.begins_with("10.") or address.begins_with("192.168.") or address.begins_with("172."):
			return address
	return "127.0.0.1"


func _connect_with_steam_lobby(lobby_id: int, player_name: String, reconnecting: bool) -> Error:
	var steam_manager := _get_steam_manager()
	if steam_manager == null or not bool(steam_manager.get("is_available")):
		_set_status("Steam istemcisi bağlı olmadığı için P2P lobisine katılınamadı.", true)
		return ERR_UNAVAILABLE
	var current_lobby_id := int(steam_manager.get("current_lobby_id"))
	if current_lobby_id > 0 and current_lobby_id != lobby_id:
		steam_manager.call("leave_lobby")
	_is_server = false
	_is_hosting_player = false
	_is_steam_transport = true
	_pending_steam_host = false
	_pending_steam_join = true
	_intentional_disconnect = false
	_player_name = _sanitize_player_name(
		player_name if not player_name.strip_edges().is_empty() else str(steam_manager.call("get_persona_name"))
	)
	_last_join_name = _player_name
	_last_steam_lobby_id = lobby_id
	_steam_lobby_id = lobby_id
	state = NetworkState.RECONNECTING if reconnecting else NetworkState.CONNECTING
	if current_lobby_id == lobby_id:
		call_deferred(
			"_on_steam_lobby_joined",
			lobby_id,
			int(steam_manager.get("current_lobby_owner_id")),
			steam_manager.call("get_lobby_metadata", lobby_id)
		)
		_set_status("Steam P2P oturumu yeniden kuruluyor…")
		return OK
	var join_error := int(steam_manager.call("join_lobby", lobby_id)) as Error
	if join_error != OK:
		_reset_network_state(reconnecting)
		return join_error
	_set_status("Steam maçına yeniden bağlanılıyor…" if reconnecting else "Steam P2P lobisine katılınıyor…")
	return OK


func _connect_with_invite(raw_code: String, player_name: String, reconnecting: bool) -> Error:

	var decoded: Dictionary = INVITE_CODE.decode(raw_code)
	if not bool(decoded.get("success", false)):
		_set_status(str(decoded.get("error", "Davet kodu geçersiz.")), true)
		return ERR_INVALID_DATA

	_is_server = false
	_is_hosting_player = false
	_is_steam_transport = false
	_intentional_disconnect = false
	_player_name = _sanitize_player_name(player_name)
	_invite_secret = int(decoded.get("secret", 0))
	_server_port = int(decoded.get("port", DEFAULT_PORT))
	_invite_code = str(decoded.get("code", ""))
	_last_join_code = _invite_code
	_last_join_name = _player_name
	_configure_authentication()

	var peer := ENetMultiplayerPeer.new()
	var create_error := peer.create_client(str(decoded.get("address", "")), _server_port)
	if create_error != OK:
		_set_status("Sunucu bağlantısı başlatılamadı: %s" % error_string(create_error), true)
		return create_error

	state = NetworkState.RECONNECTING if reconnecting else NetworkState.CONNECTING
	multiplayer.multiplayer_peer = peer
	_set_status("Maça yeniden bağlanılıyor…" if reconnecting else "Sunucuya bağlanılıyor…")
	return OK


func leave_network(return_to_menu: bool = true) -> void:
	_intentional_disconnect = true
	var was_steam_transport := _is_steam_transport
	if _is_server and multiplayer.multiplayer_peer:
		for peer_id_variant in _peer_to_player.keys():
			multiplayer.multiplayer_peer.disconnect_peer(int(peer_id_variant))
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if was_steam_transport:
		var steam_manager := _get_steam_manager()
		if steam_manager:
			steam_manager.call("leave_lobby")
	_reconnect_allowed = false
	_reconnect_deadline_msec = 0
	_reset_network_state(false)
	_set_status("Bağlantı kapatıldı.")
	if return_to_menu and get_tree().current_scene and get_tree().current_scene.scene_file_path != MAIN_MENU_SCENE:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func request_action(action: String, payload: Dictionary = {}) -> bool:
	if state != NetworkState.MATCH or not MatchSetup.is_multiplayer_player():
		return false
	if _action_pending or action.is_empty() or _waiting_for_reconnect:
		return false
	if _is_server and (not _is_hosting_player or local_player_id not in GameRules.PLAYER_IDS):
		return false
	_action_pending = true
	action_pending_changed.emit(true)
	if _is_server:
		call_deferred("_execute_local_host_action", action, payload.duplicate(true))
	else:
		_submit_action.rpc_id(1, action, payload)
	return true


func request_rematch() -> bool:
	if not MatchSetup.is_multiplayer_match() or not is_instance_valid(_battlefield):
		return false
	var game_manager := _battlefield.get("game_manager") as GameManager
	if not game_manager or game_manager.is_game_active:
		return false
	if _is_server:
		if not _is_hosting_player or local_player_id not in GameRules.PLAYER_IDS:
			return false
		_register_rematch_vote(local_player_id)
		return true
	if state != NetworkState.MATCH:
		return false
	_request_rematch_vote.rpc_id(1)
	return true


func is_match_waiting_for_reconnect() -> bool:
	return _waiting_for_reconnect or not _disconnected_players.is_empty()


func is_action_pending() -> bool:
	return _action_pending


func is_server() -> bool:
	return _is_server


func is_hosting_player() -> bool:
	return _is_server and _is_hosting_player


func is_dedicated_boot_requested() -> bool:
	return _dedicated_boot_requested


func is_client() -> bool:
	return not _is_server and state != NetworkState.OFFLINE


func get_invite_code() -> String:
	return _invite_code


func get_room_ruleset() -> int:
	return _room_ruleset


func get_room_ruleset_name() -> String:
	return "Hakimiyet" if _room_ruleset == MatchSetup.Ruleset.DOMINION else "Kuşatma"


func get_room_settings() -> Dictionary:
	return {
		"ruleset": _room_ruleset,
		"match_name": _room_match_name,
		"card_pool_mode": _room_card_pool_mode,
		"turn_duration_seconds": _room_turn_duration_seconds,
		"auto_attack_allowed": _room_auto_attack_allowed,
	}


func get_lobby_players() -> Dictionary:
	return _players.duplicate(true)


func notify_battlefield_ready(battlefield: Node) -> void:
	_battlefield = battlefield
	if _smoke_online_flow and _smoke_ready_generation_logged != _smoke_match_generation:
		_smoke_ready_generation_logged = _smoke_match_generation
		var ready_manager := _battlefield.get("game_manager") as GameManager
		if ready_manager:
			print("ONLINE_FLOW_BATTLEFIELD_READY role=%s generation=%d phase=%d active=%d started=%s" % [
				"host" if _is_server else "client",
				_smoke_match_generation,
				ready_manager.current_phase,
				ready_manager.active_player_id,
				ready_manager.is_match_started,
			])
	if _is_server:
		if not _restored_server_payload.is_empty() and not _disconnected_players.is_empty():
			var restored_manager := _battlefield.get("game_manager") as GameManager
			if restored_manager:
				if _paused_turn_timer_for_reconnect:
					restored_manager.set("_turn_timer_running", false)
				else:
					_pause_authoritative_turn_timer()
			print("DARWINE_SERVER_SNAPSHOT_APPLIED match=%s revision=%d" % [_match_id, _snapshot_revision])
			_restored_server_payload.clear()
		_connect_server_state_signals()
		mark_state_dirty()
		_try_broadcast_initial_state()
	else:
		state = NetworkState.MATCH
		_client_scene_ready.rpc_id(1)
		if not _pending_snapshot.is_empty():
			_apply_snapshot_to_battlefield(_pending_snapshot)
			_pending_snapshot.clear()


func mark_state_dirty() -> void:
	if _is_server and _match_started:
		_snapshot_dirty = true


func _bind_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_authenticating.connect(_on_peer_authenticating)
	multiplayer.peer_authentication_failed.connect(_on_peer_authentication_failed)


func _bind_steam_signals() -> void:
	var steam_manager := _get_steam_manager()
	if steam_manager == null:
		return
	_connect_node_signal(steam_manager, "lobby_created", Callable(self, "_on_steam_lobby_created"))
	_connect_node_signal(steam_manager, "lobby_joined", Callable(self, "_on_steam_lobby_joined"))
	_connect_node_signal(steam_manager, "lobby_members_changed", Callable(self, "_on_steam_lobby_members_changed"))
	_connect_node_signal(steam_manager, "lobby_list_received", Callable(self, "_on_steam_lobby_list_received"))
	_connect_node_signal(steam_manager, "join_requested", Callable(self, "_on_steam_join_requested"))
	_connect_node_signal(steam_manager, "p2p_session_failed", Callable(self, "_on_steam_p2p_session_failed"))


func _connect_node_signal(node: Node, signal_name: StringName, callback: Callable) -> void:
	if node.has_signal(signal_name) and not node.is_connected(signal_name, callback):
		node.connect(signal_name, callback)


func _get_steam_manager() -> Node:
	return get_node_or_null("/root/SteamManager")


func _on_steam_lobby_created(lobby_id: int) -> void:
	if _pending_steam_host and lobby_id <= 0:
		_fail_steam_connection("Steam lobisi oluşturulamadı.")
		return
	if _pending_steam_host and lobby_id > 0:
		_steam_lobby_id = lobby_id
		_last_steam_lobby_id = lobby_id
		_set_status("Steam lobisi oluşturuldu; P2P taşıması hazırlanıyor…")


func _on_steam_lobby_joined(lobby_id: int, owner_steam_id: int, metadata: Dictionary) -> void:
	if not _is_steam_transport:
		return
	if lobby_id <= 0:
		_fail_steam_connection("Steam lobisine girilemedi.")
		return
	var steam_manager := _get_steam_manager()
	if steam_manager == null:
		_fail_steam_connection("Steam servis yöneticisi bulunamadı.")
		return
	var local_steam_id := int(steam_manager.get("steam_id"))
	if local_steam_id <= 0 or owner_steam_id <= 0:
		_fail_steam_connection("Steam lobisi geçerli oyuncu kimlikleri döndürmedi.")
		return
	if str(metadata.get("darwine_game", "")) != "darwine" or int(metadata.get("protocol", 0)) != INVITE_CODE.PROTOCOL_VERSION:
		_fail_steam_connection("Steam lobisinin Darwine protokolü uyumsuz.")
		return
	_steam_lobby_id = lobby_id
	_last_steam_lobby_id = lobby_id
	_invite_secret = int(metadata.get("auth_secret", 0))
	if _invite_secret <= 0:
		_fail_steam_connection("Steam lobisi güvenli oturum anahtarı sağlamadı.")
		return

	if owner_steam_id == local_steam_id:
		if _pending_steam_join:
			_fail_steam_connection("Steam lobi sahibi ayrıldı; bu sürüm host migration desteklemiyor.")
			return
		if not _pending_steam_host or is_instance_valid(_steam_peer):
			return
		_steam_peer = STEAM_P2P_PEER.new()
		var host_error := _steam_peer.setup_host(
			steam_manager.call("get_steam_singleton"), lobby_id, local_steam_id
		)
		if host_error != OK:
			_fail_steam_connection("Steam P2P sunucu taşıması başlatılamadı: %s" % error_string(host_error))
			return
		_steam_peer.transport_error.connect(_on_steam_transport_error)
		_configure_authentication()
		multiplayer.multiplayer_peer = _steam_peer
		state = NetworkState.LOBBY
		_pending_steam_host = false
		var deck_payload := _get_local_deck_payload()
		_players[1] = {
			"peer_id": 1,
			"name": _player_name,
			"token": _reconnect_token,
			"deck_name": str(deck_payload.get("deck_name", "")),
			"deck_cards": (deck_payload.get("deck_cards", []) as Array).duplicate(true),
			"connected": true,
			"local_host": true,
			"steam_id": local_steam_id,
		}
		_sync_steam_lobby_members(steam_manager.get("current_lobby_members") as Array)
		steam_manager.call("set_rich_presence_lobby")
		_set_status("%s Steam P2P odası hazır; arkadaşlarını davet edebilirsin." % get_room_ruleset_name())
		_broadcast_lobby_state()
		steam_room_hosted.emit(lobby_id)
		return

	if not _pending_steam_join or is_instance_valid(_steam_peer):
		return
	_apply_steam_lobby_metadata(metadata)
	_steam_peer = STEAM_P2P_PEER.new()
	var client_error := _steam_peer.setup_client(
		steam_manager.call("get_steam_singleton"), lobby_id, local_steam_id, owner_steam_id
	)
	if client_error != OK:
		_fail_steam_connection("Steam P2P istemci taşıması başlatılamadı: %s" % error_string(client_error))
		return
	_steam_peer.transport_error.connect(_on_steam_transport_error)
	_configure_authentication()
	multiplayer.multiplayer_peer = _steam_peer
	_pending_steam_join = false
	steam_manager.call("set_rich_presence_lobby")
	_set_status("Steam P2P bağlantısı kuruluyor…")


func _on_steam_lobby_members_changed(lobby_id: int, member_ids: Array[int]) -> void:
	if not _is_steam_transport or lobby_id != _steam_lobby_id:
		return
	if _is_server:
		_sync_steam_lobby_members(member_ids)
	elif is_instance_valid(_steam_peer):
		var steam_manager := _get_steam_manager()
		if (
			steam_manager
			and int(steam_manager.get("current_lobby_owner_id")) == int(steam_manager.get("steam_id"))
		):
			_fail_steam_connection("Steam lobi sahibi ayrıldı; maç sona erdi. Host migration desteklenmiyor.")
			return
		var owner_steam_id := _steam_peer.get_steam_id_for_peer(1)
		if owner_steam_id > 0 and owner_steam_id not in member_ids:
			_steam_peer.notify_session_failed(owner_steam_id, "Steam lobi sahibi oturumdan ayrıldı.")


func _sync_steam_lobby_members(member_ids: Array) -> void:
	if not _is_server or not is_instance_valid(_steam_peer):
		return
	var steam_manager := _get_steam_manager()
	if steam_manager == null:
		return
	var local_steam_id := int(steam_manager.get("steam_id"))
	for member_id_variant in member_ids:
		var member_id := int(member_id_variant)
		if member_id > 0 and member_id != local_steam_id:
			_steam_peer.add_lobby_member(member_id)
	var connected_steam_id := _steam_peer.get_steam_id_for_peer(SteamP2PPeer.CLIENT_PEER_ID)
	if connected_steam_id > 0 and connected_steam_id not in member_ids:
		_steam_peer.remove_lobby_member(connected_steam_id)


func _on_steam_lobby_list_received(lobbies: Array[Dictionary]) -> void:
	steam_lobbies_changed.emit(lobbies.duplicate(true))


func _on_steam_join_requested(lobby_id: int, _inviter_steam_id: int) -> void:
	if lobby_id <= 0:
		return
	var steam_manager := _get_steam_manager()
	var suggested_name := str(steam_manager.call("get_persona_name")) if steam_manager else "Steam Komutanı"
	var inviter_name := (
		str(steam_manager.call("get_friend_persona_name", _inviter_steam_id))
		if steam_manager and _inviter_steam_id > 0
		else "Steam arkadaşın"
	)
	var join_error := join_steam_lobby(lobby_id, suggested_name)
	if join_error != OK:
		_set_status("%s tarafından gönderilen Steam davetine katılınamadı." % inviter_name, true)
		return
	_set_status("%s daveti kabul edildi; Steam lobisine katılınıyor…" % inviter_name)
	call_deferred("_show_main_menu_for_steam_join")


func _show_main_menu_for_steam_join() -> void:
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.scene_file_path == MAIN_MENU_SCENE:
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_steam_p2p_session_failed(remote_steam_id: int, message: String) -> void:
	if is_instance_valid(_steam_peer):
		_steam_peer.notify_session_failed(remote_steam_id, message)


func _on_steam_transport_error(message: String) -> void:
	_set_status(message, true)


func _apply_steam_lobby_metadata(metadata: Dictionary) -> void:
	_set_room_settings(
		int(metadata.get("ruleset", MatchSetup.Ruleset.SIEGE)),
		str(metadata.get("match_name", "")),
		int(metadata.get("card_pool_mode", MatchSetup.CardPoolMode.DECK)),
		float(metadata.get("turn_duration_seconds", GameRules.TURN_DURATION_SECONDS)),
		str(metadata.get("auto_attack_allowed", "1")) == "1"
	)


func _fail_steam_connection(message: String) -> void:
	var steam_manager := _get_steam_manager()
	if steam_manager:
		steam_manager.call("leave_lobby")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reset_network_state(false)
	_set_status(message, true)
	connection_closed.emit(message)


func _configure_authentication() -> void:
	multiplayer.auth_timeout = AUTH_TIMEOUT_SECONDS
	multiplayer.auth_callback = Callable(self, "_on_auth_data")


func _on_peer_authenticating(peer_id: int) -> void:
	if _is_server or peer_id != 1:
		return
	var auth_payload := JSON.stringify({
		"protocol": INVITE_CODE.PROTOCOL_VERSION,
		"secret": _invite_secret,
		"name": _player_name,
		"reconnect_token": _reconnect_token,
		"deck_name": _last_deck_name,
		"deck_cards": _last_deck_cards,
	}).to_utf8_buffer()
	multiplayer.send_auth(1, auth_payload)
	# The client has no additional server credential to validate; the invitation
	# secret is verified on the authoritative side before peer_connected emits.
	multiplayer.complete_auth(1)


func _on_auth_data(peer_id: int, raw_data: PackedByteArray) -> void:
	if not _is_server:
		return
	if raw_data.is_empty() or raw_data.size() > MAX_AUTH_BYTES:
		_reject_auth(peer_id, "authentication payload size")
		return
	var parsed: Variant = JSON.parse_string(raw_data.get_string_from_utf8())
	if not parsed is Dictionary:
		_reject_auth(peer_id, "invalid authentication payload")
		return
	var auth := parsed as Dictionary
	if int(auth.get("protocol", 0)) != INVITE_CODE.PROTOCOL_VERSION:
		_reject_auth(peer_id, "protocol mismatch")
		return
	if int(auth.get("secret", 0)) != _invite_secret:
		_reject_auth(peer_id, "invalid invite secret")
		return
	var token := str(auth.get("reconnect_token", "")).strip_edges().left(96)
	if token.is_empty():
		_reject_auth(peer_id, "missing reconnect token")
		return
	var deck_cards_variant: Variant = auth.get("deck_cards", [])
	if not _validate_network_deck(deck_cards_variant):
		_reject_auth(peer_id, "invalid deck")
		return
	_pending_auth[peer_id] = {
		"name": _sanitize_player_name(str(auth.get("name", "Komutan"))),
		"token": token,
		"deck_name": str(auth.get("deck_name", "İsimsiz Deste")).strip_edges().left(32),
		"deck_cards": (deck_cards_variant as Array).duplicate(true),
	}
	multiplayer.complete_auth(peer_id)


func _reject_auth(peer_id: int, reason: String) -> void:
	push_warning("Peer %d authentication rejected: %s" % [peer_id, reason])
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _on_peer_connected(peer_id: int) -> void:
	if not _is_server:
		return
	var auth_variant: Variant = _pending_auth.get(peer_id, {})
	if not auth_variant is Dictionary:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	var auth := auth_variant as Dictionary
	var reconnect_player_id := _find_reconnect_player_id(str(auth.get("token", "")))
	if _match_started:
		if reconnect_player_id == 0:
			_pending_auth.erase(peer_id)
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
			return
		_reconnect_player(peer_id, reconnect_player_id, auth)
		return
	if _peer_to_player.size() >= _required_remote_player_count():
		_pending_auth.erase(peer_id)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	var player_id := _next_available_player_id()
	if player_id == 0:
		_pending_auth.erase(peer_id)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	_peer_to_player[peer_id] = player_id
	_players[player_id] = {
		"peer_id": peer_id,
		"name": str(auth.get("name", "Komutan %d" % player_id)),
		"token": str(auth.get("token", "")),
		"deck_name": str(auth.get("deck_name", "İsimsiz Deste")),
		"deck_cards": (auth.get("deck_cards", []) as Array).duplicate(true),
		"connected": true,
		"local_host": false,
	}
	_pending_auth.erase(peer_id)
	print("Oyuncu katıldı: peer=%d player=%d name=%s" % [peer_id, player_id, _players[player_id]["name"]])
	_broadcast_lobby_state()
	if _players.size() == MAX_PLAYERS:
		call_deferred("_start_match")


func _on_peer_disconnected(peer_id: int) -> void:
	_pending_auth.erase(peer_id)
	if not _is_server:
		return
	var player_id := int(_peer_to_player.get(peer_id, 0))
	_peer_to_player.erase(peer_id)
	_ready_peers.erase(peer_id)
	print("Oyuncu ayrıldı: peer=%d player=%d" % [peer_id, player_id])
	if _match_started and not _intentional_disconnect and (_smoke_online_flow or not _smoke_server):
		_begin_reconnect_window(player_id)
	else:
		if player_id != 0:
			_players.erase(player_id)
		_broadcast_lobby_state()


func _on_connected_to_server() -> void:
	if _is_server:
		return
	var was_reconnecting := state == NetworkState.RECONNECTING
	state = NetworkState.LOBBY
	if _is_steam_transport:
		var steam_manager := _get_steam_manager()
		if steam_manager:
			steam_manager.call("set_rich_presence_lobby")
	_set_status("Sunucuya yeniden bağlandı; savaş alanı geri yükleniyor…" if was_reconnecting else "Bağlandı; ikinci oyuncu bekleniyor.")


func _on_connection_failed() -> void:
	if _is_server:
		return
	var was_steam_transport := _is_steam_transport
	var preserve_reconnect := can_reconnect()
	_reset_client_runtime(preserve_reconnect)
	_set_status(
		"Steam P2P eşine ulaşılamadı. Steam bağlantısını ve lobi üyeliğini kontrol et."
		if was_steam_transport
		else "Sunucuya ulaşılamadı. Kodun ve UDP portunun açık olduğunu kontrol et.",
		true
	)
	connection_closed.emit(last_status)
	if preserve_reconnect:
		reconnect_available.emit(_reconnect_descriptor(), _last_join_name, get_reconnect_seconds_remaining())


func _on_server_disconnected() -> void:
	if _is_server or _intentional_disconnect:
		return
	var can_offer_reconnect := (
		_last_assigned_player_id in GameRules.PLAYER_IDS
		and (not _last_join_code.is_empty() or _last_steam_lobby_id > 0)
	)
	if can_offer_reconnect:
		_reconnect_allowed = true
		_reconnect_deadline_msec = Time.get_ticks_msec() + (RECONNECT_GRACE_SECONDS * 1000)
	_reset_client_runtime(can_offer_reconnect)
	_set_status(
		"Bağlantı koptu. %d saniye içinde maça yeniden bağlanabilirsin." % RECONNECT_GRACE_SECONDS
		if can_offer_reconnect else "Sunucu bağlantısı kesildi.",
		true
	)
	connection_closed.emit(last_status)
	if can_offer_reconnect:
		reconnect_available.emit(_reconnect_descriptor(), _last_join_name, RECONNECT_GRACE_SECONDS)
		if _smoke_server_restart:
			_smoke_restart_disconnected = true
			call_deferred("_retry_smoke_server_restart_connection")
	if get_tree().current_scene and get_tree().current_scene.scene_file_path != MAIN_MENU_SCENE:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _retry_smoke_server_restart_connection() -> void:
	if _smoke_restart_retry_running or not _smoke_server_restart:
		return
	_smoke_restart_retry_running = true
	var logged_retry := false
	while can_reconnect() and not _smoke_restart_recovered:
		if state == NetworkState.OFFLINE:
			if not logged_retry:
				logged_retry = true
				print("SERVER_RESTART_CLIENT_RETRY player=%d" % _last_assigned_player_id)
			reconnect_last_session()
		await get_tree().create_timer(0.5).timeout
	_smoke_restart_retry_running = false


func _on_peer_authentication_failed(peer_id: int) -> void:
	if _is_server:
		push_warning("Peer %d authentication timed out or failed." % peer_id)
		return
	_set_status("Davet kodu sunucu tarafından reddedildi.", true)


func _start_match() -> void:
	if not _is_server or _match_started or _players.size() != MAX_PLAYERS or not _all_players_connected():
		return
	_match_started = true
	if _smoke_online_flow:
		_smoke_match_generation = 1
	state = NetworkState.STARTING
	_match_seed = _generate_match_seed()
	_match_id = _generate_match_id(_match_seed)
	_session_key = _generate_session_key()
	_snapshot_revision = 0
	_server_event_log.clear()
	_append_server_event("match_started", get_room_settings())
	_configure_authoritative_match_setup()
	if _is_steam_transport:
		var steam_manager := _get_steam_manager()
		if steam_manager:
			steam_manager.call("update_lobby_state", "match")
			steam_manager.call("set_rich_presence_match", get_room_ruleset_name(), _room_match_name)
	_set_status("İki oyuncu hazır; maç başlatılıyor.")
	for peer_id_variant in _peer_to_player.keys():
		var peer_id := int(peer_id_variant)
		_begin_match.rpc_id(
			peer_id,
			_match_seed,
			int(_peer_to_player[peer_id]),
			_match_id,
			_session_key,
			_room_ruleset,
			get_room_settings()
		)
	if _is_hosting_player:
		match_starting.emit(local_player_id)
	var change_error := get_tree().change_scene_to_file(BATTLEFIELD_SCENE)
	if change_error != OK:
		push_error("Dedicated battlefield could not load: %s" % error_string(change_error))


@rpc("authority", "call_remote", "reliable", 0)
func _begin_match(
	seed: int,
	assigned_player_id: int,
	authoritative_match_id: String,
	session_key: String,
	match_ruleset: int,
	room_settings: Dictionary = {}
) -> void:
	if _is_server or assigned_player_id not in GameRules.PLAYER_IDS:
		return
	if authoritative_match_id.strip_edges().is_empty() or session_key.strip_edges().length() < 24:
		_set_status("Sunucu geçerli maç kimliği göndermedi.", true)
		return
	var previous_seed := _match_seed
	var is_new_match := (
		previous_seed == 0
		or previous_seed != seed
		or _expected_match_id != authoritative_match_id
		or _expected_session_key != session_key
	)
	if _smoke_online_flow:
		if is_new_match:
			_smoke_match_generation += 1
		elif _smoke_disconnect_started:
			_smoke_reconnect_restored = true
	if is_new_match:
		_last_snapshot_revision = -1
		_pending_snapshot.clear()
		_action_pending = false
		action_pending_changed.emit(false)
	_match_seed = seed
	_expected_match_id = authoritative_match_id
	_expected_session_key = session_key
	_match_started = true
	local_player_id = assigned_player_id
	_last_assigned_player_id = assigned_player_id
	_reconnect_allowed = false
	_reconnect_deadline_msec = 0
	_waiting_for_reconnect = false
	_rematch_votes.clear()
	_room_ruleset = _normalize_ruleset(match_ruleset)
	_apply_room_settings_payload(room_settings)
	state = NetworkState.STARTING
	MatchSetup.configure_multiplayer_client(seed, assigned_player_id, authoritative_match_id, _room_ruleset)
	_apply_room_settings_to_match_setup()
	match_starting.emit(assigned_player_id)
	_set_status("Oyuncu %d olarak savaş alanına giriliyor…" % assigned_player_id)
	var change_error := get_tree().change_scene_to_file(BATTLEFIELD_SCENE)
	if change_error != OK:
		_set_status("Savaş alanı yüklenemedi: %s" % error_string(change_error), true)


@rpc("any_peer", "call_remote", "reliable", 0)
func _client_scene_ready() -> void:
	if not _is_server or not _match_started:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not _peer_to_player.has(sender_id):
		return
	_ready_peers[sender_id] = true
	_try_broadcast_initial_state()
	if _smoke_online_flow and _smoke_reconnect_accepted and _disconnected_players.is_empty():
		_smoke_reconnect_peer_ready = true
		print("NETWORK_RECONNECT_SERVER_READY player=%d" % int(_peer_to_player.get(sender_id, 0)))
	if _smoke_server and _ready_peers.size() == _required_remote_player_count():
		print("NETWORK_SMOKE_SERVER_OK players=%d" % _ready_peers.size())
		if not _smoke_host:
			get_tree().create_timer(2.0).timeout.connect(func(): get_tree().quit(0))


func _try_broadcast_initial_state() -> void:
	if not _is_server or not _match_started or not is_instance_valid(_battlefield):
		return
	if _ready_peers.is_empty():
		return
	if _ready_peers.size() >= _required_remote_player_count() and _disconnected_players.is_empty():
		state = NetworkState.MATCH
	mark_state_dirty()
	_broadcast_full_state()


func _broadcast_lobby_state() -> void:
	if not _is_server:
		return
	var public_players := _public_player_dictionary()
	for peer_id_variant in _peer_to_player.keys():
		_receive_lobby_state.rpc_id(int(peer_id_variant), public_players, _room_ruleset, get_room_settings())
	lobby_changed.emit(public_players)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_lobby_state(
	public_players: Dictionary,
	match_ruleset: int,
	room_settings: Dictionary = {}
) -> void:
	if _is_server:
		return
	_players = public_players.duplicate(true)
	_room_ruleset = _normalize_ruleset(match_ruleset)
	_apply_room_settings_payload(room_settings)
	var waiting := maxi(0, MAX_PLAYERS - _players.size())
	_set_status("Lobi hazır; %d oyuncu daha bekleniyor." % waiting if waiting > 0 else "Rakip bulundu; maç başlıyor.")
	lobby_changed.emit(_players.duplicate(true))


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_action(action: String, payload: Dictionary) -> void:
	if not _is_server or state != NetworkState.MATCH:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var player_id := int(_peer_to_player.get(sender_id, 0))
	if player_id not in GameRules.PLAYER_IDS:
		return
	if not _disconnected_players.is_empty():
		_action_result.rpc_id(sender_id, false, "Rakibin yeniden bağlanması bekleniyor.")
		return
	if _server_action_busy or not is_instance_valid(_battlefield) or not _battlefield.has_method("execute_network_action"):
		_action_result.rpc_id(sender_id, false, "Sunucu önceki hamleyi çözüyor.")
		return

	_server_action_busy = true
	var result: Dictionary = await _battlefield.execute_network_action(player_id, action, payload)
	_server_action_busy = false
	var success := bool(result.get("success", false))
	var message := str(result.get("message", result.get("error", "")))
	if success:
		_append_server_event("action", {"player_id": player_id, "action": action})
		mark_state_dirty()
		# Keep the requester locked until its fresh authoritative snapshot has
		# arrived. Both RPCs use the same reliable channel, so this ordering also
		# closes the stale-state window between result and snapshot.
		_broadcast_full_state()
	_action_result.rpc_id(sender_id, success, message)


func _execute_local_host_action(action: String, payload: Dictionary) -> void:
	if (
		state != NetworkState.MATCH
		or not _is_server
		or not _is_hosting_player
		or local_player_id not in GameRules.PLAYER_IDS
	):
		_finish_local_action(false, "Çevrimiçi maç artık aktif değil.")
		return
	if not _disconnected_players.is_empty():
		_finish_local_action(false, "Rakibin yeniden bağlanması bekleniyor.")
		return
	if _server_action_busy or not is_instance_valid(_battlefield) or not _battlefield.has_method("execute_network_action"):
		_finish_local_action(false, "Sunucu önceki hamleyi çözüyor.")
		return

	_server_action_busy = true
	var result: Dictionary = await _battlefield.execute_network_action(local_player_id, action, payload)
	_server_action_busy = false
	var success := bool(result.get("success", false))
	var message := str(result.get("message", result.get("error", "")))
	if success:
		_append_server_event("action", {"player_id": local_player_id, "action": action})
		mark_state_dirty()
		_broadcast_full_state()
	_finish_local_action(success, message)


func _finish_local_action(success: bool, message: String) -> void:
	_action_pending = false
	action_pending_changed.emit(false)
	if is_instance_valid(_battlefield) and _battlefield.has_method("show_toast") and not message.is_empty():
		var color := Color(0.38, 0.90, 0.62) if success else Color(0.95, 0.38, 0.24)
		_battlefield.show_toast(message, color)
	elif not success:
		_set_status(message if not message.is_empty() else "Hamle sunucu tarafından reddedildi.", true)
	if _smoke_client and not _smoke_client_finished:
		call_deferred("_drive_smoke_client")


@rpc("authority", "call_remote", "reliable", 0)
func _action_result(success: bool, message: String) -> void:
	if _is_server:
		return
	_finish_local_action(success, message)


func _broadcast_full_state() -> void:
	if not _is_server or not is_instance_valid(_battlefield) or not _battlefield.has_method("build_network_snapshot"):
		return
	_snapshot_dirty = false
	_snapshot_revision += 1
	_persist_authoritative_match_snapshot()
	for peer_id_variant in _peer_to_player.keys():
		var peer_id := int(peer_id_variant)
		if not _ready_peers.has(peer_id):
			continue
		var player_id := int(_peer_to_player[peer_id])
		var snapshot: Dictionary = _battlefield.build_network_snapshot(player_id)
		snapshot["match_id"] = _match_id
		snapshot["session_key"] = _session_key
		snapshot["player_id"] = player_id
		snapshot["revision"] = _snapshot_revision
		_receive_snapshot.rpc_id(peer_id, snapshot)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_snapshot(snapshot: Dictionary) -> void:
	if _is_server:
		return
	if (
		_expected_match_id.is_empty()
		or _expected_session_key.is_empty()
		or str(snapshot.get("match_id", "")) != _expected_match_id
		or str(snapshot.get("session_key", "")) != _expected_session_key
		or int(snapshot.get("player_id", 0)) != local_player_id
		or int(snapshot.get("perspective_player_id", 0)) != local_player_id
	):
		push_warning("Eşleşmeyen çevrimiçi snapshot reddedildi.")
		return
	var revision := int(snapshot.get("revision", -1))
	if revision <= _last_snapshot_revision:
		return
	_last_snapshot_revision = revision
	if not is_instance_valid(_battlefield) or not _battlefield.has_method("apply_network_snapshot"):
		_pending_snapshot = snapshot.duplicate(true)
		return
	_apply_snapshot_to_battlefield(snapshot)


func _apply_snapshot_to_battlefield(snapshot: Dictionary) -> void:
	if not is_instance_valid(_battlefield):
		_pending_snapshot = snapshot.duplicate(true)
		return
	_battlefield.apply_network_snapshot(snapshot)
	state = NetworkState.MATCH
	if _smoke_online_flow and _smoke_snapshot_generation_logged != _smoke_match_generation:
		_smoke_snapshot_generation_logged = _smoke_match_generation
		var snapshot_manager := _battlefield.get("game_manager") as GameManager
		if snapshot_manager:
			print("ONLINE_FLOW_SNAPSHOT_READY generation=%d phase=%d active=%d started=%s game_active=%s ruleset=%s match_name=%s card_pool=%s turn_duration=%d auto_attack=%s" % [
				_smoke_match_generation,
				snapshot_manager.current_phase,
				snapshot_manager.active_player_id,
				snapshot_manager.is_match_started,
				snapshot_manager.is_game_active,
				MatchSetup.get_ruleset_name(),
				MatchSetup.match_name,
				"all_cards" if MatchSetup.uses_all_cards() else "deck",
				int(round(MatchSetup.turn_duration_seconds)),
				MatchSetup.auto_attack_allowed,
			])
	if _smoke_online_flow and _smoke_reconnect_restored:
		_smoke_reconnect_restored = false
		print("NETWORK_RECONNECT_CLIENT_READY player=%d" % local_player_id)
	if _smoke_server_restart and _smoke_restart_disconnected and not _smoke_restart_recovered:
		_smoke_restart_recovered = true
		_smoke_client_finished = true
		print("SERVER_RESTART_CLIENT_RECOVERED player=%d revision=%d ruleset=%s" % [local_player_id, _last_snapshot_revision, MatchSetup.get_ruleset_name()])
		get_tree().create_timer(0.75).timeout.connect(func(): get_tree().quit(0))
		return
	if _smoke_client and not _smoke_client_finished:
		call_deferred("_drive_smoke_client")


func _drive_smoke_client() -> void:
	if not _smoke_client or _smoke_client_finished or not is_instance_valid(_battlefield):
		return
	var game_manager := _battlefield.get("game_manager") as GameManager
	if not game_manager:
		return
	if _smoke_online_flow:
		_drive_smoke_online_client(game_manager)
		return
	if _smoke_server_restart and game_manager.is_match_started:
		if not _smoke_restart_initial_ready:
			_smoke_restart_initial_ready = true
			print("SERVER_RESTART_CLIENT_READY player=%d revision=%d ruleset=%s" % [local_player_id, _last_snapshot_revision, MatchSetup.get_ruleset_name()])
		return
	if (
		game_manager.current_phase == GameManager.TurnPhase.EFFECT_SELECTION
		and not game_manager.has_effect_selection(local_player_id)
		and not _action_pending
	):
		var effect_offer := game_manager.get_effect_offer(local_player_id)
		if not effect_offer.is_empty():
			request_action("effect_choice", {"card_id": effect_offer[0]})
		return
	if game_manager.is_match_started:
		_smoke_client_finished = true
		print("NETWORK_SMOKE_CLIENT_READY player=%d revision=%d ruleset=%s" % [local_player_id, _last_snapshot_revision, MatchSetup.get_ruleset_name()])
		get_tree().create_timer(0.35).timeout.connect(func(): get_tree().quit(0))
		return
	if (
		game_manager.current_phase == GameManager.TurnPhase.MULLIGAN
		and game_manager.active_player_id == local_player_id
		and not _action_pending
	):
		request_action("mulligan", {"card_ids": []})


func _drive_smoke_host() -> void:
	if not _smoke_host or not is_instance_valid(_battlefield):
		return
	var game_manager := _battlefield.get("game_manager") as GameManager
	if not game_manager:
		return
	if _smoke_online_flow:
		_drive_smoke_online_host(game_manager)
		return
	if (
		game_manager.current_phase == GameManager.TurnPhase.EFFECT_SELECTION
		and not game_manager.has_effect_selection(local_player_id)
	):
		var effect_offer := game_manager.get_effect_offer(local_player_id)
		if not effect_offer.is_empty():
			_battlefield.resolve_effect_card_choice_for_player(local_player_id, effect_offer[0], true)
		return
	if game_manager.is_match_started:
		if not _smoke_host_finished:
			_smoke_host_finished = true
			print("HOSTED_ROOM_MATCH_READY ruleset=%s" % MatchSetup.get_ruleset_name())
			get_tree().create_timer(2.0).timeout.connect(func(): get_tree().quit(0))
		return
	if game_manager.current_phase == GameManager.TurnPhase.MULLIGAN and game_manager.active_player_id == local_player_id:
		var no_cards: Array[BaseCard] = []
		_battlefield.resolve_mulligan_for_player(local_player_id, no_cards)


func _drive_smoke_online_client(game_manager: GameManager) -> void:
	if (
		game_manager.current_phase == GameManager.TurnPhase.EFFECT_SELECTION
		and not game_manager.has_effect_selection(local_player_id)
		and not _action_pending
	):
		var effect_offer := game_manager.get_effect_offer(local_player_id)
		if not effect_offer.is_empty() and request_action("effect_choice", {"card_id": effect_offer[0]}):
			print("ONLINE_FLOW_CLIENT_EFFECT_SELECTED generation=%d" % _smoke_match_generation)
		return
	if (
		game_manager.current_phase == GameManager.TurnPhase.MULLIGAN
		and game_manager.active_player_id == local_player_id
		and not _action_pending
	):
		if request_action("mulligan", {"card_ids": []}):
			print("ONLINE_FLOW_CLIENT_MULLIGAN generation=%d" % _smoke_match_generation)
		return
	if _smoke_match_generation >= 2 and game_manager.is_match_started and game_manager.is_game_active:
		_smoke_client_finished = true
		print("ONLINE_FLOW_REMATCH_CLIENT_READY generation=%d ruleset=%s match_name=%s card_pool=%s turn_duration=%d auto_attack=%s" % [
			_smoke_match_generation,
			MatchSetup.get_ruleset_name(),
			MatchSetup.match_name,
			"all_cards" if MatchSetup.uses_all_cards() else "deck",
			int(round(MatchSetup.turn_duration_seconds)),
			MatchSetup.auto_attack_allowed,
		])
		get_tree().create_timer(0.75).timeout.connect(func(): get_tree().quit(0))
		return
	if not game_manager.is_match_started:
		return
	if game_manager.is_game_active:
		if _smoke_match_generation == 1 and not _smoke_turn_handoff_client_logged:
			_drive_smoke_initial_turn(game_manager, false)
			if not _smoke_turn_handoff_client_logged:
				return
		if not _smoke_disconnect_started:
			_smoke_disconnect_started = true
			print("ONLINE_FLOW_INITIAL_CLIENT_READY")
			call_deferred("_simulate_smoke_transport_drop")
		return
	if not _smoke_rematch_vote_sent:
		_smoke_rematch_vote_sent = request_rematch()
		if _smoke_rematch_vote_sent:
			print("ONLINE_FLOW_REMATCH_CLIENT_VOTED")


func _simulate_smoke_transport_drop() -> void:
	if not _smoke_online_flow or _is_server or _smoke_client_finished:
		return
	_reconnect_allowed = true
	_reconnect_deadline_msec = Time.get_ticks_msec() + (RECONNECT_GRACE_SECONDS * 1000)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reset_client_runtime(true)
	print("NETWORK_RECONNECT_CLIENT_DROPPED")
	await get_tree().create_timer(0.8).timeout
	if can_reconnect():
		print("NETWORK_RECONNECT_CLIENT_ATTEMPT")
		reconnect_last_session()


func _drive_smoke_online_host(game_manager: GameManager) -> void:
	if (
		game_manager.current_phase == GameManager.TurnPhase.EFFECT_SELECTION
		and not game_manager.has_effect_selection(local_player_id)
		and not _action_pending
	):
		var effect_offer := game_manager.get_effect_offer(local_player_id)
		var effect_accepted := not effect_offer.is_empty() and request_action("effect_choice", {"card_id": effect_offer[0]})
		print("ONLINE_FLOW_HOST_EFFECT_SELECTED generation=%d accepted=%s" % [_smoke_match_generation, effect_accepted])
		return
	if (
		game_manager.current_phase == GameManager.TurnPhase.MULLIGAN
		and game_manager.active_player_id == local_player_id
		and not _action_pending
	):
		var mulligan_accepted := request_action("mulligan", {"card_ids": []})
		print("ONLINE_FLOW_HOST_MULLIGAN generation=%d accepted=%s" % [_smoke_match_generation, mulligan_accepted])
		return
	if _smoke_match_generation >= 2 and game_manager.is_match_started and game_manager.is_game_active:
		if not _smoke_host_finished:
			_smoke_host_finished = true
			print("ONLINE_FLOW_REMATCH_HOST_READY generation=%d ruleset=%s match_name=%s card_pool=%s turn_duration=%d auto_attack=%s" % [
				_smoke_match_generation,
				MatchSetup.get_ruleset_name(),
				MatchSetup.match_name,
				"all_cards" if MatchSetup.uses_all_cards() else "deck",
				int(round(MatchSetup.turn_duration_seconds)),
				MatchSetup.auto_attack_allowed,
			])
			get_tree().create_timer(1.5).timeout.connect(func(): get_tree().quit(0))
		return
	if game_manager.is_game_active:
		if _smoke_match_generation == 1 and not _smoke_turn_handoff_host_logged:
			_drive_smoke_initial_turn(game_manager, true)
			return
		if _smoke_reconnect_peer_ready and not _smoke_forced_game_over:
			_smoke_forced_game_over = true
			print("NETWORK_RECONNECT_HOST_CONFIRMED")
			game_manager.finish_game(local_player_id)
			mark_state_dirty()
			_broadcast_full_state()
		return
	if not _smoke_rematch_vote_sent:
		_smoke_rematch_vote_sent = request_rematch()
		if _smoke_rematch_vote_sent:
			print("ONLINE_FLOW_REMATCH_HOST_VOTED")


func _drive_smoke_initial_turn(game_manager: GameManager, host_role: bool) -> void:
	if not game_manager.is_match_started or not game_manager.is_game_active:
		return
	if _smoke_initial_turn_player_id not in GameRules.PLAYER_IDS:
		_smoke_initial_turn_player_id = game_manager.first_player_id
	if _smoke_initial_turn_player_id not in GameRules.PLAYER_IDS:
		return
	var next_player_id := game_manager.get_opponent_id(_smoke_initial_turn_player_id)
	if game_manager.active_player_id == next_player_id and game_manager.current_phase == GameManager.TurnPhase.PREPARATION:
		if host_role and not _smoke_turn_handoff_host_logged:
			_smoke_turn_handoff_host_logged = true
			print("ONLINE_FLOW_TURN_HANDOFF_HOST first=%d active=%d phase=%d" % [
				_smoke_initial_turn_player_id,
				game_manager.active_player_id,
				game_manager.current_phase,
			])
		elif not host_role and not _smoke_turn_handoff_client_logged:
			_smoke_turn_handoff_client_logged = true
			print("ONLINE_FLOW_TURN_HANDOFF_CLIENT first=%d active=%d phase=%d revision=%d" % [
				_smoke_initial_turn_player_id,
				game_manager.active_player_id,
				game_manager.current_phase,
				_last_snapshot_revision,
			])
		return
	if game_manager.active_player_id != local_player_id or _action_pending:
		return
	if game_manager.current_phase not in [GameManager.TurnPhase.PREPARATION, GameManager.TurnPhase.COMBAT]:
		return
	if request_action("advance_phase"):
		print("ONLINE_FLOW_TURN_ADVANCE role=%s player=%d phase=%d" % [
			"host" if host_role else "client",
			local_player_id,
			game_manager.current_phase,
		])


func _broadcast_clock() -> void:
	if not _is_server or not is_instance_valid(_battlefield):
		return
	var game_manager := _battlefield.get("game_manager") as GameManager
	if not game_manager:
		return
	for peer_id_variant in _peer_to_player.keys():
		var peer_id := int(peer_id_variant)
		if _ready_peers.has(peer_id):
			_receive_clock.rpc_id(
				peer_id,
				game_manager.active_player_id,
				game_manager.turn_time_remaining_seconds,
				game_manager.turn_duration_seconds,
				bool(game_manager.get("_turn_timer_running"))
			)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_clock(active_player_id: int, remaining: float, total: float, is_running: bool) -> void:
	if _is_server or not is_instance_valid(_battlefield):
		return
	var game_manager := _battlefield.get("game_manager") as GameManager
	if not game_manager:
		return
	game_manager.turn_time_remaining_seconds = maxf(0.0, remaining)
	if _battlefield.has_method("_on_turn_time_changed"):
		_battlefield._on_turn_time_changed(active_player_id, remaining, total, is_running)


func _connect_server_state_signals() -> void:
	if not is_instance_valid(_battlefield):
		return
	var game_manager := _battlefield.get("game_manager") as GameManager
	if not game_manager:
		return
	game_manager.turn_changed.connect(func(_player_id: int): mark_state_dirty())
	game_manager.phase_changed.connect(func(_phase: GameManager.TurnPhase): mark_state_dirty())
	game_manager.energy_changed.connect(func(_player_id: int, _current: int, _maximum: int, _temporary: int): mark_state_dirty())
	game_manager.preparation_token_changed.connect(func(_player_id: int, _available: bool): mark_state_dirty())
	game_manager.hq_health_changed.connect(func(_player_id: int, _current: int, _maximum: int): mark_state_dirty())
	game_manager.card_played.connect(func(_card: BaseCard, _target: BaseCard): mark_state_dirty())
	game_manager.attack_declared.connect(func(_card: BaseCard, _target: BaseCard): mark_state_dirty())
	game_manager.card_moved.connect(func(_card: BaseCard, _from: CardSlot, _to: CardSlot): mark_state_dirty())
	game_manager.effect_resolved.connect(func(_id: String, _source: BaseCard, _target: BaseCard, _result: Dictionary): mark_state_dirty())
	game_manager.effect_draw_completed.connect(func(_player_id: int, _requested: int, _drawn: int): mark_state_dirty())
	game_manager.card_destroyed.connect(func(_card: BaseCard, _source: BaseCard): mark_state_dirty())
	game_manager.experience_changed.connect(func(_card: BaseCard, _current: int, _gained: int, _reason: String): mark_state_dirty())
	game_manager.card_leveled_up.connect(func(_card: BaseCard, _level: int, _branch: String): mark_state_dirty())
	game_manager.effect_selection_started.connect(func(): mark_state_dirty())
	game_manager.effect_selection_player_changed.connect(func(_player_id: int): mark_state_dirty())
	game_manager.effect_card_selected.connect(func(_player_id: int, _card_id: String, _automatic: bool): mark_state_dirty())
	game_manager.effect_selection_completed.connect(func(): mark_state_dirty())
	game_manager.effect_trigger_state_changed.connect(func(_player_id: int, _state: Dictionary): mark_state_dirty())
	game_manager.dominion_score_changed.connect(func(_player_id: int, _score: int, _target: int): mark_state_dirty())
	game_manager.dominion_round_resolved.connect(func(_round: int, _lanes: Array, _points: Dictionary, _scores: Dictionary): mark_state_dirty())
	game_manager.game_over.connect(_on_authoritative_game_over)


func _on_authoritative_game_over(winner_id: int) -> void:
	_append_server_event("game_over", {"winner_id": winner_id})
	mark_state_dirty()


func _begin_reconnect_window(player_id: int) -> void:
	if not _is_server or player_id not in GameRules.PLAYER_IDS or not _players.has(player_id):
		return
	var entry := (_players[player_id] as Dictionary).duplicate(true)
	entry["peer_id"] = 0
	entry["connected"] = false
	_players[player_id] = entry
	var deadline := Time.get_ticks_msec() + (RECONNECT_GRACE_SECONDS * 1000)
	_disconnected_players[player_id] = deadline
	_waiting_for_reconnect = true
	_pause_authoritative_turn_timer()
	_append_server_event("player_disconnected", {"player_id": player_id})
	mark_state_dirty()
	_broadcast_opponent_connection_state(player_id, false, RECONNECT_GRACE_SECONDS)
	_broadcast_lobby_state()
	_set_status("%s bağlantısını kaybetti; %d saniye yeniden bağlanma süresi başladı." % [
		str(entry.get("name", "Rakip")), RECONNECT_GRACE_SECONDS,
	])
	if _smoke_online_flow:
		print("NETWORK_RECONNECT_WINDOW_OPEN player=%d" % player_id)


func _reconnect_player(peer_id: int, player_id: int, auth: Dictionary) -> void:
	var entry := (_players[player_id] as Dictionary).duplicate(true)
	entry["peer_id"] = peer_id
	entry["connected"] = true
	entry["name"] = str(auth.get("name", entry.get("name", "Komutan")))
	_players[player_id] = entry
	_peer_to_player[peer_id] = player_id
	_pending_auth.erase(peer_id)
	_disconnected_players.erase(player_id)
	if _smoke_online_flow:
		_smoke_reconnect_accepted = true
		print("NETWORK_RECONNECT_SERVER_ACCEPTED player=%d" % player_id)
	_ready_peers.erase(peer_id)
	_append_server_event("player_reconnected", {"player_id": player_id})
	_begin_match.rpc_id(
		peer_id,
		_match_seed,
		player_id,
		_match_id,
		_session_key,
		_room_ruleset,
		get_room_settings()
	)
	_broadcast_lobby_state()
	_broadcast_opponent_connection_state(player_id, true, 0)
	if _disconnected_players.is_empty():
		_waiting_for_reconnect = false
		_resume_authoritative_turn_timer()
	mark_state_dirty()
	_set_status("%s maça yeniden bağlandı." % str(entry.get("name", "Komutan")))


func _find_reconnect_player_id(token: String) -> int:
	if token.is_empty():
		return 0
	for player_id_variant in _players.keys():
		var player_id := int(player_id_variant)
		var entry := _players[player_id] as Dictionary
		if (
			str(entry.get("token", "")) == token
			and not bool(entry.get("connected", true))
			and _disconnected_players.has(player_id)
		):
			return player_id
	return 0


func _expire_disconnected_players() -> void:
	if _disconnected_players.is_empty():
		return
	var now := Time.get_ticks_msec()
	var expired: Array[int] = []
	for player_id_variant in _disconnected_players.keys():
		var player_id := int(player_id_variant)
		if now >= int(_disconnected_players[player_id]):
			expired.append(player_id)
	if expired.is_empty():
		return
	for player_id in expired:
		_disconnected_players.erase(player_id)
	var connected_players := _connected_player_ids()
	if connected_players.is_empty():
		_reset_server_lobby_after_abandon()
		return
	if is_instance_valid(_battlefield):
		var game_manager := _battlefield.get("game_manager") as GameManager
		if game_manager and game_manager.is_game_active:
			game_manager.finish_game(connected_players[0])
	for peer_id_variant in _peer_to_player.keys():
		_server_notice.rpc_id(int(peer_id_variant), "Rakip yeniden bağlanmadı; hükmen zafer.")
	_waiting_for_reconnect = false
	_paused_turn_timer_for_reconnect = false


func _pause_authoritative_turn_timer() -> void:
	if not is_instance_valid(_battlefield):
		return
	var game_manager := _battlefield.get("game_manager") as GameManager
	if not game_manager:
		return
	_paused_turn_timer_for_reconnect = bool(game_manager.get("_turn_timer_running"))
	game_manager.set("_turn_timer_running", false)


func _resume_authoritative_turn_timer() -> void:
	if not is_instance_valid(_battlefield):
		return
	var game_manager := _battlefield.get("game_manager") as GameManager
	if game_manager and game_manager.is_game_active and _paused_turn_timer_for_reconnect:
		game_manager.set("_turn_timer_running", true)
	_paused_turn_timer_for_reconnect = false


func _broadcast_opponent_connection_state(player_id: int, connected: bool, seconds_remaining: int) -> void:
	for peer_id_variant in _peer_to_player.keys():
		var peer_id := int(peer_id_variant)
		if int(_peer_to_player.get(peer_id, 0)) != player_id:
			_opponent_connection_state.rpc_id(peer_id, player_id, connected, seconds_remaining)
	if _is_hosting_player and local_player_id != player_id:
		_waiting_for_reconnect = not connected
		opponent_connection_changed.emit(player_id, connected, seconds_remaining)


@rpc("authority", "call_remote", "reliable", 0)
func _opponent_connection_state(player_id: int, connected: bool, seconds_remaining: int) -> void:
	if _is_server:
		return
	_waiting_for_reconnect = not connected
	opponent_connection_changed.emit(player_id, connected, seconds_remaining)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_rematch_vote() -> void:
	if not _is_server:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var player_id := int(_peer_to_player.get(sender_id, 0))
	_register_rematch_vote(player_id)


func _register_rematch_vote(player_id: int) -> void:
	if player_id not in GameRules.PLAYER_IDS or not _players.has(player_id) or not _all_players_connected():
		return
	if not is_instance_valid(_battlefield):
		return
	var game_manager := _battlefield.get("game_manager") as GameManager
	if not game_manager or game_manager.is_game_active:
		return
	_rematch_votes[player_id] = true
	_broadcast_rematch_status()
	if _rematch_votes.size() == MAX_PLAYERS:
		call_deferred("_start_rematch")


func _broadcast_rematch_status() -> void:
	var vote_count := _rematch_votes.size()
	var message := "İki komutan da hazır; rövanş başlıyor." if vote_count == MAX_PLAYERS else "Rövanş isteği gönderildi; rakip bekleniyor."
	for peer_id_variant in _peer_to_player.keys():
		_receive_rematch_status.rpc_id(int(peer_id_variant), vote_count, MAX_PLAYERS, message)
	if _is_hosting_player:
		rematch_status_changed.emit(vote_count, MAX_PLAYERS, message)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_rematch_status(votes: int, required_votes: int, message: String) -> void:
	if _is_server:
		return
	rematch_status_changed.emit(votes, required_votes, message)


func _start_rematch() -> void:
	if not _is_server or not _all_players_connected() or _rematch_votes.size() != MAX_PLAYERS:
		return
	_match_seed = _generate_match_seed()
	_match_id = _generate_match_id(_match_seed)
	_session_key = _generate_session_key()
	if _smoke_online_flow:
		_smoke_match_generation += 1
		_smoke_reconnect_accepted = false
		_smoke_reconnect_peer_ready = false
		print("ONLINE_FLOW_REMATCH_SERVER_START generation=%d" % _smoke_match_generation)
	state = NetworkState.STARTING
	_ready_peers.clear()
	_pending_snapshot.clear()
	_snapshot_revision = 0
	_snapshot_dirty = false
	_battlefield = null
	_rematch_votes.clear()
	_server_event_log.clear()
	_append_server_event("rematch_started", get_room_settings())
	_configure_authoritative_match_setup()
	for peer_id_variant in _peer_to_player.keys():
		var peer_id := int(peer_id_variant)
		_begin_match.rpc_id(
			peer_id,
			_match_seed,
			int(_peer_to_player[peer_id]),
			_match_id,
			_session_key,
			_room_ruleset,
			get_room_settings()
		)
	if _is_hosting_player:
		match_starting.emit(local_player_id)
	var change_error := get_tree().change_scene_to_file(BATTLEFIELD_SCENE)
	if change_error != OK:
		push_error("Rövanş savaş alanı yüklenemedi: %s" % error_string(change_error))


func _configure_authoritative_match_setup() -> void:
	var configured_decks := {}
	var configured_names := {}
	for player_id in GameRules.PLAYER_IDS:
		var entry := _players.get(player_id, {}) as Dictionary
		configured_decks[player_id] = (entry.get("deck_cards", []) as Array).duplicate(true)
		configured_names[player_id] = str(entry.get("deck_name", ""))
	if _is_hosting_player:
		MatchSetup.configure_multiplayer_host(_match_seed, local_player_id, _match_id, _room_ruleset)
	else:
		MatchSetup.configure_multiplayer_server(_match_seed, _match_id, _room_ruleset)
	_apply_room_settings_to_match_setup()
	if _smoke_online_flow and _smoke_match_generation == 1:
		# The full-flow smoke always exercises the hosted player's local authority
		# path before reconnect/rematch coverage begins.
		MatchSetup.forced_first_player_id = local_player_id if _is_hosting_player else 1
	for player_id in GameRules.PLAYER_IDS:
		MatchSetup.set_player_deck(player_id, configured_decks[player_id], configured_names[player_id])


func _restore_dedicated_match_from_disk() -> void:
	if not _is_server or _is_hosting_player or _restored_server_payload.is_empty():
		return
	var validation := _online_match_repository.validate_payload(_restored_server_payload)
	if not bool(validation.get("success", false)):
		push_warning(str(validation.get("error", "Çevrimiçi maç snapshot'ı doğrulanamadı.")))
		_restored_server_payload.clear()
		state = NetworkState.LOBBY
		get_tree().change_scene_to_file(SERVER_LOBBY_SCENE)
		return

	_match_id = str(_restored_server_payload.get("match_id", ""))
	_session_key = str(_restored_server_payload.get("session_key", ""))
	_match_seed = int(_restored_server_payload.get("seed", 0))
	_snapshot_revision = int(_restored_server_payload.get("revision", 0))
	_room_ruleset = _normalize_ruleset(int(_restored_server_payload.get("ruleset", MatchSetup.Ruleset.SIEGE)))
	var restored_room_settings_variant: Variant = _restored_server_payload.get("room_settings", {})
	if restored_room_settings_variant is Dictionary:
		_apply_room_settings_payload(restored_room_settings_variant as Dictionary)
	else:
		var restored_snapshot := _restored_server_payload.get("snapshot", {}) as Dictionary
		_apply_room_settings_payload({
			"ruleset": _room_ruleset,
			"match_name": restored_snapshot.get("match_name", MatchSetup.get_default_match_name(_room_ruleset)),
			"card_pool_mode": restored_snapshot.get("card_pool_mode", MatchSetup.CardPoolMode.DECK),
			"turn_duration_seconds": restored_snapshot.get("turn_duration_seconds", GameRules.TURN_DURATION_SECONDS),
			"auto_attack_allowed": restored_snapshot.get("auto_attack_allowed", true),
		})
	_paused_turn_timer_for_reconnect = bool(
		_restored_server_payload.get("resume_turn_timer_after_reconnect", false)
	)
	_players.clear()
	_peer_to_player.clear()
	_ready_peers.clear()
	_disconnected_players.clear()
	var saved_players := _restored_server_payload.get("players", {}) as Dictionary
	var reconnect_deadline := Time.get_ticks_msec() + (RECONNECT_GRACE_SECONDS * 1000)
	for player_id in GameRules.PLAYER_IDS:
		var player_variant: Variant = _dictionary_player_value(saved_players, player_id, {})
		if not player_variant is Dictionary:
			push_warning("Kalıcı çevrimiçi maç oyuncu kaydı eksik; sunucu lobiye dönüyor.")
			_restored_server_payload.clear()
			state = NetworkState.LOBBY
			get_tree().change_scene_to_file(SERVER_LOBBY_SCENE)
			return
		var entry := (player_variant as Dictionary).duplicate(true)
		if not _validate_network_deck(entry.get("deck_cards", [])):
			push_warning("Kalıcı çevrimiçi maç deste kaydı geçersiz; sunucu lobiye dönüyor.")
			_restored_server_payload.clear()
			state = NetworkState.LOBBY
			get_tree().change_scene_to_file(SERVER_LOBBY_SCENE)
			return
		entry["peer_id"] = 0
		entry["connected"] = false
		entry["local_host"] = false
		_players[player_id] = entry
		_disconnected_players[player_id] = reconnect_deadline

	_server_event_log.clear()
	var saved_events_variant: Variant = _restored_server_payload.get("event_log", [])
	if saved_events_variant is Array:
		for event_variant in saved_events_variant as Array:
			if event_variant is Dictionary:
				_server_event_log.append((event_variant as Dictionary).duplicate(true))
	_append_server_event("server_restored", {"revision": _snapshot_revision})
	_match_started = true
	_waiting_for_reconnect = true
	state = NetworkState.STARTING
	_configure_authoritative_match_setup()
	MatchSetup.set_resume_snapshot((_restored_server_payload.get("snapshot", {}) as Dictionary).duplicate(true))
	_set_status(
		"Maç revizyon %d'den geri yüklendi; oyuncular için %d saniyelik yeniden bağlanma penceresi açık."
		% [_snapshot_revision, RECONNECT_GRACE_SECONDS]
	)
	print("DARWINE_SERVER_MATCH_RESTORED match=%s revision=%d ruleset=%s" % [_match_id, _snapshot_revision, get_room_ruleset_name()])
	var change_error := get_tree().change_scene_to_file(BATTLEFIELD_SCENE)
	if change_error != OK:
		push_error("Kalıcı çevrimiçi savaş alanı yüklenemedi: %s" % error_string(change_error))


func _persist_authoritative_match_snapshot() -> void:
	if (
		not _is_server
		or _is_hosting_player
		or not _match_started
		or _match_id.is_empty()
		or _session_key.is_empty()
		or not is_instance_valid(_battlefield)
		or not _battlefield.has_method("build_active_match_snapshot")
	):
		return
	var game_manager := _battlefield.get("game_manager") as GameManager
	if game_manager and not game_manager.is_game_active:
		_online_match_repository.delete_all()
		return
	var snapshot: Dictionary = _battlefield.build_active_match_snapshot("çevrimiçi_revizyon_%d" % _snapshot_revision)
	if snapshot.is_empty():
		return
	snapshot["match_id"] = _match_id
	snapshot["seed"] = _match_seed
	var persisted_players := {}
	for player_id in GameRules.PLAYER_IDS:
		var entry := (_players.get(player_id, {}) as Dictionary).duplicate(true)
		entry["peer_id"] = 0
		persisted_players[player_id] = entry
	var result := _online_match_repository.save_match({
		"match_id": _match_id,
		"session_key": _session_key,
		"revision": _snapshot_revision,
		"seed": _match_seed,
		"invite_secret": _invite_secret,
		"public_ip": _public_ip,
		"server_port": _server_port,
		"ruleset": _room_ruleset,
		"room_settings": get_room_settings(),
		"resume_turn_timer_after_reconnect": _paused_turn_timer_for_reconnect,
		"players": persisted_players,
		"snapshot": snapshot,
		"event_log": _server_event_log.duplicate(true),
	})
	if not bool(result.get("success", false)):
		push_warning("Otoriter çevrimiçi snapshot yazılamadı: %s" % str(result.get("error", "bilinmeyen hata")))


func _append_server_event(event_type: String, details: Dictionary = {}) -> void:
	if not _is_server:
		return
	_server_event_log.append({
		"type": event_type,
		"revision": _snapshot_revision,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"details": details.duplicate(true),
	})
	while _server_event_log.size() > 96:
		_server_event_log.pop_front()


func _dictionary_player_value(dictionary: Dictionary, player_id: int, fallback: Variant) -> Variant:
	if dictionary.has(player_id):
		return dictionary[player_id]
	return dictionary.get(str(player_id), fallback)


func _reset_server_lobby_after_abandon() -> void:
	_online_match_repository.delete_all()
	_match_started = false
	_match_id = ""
	_session_key = ""
	_peer_to_player.clear()
	_players.clear()
	_ready_peers.clear()
	_disconnected_players.clear()
	_rematch_votes.clear()
	_battlefield = null
	_server_action_busy = false
	_snapshot_dirty = false
	_snapshot_revision = 0
	_waiting_for_reconnect = false
	_paused_turn_timer_for_reconnect = false
	_server_event_log.clear()
	state = NetworkState.LOBBY
	MatchSetup.configure_local()
	if _is_hosting_player:
		_reset_network_state(false)
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		get_tree().change_scene_to_file(SERVER_LOBBY_SCENE)


@rpc("authority", "call_remote", "reliable", 0)
func _server_notice(message: String) -> void:
	if _is_server:
		return
	_set_status(message, true)


func _reset_client_runtime(preserve_reconnect: bool) -> void:
	state = NetworkState.OFFLINE
	local_player_id = 0
	_players.clear()
	_ready_peers.clear()
	_battlefield = null
	_pending_snapshot.clear()
	if not preserve_reconnect:
		_last_snapshot_revision = -1
	_action_pending = false
	_match_started = false
	_waiting_for_reconnect = false
	_steam_peer = null
	_steam_lobby_id = 0
	_pending_steam_host = false
	_pending_steam_join = false
	_is_steam_transport = false
	if not preserve_reconnect:
		_expected_match_id = ""
		_expected_session_key = ""
	MatchSetup.configure_local()
	action_pending_changed.emit(false)
	if not preserve_reconnect:
		_reset_room_settings()
		_reconnect_allowed = false
		_reconnect_deadline_msec = 0


func _reset_network_state(preserve_reconnect: bool) -> void:
	_reset_client_runtime(preserve_reconnect)
	_is_server = false
	_is_hosting_player = false
	_peer_to_player.clear()
	_pending_auth.clear()
	_disconnected_players.clear()
	_rematch_votes.clear()
	_snapshot_revision = 0
	_server_action_busy = false
	_snapshot_dirty = false
	_match_id = ""
	_session_key = ""
	_restored_server_payload.clear()
	_server_event_log.clear()
	if not preserve_reconnect:
		_reconnect_token = ""
		_last_join_code = ""
		_last_steam_lobby_id = 0
		_last_join_name = ""
		_last_deck_cards.clear()
		_last_deck_name = ""
		_last_assigned_player_id = 0


func _public_player_dictionary() -> Dictionary:
	var result := {}
	for player_id_variant in _players.keys():
		var player_id := int(player_id_variant)
		var entry := _players[player_id] as Dictionary
		result[player_id] = {
			"name": str(entry.get("name", "Komutan %d" % player_id)),
			"deck_name": str(entry.get("deck_name", "İsimsiz Deste")),
			"connected": bool(entry.get("connected", true)),
			"local_host": bool(entry.get("local_host", false)),
		}
	return result


func _next_available_player_id() -> int:
	for player_id in GameRules.PLAYER_IDS:
		if not _players.has(player_id):
			return player_id
	return 0


func _required_remote_player_count() -> int:
	return MAX_PLAYERS - 1 if _is_hosting_player else MAX_PLAYERS


func _all_players_connected() -> bool:
	if _players.size() != MAX_PLAYERS:
		return false
	for player_id in GameRules.PLAYER_IDS:
		if not _players.has(player_id) or not bool((_players[player_id] as Dictionary).get("connected", false)):
			return false
	return true


func _connected_player_ids() -> Array[int]:
	var connected: Array[int] = []
	for player_id in GameRules.PLAYER_IDS:
		if _players.has(player_id) and bool((_players[player_id] as Dictionary).get("connected", false)):
			connected.append(player_id)
	return connected


func _validate_network_deck(cards_variant: Variant) -> bool:
	if not cards_variant is Array:
		return false
	var deck_manager := get_node_or_null("/root/DeckManager")
	if deck_manager:
		return bool(deck_manager.validate_deck_cards(cards_variant).get("success", false))
	return (cards_variant as Array).size() == GameRules.DECK_SIZE


func _get_local_deck_payload() -> Dictionary:
	var deck_manager := get_node_or_null("/root/DeckManager")
	if deck_manager:
		var deck: Dictionary = deck_manager.get_active_deck()
		return {
			"deck_name": str(deck.get("name", "İsimsiz Deste")),
			"deck_cards": (deck.get("cards", []) as Array).duplicate(true),
		}
	var fallback_rng := RandomNumberGenerator.new()
	fallback_rng.seed = 1
	return {"deck_name": "Standart Deste", "deck_cards": CardDatabase.build_fixed_deck_with_rng(fallback_rng)}


func _set_status(message: String, is_error: bool = false) -> void:
	last_status = message
	last_status_is_error = is_error
	status_changed.emit(message, is_error)
	if is_error:
		push_warning(message)


func _sanitize_player_name(raw_name: String) -> String:
	var source := raw_name.strip_edges()
	var filtered := ""
	for character in source:
		if character.unicode_at(0) >= 32:
			filtered += character
		if filtered.length() >= MAX_PLAYER_NAME_LENGTH:
			break
	return filtered if not filtered.is_empty() else "Komutan"


func _generate_invite_secret() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 0x7FFFFFFF)


func _generate_reconnect_token() -> String:
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(16)
	if not random_bytes.is_empty():
		return random_bytes.hex_encode()
	return "%x%x" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]


func _generate_session_key() -> String:
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(24)
	if not random_bytes.is_empty():
		return random_bytes.hex_encode()
	return "%x%x%x" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), _generate_invite_secret()]


func _generate_match_id(seed: int) -> String:
	return "online-%d-%s" % [seed, _generate_session_key().left(16)]


func _generate_match_seed() -> int:
	return maxi(1, abs(int(Time.get_unix_time_from_system() * 1000000.0) ^ int(Time.get_ticks_usec())))


func _parse_user_arguments(arguments: PackedStringArray) -> Dictionary:
	var parsed := {}
	var index := 0
	while index < arguments.size():
		var argument := str(arguments[index])
		if not argument.begins_with("--"):
			index += 1
			continue
		var body := argument.trim_prefix("--")
		if body.contains("="):
			var separator := body.find("=")
			parsed[body.substr(0, separator)] = body.substr(separator + 1)
			index += 1
			continue
		if index + 1 < arguments.size() and not str(arguments[index + 1]).begins_with("--"):
			parsed[body] = str(arguments[index + 1])
			index += 2
			continue
		parsed[body] = true
		index += 1
	return parsed


func _parse_ruleset_argument(value: Variant) -> int:
	var normalized := str(value).strip_edges().to_lower()
	if normalized in ["1", "dominion", "hakimiyet"]:
		return MatchSetup.Ruleset.DOMINION
	return MatchSetup.Ruleset.SIEGE


func _parse_card_pool_argument(value: Variant) -> int:
	var normalized := str(value).strip_edges().to_lower()
	return (
		MatchSetup.CardPoolMode.ALL_CARDS
		if normalized in ["1", "all", "all_cards", "tum_kartlar"]
		else MatchSetup.CardPoolMode.DECK
	)


func _parse_bool_argument(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return value
	var normalized := str(value).strip_edges().to_lower()
	if normalized in ["1", "true", "yes", "on", "enabled", "acik"]:
		return true
	if normalized in ["0", "false", "no", "off", "disabled", "kapali"]:
		return false
	return fallback


func _set_room_settings(
	match_ruleset: int = MatchSetup.Ruleset.SIEGE,
	match_name: String = "",
	card_pool_mode: int = MatchSetup.CardPoolMode.DECK,
	turn_duration_seconds: float = GameRules.TURN_DURATION_SECONDS,
	auto_attack_allowed: bool = true
) -> void:
	_room_ruleset = _normalize_ruleset(match_ruleset)
	var normalized_name := match_name.replace("\n", " ").replace("\r", " ").strip_edges()
	_room_match_name = (
		normalized_name.left(MatchSetup.MAX_MATCH_NAME_LENGTH)
		if not normalized_name.is_empty()
		else MatchSetup.get_default_match_name(_room_ruleset)
	)
	_room_card_pool_mode = (
		MatchSetup.CardPoolMode.ALL_CARDS
		if card_pool_mode == MatchSetup.CardPoolMode.ALL_CARDS
		else MatchSetup.CardPoolMode.DECK
	)
	_room_turn_duration_seconds = clampf(
		turn_duration_seconds,
		MatchSetup.MIN_TURN_DURATION_SECONDS,
		MatchSetup.MAX_TURN_DURATION_SECONDS
	)
	_room_auto_attack_allowed = auto_attack_allowed


func _apply_room_settings_payload(room_settings: Dictionary) -> void:
	if room_settings.is_empty():
		# Older saved rooms only carried the ruleset. Keep compatible defaults.
		_set_room_settings(_room_ruleset)
		return
	_set_room_settings(
		int(room_settings.get("ruleset", _room_ruleset)),
		str(room_settings.get("match_name", "")),
		int(room_settings.get("card_pool_mode", MatchSetup.CardPoolMode.DECK)),
		float(room_settings.get("turn_duration_seconds", GameRules.TURN_DURATION_SECONDS)),
		bool(room_settings.get("auto_attack_allowed", true))
	)


func _apply_room_settings_to_match_setup() -> void:
	MatchSetup.set_ruleset(_room_ruleset)
	MatchSetup.set_match_name(_room_match_name)
	MatchSetup.set_card_pool_mode(_room_card_pool_mode)
	MatchSetup.set_turn_duration_seconds(_room_turn_duration_seconds)
	MatchSetup.set_auto_attack_allowed(_room_auto_attack_allowed)


func _reset_room_settings() -> void:
	_set_room_settings()


func _normalize_ruleset(value: int) -> int:
	return MatchSetup.Ruleset.DOMINION if value == MatchSetup.Ruleset.DOMINION else MatchSetup.Ruleset.SIEGE
