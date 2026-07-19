extends SceneTree

const OUTPUT_PATH := "/tmp/tdm_dominion_battlefield_1280x720.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("DOMINION_VISUAL_CAPTURE_SKIPPED: etkin görüntü sürücüsü gerekiyor")
		quit(0)
		return
	MatchSetup.configure_local(12101)
	MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	viewport.add_child(battlefield)
	for _frame in range(5):
		await process_frame

	var effect_overlay := battlefield.find_child("EffectSelectionOverlay", true, false) as Control
	if effect_overlay:
		effect_overlay.visible = false
	var tutorial := battlefield.find_child("FirstMatchTutorial", true, false) as Control
	if tutorial:
		tutorial.visible = false
	_place_card(battlefield, 1, "Slot_F1", "heroes", "okcu")
	_place_card(battlefield, 1, "Slot_S1", "settlements", "okcu_kulesi")
	_place_card(battlefield, 2, "Slot_F1", "heroes", "ayaz_muhafizi")
	_place_card(battlefield, 1, "Slot_F2", "heroes", "peri")
	_place_card(battlefield, 2, "Slot_F2", "heroes", "run_muhafizi")
	_place_card(battlefield, 1, "Slot_S3", "settlements", "yanki_mabedi")
	_place_card(battlefield, 2, "Slot_F3", "heroes", "okcu")
	for _frame in range(3):
		await process_frame

	var manager := battlefield.get_node("GameManager") as GameManager
	manager.player_dominion_score = {1: 8, 2: 10}
	for player_id in GameRules.PLAYER_IDS:
		battlefield._on_dominion_score_changed(
			player_id,
			int(manager.player_dominion_score[player_id]),
			GameRules.DOMINION_SCORE_TARGET
		)
	battlefield._refresh_lane_visuals()
	for _frame in range(2):
		await process_frame

	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var top_hud := battlefield.get_node("TopHud") as Control
	if not bounds.encloses(top_hud.get_global_rect()):
		push_error("Hakimiyet HUD'ı 1280×720 sınırlarının dışına taşıyor")
		quit(1)
		return
	for label_variant in top_hud.find_children("DominionScore", "Label", true, false):
		var label := label_variant as Label
		if not label.visible or not bounds.encloses(label.get_global_rect()):
			push_error("Hakimiyet skor etiketi görünür ekran sınırlarında değil")
			quit(1)
			return

	RenderingServer.force_draw(true, 0.0)
	var image := viewport.get_texture().get_image()
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		push_error("Hakimiyet savaş alanı görüntüsü alınamadı")
		quit(1)
		return
	var save_error := image.save_png(OUTPUT_PATH)
	if save_error != OK:
		push_error("Hakimiyet görüntüsü kaydedilemedi: %s" % error_string(save_error))
		quit(1)
		return
	print("DOMINION_VISUAL_CAPTURE_OK: %s" % OUTPUT_PATH)
	viewport.queue_free()
	await process_frame
	MatchSetup.configure_local(1)
	quit(0)


func _place_card(
	battlefield: BattlefieldUI,
	player_id: int,
	slot_name: String,
	card_type: String,
	card_id: String
) -> void:
	var slot := battlefield.get_node("Player%dZone/Grid/%s" % [player_id, slot_name]) as CardSlot
	if not slot or slot.is_occupied:
		return
	var card := battlefield._instantiate_card_from_ref({
		"card_type": card_type,
		"card_id": card_id,
	}, player_id)
	if not card:
		return
	card.is_draggable = false
	slot.add_child(card)
