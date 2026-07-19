extends SceneTree

const SELECTION_OUTPUT := "/tmp/tdm_interaction_selection_1280x720.png"
const DEPLOYED_OUTPUT := "/tmp/tdm_interaction_deployed_1280x720.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("INTERACTION_POLISH_VISUAL_CAPTURE_SKIPPED: etkin görüntü sürücüsü gerekiyor")
		quit(0)
		return

	TranslationServer.set_locale("tr")
	MatchSetup.configure_local(180726)
	MatchSetup.fast_mode = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	viewport.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame
	for _frame in range(3):
		await process_frame
	if battlefield._tutorial_overlay:
		battlefield._tutorial_overlay.visible = false
	var manager := battlefield.game_manager as GameManager
	manager.call("_reset_match_state")
	if not manager.begin_effect_selection(1):
		push_error("Görsel yakalama için Etki Kartı seçimi başlatılamadı")
		quit(1)
		return
	await process_frame
	battlefield.call("_reveal_effect_offers")
	await process_frame
	var first_offer := manager.get_effect_offer(1)
	if first_offer.is_empty():
		push_error("Görsel yakalama için birinci Etki Kartı teklifi üretilemedi")
		quit(1)
		return
	battlefield.call("_on_effect_offer_pressed", first_offer[0])
	battlefield.call("_confirm_effect_offer_selection")
	await process_frame
	var second_offer := manager.get_effect_offer(2)
	if second_offer.is_empty() or not battlefield.resolve_effect_card_choice_for_player(2, second_offer[0]):
		push_error("Görsel yakalama için ikinci Etki Kartı seçimi tamamlanamadı")
		quit(1)
		return
	await process_frame
	manager.cards_drawn_per_turn = 0
	var active := manager.first_player_id
	var opponent := manager.get_opponent_id(active)
	var active_confirmed := manager.confirm_mulligan(active)
	var opponent_confirmed := manager.confirm_mulligan(opponent)
	if not active_confirmed or not opponent_confirmed:
		push_error(
			"Görsel yakalama için başlangıç eli onaylanamadı: active=%s opponent=%s phase=%d"
			% [active_confirmed, opponent_confirmed, int(manager.current_phase)]
		)
		quit(1)
		return
	await process_frame
	manager.player_current_energy[active] = 10
	manager.player_temporary_energy[active] = 0
	battlefield.sync_player_energy(active)

	var card_ref := {"card_type": "heroes", "card_id": "sovalye"}
	var hero := battlefield._instantiate_card_from_ref(card_ref, active) as HeroCard
	if not hero:
		push_error("Görsel yakalama için Şövalye oluşturulamadı")
		quit(1)
		return
	hero.set_meta("deck_ref", card_ref.duplicate(true))
	hero.is_draggable = true
	battlefield._get_hand_for_player(active).add_child(hero)
	battlefield._register_preview_card(hero)
	battlefield._apply_responsive_layout()
	for _frame in range(4):
		await process_frame

	MatchSetup.fast_mode = false
	battlefield.request_hand_card_deployment_selection(hero)
	for _frame in range(8):
		await process_frame
	if battlefield._legal_deployment_targets.is_empty():
		push_error("Görsel yakalama için yerleştirme hedefi üretilemedi")
		quit(1)
		return
	if not _save(viewport, SELECTION_OUTPUT):
		quit(1)
		return

	var target := battlefield._legal_deployment_targets[0] as CardSlot
	var result := battlefield.request_deployment_target_selection(target)
	if not bool(result.get("success", false)):
		push_error("Görsel yakalamada kart yerleştirilemedi: %s" % str(result.get("error", "bilinmeyen hata")))
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 1600
	while hero._is_snapping and Time.get_ticks_msec() < deadline:
		await process_frame
	for _frame in range(4):
		await process_frame
	if not _save(viewport, DEPLOYED_OUTPUT):
		quit(1)
		return

	print("INTERACTION_POLISH_VISUAL_CAPTURE_OK: %s • %s" % [SELECTION_OUTPUT, DEPLOYED_OUTPUT])
	MatchSetup.fast_mode = true
	viewport.queue_free()
	await process_frame
	MatchSetup.fast_mode = false
	quit(0)


func _save(viewport: SubViewport, output_path: String) -> bool:
	RenderingServer.force_draw(true, 0.0)
	var image := viewport.get_texture().get_image()
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		push_error("1280×720 etkileşim görüntüsü alınamadı: %s" % output_path)
		return false
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Etkileşim görüntüsü kaydedilemedi: %s" % error_string(save_error))
		return false
	return true
