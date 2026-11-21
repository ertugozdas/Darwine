extends SceneTree

const CombatBoardStub := preload("res://tests/combat_board_stub.gd")
const TRIGGER_BY_CARD := {
	"yapi_ustalari": "building_masters",
	"saha_hekimleri": "field_medics",
	"kanat_manevrasi": "flanking_maneuver",
	"oncu_doktrini": "vanguard_doctrine",
	"gizli_cephanelik": "hidden_arsenal",
	"koruyucu_yemin": "protective_oath",
	"kusatma_plani": "siege_plan",
	"dovme_ocagi": "forge",
	"ikmal_hatti": "supply_line",
	"son_direnis": "last_stand",
	"muhafiz_nobeti": "guard_watch",
	"usta_zanaatkarlar": "master_artisans",
	"ilkel_uyum": "primal_harmony",
}

var _failures: Array[String] = []


class SupplyBoardStub extends Node:
	var hands := {1: [], 2: []}

	func get_hand_cards(player_id: int) -> Array:
		return (hands.get(player_id, []) as Array).duplicate()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_and_selection()
	_test_snapshot_and_server_matrix()
	await _test_building_masters()
	await _test_field_medics_and_oath()
	await _test_flanking_maneuver()
	await _test_cost_discounts_and_supply_line()
	await _test_siege_plan_and_last_stand()
	await _test_forge()
	await _test_guard_watch()
	MatchSetup.configure_local(1)
	_finish()


func _test_snapshot_and_server_matrix() -> void:
	var effect_ids := EffectCardCatalog.get_all_ids()
	for card_index in range(effect_ids.size()):
		var card_id := effect_ids[card_index]
		var trigger_id := str(TRIGGER_BY_CARD.get(card_id, ""))
		var opponent_id := effect_ids[(card_index + 1) % effect_ids.size()]
		_expect(not trigger_id.is_empty(), "%s için snapshot tetik kimliği tanımlı değil" % card_id)

		# Every card must preserve its selection, per-turn ledger and match-wide
		# count through the same GameManager state used by active-match snapshots.
		MatchSetup.configure_local(45000 + card_index)
		var manager := GameManager.new()
		root.add_child(manager)
		manager.call("_reset_match_state")
		manager.effect_offers = {1: [card_id, opponent_id], 2: [opponent_id, card_id]}
		manager.selected_effect_cards = {1: card_id, 2: opponent_id}
		manager.mark_effect_triggered(1, trigger_id, {"fixture": card_id})
		var state := manager.build_state_snapshot()
		var restored := GameManager.new()
		root.add_child(restored)
		var restore_result := restored.apply_state_snapshot(state)
		_expect(bool(restore_result.get("success", false)), "%s snapshot'tan yüklenemedi" % card_id)
		_expect(restored.get_selected_effect_card(1) == card_id, "%s seçimi snapshot'ta değişti" % card_id)
		_expect(restored.has_effect_triggered(1, trigger_id), "%s tur içi tetik hakkı snapshot'ta kayboldu" % card_id)
		if card_id == "ikmal_hatti":
			restored.mark_effect_checked(1, "supply_line_checked")
			state = restored.build_state_snapshot()
			var checked_restore := GameManager.new()
			root.add_child(checked_restore)
			checked_restore.apply_state_snapshot(state)
			_expect(checked_restore.has_effect_triggered(1, "supply_line_checked"), "İkmal Hattı ilk hamle kontrolü snapshot'ta kayboldu")
			checked_restore.queue_free()
		_expect(int(restored.effect_trigger_totals.get(1, 0)) == 1, "%s maç tetik sayacı snapshot'ta kayboldu" % card_id)
		restored.call("_reset_effect_trigger_ledger")
		_expect(not restored.has_effect_triggered(1, trigger_id), "%s yeni turda tetik hakkını yenilemedi" % card_id)
		_expect(restored.get_selected_effect_card(1) == card_id, "%s yeni turda pasif seçimden düştü" % card_id)
		_expect(int(restored.effect_trigger_totals.get(1, 0)) == 1, "%s yeni turda maç sayacını sıfırladı" % card_id)
		manager.queue_free()
		restored.queue_free()

		# The authoritative multiplayer manager must offer and accept every card,
		# while the opponent perspective sees only that a choice was made.
		MatchSetup.configure_multiplayer_server(45100 + card_index, "effect-server-%d" % card_index)
		MatchSetup.set_forced_effect_card(1, card_id)
		var server_manager := GameManager.new()
		root.add_child(server_manager)
		server_manager.call("_reset_match_state")
		_expect(server_manager.begin_effect_selection(1), "%s için sunucu seçimi başlayamadı" % card_id)
		_expect(card_id in server_manager.get_effect_offer(1), "%s sunucu teklifine eklenmedi" % card_id)
		_expect(server_manager.submit_effect_selection(1, card_id), "%s sunucu tarafından doğrulanmadı" % card_id)
		var opponent_public_state := server_manager.get_effect_selection_public_state(2)
		_expect(bool(opponent_public_state.get("opponent_selected", false)), "%s seçimi rakibe yalnızca tamamlandı olarak iletilmedi" % card_id)
		var opponent_only_state := opponent_public_state.duplicate(true)
		opponent_only_state.erase("own_offer")
		opponent_only_state.erase("own_selected_card")
		_expect(
			not opponent_only_state.has("opponent_selected_card")
			and not JSON.stringify(opponent_only_state).contains(card_id),
			"%s kimliği rakip perspektifine sızdı" % card_id
		)
		server_manager.queue_free()


