extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	root.size = Vector2i(1280, 720)
	CardDatabase.load_all(true)
	_test_tactic_content_and_deck_guarantees()
	await _test_battlefield_playability_flow()
	_finish()


func _test_tactic_content_and_deck_guarantees() -> void:
	var redraw := CardDatabase.get_card("special_powers", "taktik_degisim")
	var resupply := CardDatabase.get_card("special_powers", "ikmal_emri")
	var banish := CardDatabase.get_card("special_powers", "hiclik_fermani")
	_expect(str(redraw.get("effect_id", "")) == "redraw_card", "Taktik Değişim kart değiştirme etkisini taşımalı")
	_expect(str(resupply.get("effect_id", "")) == "draw_cards", "İkmal Emri fazladan kart çekme etkisini taşımalı")
	_expect(str(banish.get("effect_id", "")) == "banish_target", "Hiçlik Fermanı saha kartı silme etkisini taşımalı")
	_expect(ResourceLoader.exists(str(redraw.get("image_url", ""))), "Taktik Değişim görseli bulunmalı")
	_expect(ResourceLoader.exists(str(resupply.get("image_url", ""))), "İkmal Emri görseli bulunmalı")
	_expect(ResourceLoader.exists(str(banish.get("image_url", ""))), "Hiçlik Fermanı görseli bulunmalı")
	var playable_refs := CardDatabase.get_playable_card_refs()
	_expect(_deck_contains(playable_refs, "special_powers", "taktik_degisim"), "Oynanabilir havuz Taktik Değişim içermeli")
	_expect(_deck_contains(playable_refs, "special_powers", "ikmal_emri"), "Oynanabilir havuz İkmal Emri içermeli")
	_expect(_deck_contains(playable_refs, "special_powers", "hiclik_fermani"), "Oynanabilir havuz Hiçlik Fermanı içermeli")
	_expect(GameRules.MINIMUM_TURN_START_HAND == 3, "Takviye çekişi turu en az üç kartlık elle başlatmalı")
	_expect(BattlefieldFeedbackLayer.ATTACK_TELEGRAPH_SECONDS >= 0.90, "Saldırı hazırlığı hedefi okumaya yetecek kadar uzun olmalı")
	_expect(BattlefieldFeedbackLayer.ATTACK_IMPACT_SECONDS >= 0.60, "Saldırı darbesi görünür kalmalı")


func _test_battlefield_playability_flow() -> void:
	MatchSetup.configure_local(771923)
	MatchSetup.fast_mode = true
	var packed := load("res://battlefield.tscn") as PackedScene
	_expect(packed != null, "Oynanabilirlik testi için battlefield.tscn yüklenemedi")
	if not packed:
		return

	var battlefield := packed.instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	while battlefield._is_dealing_initial_hands:
		await process_frame
	battlefield._apply_responsive_layout()
	await process_frame

	_test_camera_range_and_toast(battlefield)

	var manager := battlefield.game_manager as GameManager
	manager.cards_drawn_per_turn = 0
	var active := manager.first_player_id
	var opponent := manager.get_opponent_id(active)
	_expect(manager.confirm_mulligan(active), "Aktif oyuncunun başlangıç eli onaylanmalı")
	_expect(manager.confirm_mulligan(opponent), "Rakibin başlangıç eli onaylanmalı")
	await process_frame
	var second_hq := battlefield.get_hq_slot(opponent).occupied_card as BaseCard
	_expect(
		second_hq.get_status_amount(EffectResolver.STATUS_PROTECTED) == GameRules.SECOND_PLAYER_HQ_PROTECTION,
		"İkinci oyuncunun Merkezi görünür Açılış Kalkanı almalı"
	)
	manager.player_current_energy[active] = 10
	manager.player_temporary_energy[active] = 0
	battlefield.sync_player_energy(active)

	await _test_target_language(battlefield, active, opponent)
	await _test_catch_up_draw_and_hand_tactics(battlefield, active)
	_test_combat_target_focus(battlefield, active, opponent)

	battlefield.queue_free()
	current_scene = null
	await process_frame
	MatchSetup.fast_mode = false


