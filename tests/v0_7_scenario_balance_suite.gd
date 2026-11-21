extends SceneTree

const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")
const OBJECTIVE_RESOLVER := preload("res://scripts/scenario_objective_resolver.gd")
const MATCH_ANALYSIS := preload("res://scripts/match_analysis.gd")
const DECK_ADVISOR := preload("res://scripts/deck_advisor.gd")

const DEFAULT_SAMPLES_PER_SCENARIO := 4
const FRAME_LIMIT := 1200
const BASE_SEED := 707_400

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog_result := SCENARIO_CATALOG.load_catalog(true)
	_expect(bool(catalog_result.get("success", false)), "Senaryo denge paketi kataloğu yükleyemedi")
	var deck_repository := root.get_node_or_null("DeckManager")
	_expect(deck_repository != null, "Senaryo denge paketi başlangıç destelerine erişemedi")
	if not bool(catalog_result.get("success", false)) or not deck_repository:
		_finish()
		return
	var requested_samples := int(OS.get_environment("DARWINE_V07_SCENARIO_SAMPLES"))
	var samples_per_scenario := requested_samples if requested_samples > 0 else DEFAULT_SAMPLES_PER_SCENARIO
	var scenarios := SCENARIO_CATALOG.get_scenarios()
	var rows := {}
	var total_matches := 0
	var completed_matches := 0
	var invalid_actions := 0
	var maximum_frames := 0
	var total_rewards := 0
	var previous_reward := 0

	for scenario_variant in scenarios:
		var scenario := scenario_variant as Dictionary
		var scenario_id := str(scenario.get("id", ""))
		var setup := scenario.get("setup", {}) as Dictionary
		var player_deck := deck_repository.get_deck(str(setup.get("player_deck_id", ""))) as Dictionary
		var opponent_deck := deck_repository.get_deck(str(setup.get("opponent_deck_id", ""))) as Dictionary
		var player_cards := (player_deck.get("cards", []) as Array).duplicate(true)
		var opponent_cards := (opponent_deck.get("cards", []) as Array).duplicate(true)
		var player_advice := DECK_ADVISOR.analyze(player_cards)
		var opponent_advice := DECK_ADVISOR.analyze(opponent_cards)
		_expect(bool(player_advice.get("is_complete", false)), "%s oyuncu destesi RC kurallarına uymalı" % scenario_id)
		_expect(bool(opponent_advice.get("is_complete", false)), "%s rakip destesi RC kurallarına uymalı" % scenario_id)
		_validate_objective_feasibility(scenario, player_advice)
		var reward := int((scenario.get("reward", {}) as Dictionary).get("amount", 0))
		_expect(reward > 0 and reward >= previous_reward, "%s ödülü pozitif ve sefer sırasıyla azalmayan olmalı" % scenario_id)
		previous_reward = reward
		total_rewards += reward

		var row := {
			"scenario_id": scenario_id,
			"matches": 0,
			"completed_matches": 0,
			"player_wins": 0,
			"objective_completions": 0,
			"lesson_objective_hits": {},
			"rounds": 0,
			"max_frames": 0,
		}
		for objective_variant in scenario.get("objectives", []) as Array:
			if objective_variant is Dictionary:
				var objective := objective_variant as Dictionary
				if str(objective.get("metric", "")) != "match_won":
					(row["lesson_objective_hits"] as Dictionary)[str(objective.get("id", ""))] = 0

		for sample_index in range(samples_per_scenario):
			var opponent_difficulty := _difficulty_from_id(str(setup.get("ai_difficulty", "medium")))
			MatchSetup.configure_automated(
				BASE_SEED + int(scenario.get("order", 0)) * 1000 + sample_index,
				MatchSetup.AIDifficulty.HARD,
				opponent_difficulty,
				int(setup.get("forced_first_player_id", 0))
			)
			MatchSetup.set_ruleset(
				MatchSetup.Ruleset.DOMINION
				if str(scenario.get("ruleset", "siege")) == "dominion"
				else MatchSetup.Ruleset.SIEGE
			)
			MatchSetup.set_match_name(str(scenario.get("title", scenario_id)))
			MatchSetup.set_turn_duration_seconds(float(setup.get("turn_duration_seconds", GameRules.TURN_DURATION_SECONDS)))
			MatchSetup.set_auto_attack_allowed(bool(setup.get("auto_attack_allowed", false)))
			MatchSetup.set_card_pool_mode(MatchSetup.CardPoolMode.DECK)
			MatchSetup.set_forced_effect_card(1, str(setup.get("player_effect_card_id", "")))
			MatchSetup.set_forced_effect_card(2, str(setup.get("opponent_effect_card_id", "")))
			MatchSetup.set_player_deck(1, player_cards, str(player_deck.get("name", "")))
			MatchSetup.set_player_deck(2, opponent_cards, str(opponent_deck.get("name", "")))
			MatchSetup.set_scenario_context(SCENARIO_CATALOG.build_match_context(scenario_id))

			var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
			root.add_child(battlefield)
			current_scene = battlefield
			var manager := battlefield.game_manager as GameManager
			var frame_count := 0
			while manager.is_game_active and frame_count < FRAME_LIMIT:
				await process_frame
				frame_count += 1
			maximum_frames = maxi(maximum_frames, frame_count)
			row["max_frames"] = maxi(int(row.get("max_frames", 0)), frame_count)
			total_matches += 1
			row["matches"] = int(row.get("matches", 0)) + 1
			if not manager.is_game_active:
				completed_matches += 1
				row["completed_matches"] = int(row.get("completed_matches", 0)) + 1
			var controller := battlefield.get_ai_controller()
			invalid_actions += controller.invalid_action_count if controller else 1
			var telemetry := battlefield.get_match_telemetry()
			var summary: Dictionary = telemetry.get_summary() if telemetry else {}
			_expect(str(summary.get("scenario_id", "")) == scenario_id, "%s telemetrisi senaryo kimliğini kaybetmemeli" % scenario_id)
			var rounds := int(summary.get("round_count", manager.round_count))
			row["rounds"] = int(row.get("rounds", 0)) + rounds
			if int(summary.get("winner_id", 0)) == 1:
				row["player_wins"] = int(row.get("player_wins", 0)) + 1
			var evaluation := OBJECTIVE_RESOLVER.evaluate(
				MatchSetup.get_scenario_context(),
				summary,
				1
			)
			if bool(evaluation.get("completed", false)):
				row["objective_completions"] = int(row.get("objective_completions", 0)) + 1
			for objective_result_variant in evaluation.get("objective_results", []) as Array:
				if not objective_result_variant is Dictionary:
					continue
				var objective_result := objective_result_variant as Dictionary
				var objective_id := str(objective_result.get("id", ""))
				if (row["lesson_objective_hits"] as Dictionary).has(objective_id) and bool(objective_result.get("completed", false)):
					(row["lesson_objective_hits"] as Dictionary)[objective_id] = int((row["lesson_objective_hits"] as Dictionary).get(objective_id, 0)) + 1
			var analysis := MATCH_ANALYSIS.analyze(summary, 1)
			_expect(bool(analysis.get("valid", false)), "%s sonucu açıklanabilir analiz üretmeli" % scenario_id)

			battlefield._active_match_completed = true
			battlefield.queue_free()
			current_scene = null
			await process_frame
			await process_frame

		row["average_rounds"] = snappedf(
			float(row.get("rounds", 0)) / float(maxi(1, int(row.get("matches", 0)))),
			0.01
		)
		for objective_id_variant in (row["lesson_objective_hits"] as Dictionary).keys():
			var objective_id := str(objective_id_variant)
			_expect(
				int((row["lesson_objective_hits"] as Dictionary).get(objective_id, 0)) > 0,
				"%s ders hedefi '%s' üretim AI örneklerinde hiç erişilemedi" % [scenario_id, objective_id]
			)
		_expect(int(row.get("objective_completions", 0)) > 0, "%s en az bir tam hedef tamamlaması üretmeli" % scenario_id)
		rows[scenario_id] = row

	var expected_matches := scenarios.size() * samples_per_scenario
	var report := {
		"release_version": "0.7",
		"player_reference_ai": "hard",
		"samples_per_scenario": samples_per_scenario,
		"total_matches": total_matches,
		"completed_matches": completed_matches,
		"invalid_actions": invalid_actions,
		"maximum_frames": maximum_frames,
		"total_campaign_seals": total_rewards,
		"scenarios": rows,
	}
	print("V0_7_SCENARIO_BALANCE_RESULTS ", JSON.stringify(report))
	_expect(total_matches == expected_matches, "Senaryo denge paketi beklenen maç sayısını çalıştırmalı")
	_expect(completed_matches == expected_matches, "Senaryo denge paketindeki tüm maçlar tamamlanmalı")
	_expect(invalid_actions == 0, "Senaryo denge paketinde geçersiz AI hamlesi olmamalı")
	_expect(maximum_frames < FRAME_LIMIT, "Senaryo denge paketinde zaman aşımı olmamalı")
	_expect(total_rewards == 95, "Sefer toplam ilk tamamlama ödülü 95 Mühür olmalı")
	MatchSetup.configure_local(1)
	_finish()


func _validate_objective_feasibility(scenario: Dictionary, advice: Dictionary) -> void:
	var scenario_id := str(scenario.get("id", ""))
	var types := advice.get("types", {}) as Dictionary
	var curve := advice.get("curve", {}) as Dictionary
	var maximum_energy_spend := int(round(float(curve.get("average_energy", 0.0)) * float(advice.get("card_count", 0))))
	for objective_variant in scenario.get("objectives", []) as Array:
		if not objective_variant is Dictionary:
			continue
		var objective := objective_variant as Dictionary
		var metric := str(objective.get("metric", ""))
		var target := int(objective.get("target", 0))
		match metric:
			"heroes_played":
				_expect(target <= int(types.get("heroes", 0)), "%s Kahraman hedefi destedeki Kahraman sayısını aşmamalı" % scenario_id)
			"settlements_played":
				_expect(target <= int(types.get("settlements", 0)), "%s Yapı hedefi destedeki Yapı sayısını aşmamalı" % scenario_id)
			"energy_spent":
				_expect(target <= maximum_energy_spend, "%s Enerji hedefi destenin toplam maliyetini aşmamalı" % scenario_id)
			"hq_damage":
				_expect(target <= GameRules.HEADQUARTERS_HEALTH, "%s Merkez hasarı hedefi Merkez Canını aşmamalı" % scenario_id)
			"dominion_score":
				_expect(target <= GameRules.DOMINION_SCORE_TARGET, "%s Hakimiyet hedefi maç hedefini aşmamalı" % scenario_id)


func _difficulty_from_id(value: String) -> int:
	match value:
		"easy":
			return MatchSetup.AIDifficulty.EASY
		"hard":
			return MatchSetup.AIDifficulty.HARD
		_:
			return MatchSetup.AIDifficulty.MEDIUM


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_SCENARIO_BALANCE_SUITE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_SCENARIO_BALANCE_SUITE_FAILED: %d" % _failures.size())
	quit(1)