func _test_catalog_and_selection() -> void:
	CardDatabase.load_all(true)
	var cards := CardDatabase.get_cards_for_type("effects")
	_expect(cards.size() == 13, "Etki Kartı havuzu tam olarak 13 kart içermeli")
	var rarity_counts := {"COMMON": 0, "RARE": 0, "EPIC": 0, "LEGENDARY": 0}
	for card_variant in cards:
		var card := card_variant as Dictionary
		var rarity := str(card.get("rarity", ""))
		rarity_counts[rarity] = int(rarity_counts.get(rarity, 0)) + 1
		_expect(not bool(card.get("deck_enabled", true)), "%s normal desteye girmemeli" % str(card.get("id", "")))
		_expect(not card.has("energy_cost") and not card.has("attack") and not card.has("armor") and not card.has("health"), "%s savaş veya Enerji değeri taşımamalı" % str(card.get("id", "")))
	_expect(rarity_counts == {"COMMON": 3, "RARE": 4, "EPIC": 4, "LEGENDARY": 2}, "Etki Kartı nadirlik dağılımı 3/4/4/2 olmalı")

	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 91234
	rng_b.seed = 91234
	var offer_a := EffectCardCatalog.create_offer(rng_a)
	var offer_b := EffectCardCatalog.create_offer(rng_b)
	_expect(offer_a == offer_b, "Aynı seed aynı üçlü teklifi üretmeli")
	_expect(offer_a.size() == 3 and _unique_count(offer_a) == 3, "Her teklif kendi içinde üç farklı kart içermeli")

	# Equal pool weighting is independent of rarity. A broad deterministic sample
	# catches accidental rarity-weighted or duplicate offer generation.
	var appearances := {}
	for card_id in EffectCardCatalog.get_all_ids():
		appearances[card_id] = 0
	for seed_value in range(1, 2001):
		var sample_rng := RandomNumberGenerator.new()
		sample_rng.seed = seed_value * 7919
		var sample := EffectCardCatalog.create_offer(sample_rng)
		_expect(_unique_count(sample) == 3, "Örnek teklif içinde tekrar oluştu")
		for card_id in sample:
			appearances[card_id] = int(appearances.get(card_id, 0)) + 1
	for card_id in appearances:
		_expect(abs(int(appearances[card_id]) - 500) <= 100, "%s eşit olasılık bandının dışında kaldı" % card_id)

	MatchSetup.configure_local(42001)
	var manager := GameManager.new()
	root.add_child(manager)
	manager.call("_reset_match_state")
	_expect(manager.begin_effect_selection(1), "Yerel Etki Kartı seçimi başlatılamadı")
	var player_one_offer := manager.get_effect_offer(1)
	var player_two_offer := manager.get_effect_offer(2)
	_expect(player_one_offer.size() == 3 and player_two_offer.size() == 3, "İki oyuncuya bağımsız teklifler verilmedi")
	_expect(not manager.submit_effect_selection(1, "havuzda_yok"), "Teklifte olmayan kart seçilebildi")
	_expect(manager.submit_effect_selection(1, player_one_offer[0]), "Birinci oyuncu geçerli seçimi yapamadı")
	_expect(not manager.submit_effect_selection(1, player_one_offer[1]), "Oyuncu ikinci Etki Kartını seçebildi")
	_expect(manager.submit_effect_selection(2, player_two_offer[0]), "İkinci oyuncu geçerli seçimi yapamadı")
	_expect(manager.current_phase == GameManager.TurnPhase.MULLIGAN, "İki seçimden sonra Mulligan başlamadı")

	manager.mark_effect_triggered(1, "building_masters", {"card_id": "fixture"})
	var state_snapshot := manager.build_state_snapshot()
	var restored_manager := GameManager.new()
	root.add_child(restored_manager)
	var restore_result := restored_manager.apply_state_snapshot(state_snapshot)
	_expect(bool(restore_result.get("success", false)), "Etki seçimi GameManager snapshot'ından yüklenemedi")
	_expect(restored_manager.effect_offers == manager.effect_offers, "Snapshot teklifleri yeniden üretti veya değiştirdi")
	_expect(restored_manager.selected_effect_cards == manager.selected_effect_cards, "Snapshot seçilen Etki Kartlarını korumadı")
	_expect(restored_manager.has_effect_triggered(1, "building_masters"), "Snapshot tur içi tetik sınırını korumadı")
	_expect(int(restored_manager.effect_trigger_totals.get(1, 0)) == 1, "Snapshot maç-geneli tetik sayacını korumadı")

	manager.queue_free()
	restored_manager.queue_free()

	# Timeout selection must consume the same deterministic RNG stream.
	var timeout_results: Array[Dictionary] = []
	for repetition in range(2):
		MatchSetup.configure_local(43002)
		var timeout_manager := GameManager.new()
		root.add_child(timeout_manager)
		timeout_manager.call("_reset_match_state")
		timeout_manager.begin_effect_selection(1)
		timeout_manager.call("_resolve_effect_selection_timeout")
		timeout_manager.call("_resolve_effect_selection_timeout")
		timeout_results.append(timeout_manager.selected_effect_cards.duplicate(true))
		timeout_manager.queue_free()
	_expect(timeout_results[0] == timeout_results[1] and timeout_results[0].size() == 2, "Zaman aşımı seçimi deterministik değil")

	# Authoritative multiplayer accepts simultaneous hidden choices in either order.
	MatchSetup.configure_multiplayer_server(44003, "effect-online")
	var online_manager := GameManager.new()
	root.add_child(online_manager)
	online_manager.call("_reset_match_state")
	online_manager.begin_effect_selection(1)
	_expect(online_manager.submit_effect_selection(2, online_manager.get_effect_offer(2)[0]), "Çevrimiçi ikinci oyuncunun eşzamanlı seçimi reddedildi")
	_expect(online_manager.submit_effect_selection(1, online_manager.get_effect_offer(1)[0]), "Çevrimiçi birinci oyuncunun eşzamanlı seçimi reddedildi")
	var public_state := online_manager.get_effect_selection_public_state(1)
	_expect(not public_state.has("opponent_selected_card") and not public_state.has("opponent_offer"), "Rakip Etki Kartı kimliği public state üzerinden sızdı")
	online_manager.queue_free()

	MatchSetup.configure_multiplayer_server(44004, "effect-online-same-card")
	var same_card_manager := GameManager.new()
	root.add_child(same_card_manager)
	same_card_manager.call("_reset_match_state")
	_expect(same_card_manager.begin_effect_selection(1), "Aynı kart sunucu seçimi başlatılamadı")
	same_card_manager.effect_offers = {
		1: ["son_direnis", "saha_hekimleri", "dovme_ocagi"],
		2: ["son_direnis", "ikmal_hatti", "yapi_ustalari"],
	}
	_expect(same_card_manager.submit_effect_selection(2, "son_direnis"), "İkinci oyuncu ortak Etki Kartını seçemedi")
	_expect(same_card_manager.submit_effect_selection(1, "son_direnis"), "İki oyuncunun aynı Etki Kartını seçmesine izin verilmedi")
	_expect(
		same_card_manager.selected_effect_cards == {1: "son_direnis", 2: "son_direnis"},
		"Aynı Etki Kartı seçimi sunucuda korunmadı"
	)
	same_card_manager.queue_free()

	MatchSetup.configure_multiplayer_server(44005, "effect-online-timeout")
	var server_timeout_manager := GameManager.new()
	root.add_child(server_timeout_manager)
	server_timeout_manager.call("_reset_match_state")
	_expect(server_timeout_manager.begin_effect_selection(1), "Sunucu timeout seçimi başlatılamadı")
	var server_timeout_offers := server_timeout_manager.effect_offers.duplicate(true)
	server_timeout_manager.call("_resolve_effect_selection_timeout")
	_expect(server_timeout_manager.selected_effect_cards.size() == 2, "Sunucu timeout iki eksik seçimi otomatik tamamlamadı")
	for player_id in GameRules.PLAYER_IDS:
		_expect(
			server_timeout_manager.get_selected_effect_card(player_id) in (server_timeout_offers.get(player_id, []) as Array),
			"Sunucu timeout Oyuncu %d teklif dışı kart seçti" % player_id
		)
	_expect(server_timeout_manager.current_phase == GameManager.TurnPhase.MULLIGAN, "Sunucu timeout sonrası Mulligan başlamadı")
	server_timeout_manager.queue_free()


