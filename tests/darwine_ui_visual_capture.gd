extends SceneTree

const ATTACK_OUTPUT := "/tmp/darwine_attack_1280x720.png"
const PANNED_ATTACK_OUTPUT := "/tmp/darwine_attack_panned_1280x720.png"
const GAME_OVER_OUTPUT := "/tmp/darwine_game_over_1280x720.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("DARWINE_UI_VISUAL_CAPTURE_SKIPPED")
		quit(0)
		return
	MatchSetup.configure_local(9090)
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
	_place_hero(target_slot, enemy, "gladiator")
	await process_frame
	attacker.set_combat_state(BaseCard.CombatState.READY)
	manager.advance_phase(active)
	battlefield.resolve_attack_with_feedback(attacker, target_slot)
	await create_timer(0.34).timeout
	if not _save(viewport, ATTACK_OUTPUT):
		quit(1)
		return
	battlefield._nudge_board_horizontal(1.0)
	await create_timer(0.24).timeout
	if not _save(viewport, PANNED_ATTACK_OUTPUT):
		quit(1)
		return
	while battlefield._combat_sequence_active:
		await process_frame

	battlefield._on_game_over(active)
	await process_frame
	if not _save(viewport, GAME_OVER_OUTPUT):
		quit(1)
		return
	print("DARWINE_UI_VISUAL_CAPTURE_OK: %s • %s • %s" % [ATTACK_OUTPUT, PANNED_ATTACK_OUTPUT, GAME_OVER_OUTPUT])
	viewport.queue_free()
	await process_frame
	quit(0)


func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)
	return hero


func _save(viewport: SubViewport, output_path: String) -> bool:
	RenderingServer.force_draw(true, 0.0)
	var image := viewport.get_texture().get_image()
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		push_error("1280×720 görüntü alınamadı: %s" % output_path)
		return false
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Görüntü kaydedilemedi: %s" % error_string(save_error))
		return false
	return true
