extends SceneTree

const TEST_PATH := "user://active_match_save_smoke.json"
const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	SafeJsonStore.remove_family(TEST_PATH, ActiveMatchRepository.BACKUP_COUNT)
	MatchSetup.configure_local(57001)
	SCENARIO_CATALOG.load_catalog(true)
	MatchSetup.set_scenario_context(SCENARIO_CATALOG.build_match_context("cepheye_ilk_adim"))
	MatchSetup.fast_mode = true
	var packed := load("res://battlefield.tscn") as PackedScene
	_expect(packed != null, "battlefield.tscn yüklenemedi")
	if not packed:
		_finish()
		return

	var battlefield := packed.instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	while battlefield._is_dealing_initial_hands:
		await process_frame
	await process_frame
	var scenario_button := battlefield.find_child("ScenarioObjectivesButton", true, false) as Button
	var scenario_briefing := battlefield.find_child("ScenarioBriefingOverlay", true, false) as Control
	_expect(scenario_button != null, "Senaryo hedefleri savaş alanı kenar çubuğunda görünmeli")
	_expect(scenario_briefing != null, "Senaryo brifingi savaş alanında oluşturulmalı")
	battlefield.call("_show_scenario_briefing")
	_expect(scenario_briefing != null and bool(scenario_briefing.call("is_open")), "Senaryo brifingi savaş içinden açılabilmeli")
	if scenario_briefing:
		_expect(int(scenario_briefing.call("get_objective_count")) == 3, "Savaş içi brifing senaryo hedeflerini göstermeli")
		scenario_briefing.call("close_panel")

	var manager := battlefield.game_manager as GameManager
	manager.cards_drawn_per_turn = 0
	var first_player := manager.first_player_id
	var second_player := manager.get_opponent_id(first_player)
	_expect(manager.current_phase == GameManager.TurnPhase.MULLIGAN, "Kayıt fixture'ı Mulligan aşamasına gelemedi")
	_expect(manager.confirm_mulligan(first_player), "İlk Mulligan onayı başarısız")
	_expect(manager.confirm_mulligan(second_player), "İkinci Mulligan onayı başarısız")
	await process_frame

	manager.player_current_energy[first_player] = 20
	manager.player_temporary_energy[first_player] = 2
	var playable := _find_placeable_hand_card(battlefield, first_player)
	_expect(playable != null, "Sahaya yerleştirilecek el kartı bulunamadı")
	var target_slot := _find_placement_slot(battlefield, playable, first_player)
	_expect(target_slot != null, "Kayıt fixture'ı için uygun saha yuvası bulunamadı")
	if not playable or not target_slot:
		battlefield.queue_free()
		await process_frame
		_finish()
		return
	var play_result := battlefield.play_hand_card_to_slot(playable, target_slot)
	_expect(bool(play_result.get("success", false)), "Fixture kartı sahaya oynanamadı")
	var live_summary := battlefield._match_telemetry.get_summary() as Dictionary
	var live_player := (live_summary.get("players", {}) as Dictionary).get(first_player, {}) as Dictionary
	var live_lane := (live_player.get("lane_activity", {}) as Dictionary).get(str(int(target_slot.lane_id)), {}) as Dictionary
	_expect(int(live_lane.get("deployments", 0)) == 1, "Gerçek kart yerleşimi koridor telemetrisine yazılmalı")
	_expect(
		int(live_player.get("energy_spent", 0)) == int(play_result.get("energy_spent", -1)),
		"Telemetri değiştirilmiş kart maliyeti yerine gerçekten harcanan Enerjiyi kullanmalı"
	)

	playable.apply_status(EffectResolver.STATUS_PROTECTED, 2)
	playable.apply_status(EffectResolver.STATUS_POISON, 1, 2)
	playable.experience = 4
	playable.card_level = 2
	playable.selected_branch_id = "snapshot_branch"
	playable.selected_branch_name = "Snapshot Yolu"
	playable.experience_gained_this_turn = 2
	playable.has_moved_this_turn = true
	playable.trait_runtime = {"bulwark_available": false, "soulbond_round": 4}
	playable.set_combat_state(BaseCard.CombatState.READY)
	playable.attached_skill_name = "Fixture Becerisi"
	playable.attached_skill_card_id = "celik_kalkan"
	playable.attached_skill_modifiers = {"armor": 2, "health": 1}
	playable.attached_skill_added_traits = ["guard"]
	if playable is HeroCard:
		var hero := playable as HeroCard
		hero.max_health = 13
		hero.health = 9
		hero.max_armor = 7
		hero.armor = 4
		hero.attack = 6
	elif playable is SettlementCard:
		var settlement := playable as SettlementCard
		settlement.max_health = 14
		settlement.health = 9
		settlement.attack = 3

	var graveyard_card := _first_other_hand_card(battlefield, first_player, playable)
	_expect(graveyard_card != null, "Mezarlık fixture kartı bulunamadı")
	if graveyard_card:
		battlefield.call("_remove_hand_card", graveyard_card)
		await process_frame

	manager.selected_effect_cards = {1: "dovme_ocagi", 2: "son_direnis"}
	manager.effect_offers = {
		1: ["dovme_ocagi", "saha_hekimleri", "oncu_doktrini"],
		2: ["son_direnis", "ikmal_hatti", "yapi_ustalari"],
	}
	manager.mark_effect_triggered(first_player, "forge", {"target_card_id": playable.card_id})
	manager.player_current_energy = {1: 5, 2: 7}
	manager.player_temporary_energy = {1: 1, 2: 0}
	manager.player_max_energy = {1: 8, 2: 9}
	manager.set_hq_health(1, 23)
	manager.set_hq_health(2, 17)
	manager.turn_count = 7
	manager.round_count = 4
	manager.turn_time_remaining_seconds = 21.25
	manager.set("_turn_timer_running", true)

	var snapshot := battlefield.build_active_match_snapshot("test_round_trip")
	_expect(not snapshot.is_empty(), "Aktif maç snapshot'ı üretilemedi")
	_expect(
		str((snapshot.get("scenario_context", {}) as Dictionary).get("scenario_id", "")) == "cepheye_ilk_adim",
		"Senaryo bağlamı aktif maç snapshot'ına yazılmadı"
	)
	var snapshot_validation := ActiveMatchRepository.new().validate_snapshot(snapshot)
	_expect(bool(snapshot_validation.get("success", false)), "Aktif maç snapshot şeması geçersiz")
	var saved_manager := snapshot.get("manager", {}) as Dictionary
	var saved_zones := snapshot.get("zones", {}) as Dictionary
	var saved_card_row := _find_snapshot_card(saved_zones.get("board_cards", []) as Array, str(playable.get_meta("network_card_id", "")))
	_expect(not saved_card_row.is_empty(), "Sahadaki kart snapshot'a yazılmadı")
	_expect(int(saved_card_row.get("card_level", 0)) == 2 and int(saved_card_row.get("experience", 0)) == 4, "Kart seviye/tecrübe durumu snapshot'a yazılmadı")
	_expect((saved_card_row.get("status_effects", {}) as Dictionary).get("protected", 0) == 2, "Kart durum etkileri snapshot'a yazılmadı")
	_expect((saved_card_row.get("trait_runtime", {}) as Dictionary).get("soulbond_round", 0) == 4, "Kart nitelik çalışma durumu snapshot'a yazılmadı")
	_expect((saved_zones.get("graveyards", {}) as Dictionary).get(first_player, []).size() == 1, "Mezarlık snapshot'a yazılmadı")

	var deck_rng_row := _player_value(snapshot.get("rng", {}).get("deck", {}) as Dictionary, first_player, {}) as Dictionary
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = str(deck_rng_row.get("seed", "0")).to_int()
	expected_rng.state = str(deck_rng_row.get("state", "0")).to_int()
	var expected_next_random := expected_rng.randi()

	var repository := battlefield._active_match_repository as ActiveMatchRepository
	repository.configure_path(TEST_PATH)
	repository.delete_all()
	battlefield.call("_open_pause_menu")
	var pause_loaded := repository.load_primary()
	_expect(bool(pause_loaded.get("success", false)), "Duraklatma anında otomatik kayıt alınmadı")
	_expect(
		str((pause_loaded.get("snapshot", {}) as Dictionary).get("last_save_reason", "")) == "duraklatma",
		"Duraklatma kaydı doğru nedeni taşımıyor"
	)
	battlefield.call("_manual_save_active_match")
	var manual_loaded := repository.load_primary()
	_expect(bool(manual_loaded.get("success", false)), "Oyunu Kaydet eylemi aktif snapshot yazmadı")
	_expect(
		str((manual_loaded.get("snapshot", {}) as Dictionary).get("last_save_reason", "")) == "elle_kayıt",
		"Oyunu Kaydet eylemi elle kayıt nedenini taşımıyor"
	)
	battlefield.call("_resume_from_pause")
	_expect(not paused, "Elle kayıt doğrulamasından sonra oyun duraklatılmış kalmamalı")
	repository.delete_all()

	# Stop signal-driven autosave while deliberately corrupting the fixture file.
	battlefield._restoring_active_match = true
	for save_index in range(4):
		var save_copy := snapshot.duplicate(true)
		save_copy["last_save_reason"] = "rotation_%d" % save_index
		var save_result := repository.save_snapshot(save_copy)
		_expect(bool(save_result.get("success", false)), "Aktif maç yedek rotasyonu %d yazılamadı" % save_index)
	for backup_index in range(1, ActiveMatchRepository.BACKUP_COUNT + 1):
		_expect(FileAccess.file_exists(SafeJsonStore.backup_path(TEST_PATH, backup_index)), "Aktif maç %d numaralı yedeği oluşmadı" % backup_index)

	var primary_payload := SafeJsonStore.read_dictionary(TEST_PATH).get("data", {}) as Dictionary
	primary_payload["game_version"] = "999.0"
	SafeJsonStore.write_dictionary_atomic(TEST_PATH, primary_payload, 0)
	var incompatible_status := repository.inspect_save()
	_expect(str(incompatible_status.get("state", "")) == "recoverable" and bool(incompatible_status.get("has_backup", false)), "Uyumsuz kayıt yedek kurtarma seçeneği sunmadı")

	var corrupt_file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	_expect(corrupt_file != null, "Bozuk aktif maç fixture'ı açılamadı")
	if corrupt_file:
		corrupt_file.store_string("[bozuk aktif maç")
		corrupt_file = null
	var corrupt_status := repository.inspect_save()
	_expect(str(corrupt_status.get("state", "")) == "recoverable", "Bozuk aktif maç geçerli yedeği tespit etmedi")
	var recovered := repository.recover_backup()
	_expect(bool(recovered.get("success", false)), "Aktif maç yedekten kurtarılamadı")

	var duplicate_snapshot := snapshot.duplicate(true)
	var duplicate_zones := duplicate_snapshot.get("zones", {}) as Dictionary
	var duplicate_graveyards := duplicate_zones.get("graveyards", {}) as Dictionary
	var duplicate_rows: Array = (_player_value(duplicate_graveyards, first_player, []) as Array).duplicate(true)
	var hand_rows := _player_value(duplicate_zones.get("hands", {}) as Dictionary, first_player, []) as Array
	if not hand_rows.is_empty():
		duplicate_rows.append((hand_rows[0] as Dictionary).duplicate(true))
		duplicate_graveyards[first_player] = duplicate_rows
		duplicate_zones["graveyards"] = duplicate_graveyards
		duplicate_snapshot["zones"] = duplicate_zones
		var duplicate_validation := battlefield.call("_validate_active_snapshot_identities", duplicate_snapshot) as Dictionary
		_expect(not bool(duplicate_validation.get("success", true)), "Yinelenen fiziksel kart kimliği kabul edildi")

	# The original scene must not overwrite the test snapshot on exit.
	battlefield._active_match_completed = true
	battlefield.queue_free()
	current_scene = null
	await process_frame
	await process_frame

	MatchSetup.configure_local(int(snapshot.get("seed", 57001)))
	MatchSetup.fast_mode = true
	MatchSetup.set_resume_snapshot(snapshot)
	var restored := packed.instantiate() as BattlefieldUI
	root.add_child(restored)
	current_scene = restored
	await process_frame
	await process_frame
	await process_frame
	var restored_manager := restored.game_manager as GameManager
	var restored_snapshot := restored.build_active_match_snapshot("restored_compare")
	var restored_zones := restored_snapshot.get("zones", {}) as Dictionary

	_expect(str(restored_snapshot.get("match_id", "")) == str(snapshot.get("match_id", "")), "Yükleme match_id değerini korumadı")
	_expect(MatchSetup.get_scenario_id() == "cepheye_ilk_adim", "Senaryo bağlamı aktif maç snapshot'ından geri yüklenmedi")
	_expect(restored.find_child("ScenarioObjectivesButton", true, false) is Button, "Yüklenen senaryo maçında hedef düğmesi geri gelmeli")
	_expect(restored_manager.active_player_id == int(saved_manager.get("active_player_id", 0)), "Aktif oyuncu geri yüklenmedi")
	_expect(restored_manager.turn_count == 7 and restored_manager.round_count == 4, "Tur/raund sayaçları geri yüklenmedi")
	_expect(restored_manager.player_current_energy == {1: 5, 2: 7}, "Enerji durumu geri yüklenmedi")
	_expect(restored_manager.player_temporary_energy == {1: 1, 2: 0}, "Geçici Enerji durumu geri yüklenmedi")
	_expect(restored_manager.player_hq_health == {1: 23, 2: 17}, "Merkez canları geri yüklenmedi")
	_expect(restored_manager.selected_effect_cards == {1: "dovme_ocagi", 2: "son_direnis"}, "Etki Kartı seçimleri geri yüklenmedi")
	_expect(restored_manager.has_effect_triggered(first_player, "forge"), "Etki Kartı tur içi tetik hakkı geri yüklenmedi")
	_expect(_physical_id_set(saved_zones) == _physical_id_set(restored_zones), "Yükleme kart çoğalttı, kaybetti veya kimlikleri değiştirdi")
	_expect(saved_zones.get("deck_order") == restored_zones.get("deck_order"), "Deste sırası birebir geri yüklenmedi")
	_expect(saved_zones.get("graveyards") == restored_zones.get("graveyards"), "Mezarlık birebir geri yüklenmedi")

	var restored_card := restored.call("_find_card_by_network_id", str(saved_card_row.get("network_id", ""))) as BaseCard
	_expect(restored_card != null, "Snapshot saha kartı yeniden oluşturulmadı")
	if restored_card:
		_expect(restored_card.current_slot != null and restored.call("_get_slot_network_id", restored_card.current_slot) == str(saved_card_row.get("slot_id", "")), "Kart aynı saha yuvasına dönmedi")
		_expect(restored_card.card_level == 2 and restored_card.experience == 4, "Kart ilerleme durumu geri yüklenmedi")
		_expect(restored_card.attached_skill_card_id == "celik_kalkan" and restored_card.attached_skill_modifiers == {"armor": 2, "health": 1}, "Kart geliştirme durumu geri yüklenmedi")
		_expect(restored_card.get_status_amount(EffectResolver.STATUS_PROTECTED) == 2, "Kart durum etkileri geri yüklenmedi")
		_expect(restored_card.trait_runtime == {"bulwark_available": false, "soulbond_round": 4}, "Kart nitelik çalışma durumu geri yüklenmedi")
		_expect(restored_card.combat_state == BaseCard.CombatState.READY and restored_card.has_moved_this_turn, "Kart hamle/savaş hakkı geri yüklenmedi")

	var restored_rng := restored._deck_rngs.get(first_player) as RandomNumberGenerator
	_expect(restored_rng != null and restored_rng.randi() == expected_next_random, "Deste RNG akışı snapshot sonrası aynı noktadan devam etmedi")
	var timer_at_restore := restored_manager.turn_time_remaining_seconds
	_expect(timer_at_restore <= 21.25 and timer_at_restore > 20.0 and bool(restored_manager.get("_turn_timer_running")), "Tur sayacı kaydedilen kalan süreden devam etmedi")
	await create_timer(0.12).timeout
	_expect(restored_manager.turn_time_remaining_seconds < timer_at_restore, "Yüklenen yerel maçın tur sayacı çalışmaya devam etmedi")

	restored._active_match_completed = true
	restored.queue_free()
	current_scene = null
	await process_frame
	SafeJsonStore.remove_family(TEST_PATH, ActiveMatchRepository.BACKUP_COUNT)
	MatchSetup.configure_local(1)
	_finish()


