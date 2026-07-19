class_name MatchTelemetry extends Node

const DEFAULT_LOG_PATH := "user://match_telemetry.jsonl"

var events: Array[Dictionary] = []
var log_path := DEFAULT_LOG_PATH
var write_to_disk := true

var _game_manager: GameManager
var _ai_controller: AIController
var _match_id := ""
var _started := false
var _finished := false
var _start_ticks_msec := 0
var _first_hq_damage_round := 0
var _first_dominion_score_round := 0
var _invalid_actions := 0
var _dominion_points_awarded := {1: 0, 2: 0}
var _initial_hq_health := {
	1: GameRules.HEADQUARTERS_HEALTH,
	2: GameRules.HEADQUARTERS_HEALTH,
}


func setup(
	game_manager: GameManager,
	ai_controller: AIController = null,
	should_write_to_disk: bool = true,
	custom_log_path: String = DEFAULT_LOG_PATH
) -> void:
	_game_manager = game_manager
	_ai_controller = ai_controller
	write_to_disk = should_write_to_disk
	log_path = custom_log_path
	_match_id = "%d-%d" % [MatchSetup.match_seed, Time.get_ticks_usec()]
	_connect_signals()


func get_summary() -> Dictionary:
	var duration_seconds := float(_get_end_value("duration_seconds", 0.0))
	if duration_seconds <= 0.0 and _start_ticks_msec > 0:
		duration_seconds = float(Time.get_ticks_msec() - _start_ticks_msec) / 1000.0
	return {
		"match_id": _match_id,
		"match_name": MatchSetup.match_name,
		"seed": MatchSetup.match_seed,
		"ruleset": int(MatchSetup.ruleset),
		"ruleset_name": MatchSetup.get_ruleset_name(),
		"win_reason": str(_get_end_value("win_reason", _game_manager.win_reason if _game_manager else "")),
		"turn_duration_seconds": MatchSetup.turn_duration_seconds,
		"winner_id": _get_end_value("winner_id", 0),
		"first_player_id": _game_manager.first_player_id if _game_manager else 0,
		"turn_count": _game_manager.turn_count if _game_manager else 0,
		"round_count": _game_manager.round_count if _game_manager else 0,
		"first_hq_damage_round": _first_hq_damage_round,
		"first_dominion_score_round": _first_dominion_score_round,
		"dominion_scores": _game_manager.player_dominion_score.duplicate(true) if _game_manager else {1: 0, 2: 0},
		"dominion_lane_wins": _dominion_points_awarded.duplicate(true),
		"last_dominion_lane_results": _game_manager.last_dominion_lane_results.duplicate(true) if _game_manager else [],
		"invalid_actions": _invalid_actions,
		"event_count": events.size(),
		"duration_seconds": duration_seconds,
		"players": _build_player_summaries(),
		"finished": _finished,
	}


func _connect_signals() -> void:
	if not _game_manager:
		return
	_game_manager.mulligan_player_changed.connect(_on_mulligan_player_changed)
	_game_manager.turn_changed.connect(_on_turn_changed)
	_game_manager.phase_changed.connect(_on_phase_changed)
	_game_manager.energy_changed.connect(_on_energy_changed)
	_game_manager.hq_health_changed.connect(_on_hq_health_changed)
	_game_manager.fatigue_damage_applied.connect(_on_fatigue_damage_applied)
	_game_manager.card_played.connect(_on_card_played)
	_game_manager.attack_declared.connect(_on_attack_declared)
	_game_manager.card_moved.connect(_on_card_moved)
	_game_manager.effect_resolved.connect(_on_effect_resolved)
	_game_manager.card_destroyed.connect(_on_card_destroyed)
	_game_manager.experience_changed.connect(_on_experience_changed)
	_game_manager.card_leveled_up.connect(_on_card_leveled_up)
	_game_manager.dominion_score_changed.connect(_on_dominion_score_changed)
	_game_manager.dominion_round_resolved.connect(_on_dominion_round_resolved)
	_game_manager.game_over.connect(_on_game_over)
	if _ai_controller:
		_ai_controller.action_executed.connect(_on_ai_action_executed)
		_ai_controller.invalid_action.connect(_on_ai_invalid_action)