func _test_camera_range_and_toast(battlefield: BattlefieldUI) -> void:
	for button_name in ["PanLeft", "PanRight"]:
		_expect(
			battlefield._board_navigation_panel.find_child(button_name, true, false) is Button,
			"%s yatay kamera kontrolü bulunmalı" % button_name
		)
	battlefield._fit_board_view()
	battlefield._board_camera_center.x = -10000.0
	battlefield._clamp_board_camera()
	var minimum_x := battlefield._board_camera_center.x
	battlefield._board_camera_center.x = 10000.0
	battlefield._clamp_board_camera()
	var maximum_x := battlefield._board_camera_center.x
	_expect(maximum_x - minimum_x >= 379.0, "Kamera savaş alanını iki yana genişçe tarayabilmeli")

	battlefield.show_toast("Okunabilir savaş bildirimi", Color(0.95, 0.72, 0.28), "SAVAŞ GÜNLÜĞÜ")
	_expect(battlefield._toast_panel.visible, "Tematik bildirim plakası görünür olmalı")
	_expect(battlefield._toast_panel.size.x >= 490.0 and battlefield._toast_panel.size.y >= 64.0, "Bildirim plakası okunabilir bir yüzey sunmalı")
	_expect(battlefield._toast_kicker_label.text == "SAVAŞ GÜNLÜĞÜ", "Bildirim bağlam başlığını göstermeli")
	_expect(battlefield._toast_emblem_label.text == "◆", "Bildirim Darwine stilinde bir mühür taşımalı")
	_expect(battlefield._feedback_clip != null and battlefield._feedback_clip.clip_contents, "Savaş efektleri oyun alanına kırpılmalı")
	_expect(battlefield._feedback_layer.get_parent() == battlefield._feedback_clip, "Saldırı izi kırpılan savaş yüzeyinde çizilmeli")
	_expect(battlefield._feedback_layer.z_index == 0, "Efekt çocuğu kök UI sıralamasını aşmamalı")
	var maximum_slot_z := 0
	for node in battlefield.get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if slot:
			maximum_slot_z = maxi(maximum_slot_z, slot.z_index + CardSlot.CONTENT_Z_INDEX)
	_expect(battlefield._feedback_clip.z_index > maximum_slot_z, "Savaş efekt yüzeyi kartların önünde görünmeli")
	_expect(battlefield._feedback_clip.z_index < battlefield._phase_banner_panel.z_index, "Aşama bildirimi savaş efektlerinin üstünde kalmalı")
	_expect(battlefield._feedback_clip.z_index < battlefield._hand_dock.z_index, "El alanı savaş efektlerinin üstünde kalmalı")
	_expect(
		not battlefield.top_hud.visible and battlefield._get_top_playfield_reserved_height(root.size) == 0.0,
		"Kaldırılan üst HUD görünmemeli ve savaş alanında yer ayırmamalı"
	)
	_expect(battlefield._feedback_clip.z_index < battlefield._board_navigation_panel.z_index, "Kamera kontrolleri savaş efektlerinin üstünde kalmalı")
	var feedback_rect := battlefield._feedback_clip.get_global_rect()
	_expect(feedback_rect.position.distance_to(battlefield._board_view_rect.position) < 0.1, "Efekt kırpma alanı savaş kamerasıyla aynı noktadan başlamalı")
	_expect(feedback_rect.size.distance_to(battlefield._board_view_rect.size) < 0.1, "Efekt kırpma alanı savaş kamerasıyla aynı boyutta olmalı")
	_expect(
		battlefield._effect_panel != null
		and battlefield._effect_panel.get_parent() == battlefield._battlefield_world_objects
		and battlefield._effect_panel_own_mount.get_global_rect().intersects(battlefield._board_view_rect),
		"Etki Kartı bir HUD paneli yerine savaş alanındaki dünya nesnesi olarak görünmeli"
	)
	_expect(not feedback_rect.intersects(battlefield.hud.get_global_rect()), "Efekt alanı sağ HUD'a taşmamalı")
	_expect(not feedback_rect.intersects(battlefield._hand_dock_backdrop.get_global_rect()), "Efekt alanı ele taşmamalı")
	battlefield._reset_board_view()


func _test_target_language(battlefield: BattlefieldUI, active: int, opponent: int) -> void:
	var friendly_slot := _slot(battlefield, active, "Slot_F1")
	var enemy_slot := _slot(battlefield, opponent, "Slot_F1")
	var friendly := _place_hero(friendly_slot, active, "sovalye")
	var enemy := _place_hero(enemy_slot, opponent, "gladiator")
	await process_frame
	_test_feedback_camera_tracking(battlefield, friendly, enemy)
	var skill_card: BaseCard = await _add_hand_card(battlefield, active, "upgrades", "celik_kalkan")
	var skill := skill_card as UpgradeCard
	_expect(skill != null, "Hedef dili testi için Çelik Kalkan üretilebilmeli")
	if not skill:
		return
	await battlefield.request_effect_card_selection(skill)
	_expect(friendly_slot.get_combat_highlight() == CardSlot.CombatHighlight.SUPPORT_TARGET, "Geçerli dost hedef yeşil destek hedefi olmalı")
	_expect(friendly_slot._combat_label.text == "BECERİ VER", "Dost hedef üzerinde yapılacak eylem yazmalı")
	_expect(enemy_slot.get_combat_highlight() == CardSlot.CombatHighlight.INELIGIBLE, "Geçersiz düşman hedef soluk gösterilmeli")
	_expect(enemy.modulate.a < 0.70, "Geçersiz kart hedef seçiminde geri plana çekilmeli")
	_expect(friendly_slot._combat_badge.visible, "Geçerli hedef kart üstünde eylem plakası taşımalı")
	battlefield._clear_effect_selection()
	battlefield._remove_hand_card(skill)


