class_name DeckAdvisor extends RefCounted

## Deterministic, non-scoring deck guidance. Advice is derived only from the
## current playable card data so new cards automatically enter the same model.

const ADVISOR_SCHEMA_VERSION := 1
const ROLE_IDS := ["frontline", "pressure", "control", "sustain", "resource", "support"]
const MECHANIC_ORDER := [
	"guard", "siege", "ranged", "sustain", "control",
	"mobility", "resource", "area_damage", "drain", "spell_echo",
]
const MECHANIC_LABEL_KEYS := {
	"guard": "Guard package",
	"siege": "Siege pressure",
	"ranged": "Ranged reach",
	"sustain": "Sustain package",
	"control": "Control package",
	"mobility": "Mobility package",
	"resource": "Resource flow",
	"area_damage": "Area damage",
	"drain": "Life drain",
	"spell_echo": "Spell echo",
}
const RESOURCE_EFFECTS := ["energy_income", "building_discount", "draw_cards", "redraw_card", "spell_echo"]
const SUSTAIN_EFFECTS := ["heal_target", "repair_structure", "protect_target", "revive_last_hero", "lane_heal", "lane_protect", "lane_blocker"]
const CONTROL_EFFECTS := ["poison_target", "stun_target", "push_adjacent_lane", "detach_skill", "lane_poison", "lane_ready", "banish_target"]
const PRESSURE_EFFECTS := ["damage_target", "damage_lane", "blood_price", "ranged_defense", "lane_training"]
const FRONTLINE_TAGS := ["guard", "bulwark", "steadfast", "retaliate"]
const SUSTAIN_TAGS := ["healer", "lifesteal", "soulbond", "starlight_ward"]
const CONTROL_TAGS := ["petrify", "gravity_well", "time_thief", "fog_weaver", "void_bite", "spore_drift"]
const PRESSURE_TAGS := ["fast", "siege", "ranged", "cleave", "afterburn", "war_banner"]

static var _playable_lookup: Dictionary = {}