func _on_mulligan_player_changed(_player_id: int) -> void:
	if _started:
		return
	_started = true
	_start_ticks_msec = Time.get_ticks_msec()
	_record("match_start", {
		"match_name": MatchSetup.match_name,
		"ruleset": int(MatchSetup.ruleset),
		"ruleset_name": MatchSetup.get_ruleset_name(),
		"first_player_id": _game_manager.first_player_id,
		"ai_players": _get_ai_player_payload(),
		"deck_size": GameRules.DECK_SIZE,
		"turn_duration_seconds": _game_manager.turn_duration_seconds,
	})


func _on_turn_changed(player_id: int) -> void:
	if not _started:
		return
	_record("turn_start", {
		"player_id": player_id,
		"personal_turn": int(_game_manager.player_personal_turns.get(player_id, 0)),
	})


func _on_phase_changed(phase: GameManager.TurnPhase) -> void:
	if not _started:
		return
	var payload := {
		"player_id": _game_manager.active_player_id,
		"phase": int(phase),
		"phase_name": _game_manager.get_phase_display_name(),
	}
	if phase == GameManager.TurnPhase.COMBAT:
		payload["unspent_energy"] = _game_manager.get_available_energy(_game_manager.active_player_id)
	_record("phase_changed", payload)


func _on_energy_changed(player_id: int, current: int, maximum: int, temporary: int) -> void:
	if _started:
		_record("energy", {
			"player_id": player_id,
			"current": current,
			"maximum": maximum,
			"temporary": temporary,
		})


func _on_hq_health_changed(player_id: int, current: int, maximum: int) -> void:
	if not _started:
		return
	if current < int(_initial_hq_health.get(player_id, maximum)) and _first_hq_damage_round == 0:
		_first_hq_damage_round = _game_manager.round_count
	_initial_hq_health[player_id] = current
	_record("hq_health", {
		"player_id": player_id,
		"current": current,
		"maximum": maximum,
	})


func _on_fatigue_damage_applied(player_id: int, damage: int, failed_draw_count: int) -> void:
	_record("fatigue", {
		"player_id": player_id,
		"damage": damage,
		"failed_draw_count": failed_draw_count,
	})


func _on_card_played(card: BaseCard, target: BaseCard) -> void:
	_record("card_played", {
		"player_id": card.owner_id if card else 0,
		"card_id": card.card_id if card else "",
		"card_name": card.card_name if card else "",
		"card_type": card.get_class() if card else "",
		"energy_cost": card.energy_cost if card else 0,
		"target_card_id": target.card_id if target else "",
	})


func _on_attack_declared(attacker: BaseCard, target: BaseCard) -> void:
	_record("attack", {
		"player_id": attacker.owner_id if attacker else 0,
		"card_id": attacker.card_id if attacker else "",
		"target_card_id": target.card_id if target else "",
		"lane": int(attacker.current_slot.lane_id) if attacker and attacker.current_slot else -1,
		"target_is_hq": target.is_headquarters() if target else false,
	})


func _on_card_moved(card: BaseCard, from_slot: CardSlot, to_slot: CardSlot) -> void:
	_record("card_moved", {
		"player_id": card.owner_id if card else 0,
		"card_id": card.card_id if card else "",
		"from_lane": int(from_slot.lane_id) if from_slot else -1,
		"to_lane": int(to_slot.lane_id) if to_slot else -1,
	})


func _on_effect_resolved(
	effect_id: String,
	source: BaseCard,
	target: BaseCard,
	result: Dictionary
) -> void:
	_record("effect", {
		"effect_id": effect_id,
		"player_id": source.owner_id if source else 0,
		"source_card_id": source.card_id if source else "",
		"target_card_id": target.card_id if target else "",
		"damage": int(result.get("damage", 0)),
		"healed": int(result.get("healed", 0)),
		"destroyed": bool(result.get("destroyed", false)),
	})


func _on_card_destroyed(card: BaseCard, source: BaseCard) -> void:
	_record("card_destroyed", {
		"player_id": card.owner_id if card else 0,
		"card_id": card.card_id if card else "",
		"source_card_id": source.card_id if source else "",
		"source_player_id": source.owner_id if source else 0,
	})


func _on_experience_changed(card: BaseCard, current: int, gained: int, reason: String) -> void:
	_record("experience", {
		"player_id": card.owner_id if card else 0,
		"card_id": card.card_id if card else "",
		"current": current,
		"gained": gained,
		"reason": reason,
	})


