extends SceneTree

const EFFECT_CHOICE_OUTPUT := "/tmp/tdm_effect_choice_1280x720.png"
const FIELD_OUTPUT := "/tmp/tdm_field_hud_1280x720.png"
const FIELD_PANNED_OUTPUT := "/tmp/tdm_field_hud_panned_1280x720.png"
const FIELD_FIT_OUTPUT := "/tmp/tdm_field_hud_fit_1280x720.png"
const EFFECT_PREVIEW_OUTPUT := "/tmp/tdm_effect_preview_1280x720.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("FIELD_HUD_VISUAL_CAPTURE_SKIPPED: etkin görüntü sürücüsü gerekiyor")
		quit(0)
		return
	TranslationServer.set_locale("tr")
	MatchSetup.configure_local(74747)
	MatchSetup.fast_mode = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	viewport.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame
	if battlefield._tutorial_overlay:
		battlefield._tutorial_overlay.visible = false
	var manager := battlefield.game_manager as GameManager
	manager.call("_reset_match_state")
	manager.begin_effect_selection(1)
	await process_frame
	battlefield.call("_reveal_effect_offers")
	await process_frame
	var first_offer := manager.get_effect_offer(1)
	if first_offer.is_empty():
		push_error("Görsel yakalama için Etki Kartı teklifi üretilemedi")
		quit(1)
		return
	battlefield.call("_on_effect_offer_pressed", first_offer[0])
	for _frame in range(5):
		await process_frame
	if not _save(viewport, EFFECT_CHOICE_OUTPUT):
		quit(1)
		return
	battlefield.call("_confirm_effect_offer_selection")
	await process_frame
	var second_offer := manager.get_effect_offer(2)
	if second_offer.is_empty() or not battlefield.resolve_effect_card_choice_for_player(2, second_offer[0]):
		push_error("İkinci Etki Kartı seçimi tamamlanamadı")
		quit(1)
		return
	await process_frame
	manager.cards_drawn_per_turn = 0
	var active := manager.first_player_id
	var enemy := manager.get_opponent_id(active)
	manager.confirm_mulligan(active)
	manager.confirm_mulligan(enemy)
	await process_frame

	_place_hero(battlefield.get_node("Player%dZone/Grid/Slot_F2" % active) as CardSlot, active, "sovalye")
	_place_hero(battlefield.get_node("Player%dZone/Grid/Slot_F2" % enemy) as CardSlot, enemy, "gladiator")
	_place_structure(battlefield.get_node("Player%dZone/Grid/Slot_S1" % active) as CardSlot, active, "altin_madeni")
	_place_structure(battlefield.get_node("Player%dZone/Grid/Slot_S2" % enemy) as CardSlot, enemy, "okcu_kulesi")
	battlefield.call("_on_turn_time_changed", active, 18.0, 30.0, true)
	battlefield.call("_apply_responsive_layout")
	for _frame in range(8):
		await process_frame
	var perspective_player_id := battlefield._get_hand_perspective_player_id()
	var opposing_player_id := 2 if perspective_player_id == 1 else 1
	var own_resources := battlefield._field_resource_badges[perspective_player_id] as Dictionary
	var opposing_resources := battlefield._field_resource_badges[opposing_player_id] as Dictionary
	if (
		not battlefield._field_own_energy_badge.visible
		or not battlefield._field_own_health_badge.visible
		or not (own_resources["energy"] as Control).visible
		or (opposing_resources["energy"] as Control).visible
		or not (battlefield._field_energy_labels[opposing_player_id] as Label).text.is_empty()
		or battlefield._get_hand_for_player(opposing_player_id).visible
		or battlefield._opponent_hand_backdrop.visible
	):
		push_error("Sol Enerji/Can özeti, rakip Enerji gizliliği veya gizli el görünürlüğü render sözleşmesini karşılamıyor")
		quit(1)
		return
	if not _save(viewport, FIELD_OUTPUT):
		quit(1)
		return
	var reference_slot := battlefield.get_node("Player%dZone/Grid/Slot_F2" % active) as CardSlot
	var world_positions := {
		"reference": reference_slot.global_position,
		"p1_name": (battlefield._field_name_badges[1] as Control).global_position,
		"p2_name": (battlefield._field_name_badges[2] as Control).global_position,
		"own_effect": battlefield._effect_panel_own_mount.global_position,
		"enemy_effect": battlefield._effect_panel_enemy_mount.global_position,
		"p1_deck": (battlefield._deck_panels[1] as Control).global_position,
		"p2_deck": (battlefield._deck_panels[2] as Control).global_position,
		"p1_standard": battlefield._arena_overlay.get_team_standard_centers()[1],
		"p2_standard": battlefield._arena_overlay.get_team_standard_centers()[2],
	}
	battlefield._board_camera_center += Vector2(140.0, -55.0)
	battlefield._clamp_board_camera()
	battlefield._apply_board_camera_transform()
	for _frame in range(5):
		await process_frame
	var world_delta := reference_slot.global_position - (world_positions["reference"] as Vector2)
	if (
		((battlefield._field_name_badges[1] as Control).global_position - (world_positions["p1_name"] as Vector2)).distance_to(world_delta) > 0.1
		or ((battlefield._field_name_badges[2] as Control).global_position - (world_positions["p2_name"] as Vector2)).distance_to(world_delta) > 0.1
		or (battlefield._effect_panel_own_mount.global_position - (world_positions["own_effect"] as Vector2)).distance_to(world_delta) > 0.1
		or (battlefield._effect_panel_enemy_mount.global_position - (world_positions["enemy_effect"] as Vector2)).distance_to(world_delta) > 0.1
		or ((battlefield._deck_panels[1] as Control).global_position - (world_positions["p1_deck"] as Vector2)).distance_to(world_delta) > 0.1
		or ((battlefield._deck_panels[2] as Control).global_position - (world_positions["p2_deck"] as Vector2)).distance_to(world_delta) > 0.1
		or ((battlefield._arena_overlay.get_team_standard_centers()[1] as Vector2) - (world_positions["p1_standard"] as Vector2)).distance_to(world_delta) > 0.1
		or ((battlefield._arena_overlay.get_team_standard_centers()[2] as Vector2) - (world_positions["p2_standard"] as Vector2)).distance_to(world_delta) > 0.1
	):
		push_error("Saha nesneleri kamera ile aynı dünya hareketini izlemedi")
		quit(1)
		return
	if not _save(viewport, FIELD_PANNED_OUTPUT):
		quit(1)
		return
	battlefield._fit_board_view()
	for _frame in range(5):
		await process_frame
	if (
		not battlefield._effect_panel_own_mount.get_global_rect().intersects(battlefield._board_view_rect)
		or not battlefield._effect_panel_enemy_mount.get_global_rect().intersects(battlefield._board_view_rect)
	):
		push_error("Sığdırılmış görünüm açık ve kapalı Etki Kartlarını birlikte göstermiyor")
		quit(1)
		return
	if not _save(viewport, FIELD_FIT_OUTPUT):
		quit(1)
		return
	battlefield._reset_board_view()
	for _frame in range(5):
		await process_frame
	if battlefield._effect_panel_own_card:
		battlefield.call("_show_card_preview", battlefield._effect_panel_own_card)
	for _frame in range(12):
		await process_frame
	if not _save(viewport, EFFECT_PREVIEW_OUTPUT):
		quit(1)
		return
	print("FIELD_HUD_VISUAL_CAPTURE_OK: %s • %s • %s • %s • %s" % [EFFECT_CHOICE_OUTPUT, FIELD_OUTPUT, FIELD_PANNED_OUTPUT, FIELD_FIT_OUTPUT, EFFECT_PREVIEW_OUTPUT])
	viewport.queue_free()
	await process_frame
	quit(0)


func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> void:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)


func _place_structure(slot: CardSlot, owner_id: int, card_id: String) -> void:
	var structure := SettlementCard.new()
	structure.owner_id = owner_id
	structure.card_id = card_id
	slot.add_child(structure)


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