func _test_feedback_camera_tracking(battlefield: BattlefieldUI, source: BaseCard, target: BaseCard) -> void:
	var original_center := battlefield._board_camera_center
	battlefield._play_attack_feedback(source, target, Color(1.0, 0.45, 0.24))
	var path_before := battlefield._feedback_layer.get_attack_path_points()
	battlefield._spawn_floating_feedback("KAMERA TESTİ", source, Color.WHITE)
	var floating_anchor := battlefield._feedback_clip.find_child("FloatingFeedbackAnchor", false, false) as Control
	_expect(floating_anchor != null, "Yüzen savaş yazısı kırpılan efekt yüzeyinde oluşmalı")
	var floating_before := floating_anchor.position if floating_anchor else Vector2.ZERO

	battlefield._board_camera_center.x = -10000.0
	battlefield._clamp_board_camera()
	var minimum_x := battlefield._board_camera_center.x
	battlefield._board_camera_center.x = 10000.0
	battlefield._clamp_board_camera()
	var maximum_x := battlefield._board_camera_center.x
	battlefield._board_camera_center = original_center
	battlefield._board_camera_center.x = (
		minimum_x
		if absf(original_center.x - minimum_x) > absf(original_center.x - maximum_x)
		else maximum_x
	)
	battlefield._apply_board_camera_transform()

	var path_after := battlefield._feedback_layer.get_attack_path_points()
	var expected_source := battlefield._to_feedback_point(battlefield._get_card_feedback_center(source))
	var expected_target := battlefield._to_feedback_point(battlefield._get_card_feedback_center(target))
	_expect((path_after.get("from", Vector2.ZERO) as Vector2).distance_to(expected_source) < 0.1, "Saldırı izi kamera kayınca saldıran karta yeniden bağlanmalı")
	_expect((path_after.get("to", Vector2.ZERO) as Vector2).distance_to(expected_target) < 0.1, "Saldırı izi kamera kayınca hedef karta yeniden bağlanmalı")
	_expect((path_after.get("from", Vector2.ZERO) as Vector2).distance_to(path_before.get("from", Vector2.ZERO)) > 1.0, "Saldırı izi kamera hareketini ekranda takip etmeli")
	if floating_anchor:
		_expect(floating_anchor.position.distance_to(expected_source) < 0.1, "Yüzen savaş yazısı kamera kayınca kaynak kartı takip etmeli")
		_expect(floating_anchor.position.distance_to(floating_before) > 1.0, "Yüzen savaş yazısı ekranda sabit kalmamalı")

	battlefield._feedback_layer.stop_all_feedback()
	battlefield._board_camera_center = original_center
	battlefield._apply_board_camera_transform()


