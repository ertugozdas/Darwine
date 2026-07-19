extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var battlefield_scene := load("res://battlefield.tscn") as PackedScene
	_expect(battlefield_scene != null, "battlefield.tscn yüklenemedi")
	if not battlefield_scene:
		_finish()
		return

	var battlefield := battlefield_scene.instantiate() as BattlefieldUI
	root.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame

	var manager := battlefield.game_manager as GameManager
	manager.cards_drawn_per_turn = 0
	var first_player := manager.first_player_id
	var second_player := manager.get_opponent_id(first_player)
	_expect(manager.confirm_mulligan(first_player), "İlk oyuncu mulliganı onaylanmalı")
	_expect(manager.confirm_mulligan(second_player), "İkinci oyuncu mulliganı onaylanmalı")
	await process_frame

	var attacker_slot := _get_slot(battlefield, first_player, "Slot_F1")
	var defender_slot := _get_slot(battlefield, second_player, "Slot_F1")
	var attacker := _place_hero(attacker_slot, first_player, 5, 0, 6, "UI Saldırganı")
	var defender := _place_hero(defender_slot, second_player, 2, 1, 6, "UI Savunması")
	await process_frame
	_expect(not attacker.is_ready_for_combat(), "Yeni oynanan Kahraman Tükenmiş başlamalı")
	attacker.set_combat_state(BaseCard.CombatState.READY)
	_expect(manager.advance_phase(first_player), "UI testi Çatışma aşamasına geçmeli")

	_click_slot(attacker_slot)
	_expect(battlefield._selected_attacker == attacker, "Tıklanan Hazır Kahraman saldırgan seçilmeli")
	_expect(attacker_slot.get_combat_highlight() == CardSlot.CombatHighlight.ATTACKER, "Saldırgan yuvası vurgulanmalı")
	_expect(defender_slot.get_combat_highlight() == CardSlot.CombatHighlight.TARGET, "Yasal hedef yuvası vurgulanmalı")

	_click_slot(defender_slot)
	while battlefield._combat_sequence_active:
		await process_frame
	_expect(defender.armor == 0 and defender.health == 2, "UI saldırısı Zırh ve Can hasarını uygulamalı")
	_expect(not attacker.is_ready_for_combat(), "UI saldırısından sonra Kahraman Tükenmiş olmalı")
	_expect(battlefield._selected_attacker == null, "Saldırı çözülünce seçim temizlenmeli")

	var siege_slot := _get_slot(battlefield, first_player, "Slot_F2")
	var siege_attacker := _place_hero(
		siege_slot,
		first_player,
		GameRules.HEADQUARTERS_HEALTH + GameRules.SECOND_PLAYER_HQ_PROTECTION,
		0,
		5,
		"Merkez Kıran"
	)
	await process_frame
	siege_attacker.set_combat_state(BaseCard.CombatState.READY)
	_click_slot(siege_slot)
	var enemy_hq_slot := battlefield.get_hq_slot(second_player)
	_expect(
		(enemy_hq_slot.occupied_card as BaseCard).get_status_amount(EffectResolver.STATUS_PROTECTED) == GameRules.SECOND_PLAYER_HQ_PROTECTION,
		"İkinci oyuncu Merkezi ilk darbede Açılış Kalkanı taşımalı"
	)
	_expect(enemy_hq_slot.get_combat_highlight() == CardSlot.CombatHighlight.TARGET, "Açık koridorda Merkez yasal hedef olarak vurgulanmalı")
	_click_slot(enemy_hq_slot)
	while battlefield._combat_sequence_active:
		await process_frame
	_expect(not manager.is_game_active, "Merkez sıfır Can olduğunda maç kapanmalı")
	_expect(battlefield.game_over_panel.visible, "Gerçek savaş sonucu oyun sonu ekranını açmalı")
	_expect(battlefield.end_turn_button.disabled, "Oyun sonu ekranında faz düğmesi kilitlenmeli")

	battlefield.queue_free()
	await process_frame
	_finish()

func _get_slot(battlefield: BattlefieldUI, player_id: int, slot_name: String) -> CardSlot:
	return battlefield.get_node("Player%dZone/Grid/%s" % [player_id, slot_name]) as CardSlot

func _click_slot(slot: CardSlot) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	slot.gui_input.emit(click)

func _place_hero(slot: CardSlot, owner_id: int, attack: int, armor: int, health: int, card_name: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.attack = attack
	hero.armor = armor
	hero.health = health
	hero.card_name = card_name
	slot.add_child(hero)
	return hero

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_THREE_UI_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PHASE_THREE_UI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
