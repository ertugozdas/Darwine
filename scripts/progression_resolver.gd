class_name ProgressionResolver extends RefCounted

## Owns experience awards, level validation, irreversible branch selection and
## application of data-driven level bonuses.

static func get_effective_level_paths(card: BaseCard) -> Dictionary:
	if not card or card.is_headquarters():
		return {}
	if card.level_paths.size() == 2:
		return card.level_paths
	if card is HeroCard:
		return {
			"hucum": {
				"name": "Hücum",
				"level_2": {
					"description": "+1 Saldırı ve Kahramanlara +1 hasar.",
					"bonus_attack": 1,
					"trait_value_bonuses": {"hero_damage_bonus": 1},
				},
				"level_3": {
					"description": "+2 Saldırı ve +1 azami Can.",
					"bonus_attack": 2,
					"bonus_health": 1,
				},
			},
			"tahkimat": {
				"name": "Tahkimat",
				"level_2": {
					"description": "+1 Zırh ve +2 azami Can.",
					"bonus_armor": 1,
					"bonus_health": 2,
				},
				"level_3": {
					"description": "+1 Zırh, +2 Can ve Korumalı 2.",
					"bonus_armor": 1,
					"bonus_health": 2,
					"grant_protection": 2,
				},
			},
		}
	if card is SettlementCard:
		var settlement := card as SettlementCard
		if settlement.attack > 0:
			return {
				"tahkimat": {
					"name": "Tahkimat",
					"level_2": {
						"description": "+3 azami ve mevcut Can.",
						"bonus_health": 3,
					},
					"level_3": {
						"description": "+3 Can ve Korumalı 2.",
						"bonus_health": 3,
						"grant_protection": 2,
					},
				},
				"guc": {
					"name": "Ateş Gücü",
					"level_2": {
						"description": "+1 Saldırı ve +1 azami Can.",
						"bonus_attack": 1,
						"bonus_health": 1,
					},
					"level_3": {
						"description": "+2 Saldırı.",
						"bonus_attack": 2,
					},
				},
			}
		return {
			"tahkimat": {
				"name": "Tahkimat",
				"level_2": {
					"description": "+3 azami ve mevcut Can.",
					"bonus_health": 3,
				},
				"level_3": {
					"description": "+3 Can ve Korumalı 2.",
					"bonus_health": 3,
					"grant_protection": 2,
				},
			},
			"himaye": {
				"name": "Himaye",
				"level_2": {
					"description": "+2 Can ve Korumalı 1.",
					"bonus_health": 2,
					"grant_protection": 1,
				},
				"level_3": {
					"description": "+2 Can ve Korumalı 2.",
					"bonus_health": 2,
					"grant_protection": 2,
				},
			},
		}
	return {}


static func get_upgrade_start_error(game_manager: GameManager, card: BaseCard) -> String:
	if not game_manager or not game_manager.is_game_active or not game_manager.is_match_started:
		return "Maç aktif değil."
	if game_manager.current_phase != GameManager.TurnPhase.PREPARATION:
		return "Yükseltme yalnızca Hazırlık aşamasında yapılabilir."
	if not card or not is_instance_valid(card) or card.is_queued_for_deletion():
		return "Yükseltilecek kart artık geçerli değil."
	if not card.current_slot or card.is_headquarters():
		return "Yalnızca savaş alanındaki Kahraman ve Yapılar yükseltilebilir."
	if not (card is HeroCard or card is SettlementCard):
		return "Bu kart türü seviye kazanamaz."
	if card.owner_id != game_manager.active_player_id:
		return "Yalnızca aktif oyuncunun kartı yükseltilebilir."
	if card.card_level >= GameRules.MAX_CARD_LEVEL:
		return "Bu kart zaten azami seviyede."
	var paths := get_effective_level_paths(card)
	if paths.size() != 2:
		return "Bu kart için tam iki yükseltme dalı tanımlı değil."

	var next_level := card.card_level + 1
	var required_experience := get_required_experience(next_level)
	if card.experience < required_experience:
		return "Seviye %d için %d toplam Tecrübe gerekiyor." % [next_level, required_experience]
	var energy_cost := get_level_energy_cost(next_level)
	if not game_manager.has_enough_energy(card.owner_id, energy_cost):
		return "Seviye %d için %d Enerji gerekiyor." % [next_level, energy_cost]
	if card.card_level == 2 and (
		card.selected_branch_id.is_empty()
		or not paths.has(card.selected_branch_id)
	):
		return "Seçili yükseltme dalı geçersiz."
	return ""

