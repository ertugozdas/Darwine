extends SceneTree

const CRITICAL_OUTPUT := "/tmp/tdm_combat_critical_1280x720.png"
const BLOCK_OUTPUT := "/tmp/tdm_combat_block_1280x720.png"
const ARMOR_OUTPUT := "/tmp/tdm_combat_armor_break_1280x720.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("COMBAT_FEEL_VISUAL_CAPTURE_SKIPPED")
		quit(0)
		return
	MatchSetup.configure_local(7810)
	MatchSetup.fast_mode = false
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	viewport.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame
	battlefield._apply_responsive_layout()
	if battlefield._tutorial_overlay:
		battlefield._tutorial_overlay.visible = false
		battlefield._refresh_phase_ui()
	var manager := battlefield.game_manager as GameManager
	manager.cards_drawn_per_turn = 0
	var active := manager.first_player_id
	var enemy := manager.get_opponent_id(active)
	manager.confirm_mulligan(active)
	manager.confirm_mulligan(enemy)
	await process_frame
	var attacker_slot := battlefield.get_node("Player%dZone/Grid/Slot_F2" % active) as CardSlot
	var target_slot := battlefield.get_node("Player%dZone/Grid/Slot_F2" % enemy) as CardSlot
	var attacker := _place_hero(attacker_slot, active, "sovalye")
	var target := _place_hero(target_slot, enemy, "gladiator")
	await process_frame
	battlefield._fit_board_view()
	await process_frame
	manager.advance_phase(active)

	# Low health turns the first strike into a visibly decisive critical hit.
	target.armor = 0
	target.health = 2
	attacker.set_combat_state(BaseCard.CombatState.READY)
	battlefield.resolve_attack_with_feedback(attacker, target_slot)
	await create_timer(1.30).timeout
	if not _save(viewport, CRITICAL_OUTPUT):
		quit(1)
		return
	while battlefield._combat_sequence_active:
		await process_frame

	# Full protection demonstrates the blue shield response without changing
	# combat rules or requiring a second bespoke animation path.
	target = _place_hero(target_slot, enemy, "gladiator")
	target.armor = 0
	target.apply_status(EffectResolver.STATUS_PROTECTED, 8, 1)
	attacker.set_combat_state(BaseCard.CombatState.READY)
	battlefield.resolve_attack_with_feedback(attacker, target_slot)
	await create_timer(1.30).timeout
	if not _save(viewport, BLOCK_OUTPUT):
		quit(1)
		return
	while battlefield._combat_sequence_active:
		await process_frame

	# A final strike lands entirely on armour to expose cracks and metal shards.
	target.status_effects[EffectResolver.STATUS_PROTECTED] = 0
	target.armor = 6
	target.health = target.get_max_health()
	attacker.set_combat_state(BaseCard.CombatState.READY)
	battlefield.resolve_attack_with_feedback(attacker, target_slot)
	await create_timer(1.30).timeout
	if not _save(viewport, ARMOR_OUTPUT):
		quit(1)
		return
	while battlefield._combat_sequence_active:
		await process_frame

	print("COMBAT_FEEL_VISUAL_CAPTURE_OK: %s • %s • %s" % [CRITICAL_OUTPUT, BLOCK_OUTPUT, ARMOR_OUTPUT])
	viewport.queue_free()
	await process_frame
	quit(0)


func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)
	return hero


func _save(viewport: SubViewport, path: String) -> bool:
	RenderingServer.force_draw(true, 0.0)
	var image := viewport.get_texture().get_image()
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		push_error("Savaş hissiyatı görüntüsü alınamadı: %s" % path)
		return false
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("Savaş hissiyatı görüntüsü kaydedilemedi: %s" % error_string(save_error))
		return false
	return true
