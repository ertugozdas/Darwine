class_name MovementResolver extends RefCounted

## Validates and resolves every voluntary Hero reposition. Validation completes
## before Energy is spent, so illegal destinations never consume resources.

static func get_movement_energy_cost(card: BaseCard, game_manager: GameManager = null) -> int:
	var base_cost := GameRules.MOVEMENT_ENERGY_COST
	if card and card.has_trait("wanderer"):
		base_cost = 0
	elif game_manager:
		base_cost = EffectResolver.get_effect_action_cost(
			game_manager,
			card,
			"move",
			GameRules.MOVEMENT_ENERGY_COST
		)
	if not card or not game_manager:
		return base_cost
	return base_cost + _get_gravity_well_tax(game_manager, card)

static func get_movement_start_error(game_manager: GameManager, card: BaseCard) -> String:
	if not game_manager or not game_manager.is_game_active or not game_manager.is_match_started:
		return "Maç aktif değil."
	if game_manager.current_phase != GameManager.TurnPhase.PREPARATION:
		return "Hareket yalnızca Hazırlık aşamasında yapılabilir."
	if not card or not is_instance_valid(card) or card.is_queued_for_deletion():
		return "Hareket edecek kart artık geçerli değil."
	if not card is HeroCard:
		return "Yalnızca Kahramanlar hareket edebilir."
	if not card.current_slot:
		return "Kahraman savaş alanında değil."
	if card.current_slot.position_type not in [CardSlot.PositionType.FRONT, CardSlot.PositionType.BACK]:
		return "Kahraman geçerli bir Ön veya Arka Hat yuvasında değil."
	if card.owner_id != game_manager.active_player_id:
		return "Yalnızca aktif oyuncunun Kahramanı hareket edebilir."
	if not card.is_ready_for_combat():
		return "Yalnızca Hazır Kahraman hareket edebilir."
	if card.has_moved_this_turn:
		return "Bu Kahraman bu tur zaten hareket etti."
	var movement_cost := get_movement_energy_cost(card, game_manager)
	if movement_cost > 0 and not game_manager.has_enough_energy(card.owner_id, movement_cost):
		return "Hareket için %d Enerji gerekiyor." % movement_cost
	return ""

static func get_destination_error(
	game_manager: GameManager,
	card: BaseCard,
	target_slot: CardSlot
) -> String:
	var start_error := get_movement_start_error(game_manager, card)
	if not start_error.is_empty():
		return start_error
	if not target_slot or not is_instance_valid(target_slot):
		return "Geçerli bir hareket yuvası seç."
	if not target_slot.is_inside_tree() or not target_slot.is_in_group(CardSlot.GROUP_NAME):
		return "Hedef savaş alanına ait değil."
	if not target_slot.is_visible_in_tree():
		return "Gizli bir yuvaya hareket edilemez."
	if target_slot.is_occupied:
		return "Hedef yuva boş olmalı."
	if target_slot.owner_id != card.owner_id:
		return "Kahraman rakibin alanına hareket edemez."
	if target_slot.position_type not in [CardSlot.PositionType.FRONT, CardSlot.PositionType.BACK]:
		return "Kahraman yalnızca Ön veya Arka Hatta hareket edebilir."

	var origin := card.current_slot
	if target_slot == origin:
		return "Kahraman zaten bu yuvada."
	if card.has_trait("phasewalk"):
		return ""
	var same_lane := target_slot.lane_id == origin.lane_id
	var opposite_line := target_slot.position_type != origin.position_type
	if same_lane and opposite_line:
		return ""

	var same_line := target_slot.position_type == origin.position_type
	var lane_distance: int = abs(int(target_slot.lane_id) - int(origin.lane_id))
	if same_line and lane_distance == 1:
		return ""
	if same_line and lane_distance > 1:
		return "Sol ile Sağ koridor arasında tek hamlede hareket edilemez."
	return "Çapraz hareket yapılamaz."

static func get_legal_destination_slots(game_manager: GameManager, card: BaseCard) -> Array[CardSlot]:
	var targets: Array[CardSlot] = []
	if not game_manager or not game_manager.is_inside_tree():
		return targets
	if not get_movement_start_error(game_manager, card).is_empty():
		return targets
	for node in game_manager.get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if slot and get_destination_error(game_manager, card, slot).is_empty():
			targets.append(slot)
	targets.sort_custom(func(a: CardSlot, b: CardSlot):
		if a.lane_id != b.lane_id:
			return int(a.lane_id) < int(b.lane_id)
		return int(a.position_type) < int(b.position_type)
	)
	return targets

