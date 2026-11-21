class_name ScenarioMatchConfigurator extends RefCounted

const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")


static func configure(scenario_id: String, deck_repository: Node) -> Dictionary:
	var load_result := SCENARIO_CATALOG.load_catalog()
	if not bool(load_result.get("success", false)):
		return _failure(str(load_result.get("error", "Senaryo kataloğu yüklenemedi.")))
	var scenario := SCENARIO_CATALOG.get_scenario(scenario_id)
	if scenario.is_empty():
		return _failure("Senaryo bulunamadı: %s" % scenario_id)
	if not deck_repository or not deck_repository.has_method("get_deck"):
		return _failure("Başlangıç destelerini sağlayan deste deposu bulunamadı.")
	var setup_variant: Variant = scenario.get("setup", {})
	if not setup_variant is Dictionary:
		return _failure("Senaryo kurulumu geçersiz: %s" % scenario_id)
	var setup := setup_variant as Dictionary
	var player_deck_id := str(setup.get("player_deck_id", ""))
	var opponent_deck_id := str(setup.get("opponent_deck_id", ""))
	var player_deck_variant: Variant = deck_repository.get_deck(player_deck_id)
	var opponent_deck_variant: Variant = deck_repository.get_deck(opponent_deck_id)
	if not player_deck_variant is Dictionary or (player_deck_variant as Dictionary).is_empty():
		return _failure("Oyuncu başlangıç destesi bulunamadı: %s" % player_deck_id)
	if not opponent_deck_variant is Dictionary or (opponent_deck_variant as Dictionary).is_empty():
		return _failure("Rakip başlangıç destesi bulunamadı: %s" % opponent_deck_id)
	var player_deck := player_deck_variant as Dictionary
	var opponent_deck := opponent_deck_variant as Dictionary
	var player_cards_variant: Variant = player_deck.get("cards", [])
	var opponent_cards_variant: Variant = opponent_deck.get("cards", [])
	if not player_cards_variant is Array or (player_cards_variant as Array).is_empty():
		return _failure("Oyuncu başlangıç destesi boş: %s" % player_deck_id)
	if not opponent_cards_variant is Array or (opponent_cards_variant as Array).is_empty():
		return _failure("Rakip başlangıç destesi boş: %s" % opponent_deck_id)

	var difficulty := _difficulty_from_id(str(setup.get("ai_difficulty", "medium")))
	MatchSetup.configure_ai(difficulty)
	MatchSetup.set_ruleset(
		MatchSetup.Ruleset.DOMINION
		if str(scenario.get("ruleset", "siege")) == "dominion"
		else MatchSetup.Ruleset.SIEGE
	)
	MatchSetup.set_match_name(str(scenario.get("title", MatchSetup.get_default_match_name(MatchSetup.ruleset))))
	MatchSetup.set_turn_duration_seconds(float(setup.get("turn_duration_seconds", GameRules.TURN_DURATION_SECONDS)))
	MatchSetup.set_auto_attack_allowed(bool(setup.get("auto_attack_allowed", false)))
	MatchSetup.set_card_pool_mode(MatchSetup.CardPoolMode.DECK)
	MatchSetup.forced_first_player_id = int(setup.get("forced_first_player_id", 0))
	MatchSetup.set_forced_effect_card(1, str(setup.get("player_effect_card_id", "")))
	MatchSetup.set_forced_effect_card(2, str(setup.get("opponent_effect_card_id", "")))
	MatchSetup.set_player_deck(1, player_cards_variant as Array, str(player_deck.get("name", player_deck_id)))
	MatchSetup.set_player_deck(2, opponent_cards_variant as Array, str(opponent_deck.get("name", opponent_deck_id)))
	var context := SCENARIO_CATALOG.build_match_context(scenario_id)
	MatchSetup.set_scenario_context(context)
	return {
		"success": true,
		"scenario": scenario.duplicate(true),
		"context": context,
		"difficulty": difficulty,
	}


static func _difficulty_from_id(value: String) -> int:
	match value:
		"easy": return MatchSetup.AIDifficulty.EASY
		"hard": return MatchSetup.AIDifficulty.HARD
		_: return MatchSetup.AIDifficulty.MEDIUM


static func _failure(message: String) -> Dictionary:
	return {"success": false, "error": message}
