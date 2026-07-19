class_name AIActionPlanner extends RefCounted

## Produces a complete legal action set first, then ranks that immutable set.
## Difficulty changes selection quality and action budget, never rule access.

var _battlefield: BattlefieldUI
var _game_manager: GameManager
var _rng: RandomNumberGenerator


func setup(
	battlefield: BattlefieldUI,
	game_manager: GameManager,
	rng: RandomNumberGenerator
) -> void:
	_battlefield = battlefield
	_game_manager = game_manager
	_rng = rng


func generate_legal_actions(player_id: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not _battlefield or not _game_manager or not _game_manager.is_game_active:
		return actions
	if _game_manager.active_player_id != player_id:
		return actions

	match _game_manager.current_phase:
		GameManager.TurnPhase.MULLIGAN:
			actions.append({"type": "confirm_mulligan", "player_id": player_id})
		GameManager.TurnPhase.PREPARATION:
			_generate_preparation_actions(player_id, actions)
			actions.append({"type": "advance_phase", "player_id": player_id})
		GameManager.TurnPhase.COMBAT:
			_generate_combat_actions(player_id, actions)
			actions.append({"type": "advance_phase", "player_id": player_id})
		GameManager.TurnPhase.END:
			actions.append({"type": "complete_end", "player_id": player_id})
	return actions


func choose_action(
	actions: Array[Dictionary],
	difficulty: int,
	actions_taken_in_phase: int
) -> Dictionary:
	if actions.is_empty():
		return {}
	var end_action := _find_phase_end_action(actions)
	if actions_taken_in_phase >= get_action_budget(difficulty, _game_manager.current_phase):
		return end_action if not end_action.is_empty() else actions[0]

	var productive: Array[Dictionary] = []
	for action in actions:
		if str(action.get("type", "")) not in ["advance_phase", "complete_end", "confirm_mulligan"]:
			productive.append(action)

	if difficulty == MatchSetup.AIDifficulty.EASY:
		# Easy still stays legal, but samples broadly and sometimes passes early.
		var pass_chance := 0.16 if _game_manager.current_phase == GameManager.TurnPhase.PREPARATION else 0.0
		if productive.is_empty() or (_rng.randf() < pass_chance and not end_action.is_empty()):
			return end_action if not end_action.is_empty() else actions[_rng.randi_range(0, actions.size() - 1)]
		var sampled_actions := productive.filter(func(action: Dictionary):
			return str(action.get("type", "")) != "move"
		)
		if sampled_actions.is_empty():
			sampled_actions = productive
		# Easy keeps its small action budget and broad randomness, but usually
		# prefers one useful tempo play so defensive cards do not stall mirrors.
		if _rng.randf() < 0.66:
			var tempo_action: Dictionary = sampled_actions[0]
			var tempo_score := -INF
			for candidate in sampled_actions:
				var candidate_score := _score_action(candidate, difficulty)
				if candidate_score > tempo_score:
					tempo_score = candidate_score
					tempo_action = candidate
			return tempo_action
		return sampled_actions[_rng.randi_range(0, sampled_actions.size() - 1)]

	if productive.is_empty():
		return end_action if not end_action.is_empty() else actions[0]

	var best_action: Dictionary = productive[0]
	var best_score := -INF
	for action in productive:
		var score := _score_action(action, difficulty)
		# A seeded, tiny tie-break keeps repeated openings from becoming mandatory.
		score += _rng.randf_range(-0.35, 0.35)
		if score > best_score:
			best_score = score
			best_action = action
	if best_score <= 0.0 and not end_action.is_empty():
		return end_action
	return best_action


func choose_mulligan_cards(player_id: int, difficulty: int) -> Array[BaseCard]:
	var hand := _battlefield.get_hand_cards(player_id)
	var selected: Array[BaseCard] = []
	if difficulty == MatchSetup.AIDifficulty.EASY:
		for card in hand:
			if selected.size() >= 2:
				break
			if _rng.randf() < 0.24:
				selected.append(card)
		return selected

	var candidates: Array[BaseCard] = []
	for card in hand:
		if card is UpgradeCard or card is SpecialPowerCard:
			candidates.append(card)
		elif card.energy_cost > GameRules.STARTING_ENERGY:
			candidates.append(card)
	candidates.sort_custom(func(a: BaseCard, b: BaseCard):
		return _opening_keep_value(a) < _opening_keep_value(b)
	)
	var limit := 3 if difficulty == MatchSetup.AIDifficulty.HARD else 2
	for card in candidates:
		if selected.size() >= limit:
			break
		selected.append(card)
	return selected


func choose_discards(player_id: int, count: int) -> Array[BaseCard]:
	var cards := _battlefield.get_hand_cards(player_id)
	cards.sort_custom(func(a: BaseCard, b: BaseCard):
		return _hand_keep_value(a) < _hand_keep_value(b)
	)
	var selected: Array[BaseCard] = []
	for index in range(min(count, cards.size())):
		selected.append(cards[index])
	return selected


func get_action_budget(difficulty: int, phase: GameManager.TurnPhase) -> int:
	match phase:
		GameManager.TurnPhase.PREPARATION:
			match difficulty:
				MatchSetup.AIDifficulty.EASY:
					return 3
				MatchSetup.AIDifficulty.HARD:
					return 12
				_:
					return 6
		GameManager.TurnPhase.COMBAT:
			return 12
		_:
			return 1


func describe_action(action: Dictionary) -> Dictionary:
	var description := {
		"type": str(action.get("type", "unknown")),
		"player_id": int(action.get("player_id", 0)),
	}
	var card := _get_valid_card(action.get("card"))
	if card:
		description["card_id"] = card.card_id
		description["card_name"] = card.card_name
	var hand_target := _get_valid_card(action.get("hand_target"))
	if hand_target:
		description["hand_target_card_id"] = hand_target.card_id
		description["hand_target_card_name"] = hand_target.card_name
	var target_slot := _get_valid_slot(action.get("target_slot"))
	if target_slot:
		description["target_owner_id"] = target_slot.owner_id
		description["target_lane"] = int(target_slot.lane_id)
		description["target_position"] = int(target_slot.position_type)
		var target_card := _get_valid_card(target_slot.occupied_card)
		if target_card:
			description["target_card_id"] = target_card.card_id
	if action.has("branch_id"):
		description["branch_id"] = str(action["branch_id"])
	return description


func _get_valid_card(value: Variant) -> BaseCard:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as BaseCard


func _get_valid_slot(value: Variant) -> CardSlot:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as CardSlot


func _generate_preparation_actions(player_id: int, actions: Array[Dictionary]) -> void:
	if _game_manager.has_preparation_token(player_id):
		actions.append({"type": "use_preparation_token", "player_id": player_id})

	var hand := _battlefield.get_hand_cards(player_id)
	var board_slots := _battlefield.get_board_slots(player_id)
	var has_drawable_card := _battlefield.get_deck_card_count(player_id) > 0
	for card in hand:
		if not card or card.is_queued_for_deletion():
			continue
		if card is HeroCard or card is SettlementCard:
			if not _game_manager.has_enough_energy(player_id, card.energy_cost):
				continue
			for slot in board_slots:
				if slot.can_accept_card(card):
					actions.append({
						"type": "play_card",
						"player_id": player_id,
						"card": card,
						"target_slot": slot,
					})
		elif card is SpecialPowerCard and _battlefield.is_hand_tactic_card(card):
			if not has_drawable_card or not _game_manager.has_enough_energy(player_id, card.energy_cost):
				continue
			var tactic := card as SpecialPowerCard
			if tactic.effect_id == "draw_cards":
				actions.append({
					"type": "play_hand_tactic",
					"player_id": player_id,
					"card": tactic,
				})
			elif tactic.effect_id == "redraw_card":
				for hand_target in hand:
					if hand_target == tactic or not hand_target or hand_target.is_queued_for_deletion():
						continue
					actions.append({
						"type": "play_hand_tactic",
						"player_id": player_id,
						"card": tactic,
						"hand_target": hand_target,
					})
		elif card is UpgradeCard or card is SpecialPowerCard:
			for target_slot in EffectResolver.get_legal_target_slots(_game_manager, card):
				actions.append({
					"type": "play_effect",
					"player_id": player_id,
					"card": card,
					"target_slot": target_slot,
				})

	for card in _battlefield.get_board_cards(player_id):
		if card is HeroCard:
			for target_slot in MovementResolver.get_legal_destination_slots(_game_manager, card):
				actions.append({
					"type": "move",
					"player_id": player_id,
					"card": card,
					"target_slot": target_slot,
				})
		if card is HeroCard or card is SettlementCard:
			if ProgressionResolver.get_upgrade_start_error(_game_manager, card).is_empty():
				var branches := ProgressionResolver.get_available_branches(card)
				if card.card_level == 2:
					branches = branches.filter(func(branch: Dictionary):
						return str(branch.get("id", "")) == card.selected_branch_id
					)
				for branch in branches:
					var branch_id := str(branch.get("id", ""))
					if ProgressionResolver.get_upgrade_error(_game_manager, card, branch_id).is_empty():
						actions.append({
							"type": "upgrade_level",
							"player_id": player_id,
							"card": card,
							"branch_id": branch_id,
						})


func _generate_combat_actions(player_id: int, actions: Array[Dictionary]) -> void:
	for card in _battlefield.get_board_cards(player_id):
		if not CombatResolver.get_attacker_error(_game_manager, card).is_empty():
			continue
		var target_slot := CombatResolver.get_legal_target_slot(_battlefield, _game_manager, card)
		if target_slot:
			actions.append({
				"type": "attack",
				"player_id": player_id,
				"card": card,
				"target_slot": target_slot,
			})


func _score_action(action: Dictionary, difficulty: int) -> float:
	var action_type := str(action.get("type", ""))
	var hard := difficulty == MatchSetup.AIDifficulty.HARD
	match action_type:
		"use_preparation_token":
			return 24.0
		"play_card":
			return _score_play(action, hard)
		"play_effect":
			return _score_effect(action, hard)
		"play_hand_tactic":
			var tactic := action.get("card") as SpecialPowerCard
			if not tactic:
				return -INF
			if tactic.effect_id == "draw_cards":
				return 32.0 + (tactic.intensity * 8.0) - tactic.energy_cost
			var hand_target := action.get("hand_target") as BaseCard
			return 28.0 - (_hand_keep_value(hand_target) * 0.22 if hand_target else 0.0)
		"upgrade_level":
			var card := action.get("card") as BaseCard
			return 48.0 + (float(card.card_level) * 12.0 if card else 0.0)
		"move":
			return _score_move(action, hard)
		"attack":
			return _score_attack(action, hard)
		_:
			return 0.0


func _score_play(action: Dictionary, hard: bool) -> float:
	var card := action.get("card") as BaseCard
	var slot := action.get("target_slot") as CardSlot
	if not card or not slot:
		return -INF
	var score := 34.0 + (card.get_attack_value() * 5.5) + (card.get_current_health() * 1.2)
	score -= card.energy_cost * 1.5
	if card is HeroCard:
		score += (card as HeroCard).armor * 1.2
		if slot.position_type == CardSlot.PositionType.FRONT:
			score += 3.0
		if card.has_trait("wanderer"):
			score += 10.0
		if card.has_trait("retaliate"):
			score += 0.0
		if card.has_trait("fog_weaver"):
			score += 0.0
		if card.has_trait("bulwark"):
			score += 8.0
		if card.has_trait("war_banner"):
			score += 6.0
		if card.has_trait("stormstep"):
			score += 5.0
		if card.has_trait("cleave"):
			score += 7.0
		if card.has_trait("time_thief"):
			score += 9.0
		if card.has_trait("phasewalk"):
			score += 6.0
		if card.has_trait("eclipse"):
			score += 12.0
		if card.has_trait("soulbond"):
			score += 7.0
		if card.has_trait("last_breath"):
			score += 5.0
		if card.has_trait("steadfast"):
			score += 9.0
		if card.has_trait("spore_drift"):
			score += 6.0
		if card.has_trait("afterburn"):
			score += 8.0
		if card.has_trait("petrify"):
			score += 12.0
		if card.has_trait("armor_siphon"):
			score += 9.0
		if card.has_trait("starlight_ward"):
			score += 6.0
		if card.has_trait("devourer"):
			score += 9.0
		if card.has_trait("hive_mind"):
			score += 7.0
		if card.has_trait("sporeburst"):
			score += 7.0
		if card.has_trait("gravity_well"):
			score += 12.0
		if card.has_trait("void_bite"):
			score += 9.0
	if card is SettlementCard:
		score += 5.0
		if card.effect_id in ["spell_echo", "lane_ready"]:
			score -= 4.0
	var lane_id := int(slot.lane_id)
	var enemy_id := _game_manager.get_opponent_id(card.owner_id)
	var allied_lane_cards := _count_lane_cards(card.owner_id, lane_id)
	var enemy_lane_cards := _count_lane_cards(enemy_id, lane_id)
	if card.has_trait("war_banner"):
		score += allied_lane_cards * 7.0
	if card.has_trait("soulbond"):
		score += allied_lane_cards * 4.0
	if card.has_trait("eclipse"):
		score += enemy_lane_cards * 4.0
	if card.has_trait("hive_mind"):
		score += allied_lane_cards * 4.0
	if card.has_trait("gravity_well"):
		score += enemy_lane_cards * 3.0
	# Building behind an existing push lets multiple attackers clear the same
	# priority chain instead of spreading into three harmless skirmishes.
	score += allied_lane_cards * (11.0 if hard else 10.0)
	if _battlefield.is_lane_open(enemy_id, lane_id):
		score += card.get_attack_value() * (5.0 if hard else 4.0)
	# During the opening, answer an undefended enemy lane before starting a race.
	# This delays the first HQ hit while the lane concentration above keeps the
	# established mid-game decisive.
	if (
		_game_manager.round_count <= 3
		and enemy_lane_cards > 0
		and _battlefield.is_lane_open(card.owner_id, lane_id)
	):
		score += 42.0 if hard else 34.0
	elif hard and _battlefield.is_lane_open(card.owner_id, lane_id):
		score += 8.0
	if MatchSetup.is_dominion():
		score += _score_dominion_placement(card, slot, hard)
	return score


func _score_effect(action: Dictionary, hard: bool) -> float:
	var card := action.get("card") as BaseCard
	var slot := action.get("target_slot") as CardSlot
	if not card or not slot:
		return -INF
	if card is SpecialPowerCard and card.effect_id == "revive_last_hero":
		if slot.is_occupied:
			return -INF
		var record := _game_manager.peek_last_destroyed_hero(card.owner_id)
		if record.is_empty():
			return -INF
		var hero_data := CardDatabase.get_card("heroes", str(record.get("card_id", "")))
		return (
			18.0
			+ float(hero_data.get("attack", 0)) * 3.0
			+ float(hero_data.get("energy_cost", 0))
			- card.energy_cost
		)
	if not slot.occupied_card is BaseCard:
		return -INF
	var target := slot.occupied_card as BaseCard
	if card is UpgradeCard:
		var skill := card as UpgradeCard
		var skill_score := 34.0 + (skill.bonus_attack * 8.0) + (skill.bonus_armor * 4.0) + (skill.bonus_health * 3.0)
		for trait_id in skill.granted_traits:
			match trait_id:
				"guard": skill_score += 8.0
				"retaliate": skill_score += 6.0
				"lifesteal": skill_score += 8.0 + target.get_attack_value()
				"devourer": skill_score += 9.0
				"phasewalk": skill_score += 6.0
				"cloaked": skill_score += 3.0 + target.get_attack_value()
				"siege": skill_score += 7.0
				"ranged": skill_score += 6.0
				_: skill_score += 2.0
		return skill_score
	var spell := card as SpecialPowerCard
	var score := 28.0
	match spell.effect_id:
		"damage_target", "poison_target":
			var damage := int(spell.effect_params.get("damage", spell.intensity))
			score += damage * 9.0
			if damage >= target.get_current_health():
				score += 65.0
				if MatchSetup.is_dominion():
					score += _score_dominion_removal(target, hard)
		"heal_target", "repair_structure":
			score += (target.get_max_health() - target.get_current_health()) * 7.0
		"damage_lane":
			var lane_damage := int(spell.effect_params.get("damage", spell.intensity))
			var lane_count := _count_lane_cards(target.owner_id, int(target.current_slot.lane_id))
			score += lane_damage * 8.0 * lane_count
			if MatchSetup.is_dominion():
				score += _score_dominion_lane_damage(target.owner_id, int(target.current_slot.lane_id), lane_damage, hard)
		"protect_target":
			score += target.get_attack_value() * 4.0 + target.get_current_health() * 1.5
		"stun_target":
			score += target.get_attack_value() * 8.0 + (18.0 if target.is_ready_for_combat() else 0.0)
		"push_adjacent_lane":
			score += 18.0
		"banish_target":
			score += (
				52.0
				+ target.get_attack_value() * 7.0
				+ target.get_current_health() * 2.5
				+ target.card_level * 10.0
			)
			if MatchSetup.is_dominion():
				score += _score_dominion_removal(target, hard)
		"blood_price":
			if target.get_current_health() <= int(spell.effect_params.get("health_loss", 3)):
				return -38.0
			score += int(spell.effect_params.get("cards", 2)) * 15.0
			score -= 12.0
		"detach_skill":
			score += 36.0
			score += int(target.attached_skill_modifiers.get("bonus_attack", 0)) * 8.0
			score += int(target.attached_skill_modifiers.get("bonus_armor", 0)) * 4.0
			score += int(target.attached_skill_modifiers.get("bonus_health", 0)) * 4.0
			score += target.attached_skill_added_traits.size() * 9.0
	if hard and target.card_level > 1:
		score += target.card_level * 7.0
	return score - card.energy_cost


func _score_move(action: Dictionary, hard: bool) -> float:
	var card := action.get("card") as BaseCard
	var slot := action.get("target_slot") as CardSlot
	if not card or not slot:
		return -INF
	var score := -4.0
	score -= MovementResolver.get_movement_energy_cost(card, _game_manager) * (2.0 if hard else 1.5)
	if card.has_trait("wanderer"):
		score += 18.0
	if card.has_trait("phasewalk"):
		score += 7.0
	if slot.position_type == CardSlot.PositionType.FRONT:
		score += 4.0
	if card.current_slot and int(card.current_slot.lane_id) != int(slot.lane_id):
		if card.has_trait("stormstep"):
			var storm_targets := _count_lane_cards(
				_game_manager.get_opponent_id(card.owner_id),
				int(slot.lane_id)
			)
			if storm_targets > 0:
				score += 12.0 + card.get_trait_value("stormstep_damage", 1) * 5.0
			if card.has_trait("spore_drift"):
				var spore_targets := _count_lane_cards(
					_game_manager.get_opponent_id(card.owner_id),
					int(slot.lane_id)
				)
				if spore_targets > 0:
					score += 9.0 + card.get_trait_value("spore_drift_poison", 1) * 4.0
		for ally in _battlefield.get_board_cards(card.owner_id):
			if (
				ally is SettlementCard
				and ally.effect_id == "lane_ready"
				and ally.current_slot
				and int(ally.current_slot.lane_id) == int(slot.lane_id)
			):
				score += 15.0
				break
	if hard:
		var enemy_id := _game_manager.get_opponent_id(card.owner_id)
		if _battlefield.is_lane_open(enemy_id, int(slot.lane_id)):
			score += 16.0 + card.get_attack_value() * 2.0
	if MatchSetup.is_dominion():
		score += _score_dominion_move(card, slot, hard)
	return score


func _score_attack(action: Dictionary, hard: bool) -> float:
	var attacker := action.get("card") as BaseCard
	var slot := action.get("target_slot") as CardSlot
	if not attacker or not slot or not slot.occupied_card is BaseCard:
		return -INF
	var target := slot.occupied_card as BaseCard
	var attack := attacker.get_attack_value()
	var attack_lane := int(attacker.current_slot.lane_id) if attacker.current_slot else CardSlot.Lane.NONE
	if attacker.has_trait("last_breath") and attacker.get_current_health() * 2 <= attacker.get_max_health():
		attack += attacker.get_trait_value("last_breath_damage", 2)
	attack += _get_lane_trait_value(
		attacker.owner_id,
		attack_lane,
		"war_banner",
		"war_banner_damage"
	)
	attack -= _get_lane_trait_value(
		target.owner_id,
		attack_lane,
		"eclipse",
		"eclipse_reduction"
	)
	attack = maxi(0, attack)
	var score := 70.0 + attack * 6.0
	if target.is_headquarters():
		score += 135.0
		if attack >= target.get_current_health():
			score += 1000.0
	else:
		var effective_health := target.get_current_health()
		if target is HeroCard:
			var armor_pierce := maxi(0, attacker.get_trait_value("armor_pierce", 0))
			effective_health += maxi(0, (target as HeroCard).armor - armor_pierce)
		if target.has_trait("bulwark") and bool(target.trait_runtime.get("bulwark_available", true)):
			effective_health += target.get_trait_value("bulwark_reduction", 2)
		if target.has_trait("retaliate"):
			var retaliation: int = maxi(1, target.get_trait_value("retaliate_damage", 1))
			var attacker_survival := attacker.get_current_health()
			if attacker is HeroCard:
				attacker_survival += (attacker as HeroCard).armor
			score -= 70.0 if attacker_survival <= retaliation else 12.0
		if attack >= effective_health:
			score += 95.0 + target.energy_cost * 6.0
			if (
				target is HeroCard
				and attacker.has_trait("time_thief")
				and not bool(attacker.trait_runtime.get("time_theft_used", false))
			):
				score += 44.0
			if MatchSetup.is_dominion():
				score += _score_dominion_removal(target, hard)
		if attacker.has_trait("cleave") and _count_lane_cards(target.owner_id, attack_lane) > 1:
			score += 14.0
		if target is HeroCard and attack > (target as HeroCard).armor:
			if attacker.has_trait("afterburn"):
				score += 7.0
			if attacker.has_trait("petrify"):
				score += 10.0
			if attacker.has_trait("armor_siphon"):
				score += 8.0
		if target is HeroCard and attacker.has_trait("devourer") and attack >= effective_health:
			score += 11.0
		if hard:
			score += target.get_attack_value() * 4.0 + target.card_level * 5.0
	return score


func _score_dominion_placement(card: BaseCard, slot: CardSlot, hard: bool) -> float:
	var control_value := DominionResolver.get_card_control_value(card)
	if control_value <= 0:
		return 0.0
	var lane_state := _get_dominion_lane_state(int(slot.lane_id))
	return _score_dominion_lane_delta(lane_state, card.owner_id, control_value, hard)


func _score_dominion_move(card: BaseCard, slot: CardSlot, hard: bool) -> float:
	if not card.current_slot:
		return 0.0
	var origin_lane := int(card.current_slot.lane_id)
	var destination_lane := int(slot.lane_id)
	if origin_lane == destination_lane:
		return 0.0
	var control_value := DominionResolver.get_card_control_value(card)
	if control_value <= 0:
		return 0.0
	var origin_state := _get_dominion_lane_state(origin_lane)
	var destination_state := _get_dominion_lane_state(destination_lane)
	return (
		_score_dominion_lane_delta(origin_state, card.owner_id, -control_value, hard)
		+ _score_dominion_lane_delta(destination_state, card.owner_id, control_value, hard)
	)


func _score_dominion_removal(target: BaseCard, hard: bool) -> float:
	if not target or not target.current_slot:
		return 0.0
	var control_value := DominionResolver.get_card_control_value(target)
	if control_value <= 0:
		return 0.0
	var acting_player_id := _game_manager.get_opponent_id(target.owner_id)
	var lane_state := _get_dominion_lane_state(int(target.current_slot.lane_id))
	return _score_dominion_lane_delta(lane_state, target.owner_id, -control_value, hard, acting_player_id)


func _score_dominion_lane_damage(
	target_player_id: int,
	lane_id: int,
	damage: int,
	hard: bool
) -> float:
	var removed_control := 0
	for lane_card in _battlefield.get_board_cards(target_player_id):
		if (
			lane_card.current_slot
			and int(lane_card.current_slot.lane_id) == lane_id
			and damage >= lane_card.get_current_health()
		):
			removed_control += DominionResolver.get_card_control_value(lane_card)
	if removed_control <= 0:
		return 0.0
	var acting_player_id := _game_manager.get_opponent_id(target_player_id)
	var lane_state := _get_dominion_lane_state(lane_id)
	return _score_dominion_lane_delta(lane_state, target_player_id, -removed_control, hard, acting_player_id)


func _get_dominion_lane_state(lane_id: int) -> Dictionary:
	var lane_result := DominionResolver.calculate_lane(_battlefield, lane_id)
	var control_variant: Variant = lane_result.get("control", {})
	var control: Dictionary = control_variant as Dictionary if control_variant is Dictionary else {}
	return {
		"lane_id": lane_id,
		"control": {
			1: int(control.get(1, 0)),
			2: int(control.get(2, 0)),
		},
	}


func _score_dominion_lane_delta(
	lane_state: Dictionary,
	changed_player_id: int,
	control_delta: int,
	hard: bool,
	perspective_player_id: int = 0
) -> float:
	var perspective := perspective_player_id if perspective_player_id in GameRules.PLAYER_IDS else changed_player_id
	var enemy_id := _game_manager.get_opponent_id(perspective)
	var control_variant: Variant = lane_state.get("control", {})
	var control: Dictionary = control_variant as Dictionary if control_variant is Dictionary else {}
	var before_player := int(control.get(perspective, 0))
	var before_enemy := int(control.get(enemy_id, 0))
	var after_player := before_player + (control_delta if changed_player_id == perspective else 0)
	var after_enemy := before_enemy + (control_delta if changed_player_id == enemy_id else 0)
	var before_owner := _get_dominion_owner(before_player, before_enemy, perspective, enemy_id)
	var after_owner := _get_dominion_owner(after_player, after_enemy, perspective, enemy_id)
	var before_value := _get_dominion_owner_value(before_owner, perspective)
	var after_value := _get_dominion_owner_value(after_owner, perspective)
	var ownership_weight := 58.0 if hard else 44.0
	var score := float(after_value - before_value) * ownership_weight

	# The ownership swing is decisive. A smaller bounded margin reward also
	# values progress toward a contested lane and reinforcement of a one-point lead.
	var before_margin := clampi(before_player - before_enemy, -3, 3)
	var after_margin := clampi(after_player - after_enemy, -3, 3)
	score += float(after_margin - before_margin) * (4.0 if hard else 3.0)
	if before_owner == perspective and after_owner == perspective and before_player - before_enemy <= 2:
		score += 12.0 if hard else 8.0

	return score * _get_dominion_urgency_multiplier(perspective)


func _get_dominion_owner(
	player_control: int,
	enemy_control: int,
	player_id: int,
	enemy_id: int
) -> int:
	if player_control == enemy_control:
		return 0
	return player_id if player_control > enemy_control else enemy_id


func _get_dominion_owner_value(owner_id: int, player_id: int) -> int:
	if owner_id == player_id:
		return 1
	if owner_id in GameRules.PLAYER_IDS:
		return -1
	return 0


func _get_dominion_urgency_multiplier(player_id: int) -> float:
	if not _game_manager:
		return 1.0
	var enemy_id := _game_manager.get_opponent_id(player_id)
	var player_score := int(_game_manager.player_dominion_score.get(player_id, 0))
	var enemy_score := int(_game_manager.player_dominion_score.get(enemy_id, 0))
	var highest_score := maxi(player_score, enemy_score)
	if highest_score >= GameRules.DOMINION_SCORE_TARGET - 1:
		return 1.55
	if highest_score >= GameRules.DOMINION_SCORE_TARGET - 3:
		return 1.25
	return 1.0


func _find_phase_end_action(actions: Array[Dictionary]) -> Dictionary:
	for action in actions:
		if str(action.get("type", "")) in ["advance_phase", "complete_end", "confirm_mulligan"]:
			return action
	return {}


func _opening_keep_value(card: BaseCard) -> float:
	var value := _hand_keep_value(card)
	if card is HeroCard or card is SettlementCard:
		value += 20.0 if card.energy_cost <= GameRules.STARTING_ENERGY else -8.0
	else:
		value -= 18.0
	return value


func _hand_keep_value(card: BaseCard) -> float:
	if not card:
		return -INF
	var value := float(card.get_attack_value() * 4 + card.get_current_health() * 2 - card.energy_cost)
	if card is UpgradeCard:
		var skill := card as UpgradeCard
		value = 10.0 + skill.bonus_attack * 5.0 + skill.bonus_armor * 3.0 + skill.bonus_health * 2.0
	elif card is SpecialPowerCard:
		value = 14.0 + (card as SpecialPowerCard).intensity * 2.0
	return value


func _count_lane_cards(player_id: int, lane_id: int) -> int:
	var count := 0
	for card in _battlefield.get_board_cards(player_id):
		if card.current_slot and int(card.current_slot.lane_id) == lane_id:
			count += 1
	return count


func _get_lane_trait_value(
	player_id: int,
	lane_id: int,
	trait_id: String,
	value_id: String,
	excluded_card: BaseCard = null
) -> int:
	var value := 0
	for card in _battlefield.get_board_cards(player_id):
		if (
			card == excluded_card
			or not card.current_slot
			or int(card.current_slot.lane_id) != lane_id
			or not card.has_trait(trait_id)
		):
			continue
		value = maxi(value, card.get_trait_value(value_id, 1))
	return value