func _test_building_masters() -> void:
	var environment := await _make_environment("yapi_ustalari")
	var manager := environment.manager as GameManager
	var board = environment.board
	var first := _place_settlement(board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE), 1)
	var second := _place_settlement(board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.STRUCTURE), 1)
	first.max_health = 10
	first.health = 6
	second.max_health = 10
	second.health = 6
	var first_result := EffectResolver.resolve_after_board_card_played(manager, first)
	var second_result := EffectResolver.resolve_after_board_card_played(manager, second)
	_expect(bool(first_result.get("triggered", false)) and first.max_health == 12 and first.health == 8, "Yapı Ustaları ilk Yerleşkeye mevcut ve maksimum +2 Can vermedi")
	_expect(not bool(second_result.get("triggered", true)) and second.max_health == 10, "Yapı Ustaları aynı tur ikinci kez tetiklendi")
	await _cleanup_environment(environment)


func _test_field_medics_and_oath() -> void:
	var medic_environment := await _make_environment("saha_hekimleri")
	var medic_manager := medic_environment.manager as GameManager
	var medic_board = medic_environment.board
	var front := _place_hero(medic_board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT), 1)
	var back := _place_hero(medic_board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK), 1)
	front.max_health = 10
	front.health = 5
	back.max_health = 10
	back.health = 5
	EffectResolver.resolve_turn_end(medic_manager, 1)
	EffectResolver.resolve_turn_end(medic_manager, 1)
	_expect(front.health == 6 and back.health == 5, "Saha Hekimleri eşitlikte sabit FRONT slotunu seçip yalnızca bir kez iyileştirmedi")
	await _cleanup_environment(medic_environment)

	var oath_environment := await _make_environment("koruyucu_yemin")
	var oath_manager := oath_environment.manager as GameManager
	var oath_board = oath_environment.board
	var oath_front := _place_hero(oath_board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT), 1)
	var oath_back := _place_hero(oath_board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK), 1)
	oath_front.max_health = 10
	oath_front.health = 4
	oath_back.max_health = 10
	oath_back.health = 4
	EffectResolver.resolve_turn_start(oath_manager, 1)
	EffectResolver.resolve_turn_start(oath_manager, 1)
	_expect(oath_front.get_status_amount(EffectResolver.STATUS_PROTECTED) == 1, "Koruyucu Yemin en yaralı ilk sabit slota Korumalı 1 vermedi")
	_expect(oath_back.get_status_amount(EffectResolver.STATUS_PROTECTED) == 0, "Koruyucu Yemin aynı tur ikinci hedefte tekrar tetiklendi")
	await _cleanup_environment(oath_environment)