func _on_card_leveled_up(card: BaseCard, level: int, branch_id: String) -> void:
	_record("level_up", {
		"player_id": card.owner_id if card else 0,
		"card_id": card.card_id if card else "",
		"level": level,
		"branch_id": branch_id,
	})


func _on_dominion_score_changed(player_id: int, current_score: int, target_score: int) -> void:
	if not _started or not MatchSetup.is_dominion():
		return
	_record("dominion_score", {
		"player_id": player_id,
		"current_score": current_score,
		"target_score": target_score,
	})


func _on_dominion_round_resolved(
	round_number: int,
	lane_results: Array,
	points_awarded: Dictionary,
	scores: Dictionary
) -> void:
	if not _started or not MatchSetup.is_dominion():
		return
	var total_control := {1: 0, 2: 0}
	for lane_variant in lane_results:
		if not lane_variant is Dictionary:
			continue
		var lane_result := lane_variant as Dictionary
		var control_variant: Variant = lane_result.get("control", {})
		if not control_variant is Dictionary:
			continue
		var control := control_variant as Dictionary
		for player_id in GameRules.PLAYER_IDS:
			total_control[player_id] = int(total_control[player_id]) + int(_dictionary_player_value(control, player_id, 0))
	var scored_this_round := false
	for player_id in GameRules.PLAYER_IDS:
		var awarded := maxi(0, int(_dictionary_player_value(points_awarded, player_id, 0)))
		_dominion_points_awarded[player_id] = int(_dominion_points_awarded.get(player_id, 0)) + awarded
		scored_this_round = scored_this_round or awarded > 0
	if scored_this_round and _first_dominion_score_round == 0:
		_first_dominion_score_round = round_number
	_record("dominion_round", {
		"round_number": round_number,
		"lane_results": lane_results.duplicate(true),
		"points_awarded": points_awarded.duplicate(true),
		"scores": scores.duplicate(true),
		"total_control": total_control,
	})


func _on_ai_action_executed(player_id: int, action: Dictionary) -> void:
	var payload := action.duplicate(true)
	payload["player_id"] = player_id
	_record("ai_action", payload)


func _on_ai_invalid_action(player_id: int, action: Dictionary, error: String) -> void:
	_invalid_actions += 1
	var payload := action.duplicate(true)
	payload["player_id"] = player_id
	payload["error"] = error
	_record("ai_invalid_action", payload)


func _on_game_over(winner_id: int) -> void:
	if _finished:
		return
	_finished = true
	var duration_seconds := 0.0
	if _start_ticks_msec > 0:
		duration_seconds = float(Time.get_ticks_msec() - _start_ticks_msec) / 1000.0
	_record("match_end", {
		"winner_id": winner_id,
		"ruleset": int(MatchSetup.ruleset),
		"ruleset_name": MatchSetup.get_ruleset_name(),
		"win_reason": _game_manager.win_reason,
		"dominion_scores": _game_manager.player_dominion_score.duplicate(true),
		"dominion_lane_wins": _dominion_points_awarded.duplicate(true),
		"first_dominion_score_round": _first_dominion_score_round,
		"first_player_id": _game_manager.first_player_id,
		"turn_count": _game_manager.turn_count,
		"round_count": _game_manager.round_count,
		"duration_seconds": duration_seconds,
		"first_hq_damage_round": _first_hq_damage_round,
		"invalid_actions": _invalid_actions,
		"failed_draws_p1": int(_game_manager.player_failed_draws.get(1, 0)),
		"failed_draws_p2": int(_game_manager.player_failed_draws.get(2, 0)),
	})


func _record(event_name: String, payload: Dictionary = {}) -> void:
	var event := payload.duplicate(true)
	event["event"] = event_name
	event["match_id"] = _match_id
	event["seed"] = MatchSetup.match_seed
	event["ruleset"] = int(MatchSetup.ruleset)
	event["ruleset_name"] = MatchSetup.get_ruleset_name()
	event["turn"] = _game_manager.turn_count if _game_manager else 0
	event["round"] = _game_manager.round_count if _game_manager else 0
	event["timestamp_utc"] = Time.get_datetime_string_from_system(true, true)
	events.append(event)
	if write_to_disk:
		_append_json_line(event)


func _append_json_line(event: Dictionary) -> void:
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE_READ
	var file := FileAccess.open(log_path, mode)
	if not file:
		push_warning("Maç telemetrisi açılamadı: %s" % error_string(FileAccess.get_open_error()))
		return
	file.seek_end()
	file.store_line(JSON.stringify(event))
	file.flush()


func _get_ai_player_payload() -> Array[Dictionary]:
	var payload: Array[Dictionary] = []
	for player_id in GameRules.PLAYER_IDS:
		if not MatchSetup.is_ai_player(player_id):
			continue
		payload.append({
			"player_id": player_id,
			"difficulty": MatchSetup.get_difficulty_name(MatchSetup.get_ai_difficulty(player_id)),
		})
	return payload


func _get_end_value(key: String, fallback: Variant) -> Variant:
	for index in range(events.size() - 1, -1, -1):
		var event := events[index]
		if str(event.get("event", "")) == "match_end":
			return event.get(key, fallback)
	return fallback


func _build_player_summaries() -> Dictionary:
	var players := {}
	var card_counts := {1: {}, 2: {}}
	for player_id in GameRules.PLAYER_IDS:
		players[player_id] = {
			"cards_played": 0,
			"energy_spent": 0,
			"effect_damage": 0,
			"healing": 0,
			"cards_destroyed": 0,
			"hq_damage": 0,
			"hq_remaining": GameRules.HEADQUARTERS_HEALTH,
			"dominion_score": 0,
			"dominion_points": 0,
			"dominion_lane_wins": 0,
			"mvp_card_name": "—",
		}
	for event in events:
		var event_name := str(event.get("event", ""))
		var player_id := int(event.get("player_id", 0))
		match event_name:
			"card_played":
				if player_id in GameRules.PLAYER_IDS:
					var metrics := players[player_id] as Dictionary
					metrics["cards_played"] = int(metrics.get("cards_played", 0)) + 1
					metrics["energy_spent"] = int(metrics.get("energy_spent", 0)) + int(event.get("energy_cost", 0))
					var card_name := str(event.get("card_name", event.get("card_id", "Kart")))
					var counts := card_counts[player_id] as Dictionary
					counts[card_name] = int(counts.get(card_name, 0)) + 1
			"effect":
				if player_id in GameRules.PLAYER_IDS:
					var metrics := players[player_id] as Dictionary
					metrics["effect_damage"] = int(metrics.get("effect_damage", 0)) + maxi(0, int(event.get("damage", 0)))
					metrics["healing"] = int(metrics.get("healing", 0)) + maxi(0, int(event.get("healed", 0)))
			"card_destroyed":
				var source_player_id := int(event.get("source_player_id", 0))
				if source_player_id in GameRules.PLAYER_IDS and source_player_id != player_id:
					var source_metrics := players[source_player_id] as Dictionary
					source_metrics["cards_destroyed"] = int(source_metrics.get("cards_destroyed", 0)) + 1

	for player_id in GameRules.PLAYER_IDS:
		var opponent_id := _game_manager.get_opponent_id(player_id) if _game_manager else (2 if player_id == 1 else 1)
		var opponent_health := GameRules.HEADQUARTERS_HEALTH
		var own_health := GameRules.HEADQUARTERS_HEALTH
		if _game_manager:
			opponent_health = int(_game_manager.player_hq_health.get(opponent_id, GameRules.HEADQUARTERS_HEALTH))
			own_health = int(_game_manager.player_hq_health.get(player_id, GameRules.HEADQUARTERS_HEALTH))
		var metrics := players[player_id] as Dictionary
		metrics["hq_damage"] = maxi(0, GameRules.HEADQUARTERS_HEALTH - opponent_health)
		metrics["hq_remaining"] = maxi(0, own_health)
		metrics["dominion_score"] = int(_game_manager.player_dominion_score.get(player_id, 0)) if _game_manager else 0
		metrics["dominion_points"] = int(_dominion_points_awarded.get(player_id, 0))
		metrics["dominion_lane_wins"] = int(_dominion_points_awarded.get(player_id, 0))
		var counts := card_counts[player_id] as Dictionary
		var best_name := "—"
		var best_count := 0
		for card_name_variant in counts.keys():
			var count := int(counts[card_name_variant])
			if count > best_count:
				best_count = count
				best_name = str(card_name_variant)
		metrics["mvp_card_name"] = best_name
	return players


func _dictionary_player_value(dictionary: Dictionary, player_id: int, fallback: Variant) -> Variant:
	if dictionary.has(player_id):
		return dictionary[player_id]
	return dictionary.get(str(player_id), fallback)
