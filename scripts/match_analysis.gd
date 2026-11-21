class_name MatchAnalysis extends RefCounted

## Builds a deterministic, player-perspective explanation from the match
## summary. The result contains localization keys and raw evidence only; it
## deliberately avoids claiming that a single action caused the outcome.

const ANALYSIS_SCHEMA_VERSION := 1
const LANE_IDS := [
	CardSlot.Lane.CENTER,
	CardSlot.Lane.LEFT,
	CardSlot.Lane.RIGHT,
]


static func analyze(summary: Dictionary, perspective_player_id: int) -> Dictionary:
	if perspective_player_id not in GameRules.PLAYER_IDS:
		return {
			"valid": false,
			"analysis_schema_version": ANALYSIS_SCHEMA_VERSION,
			"error": "invalid_perspective",
		}
	var opponent_player_id := 2 if perspective_player_id == 1 else 1
	var player := _player_metrics(summary, perspective_player_id)
	var opponent := _player_metrics(summary, opponent_player_id)
	var ruleset := int(summary.get("ruleset", MatchSetup.Ruleset.SIEGE))
	var winner_id := int(summary.get("winner_id", 0))
	var result_id := "draw"
	if winner_id in GameRules.PLAYER_IDS:
		result_id = "victory" if winner_id == perspective_player_id else "defeat"
	var energy := _build_energy_section(player)
	var pressure := _build_pressure_section(player, opponent, ruleset)
	var movement := _build_movement_section(player, summary)
	var critical_lane := _build_critical_lane(
		player,
		opponent,
		summary,
		perspective_player_id,
		opponent_player_id,
		ruleset
	)
	return {
		"valid": true,
		"analysis_schema_version": ANALYSIS_SCHEMA_VERSION,
		"telemetry_schema_version": int(summary.get("telemetry_schema_version", 0)),
		"perspective_player_id": perspective_player_id,
		"opponent_player_id": opponent_player_id,
		"ruleset": ruleset,
		"ruleset_id": "dominion" if ruleset == MatchSetup.Ruleset.DOMINION else "siege",
		"result_id": result_id,
		"critical_lane": critical_lane,
		"energy": energy,
		"pressure": pressure,
		"movement": movement,
		"insights": [
			_build_energy_insight(energy),
			_build_pressure_insight(pressure, ruleset),
			_build_movement_insight(movement),
		],
	}


static func _build_energy_section(player: Dictionary) -> Dictionary:
	var spent := maxi(0, int(player.get("energy_spent", 0)))
	var unspent_total := maxi(0, int(player.get("unspent_energy_at_combat", 0)))
	var combat_phases := maxi(0, int(player.get("combat_phases", 0)))
	var average_unspent := 0.0
	if combat_phases > 0:
		average_unspent = float(unspent_total) / float(combat_phases)
	return {
		"energy_spent": spent,
		"unspent_energy_at_combat": unspent_total,
		"combat_phases": combat_phases,
		"max_unspent_energy_at_combat": maxi(0, int(player.get("max_unspent_energy_at_combat", 0))),
		"average_unspent_energy": snappedf(average_unspent, 0.1),
	}


static func _build_pressure_section(player: Dictionary, opponent: Dictionary, ruleset: int) -> Dictionary:
	return {
		"attacks": maxi(0, int(player.get("attacks_declared", 0))),
		"hq_attacks": maxi(0, int(player.get("hq_attacks", 0))),
		"hq_damage": maxi(0, int(player.get("hq_damage", 0))),
		"dominion_score": maxi(0, int(player.get("dominion_score", 0))),
		"opponent_dominion_score": maxi(0, int(opponent.get("dominion_score", 0))),
		"dominion_points": maxi(0, int(player.get("dominion_points", player.get("dominion_lane_wins", 0)))),
		"is_dominion": ruleset == MatchSetup.Ruleset.DOMINION,
	}


static func _build_movement_section(player: Dictionary, summary: Dictionary) -> Dictionary:
	var moves := maxi(0, int(player.get("moves", 0)))
	var cross_lane_moves := mini(moves, maxi(0, int(player.get("cross_lane_moves", 0))))
	return {
		"moves": moves,
		"cross_lane_moves": cross_lane_moves,
		"cross_lane_ratio": snappedf(float(cross_lane_moves) / float(moves), 0.01) if moves > 0 else 0.0,
		"round_count": maxi(0, int(summary.get("round_count", 0))),
	}