func _find_placeable_hand_card(battlefield: BattlefieldUI, player_id: int) -> BaseCard:
	for card in battlefield.get_hand_cards(player_id):
		if card is HeroCard or card is SettlementCard:
			return card
	return null


func _first_other_hand_card(battlefield: BattlefieldUI, player_id: int, excluded: BaseCard) -> BaseCard:
	for card in battlefield.get_hand_cards(player_id):
		if card != excluded:
			return card
	return null


func _find_placement_slot(battlefield: BattlefieldUI, card: BaseCard, player_id: int) -> CardSlot:
	for slot in battlefield.get_board_slots(player_id):
		if card is HeroCard and slot.position_type in [CardSlot.PositionType.FRONT, CardSlot.PositionType.BACK] and not slot.is_occupied:
			return slot
		if card is SettlementCard and slot.position_type == CardSlot.PositionType.STRUCTURE and not slot.is_occupied:
			return slot
	return null


func _find_snapshot_card(rows: Array, network_id: String) -> Dictionary:
	for row_variant in rows:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("network_id", "")) == network_id:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func _physical_id_set(zones: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var hands_variant: Variant = zones.get("hands", {})
	if hands_variant is Dictionary:
		for player_id in GameRules.PLAYER_IDS:
			for row_variant in _player_value(hands_variant as Dictionary, player_id, []) as Array:
				if row_variant is Dictionary:
					ids.append(str((row_variant as Dictionary).get("network_id", "")))
	for row_variant in zones.get("board_cards", []) as Array:
		if row_variant is Dictionary:
			ids.append(str((row_variant as Dictionary).get("network_id", "")))
	var graveyards_variant: Variant = zones.get("graveyards", {})
	if graveyards_variant is Dictionary:
		for player_id in GameRules.PLAYER_IDS:
			for row_variant in _player_value(graveyards_variant as Dictionary, player_id, []) as Array:
				if row_variant is Dictionary:
					ids.append(str((row_variant as Dictionary).get("network_id", "")))
	ids.sort()
	return ids


func _player_value(dictionary: Dictionary, player_id: int, fallback: Variant) -> Variant:
	if dictionary.has(player_id):
		return dictionary[player_id]
	return dictionary.get(str(player_id), fallback)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ACTIVE_MATCH_SAVE_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("ACTIVE_MATCH_SAVE_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
