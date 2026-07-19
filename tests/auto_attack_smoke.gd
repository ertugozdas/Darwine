extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	MatchSetup.configure_local(9042)
	MatchSetup.fast_mode = true
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame

	var manager := battlefield.game_manager as GameManager
	manager.set("_turn_timer_running", false)
	manager.is_match_started = true
	manager.active_player_id = 1
	manager.current_phase = GameManager.TurnPhase.COMBAT
	if battlefield._tutorial_overlay:
		battlefield._tutorial_overlay.visible = false

	var checkbox := battlefield._auto_attack_checkbox as CheckBox
	_expect(checkbox != null, "HUD üzerinde Otomatik Saldırı tiki bulunmalı")
	_expect(checkbox != null and not checkbox.button_pressed, "Otomatik Saldırı maç başında kapalı olmalı")
	_expect(
		battlefield._auto_attack_panel != null
		and battlefield._auto_attack_panel.visible
		and battlefield.hud.get_global_rect().encloses(battlefield._auto_attack_panel.get_global_rect()),
		"Otomatik Saldırı tiki sağ HUD sınırları içinde görünmeli"
	)

	var attackers: Array[HeroCard] = []
	var defenders: Array[HeroCard] = []
	for lane_index in range(3):
		var attacker_slot := battlefield.get_lane_slots(1, lane_index)[0]
		var defender_slot := battlefield.get_lane_slots(2, lane_index)[0]
		var attacker := _place_hero(attacker_slot, 1, 2, 8, "Otomatik Saldırgan %d" % lane_index)
		var defender := _place_hero(defender_slot, 2, 1, 12, "Koridor Savunması %d" % lane_index)
		attackers.append(attacker)
		defenders.append(defender)
	await process_frame
	for attacker in attackers:
		attacker.set_combat_state(BaseCard.CombatState.READY)

	var attacked_lanes: Array[int] = []
	manager.attack_declared.connect(func(attacker: BaseCard, _target: BaseCard):
		if attacker and attacker.current_slot:
			attacked_lanes.append(int(attacker.current_slot.lane_id))
	)
	manager.phase_changed.emit(GameManager.TurnPhase.COMBAT)
	await process_frame
	_expect(attacked_lanes.is_empty(), "Tik kapalıyken koridorlar kendiliğinden saldırmamalı")

	checkbox.set_pressed_no_signal(true)
	checkbox.toggled.emit(true)
	await _wait_for_auto_attack(battlefield)
	_expect(attacked_lanes == [0, 1, 2], "Tik Çatışmada açılınca koridorlar Sol, Orta, Sağ sırasıyla saldırmalı")
	for index in range(3):
		_expect(not attackers[index].is_ready_for_combat(), "Koridor %d saldırganı saldırıdan sonra Tükenmiş olmalı" % index)
		_expect(defenders[index].health == 10, "Koridor %d hedefi otomatik saldırı hasarını almalı" % index)

	# Açık tik Hazırlıkta saldırmamalı; Çatışmaya geçildiği anda yeniden çalışmalı.
	checkbox.set_pressed_no_signal(false)
	checkbox.toggled.emit(false)
	manager.current_phase = GameManager.TurnPhase.PREPARATION
	manager.phase_changed.emit(GameManager.TurnPhase.PREPARATION)
	for index in range(3):
		attackers[index].set_combat_state(BaseCard.CombatState.READY)
		defenders[index].health = 12
	attacked_lanes.clear()
	checkbox.set_pressed_no_signal(true)
	checkbox.toggled.emit(true)
	await process_frame
	_expect(attacked_lanes.is_empty(), "Tik Hazırlıkta açılınca saldırı Çatışmayı beklemeli")
	_expect(manager.advance_phase(1), "Hazırlıktan Çatışmaya geçilebilmeli")
	await _wait_for_auto_attack(battlefield)
	_expect(attacked_lanes == [0, 1, 2], "Açık tik Çatışma başında üç koridoru otomatik çözmeli")

	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := root.get_viewport().get_texture().get_image()
		_expect(screenshot != null and not screenshot.is_empty(), "Otomatik Saldırı görseli yakalanabilmeli")
		if screenshot != null and not screenshot.is_empty():
			_expect(screenshot.save_png("/tmp/tdm_auto_attack.png") == OK, "Otomatik Saldırı görseli kaydedilebilmeli")

	# Kapatılan tik yeni bir otomatik seri başlatmamalı.
	checkbox.set_pressed_no_signal(false)
	checkbox.toggled.emit(false)
	for index in range(3):
		attackers[index].set_combat_state(BaseCard.CombatState.READY)
		defenders[index].health = 12
	attacked_lanes.clear()
	battlefield.call_deferred("_try_start_auto_attack")
	await process_frame
	_expect(attacked_lanes.is_empty(), "Tik kapatılınca otomatik saldırı durmalı")

	# Normal animasyon sırasında kapatmak mevcut vuruşu tamamlar, kalan koridorları durdurur.
	MatchSetup.fast_mode = false
	checkbox.set_pressed_no_signal(true)
	checkbox.toggled.emit(true)
	await process_frame
	_expect(battlefield._auto_attack_running, "Tik açılınca animasyonlu otomatik seri başlamalı")
	checkbox.set_pressed_no_signal(false)
	checkbox.toggled.emit(false)
	await _wait_for_auto_attack(battlefield)
	_expect(attacked_lanes == [0], "Tik seri sırasında kapatılınca yalnız başlamış saldırı tamamlanmalı")
	_expect(not attackers[0].is_ready_for_combat(), "Başlamış saldırı tamamlanıp saldırganı Tüketmeli")
	_expect(attackers[1].is_ready_for_combat() and attackers[2].is_ready_for_combat(), "Kapatılan seri kalan koridorları Hazır bırakmalı")

	battlefield.queue_free()
	await process_frame
	MatchSetup.configure_local(1)
	_finish()


func _wait_for_auto_attack(battlefield: BattlefieldUI) -> void:
	await process_frame
	var deadline := Time.get_ticks_msec() + 5000
	while battlefield._auto_attack_running and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not battlefield._auto_attack_running, "Otomatik saldırı serisi zamanında tamamlanmalı")


func _place_hero(
	slot: CardSlot,
	owner_id: int,
	attack: int,
	health: int,
	card_name: String
) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.attack = attack
	hero.armor = 0
	hero.health = health
	hero.card_name = card_name
	slot.add_child(hero)
	return hero


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AUTO_ATTACK_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("AUTO_ATTACK_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