func _test_flanking_maneuver() -> void:
	var environment := await _make_environment("kanat_manevrasi")
	var manager := environment.manager as GameManager
	var board = environment.board
	var first_origin: CardSlot = board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT)
	var first_target: CardSlot = board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.BACK)
	var second_origin: CardSlot = board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT)
	var second_target: CardSlot = board.create_lane_slot(1, CardSlot.Lane.RIGHT, CardSlot.PositionType.FRONT)
	var first := _place_hero(first_origin, 1)
	var second := _place_hero(second_origin, 1)
	first.set_combat_state(BaseCard.CombatState.READY)
	second.set_combat_state(BaseCard.CombatState.READY)
	manager.player_current_energy[1] = 3
	var first_result := MovementResolver.resolve_move(manager, first, first_target)
	var second_result := MovementResolver.resolve_move(manager, second, second_target)
	_expect(bool(first_result.get("success", false)) and int(first_result.get("energy_spent", -1)) == 0, "Kanat Manevrası ilk yasal hareketi ücretsiz yapmadı")
	_expect(bool(second_result.get("success", false)) and int(second_result.get("energy_spent", -1)) == 1, "Kanat Manevrası aynı tur ikinci hareketi de ücretsiz yaptı")
	_expect(manager.get_available_energy(1) == 2, "Kanat Manevrası Enerji muhasebesi yanlış")
	await _cleanup_environment(environment)


