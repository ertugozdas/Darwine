extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_deterministic_decks()
	await _test_difficulty_menu()
	await _test_fatigue_and_double_ko()
	await _test_action_description_lifetime()
	await _test_json_lines_telemetry()
	await _test_complete_ai_match()
	_finish()


func _test_deterministic_decks() -> void:
	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 777
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 777
	var first := CardDatabase.build_fixed_deck_with_rng(first_rng)
	var second := CardDatabase.build_fixed_deck_with_rng(second_rng)
	_expect(first == second, "Aynı RNG tohumu aynı 30 kartlık deste sırasını üretmeli")
	_expect(first.size() == GameRules.DECK_SIZE, "Deterministik deste 30 kart olmalı")


func _test_difficulty_menu() -> void:
	var menu := (load("res://main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	menu.call("_show_difficulty_selection")
	await process_frame
	var overlay := menu.find_child("DifficultyOverlay", true, false) as Control
	_expect(overlay != null and overlay.visible, "Başla akışı zorluk seçimini açmalı")
	for button_name in ["EasyDifficultyButton", "MediumDifficultyButton", "HardDifficultyButton"]:
		_expect(menu.find_child(button_name, true, false) is Button, "%s bulunmalı" % button_name)
	menu.queue_free()
	await process_frame


func _test_fatigue_and_double_ko() -> void:
	var manager := GameManager.new()
	root.add_child(manager)
	await process_frame
	var fatigue_values: Array[int] = []
	manager.fatigue_damage_applied.connect(func(_player_id: int, damage: int, _count: int):
		fatigue_values.append(damage)
	)
	for _index in range(3):
		manager.resolve_failed_draw(1)
	_expect(fatigue_values == [1, 2, 3], "Yorgunluk hasarı 1, 2, 3 biçiminde artmalı")
	_expect(int(manager.player_hq_health[1]) == 24, "İlk üç Yorgunluk toplam 6 Merkez Canı götürmeli")
	manager.queue_free()
	await process_frame

	var double_ko_manager := GameManager.new()
	root.add_child(double_ko_manager)
	await process_frame
	double_ko_manager.active_player_id = 2
	var winners: Array[int] = []
	double_ko_manager.game_over.connect(func(winner_id: int): winners.append(winner_id))
	var resolved_winner := double_ko_manager.set_hq_healths_simultaneously({1: 0, 2: 0})
	_expect(resolved_winner == 2, "Aynı anda ölümde çözümü yapan aktif oyuncu kazanmalı")
	_expect(winners == [2], "Aynı anda ölüm yalnızca bir oyun sonu olayı üretmeli")
	double_ko_manager.queue_free()
	await process_frame


func _test_action_description_lifetime() -> void:
	var planner := AIActionPlanner.new()
	var tactic := SpecialPowerCard.new()
	tactic.card_id = "ikmal_emri"
	tactic.card_name = "İkmal Emri"
	var hand_target := HeroCard.new()
	hand_target.card_id = "okcu"
	hand_target.card_name = "Okçu"
	root.add_child(tactic)
	root.add_child(hand_target)
	await process_frame

	var action := {
		"type": "play_hand_tactic",
		"player_id": 2,
		"card": tactic,
		"hand_target": hand_target,
	}
	var frozen_summary := planner.describe_action(action)
	_expect(str(frozen_summary.get("card_id", "")) == "ikmal_emri", "AI özeti taktik kartını çözümden önce dondurmalı")
	_expect(str(frozen_summary.get("hand_target_card_id", "")) == "okcu", "AI özeti el hedefini çözümden önce dondurmalı")
	tactic.queue_free()
	hand_target.queue_free()
	await process_frame

	var safe_after_free := planner.describe_action(action)
	_expect(str(safe_after_free.get("type", "")) == "play_hand_tactic", "Serbest bırakılmış kart referansı AI özetini bozmamalı")
	_expect(int(safe_after_free.get("player_id", 0)) == 2, "Serbest bırakılmış karttan sonra temel AI telemetrisi korunmalı")


func _test_complete_ai_match() -> void:
	MatchSetup.configure_automated(
		7001,
		MatchSetup.AIDifficulty.MEDIUM,
		MatchSetup.AIDifficulty.MEDIUM,
		1
	)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	var manager := battlefield.get_node("GameManager") as GameManager
	var frame_count := 0
	while manager.is_game_active and frame_count < 1200:
		await process_frame
		frame_count += 1
	var controller := battlefield.get_ai_controller()
	var telemetry := battlefield.get_match_telemetry()
	_expect(not manager.is_game_active, "Orta AI tam maçı kilitlenmeden bitirmeli")
	_expect(frame_count < 1200, "AI maçı güvenlik zaman aşımına girmemeli")
	_expect(controller != null and controller.invalid_action_count == 0, "AI hiçbir geçersiz hamle yapmamalı")
	var summary: Dictionary = telemetry.get_summary() if telemetry else {}
	_expect(telemetry != null and bool(summary.get("finished", false)), "Maç sonu telemetrisi tamamlanmalı")
	var players_variant: Variant = summary.get("players", {})
	_expect(players_variant is Dictionary and (players_variant as Dictionary).size() == 2, "Telemetri iki oyuncunun maç özeti metriklerini üretmeli")
	if players_variant is Dictionary:
		var players := players_variant as Dictionary
		var player_one: Dictionary = players.get(1, {}) as Dictionary
		_expect(player_one.has("cards_played") and player_one.has("hq_damage") and player_one.has("mvp_card_name"), "Oyuncu özeti kart, HQ hasarı ve öne çıkan kartı içermeli")
	_expect(float(summary.get("duration_seconds", -1.0)) >= 0.0, "Maç özeti süreyi içermeli")
	battlefield.queue_free()
	current_scene = null
	await process_frame
	MatchSetup.configure_local(1)


func _test_json_lines_telemetry() -> void:
	var path := "user://phase_seven_telemetry_test.jsonl"
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
	MatchSetup.configure_ai(MatchSetup.AIDifficulty.EASY, 9901)
	var manager := GameManager.new()
	root.add_child(manager)
	await process_frame
	var telemetry := MatchTelemetry.new()
	root.add_child(telemetry)
	telemetry.setup(manager, null, true, path)
	manager.begin_mulligan(1)
	manager.finish_game(1)
	var file := FileAccess.open(path, FileAccess.READ)
	_expect(file != null, "JSON Lines telemetri dosyası oluşturulmalı")
	var parsed_lines := 0
	if file:
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line.is_empty():
				continue
			if JSON.parse_string(line) is Dictionary:
				parsed_lines += 1
	_expect(parsed_lines >= 2, "Telemetri başlangıç ve maç sonunu ayrı JSON satırlarına yazmalı")
	telemetry.queue_free()
	manager.queue_free()
	await process_frame
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_SEVEN_AI_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PHASE_SEVEN_AI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
