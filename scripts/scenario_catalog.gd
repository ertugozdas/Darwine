class_name ScenarioCatalog extends RefCounted

const CATALOG_PATH := "res://data/scenarios/v0_7_scenarios.json"
const SCHEMA_VERSION := 1
const RELEASE_VERSION := "0.7"
const MIN_TURN_DURATION_SECONDS := 15
const MAX_TURN_DURATION_SECONDS := 300

const SUPPORTED_RULESETS := ["siege", "dominion"]
const SUPPORTED_LESSONS := ["deployment", "energy", "open_lane", "movement", "effects", "dominion"]
const SUPPORTED_AI_DIFFICULTIES := ["easy", "medium", "hard"]
const SUPPORTED_DECK_IDS := ["muhafiz_hatti", "firtina_hucumu", "runik_kontrol"]
const SUPPORTED_EFFECT_CARD_IDS := [
	"",
	"yapi_ustalari",
	"saha_hekimleri",
	"kanat_manevrasi",
	"oncu_doktrini",
	"gizli_cephanelik",
	"koruyucu_yemin",
	"kusatma_plani",
	"dovme_ocagi",
	"ikmal_hatti",
	"son_direnis",
	"muhafiz_nobeti",
	"usta_zanaatkarlar",
	"ilkel_uyum",
]
const SUPPORTED_OBJECTIVE_OPERATORS := ["at_least", "at_most", "equals"]
const SUPPORTED_OBJECTIVE_METRICS := [
	"heroes_played",
	"settlements_played",
	"special_powers_played",
	"upgrades_played",
	"cards_played",
	"energy_spent",
	"unspent_energy_at_combat",
	"attacks_declared",
	"hq_attacks",
	"moves",
	"cross_lane_moves",
	"effect_resolutions",
	"effect_card_triggers",
	"cards_destroyed",
	"hq_damage",
	"dominion_score",
	"match_won",
]
const SUPPORTED_REWARD_KINDS := ["seals", "title", "banner"]

static var _loaded := false
static var _payload: Dictionary = {}
static var _scenarios_by_id: Dictionary = {}
static var _ordered_scenarios: Array[Dictionary] = []


static func load_catalog(force_reload: bool = false) -> Dictionary:
	if _loaded and not force_reload:
		return {"success": true, "scenario_count": _ordered_scenarios.size()}
	clear_cache()
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if not file:
		return _failure("Senaryo kataloğu açılamadı: %s" % error_string(FileAccess.get_open_error()))
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var validation := validate_catalog(parsed)
	if not bool(validation.get("success", false)):
		return validation
	_payload = (parsed as Dictionary).duplicate(true)
	for scenario_variant in _payload.get("scenarios", []) as Array:
		var scenario := (scenario_variant as Dictionary).duplicate(true)
		var scenario_id := str(scenario.get("id", ""))
		_scenarios_by_id[scenario_id] = scenario
		_ordered_scenarios.append(scenario)
	_ordered_scenarios.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("order", 0)) < int(right.get("order", 0))
	)
	_loaded = true
	return {"success": true, "scenario_count": _ordered_scenarios.size()}


static func clear_cache() -> void:
	_loaded = false
	_payload.clear()
	_scenarios_by_id.clear()
	_ordered_scenarios.clear()


static func get_campaign() -> Dictionary:
	if not _ensure_loaded():
		return {}
	return {
		"campaign_id": str(_payload.get("campaign_id", "")),
		"campaign_title": str(_payload.get("campaign_title", "")),
		"release_version": str(_payload.get("release_version", "")),
		"schema_version": int(_payload.get("schema_version", 0)),
		"scenario_count": _ordered_scenarios.size(),
	}


static func get_scenarios() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _ensure_loaded():
		return result
	for scenario in _ordered_scenarios:
		result.append(scenario.duplicate(true))
	return result


static func get_scenario(scenario_id: String) -> Dictionary:
	if not _ensure_loaded() or not _scenarios_by_id.has(scenario_id):
		return {}
	return (_scenarios_by_id[scenario_id] as Dictionary).duplicate(true)


static func build_match_context(scenario_id: String) -> Dictionary:
	var scenario := get_scenario(scenario_id)
	if scenario.is_empty():
		return {}
	return {
		"campaign_id": str(_payload.get("campaign_id", "")),
		"campaign_version": str(_payload.get("release_version", "")),
		"scenario_id": str(scenario.get("id", "")),
		"scenario_order": int(scenario.get("order", 0)),
		"content_version": int(scenario.get("content_version", 1)),
		"lesson": str(scenario.get("lesson", "")),
		"objectives": (scenario.get("objectives", []) as Array).duplicate(true),
	}


