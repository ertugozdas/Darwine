extends SceneTree

const NETWORK_MANAGER_SCRIPT := preload("res://scripts/network_manager.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_multiplayer_configuration_keeps_ruleset()
	_test_reconnect_runtime_keeps_ruleset()
	await _test_snapshot_round_trip()
	MatchSetup.configure_local(1)
	_finish()


func _test_multiplayer_configuration_keeps_ruleset() -> void:
	MatchSetup.configure_multiplayer_server(9001, "server-match", MatchSetup.Ruleset.DOMINION)
	_expect(MatchSetup.is_dominion(), "Authoritative sunucu Hakimiyet kuralını kurmalı")
	MatchSetup.configure_multiplayer_host(9002, 1, "host-match", MatchSetup.Ruleset.DOMINION)
	_expect(MatchSetup.is_dominion(), "Oda sahibi Hakimiyet kuralını kurmalı")
	MatchSetup.configure_multiplayer_client(9003, 2, "client-match", MatchSetup.Ruleset.DOMINION)
	_expect(MatchSetup.is_dominion(), "İstemci sunucudan gelen Hakimiyet kuralını kurmalı")


func _test_reconnect_runtime_keeps_ruleset() -> void:
	var network_manager := NETWORK_MANAGER_SCRIPT.new()
	network_manager.set("_room_ruleset", MatchSetup.Ruleset.DOMINION)
	network_manager.call("_reset_client_runtime", true)
	_expect(
		int(network_manager.get_room_ruleset()) == MatchSetup.Ruleset.DOMINION,
		"Yeniden bağlanma için temizlenen istemci oturumu oda kuralını korumalı"
	)
	network_manager.call("_reset_client_runtime", false)
	_expect(
		int(network_manager.get_room_ruleset()) == MatchSetup.Ruleset.SIEGE,
		"Tam ağ çıkışı oda kuralını varsayılana döndürmeli"
	)
	network_manager.free()


func _test_snapshot_round_trip() -> void:
	MatchSetup.configure_local(9010)
	MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
	var server_battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(server_battlefield)
	current_scene = server_battlefield
	await process_frame
	await process_frame
	var server_manager := server_battlefield.get_node("GameManager") as GameManager
	var server_hand_node := server_battlefield.call("_get_hand_for_player", 2) as Control
	var runtime_card := HeroCard.new()
	runtime_card.owner_id = 2
	runtime_card.card_id = "can_muhafizi"
	server_hand_node.add_child(runtime_card)
	await process_frame
	runtime_card.trait_runtime = {"bulwark_available": false, "time_theft_used": true}
	var runtime_network_id := str(server_battlefield.call("_get_card_network_id", runtime_card))
	_expect(not runtime_network_id.is_empty(), "Ağ nitelik durumu fixture kartına fiziksel kimlik atanmalı")
	server_manager.player_dominion_score = {1: 7, 2: 11}
	server_manager.last_dominion_lane_results = (
		server_battlefield.get_dominion_preview().get("lane_results", []) as Array
	).duplicate(true)
	var last_lane_count := server_manager.last_dominion_lane_results.size()
	server_manager.win_reason = "dominion"
	var snapshot := server_battlefield.build_network_snapshot(2)
	snapshot["revision"] = 1
	_expect(int(snapshot.get("ruleset", -1)) == MatchSetup.Ruleset.DOMINION, "Snapshot ruleset kimliğini taşımalı")
	var manager_state := snapshot.get("manager", {}) as Dictionary
	_expect(
		int((manager_state.get("player_dominion_score", {}) as Dictionary).get(2, 0)) == 11,
		"Snapshot Hakimiyet skorlarını taşımalı"
	)
	_expect(str(manager_state.get("win_reason", "")) == "dominion", "Snapshot zafer nedenini taşımalı")
	var own_hand_rows := (snapshot.get("hands", {}) as Dictionary).get(2, []) as Array
	var serialized_runtime := {}
	for row_variant in own_hand_rows:
		var row := row_variant as Dictionary
		if str(row.get("network_id", "")) == runtime_network_id:
			serialized_runtime = (row.get("trait_runtime", {}) as Dictionary).duplicate(true)
			break
	_expect(
		serialized_runtime == {"bulwark_available": false, "time_theft_used": true},
		"Snapshot kartın nitelik çalışma durumunu taşımalı"
	)

	server_battlefield.queue_free()
	current_scene = null
	await process_frame
	await process_frame

	MatchSetup.configure_local(9011)
	var client_battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(client_battlefield)
	current_scene = client_battlefield
	await process_frame
	await process_frame
	MatchSetup.configure_multiplayer_client(9010, 2, "client-resume", MatchSetup.Ruleset.SIEGE)
	client_battlefield.apply_network_snapshot(snapshot)
	await process_frame

	var client_manager := client_battlefield.get_node("GameManager") as GameManager
	_expect(MatchSetup.is_dominion(), "İstemci snapshot ruleset kimliğini uygulamalı")
	_expect(int(client_manager.player_dominion_score.get(1, 0)) == 7, "Oyuncu 1 Hakimiyet skoru geri yüklenmeli")
	_expect(int(client_manager.player_dominion_score.get(2, 0)) == 11, "Oyuncu 2 Hakimiyet skoru geri yüklenmeli")
	_expect(client_manager.win_reason == "dominion", "Hakimiyet zafer nedeni geri yüklenmeli")
	var restored_runtime_card := client_battlefield.call("_find_card_by_network_id", runtime_network_id) as BaseCard
	_expect(restored_runtime_card != null, "Nitelik çalışma durumu taşıyan ağ kartı istemcide bulunmalı")
	if restored_runtime_card:
		_expect(
			restored_runtime_card.trait_runtime == {"bulwark_available": false, "time_theft_used": true},
			"Kart nitelik çalışma durumu ağ snapshot'ından geri yüklenmeli"
		)
	_expect(
		client_manager.last_dominion_lane_results.size() == last_lane_count,
		"Son koridor çözümü yeniden bağlanan istemcide korunmalı"
	)
	var score_labels := client_battlefield.top_hud.find_children("DominionScore", "Label", true, false)
	_expect(score_labels.size() == 2, "İstemci HUD'ı iki Hakimiyet skoru göstermeli")
	for label_variant in score_labels:
		var label := label_variant as Label
		_expect(label.visible, "Hakimiyet snapshot'ı skor etiketlerini görünür tutmalı")

	client_battlefield.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DOMINION_NETWORK_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("DOMINION_NETWORK_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
