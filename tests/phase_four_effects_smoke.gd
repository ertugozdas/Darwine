extends SceneTree

const CombatBoardStub = preload("res://tests/combat_board_stub.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_card_data_contract()
	await _test_traits_and_shared_damage_pipeline()
	await _test_skill_slot_and_target_validation()
	await _test_all_targeted_spells_and_statuses()
	await _test_structure_turn_effects()
	await _test_new_content_mechanics()
	_finish()

func _test_card_data_contract() -> void:
	CardDatabase.load_all(true)
	for card_type in ["heroes", "settlements", "upgrades", "special_powers"]:
		_expect(
			CardDatabase.get_cards_for_type(card_type).size() >= 3,
			"%s türünde en az üç oynanabilir kart olmalı" % card_type
		)

	var spells := CardDatabase.get_cards_for_type("special_powers")
	_expect(spells.size() == 19, "On dokuz Büyünün tamamı veri sözleşmesinde bulunmalı")
	for spell_variant in spells:
		var spell := spell_variant as Dictionary
		_expect(not str(spell.get("effect_id", "")).is_empty(), "Her Büyünün merkezi effect_id alanı olmalı")
		_expect(spell.get("effect_params", {}) is Dictionary, "Her Büyünün sayısal effect_params alanı olmalı")
	var banish := CardDatabase.get_card("special_powers", "hiclik_fermani")
	_expect(str(banish.get("effect_id", "")) == "banish_target", "Hiçlik Fermanı sahadan silme etkisini taşımalı")
	_expect(int(banish.get("energy_cost", 0)) == 6, "Hiçlik Fermanı güçlü kaldırma etkisi için 6 Enerji olmalı")

func _test_traits_and_shared_damage_pipeline() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)

	var ranged_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK)
	var ranged_target_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var ranged := _place_hero(ranged_slot, 1, "okcu")
	_place_hero(ranged_target_slot, 2, "")

	var melee_back_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.BACK)
	var guard_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var guarded_structure_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.STRUCTURE)
	var melee_back := _place_hero(melee_back_slot, 1, "gladiator")
	var guard := _place_hero(guard_slot, 1, "sovalye")
	var guarded_structure := _place_structure(guarded_structure_slot, 1, "tas_sur")

	var siege_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var healer_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.BACK)
	var siege_target_slot := board.create_lane_slot(2, CardSlot.Lane.RIGHT, CardSlot.PositionType.STRUCTURE)
	var siege := _place_hero(siege_slot, 1, "troll")
	var healer := _place_hero(healer_slot, 1, "peri")
	var siege_target := _place_structure(siege_target_slot, 2, "")
	siege_target.health = 12
	siege_target.max_health = 12

	await process_frame
	_start_match(manager, 1)
	_expect(manager.advance_phase(1), "Özellik testi Çatışma aşamasına geçebilmeli")
	_expect(CombatResolver.can_select_attacker(manager, ranged), "Menzilli Kahraman Arka Hattan saldırabilmeli")
	_expect(not CombatResolver.can_select_attacker(manager, melee_back), "Menzilli olmayan Kahraman Arka Hattan saldıramamalı")

	var siege_result := CombatResolver.resolve_attack(board, manager, siege, siege_target_slot)
	_expect(bool(siege_result.get("success", false)), "Kuşatma saldırısı merkezi hasar hattında çözülmeli")
	_expect(int(siege_result.get("siege_bonus", 0)) == 2, "Kuşatma Yapıya +2 hasar vermeli")
	_expect(siege_target.health == 6, "4 Saldırı ve +2 Kuşatma toplam 6 hasar vermeli")

	var guard_health_before := guard.health
	var structure_health_before := guarded_structure.health
	var guarded_hit := EffectResolver.apply_damage(manager, null, guarded_structure, 3, true, false)
	_expect(bool(guarded_hit.get("guard_redirected", false)), "Muhafız dost Yapıya giden ilk hasarı üstlenmeli")
	_expect(guard.health < guard_health_before, "Yönlendirilen hasarı Muhafız almalı")
	_expect(guarded_structure.health == structure_health_before, "İlk yönlendirmede Yapı hasar almamalı")
	var second_structure_hit := EffectResolver.apply_damage(manager, null, guarded_structure, 3, true, false)
	_expect(not bool(second_structure_hit.get("guard_redirected", false)), "Muhafız yenilenmeden ikinci hasarı üstlenmemeli")
	_expect(guarded_structure.health == structure_health_before - 3, "İkinci hasar Yapıya ulaşmalı")

	var fast_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var fast := _place_hero(fast_slot, 1, "capulcu")
	fast.on_played_to_board()
	_expect(fast.is_ready_for_combat(), "Hızlı Kahraman oyuna girdiği tur Hazır başlamalı")
	fast.apply_status(EffectResolver.STATUS_PROTECTED, 2)
	var protected_hit := EffectResolver.apply_damage(manager, null, fast, 5, false, false)
	_expect(int(protected_hit.get("blocked_damage", 0)) == 2, "Korumalı sonraki hasarı belirtilen miktarda azaltmalı")
	_expect(fast.get_status_amount(EffectResolver.STATUS_PROTECTED) == 0, "Korumalı tek hasardan sonra tüketilmeli")

	# The healer resolves through the same end-of-turn pipeline as structures and poison.
	siege.health = 4
	siege.armor = 0
	EffectResolver.resolve_turn_end(manager, 1)
	_expect(siege.health == 6, "Şifacı aynı koridordaki en yaralı dosta 2 Can vermeli")
	_expect(healer.has_trait("healer"), "Şifacı etiketi kart verisinden yüklenmeli")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _test_skill_slot_and_target_validation() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var hero_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var second_hero_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK)
	var structure_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE)
	var rune_hero_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var siege_structure_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.STRUCTURE)
	var hero := _place_hero(hero_slot, 1, "gladiator")
	var second_hero := _place_hero(second_hero_slot, 1, "gladiator")
	var structure := _place_structure(structure_slot, 1, "tas_sur")
	var rune_hero := _place_hero(rune_hero_slot, 1, "gladiator")
	var siege_structure := _place_structure(siege_structure_slot, 1, "tas_sur")
	var shield_skill := _make_skill(board, 1, "celik_kalkan")
	var ranged_skill := _make_skill(board, 1, "keskin_nisancilik")
	var foundation_skill := _make_skill(board, 1, "guclendirilmis_temel")
	var vampire_skill := _make_skill(board, 1, "vampir_runu")
	var siege_skill := _make_skill(board, 1, "kusatma_muhimmati")
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 20

	var energy_before_invalid := manager.get_available_energy(1)
	var invalid_result := EffectResolver.resolve_targeted_card(manager, shield_skill, structure_slot)
	_expect(not bool(invalid_result.get("success", false)), "Kahraman Becerisi Yapıyı hedefleyememeli")
	_expect(manager.get_available_energy(1) == energy_before_invalid, "Geçersiz Beceri hedefi Enerji harcatmamalı")

	var hero_health_before := hero.max_health
	var valid_result := EffectResolver.resolve_targeted_card(manager, shield_skill, hero_slot)
	_expect(bool(valid_result.get("success", false)), "Geçerli Beceri hedefe bağlanabilmeli")
	_expect(hero.attached_skill == shield_skill and shield_skill.get_parent() == hero, "Hedef tek Beceri yuvasında gerçek kartı saklamalı")
	_expect(hero.max_health == hero_health_before + 2 and hero.armor >= 3, "Çelik Kalkan tanımlı Zırh ve Can bonuslarını vermeli")
	_expect(hero.get_status_amount(EffectResolver.STATUS_PROTECTED) == 2, "Çelik Kalkan Korumalı 2 vermeli")

	var energy_before_full_slot := manager.get_available_energy(1)
	var full_slot_result := EffectResolver.resolve_targeted_card(manager, ranged_skill, hero_slot)
	_expect(not bool(full_slot_result.get("success", false)), "Dolu Beceri yuvasına ikinci Beceri bağlanamamalı")
	_expect(manager.get_available_energy(1) == energy_before_full_slot, "Dolu Beceri yuvası Enerji harcatmamalı")

	var ranged_result := EffectResolver.resolve_targeted_card(manager, ranged_skill, second_hero_slot)
	_expect(bool(ranged_result.get("success", false)), "İkinci Kahramana ayrı Beceri bağlanabilmeli")
	_expect(second_hero.has_trait("ranged"), "Keskin Nişancılık Menzilli özelliği kazandırmalı")
	var structure_health_before := structure.max_health
	var foundation_result := EffectResolver.resolve_targeted_card(manager, foundation_skill, structure_slot)
	_expect(bool(foundation_result.get("success", false)), "Yapı Becerisi doğru Yapı hedefinde çözülmeli")
	_expect(structure.max_health == structure_health_before + 4, "Güçlendirilmiş Temel Yapıya +4 azami Can vermeli")

	var rune_attack_before := rune_hero.attack
	var rune_health_before := rune_hero.max_health
	var vampire_result := EffectResolver.resolve_targeted_card(manager, vampire_skill, rune_hero_slot)
	_expect(bool(vampire_result.get("success", false)), "Vampir Rünü dost Kahramana bağlanabilmeli")
	_expect(rune_hero.attack == rune_attack_before + 1, "Vampir Rünü +1 Saldırı vermeli")
	_expect(rune_hero.max_health == rune_health_before + 2, "Vampir Rünü +2 Can vermeli")
	_expect(rune_hero.has_trait("lifesteal"), "Vampir Rünü Can Çalma kazandırmalı")

	var siege_attack_before := siege_structure.attack
	var siege_result := EffectResolver.resolve_targeted_card(manager, siege_skill, siege_structure_slot)
	_expect(bool(siege_result.get("success", false)), "Kuşatma Mühimmatı dost Yapıya bağlanabilmeli")
	_expect(siege_structure.attack == siege_attack_before + 2, "Kuşatma Mühimmatı +2 Saldırı vermeli")
	_expect(siege_structure.has_trait("siege"), "Kuşatma Mühimmatı Kuşatma kazandırmalı")

	EffectResolver.apply_damage(manager, null, hero, 99, false, false)
	await process_frame
	_expect(not hero_slot.is_occupied, "Becerili hedef yok edildiğinde yuvası boşalmalı")
	_expect(not is_instance_valid(shield_skill), "Beceri hedefiyle birlikte yok olmalı")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _test_all_targeted_spells_and_statuses() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)

	var friendly_hero_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var friendly_structure_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.STRUCTURE)
	var poison_target_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var lightning_target_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE)
	var wind_target_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var stun_target_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.STRUCTURE)
	var wind_destination_slot := board.create_lane_slot(2, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var spark_target_slot := board.create_lane_slot(2, CardSlot.Lane.RIGHT, CardSlot.PositionType.STRUCTURE)
	var banish_target_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.BACK)

	var friendly_hero := _place_hero(friendly_hero_slot, 1, "troll")
	friendly_hero.health = 3
	var friendly_structure := _place_structure(friendly_structure_slot, 1, "tas_sur")
	friendly_structure.health = 2
	var poison_target := _place_hero(poison_target_slot, 2, "troll")
	poison_target.health = 8
	poison_target.armor = 0
	var lightning_target := _place_structure(lightning_target_slot, 2, "tas_sur")
	lightning_target.health = 10
	var wind_target := _place_hero(wind_target_slot, 2, "gladiator")
	var stun_target := _place_structure(stun_target_slot, 2, "tas_sur")
	var spark_target := _place_structure(spark_target_slot, 2, "tas_sur")
	spark_target.health = 10
	var banish_target := _place_hero(banish_target_slot, 2, "demir_dev")
	banish_target.apply_status(EffectResolver.STATUS_PROTECTED, 20)

	var holy_light := _make_spell(board, 1, "kutsal_isik")
	var poison_rain := _make_spell(board, 1, "zehir_yagmuru")
	var ice_seal := _make_spell(board, 1, "buz_muhru")
	var lightning := _make_spell(board, 1, "yildirim")
	var shifting_wind := _make_spell(board, 1, "yer_degistiren_ruzgar")
	var repair := _make_spell(board, 1, "onarim_ritueli")
	var flame_wave := _make_spell(board, 1, "alev_dalgasi")
	var protective_seal := _make_spell(board, 1, "koruyucu_muhur")
	var spark := _make_spell(board, 1, "kivilcim")
	var chain_lightning := _make_spell(board, 1, "zincir_yildirim")
	var banish_spell := _make_spell(board, 1, "hiclik_fermani")
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 40
	var starting_energy := manager.get_available_energy(1)

	var heal_result := EffectResolver.resolve_targeted_card(manager, holy_light, friendly_hero_slot)
	_expect(bool(heal_result.get("success", false)) and friendly_hero.health == 8, "Kutsal Işık 5 Can iyileştirmeli")
	var poison_result := EffectResolver.resolve_targeted_card(manager, poison_rain, poison_target_slot)
	_expect(bool(poison_result.get("success", false)) and poison_target.health == 7, "Zehir Yağmuru önce 1 hasar vermeli")
	_expect(poison_target.get_status_amount(EffectResolver.STATUS_POISON) == 2, "Zehir Yağmuru Zehirli 2 uygulamalı")
	var stun_result := EffectResolver.resolve_targeted_card(manager, ice_seal, stun_target_slot)
	_expect(bool(stun_result.get("success", false)) and stun_target.get_status_amount(EffectResolver.STATUS_STUNNED) == 1, "Buz Mührü bir Hazır adımı Sersemletmeli")
	var lightning_result := EffectResolver.resolve_targeted_card(manager, lightning, lightning_target_slot)
	_expect(bool(lightning_result.get("success", false)) and lightning_target.health == 5, "Yıldırım düşman karta 5 hasar vermeli")
	var wind_result := EffectResolver.resolve_targeted_card(manager, shifting_wind, wind_target_slot)
	_expect(bool(wind_result.get("success", false)), "Yer Değiştiren Rüzgâr boş komşu koridorda çözülmeli")
	_expect(wind_target.current_slot == wind_destination_slot, "Rüzgâr hedefi ilk boş komşu koridora taşımalı")
	var repair_result := EffectResolver.resolve_targeted_card(manager, repair, friendly_structure_slot)
	_expect(bool(repair_result.get("success", false)) and friendly_structure.health == 6, "Onarım Ritüeli Yapıya 4 Can vermeli")
	var protection_result := EffectResolver.resolve_targeted_card(manager, protective_seal, friendly_hero_slot)
	_expect(bool(protection_result.get("success", false)), "Koruyucu Mühür dost kartta çözülmeli")
	_expect(friendly_hero.get_status_amount(EffectResolver.STATUS_PROTECTED) == 3, "Koruyucu Mühür Korumalı 3 vermeli")
	var wave_result := EffectResolver.resolve_targeted_card(manager, flame_wave, poison_target_slot)
	_expect(bool(wave_result.get("success", false)), "Alev Dalgası düşman koridorunda çözülmeli")
	_expect(int(wave_result.get("targets_hit", 0)) == 2, "Alev Dalgası hedef koridordaki iki düşman kartı vurmalı")
	_expect(poison_target.health == 5 and lightning_target.health == 3, "Alev Dalgası koridordaki her düşmana 2 hasar vermeli")
	var spark_result := EffectResolver.resolve_targeted_card(manager, spark, spark_target_slot)
	_expect(bool(spark_result.get("success", false)) and spark_target.health == 8, "Kıvılcım düşman karta 2 hasar vermeli")
	var chain_result := EffectResolver.resolve_targeted_card(manager, chain_lightning, spark_target_slot)
	_expect(bool(chain_result.get("success", false)), "Zincir Yıldırım düşman koridorunda çözülmeli")
	_expect(int(chain_result.get("targets_hit", 0)) == 2, "Zincir Yıldırım hedef koridordaki iki düşman kartı vurmalı")
	_expect(spark_target.health == 5, "Zincir Yıldırım koridordaki hedef Yapıya 3 hasar vermeli")
	var banish_result := EffectResolver.resolve_targeted_card(manager, banish_spell, banish_target_slot)
	_expect(bool(banish_result.get("success", false)), "Hiçlik Fermanı düşman saha kartında çözülmeli")
	_expect(bool(banish_result.get("banished", false)), "Hiçlik Fermanı sonucu sürgün bilgisini taşımalı")
	_expect(not banish_target_slot.is_occupied, "Hiçlik Fermanı hedef yuvasını anında boşaltmalı")
	_expect(banish_target.is_queued_for_deletion(), "Hiçlik Fermanı Can, Zırh ve Korumalıyı yok sayarak hedefi silmeli")
	_expect(manager.get_available_energy(1) == starting_energy - 29, "On bir Büyü açıklanan toplam 29 Enerjiyi harcamalı")

	var invalid_banish := _make_spell(board, 1, "hiclik_fermani")
	await process_frame
	var energy_before_friendly_banish := manager.get_available_energy(1)
	var invalid_banish_result := EffectResolver.resolve_targeted_card(manager, invalid_banish, friendly_hero_slot)
	_expect(not bool(invalid_banish_result.get("success", false)), "Hiçlik Fermanı dost kartı silememeli")
	_expect(manager.get_available_energy(1) == energy_before_friendly_banish, "Geçersiz silme hedefi Enerji harcatmamalı")

	var invalid_lightning := _make_spell(board, 1, "yildirim")
	await process_frame
	var energy_before_invalid := manager.get_available_energy(1)
	var invalid_result := EffectResolver.resolve_targeted_card(manager, invalid_lightning, friendly_hero_slot)
	_expect(not bool(invalid_result.get("success", false)), "Yıldırım dost hedefte çözülememeli")
	_expect(manager.get_available_energy(1) == energy_before_invalid, "Geçersiz Büyü hedefi Enerji harcatmamalı")

	EffectResolver.resolve_turn_end(manager, 2)
	_expect(poison_target.health == 3, "Zehirli kart sahibinin tur sonunda 2 hasar almalı")
	_expect(poison_target.get_status_amount(EffectResolver.STATUS_POISON) == 0, "Süresi biten Zehirli durumu temizlenmeli")
	stun_target.set_combat_state(BaseCard.CombatState.READY)
	stun_target.ready_for_turn()
	_expect(not stun_target.is_ready_for_combat(), "Sersemlemiş kart bir sonraki Hazır olma adımını atlamalı")
	_expect(stun_target.get_status_amount(EffectResolver.STATUS_STUNNED) == 0, "Kullanılan Sersemlemiş durumu temizlenmeli")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _test_new_content_mechanics() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)

	var blood_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var rune_shelter_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE)
	var blood_target_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var flame_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var alchemist_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.STRUCTURE)
	var flame_target_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var ballista_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.STRUCTURE)
	var ballista_target_slot := board.create_lane_slot(2, CardSlot.Lane.RIGHT, CardSlot.PositionType.STRUCTURE)

	var blood_mage := _place_hero(blood_slot, 1, "kan_buyucusu")
	_place_structure(rune_shelter_slot, 1, "runik_siginak")
	var blood_target := _place_hero(blood_target_slot, 2, "gladiator")
	var flame_duelist := _place_hero(flame_slot, 1, "alev_duellocusu")
	_place_structure(alchemist_slot, 1, "simyaci_kulesi")
	var flame_target := _place_hero(flame_target_slot, 2, "troll")
	var ballista := _place_structure(ballista_slot, 1, "balista")
	var ballista_target := _place_structure(ballista_target_slot, 2, "tas_sur")
	blood_mage.health = 2
	blood_target.armor = 0
	flame_target.armor = 0

	await process_frame
	_start_match(manager, 1)
	_expect(blood_mage.get_status_amount(EffectResolver.STATUS_PROTECTED) == 1, "Rünik Sığınak tur başında koridordaki Kahramana Korumalı 1 vermeli")
	_expect(manager.advance_phase(1), "Yeni içerik testi Çatışma aşamasına geçebilmeli")

	var blood_result := CombatResolver.resolve_attack(board, manager, blood_mage, blood_target_slot)
	_expect(bool(blood_result.get("success", false)), "Kan Büyücüsü normal saldırı yapabilmeli")
	_expect(int(blood_result.get("health_damage", 0)) == 4, "Kan Büyücüsü düşman Cana 4 hasar vermeli")
	_expect(blood_mage.health == blood_mage.max_health, "Can Çalma verilen Can hasarıyla Kan Büyücüsünü iyileştirmeli")
	_expect(blood_result.has("lifesteal_result"), "Can Çalma sonucu saldırı kaydına eklenmeli")

	var flame_result := CombatResolver.resolve_attack(board, manager, flame_duelist, flame_target_slot)
	_expect(bool(flame_result.get("success", false)), "Alev Düellocusu normal saldırı yapabilmeli")
	_expect(int(flame_result.get("matchup_bonus", 0)) == 1, "Alev Düellocusu Kahramana +1 ilave hasar vermeli")
	_expect(flame_target.health == 3, "Alev Düellocusu toplam 5 hasar vermeli")

	var ballista_result := CombatResolver.resolve_attack(board, manager, ballista, ballista_target_slot)
	_expect(bool(ballista_result.get("success", false)), "Balista Çatışmada saldırabilmeli")
	_expect(int(ballista_result.get("siege_bonus", 0)) == 2, "Balista Yapıya +2 Kuşatma hasarı vermeli")
	_expect(ballista_target.health == 7, "Balista Yapıya toplam 5 hasar vermeli")

	_expect(manager.advance_phase(1), "Yeni içerik testi Tur Sonuna geçebilmeli")
	_expect(flame_target.get_status_amount(EffectResolver.STATUS_POISON) == 1, "Simyacı Kulesi aynı koridordaki ilk düşman Kahramana Zehirli 1 vermeli")

	var frost_guard := CardDatabase.get_card("heroes", "ayaz_muhafizi")
	var storm_hunter := CardDatabase.get_card("heroes", "firtina_avcisi")
	var iron_giant := CardDatabase.get_card("heroes", "demir_dev")
	_expect("guard" in frost_guard.get("tags", []), "Ayaz Muhafızı Muhafız çeşitliliği sunmalı")
	_expect("ranged" in storm_hunter.get("tags", []) and int(storm_hunter.get("attack", 0)) == 4, "Fırtına Avcısı yüksek Saldırılı Menzilli olmalı")
	_expect("guard" in iron_giant.get("tags", []) and "siege" in iron_giant.get("tags", []), "Demir Dev Muhafız ve Kuşatma olmalı")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _test_structure_turn_effects() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)

	var mine_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE)
	var barracks_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.STRUCTURE)
	var tent_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.STRUCTURE)
	var enemy_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var ally_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	_place_structure(mine_slot, 1, "altin_madeni")
	var barracks := _place_structure(barracks_slot, 1, "kisla")
	_place_structure(tent_slot, 1, "sifa_cadiri")
	var enemy := _place_hero(enemy_slot, 2, "troll")
	enemy.health = 6
	enemy.armor = 0
	var wounded_ally := _place_hero(ally_slot, 1, "troll")
	wounded_ally.health = 1

	await process_frame
	_start_match(manager, 1)
	_expect(int(manager.player_temporary_energy[1]) == 1, "Üretim Yapısı tur başında +1 geçici Enerji vermeli")
	_expect(manager.advance_phase(1), "Yapı testi Çatışma aşamasına geçebilmeli")
	_expect(CombatResolver.can_select_attacker(manager, barracks), "Saldırı değeri olan Yapı saldırabilmeli")
	var attack_result := CombatResolver.resolve_attack(board, manager, barracks, enemy_slot)
	_expect(bool(attack_result.get("success", false)) and enemy.health == 5, "Saldıran Yapı merkezi hasar hattını kullanmalı")
	_expect(manager.advance_phase(1), "Yapı testi Tur Sonuna geçebilmeli")
	_expect(enemy.health == 4, "Kışla tur sonunda koridordaki ilk düşmana 1 hasar vermeli")
	_expect(wounded_ally.health == 3, "Şifa Çadırı tur sonunda en yaralı koridor dostuna 2 Can vermeli")

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
		print("PHASE_FOUR_EFFECTS_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PHASE_FOUR_EFFECTS_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