func _test_cost_discounts_and_supply_line() -> void:
	for config in [
		{"effect": "oncu_doktrini", "action": "hero", "card": HeroCard.new(), "trigger": "vanguard_doctrine"},
		{"effect": "usta_zanaatkarlar", "action": "settlement", "card": SettlementCard.new(), "trigger": "master_artisans"},
		{"effect": "gizli_cephanelik", "action": "special_power", "card": SpecialPowerCard.new(), "trigger": "hidden_arsenal"},
	]:
		var environment := await _make_environment(str(config.effect))
		var manager := environment.manager as GameManager
		var card := config.card as BaseCard
		card.owner_id = 1
		var first_cost := EffectResolver.get_effect_action_cost(manager, card, str(config.action), 1)
		_expect(first_cost == 1, "%s indirimi maliyeti 1'in altına düşürdü" % str(config.effect))
		EffectResolver.resolve_energy_action(manager, card, str(config.action), first_cost)
		var second_cost := EffectResolver.get_effect_action_cost(manager, card, str(config.action), 4)
		_expect(second_cost == 4 and manager.has_effect_triggered(1, str(config.trigger)), "%s yalnızca ilk uygun kartta tüketilmedi" % str(config.effect))
		card.free()
		await _cleanup_environment(environment)

	MatchSetup.configure_local(45004)
	var supply_board := SupplyBoardStub.new()
	root.add_child(supply_board)
	var supply_manager := GameManager.new()
	supply_board.add_child(supply_manager)
	await process_frame
	supply_manager.is_match_started = true
	supply_manager.current_phase = GameManager.TurnPhase.PREPARATION
	supply_manager.active_player_id = 1
	supply_manager.selected_effect_cards = {1: "ikmal_hatti", 2: ""}
	supply_manager.player_current_energy[1] = 2
	var requested_draws := [0]
	supply_manager.effect_draw_requested.connect(func(_player: int, count: int, _source: BaseCard): requested_draws[0] = int(requested_draws[0]) + count)
	var supply_card := HeroCard.new()
	supply_card.owner_id = 1
	_expect(supply_manager.spend_energy(1, 2), "İkmal Hattı fixture Enerjisi harcanamadı")
	var supply_result := EffectResolver.resolve_energy_action(supply_manager, supply_card, "hero", 2)
	var duplicate_result := EffectResolver.resolve_energy_action(supply_manager, supply_card, "hero", 1)
	_expect(bool(supply_result.get("triggered", false)) and int(requested_draws[0]) == 1, "İkmal Hattı ilk harcama Enerjiyi sıfırladığında kart çekmedi")
	_expect(not bool(duplicate_result.get("triggered", true)) and int(requested_draws[0]) == 1, "İkmal Hattı aynı tur ikinci kez tetiklendi")
	_expect(supply_manager.has_effect_triggered(1, "supply_line_checked") and supply_manager.has_effect_triggered(1, "supply_line"), "İkmal Hattı kontrol ve gerçek tetik durumlarını ayırmadı")
	_expect(int(supply_manager.effect_trigger_totals.get(1, 0)) == 1, "İkmal Hattı gerçek çekişi bir kez sayılmadı")

	# When the first spend leaves remaining Energy, a subsequent action that
	# empties Energy in the same turn triggers Supply Line cleanly once.
	supply_manager.call("_reset_effect_trigger_ledger")
	supply_manager.player_current_energy[1] = 2
	_expect(supply_manager.spend_energy(1, 1), "İkmal Hattı ilk kontrol harcaması yapılamadı")
	var non_zero_result := EffectResolver.resolve_energy_action(supply_manager, supply_card, "hero", 1)
	_expect(supply_manager.spend_energy(1, 1), "İkmal Hattı ikinci kontrol harcaması yapılamadı")
	var later_zero_result := EffectResolver.resolve_energy_action(supply_manager, supply_card, "hero", 1)
	_expect(
		not bool(non_zero_result.get("triggered", true))
		and bool(later_zero_result.get("triggered", false))
		and int(requested_draws[0]) == 2,
		"İkmal Hattı turda Enerjiyi sıfırlayan hamlede tetiklenmeli"
	)
	_expect(int(supply_manager.effect_trigger_totals.get(1, 0)) == 2, "İkmal Hattı ikinci turdaki gerçek tetiği kaydetmeli")
	supply_card.free()
	supply_board.queue_free()
	await process_frame