static func analyze(cards_variant: Variant) -> Dictionary:
	var cards: Array = cards_variant as Array if cards_variant is Array else []
	var types := {
		"heroes": 0,
		"settlements": 0,
		"special_powers": 0,
		"upgrades": 0,
	}
	var roles := {}
	for role_id in ROLE_IDS:
		roles[role_id] = 0
	var buckets := {
		"cost_0_1": 0,
		"cost_2": 0,
		"cost_3": 0,
		"cost_4": 0,
		"cost_5_plus": 0,
	}
	var mechanics := {}
	for mechanic_id in MECHANIC_ORDER:
		mechanics[mechanic_id] = 0
	var copies := {}
	var valid_count := 0
	var invalid_count := 0
	var energy_total := 0
	var hero_target_upgrades := 0
	var settlement_target_upgrades := 0
	var any_target_upgrades := 0
	var lookup := _get_playable_lookup()
	for card_variant in cards:
		if not card_variant is Dictionary:
			invalid_count += 1
			continue
		var card_ref := card_variant as Dictionary
		var card_type := str(card_ref.get("card_type", ""))
		var card_id := str(card_ref.get("card_id", ""))
		var card_key := "%s/%s" % [card_type, card_id]
		var data_variant: Variant = lookup.get(card_key, {})
		if not data_variant is Dictionary or (data_variant as Dictionary).is_empty():
			invalid_count += 1
			continue
		var data := data_variant as Dictionary
		valid_count += 1
		copies[card_key] = int(copies.get(card_key, 0)) + 1
		if types.has(card_type):
			types[card_type] = int(types.get(card_type, 0)) + 1
		var cost := maxi(0, int(data.get("energy_cost", 0)))
		energy_total += cost
		buckets[_curve_bucket_id(cost)] = int(buckets.get(_curve_bucket_id(cost), 0)) + 1
		var role_id := _primary_role(card_type, data)
		roles[role_id] = int(roles.get(role_id, 0)) + 1
		for mechanic_id in _card_mechanics(card_type, data):
			mechanics[mechanic_id] = int(mechanics.get(mechanic_id, 0)) + 1
		if card_type == "upgrades":
			match str(data.get("allowed_targets", "Any")):
				"Hero":
					hero_target_upgrades += 1
				"Settlement":
					settlement_target_upgrades += 1
				_:
					any_target_upgrades += 1

	var copy_limit_violations := 0
	for count_variant in copies.values():
		if int(count_variant) > GameRules.MAX_CARD_COPIES:
			copy_limit_violations += 1
	var board_presence := int(types.get("heroes", 0)) + int(types.get("settlements", 0))
	var early_count := int(buckets.get("cost_0_1", 0)) + int(buckets.get("cost_2", 0))
	var high_count := int(buckets.get("cost_4", 0)) + int(buckets.get("cost_5_plus", 0))
	var average_energy := float(energy_total) / float(valid_count) if valid_count > 0 else 0.0
	var curve_state := _curve_state(valid_count, early_count, high_count, average_energy)
	var top_mechanics := _top_mechanics(mechanics)
	var context := {
		"card_count": cards.size(),
		"valid_count": valid_count,
		"invalid_count": invalid_count,
		"missing_cards": maxi(0, GameRules.DECK_SIZE - cards.size()),
		"excess_cards": maxi(0, cards.size() - GameRules.DECK_SIZE),
		"copy_limit_violations": copy_limit_violations,
		"types": types,
		"roles": roles,
		"board_presence": board_presence,
		"early_count": early_count,
		"high_count": high_count,
		"average_energy": snappedf(average_energy, 0.1),
		"curve_state": curve_state,
		"mechanics": mechanics,
		"top_mechanics": top_mechanics,
		"hero_target_upgrades": hero_target_upgrades,
		"settlement_target_upgrades": settlement_target_upgrades,
		"any_target_upgrades": any_target_upgrades,
	}
	return {
		"valid": invalid_count == 0 and copy_limit_violations == 0 and cards.size() <= GameRules.DECK_SIZE,
		"advisor_schema_version": ADVISOR_SCHEMA_VERSION,
		"card_count": cards.size(),
		"valid_card_count": valid_count,
		"target_card_count": GameRules.DECK_SIZE,
		"is_complete": cards.size() == GameRules.DECK_SIZE and invalid_count == 0 and copy_limit_violations == 0,
		"missing_cards": maxi(0, GameRules.DECK_SIZE - cards.size()),
		"excess_cards": maxi(0, cards.size() - GameRules.DECK_SIZE),
		"invalid_card_count": invalid_count,
		"copy_limit_violations": copy_limit_violations,
		"curve": {
			"average_energy": snappedf(average_energy, 0.1),
			"early_count": early_count,
			"high_count": high_count,
			"state_id": curve_state,
			"buckets": [
				{"id": "cost_0_1", "label": "0–1", "count": int(buckets.get("cost_0_1", 0))},
				{"id": "cost_2", "label": "2", "count": int(buckets.get("cost_2", 0))},
				{"id": "cost_3", "label": "3", "count": int(buckets.get("cost_3", 0))},
				{"id": "cost_4", "label": "4", "count": int(buckets.get("cost_4", 0))},
				{"id": "cost_5_plus", "label": "5+", "count": int(buckets.get("cost_5_plus", 0))},
			],
		},
		"types": types.duplicate(true),
		"roles": roles.duplicate(true),
		"board_presence": board_presence,
		"mechanics": mechanics.duplicate(true),
		"top_mechanics": top_mechanics,
		"suggestions": [
			_curve_suggestion(context),
			_composition_suggestion(context),
			_synergy_suggestion(context),
		],
	}


static func reset_cache() -> void:
	_playable_lookup.clear()


static func _get_playable_lookup() -> Dictionary:
	if not _playable_lookup.is_empty():
		return _playable_lookup
	for ref_variant in CardDatabase.get_playable_card_refs():
		if not ref_variant is Dictionary:
			continue
		var ref := ref_variant as Dictionary
		var card_type := str(ref.get("card_type", ""))
		var card_id := str(ref.get("card_id", ""))
		_playable_lookup["%s/%s" % [card_type, card_id]] = CardDatabase.get_card(card_type, card_id)
	return _playable_lookup


static func _curve_bucket_id(cost: int) -> String:
	if cost <= 1:
		return "cost_0_1"
	if cost == 2:
		return "cost_2"
	if cost == 3:
		return "cost_3"
	if cost == 4:
		return "cost_4"
	return "cost_5_plus"


static func _curve_state(card_count: int, early_count: int, high_count: int, average_energy: float) -> String:
	if card_count <= 0:
		return "empty"
	if card_count >= 10 and average_energy >= 3.2 and float(high_count) / float(card_count) >= 0.34:
		return "top_heavy"
	if card_count >= 10 and float(early_count) / float(card_count) < 0.25:
		return "early_light"
	return "flexible"


