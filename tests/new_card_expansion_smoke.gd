extends SceneTree

const CombatBoardStub = preload("res://tests/combat_board_stub.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	CardDatabase.load_all(true)
	_test_card_data_contract()
	await _test_wanderer()
	await _test_shadow_gate()
	await _test_fog_weaver()
	await _test_retaliation()
	await _test_echo_shrine()
	await _test_last_will()
	await _test_shadow_cloak()
	await _test_blood_price()
	await _test_rune_break()
	await _test_revival_and_banish_exclusion()
	_finish()


func _test_card_data_contract() -> void:
	var expected_cards := {
		"heroes": ["ruzgar_akincisi", "dikenli_golem", "sis_dokuyucu"],
		"settlements": ["yanki_mabedi", "golgeli_gecit"],
		"upgrades": ["son_vasiyet", "golge_pelerini"],
		"special_powers": ["kan_bedeli", "run_kirilmasi", "kullerden_donus"],
	}
	_expect(CardDatabase.get_playable_card_refs().size() == 110, "Genişleyen set toplam 110 oynanabilir kart içermeli")
	for card_type in expected_cards:
		for card_id in expected_cards[card_type]:
			var card_data := CardDatabase.get_card(card_type, card_id)
			_expect(not card_data.is_empty(), "%s/%s veritabanında bulunmalı" % [card_type, card_id])
			_expect(not str(card_data.get("description", "")).is_empty(), "%s açıklama taşımalı" % card_id)
			_expect(
				ResourceLoader.exists(str(card_data.get("image_url", ""))),
				"%s kartının özgün görseli bulunmalı" % card_id
			)
	for keyword_id in ["wanderer", "retaliate", "fog_weaver", "last_will", "cloaked"]:
		_expect(CardKeywordGlossary.KEYWORDS.has(keyword_id), "%s ortak anahtar kelime sözlüğünde olmalı" % keyword_id)


func _test_wanderer() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var origin := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var destination := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var raider := _place_hero(origin, 1, "ruzgar_akincisi")
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 0
	var result := MovementResolver.resolve_move(manager, raider, destination)
	_expect(bool(result.get("success", false)), "Rüzgâr Akıncısı Enerjisiz hareket edebilmeli")
	_expect(int(result.get("energy_spent", -1)) == 0, "Gezgin hareketi 0 Enerji harcamalı")
	_expect(raider.current_slot == destination and raider.is_ready_for_combat(), "Rüzgâr Akıncısı hareketten sonra Hazır kalmalı")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_shadow_gate() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var first_origin := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var first_destination := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var second_origin := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.BACK)
	var second_destination := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.BACK)
	var gate_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.STRUCTURE)
	var first_hero := _place_hero(first_origin, 1, "gladiator")
	var second_hero := _place_hero(second_origin, 1, "gladiator")
	_place_structure(gate_slot, 1, "golgeli_gecit")
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 10
	var first_move := MovementResolver.resolve_move(manager, first_hero, first_destination)
	var second_move := MovementResolver.resolve_move(manager, second_hero, second_destination)
	_expect(bool(first_move.get("kept_ready", false)) and first_hero.is_ready_for_combat(), "Gölgeli Geçit ilk giren Kahramanı Hazır tutmalı")
	_expect(not bool(second_move.get("kept_ready", true)) and not second_hero.is_ready_for_combat(), "Gölgeli Geçit aynı tur ikinci kez tetiklenmemeli")
	_expect(manager.has_player_turn_flag(1, "lane_ready"), "Gölgeli Geçit tur başına kullanımını işaretlemeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_fog_weaver() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var ranged_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK)
	var fog_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var ranged := _place_hero(ranged_slot, 1, "okcu")
	_place_hero(fog_slot, 2, "sis_dokuyucu")
	await process_frame
	_start_match(manager, 1)
	manager.advance_phase(1)
	_expect(
		"Sis Perdesi" in CombatResolver.get_attacker_error(manager, ranged),
		"Sis Dokuyucu aynı koridordaki Menzilli Kahramanın Arka Hat saldırısını engellemeli"
	)
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_retaliation() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var defender_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var attacker := _place_hero(attacker_slot, 1, "")
	var golem := _place_hero(defender_slot, 2, "dikenli_golem")
	await process_frame
	attacker.attack = 3
	attacker.armor = 0
	attacker.max_armor = 0
	attacker.health = 5
	attacker.max_health = 5
	_start_match(manager, 1)
	manager.advance_phase(1)
	var result := CombatResolver.resolve_attack(board, manager, attacker, defender_slot)
	_expect(bool(result.get("success", false)) and golem.health > 0, "Dikenli Golem normal saldırıdan sağ çıkmalı")
	_expect(result.get("retaliation_result", {}) is Dictionary, "Dikenli Golem Misilleme sonucu üretmeli")
	_expect(attacker.health == 4, "Misilleme saldırgana ortak hasar hattından 1 hasar vermeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_echo_shrine() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var shrine_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE)
	_place_structure(shrine_slot, 1, "yanki_mabedi")
	var first_spell := _make_spell(board, 1, "kivilcim")
	var second_spell := _make_spell(board, 1, "yildirim")
	await process_frame
	_start_match(manager, 1)
	var energy_before := manager.get_available_energy(1)
	var first_result := EffectResolver.resolve_special_power_echo(manager, first_spell)
	var second_result := EffectResolver.resolve_special_power_echo(manager, second_spell)
	_expect(bool(first_result.get("triggered", false)), "Yankı Mabedi ilk Özel Güçte tetiklenmeli")
	_expect(not bool(second_result.get("triggered", true)), "Yankı Mabedi aynı tur ikinci Özel Güçte tetiklenmemeli")
	_expect(manager.get_available_energy(1) == energy_before + 1, "Yankı Mabedi turda tam 1 geçici Enerji vermeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_last_will() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var hero_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var hero := _place_hero(hero_slot, 1, "gladiator")
	var will := _make_skill(board, 1, "son_vasiyet")
	var draw_requests: Array[int] = []
	manager.effect_draw_requested.connect(func(player_id: int, count: int, _source: BaseCard):
		if player_id == 1:
			draw_requests.append(count)
	)
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 10
	var attach_result := EffectResolver.resolve_targeted_card(manager, will, hero_slot)
	_expect(bool(attach_result.get("success", false)) and hero.has_trait("last_will"), "Son Vasiyet Kahramana bağlanmalı")
	EffectResolver.apply_damage(manager, null, hero, 99, false, false)
	_expect(draw_requests == [1], "Son Vasiyet yok edilince tam 1 etki çekişi istemeli")
	_expect(not manager.peek_last_destroyed_hero(1).is_empty(), "Yok edilen Kahraman diriltme geçmişine yazılmalı")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_shadow_cloak() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var target_slot := board.create_lane_slot(2, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var attacker := _place_hero(attacker_slot, 1, "gladiator")
	var target := _place_hero(target_slot, 2, "gladiator")
	var cloak := _make_skill(board, 2, "golge_pelerini")
	await process_frame
	_start_match(manager, 2)
	manager.player_current_energy[2] = 10
	var base_health := target.max_health
	var cloak_result := EffectResolver.resolve_targeted_card(manager, cloak, target_slot)
	_expect(bool(cloak_result.get("success", false)), "Gölge Pelerini Kahramana bağlanmalı")
	_expect(target.has_trait("cloaked") and target.max_health == base_health + 2, "Gölge Pelerini Örtülü ve +2 Can vermeli")

	manager.active_player_id = 1
	manager.player_current_energy[1] = 10
	var direct_spell := _make_spell(board, 1, "kivilcim")
	var lane_spell := _make_spell(board, 1, "alev_dalgasi")
	await process_frame
	_expect(not EffectResolver.get_card_target_error(manager, direct_spell, target_slot).is_empty(), "Örtülü hedef doğrudan düşman Özel Gücünü reddetmeli")
	_expect(EffectResolver.get_card_target_error(manager, lane_spell, target_slot).is_empty(), "Örtülü hedef alan Özel Gücünden korunmamalı")
	manager.active_player_id = 2
	target.set_combat_state(BaseCard.CombatState.READY)
	manager.advance_phase(2)
	var attack_result := CombatResolver.resolve_attack(board, manager, target, attacker_slot)
	_expect(bool(attack_result.get("success", false)), "Örtülü Kahraman normal saldırı yapabilmeli")
	_expect(not target.has_trait("cloaked"), "Örtülü Kahraman ilk normal saldırısını yapınca örtü kalkmalı")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_blood_price() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var survivor_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var doomed_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var survivor := _place_hero(survivor_slot, 1, "gladiator")
	var doomed := _place_hero(doomed_slot, 1, "gladiator")
	var first_price := _make_spell(board, 1, "kan_bedeli")
	var second_price := _make_spell(board, 1, "kan_bedeli")
	var requested_cards: Array[int] = []
	manager.effect_draw_requested.connect(func(player_id: int, count: int, _source: BaseCard):
		if player_id == 1:
			requested_cards.append(count)
	)
	await process_frame
	survivor.health = 5
	survivor.armor = 2
	survivor.apply_status(EffectResolver.STATUS_PROTECTED, 4)
	doomed.health = 3
	doomed.armor = 3
	doomed.apply_status(EffectResolver.STATUS_PROTECTED, 5)
	_start_match(manager, 1)
	manager.player_current_energy[1] = 10
	var first_result := EffectResolver.resolve_targeted_card(manager, first_price, survivor_slot)
	_expect(bool(first_result.get("success", false)) and survivor.health == 2, "Kan Bedeli hayatta kalan dosttan 3 doğrudan Can götürmeli")
	_expect(survivor.armor == 2 and survivor.get_status_amount("protected") == 4, "Kan Bedeli Zırh ve Korumalıyı tüketmemeli")
	_expect(requested_cards == [2], "Kan Bedeli hayatta kalınca 2 kart çekişi istemeli")
	var second_result := EffectResolver.resolve_targeted_card(manager, second_price, doomed_slot)
	_expect(bool(second_result.get("destroyed", false)), "3 Canlı Kahraman Kan Bedeliyle yok edilmeli")
	_expect(requested_cards == [2], "Kan Bedelinde yok edilen Kahraman kart çektirmemeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_rune_break() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var target_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var target := _place_hero(target_slot, 2, "gladiator")
	var vampire_rune := _make_skill(board, 2, "vampir_runu")
	await process_frame
	var base_attack := target.attack
	var base_health := target.max_health
	_start_match(manager, 2)
	manager.player_current_energy[2] = 10
	var attach_result := EffectResolver.resolve_targeted_card(manager, vampire_rune, target_slot)
	_expect(bool(attach_result.get("success", false)), "Bozulacak Beceri önce düşman Kahramana bağlanmalı")
	_expect(target.attack == base_attack + 1 and target.max_health == base_health + 2 and target.has_trait("lifesteal"), "Bağlı Beceri stat ve nitelik bonuslarını uygulamalı")

	manager.active_player_id = 1
	manager.player_current_energy[1] = 10
	var rune_break := _make_spell(board, 1, "run_kirilmasi")
	await process_frame
	var break_result := EffectResolver.resolve_targeted_card(manager, rune_break, target_slot)
	_expect(bool(break_result.get("success", false)), "Rün Kırılması bağlı düşman Becerisini kaldırmalı")
	_expect(target.attack == base_attack and target.max_health == base_health, "Rün Kırılması kalıcı stat bonuslarını geri almalı")
	_expect(not target.has_trait("lifesteal") and target.attached_skill_name.is_empty(), "Rün Kırılması Beceri niteliklerini ve yuva kaydını temizlemeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_revival_and_banish_exclusion() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var origin_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var revive_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.BACK)
	var hero := _place_hero(origin_slot, 1, "ruzgar_akincisi")
	var skill := _make_skill(board, 1, "son_vasiyet")
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 20
	EffectResolver.resolve_targeted_card(manager, skill, origin_slot)
	EffectResolver.apply_damage(manager, null, hero, 99, false, false)
	_expect(str(manager.peek_last_destroyed_hero(1).get("card_id", "")) == "ruzgar_akincisi", "Son yok edilen dost Kahraman kaydı korunmalı")

	var revival := _make_spell(board, 1, "kullerden_donus")
	await process_frame
	var revive_result := EffectResolver.resolve_targeted_card(manager, revival, revive_slot)
	var revived := revive_result.get("revived_card") as HeroCard
	_expect(bool(revive_result.get("success", false)) and revived != null, "Küllerden Dönüş boş dost Arka Hatta çözülmeli")
	if revived:
		_expect(revived.card_id == "ruzgar_akincisi", "Küllerden Dönüş son yok edilen Kahramanı döndürmeli")
		_expect(revived.card_level == 1 and revived.experience == 0, "Dirilen Kahraman Seviye 1 ve 0 deneyimle dönmeli")
		_expect(revived.attack == 3 and revived.max_health == 5 and revived.health == 1, "Dirilen Kahraman temel değerleri ve 1 Canla dönmeli")
		_expect(not revived.is_ready_for_combat() and revived.attached_skill_name.is_empty(), "Dirilen Kahraman Tükenmiş ve Becerisiz dönmeli")
	_expect(manager.peek_last_destroyed_hero(1).is_empty(), "Kullanılan diriltme kaydı tüketilmeli")

	var banish_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	_place_hero(banish_slot, 1, "gladiator")
	manager.active_player_id = 2
	manager.player_current_energy[2] = 20
	var banish := _make_spell(board, 2, "hiclik_fermani")
	await process_frame
	var banish_result := EffectResolver.resolve_targeted_card(manager, banish, banish_slot)
	_expect(bool(banish_result.get("banished", false)), "Sürgün testi hedefi sahadan silmeli")
	_expect(manager.peek_last_destroyed_hero(1).is_empty(), "Sürgün edilen Kahraman diriltme geçmişine girmemeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)
	return hero


func _place_structure(slot: CardSlot, owner_id: int, card_id: String) -> SettlementCard:
	var structure := SettlementCard.new()
	structure.owner_id = owner_id
	structure.card_id = card_id
	slot.add_child(structure)
	return structure


func _make_skill(parent: Node, owner_id: int, card_id: String) -> UpgradeCard:
	var skill := UpgradeCard.new()
	skill.owner_id = owner_id
	skill.card_id = card_id
	parent.add_child(skill)
	return skill


func _make_spell(parent: Node, owner_id: int, card_id: String) -> SpecialPowerCard:
	var spell := SpecialPowerCard.new()
	spell.owner_id = owner_id
	spell.card_id = card_id
	parent.add_child(spell)
	return spell


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
		print("NEW_CARD_EXPANSION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("NEW_CARD_EXPANSION_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
