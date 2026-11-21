class_name EffectResolver extends RefCounted

## Every non-placement card effect and every damage/healing operation passes
## through this resolver. Target validation happens before Energy is spent.

const STATUS_STUNNED := "stunned"
const STATUS_POISON := "poison"
const STATUS_PROTECTED := "protected"


static func get_effect_action_cost(
	game_manager: GameManager,
	card: BaseCard,
	action_type: String,
	base_cost: int
) -> int:
	var cost := maxi(0, base_cost)
	if not game_manager or not card:
		return cost
	var player_id := card.owner_id
	var selected_effect := game_manager.get_selected_effect_card(player_id)
	match action_type:
		"hero":
			if selected_effect == "oncu_doktrini" and not game_manager.has_effect_triggered(player_id, "vanguard_doctrine"):
				return maxi(1, cost - 1)
		"settlement":
			if selected_effect == "usta_zanaatkarlar" and not game_manager.has_effect_triggered(player_id, "master_artisans"):
				return maxi(1, cost - 1)
		"special_power":
			if selected_effect == "gizli_cephanelik" and not game_manager.has_effect_triggered(player_id, "hidden_arsenal"):
				return maxi(1, cost - 1)
		"move":
			if selected_effect == "kanat_manevrasi" and not game_manager.has_effect_triggered(player_id, "flanking_maneuver"):
				return 0
	return cost


static func resolve_energy_action(
	game_manager: GameManager,
	card: BaseCard,
	action_type: String,
	energy_spent: int
) -> Dictionary:
	if not game_manager or not card:
		return {"triggered": false}
	var player_id := card.owner_id
	var selected_effect := game_manager.get_selected_effect_card(player_id)
	match action_type:
		"hero":
			if selected_effect == "oncu_doktrini" and not game_manager.has_effect_triggered(player_id, "vanguard_doctrine"):
				game_manager.mark_effect_triggered(player_id, "vanguard_doctrine", {"card_id": card.card_id})
		"settlement":
			if selected_effect == "usta_zanaatkarlar" and not game_manager.has_effect_triggered(player_id, "master_artisans"):
				game_manager.mark_effect_triggered(player_id, "master_artisans", {"card_id": card.card_id})
		"special_power":
			if selected_effect == "gizli_cephanelik" and not game_manager.has_effect_triggered(player_id, "hidden_arsenal"):
				game_manager.mark_effect_triggered(player_id, "hidden_arsenal", {"card_id": card.card_id})
		"move":
			if selected_effect == "kanat_manevrasi" and not game_manager.has_effect_triggered(player_id, "flanking_maneuver"):
				game_manager.mark_effect_triggered(player_id, "flanking_maneuver", {"card_id": card.card_id})

	if energy_spent <= 0 or selected_effect != "ikmal_hatti" or game_manager.has_effect_triggered(player_id, "supply_line"):
		return {"triggered": false}
	if game_manager.get_available_energy(player_id) != 0:
		return {"triggered": false, "checked": true}
	var battlefield := game_manager.get_parent()
	if not battlefield or not battlefield.has_method("get_hand_cards"):
		return {"triggered": false, "checked": true}
	var hand_cards: Array = battlefield.get_hand_cards(player_id)
	if hand_cards.size() >= GameRules.MAX_HAND_SIZE:
		return {"triggered": false, "checked": true, "hand_full": true}
	game_manager.mark_effect_checked(player_id, "supply_line_checked")
	game_manager.mark_effect_triggered(player_id, "supply_line", {
		"card_id": card.card_id,
		"energy_spent": energy_spent,
	})
	game_manager.effect_draw_requested.emit(player_id, 1, card)
	return {"triggered": true, "cards_requested": 1}


static func resolve_after_board_card_played(game_manager: GameManager, card: BaseCard) -> Dictionary:
	if not game_manager or not card:
		return {"triggered": false}
	var selected_effect := game_manager.get_selected_effect_card(card.owner_id)
	if (
		card is SettlementCard
		and selected_effect == "yapi_ustalari"
		and not game_manager.has_effect_triggered(card.owner_id, "building_masters")
	):
		var settlement := card as SettlementCard
		settlement.increase_max_health(2)
		settlement.refresh_runtime_badges()
		settlement.preview_state_changed.emit()
		game_manager.mark_effect_triggered(card.owner_id, "building_masters", {"card_id": card.card_id, "health": 2})
		return {"triggered": true, "health": 2, "target": card}
	if (
		card is HeroCard
		and selected_effect == "muhafiz_nobeti"
		and not game_manager.has_effect_triggered(card.owner_id, "guard_watch")
	):
		var protection_result := apply_status(game_manager, card, card, STATUS_PROTECTED, 2)
		if not bool(protection_result.get("success", false)):
			return {"triggered": false}
		game_manager.mark_effect_triggered(card.owner_id, "guard_watch", {"card_id": card.card_id, "protection": 2})
		protection_result["triggered"] = true
		protection_result["effect"] = "guard_watch"
		return protection_result
	return {"triggered": false}


static func resolve_after_hero_moved(
	game_manager: GameManager,
	hero: HeroCard,
	from_slot: CardSlot,
	to_slot: CardSlot
) -> Dictionary:
	if (
		not game_manager
		or not hero
		or not from_slot
		or not to_slot
		or int(from_slot.lane_id) == int(to_slot.lane_id)
	):
		return {"triggered": false}

	var combined := {
		"triggered": false,
		"from_lane": int(from_slot.lane_id),
		"to_lane": int(to_slot.lane_id),
	}
	if hero.has_trait("stormstep"):
		var target := _find_first_lane_target(game_manager, hero)
		if target:
			var damage := maxi(1, hero.get_trait_value("stormstep_damage", 1))
			var damage_result := apply_damage(game_manager, hero, target, damage, true, false, false)
			if bool(damage_result.get("success", false)):
				damage_result["triggered"] = true
				damage_result["effect"] = "stormstep"
				damage_result["from_lane"] = int(from_slot.lane_id)
				damage_result["to_lane"] = int(to_slot.lane_id)
				combined["stormstep"] = damage_result
				combined["triggered"] = true
				game_manager.effect_resolved.emit("stormstep", hero, target, damage_result)

	if hero.has_trait("spore_drift"):
		var poison_target := _find_first_lane_hero(game_manager, hero)
		if poison_target:
			var poison_result := apply_status(
				game_manager,
				hero,
				poison_target,
				STATUS_POISON,
				maxi(1, hero.get_trait_value("spore_drift_poison", 1)),
				maxi(1, hero.get_trait_value("spore_drift_duration", 1))
			)
			if bool(poison_result.get("success", false)):
				poison_result["triggered"] = true
				poison_result["effect"] = "spore_drift"
				poison_result["from_lane"] = int(from_slot.lane_id)
				poison_result["to_lane"] = int(to_slot.lane_id)
				combined["spore_drift"] = poison_result
				combined["triggered"] = true
				game_manager.effect_resolved.emit("spore_drift", hero, poison_target, poison_result)

	return combined