static func _primary_role(card_type: String, data: Dictionary) -> String:
	var effect_id := str(data.get("effect_id", ""))
	var tags := _tags(data)
	if card_type == "upgrades":
		return "support"
	if effect_id in RESOURCE_EFFECTS:
		return "resource"
	if effect_id in SUSTAIN_EFFECTS or _contains_any(tags, SUSTAIN_TAGS):
		return "sustain"
	if effect_id in CONTROL_EFFECTS or _contains_any(tags, CONTROL_TAGS):
		return "control"
	if card_type == "heroes":
		if _contains_any(tags, FRONTLINE_TAGS) or int(data.get("health", 0)) + int(data.get("armor", 0)) >= 9:
			return "frontline"
		return "pressure"
	if effect_id in PRESSURE_EFFECTS:
		return "pressure"
	if card_type == "settlements":
		return "frontline"
	return "pressure"


static func _card_mechanics(card_type: String, data: Dictionary) -> Array[String]:
	var found := {}
	var tags := _tags(data)
	var effect_id := str(data.get("effect_id", ""))
	if _contains_any(tags, FRONTLINE_TAGS) or effect_id in ["lane_blocker", "lane_protect"]:
		found["guard"] = true
	if "siege" in tags:
		found["siege"] = true
	if "ranged" in tags or effect_id == "ranged_defense":
		found["ranged"] = true
	if _contains_any(tags, SUSTAIN_TAGS) or effect_id in SUSTAIN_EFFECTS:
		found["sustain"] = true
	if _contains_any(tags, CONTROL_TAGS) or effect_id in CONTROL_EFFECTS:
		found["control"] = true
	if _contains_any(tags, ["fast", "phasewalk", "wanderer", "stormstep"]) or effect_id in ["push_adjacent_lane", "lane_ready"]:
		found["mobility"] = true
	if effect_id in RESOURCE_EFFECTS:
		found["resource"] = true
	if _contains_any(tags, ["cleave", "afterburn", "sporeburst"]) or effect_id == "damage_lane":
		found["area_damage"] = true
	if _contains_any(tags, ["lifesteal", "devourer", "armor_siphon"]) or effect_id == "blood_price":
		found["drain"] = true
	if effect_id == "spell_echo":
		found["spell_echo"] = true
	var mechanics: Array[String] = []
	for mechanic_id in MECHANIC_ORDER:
		if found.has(mechanic_id):
			mechanics.append(mechanic_id)
	return mechanics


static func _tags(data: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	for field in ["tags", "granted_tags"]:
		var values_variant: Variant = data.get(field, [])
		if not values_variant is Array:
			continue
		for value_variant in values_variant as Array:
			var value := str(value_variant)
			if not value.is_empty() and value not in tags:
				tags.append(value)
	return tags


static func _contains_any(values: Array[String], candidates: Array) -> bool:
	for candidate_variant in candidates:
		if str(candidate_variant) in values:
			return true
	return false


static func _top_mechanics(mechanics: Dictionary) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for order_index in range(MECHANIC_ORDER.size()):
		var mechanic_id := str(MECHANIC_ORDER[order_index])
		var count := maxi(0, int(mechanics.get(mechanic_id, 0)))
		if count <= 0:
			continue
		ranked.append({
			"id": mechanic_id,
			"label_key": str(MECHANIC_LABEL_KEYS.get(mechanic_id, mechanic_id)),
			"count": count,
			"order": order_index,
		})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var count_delta := int(right.get("count", 0)) - int(left.get("count", 0))
		return int(left.get("order", 0)) < int(right.get("order", 0)) if count_delta == 0 else count_delta < 0
	)
	if ranked.size() > 3:
		ranked.resize(3)
	for row in ranked:
		row.erase("order")
	return ranked


static func _curve_suggestion(context: Dictionary) -> Dictionary:
	var state := str(context.get("curve_state", "empty"))
	var average := float(context.get("average_energy", 0.0))
	var early_count := int(context.get("early_count", 0))
	var high_count := int(context.get("high_count", 0))
	if state == "top_heavy":
		return _suggestion(
			"curve_high",
			"curve",
			"consider",
			"ENERGY CURVE",
			"The curve carries %d cards at 4+ Energy. Consider trading one pair for earlier plays.",
			[high_count]
		)
	if state == "early_light":
		return _suggestion(
			"curve_early",
			"curve",
			"consider",
			"ENERGY CURVE",
			"Only %d cards cost 0–2 Energy. A few earlier plays can make opening hands more flexible.",
			[early_count]
		)
	if state == "empty":
		return _suggestion(
			"curve_empty",
			"curve",
			"neutral",
			"ENERGY CURVE",
			"Add cards to reveal the Energy curve."
		)
	return _suggestion(
		"curve_flexible",
		"curve",
		"solid",
		"ENERGY CURVE",
		"The curve averages %.1f Energy, with %d cards at 0–2 and %d at 4+.",
		[average, early_count, high_count]
	)


