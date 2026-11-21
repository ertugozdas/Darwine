class_name ScenarioObjectiveResolver extends RefCounted


static func evaluate(context: Dictionary, summary: Dictionary, perspective_player_id: int) -> Dictionary:
	var objectives_variant: Variant = context.get("objectives", [])
	var objectives: Array = objectives_variant as Array if objectives_variant is Array else []
	var metrics := _player_metrics(summary, perspective_player_id)
	var winner_id := int(summary.get("winner_id", 0))
	var results: Array[Dictionary] = []
	var required_count := 0
	var completed_required_count := 0
	for objective_variant in objectives:
		if not objective_variant is Dictionary:
			continue
		var objective := objective_variant as Dictionary
		var metric := str(objective.get("metric", ""))
		var operator := str(objective.get("operator", "at_least"))
		var target := float(objective.get("target", 0.0))
		var required := bool(objective.get("required", true))
		var value := _metric_value(metric, metrics, winner_id, perspective_player_id)
		var completed := _compare(value, target, operator)
		if required:
			required_count += 1
			completed_required_count += 1 if completed else 0
		results.append({
			"id": str(objective.get("id", metric)),
			"metric": metric,
			"operator": operator,
			"target": target,
			"value": value,
			"required": required,
			"completed": completed,
		})
	return {
		"campaign_id": str(context.get("campaign_id", "")),
		"scenario_id": str(context.get("scenario_id", "")),
		"match_id": str(summary.get("match_id", "")),
		"completed": required_count > 0 and completed_required_count == required_count,
		"completed_required_count": completed_required_count,
		"required_count": required_count,
		"objective_results": results,
	}


static func metric_label(metric: String) -> String:
	match metric:
		"heroes_played": return "Oynanan Kahraman"
		"settlements_played": return "Oynanan Yapı"
		"special_powers_played": return "Kullanılan Büyü"
		"upgrades_played": return "Bağlanan Beceri"
		"cards_played": return "Oynanan Kart"
		"energy_spent": return "Harcanan Enerji"
		"unspent_energy_at_combat": return "Çatışmaya taşınan Enerji"
		"attacks_declared": return "Yapılan Saldırı"
		"hq_attacks": return "Merkez Saldırısı"
		"moves": return "Yapılan Hareket"
		"cross_lane_moves": return "Koridor Değişimi"
		"effect_resolutions": return "Çözülen Kart Etkisi"
		"effect_card_triggers": return "Etki Kartı Tetiklemesi"
		"cards_destroyed": return "Yok Edilen Kart"
		"hq_damage": return "Merkez Hasarı"
		"dominion_score": return "Hakimiyet Puanı"
		"match_won": return "Maçı Kazan"
		_: return metric.capitalize()


static func format_progress(result: Dictionary) -> String:
	var metric := str(result.get("metric", ""))
	if metric == "match_won":
		return "Tamamlandı" if bool(result.get("completed", false)) else "Bekliyor"
	var value := int(round(float(result.get("value", 0.0))))
	var target := int(round(float(result.get("target", 0.0))))
	var operator := str(result.get("operator", "at_least"))
	if operator == "at_most":
		return "%d / en fazla %d" % [value, target]
	if operator == "equals":
		return "%d / tam %d" % [value, target]
	return "%d / %d" % [mini(value, target), target]


static func _player_metrics(summary: Dictionary, player_id: int) -> Dictionary:
	var players_variant: Variant = summary.get("players", {})
	if not players_variant is Dictionary:
		return {}
	var players := players_variant as Dictionary
	var metrics_variant: Variant = players.get(player_id, players.get(str(player_id), {}))
	return (metrics_variant as Dictionary).duplicate(true) if metrics_variant is Dictionary else {}


static func _metric_value(metric: String, metrics: Dictionary, winner_id: int, player_id: int) -> float:
	if metric == "match_won":
		return 1.0 if winner_id == player_id else 0.0
	return float(metrics.get(metric, 0.0))


static func _compare(value: float, target: float, operator: String) -> bool:
	match operator:
		"at_most": return value <= target
		"equals": return is_equal_approx(value, target)
		_: return value >= target