static func resolve_after_hero_normal_attack(
	game_manager: GameManager,
	hero: HeroCard,
	damage_result: Dictionary
) -> Dictionary:
	if (
		not game_manager
		or not hero
		or not is_instance_valid(hero)
		or hero.is_queued_for_deletion()
		or int(damage_result.get("health_damage", 0)) <= 0
	):
		return {"triggered": false}

	var target := damage_result.get("target") as BaseCard
	if (
		not target
		or not target is HeroCard
		or not is_instance_valid(target)
		or target.owner_id == hero.owner_id
	):
		return {"triggered": false}

	var combined := {"triggered": false}
	var target_destroyed := bool(damage_result.get("destroyed", false))
	if (
		hero.has_trait("afterburn")
		and not target_destroyed
		and not target.is_queued_for_deletion()
		and int(hero.trait_runtime.get("afterburn_turn", -1)) != game_manager.turn_count
	):
		hero.trait_runtime["afterburn_turn"] = game_manager.turn_count
		var afterburn_result := apply_status(
			game_manager,
			hero,
			target,
			STATUS_POISON,
			maxi(1, hero.get_trait_value("afterburn_poison", 1)),
			maxi(1, hero.get_trait_value("afterburn_duration", 1))
		)
		if bool(afterburn_result.get("success", false)):
			afterburn_result["triggered"] = true
			afterburn_result["effect"] = "afterburn"
			combined["afterburn"] = afterburn_result
			combined["triggered"] = true
			game_manager.effect_resolved.emit("afterburn", hero, target, afterburn_result)

	if (
		hero.has_trait("petrify")
		and not target_destroyed
		and not target.is_queued_for_deletion()
		and int(hero.trait_runtime.get("petrify_turn", -1)) != game_manager.turn_count
	):
		hero.trait_runtime["petrify_turn"] = game_manager.turn_count
		var petrify_result := apply_status(
			game_manager,
			hero,
			target,
			STATUS_STUNNED,
			maxi(1, hero.get_trait_value("petrify_stun", 1)),
			maxi(1, hero.get_trait_value("petrify_duration", 1))
		)
		if bool(petrify_result.get("success", false)):
			petrify_result["triggered"] = true
			petrify_result["effect"] = "petrify"
			combined["petrify"] = petrify_result
			combined["triggered"] = true
			game_manager.effect_resolved.emit("petrify", hero, target, petrify_result)

	if (
		hero.has_trait("armor_siphon")
		and int(hero.trait_runtime.get("armor_siphon_turn", -1)) != game_manager.turn_count
	):
		hero.trait_runtime["armor_siphon_turn"] = game_manager.turn_count
		var armor_gained := maxi(1, hero.get_trait_value("armor_siphon_armor", 1))
		hero.increase_max_armor(armor_gained)
		hero.refresh_runtime_badges()
		var siphon_result := {
			"success": true,
			"triggered": true,
			"effect": "armor_siphon",
			"source": hero,
			"target": hero,
			"armor_gained": armor_gained,
		}
		combined["armor_siphon"] = siphon_result
		combined["triggered"] = true
		game_manager.effect_resolved.emit("armor_siphon", hero, hero, siphon_result)

	return combined


static func resolve_after_upgrade(game_manager: GameManager, upgrade: UpgradeCard, target: BaseCard) -> Dictionary:
	if (
		not game_manager
		or not upgrade
		or not target
		or game_manager.get_selected_effect_card(upgrade.owner_id) != "dovme_ocagi"
		or game_manager.has_effect_triggered(upgrade.owner_id, "forge")
	):
		return {"triggered": false}
	if target is HeroCard:
		(target as HeroCard).increase_max_health(1)
	elif target is SettlementCard:
		(target as SettlementCard).increase_max_health(1)
	else:
		return {"triggered": false}
	target.refresh_runtime_badges()
	target.preview_state_changed.emit()
	game_manager.mark_effect_triggered(upgrade.owner_id, "forge", {"target_card_id": target.card_id, "health": 1})
	return {"triggered": true, "health": 1, "target": target}

static func get_card_start_error(game_manager: GameManager, effect_card: BaseCard) -> String:
	if not game_manager or not game_manager.is_game_active or not game_manager.is_match_started:
		return "Maç aktif değil."
	if game_manager.current_phase != GameManager.TurnPhase.PREPARATION:
		return "Beceri ve Büyüler yalnızca Hazırlık aşamasında oynanabilir."
	if not effect_card or not is_instance_valid(effect_card) or effect_card.is_queued_for_deletion():
		return "Etki kartı artık geçerli değil."
	if effect_card.current_slot:
		return "Sahadaki kart yeniden oynanamaz."
	if effect_card.owner_id != game_manager.active_player_id:
		return "Yalnızca aktif oyuncu kart oynayabilir."
	if not (effect_card is UpgradeCard or effect_card is SpecialPowerCard):
		return "Bu kart hedefli bir Beceri veya Büyü değil."
	var action_type := "special_power" if effect_card is SpecialPowerCard else "upgrade"
	var resolved_cost := get_effect_action_cost(game_manager, effect_card, action_type, effect_card.energy_cost)
	if not game_manager.has_enough_energy(effect_card.owner_id, resolved_cost):
		return "Kartı oynayacak Enerji yok."
	return ""

static func get_card_target_error(
	game_manager: GameManager,
	effect_card: BaseCard,
	target_slot: CardSlot
) -> String:
	var start_error := get_card_start_error(game_manager, effect_card)
	if not start_error.is_empty():
		return start_error
	if not target_slot or not is_instance_valid(target_slot):
		return "Geçerli bir hedef seç."
	if effect_card is SpecialPowerCard and effect_card.effect_id == "revive_last_hero":
		return _get_revive_target_error(effect_card as SpecialPowerCard, target_slot, game_manager)
	if not target_slot.is_occupied or not target_slot.occupied_card is BaseCard:
		return "Hedef yuva dolu değil."

	var target: BaseCard = target_slot.occupied_card as BaseCard if target_slot.is_occupied else null
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return "Hedef artık geçerli değil."
	if target.is_headquarters():
		return "Bu kart Merkez Binasını hedefleyemez."

	if effect_card is UpgradeCard:
		return _get_skill_target_error(effect_card as UpgradeCard, target)
	return _get_spell_target_error(effect_card as SpecialPowerCard, target, game_manager)

static func get_legal_target_slots(game_manager: GameManager, effect_card: BaseCard) -> Array[CardSlot]:
	var legal_targets: Array[CardSlot] = []
	if not game_manager or not game_manager.is_inside_tree():
		return legal_targets
	if not get_card_start_error(game_manager, effect_card).is_empty():
		return legal_targets

	for node in game_manager.get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if slot and get_card_target_error(game_manager, effect_card, slot).is_empty():
			legal_targets.append(slot)
	legal_targets.sort_custom(_sort_slots)
	return legal_targets

static func resolve_targeted_card(
	game_manager: GameManager,
	effect_card: BaseCard,
	target_slot: CardSlot
) -> Dictionary:
	var target_error := get_card_target_error(game_manager, effect_card, target_slot)
	if not target_error.is_empty():
		return {"success": false, "error": target_error, "energy_spent": 0}

	var target := target_slot.occupied_card as BaseCard
	var action_type := "special_power" if effect_card is SpecialPowerCard else "upgrade"
	var resolved_cost := get_effect_action_cost(game_manager, effect_card, action_type, effect_card.energy_cost)
	if not game_manager.spend_energy(effect_card.owner_id, resolved_cost):
		return {
			"success": false,
			"error": "Kartı oynayacak Enerji yok veya hamle artık geçersiz.",
			"energy_spent": 0,
		}

	var result: Dictionary
	if effect_card is UpgradeCard:
		result = _resolve_skill(effect_card as UpgradeCard, target, game_manager)
		var forge_result := resolve_after_upgrade(game_manager, effect_card as UpgradeCard, target)
		if bool(forge_result.get("triggered", false)):
			result["effect_card_bonus"] = forge_result
	else:
		result = _resolve_spell(effect_card as SpecialPowerCard, target, game_manager, target_slot)

	# All paths above are fully validated before spending. Treat an unexpected
	# resolver failure as a programming error instead of silently consuming a card.
	if not bool(result.get("success", false)):
		push_error("Validated effect failed after spending Energy: %s" % str(result.get("error", "unknown")))
		return result

	result["energy_spent"] = resolved_cost
	result["effect_card_name"] = effect_card.card_name
	var energy_effect := resolve_energy_action(game_manager, effect_card, action_type, resolved_cost)
	if bool(energy_effect.get("triggered", false)):
		result["energy_effect"] = energy_effect
	var resolved_effect_id := effect_card.effect_id if not effect_card.effect_id.is_empty() else "attach_skill"
	effect_card.set_meta("telemetry_energy_spent", resolved_cost)
	game_manager.card_played.emit(effect_card, target)
	game_manager.effect_resolved.emit(resolved_effect_id, effect_card, target, result)

	if effect_card is SpecialPowerCard:
		resolve_special_power_echo(game_manager, effect_card as SpecialPowerCard)
		effect_card.queue_free()
	return result