static func validate_catalog(payload_variant: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not payload_variant is Dictionary:
		return _failure("Senaryo kataloğu bir JSON nesnesi olmalı.")
	var payload := payload_variant as Dictionary
	if int(payload.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version %d olmalı." % SCHEMA_VERSION)
	if str(payload.get("release_version", "")) != RELEASE_VERSION:
		errors.append("release_version %s olmalı." % RELEASE_VERSION)
	if str(payload.get("campaign_id", "")).strip_edges().is_empty():
		errors.append("campaign_id eksik.")
	if str(payload.get("campaign_title", "")).strip_edges().is_empty():
		errors.append("campaign_title eksik.")
	var scenarios_variant: Variant = payload.get("scenarios", [])
	if not scenarios_variant is Array or (scenarios_variant as Array).is_empty():
		errors.append("scenarios boş olmayan bir dizi olmalı.")
		return _validation_result(errors)

	var scenario_ids := {}
	var scenario_orders := {}
	var scenario_rows: Array[Dictionary] = []
	for index in range((scenarios_variant as Array).size()):
		var row_variant: Variant = (scenarios_variant as Array)[index]
		var path := "scenarios[%d]" % index
		if not row_variant is Dictionary:
			errors.append("%s nesne olmalı." % path)
			continue
		var scenario := row_variant as Dictionary
		scenario_rows.append(scenario)
		_validate_scenario(scenario, path, errors)
		var scenario_id := str(scenario.get("id", ""))
		var order := int(scenario.get("order", 0))
		if not scenario_id.is_empty():
			if scenario_ids.has(scenario_id):
				errors.append("%s kimliği yineleniyor." % scenario_id)
			scenario_ids[scenario_id] = true
			scenario_orders[scenario_id] = order
		if order > 0:
			if scenario_orders.has("order_%d" % order):
				errors.append("%d senaryo sırası yineleniyor." % order)
			scenario_orders["order_%d" % order] = true

	for scenario in scenario_rows:
		var scenario_id := str(scenario.get("id", ""))
		var order := int(scenario.get("order", 0))
		var unlock_variant: Variant = scenario.get("unlock", {})
		if not unlock_variant is Dictionary:
			continue
		var requirements_variant: Variant = (unlock_variant as Dictionary).get("requires", [])
		if not requirements_variant is Array:
			continue
		for requirement_variant in requirements_variant as Array:
			var requirement := str(requirement_variant)
			if not scenario_ids.has(requirement):
				errors.append("%s bilinmeyen önkoşul %s kullanıyor." % [scenario_id, requirement])
			elif int(scenario_orders.get(requirement, 0)) >= order:
				errors.append("%s önkoşulu daha önceki bir senaryo olmalı." % scenario_id)
	for expected_order in range(1, scenario_rows.size() + 1):
		if not scenario_orders.has("order_%d" % expected_order):
			errors.append("Senaryo sırası 1–%d arasında kesintisiz olmalı." % scenario_rows.size())
			break

	return _validation_result(errors)


static func _validate_scenario(scenario: Dictionary, path: String, errors: Array[String]) -> void:
	var scenario_id := str(scenario.get("id", ""))
	if scenario_id.is_empty() or scenario_id != scenario_id.to_lower() or " " in scenario_id:
		errors.append("%s.id küçük harfli ve boşluksuz olmalı." % path)
	if int(scenario.get("order", 0)) <= 0:
		errors.append("%s.order pozitif olmalı." % path)
	if int(scenario.get("content_version", 0)) <= 0:
		errors.append("%s.content_version pozitif olmalı." % path)
	for key in ["title", "summary"]:
		if str(scenario.get(key, "")).strip_edges().is_empty():
			errors.append("%s.%s eksik." % [path, key])
	if str(scenario.get("lesson", "")) not in SUPPORTED_LESSONS:
		errors.append("%s.lesson desteklenmiyor." % path)
	if str(scenario.get("ruleset", "")) not in SUPPORTED_RULESETS:
		errors.append("%s.ruleset desteklenmiyor." % path)
	var setup_variant: Variant = scenario.get("setup", {})
	if setup_variant is Dictionary:
		_validate_setup(setup_variant as Dictionary, "%s.setup" % path, errors)
	else:
		errors.append("%s.setup nesne olmalı." % path)
	var objectives_variant: Variant = scenario.get("objectives", [])
	if objectives_variant is Array and not (objectives_variant as Array).is_empty():
		_validate_objectives(objectives_variant as Array, "%s.objectives" % path, errors)
	else:
		errors.append("%s.objectives boş olmayan bir dizi olmalı." % path)
	var unlock_variant: Variant = scenario.get("unlock", {})
	if not unlock_variant is Dictionary or not (unlock_variant as Dictionary).get("requires", []) is Array:
		errors.append("%s.unlock.requires dizi olmalı." % path)
	var reward_variant: Variant = scenario.get("reward", {})
	if reward_variant is Dictionary:
		_validate_reward(reward_variant as Dictionary, "%s.reward" % path, errors)
	else:
		errors.append("%s.reward nesne olmalı." % path)


static func _validate_setup(setup: Dictionary, path: String, errors: Array[String]) -> void:
	for key in ["player_deck_id", "opponent_deck_id"]:
		if str(setup.get(key, "")) not in SUPPORTED_DECK_IDS:
			errors.append("%s.%s desteklenen bir başlangıç destesi olmalı." % [path, key])
	if str(setup.get("ai_difficulty", "")) not in SUPPORTED_AI_DIFFICULTIES:
		errors.append("%s.ai_difficulty desteklenmiyor." % path)
	if int(setup.get("forced_first_player_id", 0)) not in [1, 2]:
		errors.append("%s.forced_first_player_id 1 veya 2 olmalı." % path)
	var duration := int(setup.get("turn_duration_seconds", 0))
	if duration < MIN_TURN_DURATION_SECONDS or duration > MAX_TURN_DURATION_SECONDS:
		errors.append("%s.turn_duration_seconds %d–%d aralığında olmalı." % [path, MIN_TURN_DURATION_SECONDS, MAX_TURN_DURATION_SECONDS])
	if not setup.get("auto_attack_allowed", false) is bool:
		errors.append("%s.auto_attack_allowed boolean olmalı." % path)
	for key in ["player_effect_card_id", "opponent_effect_card_id"]:
		if not setup.get(key, "") is String or str(setup.get(key, "")) not in SUPPORTED_EFFECT_CARD_IDS:
			errors.append("%s.%s desteklenen bir Etki Kartı olmalı." % [path, key])


static func _validate_objectives(objectives: Array, path: String, errors: Array[String]) -> void:
	var ids := {}
	for index in range(objectives.size()):
		var objective_variant: Variant = objectives[index]
		var objective_path := "%s[%d]" % [path, index]
		if not objective_variant is Dictionary:
			errors.append("%s nesne olmalı." % objective_path)
			continue
		var objective := objective_variant as Dictionary
		var objective_id := str(objective.get("id", ""))
		if objective_id.is_empty():
			errors.append("%s.id eksik." % objective_path)
		elif ids.has(objective_id):
			errors.append("%s içinde %s yineleniyor." % [path, objective_id])
		ids[objective_id] = true
		if str(objective.get("metric", "")) not in SUPPORTED_OBJECTIVE_METRICS:
			errors.append("%s.metric desteklenmiyor." % objective_path)
		if str(objective.get("operator", "")) not in SUPPORTED_OBJECTIVE_OPERATORS:
			errors.append("%s.operator desteklenmiyor." % objective_path)
		if float(objective.get("target", -1.0)) < 0.0:
			errors.append("%s.target negatif olamaz." % objective_path)
		if not objective.get("required", true) is bool:
			errors.append("%s.required boolean olmalı." % objective_path)


static func _validate_reward(reward: Dictionary, path: String, errors: Array[String]) -> void:
	var kind := str(reward.get("kind", ""))
	if kind not in SUPPORTED_REWARD_KINDS:
		errors.append("%s.kind desteklenmiyor." % path)
	elif kind == "seals" and int(reward.get("amount", 0)) <= 0:
		errors.append("%s.amount pozitif olmalı." % path)
	elif kind in ["title", "banner"] and str(reward.get("id", "")).is_empty():
		errors.append("%s.id eksik." % path)


static func _ensure_loaded() -> bool:
	return bool(load_catalog().get("success", false))


static func _validation_result(errors: Array[String]) -> Dictionary:
	if errors.is_empty():
		return {"success": true}
	return {"success": false, "error": errors[0], "errors": errors.duplicate()}


static func _failure(message: String) -> Dictionary:
	return {"success": false, "error": message, "errors": [message]}
