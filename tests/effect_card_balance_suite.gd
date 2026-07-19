extends SceneTree

const MATCHES_PER_CARD := 6
const FRAME_LIMIT := 1200
const BASE_SEED := 917_000

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	CardDatabase.load_all(true)
	var effect_ids := EffectCardCatalog.get_all_ids()
	var requested_samples := int(OS.get_environment("TDM_EFFECT_BALANCE_MATCHES_PER_CARD"))
	var matches_per_card := requested_samples if requested_samples > 0 else MATCHES_PER_CARD
	_expect(effect_ids.size() == 13, "Denge paketi tam 13 Etki Kartını kapsamalı")
	if effect_ids.size() < 2:
		_finish()
		return

	var rows: Dictionary = {}
	var completed_matches := 0
	var invalid_actions := 0
	var selection_mismatches := 0
	var selection_mismatch_details: Array[Dictionary] = []
	var maximum_frames := 0
	var signature_parts: Array[String] = []
	for effect_id in effect_ids:
		var card_data := CardDatabase.get_card("effects", effect_id)
		rows[effect_id] = {
			"card_id": effect_id,
			"name": str(card_data.get("name", effect_id)),
			"rarity": str(card_data.get("rarity", "COMMON")),
			"matches": 0,
			"wins": 0,
			"losses": 0,
			"first_player_matches": 0,
			"first_player_wins": 0,
			"rounds": 0,
			"triggers": 0,
			"triggered_matches": 0,
			"zero_trigger_matches": 0,
			"opponents": {},
		}

	for effect_index in range(effect_ids.size()):
		var effect_id := effect_ids[effect_index]
		for sample_index in range(matches_per_card):
			# Every card receives the same deterministic seed schedule. Opponents
			# rotate without mirror matches, while seat and first-player advantage
			# are balanced in blocks of four samples.
			var opponent_offset := 1 + (sample_index % (effect_ids.size() - 1))
			var opponent_effect_id := effect_ids[(effect_index + opponent_offset) % effect_ids.size()]
			var focal_player := 1 if sample_index % 2 == 0 else 2
			var opponent_player := 2 if focal_player == 1 else 1
			var first_player := 1 if int(sample_index / 2) % 2 == 0 else 2
			var seed_value := BASE_SEED + sample_index * 7919

			MatchSetup.configure_automated(
				seed_value,
				MatchSetup.AIDifficulty.MEDIUM,
				MatchSetup.AIDifficulty.MEDIUM,
				first_player
			)
			MatchSetup.set_forced_effect_card(focal_player, effect_id)
			MatchSetup.set_forced_effect_card(opponent_player, opponent_effect_id)

			var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
			root.add_child(battlefield)
			current_scene = battlefield
			var manager := battlefield.get_node("GameManager") as GameManager
			var frame_count := 0
			while manager.is_game_active and frame_count < FRAME_LIMIT:
				await process_frame
				frame_count += 1
			maximum_frames = maxi(maximum_frames, frame_count)

			var controller := battlefield.get_ai_controller()
			invalid_actions += controller.invalid_action_count if controller else 1
			if not manager.is_game_active:
				completed_matches += 1
			var selected_focal := manager.get_selected_effect_card(focal_player)
			var selected_opponent := manager.get_selected_effect_card(opponent_player)
			if selected_focal != effect_id or selected_opponent != opponent_effect_id:
				selection_mismatches += 1
				selection_mismatch_details.append({
					"expected_focal": effect_id,
					"selected_focal": selected_focal,
					"expected_opponent": opponent_effect_id,
					"selected_opponent": selected_opponent,
					"focal_player": focal_player,
				})

			var telemetry := battlefield.get_match_telemetry()
			var summary: Dictionary = telemetry.get_summary() if telemetry else {}
			var winner_id := int(summary.get("winner_id", 0))
			var rounds := int(summary.get("round_count", manager.round_count))
			var trigger_count := int(manager.effect_trigger_totals.get(focal_player, 0))
			var row := rows[effect_id] as Dictionary
			row["matches"] = int(row["matches"]) + 1
			row["rounds"] = int(row["rounds"]) + rounds
			row["triggers"] = int(row["triggers"]) + trigger_count
			if winner_id == focal_player:
				row["wins"] = int(row["wins"]) + 1
			else:
				row["losses"] = int(row["losses"]) + 1
			if first_player == focal_player:
				row["first_player_matches"] = int(row["first_player_matches"]) + 1
				if winner_id == focal_player:
					row["first_player_wins"] = int(row["first_player_wins"]) + 1
			if trigger_count > 0:
				row["triggered_matches"] = int(row["triggered_matches"]) + 1
			else:
				row["zero_trigger_matches"] = int(row["zero_trigger_matches"]) + 1
			var opponents := row["opponents"] as Dictionary
			opponents[opponent_effect_id] = int(opponents.get(opponent_effect_id, 0)) + 1
			row["opponents"] = opponents
			rows[effect_id] = row
			signature_parts.append("%s:%s:%d:%d:%d" % [
				effect_id,
				opponent_effect_id,
				winner_id,
				rounds,
				trigger_count,
			])

			battlefield.queue_free()
			current_scene = null
			await process_frame
			await process_frame

	var balance_signals: Array[Dictionary] = []
	for effect_id in effect_ids:
		var row := rows[effect_id] as Dictionary
		var matches := maxi(1, int(row.get("matches", 0)))
		var wins := int(row.get("wins", 0))
		var interval := _wilson_interval(wins, matches)
		row["win_rate"] = snappedf(float(wins) / float(matches), 0.001)
		row["average_rounds"] = snappedf(float(row.get("rounds", 0)) / float(matches), 0.01)
		row["average_triggers"] = snappedf(float(row.get("triggers", 0)) / float(matches), 0.01)
		row["triggered_match_rate"] = snappedf(float(row.get("triggered_matches", 0)) / float(matches), 0.001)
		row["win_rate_wilson_95"] = interval
		row.erase("rounds")

		var balance_signal := "normal"
		var reason := "Küçük örneklemde açık bir uç değer yok."
		if int(row.get("triggers", 0)) == 0:
			balance_signal = "etkisiz_sinyali"
			reason = "Üretim AI maçlarında hiç tetiklenmedi."
		elif matches >= 12 and float(interval.get("low", 0.0)) > 0.60:
			balance_signal = "baskin_sinyali"
			reason = "%95 Wilson alt sınırı %60'ın üzerinde."
		elif matches >= 12 and float(interval.get("high", 1.0)) < 0.40:
			balance_signal = "zayif_sinyali"
			reason = "%95 Wilson üst sınırı %40'ın altında."
		elif int(row.get("triggered_matches", 0)) * 4 < matches:
			balance_signal = "dusuk_tetiklenme"
			reason = "Maçların dörtte birinden azında tetiklendi."
		row["balance_signal"] = balance_signal
		row["balance_reason"] = reason
		if balance_signal != "normal":
			balance_signals.append({"card_id": effect_id, "signal": balance_signal, "reason": reason})
		rows[effect_id] = row

	var expected_total := effect_ids.size() * matches_per_card
	var report := {
		"matches_per_card": matches_per_card,
		"total_matches": expected_total,
		"completed_matches": completed_matches,
		"invalid_actions": invalid_actions,
		"selection_mismatches": selection_mismatches,
		"selection_mismatch_details": selection_mismatch_details,
		"maximum_frames": maximum_frames,
		"difficulty": "Orta",
		"seed_schedule": "%d + sample*7919" % BASE_SEED,
		"deterministic_signature": "effect-balance-%08x" % "|".join(signature_parts).hash(),
		"balance_signals": balance_signals,
		"cards": rows,
	}
	print("EFFECT_CARD_BALANCE_RESULTS ", JSON.stringify(report))

	_expect(completed_matches == expected_total, "Tüm Etki Kartı denge maçları tamamlanmalı")
	_expect(invalid_actions == 0, "Etki Kartı denge maçlarında geçersiz AI hamlesi olmamalı")
	_expect(selection_mismatches == 0, "Zorlanan Etki Kartı seçimleri üretim akışında korunmalı")
	_expect(maximum_frames < FRAME_LIMIT, "Etki Kartı denge maçı zaman aşımına girmemeli")
	for effect_id in effect_ids:
		var row := rows[effect_id] as Dictionary
		_expect(int(row.get("matches", 0)) == matches_per_card, "%s için örnek sayısı eksik" % effect_id)
		_expect(int(row.get("triggers", 0)) > 0, "%s üretim AI maçlarında hiç tetiklenmedi" % effect_id)

	MatchSetup.configure_local(1)
	_finish()


func _wilson_interval(wins: int, matches: int) -> Dictionary:
	if matches <= 0:
		return {"low": 0.0, "high": 1.0}
	var z := 1.959963984540054
	var sample_size := float(matches)
	var rate := float(wins) / sample_size
	var denominator := 1.0 + z * z / sample_size
	var center := (rate + z * z / (2.0 * sample_size)) / denominator
	var margin := z * sqrt((rate * (1.0 - rate) + z * z / (4.0 * sample_size)) / sample_size) / denominator
	return {
		"low": snappedf(maxf(0.0, center - margin), 0.001),
		"high": snappedf(minf(1.0, center + margin), 0.001),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("EFFECT_CARD_BALANCE_SUITE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("EFFECT_CARD_BALANCE_SUITE_FAILED: %d" % _failures.size())
	quit(1)
