extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	MatchSetup.configure_local(8102)
	MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	await process_frame
	await process_frame
	var manager := battlefield.get_node("GameManager") as GameManager
	var rng := RandomNumberGenerator.new()
	rng.seed = 8102
	var planner := AIActionPlanner.new()
	planner.setup(battlefield, manager, rng)

	await _test_placement_prioritizes_lane_capture(battlefield, planner)
	await _test_move_values_both_lanes(battlefield, planner)
	await _test_lethal_attack_values_lane_flip(battlefield, planner)
	_test_match_point_urgency(manager, battlefield, planner)

	battlefield.queue_free()
	current_scene = null
	await process_frame
	MatchSetup.configure_local(1)
	_finish()


func _test_placement_prioritizes_lane_capture(
	battlefield: BattlefieldUI,
	planner: AIActionPlanner
) -> void:
	await _clear_board(battlefield)
	_place_hero(_get_slot(battlefield, 1, "Slot_F1"), 1)
	_place_structure(_get_slot(battlefield, 2, "Slot_S1"), 2)
	await process_frame

	var candidate := HeroCard.new()
	candidate.owner_id = 2
	candidate.health = 5
	root.add_child(candidate)
	await process_frame
	var capture_slot := _get_slot(battlefield, 2, "Slot_B1")
	var open_slot := _get_slot(battlefield, 2, "Slot_B2")
	var medium_capture := float(planner.call("_score_dominion_placement", candidate, capture_slot, false))
	var medium_open := float(planner.call("_score_dominion_placement", candidate, open_slot, false))
	var hard_capture := float(planner.call("_score_dominion_placement", candidate, capture_slot, true))
	var hard_open := float(planner.call("_score_dominion_placement", candidate, open_slot, true))
	_expect(medium_capture > medium_open, "Orta AI rakibin koridorunu alan yerleşimi boş koridora tercih etmeli")
	_expect(hard_capture > hard_open, "Zor AI rakibin koridorunu alan yerleşimi boş koridora tercih etmeli")
	candidate.queue_free()
	await process_frame


func _test_move_values_both_lanes(battlefield: BattlefieldUI, planner: AIActionPlanner) -> void:
	await _clear_board(battlefield)
	var mover := _place_hero(_get_slot(battlefield, 2, "Slot_F1"), 2)
	_place_hero(_get_slot(battlefield, 1, "Slot_F2"), 1)
	_place_structure(_get_slot(battlefield, 2, "Slot_S2"), 2)
	await process_frame

	var capture_slot := _get_slot(battlefield, 2, "Slot_B2")
	var open_slot := _get_slot(battlefield, 2, "Slot_B3")
	var capture_score := float(planner.call("_score_dominion_move", mover, capture_slot, false))
	var open_score := float(planner.call("_score_dominion_move", mover, open_slot, false))
	_expect(capture_score > open_score, "AI hareketin hem terk edilen hem ele geçirilen koridora etkisini birlikte tartmalı")


func _test_lethal_attack_values_lane_flip(
	battlefield: BattlefieldUI,
	planner: AIActionPlanner
) -> void:
	await _clear_board(battlefield)
	var flip_target := _place_hero(_get_slot(battlefield, 1, "Slot_F1"), 1, 2, 3)
	_place_hero(_get_slot(battlefield, 1, "Slot_B1"), 1, 2, 5)
	var flip_attacker := _place_hero(_get_slot(battlefield, 2, "Slot_F1"), 2, 5, 5)
	_place_structure(_get_slot(battlefield, 2, "Slot_S1"), 2)

	var neutral_target := _place_hero(_get_slot(battlefield, 1, "Slot_F3"), 1, 2, 3)
	var neutral_attacker := _place_hero(_get_slot(battlefield, 2, "Slot_F3"), 2, 5, 5)
	await process_frame

	var flip_score := float(planner.call("_score_attack", {
		"card": flip_attacker,
		"target_slot": flip_target.current_slot,
	}, false))
	var neutral_score := float(planner.call("_score_attack", {
		"card": neutral_attacker,
		"target_slot": neutral_target.current_slot,
	}, false))
	_expect(flip_score > neutral_score, "Öldürücü saldırı koridoru rakipten alıyorsa AI daha yüksek değer vermeli")


func _test_match_point_urgency(
	manager: GameManager,
	battlefield: BattlefieldUI,
	planner: AIActionPlanner
) -> void:
	manager.player_dominion_score = {1: 0, 2: 0}
	var target := _get_slot(battlefield, 1, "Slot_F1").occupied_card as BaseCard
	var normal_score := float(planner.call("_score_dominion_removal", target, false))
	manager.player_dominion_score = {1: GameRules.DOMINION_SCORE_TARGET - 1, 2: 4}
	var urgent_score := float(planner.call("_score_dominion_removal", target, false))
	_expect(urgent_score > normal_score, "Maç puanına gelindiğinde koridor hamlesinin aciliyeti artmalı")


func _clear_board(battlefield: BattlefieldUI) -> void:
	for slot in battlefield.get_board_slots():
		if not slot.is_occupied or not is_instance_valid(slot.occupied_card):
			continue
		var card := slot.occupied_card
		slot.release_card()
		card.queue_free()
	await process_frame


func _get_slot(battlefield: BattlefieldUI, player_id: int, slot_name: String) -> CardSlot:
	return battlefield.get_node("Player%dZone/Grid/%s" % [player_id, slot_name]) as CardSlot


func _place_hero(
	slot: CardSlot,
	owner_id: int,
	attack: int = 3,
	health: int = 5
) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.attack = attack
	hero.health = health
	slot.add_child(hero)
	return hero


func _place_structure(slot: CardSlot, owner_id: int) -> SettlementCard:
	var structure := SettlementCard.new()
	structure.owner_id = owner_id
	structure.health = 5
	slot.add_child(structure)
	return structure


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DOMINION_AI_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("DOMINION_AI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
