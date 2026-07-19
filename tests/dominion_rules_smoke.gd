extends SceneTree

const BOARD_STUB := preload("res://tests/combat_board_stub.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_control_calculation()
	await _test_full_round_scoring()
	await _test_target_and_sudden_death()
	await _test_siege_is_unchanged()
	MatchSetup.configure_local(1)
	_finish()


func _test_control_calculation() -> void:
	var board := _create_board()
	root.add_child(board)
	await process_frame

	var left_p1_hero := _place_card(board, 1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT, HeroCard.new())
	_place_card(board, 2, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE, SettlementCard.new())
	_place_card(board, 1, CardSlot.Lane.CENTER, CardSlot.PositionType.STRUCTURE, SettlementCard.new())
	_place_card(board, 2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT, HeroCard.new())
	_place_card(board, 1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT, HeroCard.new())
	_place_card(board, 2, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT, HeroCard.new())

	var result := DominionResolver.calculate_board(board, 1)
	var lanes := result.get("lane_results", []) as Array
	var points := result.get("points_awarded", {}) as Dictionary
	_expect(lanes.size() == 3, "Hakimiyet üç koridoru da çözmeli")
	_expect(int((lanes[0] as Dictionary).get("owner_id", 0)) == 1, "2 güce karşı 1 güçte Oyuncu 1 Sol koridoru almalı")
	_expect(int((lanes[1] as Dictionary).get("owner_id", 0)) == 2, "1 güce karşı 2 güçte Oyuncu 2 Orta koridoru almalı")
	_expect(int((lanes[2] as Dictionary).get("owner_id", -1)) == 0, "Eşit kontrol gücü koridoru tarafsız bırakmalı")
	_expect(int(points.get(1, 0)) == 1 and int(points.get(2, 0)) == 1, "Yalnızca kontrol edilen koridorlar puan vermeli")

	left_p1_hero.health = 0
	var dead_result := DominionResolver.calculate_lane(board, CardSlot.Lane.LEFT)
	_expect(int(dead_result.get("owner_id", 0)) == 2, "Yok edilmiş kart Hakimiyet gücü üretmemeli")

	board.queue_free()
	await process_frame


func _test_full_round_scoring() -> void:
	MatchSetup.configure_local(2026)
	MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
	var board := _create_board()
	var manager := GameManager.new()
	root.add_child(board)
	root.add_child(manager)
	await process_frame

	_place_card(board, 1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT, HeroCard.new())
	_place_card(board, 1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT, HeroCard.new())
	_place_card(board, 2, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT, HeroCard.new())
	manager.round_completed.connect(func(round_number: int):
		manager.apply_dominion_round_result(DominionResolver.calculate_board(board, round_number))
	)

	_expect(manager.begin_mulligan(1), "Hakimiyet mulliganı başlamalı")
	_expect(manager.has_preparation_token(1), "Hakimiyet son hamle avantajını dengelemek için Hazırlık Jetonunu ilk oyuncuya vermeli")
	_expect(not manager.has_preparation_token(2), "Hakimiyet ikinci oyuncuya ek açılış jetonu vermemeli")
	_expect(manager.confirm_mulligan(1), "İlk mulligan onaylanmalı")
	_expect(manager.confirm_mulligan(2), "İkinci mulligan onaylanmalı")
	_finish_turn(manager)
	_expect(int(manager.player_dominion_score[1]) == 0, "İlk kişisel tur sonunda Hakimiyet puanı verilmemeli")
	_expect(manager.get_available_energy(2) == GameRules.STARTING_ENERGY, "Hakimiyet ikinci oyuncusu ilk raundda ek taban Enerji almamalı")
	_finish_turn(manager)
	_expect(int(manager.player_dominion_score[1]) == 2, "Tam raund sonunda Oyuncu 1 iki puan almalı")
	_expect(int(manager.player_dominion_score[2]) == 1, "Tam raund sonunda Oyuncu 2 bir puan almalı")
	_expect(manager.active_player_id == 1, "Puanlama sonrası yeni raund ilk oyuncuyla başlamalı")

	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_target_and_sudden_death() -> void:
	MatchSetup.configure_local(3030)
	MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
	var manager := GameManager.new()
	root.add_child(manager)
	await process_frame

	var tied_result := {
		"round_number": 6,
		"lane_results": [],
		"points_awarded": {1: GameRules.DOMINION_SCORE_TARGET, 2: GameRules.DOMINION_SCORE_TARGET},
	}
	_expect(manager.apply_dominion_round_result(tied_result) == 0, "Eşit hedef puanı ani kazanan üretmemeli")
	_expect(manager.is_game_active, "Eşit hedef puanında maç ani ölüme devam etmeli")
	var winning_result := {
		"round_number": 7,
		"lane_results": [],
		"points_awarded": {1: 1, 2: 0},
	}
	_expect(manager.apply_dominion_round_result(winning_result) == 1, "Ani ölümde öne geçen oyuncu kazanmalı")
	_expect(not manager.is_game_active and manager.win_reason == "dominion", "Hakimiyet zafer nedeni saklanmalı")

	manager.queue_free()
	await process_frame


func _test_siege_is_unchanged() -> void:
	MatchSetup.configure_local(4040)
	var manager := GameManager.new()
	root.add_child(manager)
	await process_frame
	var result := {
		"round_number": 1,
		"lane_results": [],
		"points_awarded": {1: 12, 2: 0},
	}
	_expect(manager.apply_dominion_round_result(result) == 0, "Kuşatma kuralları Hakimiyet sonucunu yok saymalı")
	_expect(int(manager.player_dominion_score[1]) == 0 and manager.is_game_active, "Kuşatma maçının skoru değişmemeli")
	manager.set_hq_health(2, 0)
	_expect(not manager.is_game_active and manager.win_reason == "headquarters", "Merkez zaferi mevcut davranışını korumalı")
	manager.queue_free()
	await process_frame


func _create_board() -> Node:
	var board := BOARD_STUB.new()
	for player_id in GameRules.PLAYER_IDS:
		for lane_id in DominionResolver.LANES:
			board.create_lane_slot(player_id, lane_id, CardSlot.PositionType.FRONT)
			board.create_lane_slot(player_id, lane_id, CardSlot.PositionType.BACK)
			board.create_lane_slot(player_id, lane_id, CardSlot.PositionType.STRUCTURE)
	return board


func _place_card(
	board: Node,
	player_id: int,
	lane_id: int,
	position_type: int,
	card: BaseCard
) -> BaseCard:
	var target_slot: CardSlot = null
	for slot_variant in board.get_lane_slots(player_id, lane_id):
		var slot := slot_variant as CardSlot
		if slot and int(slot.position_type) == position_type:
			target_slot = slot
			break
	if not target_slot:
		return card
	card.owner_id = player_id
	target_slot.add_child(card)
	card.current_slot = target_slot
	target_slot.accept_card(card)
	return card


func _finish_turn(manager: GameManager) -> void:
	var player_id := manager.active_player_id
	_expect(manager.advance_phase(player_id), "Hazırlık fazı ilerlemeli")
	_expect(manager.advance_phase(player_id), "Çatışma fazı ilerlemeli")
	_expect(manager.complete_end_phase(player_id), "Tur Sonu tamamlanmalı")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DOMINION_RULES_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("DOMINION_RULES_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
