extends SceneTree

const CombatBoardStub := preload("res://tests/combat_board_stub.gd")

const NEW_CARDS := {
	"settlements": [
		"bakir_gozetleme_kulesi",
		"ay_muhru_siginagi",
		"kizil_firin",
		"prizma_balista",
	],
	"upgrades": [
		"muhafiz_yemini",
		"goktasi_kaplama",
		"gizli_pusula",
	],
	"special_powers": [
		"kor_kuresi",
		"zaman_yarigi",
		"prizma_perdesi",
	],
	"heroes": [
		"dus_yuruyeni",
		"yankili_yayci",
		"ates_izcisi",
		"gece_avcisi",
		"demir_tac_muhafizi",
	],
	"effects": [
		"muhafiz_nobeti",
		"usta_zanaatkarlar",
		"ilkel_uyum",
	],
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	CardDatabase.load_all(true)
	_test_catalog_contract()
	await _test_new_effect_cards()
	_finish()


func _test_catalog_contract() -> void:
	_expect(CardDatabase.get_playable_card_refs().size() == 110, "Yeni set 110 oynanabilir kart içermeli")
	_expect(EffectCardCatalog.get_all_ids().size() == 13, "Etki Kartı havuzu 13 karta çıkmalı")
	for card_type_variant in NEW_CARDS:
		var card_type := str(card_type_variant)
		var card_ids := NEW_CARDS[card_type] as Array
		for card_id_variant in card_ids:
			var card_id := str(card_id_variant)
			var card_data := CardDatabase.get_card(card_type, card_id)
			_expect(not card_data.is_empty(), "%s/%s bulunmalı" % [card_type, card_id])
			_expect(not str(card_data.get("name", "")).strip_edges().is_empty(), "%s adı eksik" % card_id)
			_expect(not str(card_data.get("description", "")).strip_edges().is_empty(), "%s açıklaması eksik" % card_id)
			_expect(ResourceLoader.exists(str(card_data.get("image_url", ""))), "%s görseli bulunmalı" % card_id)
			if card_type in ["upgrades", "special_powers"]:
				_expect(str(card_data.get("description", "")).begins_with("Hedef:"), "%s hedef dilini kullanmalı" % card_id)


func _test_new_effect_cards() -> void:
	var board := CombatBoardStub.new()
	root.add_child(board)
	var manager := GameManager.new()
	board.add_child(manager)
	await process_frame
	manager.is_game_active = true
	manager.is_match_started = true
	manager.active_player_id = 1
	manager.current_phase = GameManager.TurnPhase.PREPARATION
	manager.selected_effect_cards = {1: "muhafiz_nobeti", 2: ""}
	manager.effect_trigger_totals = {1: 0, 2: 0}
	manager.call("_reset_effect_trigger_ledger")

	var first_slot := board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var second_slot := board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var first_hero := _place_hero(first_slot, "dus_yuruyeni")
	var second_hero := _place_hero(second_slot, "ates_izcisi")
	var first_watch := EffectResolver.resolve_after_board_card_played(manager, first_hero)
	var second_watch := EffectResolver.resolve_after_board_card_played(manager, second_hero)
	_expect(bool(first_watch.get("triggered", false)), "Muhafız Nöbeti ilk Kahramanda tetiklenmeli")
	_expect(first_hero.get_status_amount(EffectResolver.STATUS_PROTECTED) == 2, "Muhafız Nöbeti Korumalı 2 vermeli")
	_expect(not bool(second_watch.get("triggered", true)), "Muhafız Nöbeti aynı tur ikinci Kahramanda tetiklenmemeli")

	manager.call("_reset_effect_trigger_ledger")
	manager.selected_effect_cards = {1: "usta_zanaatkarlar", 2: ""}
	var structure := SettlementCard.new()
	structure.owner_id = 1
	structure.card_id = "kizil_firin"
	var discounted_cost := EffectResolver.get_effect_action_cost(manager, structure, "settlement", 4)
	EffectResolver.resolve_energy_action(manager, structure, "settlement", discounted_cost)
	var normal_cost := EffectResolver.get_effect_action_cost(manager, structure, "settlement", 4)
	_expect(discounted_cost == 3, "Usta Zanaatkârlar ilk Yapı maliyetini 1 azaltmalı")
	_expect(normal_cost == 4 and manager.has_effect_triggered(1, "master_artisans"), "Usta Zanaatkârlar ikinci Yapıda tetik hakkını korumamalı")
	structure.free()
	board.queue_free()
	await process_frame


func _place_hero(slot: CardSlot, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = 1
	hero.card_id = card_id
	slot.add_child(hero)
	return hero


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CREATIVE_CARD_EXPANSION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("CREATIVE_CARD_EXPANSION_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
