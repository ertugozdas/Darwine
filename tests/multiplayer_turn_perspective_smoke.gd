extends SceneTree

const NETWORK_MANAGER_SCRIPT := preload("res://scripts/network_manager.gd")
const UI := preload("res://scripts/dark_fantasy_ui.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime_network := root.get_node_or_null("NetworkManager")
	var original_is_server := false
	var original_is_hosting_player := false
	var original_local_player_id := 0
	if runtime_network:
		original_is_server = bool(runtime_network.get("_is_server"))
		original_is_hosting_player = bool(runtime_network.get("_is_hosting_player"))
		original_local_player_id = int(runtime_network.get("local_player_id"))
		runtime_network.set("_is_server", true)
		runtime_network.set("_is_hosting_player", true)
		runtime_network.set("local_player_id", 1)
	await _test_host_turn_authority()
	await _test_player_two_perspective()
	if runtime_network:
		runtime_network.set("_battlefield", null)
		runtime_network.set("_is_server", original_is_server)
		runtime_network.set("_is_hosting_player", original_is_hosting_player)
		runtime_network.set("local_player_id", original_local_player_id)
	MatchSetup.configure_local(1)
	_finish()


func _test_host_turn_authority() -> void:
	MatchSetup.configure_multiplayer_host(73101, 1, "host-turn-smoke", MatchSetup.Ruleset.SIEGE)
	MatchSetup.fast_mode = true
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	while battlefield._is_dealing_initial_hands:
		await process_frame
	await process_frame

	var game_manager := battlefield.game_manager as GameManager
	game_manager.is_game_active = true
	game_manager.is_match_started = true
	game_manager.active_player_id = 2
	game_manager.current_phase = GameManager.TurnPhase.PREPARATION
	battlefield.call("_refresh_hand_visibility")
	battlefield.call("_apply_responsive_layout")

	_expect(battlefield.is_card_interaction_locked(), "Oda sahibi rakibin turunda etkileşime kilitlenmedi")
	var phase_before := game_manager.current_phase
	battlefield.call("_on_end_turn_pressed")
	_expect(game_manager.current_phase == phase_before, "Oda sahibi rakibin aşamasını ilerletebildi")
	_expect(int(battlefield.call("_get_hand_perspective_player_id")) == 1, "Oda sahibinin eli rakibin turunda değişti")
	_expect(battlefield.p1_hand.visible and not battlefield.p2_hand.visible, "Oda sahibi yalnızca kendi elini görmüyor")
	_expect(battlefield._p1_zone_world_rect.position.y > battlefield._p2_zone_world_rect.position.y, "Oda sahibinin alanı ekranın altına yerleşmedi")
	_expect(_same_color(battlefield.call("_get_team_accent", 1), UI.TEAM_PLAYER), "Oda sahibinin alanı mavi değil")
	_expect(_same_color(battlefield.call("_get_team_accent", 2), UI.TEAM_OPPONENT), "Oda sahibinin rakibi kırmızı değil")

	var hosted_network = NETWORK_MANAGER_SCRIPT.new()
	root.add_child(hosted_network)
	hosted_network.set("state", NETWORK_MANAGER_SCRIPT.NetworkState.MATCH)
	hosted_network.set("_is_server", true)
	hosted_network.set("_is_hosting_player", true)
	hosted_network.set("local_player_id", 1)
	hosted_network.set("_battlefield", battlefield)

	game_manager.active_player_id = 1
	game_manager.current_phase = GameManager.TurnPhase.PREPARATION
	var accepted := hosted_network.request_action("advance_phase")
	var duplicate_accepted := hosted_network.request_action("advance_phase")
	_expect(accepted, "Oda sahibinin geçerli aşama hamlesi sunucu akışına alınmadı")
	_expect(not duplicate_accepted, "Oda sahibi bekleyen hamle sırasında ikinci aşama hamlesi gönderebildi")
	await _wait_for_action(hosted_network)
	_expect(game_manager.current_phase == GameManager.TurnPhase.COMBAT, "Oda sahibinin doğrulanmış aşama hamlesi uygulanmadı")
	_expect(not hosted_network.is_action_pending(), "Oda sahibinin hamle kilidi sonuçtan sonra açılmadı")

	game_manager.active_player_id = 2
	game_manager.current_phase = GameManager.TurnPhase.PREPARATION
	_expect(hosted_network.request_action("advance_phase"), "Rakip turu doğrulama sınamasına alınamadı")
	await _wait_for_action(hosted_network)
	_expect(game_manager.current_phase == GameManager.TurnPhase.PREPARATION, "Sunucu oda sahibinin rakip turu hamlesini kabul etti")

	hosted_network.queue_free()
	battlefield._active_match_completed = true
	battlefield.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _test_player_two_perspective() -> void:
	MatchSetup.configure_multiplayer_client(73102, 2, "client-perspective-smoke", MatchSetup.Ruleset.SIEGE)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	await process_frame
	await process_frame

	var game_manager := battlefield.game_manager as GameManager
	game_manager.active_player_id = 1
	battlefield.call("_refresh_hand_visibility")
	battlefield.call("_apply_responsive_layout")

	_expect(int(battlefield.call("_get_hand_perspective_player_id")) == 2, "Oyuncu 2 eli aktif tura göre değişiyor")
	_expect(battlefield.p2_hand.visible and not battlefield.p1_hand.visible, "Oyuncu 2 yalnızca kendi elini görmüyor")
	_expect(battlefield._p2_zone_world_rect.position.y > battlefield._p1_zone_world_rect.position.y, "Oyuncu 2 alanı ekranın altına yerleşmedi")
	_expect(_same_color(battlefield.call("_get_team_accent", 2), UI.TEAM_PLAYER), "Oyuncu 2 kendi tarafını mavi görmüyor")
	_expect(_same_color(battlefield.call("_get_team_accent", 1), UI.TEAM_OPPONENT), "Oyuncu 2 rakibini kırmızı görmüyor")
	_expect(_same_color(battlefield.p2_hq_slot.call("_get_team_accent", 2), UI.TEAM_PLAYER), "Oyuncu 2 yuvaları mavi takım vurgusu kullanmıyor")
	_expect(_same_color(battlefield._arena_overlay.call("_get_team_accent", 2), UI.TEAM_PLAYER), "Arena katmanı oyuncu 2'yi mavi göstermiyor")

	battlefield._active_match_completed = true
	battlefield.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _wait_for_action(network_manager: Node) -> void:
	for _frame in range(60):
		if not network_manager.is_action_pending():
			return
		await process_frame
	_failures.append("Otoriter host hamlesi 60 kare içinde tamamlanmadı")


func _same_color(value: Variant, expected: Color) -> bool:
	if not value is Color:
		return false
	var color: Color = value
	return color.is_equal_approx(expected)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MULTIPLAYER_TURN_PERSPECTIVE_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("MULTIPLAYER_TURN_PERSPECTIVE_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