static func resolve_move(
	game_manager: GameManager,
	card: BaseCard,
	target_slot: CardSlot
) -> Dictionary:
	var destination_error := get_destination_error(game_manager, card, target_slot)
	if not destination_error.is_empty():
		return {"success": false, "error": destination_error, "energy_spent": 0}
	var movement_cost := get_movement_energy_cost(card, game_manager)
	if movement_cost > 0 and not game_manager.spend_energy(card.owner_id, movement_cost):
		return {"success": false, "error": "Hareket Enerjisi harcanamadı.", "energy_spent": 0}

	var origin := card.current_slot
	origin.release_card()
	card.current_slot = target_slot
	target_slot.accept_card(card)
	card.reparent(target_slot, true)
	card.position = (target_slot.size - card.size) * 0.5
	card.mark_moved_this_turn()
	var kept_ready := card.has_trait("wanderer")
	var ready_source: SettlementCard = null
	if (
		not kept_ready
		and int(origin.lane_id) != int(target_slot.lane_id)
		and not game_manager.has_player_turn_flag(card.owner_id, "lane_ready")
	):
		ready_source = _find_lane_ready_structure(game_manager, card.owner_id, int(target_slot.lane_id))
		if ready_source:
			kept_ready = true
			game_manager.set_player_turn_flag(card.owner_id, "lane_ready")
	card.set_combat_state(
		BaseCard.CombatState.READY if kept_ready else BaseCard.CombatState.EXHAUSTED
	)
	card.refresh_runtime_badges()

	var result := {
		"success": true,
		"card": card,
		"card_name": card.card_name,
		"from_slot": origin,
		"to_slot": target_slot,
		"from_lane": int(origin.lane_id),
		"to_lane": int(target_slot.lane_id),
		"energy_spent": movement_cost,
		"free_movement": movement_cost == 0,
		"kept_ready": kept_ready,
		"ready_source": ready_source,
	}
	game_manager.card_moved.emit(card, origin, target_slot)
	var movement_trait_effect := EffectResolver.resolve_after_hero_moved(
		game_manager,
		card as HeroCard,
		origin,
		target_slot
	)
	if bool(movement_trait_effect.get("triggered", false)):
		result["movement_trait_effect"] = movement_trait_effect
	var energy_effect := EffectResolver.resolve_energy_action(game_manager, card, "move", movement_cost)
	if bool(energy_effect.get("triggered", false)):
		result["energy_effect"] = energy_effect
	if ready_source:
		var ready_result := {
			"success": true,
			"effect": "lane_ready",
			"source": ready_source,
			"target": card,
			"from_lane": int(origin.lane_id),
			"to_lane": int(target_slot.lane_id),
		}
		game_manager.effect_resolved.emit("lane_ready", ready_source, card, ready_result)
		ProgressionResolver.record_structure_effect(game_manager, ready_source, ready_result)
	return result

static func _find_lane_ready_structure(
	game_manager: GameManager,
	player_id: int,
	lane_id: int
) -> SettlementCard:
	if not game_manager or not game_manager.is_inside_tree():
		return null
	for node in game_manager.get_tree().get_nodes_in_group(BaseCard.GROUP_NAME):
		var structure := node as SettlementCard
		if (
			structure
			and structure.owner_id == player_id
			and structure.current_slot
			and int(structure.current_slot.lane_id) == lane_id
			and structure.effect_id == "lane_ready"
			and not structure.is_queued_for_deletion()
		):
			return structure
	return null


static func _get_gravity_well_tax(game_manager: GameManager, card: BaseCard) -> int:
	if not game_manager or not card or not card.current_slot or not game_manager.is_inside_tree():
		return 0
	var tax := 0
	var enemy_id := game_manager.get_opponent_id(card.owner_id)
	var lane_id := int(card.current_slot.lane_id)
	for node in game_manager.get_tree().get_nodes_in_group(BaseCard.GROUP_NAME):
		var enemy := node as BaseCard
		if (
			not enemy
			or enemy.owner_id != enemy_id
			or not enemy is HeroCard
			or not enemy.current_slot
			or int(enemy.current_slot.lane_id) != lane_id
			or not enemy.has_trait("gravity_well")
			or enemy.is_queued_for_deletion()
		):
			continue
		tax = maxi(tax, enemy.get_trait_value("gravity_well_tax", 1))
	return tax
