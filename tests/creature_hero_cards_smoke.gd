extends SceneTree

const CombatBoardStub = preload("res://tests/combat_board_stub.gd")

const CREATURE_HERO_IDS := [
	"kivilcim_mantari_kolonisi",
	"ates_semenderi",
	"kristal_basilisk",
	"ayna_sulugu",
	"ay_isigi_anemonu",
	"yutucu_orkide",
	"koro_yosunu",
	"mezar_spor_bulutu",
	"yercekimi_salyangozu",
	"obsidyen_vatoz",
]

const CREATURE_TRAIT_IDS := [
	"spore_drift",
	"afterburn",
	"petrify",
	"armor_siphon",
	"starlight_ward",
	"devourer",
	"hive_mind",
	"sporeburst",
	"gravity_well",
	"void_bite",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	CardDatabase.load_all(true)
	_test_card_data_contract()
	await _test_spore_drift()
	await _test_afterburn_petrify_and_armor_siphon()
	await _test_starlight_ward()
	await _test_devourer()
	await _test_hive_mind()
	await _test_sporeburst()
	await _test_gravity_well()
	await _test_void_bite()
	_finish()


func _test_card_data_contract() -> void:
	_expect(CardDatabase.get_cards_for_type("heroes").size() == 54, "Kahraman havuzu 54 karta çıkmalı")
	_expect(CardDatabase.get_playable_card_refs().size() == 110, "Oynanabilir havuz 110 karta çıkmalı")
	for card_id in CREATURE_HERO_IDS:
		var card_data := CardDatabase.get_card("heroes", card_id)
		_expect(not card_data.is_empty(), "%s Kahraman veritabanında bulunmalı" % card_id)
		_expect(not str(card_data.get("description", "")).is_empty(), "%s açıklama taşımalı" % card_id)
		_expect(ResourceLoader.exists(str(card_data.get("image_url", ""))), "%s özgün görsel taşımalı" % card_id)
	for trait_id in CREATURE_TRAIT_IDS:
		_expect(CardKeywordGlossary.is_supported_keyword(trait_id), "%s ortak sözlükte açıklanmalı" % trait_id)


func _test_spore_drift() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var origin := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var destination := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var enemy_slot := board.create_lane_slot(2, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var colony := _place_hero(origin, 1, "kivilcim_mantari_kolonisi")
	var enemy := _place_hero(enemy_slot, 2, "gladiator")
	await process_frame
	_start_match(manager, 1)
	manager.player_current_energy[1] = 10
	var result := MovementResolver.resolve_move(manager, colony, destination)
	var trait_result := result.get("movement_trait_effect", {}) as Dictionary
	_expect(bool(result.get("success", false)), "Kıvılcım Mantarı Kolonisi yasal hareketi tamamlamalı")
	_expect(bool(trait_result.get("triggered", false)), "Spor Sürüklenmesi koridor değişiminde tetiklenmeli")
	_expect(enemy.get_status_amount("poison") == 1, "Spor Sürüklenmesi ilk düşman Kahramana 1 Zehir vermeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_afterburn_petrify_and_armor_siphon() -> void:
	await _test_hero_hit_trait("ates_semenderi", "afterburn")
	await _test_hero_hit_trait("kristal_basilisk", "petrify")
	await _test_hero_hit_trait("ayna_sulugu", "armor_siphon")


func _test_hero_hit_trait(card_id: String, trait_id: String) -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var target_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var attacker := _place_hero(attacker_slot, 1, card_id)
	var target := _place_hero(target_slot, 2, "gladiator")
	await process_frame
	_start_match(manager, 1)
	manager.advance_phase(1)
	var result := CombatResolver.resolve_attack(board, manager, attacker, target_slot)
	_expect(bool(result.get("success", false)), "%s normal saldırıyı çözmeli" % card_id)
	match trait_id:
		"afterburn":
			_expect(target.get_status_amount("poison") == 1, "Kor Hasarı ilk Can hasarında 1 Zehir vermeli")
		"petrify":
			_expect(target.get_status_amount("stunned") == 1, "Taş Bakış ilk Can hasarında Sersemletmeli")
		"armor_siphon":
			_expect(attacker.max_armor == 1 and attacker.armor == 1, "Yansıyan Kabuk 1 azami ve mevcut Zırh kazandırmalı")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_starlight_ward() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.BACK)
	var anemone := _place_hero(slot, 1, "ay_isigi_anemonu")
	await process_frame
	_start_match(manager, 1)
	anemone.set_combat_state(BaseCard.CombatState.READY)
	EffectResolver.resolve_turn_end(manager, 1)
	_expect(anemone.get_status_amount("protected") == 1, "Ay Kalkanı Hazır Anemonu Korumalı yapmalı")
	EffectResolver.resolve_turn_end(manager, 1)
	_expect(anemone.get_status_amount("protected") == 1, "Ay Kalkanı mevcut Korumalıyı biriktirmemeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_devourer() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var target_slot := board.create_lane_slot(2, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var orchid := _place_hero(attacker_slot, 1, "yutucu_orkide")
	_place_hero(target_slot, 2, "okcu")
	await process_frame
	_start_match(manager, 1)
	manager.advance_phase(1)
	var result := CombatResolver.resolve_attack(board, manager, orchid, target_slot)
	_expect(bool(result.get("destroyed", false)), "Yutucu Orkide hedef Kahramanı yok etmeli")
	_expect(orchid.max_health == 6 and orchid.health == 6, "Etçil Büyüme 1 azami ve mevcut Can vermeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_hive_mind() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	_start_match(manager, 1)
	var chorus_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.BACK)
	var ally_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	_place_hero(chorus_slot, 1, "koro_yosunu")
	_place_hero(ally_slot, 1, "koro_yosunu")
	await process_frame
	var available_before := manager.get_available_energy(1)
	var results := EffectResolver.resolve_turn_start(manager, 1)
	_expect(not results.is_empty(), "Simbiyoz Korosu bir tur başlangıcı etkisi üretmeli")
	_expect(manager.get_available_energy(1) == available_before + 1, "Simbiyoz Korosu 1 geçici Enerji vermeli")
	EffectResolver.resolve_turn_start(manager, 1)
	_expect(manager.get_available_energy(1) == available_before + 1, "Birden fazla Simbiyoz Korosu etkisi aynı tur birikmemeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_sporeburst() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var cloud_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var enemy_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var cloud := _place_hero(cloud_slot, 1, "mezar_spor_bulutu")
	var enemy := _place_hero(enemy_slot, 2, "gladiator")
	await process_frame
	_start_match(manager, 1)
	EffectResolver.apply_damage(manager, enemy, cloud, 99, false, false, true)
	_expect(enemy.get_status_amount("poison") == 2, "Son Spor yok edilince ilk düşman Kahramana 2 Zehir vermeli")
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_gravity_well() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var mover_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var enemy_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var enemy_back_slot := board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK)
	var mover := _place_hero(mover_slot, 1, "okcu")
	_place_hero(enemy_slot, 2, "yercekimi_salyangozu")
	_place_hero(enemy_back_slot, 2, "yercekimi_salyangozu")
	await process_frame
	_start_match(manager, 1)
	_expect(
		MovementResolver.get_movement_energy_cost(mover, manager) == GameRules.MOVEMENT_ENERGY_COST + 1,
		"Ağır Alan aynı koridorda başlayan düşman hareketini 1 Enerji artırmalı ve birikmemeli"
	)
	manager.queue_free()
	board.queue_free()
	await process_frame


func _test_void_bite() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var attacker_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var target_slot := board.create_lane_slot(2, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var manta := _place_hero(attacker_slot, 1, "obsidyen_vatoz")
	var target := _place_hero(target_slot, 2, "gladiator")
	await process_frame
	target.max_armor = 5
	target.armor = 5
	_start_match(manager, 1)
	manager.advance_phase(1)
	var result := CombatResolver.resolve_attack(board, manager, manta, target_slot)
	_expect(bool(result.get("success", false)), "Obsidyen Vatoz normal saldırıyı çözmeli")
	_expect(int(result.get("piercing_health_damage", 0)) == 1, "Boşluk Dikeni 1 hasarı doğrudan Cana işlemeli")
	_expect(target.health == 5, "Boşluk Dikeni yüksek Zırh altında bile 1 Can hasarı vermeli")
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
		print("CREATURE_HERO_CARDS_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("CREATURE_HERO_CARDS_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