static func _composition_suggestion(context: Dictionary) -> Dictionary:
	var missing_cards := int(context.get("missing_cards", 0))
	var excess_cards := int(context.get("excess_cards", 0))
	var invalid_count := int(context.get("invalid_count", 0))
	var copy_violations := int(context.get("copy_limit_violations", 0))
	var board_presence := int(context.get("board_presence", 0))
	var card_count := int(context.get("card_count", 0))
	var roles := context.get("roles", {}) as Dictionary
	var types := context.get("types", {}) as Dictionary
	if invalid_count > 0 or copy_violations > 0:
		return _suggestion(
			"composition_invalid",
			"composition",
			"consider",
			"ROLE COVERAGE",
			"Resolve %d invalid entries and %d copy-limit conflicts before saving.",
			[invalid_count, copy_violations]
		)
	if excess_cards > 0:
		return _suggestion(
			"composition_excess",
			"composition",
			"consider",
			"ROLE COVERAGE",
			"Remove %d cards to return to the %d-card limit.",
			[excess_cards, GameRules.DECK_SIZE]
		)
	if missing_cards > 0:
		return _suggestion(
			"composition_incomplete",
			"composition",
			"consider",
			"ROLE COVERAGE",
			"Add %d more cards. Board cards make the next additions easier to evaluate.",
			[missing_cards]
		)
	if card_count > 0 and board_presence < maxi(10, int(ceil(float(card_count) * 0.45))):
		return _suggestion(
			"composition_board",
			"composition",
			"consider",
			"ROLE COVERAGE",
			"Only %d cards create board presence. Consider adding a Hero or Settlement pair.",
			[board_presence]
		)
	var hero_upgrades := int(context.get("hero_target_upgrades", 0))
	var settlement_upgrades := int(context.get("settlement_target_upgrades", 0))
	if (hero_upgrades > 0 and int(types.get("heroes", 0)) == 0) or (settlement_upgrades > 0 and int(types.get("settlements", 0)) == 0):
		return _suggestion(
			"composition_targets",
			"composition",
			"consider",
			"ROLE COVERAGE",
			"Some Skills have no matching Hero or Settlement target. Pair each target-specific Skill with board cards."
		)
	var frontline := int(roles.get("frontline", 0))
	if frontline < 4:
		return _suggestion(
			"composition_frontline",
			"composition",
			"consider",
			"ROLE COVERAGE",
			"The deck has %d frontline cards. A durable pair can protect its pressure plan.",
			[frontline]
		)
	return _suggestion(
		"composition_base",
		"composition",
		"solid",
		"ROLE COVERAGE",
		"The deck has %d board cards and %d frontline roles; its battlefield plan has a usable base.",
		[board_presence, frontline]
	)


static func _synergy_suggestion(context: Dictionary) -> Dictionary:
	var mechanics := context.get("mechanics", {}) as Dictionary
	var types := context.get("types", {}) as Dictionary
	if int(mechanics.get("spell_echo", 0)) > 0 and int(types.get("special_powers", 0)) < 4:
		return _suggestion(
			"synergy_echo",
			"synergy",
			"consider",
			"KEYWORD SYNERGY",
			"Spell Echo is present, but only %d Spells support it. Consider one more Spell pair.",
			[int(types.get("special_powers", 0))]
		)
	var top_mechanics := context.get("top_mechanics", []) as Array
	if not top_mechanics.is_empty():
		var top := top_mechanics[0] as Dictionary
		if int(top.get("count", 0)) >= 4:
			return _suggestion(
				"synergy_anchor",
				"synergy",
				"identity",
				"KEYWORD SYNERGY",
				"%s already connects %d cards. Keep it as the plan's anchor or add a second supporting package.",
				[str(top.get("label_key", "")), int(top.get("count", 0))],
				[0]
			)
	return _suggestion(
		"synergy_open",
		"synergy",
		"neutral",
		"KEYWORD SYNERGY",
		"No single mechanic dominates yet. Repeat one package across 4–6 cards if you want a clearer identity."
	)


static func _suggestion(
	id: String,
	category: String,
	tone: String,
	title_key: String,
	body_key: String,
	body_args: Array = [],
	translate_arg_indexes: Array = []
) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"tone": tone,
		"title_key": title_key,
		"body_key": body_key,
		"body_args": body_args.duplicate(true),
		"translate_arg_indexes": translate_arg_indexes.duplicate(true),
	}