func _test_catch_up_draw_and_hand_tactics(battlefield: BattlefieldUI, active: int) -> void:
	var hand := battlefield._get_hand_for_player(active)
	for card in battlefield.get_hand_cards(active):
		battlefield._remove_hand_card(card)
	_expect(battlefield.get_turn_start_draw_count(active, 1) == 3, "Boş el normal çekişle birlikte üç karta tamamlanmalı")
	_expect(battlefield.get_turn_start_draw_count(active, 0) == 0, "Çekişi kapatan modlar takviye çekişini de kapatmalı")
	await battlefield._on_turn_draw_requested(active, 1)
	_expect(battlefield.get_hand_cards(active).size() == 3, "Tur başı takviyesi boş eli gerçekten üç karta tamamlamalı")

	var redraw_card: BaseCard = await _add_hand_card(battlefield, active, "special_powers", "taktik_degisim")
	var redraw := redraw_card as SpecialPowerCard
	var redraw_target: BaseCard = await _add_hand_card(battlefield, active, "heroes", "okcu")
	var redraw_hand_before := battlefield.get_hand_cards(active).size()
	var redraw_deck_before: int = (battlefield._player_decks.get(active, []) as Array).size()
	var redraw_energy_before: int = battlefield.game_manager.get_available_energy(active)
	var redraw_result: Dictionary = await battlefield.resolve_hand_tactic(redraw, redraw_target)
	_expect(bool(redraw_result.get("success", false)), "Taktik Değişim seçilen el kartını değiştirebilmeli")
	_expect(int(redraw_result.get("cards_drawn", 0)) == 1, "Taktik Değişim tam bir yeni kart çekmeli")
	_expect(battlefield.get_hand_cards(active).size() == redraw_hand_before - 1, "Kart değiştirme yalnızca taktik kartını tüketmeli")
	_expect((battlefield._player_decks.get(active, []) as Array).size() == redraw_deck_before, "Değişen kart destenin altına dönmeli")
	_expect(battlefield.game_manager.get_available_energy(active) == redraw_energy_before - 1, "Taktik Değişim bir Enerji harcamalı")

	var draw_card: BaseCard = await _add_hand_card(battlefield, active, "special_powers", "ikmal_emri")
	var draw_tactic := draw_card as SpecialPowerCard
	var draw_hand_before := battlefield.get_hand_cards(active).size()
	var draw_deck_before: int = (battlefield._player_decks.get(active, []) as Array).size()
	var draw_energy_before: int = battlefield.game_manager.get_available_energy(active)
	var draw_result: Dictionary = await battlefield.resolve_hand_tactic(draw_tactic)
	_expect(bool(draw_result.get("success", false)), "İkmal Emri oynanabilmeli")
	_expect(int(draw_result.get("cards_drawn", 0)) == 2, "İkmal Emri iki kart çekmeli")
	_expect(battlefield.get_hand_cards(active).size() == draw_hand_before + 1, "İkmal Emri kendini tüketip ele net bir kart kazandırmalı")
	_expect((battlefield._player_decks.get(active, []) as Array).size() == draw_deck_before - 2, "İkmal Emri desteden iki fiziksel kart eksiltmeli")
	_expect(battlefield.game_manager.get_available_energy(active) == draw_energy_before - 2, "İkmal Emri iki Enerji harcamalı")


func _test_combat_target_focus(battlefield: BattlefieldUI, active: int, opponent: int) -> void:
	var manager := battlefield.game_manager as GameManager
	_expect(manager.advance_phase(active), "Hedef vurgusu için Çatışma aşamasına geçilebilmeli")
	var attacker_slot := _slot(battlefield, active, "Slot_F1")
	var target_slot := _slot(battlefield, opponent, "Slot_F1")
	var irrelevant_slot := _slot(battlefield, opponent, "Slot_F2")
	var attacker := attacker_slot.occupied_card as BaseCard
	var target := target_slot.occupied_card as BaseCard
	var irrelevant := _place_hero(irrelevant_slot, opponent, "troll")
	attacker.set_combat_state(BaseCard.CombatState.READY)
	battlefield._select_combat_attacker(attacker)
	_expect(attacker_slot.get_combat_highlight() == CardSlot.CombatHighlight.ATTACKER, "Saldıran kart altın SALDIRAN vurgusu taşımalı")
	_expect(target_slot.get_combat_highlight() == CardSlot.CombatHighlight.TARGET, "Yasal savaş hedefi kırmızı VUR vurgusu taşımalı")
	_expect(target_slot._combat_label.text == "VUR", "Yasal savaş hedefi eylemi açıkça yazmalı")
	_expect(irrelevant_slot.get_combat_highlight() == CardSlot.CombatHighlight.INELIGIBLE, "Yasal olmayan saha kartları geri plana çekilmeli")
	_expect(irrelevant.modulate.a < 0.70 and target.modulate.a > 0.95, "Yalnızca vurulabilir hedef tam görünür kalmalı")


func _add_hand_card(
	battlefield: BattlefieldUI,
	player_id: int,
	card_type: String,
	card_id: String
) -> BaseCard:
	var card_ref := {"card_type": card_type, "card_id": card_id}
	var card := battlefield._instantiate_card_from_ref(card_ref, player_id)
	if not card:
		return null
	card.set_meta("deck_ref", card_ref.duplicate(true))
	battlefield._get_hand_for_player(player_id).add_child(card)
	await process_frame
	return card


func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)
	return hero


func _slot(battlefield: BattlefieldUI, player_id: int, slot_name: String) -> CardSlot:
	return battlefield.get_node("Player%dZone/Grid/%s" % [player_id, slot_name]) as CardSlot


func _deck_contains(deck: Array, card_type: String, card_id: String) -> bool:
	for card_ref_variant in deck:
		var card_ref := card_ref_variant as Dictionary
		if str(card_ref.get("card_type", "")) == card_type and str(card_ref.get("card_id", "")) == card_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLAYABILITY_REFINEMENT_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PLAYABILITY_REFINEMENT_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
