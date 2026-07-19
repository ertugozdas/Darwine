extends SceneTree

const NETWORK_MANAGER_SCRIPT := preload("res://scripts/network_manager.gd")
const TEST_PORT := 61973

var _failures: Array[String] = []


class SnapshotSink extends Node:
	var applied_snapshots: Array[Dictionary] = []

	func apply_network_snapshot(snapshot: Dictionary) -> void:
		applied_snapshots.append(snapshot.duplicate(true))


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_client_snapshot_binding()
	await _test_authoritative_action_boundary_and_persistence()
	MatchSetup.configure_local(1)
	_finish()


func _test_client_snapshot_binding() -> void:
	var network_manager = NETWORK_MANAGER_SCRIPT.new()
	var sink := SnapshotSink.new()
	network_manager.set("_battlefield", sink)
	network_manager.set("_is_server", false)
	network_manager.set("local_player_id", 1)
	network_manager.set("_expected_match_id", "bound-match")
	network_manager.set("_expected_session_key", "0123456789abcdef0123456789abcdef0123456789abcdef")
	network_manager.set("_last_snapshot_revision", 4)

	var valid_base := {
		"match_id": "bound-match",
		"session_key": "0123456789abcdef0123456789abcdef0123456789abcdef",
		"player_id": 1,
		"perspective_player_id": 1,
		"revision": 5,
	}
	var wrong_match := valid_base.duplicate(true)
	wrong_match["match_id"] = "forged-match"
	network_manager.call("_receive_snapshot", wrong_match)
	var wrong_session := valid_base.duplicate(true)
	wrong_session["session_key"] = "ffffffffffffffffffffffffffffffffffffffffffffffff"
	network_manager.call("_receive_snapshot", wrong_session)
	var wrong_player := valid_base.duplicate(true)
	wrong_player["player_id"] = 2
	network_manager.call("_receive_snapshot", wrong_player)
	_expect(sink.applied_snapshots.is_empty(), "Kimliği eşleşmeyen istemci snapshot'ı uygulandı")
	_expect(int(network_manager.get("_last_snapshot_revision")) == 4, "Reddedilen snapshot revizyon sayacını ilerletti")

	network_manager.call("_receive_snapshot", valid_base)
	_expect(sink.applied_snapshots.size() == 1, "Geçerli bağlı snapshot uygulanmadı")
	_expect(int(network_manager.get("_last_snapshot_revision")) == 5, "Geçerli snapshot revizyonu kaydedilmedi")
	network_manager.call("_receive_snapshot", valid_base)
	var stale := valid_base.duplicate(true)
	stale["revision"] = 3
	network_manager.call("_receive_snapshot", stale)
	_expect(sink.applied_snapshots.size() == 1, "Aynı veya eski snapshot revizyonu tekrar uygulandı")
	var next_snapshot := valid_base.duplicate(true)
	next_snapshot["revision"] = 6
	network_manager.call("_receive_snapshot", next_snapshot)
	_expect(sink.applied_snapshots.size() == 2, "Artan snapshot revizyonu uygulanmadı")

	_expect(int(NETWORK_MANAGER_SCRIPT.RECONNECT_GRACE_SECONDS) == 90, "Yeniden bağlanma penceresi 90 saniye değil")
	network_manager.set("_players", {
		1: {"token": "token-one", "connected": false},
		2: {"token": "token-two", "connected": false},
	})
	network_manager.set("_disconnected_players", {1: Time.get_ticks_msec() + 90000, 2: Time.get_ticks_msec() + 90000})
	_expect(int(network_manager.call("_find_reconnect_player_id", "token-two")) == 2, "Yeniden bağlanma anahtarı eski oyuncu yuvasına bağlanmadı")
	_expect(int(network_manager.call("_find_reconnect_player_id", "forged-token")) == 0, "Sahte yeniden bağlanma anahtarı kabul edildi")

	sink.free()
	network_manager.free()