static func _build_critical_lane(
	player: Dictionary,
	opponent: Dictionary,
	summary: Dictionary,
	perspective_player_id: int,
	opponent_player_id: int,
	ruleset: int
) -> Dictionary:
	var player_lanes := _lane_activity(player)
	var opponent_lanes := _lane_activity(opponent)
	var dominion_control := _last_dominion_control(
		summary,
		perspective_player_id,
		opponent_player_id
	)
	var selected_lane := int(CardSlot.Lane.CENTER)
	var selected_score := -1
	var selected_player_activity := {}
	var selected_opponent_activity := {}
	for lane_variant in LANE_IDS:
		var lane_id := int(lane_variant)
		var player_activity := _lane_entry(player_lanes, lane_id)
		var opponent_activity := _lane_entry(opponent_lanes, lane_id)
		var activity_score := (_activity_score(player_activity) * 2) + _activity_score(opponent_activity)
		if ruleset == MatchSetup.Ruleset.DOMINION:
			var control := _lane_entry(dominion_control, lane_id)
			activity_score += int(control.get("player", 0)) + int(control.get("opponent", 0))
		if activity_score > selected_score:
			selected_lane = lane_id
			selected_score = activity_score
			selected_player_activity = player_activity
			selected_opponent_activity = opponent_activity
	var selected_control := _lane_entry(dominion_control, selected_lane)
	var has_evidence := selected_score > 0
	var explanation_key := "Your decisions clustered here: %d deployments, %d attacks and %d cross-lane entries."
	var explanation_args: Array = [
		int(selected_player_activity.get("deployments", 0)),
		int(selected_player_activity.get("attacks", 0)),
		int(selected_player_activity.get("moves_in", 0)),
	]
	if ruleset == MatchSetup.Ruleset.DOMINION and not selected_control.is_empty():
		explanation_key = "This lane carried the strongest control contest: %d–%d control in the final snapshot."
		explanation_args = [
			int(selected_control.get("player", 0)),
			int(selected_control.get("opponent", 0)),
		]
	elif not has_evidence:
		explanation_key = "No lane produced enough activity for a confident critical-lane read."
		explanation_args = []
	return {
		"lane_id": selected_lane,
		"lane_name_key": _lane_name_key(selected_lane),
		"activity_score": maxi(0, selected_score),
		"has_evidence": has_evidence,
		"confidence_id": "high" if selected_score >= 16 else ("medium" if selected_score >= 6 else "low"),
		"player_activity": selected_player_activity.duplicate(true),
		"opponent_activity": selected_opponent_activity.duplicate(true),
		"player_control": int(selected_control.get("player", 0)),
		"opponent_control": int(selected_control.get("opponent", 0)),
		"explanation_key": explanation_key,
		"explanation_args": explanation_args,
	}


static func _build_energy_insight(energy: Dictionary) -> Dictionary:
	var phases := int(energy.get("combat_phases", 0))
	var average := float(energy.get("average_unspent_energy", 0.0))
	var spent := int(energy.get("energy_spent", 0))
	if phases <= 0:
		return _insight(
			"energy_evidence",
			"energy",
			"neutral",
			"ENERGY DISCIPLINE",
			"There was not enough Combat-phase Energy data for a confident read."
		)
	if average >= 3.0:
		return _insight(
			"energy_reserve",
			"energy",
			"opportunity",
			"ENERGY DISCIPLINE",
			"You carried %.1f Energy into Combat on average. Try converting more of it into deployment or movement before attacking.",
			[average]
		)
	return _insight(
		"energy_conversion",
		"energy",
		"strength" if average <= 1.0 else "neutral",
		"ENERGY DISCIPLINE",
		"You entered Combat with %.1f unspent Energy on average and converted %d Energy into actions.",
		[average, spent]
	)


static func _build_pressure_insight(pressure: Dictionary, ruleset: int) -> Dictionary:
	if ruleset == MatchSetup.Ruleset.DOMINION:
		var score := int(pressure.get("dominion_score", 0))
		var opponent_score := int(pressure.get("opponent_dominion_score", 0))
		if score > opponent_score:
			return _insight(
				"dominion_edge",
				"pressure",
				"strength",
				"LANE CONTROL",
				"You converted lane control into %d Dominion points against %d.",
				[score, opponent_score]
			)
		if score < opponent_score:
			return _insight(
				"dominion_gap",
				"pressure",
				"opportunity",
				"LANE CONTROL",
				"The opponent converted lane control into %d points against your %d. Contest the scoring lane before ending the round.",
				[opponent_score, score]
			)
		return _insight(
			"dominion_even",
			"pressure",
			"neutral",
			"LANE CONTROL",
			"Dominion control finished level at %d–%d; the next lane swing decides the edge.",
			[score, opponent_score]
		)
	var attacks := int(pressure.get("attacks", 0))
	var hq_attacks := int(pressure.get("hq_attacks", 0))
	var hq_damage := int(pressure.get("hq_damage", 0))
	if hq_attacks > 0 and hq_damage > 0:
		return _insight(
			"hq_conversion",
			"pressure",
			"strength",
			"HEADQUARTERS PRESSURE",
			"You turned %d Headquarters attacks into %d damage.",
			[hq_attacks, hq_damage]
		)
	if hq_attacks > 0:
		return _insight(
			"hq_blocked",
			"pressure",
			"opportunity",
			"HEADQUARTERS PRESSURE",
			"%d Headquarters attacks produced no recorded Headquarters damage. Recheck attack order and blockers.",
			[hq_attacks]
		)
	if attacks > 0:
		return _insight(
			"hq_window",
			"pressure",
			"opportunity",
			"HEADQUARTERS PRESSURE",
			"%d attacks produced no Headquarters attempt. Opening one lane earlier may create direct pressure.",
			[attacks]
		)
	return _insight(
		"attack_evidence",
		"pressure",
		"opportunity",
		"HEADQUARTERS PRESSURE",
		"No attack decision was recorded; build a lane that can threaten the Headquarters."
	)


