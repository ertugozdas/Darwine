class_name CombatResolver extends RefCounted

## All normal attacks pass through this resolver. Keeping priority and damage
## validation here prevents UI paths from bypassing a lane's first defender.

static func get_attacker_error(game_manager: GameManager, attacker: BaseCard) -> String:
	if not game_manager or not game_manager.is_game_active or not game_manager.is_match_started:
		return "Maç aktif değil."
	if game_manager.current_phase != GameManager.TurnPhase.COMBAT:
		return "Saldırılar yalnızca Çatışma aşamasında yapılabilir."
	if not attacker or not is_instance_valid(attacker) or not attacker.current_slot:
		return "Saldırgan savaş alanında değil."
	if attacker.owner_id != game_manager.active_player_id:
		return "Yalnızca aktif oyuncunun kartı saldırabilir."
	if not attacker.is_ready_for_combat():
		return "Bu kart Tükenmiş durumda."
	if attacker.get_attack_value() <= 0:
		return "Bu kartın saldırı değeri yok."

	if attacker is HeroCard:
		if attacker.current_slot.position_type != CardSlot.PositionType.FRONT:
			if attacker.current_slot.position_type != CardSlot.PositionType.BACK or not attacker.has_trait("ranged"):
				return "Yalnızca Menzilli Kahraman Arka Hattan saldırabilir."
			if _is_ranged_suppressed(game_manager, attacker):
				return "Sis Perdesi bu Kahramanın Arka Hattan saldırmasını engelliyor."
		return ""

	if attacker is SettlementCard:
		if attacker.is_headquarters() or attacker.current_slot.position_type != CardSlot.PositionType.STRUCTURE:
			return "Bu Yapı saldıramaz."
		return ""

	return "Yalnızca Kahramanlar ve saldırı değeri olan Yapılar saldırabilir."

static func can_select_attacker(game_manager: GameManager, attacker: BaseCard) -> bool:
	return get_attacker_error(game_manager, attacker).is_empty()

static func get_legal_target_slot(battlefield: Node, game_manager: GameManager, attacker: BaseCard) -> CardSlot:
	if not battlefield or not game_manager or not attacker or not attacker.current_slot:
		return null
	if not get_attacker_error(game_manager, attacker).is_empty():
		return null

	var lane_id := int(attacker.current_slot.lane_id)
	if lane_id == CardSlot.Lane.NONE:
		return null
	var defender_id := game_manager.get_opponent_id(attacker.owner_id)
	var lane_slots: Array = battlefield.get_lane_slots(defender_id, lane_id)
	for slot_variant in lane_slots:
		var slot := slot_variant as CardSlot
		if slot and slot.is_occupied and slot.occupied_card is BaseCard:
			return slot

	if battlefield.is_lane_open(defender_id, lane_id):
		return battlefield.get_hq_slot(defender_id)
	return null

static func is_legal_target(battlefield: Node, game_manager: GameManager, attacker: BaseCard, target_slot: CardSlot) -> bool:
	return target_slot != null and target_slot == get_legal_target_slot(battlefield, game_manager, attacker)

