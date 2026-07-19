extends SceneTree

const CombatBoardStub := preload("res://tests/combat_board_stub.gd")

const HERO_IDS := [
	"kehribar_govde",
	"prizma_guvesi",
	"firtina_denizanasi",
	"kemik_mercan",
	"gece_oburu",
	"zaman_yutan_yengec",
]
const SKILL_IDS := ["kadim_kabuk", "yutucu_metamorfoz"]
const EFFECT_ID := "ilkel_uyum"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	CardDatabase.load_all(true)
	_test_catalog_contract()
	await _test_legendary_skills()
	await _test_primal_harmony()
	_finish()


func _test_catalog_contract() -> void:
	_expect(CardDatabase.get_cards_for_type("heroes").size() == 54, "Kahraman havuzu 54 karta çıkmalı")
	_expect(CardDatabase.get_cards_for_type("upgrades").size() == 17, "Beceri havuzu 17 karta çıkmalı")
	_expect(EffectCardCatalog.get_all_ids().size() == 13, "Etki Kartı havuzu 13 karta çıkmalı")
	_expect(CardDatabase.get_playable_card_refs().size() == 110, "Oynanabilir kart havuzu 110 karta çıkmalı")

	for card_id in HERO_IDS:
		var card_data := CardDatabase.get_card("heroes", card_id)
		_expect(not card_data.is_empty(), "%s Kahramanı bulunmalı" % card_id)
		_expect(not str(card_data.get("description", "")).is_empty(), "%s açıklama taşımalı" % card_id)
		_expect(ResourceLoader.exists(str(card_data.get("image_url", ""))), "%s özgün görsel taşımalı" % card_id)
	for card_id in SKILL_IDS:
		var card_data := CardDatabase.get_card("upgrades", card_id)
		_expect(str(card_data.get("rarity", "")) == "LEGENDARY", "%s efsanevi olmalı" % card_id)
		_expect(str(card_data.get("description", "")).begins_with("Hedef:"), "%s hedef dilini kullanmalı" % card_id)
		_expect(ResourceLoader.exists(str(card_data.get("image_url", ""))), "%s özgün görsel taşımalı" % card_id)
	var effect_data := CardDatabase.get_card("effects", EFFECT_ID)
	_expect(str(effect_data.get("rarity", "")) == "LEGENDARY", "İlkel Uyum efsanevi olmalı")
	_expect(str(effect_data.get("effect_id", "")) == "effect_primal_harmony", "İlkel Uyum çözümleyici kimliğini taşımalı")
	_expect(ResourceLoader.exists(str(effect_data.get("image_url", ""))), "İlkel Uyum özgün görsel taşımalı")


func _test_legendary_skills() -> void:
	await _test_skill(
		"kadim_kabuk",
		{"attack": 0, "armor": 3, "health": 3},
		["guard", "retaliate"]
	)
	await _test_skill(
		"yutucu_metamorfoz",
		{"attack": 2, "armor": 0, "health": 2},
		["lifesteal", "devourer"]
	)


func _test_skill(card_id: String, bonuses: Dictionary, expected_traits: Array[String]) -> void:
	var board := CombatBoardStub.new()
	root.add_child(board)
	var slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var hero := _place_hero(slot, 1, "gladiator")
	var skill := UpgradeCard.new()
	skill.owner_id = 1
	skill.card_id = card_id
	root.add_child(skill)
	await process_frame
	var base_attack := hero.attack
	var base_armor := hero.armor
	var base_health := hero.health
	_expect(hero.attach_skill(skill), "%s hedef Kahramana bağlanmalı" % card_id)
	var result := EffectResolver.apply_skill_modifiers(hero, skill)
	_expect(bool(result.get("success", false)), "%s bonusları çözümlenmeli" % card_id)
	_expect(hero.attack == base_attack + int(bonuses.get("attack", 0)), "%s Saldırı bonusu uygulanmalı" % card_id)
	_expect(hero.armor == base_armor + int(bonuses.get("armor", 0)), "%s Zırh bonusu uygulanmalı" % card_id)
	_expect(hero.health == base_health + int(bonuses.get("health", 0)), "%s Can bonusu uygulanmalı" % card_id)
	for trait_id in expected_traits:
		_expect(hero.has_trait(trait_id), "%s, %s niteliğini kazandırmalı" % [card_id, trait_id])
	board.queue_free()
	await process_frame


func _test_primal_harmony() -> void:
	var manager := GameManager.new()
	var board := CombatBoardStub.new()
	root.add_child(manager)
	root.add_child(board)
	var left_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var right_slot := board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var injured := _place_hero(left_slot, 1, "kehribar_govde")
	_place_hero(right_slot, 1, "prizma_guvesi")
	await process_frame
	_start_match(manager, 1)
	manager.selected_effect_cards = {1: EFFECT_ID, 2: ""}
	manager.call("_reset_effect_trigger_ledger")
	injured.health = maxi(1, injured.health - 2)
	var health_before := injured.health
	var energy_before := manager.get_available_energy(1)
	var results := EffectResolver.resolve_turn_start(manager, 1)
	_expect(not results.is_empty(), "İlkel Uyum iki koridora yayılınca tetiklenmeli")
	_expect(manager.get_available_energy(1) == energy_before + 1, "İlkel Uyum 1 geçici Enerji vermeli")
	_expect(injured.health == health_before + 1, "İlkel Uyum en yaralı dostu 1 Can iyileştirmeli")
	_expect(manager.has_effect_triggered(1, "primal_harmony"), "İlkel Uyum tur tetik hakkını kaydetmeli")
	EffectResolver.resolve_turn_start(manager, 1)
	_expect(manager.get_available_energy(1) == energy_before + 1, "İlkel Uyum aynı tur ikinci kez tetiklenmemeli")
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
		print("ORIGINAL_CARD_EXPANSION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("ORIGINAL_CARD_EXPANSION_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