static func get_upgrade_error(
	game_manager: GameManager,
	card: BaseCard,
	branch_id: String
) -> String:
	var start_error := get_upgrade_start_error(game_manager, card)
	if not start_error.is_empty():
		return start_error
	var paths := get_effective_level_paths(card)
	var normalized_branch := branch_id.strip_edges().to_lower()
	if normalized_branch.is_empty() or not paths.has(normalized_branch):
		return "Geçerli bir yükseltme dalı seç."
	if card.card_level == 2 and normalized_branch != card.selected_branch_id:
		return "Seviye 2'de seçilen yükseltme dalı değiştirilemez."

	var branch_variant: Variant = paths.get(normalized_branch, {})
	if not branch_variant is Dictionary:
		return "Yükseltme dalı verisi geçersiz."
	var branch := branch_variant as Dictionary
	var level_key := "level_%d" % (card.card_level + 1)
	if not branch.get(level_key, {}) is Dictionary:
		return "Seçilen dal için %s tanımı bulunamadı." % level_key
	return ""

static func get_available_branches(card: BaseCard) -> Array[Dictionary]:
	var branches: Array[Dictionary] = []
	if not card:
		return branches
	var paths := get_effective_level_paths(card)
	for branch_key_variant in paths.keys():
		var branch_id := str(branch_key_variant).strip_edges().to_lower()
		var branch_variant: Variant = paths.get(branch_id, {})
		if not branch_variant is Dictionary:
			continue
		var branch := branch_variant as Dictionary
		branches.append({
			"id": branch_id,
			"name": str(branch.get("name", branch_id.capitalize())),
			"level_2": branch.get("level_2", {}),
			"level_3": branch.get("level_3", {}),
		})
	branches.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("id", "")) < str(b.get("id", "")))
	return branches

static func resolve_upgrade(
	game_manager: GameManager,
	card: BaseCard,
	branch_id: String
) -> Dictionary:
	var normalized_branch := branch_id.strip_edges().to_lower()
	var upgrade_error := get_upgrade_error(game_manager, card, normalized_branch)
	if not upgrade_error.is_empty():
		return {"success": false, "error": upgrade_error, "energy_spent": 0}

	var next_level := card.card_level + 1
	var energy_cost := get_level_energy_cost(next_level)
	if not game_manager.spend_energy(card.owner_id, energy_cost):
		return {"success": false, "error": "Yükseltme Enerjisi harcanamadı.", "energy_spent": 0}

	var paths := get_effective_level_paths(card)
	var branch := paths[normalized_branch] as Dictionary
	var level_definition := branch["level_%d" % next_level] as Dictionary
	_apply_level_definition(card, level_definition)
	if card.card_level == 1:
		card.selected_branch_id = normalized_branch
		card.selected_branch_name = str(branch.get("name", normalized_branch.capitalize()))
	card.set_progression_level(next_level)

	var result := {
		"success": true,
		"card": card,
		"card_name": card.card_name,
		"level": next_level,
		"branch_id": card.selected_branch_id,
		"branch_name": card.selected_branch_name,
		"description": str(level_definition.get("description", "")),
		"energy_spent": energy_cost,
	}
	game_manager.card_leveled_up.emit(card, next_level, card.selected_branch_id)
	return result

static func record_combat_attack(
	game_manager: GameManager,
	attacker: BaseCard,
	target: BaseCard,
	result: Dictionary
) -> void:
	if not game_manager or not attacker or not bool(result.get("success", false)):
		return
	var target_was_hq := bool(result.get("target_was_hq", false))
	var destroyed := bool(result.get("destroyed", false))
	var resolved_target := target
	var resolved_target_variant: Variant = result.get("target", target)
	if resolved_target_variant is BaseCard:
		resolved_target = resolved_target_variant as BaseCard
	var damage_dealt := (
		int(result.get("armor_damage", 0))
		+ int(result.get("health_damage", 0))
	)

	if attacker is HeroCard:
		if damage_dealt > 0 and not attacker.combat_damage_experience_awarded_this_turn:
			attacker.combat_damage_experience_awarded_this_turn = true
			_grant_experience(game_manager, attacker, 1, "combat_damage")
		if destroyed and not target_was_hq and (resolved_target is HeroCard or resolved_target is SettlementCard):
			_grant_experience(game_manager, attacker, 1, "combat_kill")
		if (
			destroyed
			and resolved_target is HeroCard
			and attacker.has_trait("ready_on_hero_kill")
			and not attacker.ready_on_kill_used_this_turn
		):
			attacker.ready_on_kill_used_this_turn = true
			attacker.set_combat_state(BaseCard.CombatState.READY)
		if (
			destroyed
			and resolved_target is HeroCard
			and attacker.has_trait("time_thief")
			and not bool(attacker.trait_runtime.get("time_theft_used", false))
		):
			attacker.trait_runtime["time_theft_used"] = true
			attacker.set_combat_state(BaseCard.CombatState.READY)
			var heal_result := EffectResolver.apply_healing(
				game_manager,
				attacker,
				attacker,
				attacker.get_trait_value("time_theft_healing", 2)
			)
			var time_theft_result := {
				"success": true,
				"effect": "time_thief",
				"source": attacker,
				"target": attacker,
				"destroyed_hero": resolved_target,
				"healed": int(heal_result.get("healed", 0)),
				"readied": true,
			}
			game_manager.effect_resolved.emit(
				"time_thief",
				attacker,
				attacker,
				time_theft_result
			)
	elif attacker is SettlementCard:
		if destroyed and not target_was_hq and (resolved_target is HeroCard or resolved_target is SettlementCard):
			_grant_experience(game_manager, attacker, 1, "structure_kill")

