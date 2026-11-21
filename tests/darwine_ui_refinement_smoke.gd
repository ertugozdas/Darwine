extends SceneTree

const CARD_STAT_ICON_SCRIPT := preload("res://scripts/card_stat_icon.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	root.size = Vector2i(1280, 720)
	_test_brand_and_centered_menu()
	await process_frame
	await _test_battlefield_refinement()
	_finish()


func _test_brand_and_centered_menu() -> void:
	_expect(str(ProjectSettings.get_setting("application/config/name", "")) == "Darwine", "Proje adı Darwine olmalı")
	var packed := load("res://main_menu.tscn") as PackedScene
	_expect(packed != null, "Ana menü yüklenemedi")
	if not packed:
		return
	var menu := packed.instantiate()
	root.add_child(menu)
	current_scene = menu
	var title := menu.find_child("GameTitle", true, false) as Label
	_expect(title != null and title.text == "DARWINE", "Ana başlık DARWINE olmalı")
	_expect(title != null and title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Darwine başlığı ortalanmalı")
	for button_name in ["StartButton", "SettingsButton", "GalleryButton", "QuitButton"]:
		var button := menu.find_child(button_name, true, false) as Button
		_expect(button != null and button.alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s metni ortalanmalı" % button_name)
	menu.queue_free()
	current_scene = null


func _test_battlefield_refinement() -> void:
	MatchSetup.configure_local(424242)
	var packed := load("res://battlefield.tscn") as PackedScene
	_expect(packed != null, "Savaş alanı yüklenemedi")
	if not packed:
		return
	var battlefield := packed.instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	while battlefield._is_dealing_initial_hands:
		await process_frame
	battlefield._apply_responsive_layout()
	await process_frame

	var perspective_player_id := battlefield._get_hand_perspective_player_id()
	var opposing_player_id := 2 if perspective_player_id == 1 else 1
	var opponent_deck_panel := battlefield._deck_panels[opposing_player_id] as Panel
	_expect(
		opponent_deck_panel != null
		and opponent_deck_panel.visible
		and opponent_deck_panel.get_parent() == battlefield._battlefield_world_objects,
		"Rakip destesi oyun dünyası katmanında fiziksel kart yığını olarak görünmeli"
	)
	var own_deck_panel := battlefield._deck_panels[perspective_player_id] as Panel
	var own_deck_label := battlefield._deck_labels[perspective_player_id] as Label
	_expect(own_deck_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Oyuncu deste bilgisi etkileşimli buton görünümü taşımamalı")
	_expect(own_deck_label.text.begins_with("DESTEN") and "OYUNCU" not in own_deck_label.text, "Oyuncu deste bilgisi sade DESTEN etiketiyle gösterilmeli")
	_expect(
		own_deck_panel.get_parent() == battlefield._battlefield_world_objects
		and own_deck_panel.get_rect().end.x < battlefield._p1_zone_world_rect.position.x,
		"Oyuncu destesi kart yerleşim alanından uzakta, Merkezin solunda durmalı"
	)
	_expect(battlefield._effect_panel != null and battlefield._effect_panel.get_parent() == battlefield._battlefield_world_objects, "Etki Kartları oyun dünyası katmanına taşınmalı")
	_expect(
		battlefield._effect_panel_own_mount.get_global_rect().intersects(battlefield._board_view_rect)
		and not battlefield._effect_panel_own_mount.get_global_rect().intersects(battlefield._preview_panel.get_global_rect()),
		"Açık Etki Kartı savaş alanında, büyük kart önizlemesinden ayrı durmalı"
	)
	_expect(battlefield._preview_panel.position.y <= 20.0 and battlefield._preview_panel.size.y >= 300.0, "Sağ kart önizlemesi yeniden büyük ve üstten başlamalı")
	_expect(not _tree_contains_text(battlefield._preview_panel, "KART ÖNİZLEME"), "Önizlemede Kart Önizleme ibaresi kalmamalı")
	_expect(battlefield._preview_title_label == null, "Önizleme başlık kromu kaldırılmalı")
	_expect(battlefield._hand_dock != null, "Oyuncu eli için geniş alt el alanı oluşturulmalı")
	_expect(
		battlefield.p1_grid.size.x >= 340.0 and battlefield.p1_grid.size.y > battlefield.p1_grid.size.x,
		"Arena geniş koridor aralıklarıyla okunur bir oyun yüzeyi oluşturmalı"
	)

	_expect(not battlefield.top_hud.visible and battlefield._get_top_playfield_reserved_height(root.size) == 0.0, "Eski üst bar görünmemeli ve oyun alanında yer ayırmamalı")
	_expect(battlefield.top_hud._own_health_label.text == "30 / 30", "Gizli uyumluluk HUD'ı bizim Merkez canını izlemeli")
	_expect(battlefield.top_hud._enemy_health_label.text == "30 / 30", "Üst HUD rakip Merkez canını göstermeli")
	_expect(battlefield.top_hud._own_health_title.text == "BİZİM MERKEZ", "Bizim Merkez etiketi açık olmalı")
	_expect(battlefield.top_hud._enemy_health_title.text == "RAKİP MERKEZ", "Rakip Merkez etiketi açık olmalı")
	_expect(battlefield.top_hud.round_label.text.begins_with("TUR"), "Üst HUD tur numarasını ayrı göstermeli")
	_expect("ENERJİ" not in battlefield.top_hud.active_player_label.text, "Tur metni rakip Enerjisi izlenimi vermemeli")
	_expect(battlefield.top_hud._own_energy_badge != null and battlefield.top_hud._own_energy_badge.visible, "Kendi Enerjimiz ayrı üst bar plakası taşımalı")
	_expect(battlefield.top_hud._own_energy_caption.text == "ENERJİN", "Enerji plakası yalnız oyuncunun Enerjisi olduğunu açıkça yazmalı")
	_expect(battlefield.top_hud._own_energy_label.text == "3 / 3", "Kendi Enerjimiz büyük ve okunur değerle gösterilmeli")
	_expect(
		battlefield.top_hud._own_energy_icon != null
		and int(battlefield.top_hud._own_energy_icon.get("icon_type")) == CARD_STAT_ICON_SCRIPT.IconType.LIGHTNING,
		"Kendi Enerji plakası yıldırım ikonu taşımalı"
	)
	_expect(battlefield.top_hud.find_child("P1EnergyLabel", true, false) == null, "Üst bar oyuncu kimliğine bağlı eski Enerji etiketi üretmemeli")
	_expect(battlefield.top_hud.find_child("P2EnergyLabel", true, false) == null, "Üst bar rakip Enerji etiketi üretmemeli")
	_expect(not battlefield.p1_energy_label.visible and not battlefield.p2_energy_label.visible, "Eski yan panel Enerji etiketleri gizli kalmalı")
	var p1_field_energy := battlefield._field_energy_labels.get(1) as Label
	var p2_field_energy := battlefield._field_energy_labels.get(2) as Label
	var p1_field_health := battlefield._field_health_labels.get(1) as Label
	var p2_field_health := battlefield._field_health_labels.get(2) as Label
	var own_field_energy := p1_field_energy if perspective_player_id == 1 else p2_field_energy
	var enemy_field_energy := p2_field_energy if perspective_player_id == 1 else p1_field_energy
	var own_resource_entry := battlefield._field_resource_badges[perspective_player_id] as Dictionary
	var enemy_resource_entry := battlefield._field_resource_badges[opposing_player_id] as Dictionary
	_expect(
		own_field_energy != null
		and own_field_energy.text == "3"
		and (own_resource_entry["energy"] as Control).visible,
		"Yalnız yerel oyuncunun Enerjisi Merkez yanında görünmeli"
	)
	_expect(
		enemy_field_energy != null
		and enemy_field_energy.text.is_empty()
		and not (enemy_resource_entry["energy"] as Control).visible,
		"Rakibin Enerji rozeti ve değeri savaş alanında gizli kalmalı"
	)
	_expect(p1_field_health != null and p1_field_health.text == "30", "Oyuncu 1 Merkez canı bina yanında kalp ve sayı olarak görünmeli")
	_expect(p2_field_health != null and p2_field_health.text == "30", "Oyuncu 2 Merkez canı bina yanında kalp ve sayı olarak görünmeli")
	_expect(
		battlefield._field_timer_badge != null
		and battlefield._field_timer_badge.visible
		and int(battlefield._field_timer_icon.get("icon_type")) == CARD_STAT_ICON_SCRIPT.IconType.HOURGLASS,
		"Saha solunda kum saatli tur sayacı görünmeli"
	)
	_expect(
		battlefield._field_own_energy_badge != null
		and battlefield._field_own_energy_badge.visible
		and battlefield._field_own_energy_badge.position.y > battlefield._field_timer_badge.get_global_rect().end.y
		and battlefield._field_own_energy_label.text == "3"
		and int(battlefield._field_own_energy_icon.get("icon_type")) == CARD_STAT_ICON_SCRIPT.IconType.LIGHTNING,
		"Kendi Enerjimiz kum saatinin altında yıldırım rozetiyle görünmeli"
	)
	_expect(
		battlefield._field_own_health_badge != null
		and battlefield._field_own_health_badge.visible
		and battlefield._field_own_health_badge.position.y > battlefield._field_own_energy_badge.position.y
		and battlefield._field_own_health_label.text == "30"
		and int(battlefield._field_own_health_icon.get("icon_type")) == CARD_STAT_ICON_SCRIPT.IconType.HEART,
		"Kendi Canımız Enerjinin altında kalp rozetiyle görünmeli"
	)
	_expect(battlefield._field_round_badge != null and battlefield._field_round_label.text.begins_with("TUR"), "Tur sayısı savaş alanının sağında görünmeli")
	var p1_name_label := battlefield._field_name_labels.get(1) as Label
	var p2_name_label := battlefield._field_name_labels.get(2) as Label
	_expect(p1_name_label != null and p1_name_label.is_visible_in_tree() and "OYUNCU 1" in p1_name_label.text, "Oyuncu 1 adı savaş alanında görünmeli")
	_expect(p2_name_label != null and p2_name_label.is_visible_in_tree() and "OYUNCU 2" in p2_name_label.text, "Oyuncu 2 adı savaş alanında görünmeli")
	_expect(int(battlefield._arena_overlay.get("_active_player_id")) == battlefield.game_manager.active_player_id, "Ateş çemberi sırası gelen oyuncunun alanına bağlanmalı")
	var standard_centers := battlefield._arena_overlay.get_team_standard_centers()
	for player_id in GameRules.PLAYER_IDS:
		var deck_panel := battlefield._deck_panels[player_id] as Control
		var grid: Control = battlefield.p1_grid if player_id == 1 else battlefield.p2_grid
		var standard_center := standard_centers[player_id] as Vector2
		_expect(
			deck_panel != null
			and absf(standard_center.x - deck_panel.get_global_rect().get_center().x) < 0.1
			and absf(standard_center.y - grid.get_global_rect().get_center().y) < 0.1,
			"Takım sembolü destenin üzerinde ve gridin dikey merkezinde kalmalı"
		)
	var standard_centers_before := battlefield._arena_overlay.get_team_standard_centers()
	var hq_position_before: Vector2 = battlefield.p1_hq_slot.global_position
	var original_camera_center := battlefield._board_camera_center
	battlefield._board_camera_center += Vector2(120.0, 0.0)
	battlefield.call("_clamp_board_camera")
	battlefield.call("_apply_board_camera_transform")
	var standard_centers_after := battlefield._arena_overlay.get_team_standard_centers()
	var world_delta: Vector2 = battlefield.p1_hq_slot.global_position - hq_position_before
	_expect(
		((standard_centers_after[1] as Vector2) - (standard_centers_before[1] as Vector2)).distance_to(world_delta) < 0.1
		and ((standard_centers_after[2] as Vector2) - (standard_centers_before[2] as Vector2)).distance_to(world_delta) < 0.1,
		"Mavi ve kırmızı takım sembolleri kamera ile aynı dünya hareketini izlemeli"
	)
	battlefield._board_camera_center = original_camera_center
	battlefield.call("_apply_board_camera_transform")
	var own_energy_before_enemy_update := battlefield.top_hud._own_energy_label.text
	var own_left_energy_before_enemy_update := battlefield._field_own_energy_label.text
	var enemy_energy_before: Dictionary = battlefield.top_hud._player_energy.get(opposing_player_id, {}).duplicate(true)
	battlefield.top_hud.set_player_energy(opposing_player_id, 9, 10, 0)
	battlefield._on_energy_changed(opposing_player_id, 9, 10, 0)
	_expect(battlefield.top_hud._own_energy_label.text == own_energy_before_enemy_update, "Rakip Enerji güncellemesi görünür kendi Enerjimizi değiştirmemeli")
	_expect(
		battlefield._field_own_energy_label.text == own_left_energy_before_enemy_update
		and not (enemy_resource_entry["energy"] as Control).visible
		and enemy_field_energy.text.is_empty(),
		"Rakip Enerji güncellemesi sol özeti değiştirmemeli veya gizli değeri göstermemeli"
	)
	battlefield.top_hud.set_player_energy(
		opposing_player_id,
		int(enemy_energy_before.get("current", 0)),
		int(enemy_energy_before.get("maximum", 0)),
		int(enemy_energy_before.get("temporary", 0))
	)
	_expect(battlefield.find_child("P1HQHealthLabel", true, false) == null, "Merkez kartının üstünde 30/30 etiketi olmamalı")
	_expect(battlefield.find_child("P2HQHealthLabel", true, false) == null, "Rakip Merkez kartının üstünde 30/30 etiketi olmamalı")

	var manager := battlefield.game_manager as GameManager
	manager.cards_drawn_per_turn = 0
	var active := manager.first_player_id
	var enemy := manager.get_opponent_id(active)
	manager.confirm_mulligan(active)
	manager.confirm_mulligan(enemy)
	await process_frame

	var attacker_slot := battlefield.get_node("Player%dZone/Grid/Slot_F1" % active) as CardSlot
	var target_slot := battlefield.get_node("Player%dZone/Grid/Slot_F1" % enemy) as CardSlot
	var attacker := _place_hero(attacker_slot, active, "sovalye")
	var target := _place_hero(target_slot, enemy, "alev_duellocusu")
	await process_frame

	_expect(battlefield._can_preview_card(target), "Rakibin sahadaki yüzü açık kartı önizlenebilmeli")
	_expect(target.mouse_filter == Control.MOUSE_FILTER_PASS, "Rakip saha kartı işaretçiyi önizleme slotuna iletmeli")
	var inspect_click := InputEventMouseButton.new()
	inspect_click.button_index = MOUSE_BUTTON_LEFT
	inspect_click.pressed = true
	battlefield._on_board_slot_gui_input(inspect_click, target_slot)
	await process_frame
	_expect(battlefield._preview_card != null and battlefield._preview_card.owner_id == enemy, "Rakip saha kartına tıklamak sağ önizlemeyi açmalı")
	if battlefield._preview_card:
		_expect(battlefield._preview_card.is_public_preview, "Rakip saha önizleme kopyası açık bilgi olarak işaretlenmeli")
		_expect(not battlefield._preview_card._is_hand_face_down(manager), "Rakip saha önizlemesi kart arkasını göstermemeli")
		_expect(battlefield._preview_card._frame_panel.visible, "Rakip saha önizlemesinde kartın ön yüzü görünmeli")
		_expect(not battlefield._preview_card._card_back_panel.visible, "Rakip saha önizlemesinde kart arkası gizli kalmalı")
	battlefield._hide_card_preview()
	target.mouse_entered.emit()
	await create_timer(BattlefieldUI.CARD_PREVIEW_DELAY + 0.02).timeout
	_expect(battlefield._preview_card != null and battlefield._preview_card.owner_id == enemy, "Rakip saha kartı hover ile sağ önizlemeyi açmalı")
	target.mouse_exited.emit()

	_expect(attacker._name_lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Kart adı ortalanmalı")
	_expect(attacker._desc_lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Kart açıklaması ortalanmalı")
	_expect(attacker._desc_lbl.clip_text and attacker._desc_lbl.max_lines_visible == 4, "Kart açıklaması taşmayı sınırlamalı")
	attacker.selected_branch_name = "Muhafız"
	attacker.card_level = 2
	attacker.attached_skill_name = "Kadim Kalkan"
	attacker.refresh_runtime_badges()
	attacker_slot._refresh_card_state_overlay()
	_expect(attacker._progression_badge.visible and attacker._progression_label.text == "SV 2", "Seviye rozeti kartın kendi çerçevesine bağlanmalı")
	_expect(attacker._progression_badge.anchor_bottom <= 0.10, "Seviye rozeti kart metnini kapatmamalı")
	_expect(attacker_slot._skill_badge.visible, "Bağlı Beceri küçük kenar rozetiyle görünmeli")
	attacker.set_combat_state(BaseCard.CombatState.EXHAUSTED)
	_expect(attacker._frame_panel.modulate.r >= 0.70 and attacker._frame_panel.modulate.r < 1.0, "Tükenmişlik kartı hafifçe solgunlaştırarak okunabilir ayrım sağlamalı")
	_expect(attacker._combat_state_badge.visible and attacker._combat_state_label.text == "TÜKENDİ", "Kart tek ve tam TÜKENDİ rozeti göstermeli")
	_expect(not attacker_slot._combat_badge.visible, "Slot üstündeki ikinci TÜK rozeti kaldırılmalı")
	attacker.set_combat_state(BaseCard.CombatState.READY)
	attacker.set_selection_visual(true, DarkFantasyUI.BRASS_BRIGHT)
	_expect(attacker._interaction_glow.visible, "Kart seçimi tematik dış kontur üretmeli")
	attacker.set_selection_visual(false)

	_expect(attacker_slot._style_box.border_width_left >= 4, "Grid yuvası kalın taş plaka çerçevesi kullanmalı")
	_expect(attacker_slot.normal_color.r < 0.16 and attacker_slot.normal_color.g < 0.14, "Grid yuvası koyu taş malzeme paletini kullanmalı")
	_expect(BattlefieldFeedbackLayer.ATTACK_TELEGRAPH_SECONDS >= 0.38, "Saldırı telegraph süresi seri ve okunabilir olmalı")
	_expect(manager.advance_phase(active), "Çatışma aşamasına geçilemedi")
	attacker.set_combat_state(BaseCard.CombatState.READY)
	var trace_before := battlefield._feedback_layer.attack_animation_count
	var started_at := Time.get_ticks_msec()
	var result: Dictionary = await battlefield.resolve_attack_with_feedback(attacker, target_slot)
	var elapsed := Time.get_ticks_msec() - started_at
	_expect(bool(result.get("success", false)), "Görsel sıralı saldırı çözülemedi")
	_expect(elapsed >= 850, "Normal savaş çözümü hedefi okumaya yetecek kadar yavaş olmalı")
	_expect(battlefield._feedback_layer.attack_animation_count == trace_before + 1, "Saldırı tek ve belirgin bir hedef izi üretmeli")
	_expect(not battlefield._combat_sequence_active, "Saldırı sonrası etkileşim kilidi açılmalı")

	battlefield._on_game_over(active)
	_expect(battlefield.game_over_panel.visible, "Oyun sonu yüzeyi görünmeli")
	var summary_grid := battlefield.game_over_panel.find_child("GameOverStatsGrid", true, false) as GridContainer
	_expect(summary_grid != null and summary_grid.get_child_count() == 6, "Oyun sonu yüzeyi altı kişisel maç metriği göstermeli")
	_expect(battlefield._game_over_reward_label != null, "Oyun sonu XP ve Mühür özeti bulunmalı")
	_expect(battlefield._game_over_restart_button != null and battlefield._game_over_restart_button.text == "YENİDEN OYNA", "Yeniden Oyna düğmesi bulunmalı")
	_expect(battlefield._game_over_main_menu_button != null and battlefield._game_over_main_menu_button.text == "ANA MENÜ", "Ana Menü düğmesi bulunmalı")

	battlefield.queue_free()
	current_scene = null
	await process_frame


func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)
	return hero


func _tree_contains_text(node: Node, needle: String) -> bool:
	if node is Label and needle in (node as Label).text:
		return true
	if node is Button and needle in (node as Button).text:
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DARWINE_UI_REFINEMENT_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("DARWINE_UI_REFINEMENT_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