func _test_siege_plan_and_last_stand() -> void:
	var siege_environment := await _make_environment("kusatma_plani", GameManager.TurnPhase.COMBAT)
	var siege_manager := siege_environment.manager as GameManager
	var siege_board = siege_environment.board
	var attacker := _place_hero(siege_board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT), 1)
	var target := _place_settlement(siege_board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE), 2)
	attacker.attack = 3
	target.max_health = 20
	target.health = 20
	var first_hit := EffectResolver.apply_damage(siege_manager, attacker, target, 3, false, false, true)
	var second_hit := EffectResolver.apply_damage(siege_manager, attacker, target, 3, false, false, true)
	_expect(int(first_hit.get("effect_card_bonus", 0)) == 1 and target.health == 13, "Kuşatma Planı ilk normal Yapı saldırısına yalnızca +1 eklemedi")
	_expect(int(second_hit.get("effect_card_bonus", -1)) == 0, "Kuşatma Planı aynı tur ikinci kez tetiklendi")
	await _cleanup_environment(siege_environment)

	var guard_environment := await _make_environment("kusatma_plani", GameManager.TurnPhase.COMBAT)
	var guard_manager := guard_environment.manager as GameManager
	var guard_board = guard_environment.board
	var guard_attacker := _place_hero(guard_board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT), 1)
	var guard := _place_hero(guard_board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT), 2, "sovalye")
	var guarded_target := _place_settlement(guard_board.create_lane_slot(2, CardSlot.Lane.LEFT, CardSlot.PositionType.STRUCTURE), 2)
	guard_attacker.attack = 3
	guarded_target.max_health = 20
	guarded_target.health = 20
	var redirected := EffectResolver.apply_damage(guard_manager, guard_attacker, guarded_target, 3, true, false, true)
	_expect(bool(redirected.get("guard_redirected", false)) and int(redirected.get("effect_card_bonus", -1)) == 0, "Muhafıza yönlenen saldırı Kuşatma Planını tetikledi")
	_expect(not guard_manager.has_effect_triggered(1, "siege_plan"), "Yönlenen saldırı Kuşatma Planı hakkını tüketti")
	guard.consume_guard()
	await _cleanup_environment(guard_environment)

	var stand_environment := await _make_environment("", GameManager.TurnPhase.COMBAT)
	var stand_manager := stand_environment.manager as GameManager
	stand_manager.selected_effect_cards = {1: "", 2: "son_direnis"}
	var stand_board = stand_environment.board
	var source := _place_hero(stand_board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT), 1)
	var hq := _place_settlement(stand_board.create_hq_slot(2), 2, "p2_merkez")
	hq.max_health = 30
	hq.health = 30
	var first_hq_hit := EffectResolver.apply_damage(stand_manager, source, hq, 3, false, false, true)
	var second_hq_hit := EffectResolver.apply_damage(stand_manager, source, hq, 3, false, false, true)
	_expect(int(first_hq_hit.get("last_stand_reduction", 0)) == 1 and hq.health == 25, "Son Direniş ilk pozitif Merkez hasarını 1 azaltmadı")
	_expect(int(second_hq_hit.get("last_stand_reduction", -1)) == 0, "Son Direniş aynı rakip turunda ikinci kez tetiklendi")
	await _cleanup_environment(stand_environment)


