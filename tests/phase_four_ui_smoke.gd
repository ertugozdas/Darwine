extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	MatchSetup.configure_local(40404)
	MatchSetup.fast_mode = true
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
	var active_player := manager.first_player_id
	var opponent := manager.get_opponent_id(active_player)
	_expect(manager.confirm_mulligan(active_player), "İlk oyuncu mulliganı onaylanmalı")
	_expect(manager.confirm_mulligan(opponent), "İkinci oyuncu mulliganı onaylanmalı")
	await process_frame

	var friendly_slot := _get_slot(battlefield, active_player, "Slot_F1")
	var enemy_slot := _get_slot(battlefield, opponent, "Slot_F1")
	var friendly := _place_hero(friendly_slot, active_player, 10)
	var enemy := _place_hero(enemy_slot, opponent, 10)
	var lightning := _make_spell(battlefield, active_player, "yildirim")
	await process_frame
	manager.player_current_energy[active_player] = 10
	battlefield.sync_player_energy(active_player)

	_click_spell(lightning)
	_expect(battlefield._selected_effect_card == lightning, "Büyü tıklanınca hedefleme modu başlamalı")
	_expect(enemy_slot.get_combat_highlight() == CardSlot.CombatHighlight.TARGET, "Yasal düşman hedefi vurgulanmalı")
	_expect(friendly_slot.get_combat_highlight() == CardSlot.CombatHighlight.INELIGIBLE, "Geçersiz dost hedefi geri plana çekilmeli")

	var energy_before_invalid := manager.get_available_energy(active_player)
	var resolved_lightning_cost := EffectResolver.get_effect_action_cost(
		manager,
		lightning,
		"special_power",
		lightning.energy_cost
	)
	battlefield.request_effect_target_selection(friendly_slot)
	_expect(manager.get_available_energy(active_player) == energy_before_invalid, "UI'da geçersiz Büyü hedefi Enerji harcatmamalı")
	_expect(battlefield._selected_effect_card == lightning, "Geçersiz hedef sonrası hedefleme modu açık kalmalı")

	battlefield.request_effect_target_selection(enemy_slot)
	await process_frame
	_expect(enemy.health == 5, "UI hedeflemesi Yıldırımın 5 hasarını uygulamalı")
	_expect(
		manager.get_available_energy(active_player) == energy_before_invalid - resolved_lightning_cost,
		"Geçerli Büyü Etki Kartı indirimleri dahil merkezi çözücünün maliyetini harcamalı"
	)
	_expect(battlefield._selected_effect_card == null, "Büyü çözülünce hedefleme modu kapanmalı")
	_expect(enemy_slot.get_combat_highlight() == CardSlot.CombatHighlight.NONE, "Büyü çözülünce hedef vurgusu temizlenmeli")
	_expect(not is_instance_valid(lightning), "Çözülen Büyü ıskartaya gitmeli")

	var holy_light := _make_spell(battlefield, active_player, "kutsal_isik")
	await process_frame
	var energy_before_no_target := manager.get_available_energy(active_player)
	_click_spell(holy_light)
	_expect(battlefield._selected_effect_card == null, "Yasal hedefi olmayan Büyü hedefleme moduna girmemeli")
	_expect(manager.get_available_energy(active_player) == energy_before_no_target, "Yasal hedefi olmayan Büyü Enerji harcatmamalı")
	_expect(friendly.health == friendly.max_health, "Hedef yokluğu gerçekten tam canlı dosttan kaynaklanmalı")

	battlefield.queue_free()
	await process_frame
	MatchSetup.fast_mode = false
	_finish()

func _get_slot(battlefield: BattlefieldUI, player_id: int, slot_name: String) -> CardSlot:
	return battlefield.get_node("Player%dZone/Grid/%s" % [player_id, slot_name]) as CardSlot

func _place_hero(slot: CardSlot, owner_id: int, health: int) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.attack = 2
	hero.armor = 0
	hero.health = health
	slot.add_child(hero)
	return hero

func _make_spell(parent: Node, owner_id: int, card_id: String) -> SpecialPowerCard:
	var spell := SpecialPowerCard.new()
	spell.owner_id = owner_id
	spell.card_id = card_id
	parent.add_child(spell)
	return spell

func _click_spell(spell: SpecialPowerCard) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	spell._gui_input(click)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_FOUR_UI_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PHASE_FOUR_UI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