static func apply_damage(
	game_manager: GameManager,
	source: BaseCard,
	target: BaseCard,
	base_damage: int,
	allow_guard: bool = true,
	apply_siege_bonus: bool = true,
	is_normal_attack: bool = false
) -> Dictionary:
	if not target or not is_instance_valid(target) or target.is_queued_for_deletion():
		return {"success": false, "error": "Hasar hedefi artık geçerli değil."}
	if game_manager and not game_manager.is_game_active:
		return {"success": false, "error": "Maç aktif değil."}

	var normalized_damage: int = max(0, base_damage)
	var siege_bonus := 0
	var matchup_bonus := 0
	var war_banner_bonus := _resolve_war_banner_bonus(game_manager, source, is_normal_attack)
	var last_breath_bonus := _resolve_last_breath_bonus(source, is_normal_attack)
	if (
		apply_siege_bonus
		and source
		and is_instance_valid(source)
		and source.has_trait("siege")
		and target is SettlementCard
	):
		siege_bonus = max(0, source.get_trait_value("siege_bonus", 2))
	if source and is_instance_valid(source) and target is HeroCard:
		matchup_bonus = max(0, source.get_trait_value("hero_damage_bonus", 0))

	var original_target := target
	var actual_target := target
	var guard_redirected := false
	if allow_guard and target is SettlementCard and not target.is_headquarters():
		var guard := _find_available_guard(game_manager, target)
		if guard:
			guard.consume_guard()
			actual_target = guard
			guard_redirected = true

	var effect_card_bonus: int = _resolve_siege_plan_bonus(
		game_manager,
		source,
		original_target,
		actual_target,
		is_normal_attack
	)
	var incoming_damage: int = (
		normalized_damage
		+ siege_bonus
		+ matchup_bonus
		+ war_banner_bonus
		+ last_breath_bonus
		+ effect_card_bonus
	)
	var eclipse_reduction := _resolve_eclipse_reduction(
		game_manager,
		source,
		actual_target,
		incoming_damage,
		is_normal_attack
	)
	incoming_damage = maxi(0, incoming_damage - eclipse_reduction)
	var bulwark_reduction := _resolve_bulwark_reduction(actual_target, incoming_damage, is_normal_attack)
	incoming_damage = maxi(0, incoming_damage - bulwark_reduction)
	var last_stand_reduction: int = _resolve_last_stand_reduction(game_manager, source, actual_target, incoming_damage)
	incoming_damage = maxi(0, incoming_damage - last_stand_reduction)
	var protection_result := actual_target.absorb_protected_damage(incoming_damage)
	var blocked_damage := int(protection_result.get("blocked", 0))
	var final_damage := int(protection_result.get("remaining", incoming_damage))
	var target_was_hq := actual_target.is_headquarters()
	var target_name := actual_target.card_name
	var piercing_health_damage := 0
	var remaining_damage := final_damage
	var direct_damage_result: Dictionary = {}
	if source and actual_target is HeroCard:
		var target_hero := actual_target as HeroCard
		var armor_pierce: int = max(0, source.get_trait_value("armor_pierce", 0))
		var piercing_request: int = min(remaining_damage, min(target_hero.armor, armor_pierce))
		if piercing_request > 0:
			direct_damage_result = target_hero.take_direct_health_damage(piercing_request)
			piercing_health_damage = int(direct_damage_result.get("health_damage", 0))
			remaining_damage -= piercing_request

	var damage_result: Dictionary
	if bool(direct_damage_result.get("destroyed", false)):
		damage_result = {
			"success": true,
			"armor_damage": 0,
			"health_damage": 0,
			"remaining_health": actual_target.get_current_health(),
			"destroyed": true,
		}
	else:
		damage_result = actual_target.take_combat_damage(remaining_damage)
	if not bool(damage_result.get("success", false)):
		return damage_result

	var destroyed := bool(damage_result.get("destroyed", false))
	if target_was_hq and game_manager:
		game_manager.set_hq_health(actual_target.owner_id, actual_target.get_current_health())
	elif destroyed:
		_resolve_card_destruction(game_manager, actual_target, source, false)

	var result := {
		"success": true,
		"effect": "damage",
		"source": source,
		"target": actual_target,
		"original_target": original_target,
		"target_name": target_name,
		"target_was_hq": target_was_hq,
		"requested_damage": normalized_damage,
		"siege_bonus": siege_bonus,
		"matchup_bonus": matchup_bonus,
		"war_banner_bonus": war_banner_bonus,
		"last_breath_bonus": last_breath_bonus,
		"effect_card_bonus": effect_card_bonus,
		"eclipse_reduction": eclipse_reduction,
		"bulwark_reduction": bulwark_reduction,
		"last_stand_reduction": last_stand_reduction,
		"damage": final_damage,
		"blocked_damage": blocked_damage,
		"armor_damage": int(damage_result.get("armor_damage", 0)),
		"health_damage": int(damage_result.get("health_damage", 0)) + piercing_health_damage,
		"piercing_health_damage": piercing_health_damage,
		"remaining_health": int(damage_result.get("remaining_health", 0)),
		"destroyed": destroyed,
		"guard_redirected": guard_redirected,
	}
	if game_manager:
		game_manager.effect_resolved.emit("damage", source, actual_target, result)
	return result

static func apply_direct_health_loss(
	game_manager: GameManager,
	source: BaseCard,
	target: HeroCard,
	amount: int
) -> Dictionary:
	if not target or not is_instance_valid(target) or target.is_queued_for_deletion():
		return {"success": false, "error": "Can kaybı hedefi artık geçerli değil."}
	var target_name := target.card_name
	var loss_result := target.take_direct_health_damage(max(0, amount))
	var destroyed := bool(loss_result.get("destroyed", false))
	if destroyed:
		_resolve_card_destruction(game_manager, target, source, false)
	var result := {
		"success": true,
		"effect": "damage",
		"source": source,
		"target": target,
		"original_target": target,
		"target_name": target_name,
		"target_was_hq": false,
		"requested_damage": max(0, amount),
		"siege_bonus": 0,
		"matchup_bonus": 0,
		"damage": int(loss_result.get("health_damage", 0)),
		"blocked_damage": 0,
		"armor_damage": 0,
		"health_damage": int(loss_result.get("health_damage", 0)),
		"piercing_health_damage": int(loss_result.get("health_damage", 0)),
		"remaining_health": int(loss_result.get("remaining_health", 0)),
		"destroyed": destroyed,
		"guard_redirected": false,
		"direct_health_loss": true,
	}
	if game_manager:
		game_manager.effect_resolved.emit("damage", source, target, result)
	return result

static func _resolve_card_destruction(
	game_manager: GameManager,
	target: BaseCard,
	source: BaseCard,
	banished: bool
) -> void:
	if not target or not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	if game_manager:
		if not banished and target.has_trait("last_will"):
			var draw_count: int = max(1, target.get_trait_value("last_will_draw", 1))
			var will_result := {
				"success": true,
				"effect": "last_will",
				"source": target,
				"target": target,
				"cards_requested": draw_count,
			}
			game_manager.effect_resolved.emit("last_will", target, target, will_result)
			game_manager.effect_draw_requested.emit(target.owner_id, draw_count, target)
		if not banished:
			_resolve_sporeburst_reaction(game_manager, target)
			_resolve_soulbond_reactions(game_manager, target)
			_resolve_devourer_reaction(game_manager, target, source)
		game_manager.record_card_destroyed(target, source, banished)
	target.destroy_from_combat()


static func _resolve_sporeburst_reaction(game_manager: GameManager, destroyed_card: BaseCard) -> void:
	if (
		not game_manager
		or not destroyed_card is HeroCard
		or not destroyed_card.has_trait("sporeburst")
		or not destroyed_card.current_slot
	):
		return
	var target := _find_first_lane_hero(game_manager, destroyed_card)
	if not target:
		return
	var poison_result := apply_status(
		game_manager,
		destroyed_card,
		target,
		STATUS_POISON,
		maxi(1, destroyed_card.get_trait_value("sporeburst_poison", 2)),
		maxi(1, destroyed_card.get_trait_value("sporeburst_duration", 1))
	)
	if not bool(poison_result.get("success", false)):
		return
	poison_result["triggered"] = true
	poison_result["effect"] = "sporeburst"
	game_manager.effect_resolved.emit("sporeburst", destroyed_card, target, poison_result)


static func _resolve_devourer_reaction(
	game_manager: GameManager,
	destroyed_card: BaseCard,
	source: BaseCard
) -> void:
	if (
		not game_manager
		or not destroyed_card is HeroCard
		or not source
		or not is_instance_valid(source)
		or not source is HeroCard
		or source.is_queued_for_deletion()
		or source.owner_id == destroyed_card.owner_id
		or not source.has_trait("devourer")
	):
		return
	var devourer := source as HeroCard
	var health_gained := maxi(1, devourer.get_trait_value("devourer_health", 1))
	devourer.increase_max_health(health_gained)
	devourer.refresh_runtime_badges()
	var result := {
		"success": true,
		"triggered": true,
		"effect": "devourer",
		"source": devourer,
		"target": devourer,
		"destroyed_hero": destroyed_card,
		"health_gained": health_gained,
	}
	game_manager.effect_resolved.emit("devourer", devourer, devourer, result)


static func _resolve_soulbond_reactions(game_manager: GameManager, destroyed_card: BaseCard) -> void:
	if (
		not game_manager
		or not destroyed_card is HeroCard
		or not destroyed_card.current_slot
	):
		return
	var lane_id := int(destroyed_card.current_slot.lane_id)
	for ally in _get_board_cards(game_manager, destroyed_card.owner_id):
		if (
			ally == destroyed_card
			or not ally is HeroCard
			or not ally.current_slot
			or int(ally.current_slot.lane_id) != lane_id
			or not ally.has_trait("soulbond")
			or int(ally.trait_runtime.get("soulbond_round", -1)) == game_manager.round_count
		):
			continue
		ally.trait_runtime["soulbond_round"] = game_manager.round_count
		var heal_result := apply_healing(
			game_manager,
			ally,
			ally,
			ally.get_trait_value("soulbond_healing", 2)
		)
		var protection_result := apply_status(
			game_manager,
			ally,
			ally,
			STATUS_PROTECTED,
			ally.get_trait_value("soulbond_protection", 1)
		)
		var result := {
			"success": true,
			"effect": "soulbond",
			"source": ally,
			"target": ally,
			"destroyed_ally": destroyed_card,
			"healed": int(heal_result.get("healed", 0)),
			"protection": int(protection_result.get("amount", 0)),
			"round": game_manager.round_count,
		}
		game_manager.effect_resolved.emit("soulbond", ally, ally, result)

static func apply_healing(
	game_manager: GameManager,
	source: BaseCard,
	target: BaseCard,
	amount: int
) -> Dictionary:
	if not target or not is_instance_valid(target) or target.is_queued_for_deletion():
		return {"success": false, "error": "İyileştirme hedefi artık geçerli değil."}
	var healed := target.heal_combat_damage(max(0, amount))
	var result := {
		"success": true,
		"effect": "heal",
		"source": source,
		"target": target,
		"target_name": target.card_name,
		"healed": healed,
		"remaining_health": target.get_current_health(),
	}
	if game_manager:
		game_manager.effect_resolved.emit("heal", source, target, result)
	return result

static func apply_status(
	game_manager: GameManager,
	source: BaseCard,
	target: BaseCard,
	status_id: String,
	amount: int,
	duration: int = 1
) -> Dictionary:
	if not target or not is_instance_valid(target) or target.is_queued_for_deletion():
		return {"success": false, "error": "Durum hedefi artık geçerli değil."}
	if not target.apply_status(status_id, amount, duration):
		return {"success": false, "error": "Bilinmeyen durum etkisi: %s" % status_id}
	var result := {
		"success": true,
		"effect": "status",
		"status_id": status_id,
		"amount": max(0, amount),
		"duration": max(1, duration),
		"target": target,
		"target_name": target.card_name,
	}
	if game_manager:
		game_manager.effect_resolved.emit(status_id, source, target, result)
	return result

static func apply_skill_modifiers(target: BaseCard, skill: UpgradeCard) -> Dictionary:
	if not target or not skill:
		return {"success": false, "error": "Beceri veya hedef eksik."}

	if target is HeroCard:
		var hero := target as HeroCard
		hero.attack += skill.bonus_attack
		hero.increase_max_armor(skill.bonus_armor)
		hero.increase_max_health(skill.bonus_health)
	elif target is SettlementCard:
		var structure := target as SettlementCard
		structure.attack += skill.bonus_attack
		structure.increase_max_health(skill.bonus_health)
	else:
		return {"success": false, "error": "Beceri bu kart türüne uygulanamaz."}

	for trait_id in skill.granted_traits:
		target.add_attached_skill_trait(trait_id)
	if target.has_trait("fast") and target.current_slot:
		target.set_combat_state(BaseCard.CombatState.READY)
	if not skill.granted_status.is_empty() and skill.status_amount > 0:
		target.apply_status(skill.granted_status, skill.status_amount, skill.status_duration)

	target.preview_state_changed.emit()
	return {"success": true, "effect": "skill", "target": target}

static func resolve_special_power_echo(
	game_manager: GameManager,
	spell: SpecialPowerCard
) -> Dictionary:
	if not game_manager or not spell or game_manager.has_player_turn_flag(spell.owner_id, "spell_echo"):
		return {"success": false, "triggered": false}
	var shrine: SettlementCard = null
	for card in _get_board_cards(game_manager, spell.owner_id):
		if card is SettlementCard and card.effect_id == "spell_echo":
			shrine = card as SettlementCard
			break
	if not shrine:
		return {"success": false, "triggered": false}
	var energy_gain: int = max(1, _get_effect_int(shrine, "energy", 1))
	game_manager.set_player_turn_flag(spell.owner_id, "spell_echo")
	if not game_manager.add_temporary_energy(spell.owner_id, energy_gain):
		return {"success": false, "triggered": false}
	var result := {
		"success": true,
		"triggered": true,
		"effect": "spell_echo",
		"source": shrine,
		"spell_name": spell.card_name,
		"energy_gained": energy_gain,
	}
	game_manager.effect_resolved.emit("spell_echo", shrine, null, result)
	ProgressionResolver.record_structure_effect(game_manager, shrine, result)
	return result

static func resolve_turn_start(game_manager: GameManager, player_id: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var oath_result: Dictionary = _resolve_protective_oath(game_manager, player_id)
	if bool(oath_result.get("triggered", false)):
		results.append(oath_result)
	var harmony_result: Dictionary = _resolve_primal_harmony(game_manager, player_id)
	if bool(harmony_result.get("triggered", false)):
		results.append(harmony_result)
	for card in _get_board_cards(game_manager, player_id):
		if not card is SettlementCard:
			continue
		match card.effect_id:
			"energy_income", "building_discount":
				var amount := _get_effect_int(card, "energy", 1)
				if game_manager.add_temporary_energy(player_id, amount):
					var result := {
						"success": true,
						"effect": card.effect_id,
						"source": card,
						"energy_gained": amount,
					}
					results.append(result)
					game_manager.effect_resolved.emit(card.effect_id, card, null, result)
					ProgressionResolver.record_structure_effect(game_manager, card, result)
			"lane_protect":
				var protect_target := _find_lane_protection_target(game_manager, card)
				if protect_target:
					var protect_result := apply_status(
						game_manager,
						card,
						protect_target,
						STATUS_PROTECTED,
						_get_effect_int(card, "protection", 2)
					)
					results.append(protect_result)
					ProgressionResolver.record_structure_effect(game_manager, card, protect_result)
	var hive_mind_result := _resolve_hive_mind(game_manager, player_id)
	if bool(hive_mind_result.get("triggered", false)):
		results.append(hive_mind_result)
	return results

static func resolve_turn_end(game_manager: GameManager, player_id: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	# Poison resolves first, so a destroyed source cannot trigger a later passive.
	for card in _get_board_cards(game_manager, player_id):
		var poison_damage := card.consume_poison_tick()
		if poison_damage <= 0:
			continue
		var poison_result := apply_damage(game_manager, null, card, poison_damage, false, false)
		poison_result["effect"] = STATUS_POISON
		results.append(poison_result)

	if not game_manager.is_game_active:
		return results
	var medic_result: Dictionary = _resolve_field_medics(game_manager, player_id)
	if bool(medic_result.get("triggered", false)):
		results.append(medic_result)

	for card in _get_board_cards(game_manager, player_id):
		if not is_instance_valid(card) or not card.current_slot:
			continue
		if card is SettlementCard:
			match card.effect_id:
				"lane_training":
					var target := _find_first_lane_target(game_manager, card)
					if target:
						var training_result := apply_damage(
							game_manager,
							card,
							target,
							_get_effect_int(card, "damage", 1),
							true,
							false
						)
						results.append(training_result)
						ProgressionResolver.record_structure_effect(game_manager, card, training_result)
				"lane_heal":
					var heal_target := _find_most_injured_lane_ally(game_manager, card)
					if heal_target:
						var structure_heal_result := apply_healing(
							game_manager,
							card,
							heal_target,
							_get_effect_int(card, "healing", 2)
						)
						results.append(structure_heal_result)
						ProgressionResolver.record_structure_effect(game_manager, card, structure_heal_result)
				"lane_poison":
					var poison_target := _find_first_lane_hero(game_manager, card)
					if poison_target:
						var poison_result := apply_status(
							game_manager,
							card,
							poison_target,
							STATUS_POISON,
							_get_effect_int(card, "poison", 1),
							_get_effect_int(card, "duration", 1)
						)
						results.append(poison_result)
						ProgressionResolver.record_structure_effect(game_manager, card, poison_result)
		if card is HeroCard and card.has_trait("healer"):
			var hero_heal_target := _find_most_injured_lane_ally(game_manager, card)
			if hero_heal_target:
				results.append(apply_healing(
					game_manager,
					card,
					hero_heal_target,
					card.get_trait_value("healer_amount", 2)
				))
		if (
			card is HeroCard
			and card.has_trait("starlight_ward")
			and card.is_ready_for_combat()
			and card.get_status_amount(STATUS_PROTECTED) <= 0
		):
			var ward_result := apply_status(
				game_manager,
				card,
				card,
				STATUS_PROTECTED,
				maxi(1, card.get_trait_value("starlight_ward_protection", 1))
			)
			if bool(ward_result.get("success", false)):
				ward_result["effect"] = "starlight_ward"
				results.append(ward_result)
				game_manager.effect_resolved.emit("starlight_ward", card, card, ward_result)
		if card is HeroCard and card.has_trait("steadfast") and not card.has_moved_this_turn:
			var steadfast_hero := card as HeroCard
			var healed := 0
			if steadfast_hero.get_current_health() < steadfast_hero.get_max_health():
				var steadfast_heal := apply_healing(
					game_manager,
					steadfast_hero,
					steadfast_hero,
					steadfast_hero.get_trait_value("steadfast_healing", 1)
				)
				healed = int(steadfast_heal.get("healed", 0))
			var armor_restored := 0
			if healed == 0 and steadfast_hero.get_current_health() >= steadfast_hero.get_max_health():
				armor_restored = steadfast_hero.restore_armor(
					steadfast_hero.get_trait_value("steadfast_armor", 1)
				)
			if healed > 0 or armor_restored > 0:
				var steadfast_result := {
					"success": true,
					"effect": "steadfast",
					"source": steadfast_hero,
					"target": steadfast_hero,
					"healed": healed,
					"armor_restored": armor_restored,
				}
				steadfast_hero.refresh_runtime_badges()
				results.append(steadfast_result)
				game_manager.effect_resolved.emit(
					"steadfast",
					steadfast_hero,
					steadfast_hero,
					steadfast_result
				)
		if not game_manager.is_game_active:
			break
	return results


static func _resolve_hive_mind(game_manager: GameManager, player_id: int) -> Dictionary:
	if not game_manager or game_manager.has_player_turn_flag(player_id, "hive_mind"):
		return {"triggered": false}
	var allied_cards := _get_board_cards(game_manager, player_id)
	for card in allied_cards:
		if not card is HeroCard or not card.has_trait("hive_mind") or not card.current_slot:
			continue
		for ally in allied_cards:
			if (
				ally == card
				or not ally is HeroCard
				or not ally.current_slot
				or int(ally.current_slot.lane_id) != int(card.current_slot.lane_id)
			):
				continue
			var energy_gained := maxi(1, card.get_trait_value("hive_mind_energy", 1))
			if not game_manager.add_temporary_energy(player_id, energy_gained):
				return {"triggered": false}
			game_manager.set_player_turn_flag(player_id, "hive_mind")
			var result := {
				"success": true,
				"triggered": true,
				"effect": "hive_mind",
				"source": card,
				"target": ally,
				"energy_gained": energy_gained,
				"lane_id": int(card.current_slot.lane_id),
			}
			game_manager.effect_resolved.emit("hive_mind", card, ally, result)
			return result
	return {"triggered": false}


static func _resolve_primal_harmony(game_manager: GameManager, player_id: int) -> Dictionary:
	if (
		not game_manager
		or game_manager.get_selected_effect_card(player_id) != "ilkel_uyum"
		or game_manager.has_effect_triggered(player_id, "primal_harmony")
	):
		return {"triggered": false}

	var occupied_lanes: Dictionary = {}
	for card in _get_board_cards(game_manager, player_id):
		if card is HeroCard and card.current_slot:
			occupied_lanes[int(card.current_slot.lane_id)] = true
	if occupied_lanes.size() < 2:
		return {"triggered": false}
	if not game_manager.add_temporary_energy(player_id, 1):
		return {"triggered": false}

	var target := _find_most_injured_non_hq(game_manager, player_id, true, false)
	var healed := 0
	if target:
		var heal_result := apply_healing(game_manager, null, target, 1)
		healed = int(heal_result.get("healed", 0))
	game_manager.mark_effect_triggered(player_id, "primal_harmony", {
		"occupied_lane_count": occupied_lanes.size(),
		"energy_gained": 1,
		"target_card_id": target.card_id if target else "",
		"healed": healed,
	})
	var result := {
		"success": true,
		"triggered": true,
		"effect": "primal_harmony",
		"source": null,
		"target": target,
		"occupied_lane_count": occupied_lanes.size(),
		"energy_gained": 1,
		"healed": healed,
	}
	game_manager.effect_resolved.emit("primal_harmony", null, target, result)
	return result


static func _resolve_protective_oath(game_manager: GameManager, player_id: int) -> Dictionary:
	if (
		not game_manager
		or game_manager.get_selected_effect_card(player_id) != "koruyucu_yemin"
		or game_manager.has_effect_triggered(player_id, "protective_oath")
	):
		return {"triggered": false}
	var target := _find_most_injured_non_hq(game_manager, player_id, false, true)
	if not target:
		return {"triggered": false}
	var result := apply_status(game_manager, null, target, STATUS_PROTECTED, 1)
	if not bool(result.get("success", false)):
		return {"triggered": false}
	game_manager.mark_effect_triggered(player_id, "protective_oath", {"target_card_id": target.card_id})
	result["triggered"] = true
	return result


static func _resolve_field_medics(game_manager: GameManager, player_id: int) -> Dictionary:
	if (
		not game_manager
		or game_manager.get_selected_effect_card(player_id) != "saha_hekimleri"
		or game_manager.has_effect_triggered(player_id, "field_medics")
	):
		return {"triggered": false}
	var target := _find_most_injured_non_hq(game_manager, player_id, true, false)
	if not target:
		return {"triggered": false}
	var result := apply_healing(game_manager, null, target, 1)
	if int(result.get("healed", 0)) <= 0:
		return {"triggered": false}
	game_manager.mark_effect_triggered(player_id, "field_medics", {"target_card_id": target.card_id, "healed": 1})
	result["triggered"] = true
	return result


static func _resolve_war_banner_bonus(
	game_manager: GameManager,
	source: BaseCard,
	is_normal_attack: bool
) -> int:
	if (
		not game_manager
		or not source is HeroCard
		or not source.current_slot
		or not is_normal_attack
	):
		return 0
	var bonus := 0
	for ally in _get_board_cards(game_manager, source.owner_id):
		if (
			not ally is HeroCard
			or not ally.current_slot
			or int(ally.current_slot.lane_id) != int(source.current_slot.lane_id)
			or not ally.has_trait("war_banner")
		):
			continue
		bonus = maxi(bonus, ally.get_trait_value("war_banner_damage", 1))
	return bonus


static func _resolve_last_breath_bonus(source: BaseCard, is_normal_attack: bool) -> int:
	if not source is HeroCard or not is_normal_attack or not source.has_trait("last_breath"):
		return 0
	if source.get_current_health() * 2 > source.get_max_health():
		return 0
	return maxi(1, source.get_trait_value("last_breath_damage", 2))


static func _resolve_eclipse_reduction(
	game_manager: GameManager,
	source: BaseCard,
	actual_target: BaseCard,
	incoming_damage: int,
	is_normal_attack: bool
) -> int:
	if (
		not game_manager
		or not source
		or not source.current_slot
		or not actual_target
		or not is_normal_attack
		or incoming_damage <= 0
	):
		return 0
	var reduction := 0
	for defender in _get_board_cards(game_manager, actual_target.owner_id):
		if (
			not defender is HeroCard
			or not defender.current_slot
			or int(defender.current_slot.lane_id) != int(source.current_slot.lane_id)
			or not defender.has_trait("eclipse")
		):
			continue
		reduction = maxi(reduction, defender.get_trait_value("eclipse_reduction", 1))
	return mini(incoming_damage, reduction)


static func _resolve_bulwark_reduction(
	actual_target: BaseCard,
	incoming_damage: int,
	is_normal_attack: bool
) -> int:
	if (
		not actual_target
		or not is_normal_attack
		or incoming_damage <= 0
		or not actual_target.has_trait("bulwark")
		or not bool(actual_target.trait_runtime.get("bulwark_available", true))
	):
		return 0
	actual_target.trait_runtime["bulwark_available"] = false
	actual_target.preview_state_changed.emit()
	return mini(incoming_damage, maxi(1, actual_target.get_trait_value("bulwark_reduction", 2)))


static func _resolve_siege_plan_bonus(
	game_manager: GameManager,
	source: BaseCard,
	original_target: BaseCard,
	actual_target: BaseCard,
	is_normal_attack: bool
) -> int:
	if (
		not game_manager
		or not source
		or not original_target
		or not actual_target
		or not is_normal_attack
		or source.owner_id != game_manager.active_player_id
		or game_manager.current_phase != GameManager.TurnPhase.COMBAT
		or game_manager.get_selected_effect_card(source.owner_id) != "kusatma_plani"
		or game_manager.has_effect_triggered(source.owner_id, "siege_plan")
		or original_target != actual_target
		or not actual_target is SettlementCard
	):
		return 0
	game_manager.mark_effect_triggered(source.owner_id, "siege_plan", {"target_card_id": actual_target.card_id, "damage": 1})
	return 1


static func _resolve_last_stand_reduction(
	game_manager: GameManager,
	source: BaseCard,
	actual_target: BaseCard,
	incoming_damage: int
) -> int:
	if (
		not game_manager
		or not actual_target
		or not actual_target.is_headquarters()
		or incoming_damage <= 0
		or actual_target.owner_id == game_manager.active_player_id
		or (source and source.owner_id == actual_target.owner_id)
		or game_manager.get_selected_effect_card(actual_target.owner_id) != "son_direnis"
		or game_manager.has_effect_triggered(actual_target.owner_id, "last_stand")
	):
		return 0
	game_manager.mark_effect_triggered(actual_target.owner_id, "last_stand", {"prevented": 1})
	return 1


static func _find_most_injured_non_hq(
	game_manager: GameManager,
	player_id: int,
	require_injury: bool,
	require_unprotected: bool
) -> BaseCard:
	var best: BaseCard = null
	var best_missing := -1
	for card in _get_board_cards(game_manager, player_id):
		if card.is_headquarters():
			continue
		if require_unprotected and card.get_status_amount(STATUS_PROTECTED) > 0:
			continue
		var missing := maxi(0, card.get_max_health() - card.get_current_health())
		if require_injury and missing <= 0:
			continue
		if missing > best_missing:
			best = card
			best_missing = missing
	return best


static func _get_skill_target_error(skill: UpgradeCard, target: BaseCard) -> String:
	if target.owner_id != skill.owner_id:
		return "Beceri yalnızca dost karta bağlanabilir."
	if not skill.can_target_card(target):
		return "Bu Beceri seçilen kart türünü hedefleyemez."
	if not target.can_attach_skill():
		return "Bu kartın Beceri yuvası dolu."
	return ""

static func _get_spell_target_error(
	spell: SpecialPowerCard,
	target: BaseCard,
	game_manager: GameManager
) -> String:
	var effect_id := spell.effect_id
	if (
		target.owner_id != spell.owner_id
		and target.has_trait("cloaked")
		and effect_id != "damage_lane"
	):
		return "Örtülü hedef ilk saldırısını yapmadan doğrudan düşman Özel Güçlerine hedef olamaz."
	match effect_id:
		"heal_target":
			if target.owner_id != spell.owner_id:
				return "Kutsal Işık yalnızca dost kartı hedefleyebilir."
			if not (target is HeroCard or target is SettlementCard):
				return "Bu Büyü Kahraman veya Yapı hedeflemeli."
			if target.get_current_health() >= target.get_max_health():
				return "Hedefin Canı zaten dolu."
		"poison_target":
			if target.owner_id == spell.owner_id or not target is HeroCard:
				return "Zehir Yağmuru bir düşman Kahramanı hedeflemeli."
		"stun_target", "damage_target", "damage_lane", "banish_target":
			if target.owner_id == spell.owner_id:
				return "Bu Büyü bir düşman kartı hedeflemeli."
		"protect_target":
			if target.owner_id != spell.owner_id:
				return "Koruyucu Mühür yalnızca dost kartı hedefleyebilir."
			if not (target is HeroCard or target is SettlementCard):
				return "Bu Büyü Kahraman veya Yapı hedeflemeli."
		"push_adjacent_lane":
			if not target is HeroCard:
				return "Yer Değiştiren Rüzgâr yalnızca Kahraman hedefleyebilir."
			if not _find_push_destination(game_manager, target):
				return "Hedefin sırasında boş bir komşu koridor yok."
		"repair_structure":
			if target.owner_id != spell.owner_id or not target is SettlementCard:
				return "Onarım Ritüeli dost bir Yapıyı hedeflemeli."
			if target.get_current_health() >= target.get_max_health():
				return "Yapının Canı zaten dolu."
		"blood_price":
			if target.owner_id != spell.owner_id or not target is HeroCard:
				return "Kan Bedeli dost bir Kahramanı hedeflemeli."
		"detach_skill":
			if target.owner_id == spell.owner_id:
				return "Rün Kırılması düşman kartı hedeflemeli."
			if target.attached_skill_name.is_empty():
				return "Hedefte kırılacak bağlı Beceri yok."
		_:
			return "Büyünün etki tanımı bulunamadı."
	return ""

static func _get_revive_target_error(
	spell: SpecialPowerCard,
	target_slot: CardSlot,
	game_manager: GameManager
) -> String:
	if target_slot.owner_id != spell.owner_id:
		return "Küllerden Dönüş yalnızca dost Arka Hattı hedefleyebilir."
	if target_slot.position_type != CardSlot.PositionType.BACK:
		return "Diriltilecek Kahraman boş bir Arka Hat yuvasına dönmeli."
	if target_slot.is_occupied:
		return "Diriltme için seçilen Arka Hat yuvası boş olmalı."
	if game_manager.peek_last_destroyed_hero(spell.owner_id).is_empty():
		return "Geri döndürülebilecek yok edilmiş dost Kahraman yok."
	if not _find_resurrection_host(target_slot):
		return "Savaş alanı diriltme işlemini desteklemiyor."
	return ""

static func _resolve_skill(skill: UpgradeCard, target: BaseCard, game_manager: GameManager) -> Dictionary:
	if not target.attach_skill(skill):
		return {"success": false, "error": "Beceri hedefe bağlanamadı."}
	var result := apply_skill_modifiers(target, skill)
	if not bool(result.get("success", false)):
		return result
	result["message"] = _translate("%s was attached to %s.") % [
		_translate(skill.card_name),
		_translate(target.card_name),
	]
	result["attached"] = true
	game_manager.effect_resolved.emit("attach_skill", skill, target, result)
	return result

static func _resolve_spell(
	spell: SpecialPowerCard,
	target: BaseCard,
	game_manager: GameManager,
	target_slot: CardSlot
) -> Dictionary:
	var result: Dictionary
	match spell.effect_id:
		"heal_target":
			result = apply_healing(game_manager, spell, target, _get_effect_int(spell, "healing", spell.intensity))
		"poison_target":
			var immediate_damage := _get_effect_int(spell, "damage", 1)
			result = apply_damage(game_manager, spell, target, immediate_damage, true, false)
			if bool(result.get("success", false)) and not bool(result.get("destroyed", false)):
				var status_result := apply_status(
					game_manager,
					spell,
					target,
					STATUS_POISON,
					_get_effect_int(spell, "poison", 2),
					_get_effect_int(spell, "duration", 1)
				)
				result["status_applied"] = bool(status_result.get("success", false))
		"stun_target":
			result = apply_status(
				game_manager,
				spell,
				target,
				STATUS_STUNNED,
				1,
				_get_effect_int(spell, "ready_skips", 1)
			)
		"damage_target":
			result = apply_damage(game_manager, spell, target, _get_effect_int(spell, "damage", spell.intensity), true, false)
		"damage_lane":
			result = _resolve_lane_damage(game_manager, spell, target)
		"protect_target":
			result = apply_status(
				game_manager,
				spell,
				target,
				STATUS_PROTECTED,
				_get_effect_int(spell, "protection", spell.intensity)
			)
		"push_adjacent_lane":
			result = _push_to_adjacent_lane(game_manager, spell, target)
		"repair_structure":
			result = apply_healing(game_manager, spell, target, _get_effect_int(spell, "healing", spell.intensity))
		"banish_target":
			result = _banish_target(game_manager, spell, target)
		"blood_price":
			result = apply_direct_health_loss(
				game_manager,
				spell,
				target as HeroCard,
				_get_effect_int(spell, "health_loss", 3)
			)
			if bool(result.get("success", false)) and not bool(result.get("destroyed", false)):
				var draw_count: int = max(1, _get_effect_int(spell, "cards", spell.intensity))
				result["cards_requested"] = draw_count
				game_manager.effect_draw_requested.emit(spell.owner_id, draw_count, spell)
		"detach_skill":
			result = _detach_attached_skill(game_manager, spell, target)
		"revive_last_hero":
			result = _revive_last_hero(game_manager, spell, target_slot)
		_:
			result = {"success": false, "error": "Büyünün etki tanımı bulunamadı."}

	if bool(result.get("success", false)):
		result["message"] = _build_spell_message(spell, result)
	return result


static func _banish_target(
	game_manager: GameManager,
	spell: SpecialPowerCard,
	target: BaseCard
) -> Dictionary:
	if not target or not is_instance_valid(target) or target.is_queued_for_deletion():
		return {"success": false, "error": "Silinecek hedef artık geçerli değil."}
	if not target.current_slot or target.is_headquarters():
		return {"success": false, "error": "Yalnızca sahadaki Merkez dışı bir kart silinebilir."}

	var target_name := target.card_name
	var result := {
		"success": true,
		"effect": spell.effect_id,
		"source": spell,
		"target": target,
		"target_name": target_name,
		"destroyed": true,
		"banished": true,
	}
	_resolve_card_destruction(game_manager, target, spell, true)
	return result

static func _detach_attached_skill(
	game_manager: GameManager,
	spell: SpecialPowerCard,
	target: BaseCard
) -> Dictionary:
	if not target or target.attached_skill_name.is_empty():
		return {"success": false, "error": "Hedefte kaldırılacak bağlı Beceri yok."}
	var removed_skill_name := target.attached_skill_name
	var modifiers := target.attached_skill_modifiers.duplicate(true)
	var removed_skill := target.attached_skill
	for trait_id in target.attached_skill_added_traits.duplicate():
		target.remove_trait(trait_id)

	var bonus_attack := int(modifiers.get("bonus_attack", 0))
	var bonus_armor := int(modifiers.get("bonus_armor", 0))
	var bonus_health := int(modifiers.get("bonus_health", 0))
	if target is HeroCard:
		var hero := target as HeroCard
		hero.attack = max(0, hero.attack - bonus_attack)
		hero.max_armor = max(0, hero.max_armor - bonus_armor)
		hero.armor = max(0, hero.armor - bonus_armor)
		hero.max_health = max(1, hero.max_health - bonus_health)
		hero.health = max(0, hero.health - bonus_health)
	elif target is SettlementCard:
		var structure := target as SettlementCard
		structure.attack = max(0, structure.attack - bonus_attack)
		structure.max_health = max(1, structure.max_health - bonus_health)
		structure.health = max(0, structure.health - bonus_health)

	target.clear_attached_skill()
	if removed_skill and is_instance_valid(removed_skill):
		removed_skill.queue_free()
	target.refresh_runtime_badges()
	var destroyed := target.get_current_health() <= 0
	if destroyed:
		_resolve_card_destruction(game_manager, target, spell, false)
	return {
		"success": true,
		"effect": "detach_skill",
		"source": spell,
		"target": target,
		"target_name": target.card_name,
		"removed_skill_name": removed_skill_name,
		"destroyed": destroyed,
	}

static func _revive_last_hero(
	game_manager: GameManager,
	spell: SpecialPowerCard,
	target_slot: CardSlot
) -> Dictionary:
	var record := game_manager.peek_last_destroyed_hero(spell.owner_id)
	if record.is_empty():
		return {"success": false, "error": "Diriltilecek Kahraman kaydı bulunamadı."}
	var host := _find_resurrection_host(target_slot)
	if not host:
		return {"success": false, "error": "Savaş alanı diriltme işlemini tamamlayamadı."}
	var revived_variant: Variant = host.call("resurrect_hero_from_record", record, target_slot, spell.owner_id)
	var revived := revived_variant as HeroCard
	if not revived:
		return {"success": false, "error": "Kahraman savaş alanına geri döndürülemedi."}
	game_manager.consume_last_destroyed_hero(spell.owner_id)
	return {
		"success": true,
		"effect": "revive_last_hero",
		"source": spell,
		"target": revived,
		"target_name": revived.card_name,
		"revived_card": revived,
		"revived_card_id": revived.card_id,
		"target_slot": target_slot,
	}

static func _find_resurrection_host(target_slot: CardSlot) -> Node:
	var candidate: Node = target_slot
	while candidate:
		if candidate.has_method("resurrect_hero_from_record"):
			return candidate
		candidate = candidate.get_parent()
	return null

static func _resolve_lane_damage(
	game_manager: GameManager,
	spell: SpecialPowerCard,
	target: BaseCard
) -> Dictionary:
	if not target.current_slot:
		return {"success": false, "error": "Hedef savaş alanında değil."}
	var lane_id := int(target.current_slot.lane_id)
	var lane_targets: Array[BaseCard] = []
	for candidate in _get_board_cards(game_manager, target.owner_id):
		if (
			candidate.current_slot
			and not candidate.is_headquarters()
			and int(candidate.current_slot.lane_id) == lane_id
		):
			lane_targets.append(candidate)
	lane_targets.sort_custom(func(a: BaseCard, b: BaseCard):
		return int(a.current_slot.position_type) < int(b.current_slot.position_type)
	)

	var damage_results: Array[Dictionary] = []
	var total_health_damage := 0
	for lane_target in lane_targets:
		if not is_instance_valid(lane_target) or lane_target.is_queued_for_deletion():
			continue
		var damage_result := apply_damage(
			game_manager,
			spell,
			lane_target,
			_get_effect_int(spell, "damage", spell.intensity),
			false,
			false
		)
		damage_results.append(damage_result)
		total_health_damage += int(damage_result.get("health_damage", 0))
		if not game_manager.is_game_active:
			break

	return {
		"success": not damage_results.is_empty(),
		"effect": spell.effect_id,
		"target": target,
		"target_name": target.card_name,
		"lane_id": lane_id,
		"targets_hit": damage_results.size(),
		"health_damage": total_health_damage,
		"damage_results": damage_results,
	}

static func _push_to_adjacent_lane(
	game_manager: GameManager,
	spell: SpecialPowerCard,
	target: BaseCard
) -> Dictionary:
	var destination := _find_push_destination(game_manager, target)
	if not destination:
		return {"success": false, "error": "Boş komşu koridor bulunamadı."}
	var origin := target.current_slot
	if not origin:
		return {"success": false, "error": "Hedef savaş alanında değil."}

	origin.release_card()
	target.current_slot = destination
	destination.accept_card(target)
	target.reparent(destination, true)
	target.position = (destination.size - target.size) * 0.5
	var result := {
		"success": true,
		"effect": spell.effect_id,
		"target": target,
		"target_name": target.card_name,
		"from_lane": int(origin.lane_id),
		"to_lane": int(destination.lane_id),
	}
	game_manager.effect_resolved.emit(spell.effect_id, spell, target, result)
	return result

static func _find_push_destination(game_manager: GameManager, target: BaseCard) -> CardSlot:
	if not game_manager or not target or not target.current_slot:
		return null
	var origin := target.current_slot
	var candidate_lanes: Array[int] = []
	match origin.lane_id:
		CardSlot.Lane.LEFT:
			candidate_lanes = [CardSlot.Lane.CENTER]
		CardSlot.Lane.CENTER:
			candidate_lanes = [CardSlot.Lane.LEFT, CardSlot.Lane.RIGHT]
		CardSlot.Lane.RIGHT:
			candidate_lanes = [CardSlot.Lane.CENTER]
		_:
			return null

	for lane_id in candidate_lanes:
		for node in game_manager.get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
			var slot := node as CardSlot
			if (
				slot
				and slot.owner_id == origin.owner_id
				and int(slot.lane_id) == lane_id
				and slot.position_type == origin.position_type
				and not slot.is_occupied
				and slot.is_visible_in_tree()
			):
				return slot
	return null

static func _find_available_guard(game_manager: GameManager, protected_structure: BaseCard) -> BaseCard:
	if not game_manager or not protected_structure.current_slot:
		return null
	var candidates: Array[BaseCard] = []
	for card in _get_board_cards(game_manager, protected_structure.owner_id):
		if (
			card is HeroCard
			and card.current_slot
			and card.current_slot.lane_id == protected_structure.current_slot.lane_id
			and card.has_trait("guard")
			and card.is_guard_available()
		):
			candidates.append(card)
	candidates.sort_custom(func(a: BaseCard, b: BaseCard):
		return int(a.current_slot.position_type) < int(b.current_slot.position_type)
	)
	return candidates[0] if not candidates.is_empty() else null


static func _find_first_lane_target(game_manager: GameManager, source: BaseCard) -> BaseCard:
	if not source.current_slot:
		return null
	var defender_id := game_manager.get_opponent_id(source.owner_id)
	for slot in _get_lane_slots(game_manager, defender_id, int(source.current_slot.lane_id)):
		if slot.is_occupied and slot.occupied_card is BaseCard:
			return slot.occupied_card as BaseCard
	return null

static func _find_most_injured_lane_ally(game_manager: GameManager, source: BaseCard) -> BaseCard:
	if not source.current_slot:
		return null
	var best_target: BaseCard = null
	var best_missing_health := 0
	for card in _get_board_cards(game_manager, source.owner_id):
		if not card.current_slot or card.is_headquarters():
			continue
		if card.current_slot.lane_id != source.current_slot.lane_id:
			continue
		var missing_health: int = max(0, card.get_max_health() - card.get_current_health())
		if missing_health > best_missing_health:
			best_missing_health = missing_health
			best_target = card
	return best_target

static func _find_lane_protection_target(game_manager: GameManager, source: BaseCard) -> BaseCard:
	if not source.current_slot:
		return null
	var candidates: Array[BaseCard] = []
	for card in _get_board_cards(game_manager, source.owner_id):
		if (
			card.current_slot
			and not card.is_headquarters()
			and card.current_slot.lane_id == source.current_slot.lane_id
			and card.get_status_amount(STATUS_PROTECTED) <= 0
		):
			candidates.append(card)
	candidates.sort_custom(func(a: BaseCard, b: BaseCard):
		var a_priority := 0 if a is HeroCard else 1
		var b_priority := 0 if b is HeroCard else 1
		if a_priority != b_priority:
			return a_priority < b_priority
		if a.get_current_health() != b.get_current_health():
			return a.get_current_health() < b.get_current_health()
		return int(a.current_slot.position_type) < int(b.current_slot.position_type)
	)
	return candidates[0] if not candidates.is_empty() else null

static func _find_first_lane_hero(game_manager: GameManager, source: BaseCard) -> HeroCard:
	if not source.current_slot:
		return null
	var defender_id := game_manager.get_opponent_id(source.owner_id)
	for slot in _get_lane_slots(game_manager, defender_id, int(source.current_slot.lane_id)):
		if slot.is_occupied and slot.occupied_card is HeroCard:
			return slot.occupied_card as HeroCard
	return null

static func _get_lane_slots(game_manager: GameManager, player_id: int, lane_id: int) -> Array[CardSlot]:
	var slots: Array[CardSlot] = []
	for node in game_manager.get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if (
			slot
			and slot.owner_id == player_id
			and int(slot.lane_id) == lane_id
			and slot.position_type != CardSlot.PositionType.HQ
		):
			slots.append(slot)
	slots.sort_custom(_sort_slots)
	return slots

static func _get_board_cards(game_manager: GameManager, player_id: int = 0) -> Array[BaseCard]:
	var cards: Array[BaseCard] = []
	if not game_manager or not game_manager.is_inside_tree():
		return cards
	for node in game_manager.get_tree().get_nodes_in_group(BaseCard.GROUP_NAME):
		var card := node as BaseCard
		if not card or not card.current_slot or card.is_queued_for_deletion():
			continue
		if player_id != 0 and card.owner_id != player_id:
			continue
		cards.append(card)
	cards.sort_custom(func(a: BaseCard, b: BaseCard):
		if a.current_slot and b.current_slot:
			return _sort_slots(a.current_slot, b.current_slot)
		return a.get_instance_id() < b.get_instance_id()
	)
	return cards

static func _get_effect_int(card: BaseCard, key: String, fallback: int) -> int:
	var value: Variant = card.effect_params.get(key, fallback)
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback

static func _build_spell_message(spell: SpecialPowerCard, result: Dictionary) -> String:
	var target_name := _translate(str(result.get("target_name", "Target")))
	match spell.effect_id:
		"heal_target", "repair_structure":
			return _translate("%s restored %d Health.") % [target_name, int(result.get("healed", 0))]
		"poison_target":
			return _translate("%s became Poisoned.") % target_name
		"stun_target":
			return _translate("%s was Stunned.") % target_name
		"damage_target":
			return _translate("%s took %d damage.") % [target_name, int(result.get("damage", 0))]
		"banish_target":
			return _translate("%s was banished from the battlefield.") % target_name
		"damage_lane":
			return _translate("%d enemies in the lane were hit by Flame Wave.") % int(result.get("targets_hit", 0))
		"protect_target":
			return _translate("%s became Protected.") % target_name
		"push_adjacent_lane":
			return _translate("%s was pushed into an adjacent lane.") % target_name
		"blood_price":
			if bool(result.get("destroyed", false)):
				return _translate("%s could not pay the Blood Price and was destroyed.") % target_name
			return _translate("%s lost 3 Health; drawing %d cards.") % [
				target_name,
				int(result.get("cards_requested", 0)),
			]
		"detach_skill":
			return _translate("%s was removed from %s.") % [
				_translate(str(result.get("removed_skill_name", "attached Skill"))),
				target_name,
			]
		"revive_last_hero":
			return _translate("%s returned to the Back Row with Return from Ashes.") % target_name
		_:
			return _translate("%s resolved.") % _translate(spell.card_name)


static func _translate(value: String) -> String:
	return TranslationServer.translate(value)

static func _sort_slots(a: CardSlot, b: CardSlot) -> bool:
	if a.owner_id != b.owner_id:
		return a.owner_id < b.owner_id
	if a.lane_id != b.lane_id:
		return int(a.lane_id) < int(b.lane_id)
	return int(a.position_type) < int(b.position_type)