static func _build_movement_insight(movement: Dictionary) -> Dictionary:
	var moves := int(movement.get("moves", 0))
	var cross_lane_moves := int(movement.get("cross_lane_moves", 0))
	var rounds := int(movement.get("round_count", 0))
	if cross_lane_moves >= 2 or (moves > 0 and float(cross_lane_moves) / float(moves) >= 0.5):
		return _insight(
			"lane_redirect",
			"movement",
			"strength",
			"LANE MOVEMENT",
			"You used %d cross-lane moves across %d moves to redirect pressure.",
			[cross_lane_moves, moves]
		)
	if moves <= 0:
		return _insight(
			"lane_static",
			"movement",
			"opportunity" if rounds >= 3 else "neutral",
			"LANE MOVEMENT",
			"No cross-lane move was recorded across %d rounds. A single transfer can reinforce the critical lane.",
			[rounds]
		)
	return _insight(
		"lane_transfer",
		"movement",
		"opportunity",
		"LANE MOVEMENT",
		"Only %d of %d moves changed lanes. Look for an earlier transfer into the contested lane.",
		[cross_lane_moves, moves]
	)


static func _insight(
	id: String,
	category: String,
	tone: String,
	title_key: String,
	body_key: String,
	body_args: Array = []
) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"tone": tone,
		"title_key": title_key,
		"body_key": body_key,
		"body_args": body_args.duplicate(true),
	}


static func _player_metrics(summary: Dictionary, player_id: int) -> Dictionary:
	var players_variant: Variant = summary.get("players", {})
	if not players_variant is Dictionary:
		return {}
	var players := players_variant as Dictionary
	var metrics_variant: Variant = players.get(player_id, players.get(str(player_id), {}))
	return (metrics_variant as Dictionary).duplicate(true) if metrics_variant is Dictionary else {}


static func _lane_activity(player: Dictionary) -> Dictionary:
	var activity_variant: Variant = player.get("lane_activity", {})
	return (activity_variant as Dictionary).duplicate(true) if activity_variant is Dictionary else {}


static func _lane_entry(lanes: Dictionary, lane_id: int) -> Dictionary:
	var entry_variant: Variant = lanes.get(lane_id, lanes.get(str(lane_id), {}))
	return (entry_variant as Dictionary).duplicate(true) if entry_variant is Dictionary else {}


static func _activity_score(activity: Dictionary) -> int:
	return (
		int(activity.get("deployments", 0)) * 2
		+ int(activity.get("attacks", 0)) * 3
		+ int(activity.get("hq_attacks", 0)) * 4
		+ int(activity.get("moves_in", 0)) * 2
		+ int(activity.get("moves_out", 0))
		+ int(activity.get("effect_damage", 0))
		+ int(activity.get("cards_destroyed", 0)) * 4
	)


static func _last_dominion_control(
	summary: Dictionary,
	perspective_player_id: int,
	opponent_player_id: int
) -> Dictionary:
	var control_by_lane := {}
	var results_variant: Variant = summary.get("last_dominion_lane_results", [])
	if not results_variant is Array:
		return control_by_lane
	for result_variant in results_variant as Array:
		if not result_variant is Dictionary:
			continue
		var result := result_variant as Dictionary
		var lane_id := int(result.get("lane_id", -1))
		if lane_id not in [CardSlot.Lane.LEFT, CardSlot.Lane.CENTER, CardSlot.Lane.RIGHT]:
			continue
		var control_variant: Variant = result.get("control", {})
		var control := control_variant as Dictionary if control_variant is Dictionary else {}
		control_by_lane[str(lane_id)] = {
			"player": int(control.get(perspective_player_id, control.get(str(perspective_player_id), 0))),
			"opponent": int(control.get(opponent_player_id, control.get(str(opponent_player_id), 0))),
		}
	return control_by_lane


static func _lane_name_key(lane_id: int) -> String:
	match lane_id:
		CardSlot.Lane.LEFT:
			return "LEFT"
		CardSlot.Lane.RIGHT:
			return "RIGHT"
		_:
			return "CENTER"