static func record_structure_effect(
	game_manager: GameManager,
	structure: BaseCard,
	result: Dictionary
) -> void:
	if not structure is SettlementCard or not bool(result.get("success", false)):
		return
	if structure.base_effect_experience_awarded_this_turn:
		return
	structure.base_effect_experience_awarded_this_turn = true
	_grant_experience(game_manager, structure, 1, "base_effect")

static func begin_owner_turn(game_manager: GameManager, card: BaseCard) -> void:
	if not card:
		return
	card.reset_owner_turn_tracking()
	card.ready_for_turn()
	if card is HeroCard:
		var armor_regen := card.get_trait_value("turn_start_armor_regen", 0)
		if armor_regen > 0:
			(card as HeroCard).restore_armor(armor_regen)
			var result := {
				"success": true,
				"effect": "turn_start_armor_regen",
				"source": card,
				"armor_restored": armor_regen,
			}
			game_manager.effect_resolved.emit("turn_start_armor_regen", card, card, result)

static func get_required_experience(level: int) -> int:
	return int(GameRules.LEVEL_EXPERIENCE_REQUIREMENTS.get(level, 0))

static func get_level_energy_cost(level: int) -> int:
	return int(GameRules.LEVEL_ENERGY_COSTS.get(level, 0))

static func _grant_experience(
	game_manager: GameManager,
	card: BaseCard,
	amount: int,
	reason: String
) -> int:
	var gained := card.gain_experience(amount)
	if gained <= 0:
		return 0
	game_manager.experience_changed.emit(card, card.experience, gained, reason)
	return gained

static func _apply_level_definition(card: BaseCard, definition: Dictionary) -> void:
	var bonus_attack := _get_int(definition, "bonus_attack", 0)
	var bonus_armor := _get_int(definition, "bonus_armor", 0)
	var bonus_health := _get_int(definition, "bonus_health", 0)
	if card is HeroCard:
		var hero := card as HeroCard
		hero.attack += bonus_attack
		hero.increase_max_armor(bonus_armor)
		hero.increase_max_health(bonus_health)
	elif card is SettlementCard:
		var structure := card as SettlementCard
		structure.attack += bonus_attack
		structure.increase_max_health(bonus_health)

	var traits_variant: Variant = definition.get("grant_traits", [])
	if traits_variant is Array:
		for trait_variant in traits_variant:
			card.add_trait(str(trait_variant))

	var trait_bonuses_variant: Variant = definition.get("trait_value_bonuses", {})
	if trait_bonuses_variant is Dictionary:
		var trait_bonuses := trait_bonuses_variant as Dictionary
		for key_variant in trait_bonuses.keys():
			var key := str(key_variant)
			card.trait_values[key] = card.get_trait_value(key, 0) + int(trait_bonuses[key_variant])

	var effect_bonuses_variant: Variant = definition.get("effect_param_bonuses", {})
	if effect_bonuses_variant is Dictionary:
		var effect_bonuses := effect_bonuses_variant as Dictionary
		for key_variant in effect_bonuses.keys():
			var key := str(key_variant)
			card.effect_params[key] = int(card.effect_params.get(key, 0)) + int(effect_bonuses[key_variant])
	var grant_protection := _get_int(definition, "grant_protection", 0)
	if grant_protection > 0:
		card.apply_status("protected", grant_protection)
	card.refresh_runtime_badges()
	card.preview_state_changed.emit()

static func _get_int(dictionary: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = dictionary.get(key, fallback)
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback
