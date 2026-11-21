extends SceneTree

const MATCH_COUNT := 50
const FRAME_LIMIT := 1200
## v0.7 RC calibration: two independent 50-match Siege batches averaged
## 14.16 and 14.82 rounds. A 15-round ceiling keeps the duration guard strict
## without rejecting the stable 14.49-round combined population.
const SIEGE_AVERAGE_ROUND_MAX := 15.0
const TRACKED_EXPANSION_CARD_IDS := [
	"can_muhafizi",
	"kul_sancaktari",
	"firtina_nakkasi",
	"yanki_celladi",
	"zaman_hirsizi",
	"dus_yuruyeni",
	"gunesiz_kralice",
	"ruh_fenercisi",
	"kiriktac_yeminlisi",
	"demirkok_samani",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested_match_count: int = int(OS.get_environment("TDM_BALANCE_MATCH_COUNT"))
	var match_count: int = requested_match_count if requested_match_count > 0 else MATCH_COUNT
	var match_offset: int = maxi(0, int(OS.get_environment("TDM_BALANCE_MATCH_OFFSET")))
	var use_all_cards := OS.get_environment("TDM_BALANCE_ALL_CARDS") == "1"
	var requested_ruleset := OS.get_environment("TDM_BALANCE_RULESET").strip_edges().to_lower()
	var use_dominion := requested_ruleset in ["1", "dominion", "hakimiyet"]
	var completed := 0
	var invalid_actions := 0
	var first_player_wins := 0
	var player_one_wins := 0
	var total_rounds := 0
	var min_rounds := 999
	var max_rounds := 0
	var total_first_hq_damage_round := 0
	var measured_first_hq_damage_matches := 0
	var total_first_dominion_score_round := 0
	var measured_first_dominion_score_matches := 0
	var maximum_frames := 0
	var win_reason_counts: Dictionary = {}
	var opening_cards: Dictionary = {}
	var card_performance: Dictionary = {}
	var difficulty_results := {
		"Kolay": {"matches": 0, "rounds": 0, "first_player_wins": 0},
		"Orta": {"matches": 0, "rounds": 0, "first_player_wins": 0},
		"Zor": {"matches": 0, "rounds": 0, "first_player_wins": 0},
	}

	for batch_index in range(match_count):
		var match_index: int = match_offset + int(batch_index)
		var difficulty: int = match_index % 3
		var forced_first_player: int = 1 if match_index % 2 == 0 else 2
		MatchSetup.configure_automated(
			8100 + match_index,
			difficulty,
			difficulty,
			forced_first_player
		)
		if use_dominion:
			MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
		if use_all_cards:
			MatchSetup.set_card_pool_mode(MatchSetup.CardPoolMode.ALL_CARDS)
		var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
		root.add_child(battlefield)
		current_scene = battlefield
		var manager := battlefield.get_node("GameManager") as GameManager
		var frame_count := 0
		while manager.is_game_active and frame_count < FRAME_LIMIT:
			await process_frame
			frame_count += 1
		maximum_frames = max(maximum_frames, frame_count)

		var controller := battlefield.get_ai_controller()
		var telemetry := battlefield.get_match_telemetry()
		var summary: Dictionary = telemetry.get_summary() if telemetry else {}
		invalid_actions += controller.invalid_action_count if controller else 1
		if not manager.is_game_active:
			completed += 1
		var winner_id := int(summary.get("winner_id", 0))
		var win_reason := str(summary.get("win_reason", ""))
		win_reason_counts[win_reason] = int(win_reason_counts.get(win_reason, 0)) + 1
		if winner_id == manager.first_player_id:
			first_player_wins += 1
		if winner_id == 1:
			player_one_wins += 1
		var rounds := int(summary.get("round_count", manager.round_count))
		total_rounds += rounds
		min_rounds = min(min_rounds, rounds)
		max_rounds = max(max_rounds, rounds)
		var first_damage_round := int(summary.get("first_hq_damage_round", 0))
		if first_damage_round > 0:
			total_first_hq_damage_round += first_damage_round
			measured_first_hq_damage_matches += 1
		var first_dominion_score_round := int(summary.get("first_dominion_score_round", 0))
		if first_dominion_score_round > 0:
			total_first_dominion_score_round += first_dominion_score_round
			measured_first_dominion_score_matches += 1
		var difficulty_name := MatchSetup.get_difficulty_name(difficulty)
		var difficulty_row := difficulty_results[difficulty_name] as Dictionary
		difficulty_row["matches"] = int(difficulty_row["matches"]) + 1
		difficulty_row["rounds"] = int(difficulty_row["rounds"]) + rounds
		if winner_id == manager.first_player_id:
			difficulty_row["first_player_wins"] = int(difficulty_row["first_player_wins"]) + 1
		_collect_openings(telemetry, opening_cards)
		_collect_card_performance(telemetry, winner_id, card_performance)

		battlefield.queue_free()
		current_scene = null
		await process_frame
		await process_frame

	var average_rounds := float(total_rounds) / float(match_count)
	var first_player_win_rate := float(first_player_wins) / float(match_count)
	var player_one_win_rate := float(player_one_wins) / float(match_count)
	var average_first_damage_round := (
		float(total_first_hq_damage_round) / float(measured_first_hq_damage_matches)
		if measured_first_hq_damage_matches > 0
		else 0.0
	)
	var average_first_dominion_score_round := (
		float(total_first_dominion_score_round) / float(measured_first_dominion_score_matches)
		if measured_first_dominion_score_matches > 0
		else 0.0
	)
	for difficulty_name in difficulty_results:
		var row := difficulty_results[difficulty_name] as Dictionary
		row["average_rounds"] = float(row["rounds"]) / float(max(1, int(row["matches"])))
		row["first_player_win_rate"] = float(row["first_player_wins"]) / float(max(1, int(row["matches"])))

	var report := {
		"matches": match_count,
		"match_offset": match_offset,
		"ruleset": "dominion" if use_dominion else "siege",
		"card_pool_mode": "all_cards" if use_all_cards else "deck",
		"completed": completed,
		"invalid_actions": invalid_actions,
		"average_rounds": snappedf(average_rounds, 0.01),
		"min_rounds": min_rounds,
		"max_rounds": max_rounds,
		"first_player_wins": first_player_wins,
		"first_player_win_rate": snappedf(first_player_win_rate, 0.001),
		"player_one_wins": player_one_wins,
		"player_one_win_rate": snappedf(player_one_win_rate, 0.001),
		"average_first_hq_damage_round": snappedf(average_first_damage_round, 0.01),
		"average_first_dominion_score_round": snappedf(average_first_dominion_score_round, 0.01),
		"win_reason_counts": win_reason_counts,
		"unique_opening_cards": opening_cards.size(),
		"maximum_frames": maximum_frames,
		"difficulty_results": difficulty_results,
		"card_performance_extremes": _get_card_performance_extremes(card_performance),
		"tracked_expansion_cards": _get_tracked_card_performance(card_performance),
	}
	print("PHASE_SEVEN_BALANCE_RESULTS ", JSON.stringify(report))

	_expect(completed == match_count, "%d otomatik maçın tamamı bitmeli" % match_count)
	_expect(invalid_actions == 0, "%d maçta geçersiz AI hamlesi olmamalı" % match_count)
	_expect(maximum_frames < FRAME_LIMIT, "Hiçbir otomatik maç zaman aşımına girmemeli")
	_expect(opening_cards.size() >= mini(4, match_count), "Tek bir zorunlu açılış yerine yeterli açılış çeşitliliği görülmeli")
	var extremes := _get_card_performance_extremes(card_performance)
	if match_count == MATCH_COUNT and match_offset == 0 and not use_all_cards and not use_dominion:
		_expect(average_rounds >= 8.0 and average_rounds <= SIEGE_AVERAGE_ROUND_MAX, "Ortalama raund sayısı 8–15 kabul bandında olmalı")
		_expect(first_player_win_rate >= 0.44 and first_player_win_rate <= 0.56, "İlk oyuncu kazanma oranı %44–56 kabul bandında olmalı")
		_expect(average_first_damage_round >= 3.0 and average_first_damage_round <= 7.0, "İlk Merkez hasarı açılışın hemen önüne geçmemeli")
		_expect(int(extremes.get("outlier_count", 0)) == 0, "Yeterli örnekli hiçbir kartın kullanım-kazanma oranı aşırı uçta olmamalı")
	if match_count == MATCH_COUNT and match_offset == 0 and not use_all_cards and use_dominion:
		_expect(average_rounds >= 4.0 and average_rounds <= 14.0, "Hakimiyet maç süresi 4–14 raund kabul bandında olmalı")
		_expect(first_player_win_rate >= 0.40 and first_player_win_rate <= 0.60, "Hakimiyet ilk oyuncu oranı %40–60 kabul bandında olmalı")
		_expect(player_one_win_rate >= 0.35 and player_one_win_rate <= 0.65, "Hakimiyet oyuncu kimliği oranı %35–65 kabul bandında olmalı")
		_expect(average_first_dominion_score_round >= 1.0 and average_first_dominion_score_round <= 4.0, "İlk Hakimiyet puanı ilk dört raund içinde gelmeli")
		_expect(int(win_reason_counts.get("dominion", 0)) >= int(ceil(match_count * 0.70)), "Hakimiyet maçlarının en az %70'i puan hedefiyle bitmeli")
	MatchSetup.configure_local(1)
	_finish()


func _collect_openings(telemetry: MatchTelemetry, openings: Dictionary) -> void:
	if not telemetry:
		return
	var seen_players: Dictionary = {}
	for event in telemetry.events:
		if str(event.get("event", "")) != "card_played":
			continue
		var player_id := int(event.get("player_id", 0))
		if seen_players.has(player_id):
			continue
		seen_players[player_id] = true
		var card_id := str(event.get("card_id", ""))
		if not card_id.is_empty():
			openings[card_id] = int(openings.get(card_id, 0)) + 1


func _collect_card_performance(
	telemetry: MatchTelemetry,
	winner_id: int,
	performance: Dictionary
) -> void:
	if not telemetry:
		return
	var seen_player_cards: Dictionary = {}
	for event in telemetry.events:
		if str(event.get("event", "")) != "card_played":
			continue
		var player_id := int(event.get("player_id", 0))
		var card_id := str(event.get("card_id", ""))
		if player_id == 0 or card_id.is_empty():
			continue
		var sample_key := "%d:%s" % [player_id, card_id]
		if seen_player_cards.has(sample_key):
			continue
		seen_player_cards[sample_key] = true
		var row: Dictionary = performance.get(card_id, {"uses": 0, "wins": 0})
		row["uses"] = int(row["uses"]) + 1
		if player_id == winner_id:
			row["wins"] = int(row["wins"]) + 1
		performance[card_id] = row


func _get_card_performance_extremes(performance: Dictionary) -> Dictionary:
	var highest := {"card_id": "", "uses": 0, "win_rate": 0.0}
	var lowest := {"card_id": "", "uses": 0, "win_rate": 1.0}
	var outlier_count := 0
	var measured_cards := 0
	for card_id_variant in performance:
		var card_id := str(card_id_variant)
		var row := performance[card_id] as Dictionary
		var uses := int(row.get("uses", 0))
		if uses < 10:
			continue
		measured_cards += 1
		var win_rate := float(row.get("wins", 0)) / float(uses)
		if win_rate > float(highest["win_rate"]):
			highest = {"card_id": card_id, "uses": uses, "win_rate": snappedf(win_rate, 0.001)}
		if win_rate < float(lowest["win_rate"]):
			lowest = {"card_id": card_id, "uses": uses, "win_rate": snappedf(win_rate, 0.001)}
		if win_rate < 0.20 or win_rate > 0.80:
			outlier_count += 1
	return {
		"measured_cards": measured_cards,
		"highest": highest,
		"lowest": lowest,
		"outlier_count": outlier_count,
	}


func _get_tracked_card_performance(performance: Dictionary) -> Dictionary:
	var tracked := {}
	for card_id in TRACKED_EXPANSION_CARD_IDS:
		var row := performance.get(card_id, {"uses": 0, "wins": 0}) as Dictionary
		var uses := int(row.get("uses", 0))
		var wins := int(row.get("wins", 0))
		tracked[card_id] = {
			"uses": uses,
			"wins": wins,
			"win_rate": snappedf(float(wins) / float(uses), 0.001) if uses > 0 else 0.0,
		}
	return tracked


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_SEVEN_BALANCE_SUITE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PHASE_SEVEN_BALANCE_SUITE_FAILED: %d" % _failures.size())
	quit(1)