static func resolve_attack(
	battlefield: Node,
	game_manager: GameManager,
	attacker: BaseCard,
	target_slot: CardSlot
) -> Dictionary:
	var attacker_error := get_attacker_error(game_manager, attacker)
	if not attacker_error.is_empty():
		return {"success": false, "error": attacker_error}

	var legal_target := get_legal_target_slot(battlefield, game_manager, attacker)
	if not legal_target:
		return {"success": false, "error": "Bu koridorda saldırılabilecek hedef yok."}
	if target_slot != legal_target:
		return {"success": false, "error": "Koridordaki hedef sırası atlanamaz."}
	if not target_slot.is_occupied or not target_slot.occupied_card is BaseCard:
		return {"success": false, "error": "Hedef artık geçerli değil."}

	var target := target_slot.occupied_card as BaseCard
	if target.owner_id == attacker.owner_id:
		return {"success": false, "error": "Dost karta normal saldırı yapılamaz."}

	game_manager.attack_declared.emit(attacker, target)
	var damage_result := EffectResolver.apply_damage(
		game_manager,
		attacker,
		target,
		attacker.get_attack_value(),
		true,
		true,
		true
	)
	if not bool(damage_result.get("success", false)):
		return damage_result
	attacker.set_combat_state(BaseCard.CombatState.EXHAUSTED)
	ProgressionResolver.record_combat_attack(game_manager, attacker, target, damage_result)
	if (
		attacker is HeroCard
		and game_manager.is_game_active
		and is_instance_valid(attacker)
		and not attacker.is_queued_for_deletion()
	):
		var hero_trait_result := EffectResolver.resolve_after_hero_normal_attack(
			game_manager,
			attacker as HeroCard,
			damage_result
		)
		if bool(hero_trait_result.get("triggered", false)):
			damage_result["hero_trait_result"] = hero_trait_result

	if attacker is SettlementCard and attacker.has_trait("multi_shot") and game_manager.is_game_active:
		var secondary_slot := _get_secondary_target_slot(
			battlefield,
			game_manager.get_opponent_id(attacker.owner_id),
			int(attacker.current_slot.lane_id),
			target_slot
		)
		if secondary_slot and secondary_slot.occupied_card is BaseCard:
			var secondary_target := secondary_slot.occupied_card as BaseCard
			var multiplier := clampi(attacker.get_trait_value("secondary_damage_percent", 50), 1, 100)
			var secondary_damage: int = max(1, int(floor(float(attacker.get_attack_value() * multiplier) / 100.0)))
			var secondary_result := EffectResolver.apply_damage(
				game_manager,
				attacker,
				secondary_target,
				secondary_damage,
				true,
				true
			)
			damage_result["secondary_result"] = secondary_result
			if bool(secondary_result.get("success", false)):
				ProgressionResolver.record_combat_attack(game_manager, attacker, secondary_target, secondary_result)

	if (
		attacker is HeroCard
		and attacker.has_trait("cleave")
		and game_manager.is_game_active
		and is_instance_valid(attacker)
		and not attacker.is_queued_for_deletion()
	):
		var cleave_slot := _get_secondary_target_slot(
			battlefield,
			game_manager.get_opponent_id(attacker.owner_id),
			int(attacker.current_slot.lane_id),
			target_slot
		)
		if cleave_slot and cleave_slot.occupied_card is BaseCard:
			var cleave_target := cleave_slot.occupied_card as BaseCard
			var cleave_damage := maxi(1, attacker.get_trait_value("cleave_damage", 1))
			var cleave_result := EffectResolver.apply_damage(
				game_manager,
				attacker,
				cleave_target,
				cleave_damage,
				true,
				false
			)
			damage_result["cleave_result"] = cleave_result
			if bool(cleave_result.get("success", false)):
				ProgressionResolver.record_combat_attack(game_manager, attacker, cleave_target, cleave_result)
				var cleave_feedback := cleave_result.duplicate(true)
				cleave_feedback["effect"] = "cleave"
				game_manager.effect_resolved.emit("cleave", attacker, cleave_target, cleave_feedback)

	if (
		attacker is HeroCard
		and attacker.has_trait("lifesteal")
		and is_instance_valid(attacker)
		and not attacker.is_queued_for_deletion()
	):
		var life_damage := int(damage_result.get("health_damage", 0))
		if life_damage > 0:
			var lifesteal_result := EffectResolver.apply_healing(
				game_manager,
				attacker,
				attacker,
				life_damage
			)
			damage_result["lifesteal_result"] = lifesteal_result

	if attacker and is_instance_valid(attacker) and attacker.has_trait("cloaked"):
		attacker.remove_trait("cloaked")
		var reveal_result := {
			"success": true,
			"effect": "cloak_revealed",
			"source": attacker,
			"target": attacker,
		}
		game_manager.effect_resolved.emit("cloak_revealed", attacker, attacker, reveal_result)

	var actual_defender := damage_result.get("target") as BaseCard
	if (
		actual_defender
		and is_instance_valid(actual_defender)
		and not actual_defender.is_queued_for_deletion()
		and actual_defender.get_current_health() > 0
		and actual_defender.has_trait("retaliate")
		and attacker
		and is_instance_valid(attacker)
		and not attacker.is_queued_for_deletion()
	):
		var retaliation_damage: int = max(1, actual_defender.get_trait_value("retaliate_damage", 1))
		var retaliation_result := EffectResolver.apply_damage(
			game_manager,
			actual_defender,
			attacker,
			retaliation_damage,
			false,
			false
		)
		damage_result["retaliation_result"] = retaliation_result
		if bool(retaliation_result.get("success", false)):
			var retaliation_feedback := retaliation_result.duplicate(true)
			retaliation_feedback["effect"] = "retaliate"
			game_manager.effect_resolved.emit(
				"retaliate",
				actual_defender,
				attacker,
				retaliation_feedback
			)
	damage_result["attacker"] = attacker
	return damage_result

static func _is_ranged_suppressed(game_manager: GameManager, attacker: BaseCard) -> bool:
	if not game_manager or not attacker or not attacker.current_slot or not game_manager.is_inside_tree():
		return false
	var enemy_id := game_manager.get_opponent_id(attacker.owner_id)
	var lane_id := int(attacker.current_slot.lane_id)
	for node in game_manager.get_tree().get_nodes_in_group(BaseCard.GROUP_NAME):
		var enemy_card := node as BaseCard
		if (
			enemy_card
			and enemy_card.owner_id == enemy_id
			and enemy_card.current_slot
			and int(enemy_card.current_slot.lane_id) == lane_id
			and enemy_card.has_trait("fog_weaver")
			and enemy_card.get_current_health() > 0
			and not enemy_card.is_queued_for_deletion()
		):
			return true
	return false

static func _get_secondary_target_slot(
	battlefield: Node,
	defender_id: int,
	lane_id: int,
	primary_slot: CardSlot
) -> CardSlot:
	if not battlefield or not battlefield.has_method("get_lane_slots"):
		return null
	var lane_slots: Array = battlefield.get_lane_slots(defender_id, lane_id)
	for slot_variant in lane_slots:
		var slot := slot_variant as CardSlot
		if not slot or slot == primary_slot:
			continue
		if int(slot.position_type) <= int(primary_slot.position_type):
			continue
		if slot.is_occupied and slot.occupied_card is BaseCard:
			return slot
	return null