func _test_authoritative_action_boundary_and_persistence() -> void:
	MatchSetup.configure_local(63001)
	MatchSetup.fast_mode = true
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	while battlefield._is_dealing_initial_hands:
		await process_frame
	await process_frame
	var game_manager := battlefield.game_manager as GameManager

	MatchSetup.configure_multiplayer_server(63001, "online-authority-match", MatchSetup.Ruleset.SIEGE)
	game_manager.is_game_active = true
	game_manager.is_match_started = false
	game_manager.current_phase = GameManager.TurnPhase.EFFECT_SELECTION
	game_manager.active_player_id = 1
	game_manager.effect_offers = {
		1: ["dovme_ocagi", "saha_hekimleri", "oncu_doktrini"],
		2: ["son_direnis", "ikmal_hatti", "yapi_ustalari"],
	}
	game_manager.selected_effect_cards.clear()
	game_manager.set("_effect_selection_active", true)

	for forbidden_action in ["load", "snapshot", "restore", "set_stat", "set_stats"]:
		var forbidden_result: Dictionary = await battlefield.execute_network_action(1, forbidden_action, {"health": 999})
		_expect(not bool(forbidden_result.get("success", true)), "İstemcinin '%s' otorite komutu kabul edildi" % forbidden_action)
	var forged_choice: Dictionary = await battlefield.execute_network_action(1, "effect_choice", {"card_id": "son_direnis"})
	_expect(not bool(forged_choice.get("success", true)), "Oyuncu kendi teklifinde olmayan Etki Kartını seçti")
	var valid_choice: Dictionary = await battlefield.execute_network_action(1, "effect_choice", {"card_id": "dovme_ocagi"})
	_expect(bool(valid_choice.get("success", false)), "Sunucu oyuncunun geçerli gizli Etki Kartı seçimini kabul etmedi")
	var duplicate_choice: Dictionary = await battlefield.execute_network_action(1, "effect_choice", {"card_id": "saha_hekimleri"})
	_expect(not bool(duplicate_choice.get("success", true)), "Sunucu aynı oyuncunun ikinci Etki Kartı seçimini kabul etti")

	game_manager.selected_effect_cards = {1: "dovme_ocagi", 2: "son_direnis"}
	game_manager.effect_trigger_state = {
		1: {"last_trigger_id": "forge", "last_trigger_details": {"target": "own"}},
		2: {"last_trigger_id": "last_stand", "last_trigger_details": {"secret_card_id": "son_direnis"}},
	}
	game_manager.set("_effect_selection_active", false)
	var perspective_snapshot := battlefield.build_network_snapshot(1)
	var public_manager := perspective_snapshot.get("manager", {}) as Dictionary
	var public_effect := public_manager.get("effect_selection", {}) as Dictionary
	_expect(str(public_effect.get("own_selected_card", "")) == "dovme_ocagi", "Oyuncunun kendi Etki Kartı public snapshot'ta yok")
	_expect(bool(public_effect.get("opponent_selected", false)), "Rakibin seçim tamamlandı bayrağı public snapshot'ta yok")
	_expect(not public_effect.has("opponent_card_id") and not public_effect.has("opponent_offer"), "Rakibin Etki Kartı kimliği public snapshot alanıyla sızdı")
	_expect(not JSON.stringify(perspective_snapshot).contains("son_direnis"), "Rakibin Etki Kartı adı veya tetik ayrıntısı perspektif snapshot'ına sızdı")

	var deck := _valid_deck()
	_expect(deck.size() == GameRules.DECK_SIZE, "Otoriter snapshot fixture destesi 30 kart değil")
	MatchSetup.set_player_deck(1, deck, "Sunucu Deste 1")
	MatchSetup.set_player_deck(2, deck, "Sunucu Deste 2")
	var players := {
		1: {
			"peer_id": 11,
			"name": "Komutan Bir",
			"token": "restart-token-one",
			"deck_name": "Sunucu Deste 1",
			"deck_cards": deck.duplicate(true),
			"connected": true,
			"local_host": false,
		},
		2: {
			"peer_id": 12,
			"name": "Komutan İki",
			"token": "restart-token-two",
			"deck_name": "Sunucu Deste 2",
			"deck_cards": deck.duplicate(true),
			"connected": true,
			"local_host": false,
		},
	}
	var authoritative_network = NETWORK_MANAGER_SCRIPT.new()
	var online_repository := authoritative_network.get("_online_match_repository") as OnlineMatchRepository
	online_repository.configure_port(TEST_PORT)
	online_repository.delete_all()
	authoritative_network.set("_is_server", true)
	authoritative_network.set("_is_hosting_player", false)
	authoritative_network.set("_match_started", true)
	authoritative_network.set("_match_id", "online-authority-match")
	authoritative_network.set("_session_key", "abcdef0123456789abcdef0123456789abcdef0123456789")
	authoritative_network.set("_match_seed", 63001)
	authoritative_network.set("_snapshot_revision", 7)
	authoritative_network.set("_invite_secret", 24681357)
	authoritative_network.set("_public_ip", "127.0.0.1")
	authoritative_network.set("_server_port", TEST_PORT)
	authoritative_network.set("_players", players)
	authoritative_network.set("_battlefield", battlefield)
	authoritative_network.call("_append_server_event", "accepted_action", {"player_id": 1})
	authoritative_network.call("_persist_authoritative_match_snapshot")
	var loaded := online_repository.load_match()
	_expect(bool(loaded.get("success", false)), "Dedicated sunucu otoriter snapshot'ı diske yazmadı")
	if bool(loaded.get("success", false)):
		var payload := loaded.get("payload", {}) as Dictionary
		_expect(str(payload.get("match_id", "")) == "online-authority-match", "Kalıcı online snapshot match_id değerini kaybetti")
		_expect(str(payload.get("session_key", "")) == "abcdef0123456789abcdef0123456789abcdef0123456789", "Kalıcı online snapshot oturum anahtarını kaybetti")
		_expect(int(payload.get("revision", -1)) == 7, "Kalıcı online snapshot revizyonu yanlış")
		_expect((payload.get("event_log", []) as Array).size() == 1, "Kalıcı online snapshot olay günlüğünü taşımadı")
		var tampered := payload.duplicate(true)
		(tampered.get("snapshot", {}) as Dictionary)["match_id"] = "forged-match"
		var tampered_result := online_repository.validate_payload(tampered)
		_expect(not bool(tampered_result.get("success", true)), "Eşleşmeyen match_id taşıyan online restore kabul edildi")

	# A normal authoritative game over removes the active-online slot; only active
	# matches are restart-recoverable.
	game_manager.is_game_active = false
	authoritative_network.call("_persist_authoritative_match_snapshot")
	_expect(not bool(online_repository.load_match().get("success", false)), "Tamamlanan online maç aktif snapshot olarak bırakıldı")

	authoritative_network.free()
	battlefield._active_match_completed = true
	battlefield.queue_free()
	current_scene = null
	await process_frame


func _valid_deck() -> Array:
	var deck_manager := root.get_node_or_null("DeckManager")
	if deck_manager:
		return (deck_manager.get_active_deck().get("cards", []) as Array).duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 63001
	return CardDatabase.build_fixed_deck_with_rng(rng)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ONLINE_AUTHORITY_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("ONLINE_AUTHORITY_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
