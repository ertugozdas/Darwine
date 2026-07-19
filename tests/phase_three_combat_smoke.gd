extends SceneTree

const CombatBoardStub = preload("res://tests/combat_board_stub.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_damage_healing_and_target_priority()
	await _test_hero_match_to_completion()
	_finish()

func _test_damage_healing_and_target_priority() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var slots := _create_full_lane(board, CardSlot.Lane.LEFT)
	var attacker := _place_hero(slots["p1_front"], 1, 7, 0, 6, "Saldırgan")
	var attacking_structure := _place_structure(slots["p1_structure"], 1, 5, 2, "Saldıran Yapı")
	var front := _place_hero(slots["p2_front"], 2, 2, 4, 6, "Ön Savunma")
	var back := _place_hero(slots["p2_back"], 2, 3, 0, 4, "Arka Savunma")
	var structure := _place_structure(slots["p2_structure"], 2, 8, 0, "Yapı")
	await process_frame

	_start_match(manager, 1)
	_expect(attacker.is_ready_for_combat(), "Tur başlangıcında aktif oyuncunun Tükenmiş kartı Hazır olmalı")
	_expect(manager.advance_phase(1), "Çatışma aşamasına geçilebilmeli")
	_expect(CombatResolver.can_select_attacker(manager, attacking_structure), "Saldırı değeri olan Hazır Yapı saldırgan seçilebilmeli")
	_expect(CombatResolver.get_legal_target_slot(board, manager, attacker) == slots["p2_front"], "Normal saldırı önce Ön Hattı hedeflemeli")

	var skipped_result := CombatResolver.resolve_attack(board, manager, attacker, slots["p2_back"])
	_expect(not bool(skipped_result.get("success", false)), "Ön Hat varken Arka Hat hedeflenememeli")
	_expect(attacker.is_ready_for_combat(), "Geçersiz hedef saldırganı Tüketmemeli")

	var attacker_health_before := attacker.health
	var first_hit := CombatResolver.resolve_attack(board, manager, attacker, slots["p2_front"])
	_expect(bool(first_hit.get("success", false)), "Yasal Ön Hat saldırısı çözülmeli")
	_expect(front.armor == 0 and front.health == 3, "7 hasar önce 4 Zırhı, sonra 3 Canı azaltmalı")
	_expect(attacker.health == attacker_health_before, "Savunan kart otomatik karşı saldırı yapmamalı")
	_expect(not attacker.is_ready_for_combat(), "Saldırıdan sonra kart Tükenmiş olmalı")
	_expect(not bool(CombatResolver.resolve_attack(board, manager, attacker, slots["p2_front"]).get("success", false)), "Tükenmiş kart aynı tur ikinci kez saldıramamalı")

	front.heal_combat_damage(99)
	_expect(front.health == front.max_health, "İyileştirme azami Canı aşmamalı")
	_expect(front.armor == 0, "İyileştirme Zırh yenilememeli")
	front.health = 3
	attacker.set_combat_state(BaseCard.CombatState.READY)
	var kill_result := CombatResolver.resolve_attack(board, manager, attacker, slots["p2_front"])
	_expect(bool(kill_result.get("destroyed", false)), "Canı sıfırlanan Kahraman yok edilmeli")
	_expect(not slots["p2_front"].is_occupied, "Ölen kartın yuvası anında boşalmalı")
	_expect(back.health == 4, "Fazla hasar sıradaki hedefe taşmamalı")
	_expect(CombatResolver.get_legal_target_slot(board, manager, attacker) == null, "Tükenmiş saldırgan için hedef üretilmemeli")

	attacker.set_combat_state(BaseCard.CombatState.READY)
	_expect(CombatResolver.get_legal_target_slot(board, manager, attacker) == slots["p2_back"], "Ön Hat ölünce Arka Hat ilk hedef olmalı")
	var back_result := CombatResolver.resolve_attack(board, manager, attacker, slots["p2_back"])
	_expect(bool(back_result.get("destroyed", false)) and not slots["p2_back"].is_occupied, "Arka Hat sırası geldiğinde hasarla yok edilebilmeli")
	await process_frame
	attacker.set_combat_state(BaseCard.CombatState.READY)
	_expect(CombatResolver.get_legal_target_slot(board, manager, attacker) == slots["p2_structure"], "Kahramanlar kalkınca Yapı hedef olmalı")
	var structure_hit := CombatResolver.resolve_attack(board, manager, attacker, slots["p2_structure"])
	_expect(bool(structure_hit.get("success", false)) and structure.health == 1, "Yapı normal savaş hasarı alabilmeli")
	_expect(structure.heal_combat_damage(99) == 7 and structure.health == structure.max_health, "Yapı iyileştirmesi azami Canla sınırlanmalı")
	structure.health = 1
	attacker.set_combat_state(BaseCard.CombatState.READY)
	var structure_kill := CombatResolver.resolve_attack(board, manager, attacker, slots["p2_structure"])
	_expect(bool(structure_kill.get("destroyed", false)) and not slots["p2_structure"].is_occupied, "Yapı sıfır Canda yuvasını boşaltmalı")
	await process_frame
	attacker.set_combat_state(BaseCard.CombatState.READY)
	_expect(CombatResolver.get_legal_target_slot(board, manager, attacker) == slots["p2_hq"], "Koridor açılınca Merkez hedef olmalı")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _test_hero_match_to_completion() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var slots := _create_full_lane(board, CardSlot.Lane.RIGHT)
	var attacker := _place_hero(slots["p1_front"], 1, 10, 0, 6, "Kuşatma Kahramanı")
	var winner_result := {"id": 0}
	manager.game_over.connect(func(winner: int): winner_result["id"] = winner)
	await process_frame

	_start_match(manager, 1)
	_expect(manager.advance_phase(1), "Kahraman maçı Çatışmaya geçebilmeli")
	for hit_index in range(3):
		var target := CombatResolver.get_legal_target_slot(board, manager, attacker)
		_expect(target == slots["p2_hq"], "Açık koridordaki Kahraman Merkeze saldırabilmeli")
		var result := CombatResolver.resolve_attack(board, manager, attacker, target)
		_expect(bool(result.get("success", false)), "Merkez saldırısı çözülmeli")
		if hit_index < 2:
			_expect(manager.is_game_active, "Merkez Canı sıfırlanmadan maç sürmeli")
			_cycle_back_to_player_one_combat(manager)

	_expect(int(manager.player_hq_health[2]) == 0, "Üç 10 hasarlık saldırı Merkezin 30 Canını sıfırlamalı")
	_expect(not manager.is_game_active and int(winner_result["id"]) == 1, "Merkez sıfır Can olduğunda saldıran oyuncu kazanmalı")
	_expect(not manager.advance_phase(1), "Oyun bittikten sonra faz ilerletilememeli")
	attacker.set_combat_state(BaseCard.CombatState.READY)
	_expect(not bool(CombatResolver.resolve_attack(board, manager, attacker, slots["p2_hq"]).get("success", false)), "Oyun bittikten sonra başka saldırı yapılamamalı")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _create_full_lane(board: Node, lane_id: int) -> Dictionary:
	var slots: Dictionary = {}
	for player_id in [1, 2]:
		for position_type in [CardSlot.PositionType.FRONT, CardSlot.PositionType.BACK, CardSlot.PositionType.STRUCTURE]:
			var key := "p%d_%s" % [player_id, _position_key(position_type)]
			slots[key] = board.create_lane_slot(player_id, lane_id, position_type)
		slots["p%d_hq" % player_id] = board.create_hq_slot(player_id)
		var hq := SettlementCard.new()
		hq.owner_id = player_id
		hq.card_name = "Oyuncu %d Merkez" % player_id
		hq.health = GameRules.HEADQUARTERS_HEALTH
		hq.attack = 0
		slots["p%d_hq" % player_id].add_child(hq)
	return slots

func _place_hero(slot: CardSlot, owner_id: int, attack: int, armor: int, health: int, card_name: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.attack = attack
	hero.armor = armor
	hero.health = health
	hero.card_name = card_name
	slot.add_child(hero)
	return hero

func _place_structure(slot: CardSlot, owner_id: int, health: int, attack: int, card_name: String) -> SettlementCard:
	var structure := SettlementCard.new()
	structure.owner_id = owner_id
	structure.health = health
	structure.attack = attack
	structure.card_name = card_name
	slot.add_child(structure)
	return structure

func _start_match(manager: GameManager, first_player_id: int) -> void:
	manager.cards_drawn_per_turn = 0
	_expect(manager.begin_mulligan(first_player_id), "Mulligan başlamalı")
	_expect(manager.confirm_mulligan(first_player_id), "İlk mulligan onaylanmalı")
	_expect(manager.confirm_mulligan(manager.get_opponent_id(first_player_id)), "İkinci mulligan onaylanmalı")

func _cycle_back_to_player_one_combat(manager: GameManager) -> void:
	_expect(manager.advance_phase(1), "Oyuncu 1 Çatışmayı bitirebilmeli")
	_expect(manager.complete_end_phase(1), "Oyuncu 1 turu devretmeli")
	_expect(manager.advance_phase(2), "Oyuncu 2 Çatışmaya geçmeli")
	_expect(manager.advance_phase(2), "Oyuncu 2 Çatışmayı bitirmeli")
	_expect(manager.complete_end_phase(2), "Oyuncu 2 turu devretmeli")
	_expect(manager.current_phase == GameManager.TurnPhase.PREPARATION, "Oyuncu 1 Hazırlık aşamasına dönmeli")
	_expect(manager.active_player_id == 1, "Sıra yeniden Oyuncu 1'e gelmeli")
	_expect(manager.advance_phase(1), "Oyuncu 1 yeniden Çatışmaya geçmeli")
	_expect(manager.current_phase == GameManager.TurnPhase.COMBAT, "Çatışma aşaması aktif olmalı")

func _position_key(position_type: int) -> String:
	match position_type:
		CardSlot.PositionType.FRONT:
			return "front"
		CardSlot.PositionType.BACK:
			return "back"
		_:
			return "structure"

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_THREE_COMBAT_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PHASE_THREE_COMBAT_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
