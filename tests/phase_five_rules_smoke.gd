extends SceneTree

const CombatBoardStub = preload("res://tests/combat_board_stub.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	CardDatabase.load_all(true)
	_test_progression_data_contract()
	await _test_movement_rules()
	await _test_hero_experience_rules()
	await _test_structure_experience_rules()
	await _test_upgrade_lock_and_destruction_cleanup()
	await _test_all_level_branches()
	_finish()

func _test_progression_data_contract() -> void:
	var required_cards := [
		{"type": "heroes", "id": "sovalye"},
		{"type": "heroes", "id": "troll"},
		{"type": "settlements", "id": "altin_madeni"},
		{"type": "settlements", "id": "okcu_kulesi"},
	]
	for card_spec_variant in required_cards:
		var card_spec := card_spec_variant as Dictionary
		var card_data := CardDatabase.get_card(str(card_spec["type"]), str(card_spec["id"]))
		var paths_variant: Variant = card_data.get("level_paths", {})
		_expect(paths_variant is Dictionary, "%s kartının level_paths sözleşmesi olmalı" % str(card_spec["id"]))
		if not paths_variant is Dictionary:
			continue
		var paths := paths_variant as Dictionary
		_expect(paths.size() == 2, "%s kartında tam iki yükseltme dalı olmalı" % str(card_spec["id"]))
		for branch_variant in paths.values():
			var branch := branch_variant as Dictionary
			_expect(branch.get("level_2", {}) is Dictionary, "Her dalın Seviye 2 tanımı olmalı")
			_expect(branch.get("level_3", {}) is Dictionary, "Her dalın Seviye 3 tanımı olmalı")

func _test_movement_rules() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)

	var left_front := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var left_back := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK)
	var center_front := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var center_back := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.BACK)
	var right_front := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var right_back := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.BACK)
	var structure_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE)
	var enemy_front := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)

	var mover := _place_hero(left_front, 1, "sovalye")
	_place_hero(left_back, 1, "")
	var structure := _place_structure(structure_slot, 1, "")
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 10

	var energy_before_structure := manager.get_available_energy(1)
	var structure_move := MovementResolver.resolve_move(manager, structure, center_back)
	_expect(not bool(structure_move.get("success", false)), "Yapılar hareket edememeli")
	_expect(manager.get_available_energy(1) == energy_before_structure, "Yapı hareketi denemesi Enerji harcatmamalı")

	var legal_targets: Array[CardSlot] = MovementResolver.get_legal_destination_slots(manager, mover)
	_expect(legal_targets.has(center_front), "Aynı sıradaki komşu koridor yasal hareket hedefi olmalı")
	_expect(not legal_targets.has(left_back), "Dolu Ön/Arka hedefi yasal olmamalı")
	_expect(not legal_targets.has(center_back), "Çapraz hedef yasal olmamalı")
	_expect(not legal_targets.has(right_front), "Sol ile Sağ arasında doğrudan hareket yasal olmamalı")
	_expect(not legal_targets.has(enemy_front), "Rakip alana hareket yasal olmamalı")

	for invalid_target in [left_back, center_back, right_front, enemy_front]:
		var energy_before_invalid := manager.get_available_energy(1)
		var invalid_result := MovementResolver.resolve_move(manager, mover, invalid_target)
		_expect(not bool(invalid_result.get("success", false)), "Geçersiz hareket reddedilmeli")
		_expect(manager.get_available_energy(1) == energy_before_invalid, "Geçersiz hareket Enerji harcatmamalı")
		_expect(mover.current_slot == left_front, "Geçersiz hareket Kahramanın konumunu değiştirmemeli")

	var energy_before_move := manager.get_available_energy(1)
	var move_result := MovementResolver.resolve_move(manager, mover, center_front)
	_expect(bool(move_result.get("success", false)), "Komşu koridora aynı sırada hareket çözülebilmeli")
	_expect(manager.get_available_energy(1) == energy_before_move - 1, "Geçerli hareket tam 1 Enerji harcamalı")
	_expect(mover.current_slot == center_front and center_front.occupied_card == mover, "Hareket hedef yuvayı güvenilir biçimde doldurmalı")
	_expect(not left_front.is_occupied, "Hareket kaynak yuvayı boşaltmalı")
	_expect(mover.has_moved_this_turn, "Hareket tur başına kullanım bayrağını işaretlemeli")
	_expect(not mover.is_ready_for_combat(), "Hareket eden Kahraman Tükenmiş olmalı")

	mover.set_combat_state(BaseCard.CombatState.READY)
	var energy_before_second_move := manager.get_available_energy(1)
	var second_move := MovementResolver.resolve_move(manager, mover, right_front)
	_expect(not bool(second_move.get("success", false)), "Kahraman aynı tur ikinci kez hareket edememeli")
	_expect(manager.get_available_energy(1) == energy_before_second_move, "İkinci hareket denemesi Enerji harcatmamalı")

	ProgressionResolver.begin_owner_turn(manager, mover)
	_expect(not mover.has_moved_this_turn and mover.is_ready_for_combat(), "Sahibinin yeni turu hareket sınırını ve Hazır durumunu yenilemeli")
	var vertical_move := MovementResolver.resolve_move(manager, mover, center_back)
	_expect(bool(vertical_move.get("success", false)), "Aynı koridorda Ön/Arka hareketi yasal olmalı")
	_expect(mover.current_slot == center_back, "Ön/Arka hareketi doğru hedefte bitmeli")

	_expect(manager.advance_phase(1), "Hareket aşama testi Çatışmaya geçebilmeli")
	mover.reset_owner_turn_tracking()
	mover.set_combat_state(BaseCard.CombatState.READY)
	var energy_before_wrong_phase := manager.get_available_energy(1)
	var wrong_phase_move := MovementResolver.resolve_move(manager, mover, center_front)
	_expect(not bool(wrong_phase_move.get("success", false)), "Çatışma aşamasında hareket edilememeli")
	_expect(manager.get_available_energy(1) == energy_before_wrong_phase, "Yanlış aşamadaki hareket Enerji harcatmamalı")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _test_hero_experience_rules() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)

	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var enemy_front_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var enemy_back_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK)
	var passive_source_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var passive_target_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)

	var attacker := _place_hero(attacker_slot, 1, "sovalye")
	var front_target := _place_custom_hero(enemy_front_slot, 2, 0, 4, "İlk Hedef")
	_place_custom_hero(enemy_back_slot, 2, 0, 1, "İkinci Hedef")
	var passive_source := _place_custom_hero(passive_source_slot, 1, 0, 5, "Pasif Kaynak")
	var passive_target := _place_custom_hero(passive_target_slot, 2, 0, 5, "Pasif Hedef")
	await process_frame
	attacker.attack = 2
	_start_match(manager, 1)
	_expect(manager.advance_phase(1), "Kahraman Tecrübe testi Çatışmaya geçebilmeli")

	var first_hit := CombatResolver.resolve_attack(board, manager, attacker, enemy_front_slot)
	_expect(bool(first_hit.get("success", false)) and front_target.health == 2, "İlk savaş hasarı çözülmeli")
	_expect(attacker.experience == 1, "Kahraman turdaki ilk savaş hasarından +1 Tecrübe kazanmalı")
	_expect(attacker.card_level == 1, "Tecrübe kazanımı otomatik seviye yükseltmemeli")

	attacker.set_combat_state(BaseCard.CombatState.READY)
	var kill_hit := CombatResolver.resolve_attack(board, manager, attacker, enemy_front_slot)
	_expect(bool(kill_hit.get("destroyed", false)), "İkinci saldırı hedefi yok etmeli")
	_expect(attacker.experience == 2, "Kahraman yok etmeden +1 ek Tecrübe kazanmalı")
	_expect(attacker.experience_gained_this_turn == 2, "Kahraman tur başına 2 Tecrübe tavanına ulaşmalı")

	var passive_result := EffectResolver.apply_damage(manager, passive_source, passive_target, 1, false, false)
	_expect(bool(passive_result.get("success", false)), "Pasif etki ortak hasar hattında çözülmeli")
	_expect(passive_source.experience == 0, "Savaş çözümleyicisi dışındaki pasif hasar Kahramana Tecrübe vermemeli")

	await process_frame
	attacker.set_combat_state(BaseCard.CombatState.READY)
	var capped_kill := CombatResolver.resolve_attack(board, manager, attacker, enemy_back_slot)
	_expect(bool(capped_kill.get("destroyed", false)), "Kahraman turda başka bir hedefi daha yok edebilmeli")
	_expect(attacker.experience == 2, "Ek yok etme Kahramanın tur başına 2 Tecrübe tavanını aşmamalı")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _test_structure_experience_rules() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)

	var mine_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE)
	var barracks_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.STRUCTURE)
	var enemy_front_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var enemy_back_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.BACK)
	var mine := _place_structure(mine_slot, 1, "altin_madeni")
	var barracks := _place_structure(barracks_slot, 1, "savas_davulu")
	_place_custom_hero(enemy_front_slot, 2, 0, 1, "Yapı Hedefi")
	var passive_target := _place_custom_hero(enemy_back_slot, 2, 0, 5, "Pasif Hedef")
	await process_frame
	_start_match(manager, 1)

	_expect(mine.experience == 1, "Üretim Yapısı başarılı temel etkisinden +1 Tecrübe kazanmalı")
	EffectResolver.resolve_turn_start(manager, 1)
	_expect(mine.experience == 1, "Aynı tur tekrarlanan temel etki Yapıya ikinci Tecrübe vermemeli")

	_expect(manager.advance_phase(1), "Yapı Tecrübe testi Çatışmaya geçebilmeli")
	var kill_result := CombatResolver.resolve_attack(board, manager, barracks, enemy_front_slot)
	_expect(bool(kill_result.get("destroyed", false)), "Saldırabilen Yapı hedef yok edebilmeli")
	_expect(barracks.experience == 1, "Saldıran Yapı yok etmeden +1 Tecrübe kazanmalı")
	await process_frame
	_expect(manager.advance_phase(1), "Yapı Tecrübe testi Tur Sonuna geçebilmeli")
	_expect(passive_target.health == 4, "Kışlanın temel tur sonu etkisi başarıyla çalışmalı")
	_expect(barracks.experience == 1, "Yapı yok etme ve temel etkiyle tur başına 1 Tecrübe tavanını aşmamalı")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _test_upgrade_lock_and_destruction_cleanup() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var hero_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var hero := _place_hero(hero_slot, 1, "sovalye")
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 10

	hero.experience = 1
	var energy_before_threshold := manager.get_available_energy(1)
	var threshold_failure := ProgressionResolver.resolve_upgrade(manager, hero, "muhafiz")
	_expect(not bool(threshold_failure.get("success", false)), "Seviye 2 toplam 2 Tecrübe olmadan açılamamalı")
	_expect(manager.get_available_energy(1) == energy_before_threshold, "Yetersiz Tecrübe Enerji harcatmamalı")

	var base_max_armor := hero.max_armor
	hero.experience = 2
	var level_two := ProgressionResolver.resolve_upgrade(manager, hero, "muhafiz")
	_expect(bool(level_two.get("success", false)), "Seviye 2 iki Tecrübeyle açılabilmeli")
	_expect(hero.card_level == 2 and hero.selected_branch_id == "muhafiz", "Seviye 2 seçilen dalı kalıcı olarak kaydetmeli")
	_expect(hero.max_armor == base_max_armor + 2, "Muhafız Seviye 2 bonusu uygulanmalı")
	_expect(manager.get_available_energy(1) == energy_before_threshold - 1, "Seviye 2 tam 1 Enerji harcamalı")

	hero.experience = 6
	var energy_before_branch_change := manager.get_available_energy(1)
	var branch_change := ProgressionResolver.resolve_upgrade(manager, hero, "duellocu")
	_expect(not bool(branch_change.get("success", false)), "Seviye 2 dalı Seviye 3'te değiştirilememeli")
	_expect(manager.get_available_energy(1) == energy_before_branch_change, "Dal değiştirme denemesi Enerji harcatmamalı")
	_expect(hero.card_level == 2 and hero.selected_branch_id == "muhafiz", "Geçersiz dal değişimi ilerlemeyi bozmamalı")

	var level_three := ProgressionResolver.resolve_upgrade(manager, hero, "muhafiz")
	_expect(bool(level_three.get("success", false)), "Seviye 3 yalnızca seçilmiş dalda açılabilmeli")
	_expect(hero.card_level == 3 and hero.get_trait_value("turn_start_armor_regen", 0) == 1, "Muhafız Seviye 3 etkisi uygulanmalı")
	_expect(manager.get_available_energy(1) == energy_before_branch_change - 2, "Seviye 3 tam 2 Enerji harcamalı")

	var skill := UpgradeCard.new()
	skill.owner_id = 1
	skill.card_id = "celik_kalkan"
	board.add_child(skill)
	await process_frame
	_expect(hero.attach_skill(skill), "Yok edilme testi için Kahramana Beceri bağlanabilmeli")
	var destroy_result := EffectResolver.apply_damage(manager, null, hero, 999, false, false)
	_expect(bool(destroy_result.get("destroyed", false)), "Seviye 3 kart hasarla yok edilebilmeli")
	_expect(hero.experience == 0 and hero.card_level == 1, "Yok edilen kartın Tecrübe ve seviyesi anında temizlenmeli")
	_expect(hero.selected_branch_id.is_empty() and hero.selected_branch_name.is_empty(), "Yok edilen kartın dal seçimi temizlenmeli")
	_expect(not hero_slot.is_occupied, "Yok edilen ilerlemeli kart yuvasını boşaltmalı")
	await process_frame
	_expect(not is_instance_valid(skill), "Bağlı Beceri hedef kartla birlikte yok olmalı")

	var replacement := _place_hero(hero_slot, 1, "sovalye")
	await process_frame
	_expect(replacement.card_level == 1 and replacement.experience == 0, "Yeniden oynanan kart Seviye 1 ve 0 Tecrübeyle başlamalı")
	_expect(replacement.selected_branch_id.is_empty(), "Yeniden oynanan kart eski dalı taşımamalı")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _test_all_level_branches() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var hero_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var structure_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE)
	var enemy_front_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var enemy_back_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK)
	await process_frame
	_start_match(manager, 1)

	var duel_data: Dictionary = await _upgrade_branch(manager, hero_slot, "hero", "sovalye", "duellocu")
	var duel_knight := duel_data["card"] as HeroCard
	_expect(duel_knight.attack == int(duel_data["base_attack"]) + 1, "Şövalye Düellocu dalı +1 Saldırı vermeli")
	_expect(duel_knight.get_trait_value("hero_damage_bonus", 0) == 1, "Şövalye Düellocu dalı Kahraman hasarı bonusu vermeli")
	_expect(duel_knight.has_trait("ready_on_hero_kill"), "Şövalye Düellocu Seviye 3 yok etmede Hazır özelliği vermeli")
	var duel_target := HeroCard.new()
	duel_target.owner_id = 2
	duel_target.health = 10
	duel_target.armor = 0
	board.add_child(duel_target)
	await process_frame
	var duel_damage := EffectResolver.apply_damage(manager, duel_knight, duel_target, duel_knight.attack, false, false)
	_expect(int(duel_damage.get("matchup_bonus", 0)) == 1 and duel_target.health == 5, "Düellocu bonusu gerçek Kahraman hasarına eklenmeli")
	duel_knight.set_combat_state(BaseCard.CombatState.EXHAUSTED)
	ProgressionResolver.record_combat_attack(manager, duel_knight, duel_target, {
		"success": true,
		"destroyed": true,
		"target_was_hq": false,
		"armor_damage": 0,
		"health_damage": 1,
		"target": duel_target,
	})
	_expect(duel_knight.is_ready_for_combat(), "Düellocu Seviye 3 bir Kahraman yok etmesinden sonra turda bir kez Hazır olmalı")
	duel_target.queue_free()
	await _remove_card(duel_knight)

	var guard_data: Dictionary = await _upgrade_branch(manager, hero_slot, "hero", "sovalye", "muhafiz")
	var guard_knight := guard_data["card"] as HeroCard
	_expect(guard_knight.max_armor == int(guard_data["base_armor"]) + 2, "Şövalye Muhafız dalı +2 azami ve mevcut Zırh vermeli")
	_expect(guard_knight.has_trait("guard"), "Şövalye Muhafız dalı Muhafız özelliğini korumalı")
	_expect(guard_knight.get_trait_value("turn_start_armor_regen", 0) == 1, "Şövalye Muhafız Seviye 3 Zırh yenilemesi vermeli")
	guard_knight.armor = 0
	ProgressionResolver.begin_owner_turn(manager, guard_knight)
	_expect(guard_knight.armor == 1, "Muhafız Seviye 3 tur başında gerçekten 1 Zırh yenilemeli")
	await _remove_card(guard_knight)

	var giant_data: Dictionary = await _upgrade_branch(manager, hero_slot, "hero", "troll", "dev")
	var giant_troll := giant_data["card"] as HeroCard
	_expect(giant_troll.max_health == int(giant_data["base_health"]) + 6, "Troll Dev dalı iki seviyede toplam +6 azami Can vermeli")
	_expect(giant_troll.health == giant_troll.max_health, "Troll Dev dalı mevcut Canı da azami Canla birlikte artırmalı")
	await _remove_card(giant_troll)

	var siege_data: Dictionary = await _upgrade_branch(manager, hero_slot, "hero", "troll", "kusatma")
	var siege_troll := siege_data["card"] as HeroCard
	_expect(siege_troll.attack == int(siege_data["base_attack"]) + 2, "Troll Kuşatma dalı toplam +2 Saldırı vermeli")
	_expect(siege_troll.get_trait_value("siege_bonus", 0) == 4, "Troll Kuşatma dalı toplam +4 Kuşatma hasarına ulaşmalı")
	await _remove_card(siege_troll)

	var fortified_data: Dictionary = await _upgrade_branch(manager, structure_slot, "structure", "altin_madeni", "tahkimat")
	var fortified_mine := fortified_data["card"] as SettlementCard
	_expect(fortified_mine.max_health == int(fortified_data["base_health"]) + 6, "Enerji Ocağı Tahkimat dalı toplam +6 azami Can vermeli")
	_expect(fortified_mine.health == fortified_mine.max_health, "Tahkimat dalı mevcut Canı da artırmalı")
	await _remove_card(fortified_mine)

	var production_data: Dictionary = await _upgrade_branch(manager, structure_slot, "structure", "altin_madeni", "uretim")
	var production_mine := production_data["card"] as SettlementCard
	_expect(int(production_mine.effect_params.get("energy", 0)) == 3, "Enerji Ocağı Üretim dalı tur başı üretimi 3'e çıkarmalı")
	var temporary_before := int(manager.player_temporary_energy.get(1, 0))
	EffectResolver.resolve_turn_start(manager, 1)
	_expect(int(manager.player_temporary_energy.get(1, 0)) == temporary_before + 3, "Üretim Seviye 3 gerçek tur başında +3 geçici Enerji vermeli")
	await _remove_card(production_mine)

	var precision_data: Dictionary = await _upgrade_branch(manager, structure_slot, "structure", "okcu_kulesi", "keskin_atis")
	var precision_tower := precision_data["card"] as SettlementCard
	_expect(precision_tower.attack == int(precision_data["base_attack"]) + 2, "Okçu Kulesi Keskin Atış dalı +2 Saldırı vermeli")
	_expect(precision_tower.get_trait_value("armor_pierce", 0) == 2, "Keskin Atış Seviye 3 ilk 2 Zırh hasarını delmeli")
	var armored_target := _place_custom_hero(enemy_front_slot, 2, 10, 2, "Zırhlı Hedef")
	await process_frame
	var precision_hit := EffectResolver.apply_damage(manager, precision_tower, armored_target, precision_tower.attack, false, false)
	_expect(bool(precision_hit.get("destroyed", false)), "Keskin Atış düşük Canlı hedefi yüksek Zırhın arkasından yok edebilmeli")
	_expect(int(precision_hit.get("piercing_health_damage", 0)) == 2, "Keskin Atış tam 2 hasarı doğrudan Cana geçirmeli")
	await process_frame
	await _remove_card(precision_tower)

	var rapid_data: Dictionary = await _upgrade_branch(manager, structure_slot, "structure", "okcu_kulesi", "seri_atis")
	var rapid_tower := rapid_data["card"] as SettlementCard
	_expect(rapid_tower.has_trait("multi_shot"), "Okçu Kulesi Seri Atış dalı çoklu atış özelliği vermeli")
	_expect(rapid_tower.get_trait_value("secondary_damage_percent", 0) == 100, "Seri Atış Seviye 3 ikinci hedefe tam hasar vermeli")
	var primary_target := _place_custom_hero(enemy_front_slot, 2, 0, 10, "Birincil Hedef")
	var secondary_target := _place_custom_hero(enemy_back_slot, 2, 0, 10, "İkincil Hedef")
	await process_frame
	rapid_tower.set_combat_state(BaseCard.CombatState.READY)
	_expect(manager.advance_phase(1), "Seri Atış davranış testi Çatışmaya geçebilmeli")
	var rapid_hit := CombatResolver.resolve_attack(board, manager, rapid_tower, enemy_front_slot)
	var secondary_variant: Variant = rapid_hit.get("secondary_result", {})
	_expect(bool(rapid_hit.get("success", false)), "Seri Atış ana hedefte çözülmeli")
	_expect(secondary_variant is Dictionary and bool((secondary_variant as Dictionary).get("success", false)), "Seri Atış ikinci hedefte de ortak hasar hattını kullanmalı")
	_expect(primary_target.health == 7 and secondary_target.health == 7, "Seri Atış Seviye 3 iki hedefe de tam 3 hasar vermeli")

	manager.queue_free()
	board.queue_free()
	await process_frame