func _test_forge() -> void:
	var environment := await _make_environment("dovme_ocagi")
	var manager := environment.manager as GameManager
	var board = environment.board
	var target := _place_hero(board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT), 1)
	target.max_health = 8
	target.health = 5
	var first_upgrade := UpgradeCard.new()
	first_upgrade.owner_id = 1
	var second_upgrade := UpgradeCard.new()
	second_upgrade.owner_id = 1
	var first_result := EffectResolver.resolve_after_upgrade(manager, first_upgrade, target)
	var second_result := EffectResolver.resolve_after_upgrade(manager, second_upgrade, target)
	_expect(bool(first_result.get("triggered", false)) and target.max_health == 9 and target.health == 6, "Dövme Ocağı ilk Beceri çözümünde hedefe mevcut ve maksimum +1 Can vermedi")
	_expect(not bool(second_result.get("triggered", true)) and target.max_health == 9, "Dövme Ocağı aynı tur ikinci kez tetiklendi")
	first_upgrade.free()
	second_upgrade.free()
	await _cleanup_environment(environment)


func _test_guard_watch() -> void:
	var environment := await _make_environment("muhafiz_nobeti")
	var manager := environment.manager as GameManager
	var board = environment.board
	var first := _place_hero(board.create_lane_slot(1, CardSlot.Lane.LEFT, CardSlot.PositionType.FRONT), 1)
	var second := _place_hero(board.create_lane_slot(1, CardSlot.Lane.CENTER, CardSlot.PositionType.FRONT), 1)
	var first_result := EffectResolver.resolve_after_board_card_played(manager, first)
	var second_result := EffectResolver.resolve_after_board_card_played(manager, second)
	_expect(
		bool(first_result.get("triggered", false))
		and first.get_status_amount(EffectResolver.STATUS_PROTECTED) == 2,
		"Muhafız Nöbeti ilk oynanan Kahramana Korumalı 2 vermedi"
	)
	_expect(
		not bool(second_result.get("triggered", true))
		and second.get_status_amount(EffectResolver.STATUS_PROTECTED) == 0,
		"Muhafız Nöbeti aynı tur ikinci Kahramanda tekrar tetiklendi"
	)
	await _cleanup_environment(environment)


func _make_environment(effect_card_id: String, phase: int = GameManager.TurnPhase.PREPARATION) -> Dictionary:
	MatchSetup.configure_local(46000 + effect_card_id.hash())
	var board := CombatBoardStub.new()
	root.add_child(board)
	var manager := GameManager.new()
	board.add_child(manager)
	await process_frame
	manager.is_game_active = true
	manager.is_match_started = true
	manager.active_player_id = 1
	manager.first_player_id = 1
	manager.current_phase = phase
	manager.selected_effect_cards = {1: effect_card_id, 2: ""}
	manager.effect_trigger_totals = {1: 0, 2: 0}
	manager.call("_reset_effect_trigger_ledger")
	return {"board": board, "manager": manager}


func _cleanup_environment(environment: Dictionary) -> void:
	var board := environment.get("board") as Node
	if board:
		board.queue_free()
	await process_frame


func _place_hero(slot: CardSlot, owner_id: int, card_id: String = "alev_duellocusu") -> HeroCard:
	var card := HeroCard.new()
	card.owner_id = owner_id
	card.card_id = card_id
	slot.add_child(card)
	return card


func _place_settlement(slot: CardSlot, owner_id: int, card_id: String = "tas_sur") -> SettlementCard:
	var card := SettlementCard.new()
	card.owner_id = owner_id
	card.card_id = card_id
	slot.add_child(card)
	return card


func _unique_count(values: Array) -> int:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("EFFECT_CARDS_RULES_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("EFFECT_CARDS_RULES_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
