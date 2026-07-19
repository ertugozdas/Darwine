extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale("tr")
	root.size = Vector2i(1280, 720)
	var battlefield_scene := load("res://battlefield.tscn") as PackedScene
	_expect(battlefield_scene != null, "battlefield.tscn yüklenemedi")
	if not battlefield_scene:
		_finish()
		return

	var battlefield := battlefield_scene.instantiate() as BattlefieldUI
	root.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame
	battlefield._apply_responsive_layout()
	await process_frame

	_expect(root.size == Vector2i(1280, 720), "Aşama 6 kabul görünümü 1280×720 olmalı")
	_expect(
		battlefield._arena_texture != null
		and battlefield._arena_texture.texture != null
		and battlefield._arena_texture.texture.resource_path == "res://images/environments/battlefield_factions_arena_blue_player.png",
		"Savaş alanı temaya uygun özel çevre görselini kullanmalı"
	)
	_expect("BAŞLANGIÇ ELİ" in battlefield._phase_label.text, "Faz göstergesi başlangıç eli aşamasını göstermeli")
	_expect("DEĞİŞTİRMEK İSTEDİĞİN KARTLARI SEÇ" in battlefield._phase_label.text, "Faz göstergesi yeni oyuncuya yapılacak hamleyi açıkça söylemeli")
	_expect(battlefield.end_turn_button.get_theme_font_size("font_size") == 11, "Başlangıç elini onayla metni iki punto küçültülerek 11 punto olmalı")
	var card_back_art := battlefield.find_child("FantasyBackArt", true, false) as TextureRect
	_expect(card_back_art != null and card_back_art.texture != null, "Kart arkası fantasy görselini kullanmalı")
	var visible_hand_id := battlefield._get_locally_visible_hand_player_id()
	var opponent_hand_id := 2 if visible_hand_id == 1 else 1
	var own_resource_entry := battlefield._field_resource_badges[visible_hand_id] as Dictionary
	var enemy_resource_entry := battlefield._field_resource_badges[opponent_hand_id] as Dictionary
	_expect(
		battlefield._field_own_energy_badge != null
		and battlefield._field_own_health_badge != null
		and battlefield._field_own_energy_badge.get_global_rect().position.y > battlefield._field_timer_badge.get_global_rect().end.y
		and battlefield._field_own_health_badge.get_global_rect().position.y > battlefield._field_own_energy_badge.get_global_rect().end.y,
		"Kendi Enerji ve Can rozetleri kum saatinin altında sıralanmalı"
	)
	_expect(
		(own_resource_entry["energy"] as Control).visible
		and not (enemy_resource_entry["energy"] as Control).visible
		and (battlefield._field_energy_labels[opponent_hand_id] as Label).text.is_empty(),
		"Yalnız görünür oyuncunun saha Enerjisi okunabilir olmalı"
	)
	var own_deck_panel := battlefield._deck_panels.get(visible_hand_id) as Panel
	var opponent_deck_panel := battlefield._deck_panels.get(opponent_hand_id) as Panel
	var own_deck_label := battlefield._deck_labels.get(visible_hand_id) as Label
	var opponent_deck_label := battlefield._deck_labels.get(opponent_hand_id) as Label
	var deck_back_icon := own_deck_panel.get_node_or_null("DeckBackIcon") as TextureRect if own_deck_panel else null
	_expect(own_deck_panel != null and own_deck_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Deste bilgisi tıklanabilir bir buton gibi davranmamalı")
	_expect(own_deck_label != null and own_deck_label.text.begins_with("DESTEN") and "OYUNCU" not in own_deck_label.text, "Deste sayısı doğal ve kişisel bir etiketle gösterilmeli")
	_expect(opponent_deck_label != null and opponent_deck_label.text.begins_with("RAKİP"), "Karşı deste rakibe ait olduğunu açıkça göstermeli")
	_expect(own_deck_label != null and own_deck_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Deste kart sayısı etiketi kendi alanında ortalanmalı")
	_expect(deck_back_icon != null and deck_back_icon.texture != null, "Deste bilgisinde küçük fantasy kart arkası simgesi bulunmalı")
	var deck_style := own_deck_panel.get_theme_stylebox("panel") as StyleBoxFlat if own_deck_panel else null
	_expect(
		deck_style != null
		and deck_style.border_width_left >= 2
		and deck_style.border_width_right >= 2
		and deck_style.shadow_size >= 8,
		"Saha destesi fiziksel kart yığını gibi tam çerçeve ve gölge taşımalı"
	)
	_expect(
		battlefield._battlefield_world_objects != null
		and own_deck_panel.get_parent() == battlefield._battlefield_world_objects
		and opponent_deck_panel != null
		and opponent_deck_panel.get_parent() == battlefield._battlefield_world_objects
		and own_deck_panel.visible
		and opponent_deck_panel.visible,
		"İki fiziksel deste de kamera ile hareket eden oyun dünyası katmanında görünmeli"
	)
	_expect(
		battlefield._effect_panel.get_parent() == battlefield._battlefield_world_objects
		and (battlefield._field_name_badges[1] as Control).get_parent() == battlefield._battlefield_world_objects
		and (battlefield._field_name_badges[2] as Control).get_parent() == battlefield._battlefield_world_objects,
		"Kullanıcı tagları ve Etki Kartları aynı oyun dünyası katmanında olmalı"
	)
	var p1_deck_rect := (battlefield._deck_panels[1] as Control).get_rect()
	var p2_deck_rect := (battlefield._deck_panels[2] as Control).get_rect()
	_expect(
		p1_deck_rect.end.x < battlefield._p1_zone_world_rect.position.x
		and p2_deck_rect.end.x < battlefield._p2_zone_world_rect.position.x,
		"Desteler kart yerleşim alanının tamamen dışında, Merkezlerin uzağında durmalı"
	)
	_expect(
		absf(p1_deck_rect.get_center().x - p2_deck_rect.get_center().x) <= 0.1
		and absf(p1_deck_rect.get_center().y + p2_deck_rect.get_center().y - battlefield._board_world_size.y) <= 0.1,
		"Oyuncu ve rakip desteleri oyun dünyasında tam karşılıklı hizalanmalı"
	)
	var own_effect_rect := battlefield._effect_panel_own_mount.get_rect()
	var enemy_effect_rect := battlefield._effect_panel_enemy_mount.get_rect()
	_expect(
		absf(own_effect_rect.get_center().x - enemy_effect_rect.get_center().x) <= 0.1
		and absf(own_effect_rect.get_center().y + enemy_effect_rect.get_center().y - battlefield._board_world_size.y) <= 0.1
		and own_effect_rect.position.x - battlefield._p1_zone_world_rect.end.x >= 20.0,
		"Açık ve kapalı Etki Kartları sağ borderdan belirgin boşlukla karşılıklı durmalı"
	)
	var field_object_rects := {
		"OYUNCU 1 TAGI": (battlefield._field_name_badges[1] as Control).get_global_rect(),
		"OYUNCU 2 TAGI": (battlefield._field_name_badges[2] as Control).get_global_rect(),
		"OYUNCU 1 DESTESİ": (battlefield._deck_panels[1] as Control).get_global_rect(),
		"OYUNCU 2 DESTESİ": (battlefield._deck_panels[2] as Control).get_global_rect(),
		"AÇIK ETKİ KARTI": battlefield._effect_panel_own_mount.get_global_rect(),
		"KAPALI ETKİ KARTI": battlefield._effect_panel_enemy_mount.get_global_rect(),
	}
	for node in battlefield.get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if not slot:
			continue
		for object_name in field_object_rects:
			_expect(
				not (field_object_rects[object_name] as Rect2).intersects(slot.get_global_rect()),
				"%s hiçbir kart yuvasıyla çakışmamalı" % object_name
			)
	for player_id in GameRules.PLAYER_IDS:
		var name_rect := (battlefield._field_name_badges[player_id] as Control).get_global_rect()
		var resource_entry := battlefield._field_resource_badges[player_id] as Dictionary
		for badge_key in ["energy", "health"]:
			var resource_badge := resource_entry[badge_key] as Control
			_expect(
				resource_badge != null and not name_rect.intersects(resource_badge.get_global_rect()),
				"Oyuncu %d tagı Merkez %s rozetiyle çakışmamalı" % [player_id, badge_key]
			)
		_expect(
			not name_rect.intersects((battlefield._deck_panels[player_id] as Control).get_global_rect()),
			"Oyuncu %d tagı fiziksel desteyle çakışmamalı" % player_id
		)
	var visible_hand := battlefield._get_hand_for_player(visible_hand_id)
	var opponent_hand := battlefield._get_hand_for_player(opponent_hand_id)
	_expect(
		battlefield._hand_dock != null
		and battlefield._hand_dock_backdrop.get_global_rect().position.y > root.size.y * 0.68
		and visible_hand.get_global_rect().position.y >= battlefield._hand_dock_backdrop.get_global_rect().position.y - 24.0,
		"Oyuncunun kart eli ekranın altında geniş bir el alanında olmalı"
	)
	_expect(
		visible_hand.visible
		and not opponent_hand.visible
		and not battlefield._opponent_hand_backdrop.visible,
		"Yerel el altta görünmeli; sol üstte rakibin kapalı el şeridi gösterilmemeli"
	)
	var saved_ai_difficulties := MatchSetup.ai_difficulties.duplicate(true)
	var saved_human_player_id := MatchSetup.human_player_id
	MatchSetup.ai_difficulties = {2: MatchSetup.AIDifficulty.MEDIUM}
	MatchSetup.human_player_id = 1
	battlefield._refresh_hand_visibility()
	_expect(battlefield.p1_hand.visible and not battlefield.p2_hand.visible, "Yapay zekâ maçında da rakibin kapalı eli gösterilmemeli")
	MatchSetup.ai_difficulties = saved_ai_difficulties
	MatchSetup.human_player_id = saved_human_player_id
	battlefield._refresh_hand_visibility()
	_expect(
		battlefield.p1_grid.size.x >= 340.0
		and battlefield.p2_grid.size.x >= 340.0
		and battlefield.p1_grid.size.y > battlefield.p1_grid.size.x,
		"Üç koridorlu arena geniş koridor aralıklarıyla okunur bir oyun yüzeyi oluşturmalı"
	)
	_expect(
		absf(battlefield.p1_grid.get_global_rect().get_center().x - battlefield.p2_grid.get_global_rect().get_center().x) <= 1.0,
		"İki tarafın üç koridoru kamera alanında aynı eksene hizalanmalı"
	)
	for player_id in [1, 2]:
		var structure_center_slot := _get_slot(battlefield, player_id, "Slot_S2")
		var hq_slot: CardSlot = battlefield.p1_hq_slot if player_id == 1 else battlefield.p2_hq_slot
		var player_grid: Control = battlefield.p1_grid if player_id == 1 else battlefield.p2_grid
		var slot_aspect_ratio := structure_center_slot.size.y / structure_center_slot.size.x
		var card_aspect_ratio := BattlefieldUI.HAND_CARD_BASE_SIZE.y / BattlefieldUI.HAND_CARD_BASE_SIZE.x
		_expect(
			absf(slot_aspect_ratio - card_aspect_ratio) <= 0.02,
			"Grid hücreleri kartın portre oranını korumalı"
		)
		_expect(
			absf(hq_slot.get_global_rect().get_center().x - player_grid.get_global_rect().get_center().x) <= 1.0,
			"Merkez binası üç koridorun yatay merkezine hizalanmalı"
		)
		if player_id == 1:
			_expect(hq_slot.get_global_rect().position.y >= player_grid.get_global_rect().end.y, "Oyuncu Merkezi gridin altında olmalı")
		else:
			_expect(hq_slot.get_global_rect().end.y <= player_grid.get_global_rect().position.y, "Rakip Merkezi gridin üstünde olmalı")
		var empty_slot_style := structure_center_slot.get_theme_stylebox("panel") as StyleBoxFlat
		_expect(
			empty_slot_style != null and empty_slot_style.bg_color.a <= 0.40,
			"Boş saha yuvaları araziyi örtecek kadar opak olmamalı"
		)
	var visible_cards := battlefield.get_hand_cards(visible_hand_id)
	if visible_cards.size() >= 2:
		var card_step := absf(visible_cards[1].position.x - visible_cards[0].position.x)
		var visible_card_width := BattlefieldUI.HAND_CARD_BASE_SIZE.x * battlefield._hand_card_scale
		_expect(
			card_step >= visible_card_width * 0.98,
			"Yerel el kartları birbirini kapatmadan tüm yüzleri görünecek biçimde yayılmalı"
		)
		_expect(battlefield._hand_card_scale >= 0.60, "Beş kartlık yerel el büyük ve okunur ölçekte gösterilmeli")
	_test_board_camera(battlefield)
	_test_overlay_controls(battlefield)
	_test_core_control_bounds(battlefield)

	var manager := battlefield.game_manager as GameManager
	manager.cards_drawn_per_turn = 0
	var active_player := manager.first_player_id
	var opponent := manager.get_opponent_id(active_player)
	_expect(manager.confirm_mulligan(active_player), "İlk oyuncu mulliganı onaylanmalı")
	_expect(manager.confirm_mulligan(opponent), "İkinci oyuncu mulliganı onaylanmalı")
	await process_frame
	_expect(battlefield.end_turn_button.get_theme_font_size("font_size") == 15, "Normal faz butonları standart 15 puntoya dönmeli")
	manager.player_current_energy[active_player] = 10
	manager.player_temporary_energy[active_player] = 0
	battlefield.sync_player_energy(active_player)
	battlefield._refresh_lane_visuals()
	_expect(battlefield._feedback_layer.get_open_path_count() == 3, "Boş rakip alanında üç açık Merkez rotası görünmeli")

	var empty_slot := _get_slot(battlefield, active_player, "Slot_F3")
	battlefield.request_card_action_selection(empty_slot)
	_expect("Eylem için" in battlefield._toast_label.text, "Geçersiz hamlenin nedeni görünür olmalı")
	_expect(battlefield._feedback_audio.last_event_id == "invalid", "Geçersiz hamle kısa ses geri bildirimi vermeli")

	var attacker_slot := _get_slot(battlefield, active_player, "Slot_F1")
	var target_slot := _get_slot(battlefield, opponent, "Slot_F1")
	var attacker := _place_hero(attacker_slot, active_player, "sovalye")
	var target := _place_hero(target_slot, opponent, "gladiator")
	await process_frame
	attacker.experience = 2
	attacker.selected_branch_id = "muhafiz"
	attacker.selected_branch_name = "Muhafız"
	attacker.set_progression_level(2)
	attacker.apply_status("stunned", 1, 1)
	attacker.apply_status("poison", 2, 1)
	attacker.apply_status("protected", 2, 1)
	attacker.set_combat_state(BaseCard.CombatState.READY)
	await process_frame

	_expect(attacker._progression_badge.visible and attacker._progression_label.text == "SV 2", "Seviye kartın kendi üst rozetinde görünmeli")
	_expect(not attacker_slot._level_badge.visible, "Slot üzerinde ikinci bir seviye rozeti kalmamalı")
	_expect(not attacker_slot._combat_badge.visible, "Slot üzerinde TÜK kısaltması kalmamalı")
	_expect("SERSEM" in attacker_slot._status_label.text, "Saha yuvası Sersemlemiş durumunu göstermeli")
	_expect("ZEHİR" in attacker_slot._status_label.text, "Saha yuvası Zehirli durumunu göstermeli")
	_expect("KORUMA" in attacker_slot._status_label.text, "Saha yuvası Korumalı durumunu göstermeli")
	_expect(
		attacker._progression_badge.get_global_rect().intersects(attacker.get_global_rect()),
		"Seviye mührü kartın kendi çerçevesine bağlı kalmalı"
	)
	attacker.set_combat_state(BaseCard.CombatState.EXHAUSTED)
	_expect(
		attacker._combat_state_badge.visible
		and attacker._combat_state_label.text == "TÜKENDİ"
		and not attacker_slot._combat_badge.visible,
		"Tükenmişlik kart üzerinde tek ve tam TÜKENDİ rozetiyle görünmeli"
	)
	attacker.set_combat_state(BaseCard.CombatState.READY)
	battlefield._show_card_preview(attacker)
	await process_frame
	_expect(battlefield._preview_details_panel.visible, "Kart önizlemesinin altında ayrıntı şeridi görünmeli")
	_expect(
		battlefield._preview_details_panel.get_theme_stylebox("panel") is StyleBoxTexture
		and battlefield._preview_details_panel.get_node_or_null("InnerPlate") is Panel,
		"Saha Durumu dövme çerçeve ve iç plaka ile ana temayı kullanmalı"
	)
	_expect("SEVİYE 2" in battlefield._preview_details_label.text, "Önizleme seviye bilgisini açıkça göstermeli")
	_expect("DURUM" in battlefield._preview_details_label.text and "Muhafız" in battlefield._preview_details_label.text, "Önizleme durum ve nitelik bilgisini göstermeli")
	_expect(battlefield._feedback_layer.get_open_path_count() == 2, "Dolu koridorun Merkez rotası kapanmalı")

	var floating_before_level := battlefield.floating_feedback_count
	manager.card_leveled_up.emit(attacker, 2, "muhafiz")
	_expect(attacker.last_feedback_kind == "upgrade", "Seviye yükseltme kart animasyonu tetiklemeli")
	_expect(battlefield.floating_feedback_count == floating_before_level + 1, "Seviye yükseltme yüzen metin üretmeli")

	attacker.health = maxi(1, attacker.health - 2)
	var heal_result := EffectResolver.apply_healing(manager, null, attacker, 1)
	_expect(bool(heal_result.get("success", false)), "İyileştirme ortak çözüm hattından geçmeli")
	_expect(attacker.last_feedback_kind == "heal", "İyileştirme kart animasyonu tetiklemeli")

	_expect(manager.advance_phase(active_player), "Hazırlıktan Çatışmaya geçilebilmeli")
	_expect("ÇATIŞMA" in battlefield.top_hud._phase_label.text, "Üst HUD Çatışma aşamasını göstermeli")
	_expect("HAZIR SALDIRGANI" in battlefield._phase_label.text, "Bağlamsal gösterge saldırı adımını kısa açıklamalı")
	_expect(battlefield._phase_banner_panel.visible, "Aşama değişiminde görsel faz bandı gösterilmeli")
	attacker.set_combat_state(BaseCard.CombatState.READY)
	target.health = 4
	var trace_before := battlefield._feedback_layer.attack_animation_count
	var floating_before_attack := battlefield.floating_feedback_count
	var first_attack := CombatResolver.resolve_attack(battlefield, manager, attacker, target_slot)
	_expect(bool(first_attack.get("success", false)), "İlk saldırı çözülebilmeli")
	_expect(battlefield._feedback_layer.attack_animation_count == trace_before + 1, "Saldırı hedefe giden iz animasyonu üretmeli")
	_expect(target.last_feedback_kind == "armor_break", "Zırha çarpan hasar çatlama animasyonu tetiklemeli")
	_expect(battlefield.floating_feedback_count > floating_before_attack, "Hasar yüzen değer üretmeli")

	attacker.set_combat_state(BaseCard.CombatState.READY)
	target.health = 1
	var deaths_before := battlefield.death_feedback_count
	var kill_attack := CombatResolver.resolve_attack(battlefield, manager, attacker, target_slot)
	_expect(bool(kill_attack.get("destroyed", false)), "İkinci saldırı hedefi yok etmeli")
	_expect(battlefield.death_feedback_count == deaths_before + 1, "Ölüm ayrı bir görsel geri bildirim üretmeli")
	await process_frame
	battlefield._refresh_lane_visuals()
	_expect(battlefield._feedback_layer.get_open_path_count() == 3, "Hedef ölünce koridorun Merkez rotası yeniden açılmalı")

	_expect(manager.advance_phase(active_player), "Çatışmadan Tur Sonuna geçilebilmeli")
	await process_frame
	_expect(manager.active_player_id == opponent, "Tur Sonu tamamlanınca sıra rakibe geçmeli")
	_expect("HAZIRLIK" in battlefield.top_hud._phase_label.text, "Yeni tur üst HUD'da Hazırlık göstergesiyle başlamalı")
	var rotated_local_hand := battlefield._get_hand_for_player(battlefield._get_hand_perspective_player_id())
	_expect(
		rotated_local_hand.get_global_rect().position.y >= battlefield._hand_dock_backdrop.get_global_rect().position.y - 24.0,
		"Sıra değişince yeni yerel el alt kart destesine taşınmalı"
	)
	_expect(
		(battlefield._deck_panels[opponent] as Control).visible
		and (battlefield._deck_panels[active_player] as Control).visible
		and (battlefield._deck_panels[opponent] as Control).get_parent() == battlefield._battlefield_world_objects
		and (battlefield._deck_labels[opponent] as Label).text.begins_with("DESTEN"),
		"Sıra değişince desteler dünya ankrajlarında kalırken yerel deste etiketi doğru oyuncuya geçmeli"
	)
	var rotated_own_resources := battlefield._field_resource_badges[opponent] as Dictionary
	var rotated_enemy_resources := battlefield._field_resource_badges[active_player] as Dictionary
	_expect(
		(rotated_own_resources["energy"] as Control).visible
		and not (rotated_enemy_resources["energy"] as Control).visible
		and (battlefield._field_energy_labels[active_player] as Label).text.is_empty()
		and battlefield._field_own_energy_label.text == str(
			int(manager.player_current_energy[opponent]) + int(manager.player_temporary_energy[opponent])
		),
		"Yerel sıra değişince yalnız yeni perspektifin Enerjisi görünmeli"
	)

	battlefield.queue_free()
	await process_frame
	_finish()

func _test_overlay_controls(battlefield: BattlefieldUI) -> void:
	battlefield.force_show_tutorial(0)
	_expect(battlefield._tutorial_overlay.is_open(), "İlk maç öğreticisi açılabilmeli")
	_expect(battlefield.is_card_interaction_locked(), "Öğretici açıkken kart etkileşimi kilitlenmeli")
	_expect(battlefield._tutorial_overlay.get_step_count() == 5, "Öğretici kısa ve adımlı olmalı")
	_expect(_rect_inside_viewport(battlefield._tutorial_overlay._panel.get_global_rect()), "Öğretici paneli 1280×720 içinde kalmalı")
	battlefield._tutorial_overlay.close_tutorial(true)
	_expect(not battlefield._tutorial_overlay.is_open(), "Öğretici Atla ile kapanabilmeli")

	battlefield._open_pause_menu()
	_expect(battlefield.get_tree().paused, "ESC menüsü oyunu gerçekten duraklatmalı")
	_expect(battlefield._pause_menu.is_open(), "ESC menüsü açılabilmeli")
	_expect(battlefield.is_card_interaction_locked(), "ESC menüsü açıkken kart etkileşimi kilitlenmeli")
	var pause_panel := battlefield._pause_menu.find_child("PausePanel", true, false) as Control
	_expect(pause_panel != null and _rect_inside_viewport(pause_panel.get_global_rect()), "Kaydet ve Yükle eylemleriyle ESC menüsü 1280×720 içinde kalmalı")
	for button_name in ["ContinueButton", "SaveGameButton", "LoadGameButton", "RulesButton", "SettingsButton", "LeaveGameButton"]:
		_expect(battlefield._pause_menu.find_child(button_name, true, false) is Button, "%s ESC menüsünde bulunmalı" % button_name)
	var save_button := battlefield._pause_menu.find_child("SaveGameButton", true, false) as Button
	var load_button := battlefield._pause_menu.find_child("LoadGameButton", true, false) as Button
	_expect(save_button != null and save_button.visible and save_button.text == "KAYDET", "Yerel/AI duraklatma menüsü Kaydet eylemini göstermeli")
	_expect(load_button != null and load_button.visible and load_button.text == "YÜKLE", "Yerel/AI duraklatma menüsü Yükle eylemini göstermeli")
	_expect(
		battlefield.find_child("RulesHelpButton", true, false) == null
		and battlefield.find_child("AudioToggleButton", true, false) == null,
		"Kalıcı Kurallar ve Ses düğmeleri sağ HUD'dan kaldırılmalı"
	)

	var rules_button := battlefield._pause_menu.find_child("RulesButton", true, false) as Button
	rules_button.pressed.emit()
	_expect(battlefield._rules_reference_panel.is_open(), "ESC menüsündeki Kurallar hızlı rehberi açmalı")
	_expect("Menzilli" in battlefield._rules_reference_panel.get_reference_text(), "Hızlı rehber ortak sözlüğü içermeli")
	_expect(_rect_inside_viewport(battlefield._rules_reference_panel._panel.get_global_rect()), "Kural paneli 1280×720 içinde kalmalı")
	battlefield._rules_reference_panel.close_reference()
	_expect(battlefield._pause_menu.is_open(), "Kural rehberi kapanınca ESC menüsüne dönülmeli")

	var settings_button := battlefield._pause_menu.find_child("SettingsButton", true, false) as Button
	settings_button.pressed.emit()
	_expect(battlefield._pause_menu._settings_view.visible, "Ayarlar düğmesi ses ve ekran alt yüzeyini açmalı")
	battlefield._pause_menu._show_home()
	battlefield._resume_from_pause()
	_expect(not battlefield.get_tree().paused and not battlefield._pause_menu.is_open(), "Devam Et oyunu sürdürmeli")

func _test_board_camera(battlefield: BattlefieldUI) -> void:
	_expect(battlefield._board_navigation_panel != null, "Savaş alanında görünür zoom/pan kontrolü bulunmalı")
	_expect(
		battlefield._board_navigation_toggle_button != null
		and battlefield._board_navigation_content != null
		and not battlefield._board_navigation_content.visible,
		"Kamera ayarları başlangıçta kompakt bir açılır panel olmalı"
	)
	var camera_button_style := battlefield._board_navigation_toggle_button.get_theme_stylebox("normal")
	_expect(
		camera_button_style.content_margin_top > camera_button_style.content_margin_bottom,
		"Kamera düğmesi yazısı dövme çerçevenin görsel merkezine doğru aşağı kaydırılmalı"
	)
	var collapsed_height := battlefield._board_navigation_panel.size.y
	battlefield._on_board_navigation_toggle_pressed()
	_expect(
		battlefield._board_navigation_content.visible
		and battlefield._board_navigation_panel.size.y > collapsed_height + 100.0,
		"Kamera başlığı ayarları açıp paneli büyütebilmeli"
	)
	battlefield._on_board_navigation_toggle_pressed()
	_expect(
		not battlefield._board_navigation_content.visible
		and is_equal_approx(battlefield._board_navigation_panel.size.y, collapsed_height),
		"Kamera ayarları yeniden kompakt duruma kapanabilmeli"
	)
	for button_name in ["OpponentFocus", "FrontFocus", "BaseFocus", "PanLeft", "PanRight", "ResetView"]:
		_expect(
			battlefield._board_navigation_panel.find_child(button_name, true, false) is Button,
			"%s kamera kontrolünde bulunmalı" % button_name
		)
	var initial_zoom := battlefield._board_zoom
	var tracked_slot := battlefield.p1_grid.get_node("Slot_F2") as CardSlot
	var initial_size := tracked_slot.get_global_rect().size
	var initial_deck_size := (battlefield._deck_panels[1] as Control).get_global_rect().size
	battlefield._zoom_board_at(battlefield._board_view_rect.get_center(), initial_zoom * BattlefieldUI.BOARD_ZOOM_STEP)
	_expect(battlefield._board_zoom > initial_zoom, "Kamera savaş alanına yakınlaşabilmeli")
	_expect(tracked_slot.get_global_rect().size.x > initial_size.x, "Zoom kart yuvalarını okunur biçimde büyütmeli")
	_expect(
		(battlefield._deck_panels[1] as Control).get_global_rect().size.x > initial_deck_size.x,
		"Dünya nesnesi olan deste kamera yakınlaşınca oyun alanıyla birlikte büyümeli"
	)
	var position_before_pan := tracked_slot.get_global_rect().position
	var p1_name_position := (battlefield._field_name_badges[1] as Control).global_position
	var p2_name_position := (battlefield._field_name_badges[2] as Control).global_position
	var own_effect_position := battlefield._effect_panel_own_mount.global_position
	var enemy_effect_position := battlefield._effect_panel_enemy_mount.global_position
	var p1_deck_position := (battlefield._deck_panels[1] as Control).global_position
	var p2_deck_position := (battlefield._deck_panels[2] as Control).global_position
	var standard_positions := battlefield._arena_overlay.get_team_standard_centers()
	battlefield._board_camera_center.y += 40.0
	battlefield._clamp_board_camera()
	battlefield._apply_board_camera_transform()
	var world_delta := tracked_slot.get_global_rect().position - position_before_pan
	_expect(world_delta.y < 0.0, "Kamera merkezi değişince savaş alanı hareket etmeli")
	_expect(
		((battlefield._field_name_badges[1] as Control).global_position - p1_name_position).distance_to(world_delta) < 0.1
		and ((battlefield._field_name_badges[2] as Control).global_position - p2_name_position).distance_to(world_delta) < 0.1
		and (battlefield._effect_panel_own_mount.global_position - own_effect_position).distance_to(world_delta) < 0.1
		and (battlefield._effect_panel_enemy_mount.global_position - enemy_effect_position).distance_to(world_delta) < 0.1
		and ((battlefield._deck_panels[1] as Control).global_position - p1_deck_position).distance_to(world_delta) < 0.1
		and ((battlefield._deck_panels[2] as Control).global_position - p2_deck_position).distance_to(world_delta) < 0.1
		and ((battlefield._arena_overlay.get_team_standard_centers()[1] as Vector2) - (standard_positions[1] as Vector2)).distance_to(world_delta) < 0.1
		and ((battlefield._arena_overlay.get_team_standard_centers()[2] as Vector2) - (standard_positions[2] as Vector2)).distance_to(world_delta) < 0.1,
		"Taglar, semboller, Etki Kartları ve desteler kamera ile aynı dünya hareketini izlemeli"
	)
	battlefield._focus_board_region(-1)
	var opponent_focus_y := battlefield._board_camera_center.y
	battlefield._focus_board_region(1)
	var own_focus_y := battlefield._board_camera_center.y
	_expect(own_focus_y > opponent_focus_y, "Rakip ve Üs kısayolları savaş alanının farklı bölgelerine odaklanmalı")
	battlefield._fit_board_view()
	_expect(is_equal_approx(battlefield._board_zoom, battlefield._board_fit_zoom), "Sığdır kontrolü savaş alanının tamamını görünür kılmalı")
	battlefield._board_camera_center.x = -10000.0
	battlefield._clamp_board_camera()
	var leftmost_camera_x := battlefield._board_camera_center.x
	battlefield._board_camera_center.x = 10000.0
	battlefield._clamp_board_camera()
	var rightmost_camera_x := battlefield._board_camera_center.x
	_expect(
		rightmost_camera_x - leftmost_camera_x >= (BattlefieldUI.BOARD_HORIZONTAL_OVERSCROLL_MIN * 2.0) - 1.0,
		"Savaş alanı iki yana en az 190'ar dünya birimi kaydırılabilmeli"
	)
	var fitted_center_x := battlefield._board_world_size.x * 0.5
	battlefield._board_camera_center.x += 32.0
	battlefield._clamp_board_camera()
	_expect(
		not is_equal_approx(battlefield._board_camera_center.x, fitted_center_x),
		"Sığdır görünümünde bile alan yatay olarak biraz kaydırılabilmeli"
	)
	var empty_pointer := Vector2(
		battlefield._board_view_rect.end.x - 54.0,
		battlefield._board_view_rect.get_center().y
	)
	var left_press := InputEventMouseButton.new()
	left_press.button_index = MOUSE_BUTTON_LEFT
	left_press.pressed = true
	left_press.position = empty_pointer
	battlefield._input(left_press)
	_expect(battlefield._is_board_panning, "Boş arazide sol tık pan başlatmalı")
	var center_before_drag := battlefield._board_camera_center
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.position = empty_pointer + Vector2(22.0, 18.0)
	battlefield._input(drag_motion)
	_expect(
		battlefield._board_camera_center.x < center_before_drag.x
		and battlefield._board_camera_center.y < center_before_drag.y,
		"Sol tık sürükleme alanı hem yatay hem dikey taşımalı"
	)
	var left_release := InputEventMouseButton.new()
	left_release.button_index = MOUSE_BUTTON_LEFT
	left_release.pressed = false
	left_release.position = drag_motion.position
	battlefield._input(left_release)
	_expect(not battlefield._is_board_panning, "Sol tuş bırakılınca pan sona ermeli")
	battlefield._reset_board_view()
	_expect(is_equal_approx(battlefield._board_zoom, battlefield._get_default_board_zoom()), "Ortala kontrolü varsayılan net görünüme dönmeli")

func _test_core_control_bounds(battlefield: BattlefieldUI) -> void:
	var controls: Array[Control] = [
		battlefield._preview_panel,
		battlefield.end_turn_button,
		battlefield._board_navigation_panel,
	]
	for control in controls:
		_expect(control != null and _rect_inside_viewport(control.get_global_rect()), "%s 1280×720 dışına taşmamalı" % control.name)
	_expect(battlefield._preview_panel.size.y >= 260.0, "Kart önizlemesi okunur yüksekliği korumalı")
	_expect(
		battlefield._effect_panel != null
		and battlefield._effect_panel.get_parent() == battlefield._battlefield_world_objects
		and battlefield._preview_panel.size.y > battlefield._effect_panel_own_mount.get_global_rect().size.y * 2.0
		and not battlefield._preview_panel.get_global_rect().intersects(battlefield._effect_panel_own_mount.get_global_rect()),
		"Saha Etki Kartı sağ HUD'ı tüketmeden büyük önizlemeden ayrı kalmalı"
	)
	_expect(
		battlefield._preview_panel.get_global_rect().end.y <= battlefield.end_turn_button.get_global_rect().position.y + 0.5,
		"Kart önizlemesi ana faz düğmesinin üzerine taşmamalı"
	)

func _rect_inside_viewport(rect: Rect2) -> bool:
	var viewport_size := Vector2(root.size)
	return (
		rect.position.x >= -0.5
		and rect.position.y >= -0.5
		and rect.end.x <= viewport_size.x + 0.5
		and rect.end.y <= viewport_size.y + 0.5
	)

func _get_slot(battlefield: BattlefieldUI, player_id: int, slot_name: String) -> CardSlot:
	return battlefield.get_node("Player%dZone/Grid/%s" % [player_id, slot_name]) as CardSlot

func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)
	return hero

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_SIX_UI_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PHASE_SIX_UI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