func _upgrade_branch(
	manager: GameManager,
	slot: CardSlot,
	card_kind: String,
	card_id: String,
	branch_id: String
) -> Dictionary:
	var card: BaseCard
	if card_kind == "hero":
		card = HeroCard.new()
	else:
		card = SettlementCard.new()
	card.owner_id = 1
	card.card_id = card_id
	slot.add_child(card)
	await process_frame

	var baseline := {
		"card": card,
		"base_attack": card.get_attack_value(),
		"base_health": card.get_max_health(),
		"base_armor": (card as HeroCard).max_armor if card is HeroCard else 0,
	}
	card.experience = 6
	card.refresh_runtime_badges()
	manager.player_current_energy[1] = 10
	manager.player_temporary_energy[1] = 0
	var level_two := ProgressionResolver.resolve_upgrade(manager, card, branch_id)
	var level_three := ProgressionResolver.resolve_upgrade(manager, card, branch_id)
	_expect(bool(level_two.get("success", false)), "%s/%s Seviye 2 dalı çözülebilmeli" % [card_id, branch_id])
	_expect(bool(level_three.get("success", false)), "%s/%s Seviye 3 dalı çözülebilmeli" % [card_id, branch_id])
	_expect(card.card_level == 3 and card.selected_branch_id == branch_id, "%s/%s seçimi Seviye 3'te korunmalı" % [card_id, branch_id])
	_expect(manager.get_available_energy(1) == 7, "%s/%s Seviye 2 ve 3 toplam 3 Enerji harcamalı" % [card_id, branch_id])
	return baseline

func _remove_card(card: BaseCard) -> void:
	if card and is_instance_valid(card):
		card.destroy_from_combat()
	await process_frame

func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)
	return hero

func _place_custom_hero(
	slot: CardSlot,
	owner_id: int,
	armor: int,
	health: int,
	card_name: String
) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.attack = 1
	hero.armor = armor
	hero.health = health
	hero.card_name = card_name
	slot.add_child(hero)
	return hero

func _place_structure(slot: CardSlot, owner_id: int, card_id: String) -> SettlementCard:
	var structure := SettlementCard.new()
	structure.owner_id = owner_id
	structure.card_id = card_id
	slot.add_child(structure)
	return structure

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
		print("PHASE_FIVE_RULES_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PHASE_FIVE_RULES_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
