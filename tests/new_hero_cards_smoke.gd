extends SceneTree

const CombatBoardStub = preload("res://tests/combat_board_stub.gd")

const NEW_HERO_IDS := [
	"can_muhafizi",
	"kul_sancaktari",
	"firtina_nakkasi",
	"yanki_celladi",
	"zaman_hirsizi",
	"bosluk_gezgini",
	"gunesiz_kralice",
	"ruh_fenercisi",
	"kiriktac_yeminlisi",
	"demirkok_samani",
]

const NEW_TRAIT_IDS := [
	"bulwark",
	"war_banner",
	"stormstep",
	"cleave",
	"time_thief",
	"phasewalk",
	"eclipse",
	"soulbond",
	"last_breath",
	"steadfast",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	CardDatabase.load_all(true)
	_test_card_data_contract()
	await _test_bulwark()
	await _test_war_banner()
	await _test_stormstep()
	await _test_cleave()
	await _test_time_thief()
	await _test_phasewalk()
	await _test_eclipse()
	await _test_soulbond()
	await _test_last_breath()
	await _test_steadfast()
	_finish()


func _test_card_data_contract() -> void:
	_expect(CardDatabase.get_cards_for_type("heroes").size() == 54, "Kahraman havuzu 54 karta çıkmalı")
	_expect(CardDatabase.get_playable_card_refs().size() == 110, "Oynanabilir havuz 110 karta çıkmalı")
	for card_id in NEW_HERO_IDS:
		var card_data := CardDatabase.get_card("heroes", card_id)
		_expect(not card_data.is_empty(), "%s Kahraman veritabanında bulunmalı" % card_id)
		_expect(not str(card_data.get("description", "")).is_empty(), "%s açıklama taşımalı" % card_id)
		_expect(ResourceLoader.exists(str(card_data.get("image_url", ""))), "%s özgün görsel taşımalı" % card_id)
	for trait_id in NEW_TRAIT_IDS:
		_expect(CardKeywordGlossary.is_supported_keyword(trait_id), "%s ortak sözlükte açıklanmalı" % trait_id)


func _test_bulwark() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var defender_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var attacker := _place_hero(attacker_slot, 1, "gladiator")
	var defender := _place_hero(defender_slot, 2, "can_muhafizi")
	await process_frame
	_start_match(manager, 1)
	var first_hit := EffectResolver.apply_damage(manager, attacker, defender, 4, false, false, true)
	_expect(int(first_hit.get("bulwark_reduction", 0)) == 2, "Siper ilk normal saldırıdan 2 hasar azaltmalı")
	_expect(defender.health == 6 and defender.armor == 0, "Siper sonrası kalan hasarı Zırh karşılamalı")
	var second_hit := EffectResolver.apply_damage(manager, attacker, defender, 4, false, false, true)
	_expect(int(second_hit.get("bulwark_reduction", -1)) == 0, "Siper aynı tur ikinci kez çalışmamalı")
	_expect(defender.health == 2, "İkinci saldırı Siper olmadan Cana işlemeli")
	defender.reset_owner_turn_tracking()
	_expect(bool(defender.trait_runtime.get("bulwark_available", false)), "Siper sahibinin tur takibinde yenilenmeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_war_banner() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var banner_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.BACK)
	var target_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var attacker := _place_hero(attacker_slot, 1, "gladiator")
	var banner := _place_hero(banner_slot, 1, "kul_sancaktari")
	var target := _place_hero(target_slot, 2, "gladiator")
	await process_frame
	_start_match(manager, 1)
	var result := EffectResolver.apply_damage(manager, attacker, target, attacker.attack, false, false, true)
	_expect(int(result.get("war_banner_bonus", 0)) == 1, "Savaş Sancağı aynı koridordaki dosta +1 hasar vermeli")
	_expect(int(result.get("damage", 0)) == 5, "Sancaklı normal saldırı toplam 5 hasar üretmeli")
	var self_result := EffectResolver.apply_damage(manager, banner, target, banner.attack, false, false, true)
	_expect(int(self_result.get("war_banner_bonus", 0)) == 1, "Savaş Sancağı Sancaktarın kendi saldırısını da +1 artırmalı")
	_expect(int(self_result.get("damage", 0)) == 4, "Sancaktarın güçlendirilmiş normal saldırısı toplam 4 hasar üretmeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_stormstep() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var origin := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var destination := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var enemy_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var painter := _place_hero(origin, 1, "firtina_nakkasi")
	var enemy := _place_hero(enemy_slot, 2, "gladiator")
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 10
	var result := MovementResolver.resolve_move(manager, painter, destination)
	var trait_result := result.get("movement_trait_effect", {}) as Dictionary
	_expect(bool(result.get("success", false)), "Fırtına Nakkaşı yasal hareketi tamamlamalı")
	_expect(bool(trait_result.get("triggered", false)), "Akım İzi koridor değişiminde tetiklenmeli")
	_expect(enemy.armor == 0 and enemy.health == 6, "Akım İzi ilk düşmana 1 hasar vermeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_cleave() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var front_slot := board.create_lane_slot(2, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var back_slot := board.create_lane_slot(2, CardSlot.Lane.RIGHT, CardSlot.PositionType.BACK)
	var attacker := _place_hero(attacker_slot, 1, "yanki_celladi")
	_place_hero(front_slot, 2, "gladiator")
	var back_target := _place_hero(back_slot, 2, "gladiator")
	await process_frame
	_start_match(manager, 1)
	manager.advance_phase(1)
	var result := CombatResolver.resolve_attack(board, manager, attacker, front_slot)
	var cleave_result := result.get("cleave_result", {}) as Dictionary
	_expect(bool(result.get("success", false)), "Yankı Celladı normal saldırıyı çözmeli")
	_expect(int(cleave_result.get("damage", 0)) == 1, "Yarma sıradaki düşmana 1 hasar vermeli")
	_expect(back_target.armor == 0 and back_target.health == 6, "Yarma hasarı sıradaki hedefin Zırhına işlemeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_time_thief() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var front_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var back_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK)
	var thief := _place_hero(attacker_slot, 1, "zaman_hirsizi")
	_place_hero(front_slot, 2, "okcu")
	_place_hero(back_slot, 2, "okcu")
	await process_frame
	_start_match(manager, 1)
	manager.advance_phase(1)
	thief.health = 2
	var first_result := CombatResolver.resolve_attack(board, manager, thief, front_slot)
	_expect(bool(first_result.get("destroyed", false)), "Zaman Hırsızı ilk hedef Kahramanı yok etmeli")
	_expect(thief.health == 4 and thief.is_ready_for_combat(), "Çalınan An 2 Can yenileyip Kahramanı Hazır etmeli")
	_expect(bool(thief.trait_runtime.get("time_theft_used", false)), "Çalınan An tur kullanımını kaydetmeli")
	thief.health = 2
	var second_result := CombatResolver.resolve_attack(board, manager, thief, back_slot)
	_expect(bool(second_result.get("destroyed", false)), "Zaman Hırsızı Hazır olduktan sonra ikinci hedefi yok edebilmeli")
	_expect(thief.health == 2 and not thief.is_ready_for_combat(), "Çalınan An aynı tur ikinci kez çalışmamalı")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_phasewalk() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var origin := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var destination := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.BACK)
	var traveler := _place_hero(origin, 1, "bosluk_gezgini")
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 10
	_expect(MovementResolver.get_destination_error(manager, traveler, destination).is_empty(), "Faz Yürüyüşü çapraz iki koridorluk hedefi yasal kılmalı")
	var result := MovementResolver.resolve_move(manager, traveler, destination)
	_expect(bool(result.get("success", false)) and traveler.current_slot == destination, "Boşluk Gezgini uzak Faz Yürüyüşünü tamamlamalı")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_eclipse() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var target_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var eclipse_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.BACK)
	var attacker := _place_hero(attacker_slot, 1, "gladiator")
	var target := _place_hero(target_slot, 2, "gladiator")
	_place_hero(eclipse_slot, 2, "gunesiz_kralice")
	await process_frame
	_start_match(manager, 1)
	var result := EffectResolver.apply_damage(manager, attacker, target, attacker.attack, false, false, true)
	_expect(int(result.get("eclipse_reduction", 0)) == 1, "Tutulma aynı koridordaki normal saldırıyı 1 azaltmalı")
	_expect(int(result.get("damage", 0)) == 3, "Tutulma sonrası 4 taban hasar 3 olmalı")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_soulbond() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var ally_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var lantern_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.BACK)
	var enemy_slot := board.create_lane_slot(2, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var ally := _place_hero(ally_slot, 1, "okcu")
	var lantern := _place_hero(lantern_slot, 1, "ruh_fenercisi")
	var enemy := _place_hero(enemy_slot, 2, "gladiator")
	await process_frame
	_start_match(manager, 2)
	lantern.health = 4
	EffectResolver.apply_damage(manager, enemy, ally, 99, false, false, true)
	_expect(lantern.health == 5, "Ruh Bağı başka dost yok edilince 1 Can yenilemeli")
	_expect(lantern.get_status_amount("protected") == 1, "Ruh Bağı 1 Korumalı kazandırmalı")
	_expect(int(lantern.trait_runtime.get("soulbond_round", -1)) == manager.round_count, "Ruh Bağı raund kullanımını kaydetmeli")
	var second_ally := _place_hero(ally_slot, 1, "okcu")
	EffectResolver.apply_damage(manager, enemy, second_ally, 99, false, false, true)
	_expect(lantern.get_status_amount("protected") == 1, "Ruh Bağı aynı raund ikinci kez çalışmamalı")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_last_breath() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var target_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var attacker := _place_hero(attacker_slot, 1, "kiriktac_yeminlisi")
	var target := _place_hero(target_slot, 2, "gladiator")
	await process_frame
	_start_match(manager, 1)
	attacker.health = 2
	var result := EffectResolver.apply_damage(manager, attacker, target, attacker.attack, false, false, true)
	_expect(int(result.get("last_breath_bonus", 0)) == 2, "Son Nefes yarı Can altında +2 hasar vermeli")
	_expect(int(result.get("damage", 0)) == 5, "Son Nefes saldırısı toplam 5 hasar üretmeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_steadfast() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var shaman := _place_hero(slot, 1, "demirkok_samani")
	await process_frame
	_start_match(manager, 1)
	shaman.health = 6
	shaman.armor = 1
	EffectResolver.resolve_turn_end(manager, 1)
	_expect(shaman.health == 7 and shaman.armor == 1, "Kök Salma yaralıyken 1 Can yenileyip Zırhı değiştirmemeli")
	shaman.health = shaman.max_health
	EffectResolver.resolve_turn_end(manager, 1)
	_expect(shaman.health == shaman.max_health and shaman.armor == 2, "Kök Salma Can tamken bunun yerine 1 Zırh yenilemeli")
	shaman.health = 5
	shaman.armor = 0
	shaman.mark_moved_this_turn()
	EffectResolver.resolve_turn_end(manager, 1)
	_expect(shaman.health == 5 and shaman.armor == 0, "Kök Salma hareket edilen turda çalışmamalı")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)
	return hero


func _start_match(manager: GameManager, first_player_id: int) -> void:
	manager.cards_drawn_per_turn = 0
	_expect(manager.begin_mulligan(first_player_id), "Mulligan başlamalı")
	_expect(manager.confirm_mulligan(first_player_id), "İlk mulligan onaylanmalı")
	_expect(manager.confirm_mulligan(manager.get_opponent_id(first_player_id)), "İkinci mulligan onaylanmalı")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NEW_HERO_CARDS_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("NEW_HERO_CARDS_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
