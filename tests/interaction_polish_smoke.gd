extends SceneTree

class ForcedDropHero:
	extends HeroCard
	var forced_drop_slot: CardSlot = null

	func _get_slot_under_mouse() -> CardSlot:
		return forced_drop_slot

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	root.size = Vector2i(1280, 720)
	MatchSetup.configure_local(180726)
	MatchSetup.fast_mode = true

	var packed := load("res://battlefield.tscn") as PackedScene
	_expect(packed != null, "Etkileşim testi için battlefield.tscn yüklenebilmeli")
	if not packed:
		_finish()
		return

	var battlefield := packed.instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	while battlefield._is_dealing_initial_hands:
		await process_frame
	battlefield._apply_responsive_layout()
	await process_frame

	var manager := battlefield.game_manager as GameManager
	manager.cards_drawn_per_turn = 0
	var active := manager.first_player_id
	var opponent := manager.get_opponent_id(active)
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	var mulligan_card := battlefield.get_hand_cards(active)[0] as BaseCard
	battlefield.request_hand_card_selection(mulligan_card)
	_expect(battlefield._phase_selected_cards == [mulligan_card], "Mulligan kartı tıklamayla seçilebilmeli")
	battlefield._unhandled_input(cancel_event)
	_expect(battlefield._phase_selected_cards.is_empty(), "ESC mulligan/atılacak kart seçimini temizlemeli")
	_expect(not battlefield._pause_menu.is_open(), "Mulligan seçimi varken ESC duraklatma menüsünü açmamalı")
	_expect(manager.confirm_mulligan(active), "Aktif oyuncu başlangıç elini onaylayabilmeli")
	_expect(manager.confirm_mulligan(opponent), "Rakip başlangıç elini onaylayabilmeli")
	await process_frame
	manager.player_current_energy[active] = 10
	manager.player_temporary_energy[active] = 0
	battlefield.sync_player_energy(active)

	var hero := await _add_hand_card(battlefield, active, "heroes", "sovalye") as HeroCard
	_expect(hero != null, "Tıkla-yerleştir testi için Şövalye oluşturulabilmeli")
	if not hero:
		await _cleanup(battlefield)
		_finish()
		return

	battlefield._apply_responsive_layout()
	await process_frame
	_expect(hero.drag_start_distance >= 8.0, "Tıklama ile sürükleme arasında yanlış hamleyi önleyen bir eşik olmalı")
	_click_card(hero)
	_expect(battlefield._selected_deployment_card == hero, "Eldeki Kahramana tıklamak yerleştirme modunu açmalı")
	_expect(not battlefield._legal_deployment_targets.is_empty(), "Tıklanan Kahraman için yasal yuvalar hesaplanmalı")
	_expect(
		"YERLEŞTİRME YUVASI SEÇ" in battlefield._phase_label.text,
		"Aşama kılavuzu seçilen kart için sonraki adımı açıkça söylemeli"
	)

	var first_target := battlefield._legal_deployment_targets[0] as CardSlot
	_expect(
		first_target.get_combat_highlight() == CardSlot.CombatHighlight.MOVE_TARGET,
		"Yasal yerleştirme yuvası mavi hareket/yerleştirme diliyle vurgulanmalı"
	)
	_expect(
		first_target.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
		"Yasal hedef yuvası tıklanabilir imleç göstermeli"
	)

	var escape_is_bound := false
	for binding in InputMap.action_get_events("ui_cancel"):
		if binding is InputEventKey and (
			(binding as InputEventKey).keycode == KEY_ESCAPE
			or (binding as InputEventKey).physical_keycode == KEY_ESCAPE
		):
			escape_is_bound = true
			break
	_expect(escape_is_bound, "ESC, ui_cancel eylemine bağlı olmalı")
	battlefield._unhandled_input(cancel_event)
	_expect(battlefield._selected_deployment_card == null, "ESC aktif yerleştirme seçimini iptal etmeli")
	_expect(not battlefield._pause_menu.is_open(), "ESC önce seçimi iptal etmeli; duraklatma menüsünü açmamalı")
	_expect(first_target.get_combat_highlight() == CardSlot.CombatHighlight.NONE, "İptal edilen hedef vurgusu temizlenmeli")

	_click_card(hero)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	battlefield._input(right_click)
	_expect(battlefield._selected_deployment_card == null, "Sağ tık aktif yerleştirme seçimini iptal etmeli")
	hero._start_dragging()
	_expect(hero.is_dragging, "Sürükleme eşiği aşıldığında kart gerçek sürükleme moduna girmeli")
	battlefield._input(right_click)
	_expect(not hero.is_dragging and hero._is_returning, "Sağ tık aktif sürüklemeyi hedefe bırakmadan geri çevirmeli")
	var return_deadline := Time.get_ticks_msec() + 1500
	while hero._is_returning and Time.get_ticks_msec() < return_deadline:
		await process_frame
	_expect(not hero._is_returning, "İptal edilen sürükleme sınırlı sürede ele dönmeli")
	_expect(hero.get_parent() == battlefield._get_hand_for_player(active), "İptal edilen sürükleme kartı aynı ele geri bağlamalı")
	_click_card(hero)
	_expect(battlefield._selected_deployment_card == hero, "Kart iptalden sonra yeniden seçilebilmeli")
	var target := battlefield._legal_deployment_targets[0] as CardSlot
	var energy_before := manager.get_available_energy(active)
	var result := battlefield.request_deployment_target_selection(target)
	_expect(bool(result.get("success", false)), "Tıklanan yasal yuva kartı yerleştirebilmeli")
	_expect(hero.current_slot == target and target.occupied_card == hero, "Kart seçilen yuvaya bağlanmalı")
	_expect(
		manager.get_available_energy(active) == energy_before - int(result.get("energy_spent", -1)),
		"Tıkla-yerleştir merkezi çözücünün hesapladığı Enerjiyi harcamalı"
	)
	_expect(battlefield._selected_deployment_card == null, "Başarılı yerleştirme hedefleme modunu kapatmalı")
	_expect(hero._is_snapping, "Yerleştirilen kart elden sahaya akıcı biçimde oturmalı")
	_expect(battlefield._feedback_audio.last_event_id == "deploy", "Yerleştirme kendine özgü ses geri bildirimi çalmalı")
	_expect(hero.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Yerleşme animasyonu sırasında kart çift giriş almamalı")
	var snap_deadline := Time.get_ticks_msec() + 1500
	while hero._is_snapping and Time.get_ticks_msec() < snap_deadline:
		await process_frame
	_expect(not hero._is_snapping, "Kart yerleşme animasyonunu sınırlı sürede tamamlamalı")
	_expect(hero.mouse_filter == Control.MOUSE_FILTER_PASS, "Sahadaki kart inceleme ve eylem tıklamalarını kabul etmeli")

	var drag_hero := ForcedDropHero.new()
	drag_hero.name = "ForcedDragHero"
	drag_hero.owner_id = active
	drag_hero.card_id = "sovalye"
	drag_hero.is_draggable = true
	drag_hero.set_meta("deck_ref", {"card_type": "heroes", "card_id": "sovalye"})
	battlefield._get_hand_for_player(active).add_child(drag_hero)
	battlefield._register_preview_card(drag_hero)
	await process_frame
	var drag_target: CardSlot = null
	for candidate in battlefield.get_board_slots(active):
		if candidate.can_accept_card(drag_hero):
			drag_target = candidate
			break
	_expect(drag_target != null, "Sürükle-bırak testi için ikinci bir yasal yuva bulunmalı")
	if drag_target:
		drag_hero.forced_drop_slot = drag_target
		var drag_cost := EffectResolver.get_effect_action_cost(
			manager,
			drag_hero,
			"hero",
			drag_hero.energy_cost
		)
		var drag_energy_before := manager.get_available_energy(active)
		drag_hero._start_dragging()
		_expect(drag_hero.is_dragging, "Kart sürükleme akışı başlatılabilmeli")
		drag_hero._stop_dragging()
		_expect(drag_hero.current_slot == drag_target, "Sürüklenen kart bırakılan yuvaya bağlanmalı")
		_expect(
			manager.get_available_energy(active) == drag_energy_before - drag_cost,
			"Sürükle-bırak da tıkla-yerleştir ile aynı merkezi maliyeti kullanmalı"
		)
		_expect(drag_hero._is_snapping, "Sürüklenen kart hedef yuvaya akıcı biçimde oturmalı")

	var phase_before := manager.current_phase
	var advance_event := InputEventKey.new()
	advance_event.keycode = KEY_SPACE
	advance_event.pressed = true
	battlefield._unhandled_input(advance_event)
	_expect(phase_before == GameManager.TurnPhase.PREPARATION, "Space testi Hazırlık aşamasından başlamalı")
	_expect(manager.current_phase == GameManager.TurnPhase.COMBAT, "Space ana aşama düğmesiyle aynı biçimde Çatışmaya geçmeli")

	MatchSetup.fast_mode = false
	var shake_started := battlefield._play_board_impact_shake(BattlefieldFeedbackLayer.IMPACT_CRITICAL, 8.0)
	_expect(shake_started, "Kritik darbe savaş alanı kamerasında kısa bir tepki başlatmalı")
	_expect(battlefield.impact_shake_count == 1, "Kamera darbesi telemetri sayacına işlenmeli")
	_expect(
		battlefield.last_impact_shake_kind == BattlefieldFeedbackLayer.IMPACT_CRITICAL,
		"Kamera darbesi kritik vuruş profilini korumalı"
	)
	await create_timer(BattlefieldUI.BOARD_IMPACT_SHAKE_SECONDS + 0.10).timeout
	_expect(battlefield._board_impact_offset.length() < 0.05, "Darbe kamerası kısa animasyondan sonra tam merkezine dönmeli")

	await _cleanup(battlefield)
	_finish()


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
	card.is_draggable = true
	battlefield._get_hand_for_player(player_id).add_child(card)
	battlefield._register_preview_card(card)
	await process_frame
	return card


func _click_card(card: BaseCard) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	card._gui_input(press)
	_expect(card._pointer_press_pending, "Basış kartı hemen sürüklemek yerine tıklama kararını beklemeli")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	card._gui_input(release)


func _cleanup(battlefield: BattlefieldUI) -> void:
	MatchSetup.fast_mode = true
	current_scene = null
	battlefield.queue_free()
	await process_frame
	MatchSetup.fast_mode = false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("INTERACTION_POLISH_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("INTERACTION_POLISH_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
