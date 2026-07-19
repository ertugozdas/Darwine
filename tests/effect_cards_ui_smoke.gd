extends SceneTree

const SELECTION_CAPTURE := "/tmp/tdm_effect_selection.png"
const PANEL_CAPTURE := "/tmp/tdm_effect_panel.png"
const GALLERY_CAPTURE := "/tmp/tdm_effect_gallery.png"

var _failures: Array[String] = []
var _captures_written := 0
var _previous_tutorial_enabled := true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	root.size = Vector2i(1280, 720)
	var settings_manager := root.get_node_or_null("SettingsManager")
	if settings_manager:
		_previous_tutorial_enabled = bool(settings_manager.get("tutorial_enabled"))
		settings_manager.call("set_tutorial_enabled", false)
	ActiveMatchRepository.new().delete_all()
	await _test_templates()
	await _test_battlefield_selection_and_privacy()
	await _test_gallery()
	ActiveMatchRepository.new().delete_all()
	if settings_manager:
		settings_manager.call("set_tutorial_enabled", _previous_tutorial_enabled)
	MatchSetup.configure_local(1)
	_finish()


func _test_templates() -> void:
	CardDatabase.load_all(true)
	var definitions := [
		{"rarity": "common", "id": "yapi_ustalari", "label": "YAYGIN"},
		{"rarity": "rare", "id": "oncu_doktrini", "label": "NADİR"},
		{"rarity": "epic", "id": "dovme_ocagi", "label": "DESTANSI"},
		{"rarity": "legendary", "id": "son_direnis", "label": "EFSANEVİ"},
	]
	for definition in definitions:
		var scene_path := "res://scenes/card_templates/effect_%s.tscn" % str(definition.rarity)
		var packed := load(scene_path) as PackedScene
		_expect(packed != null, "%s yüklenemedi" % scene_path)
		if not packed:
			continue
		var card := packed.instantiate() as EffectCard
		_expect(card != null, "%s EffectCard üretmedi" % scene_path)
		if not card:
			continue
		card.card_id = str(definition.id)
		root.add_child(card)
		await process_frame
		var type_label := card.get_node_or_null("CardFrame/TypeLabel") as Label
		var rarity_label := card.get_node_or_null("CardFrame/RarityLabel") as Label
		var persistent_badge := card.get_node_or_null("CardFrame/PersistentBadge") as Label
		var gold_badge := card.get_node_or_null("CardFrame/GoldBadge") as Control
		_expect(type_label != null and type_label.text == "ETKİ", "%s ETKİ tür etiketi göstermiyor" % scene_path)
		_expect(rarity_label != null and rarity_label.text == str(definition.label), "%s doğru Türkçe nadirlik etiketini göstermiyor" % scene_path)
		_expect(persistent_badge != null and "KALICI" in persistent_badge.text and "AKTİF" in persistent_badge.text, "%s kalıcı/aktif işareti taşımıyor" % scene_path)
		_expect(card.energy_cost == 0 and not card.is_draggable, "%s Enerji veya sürükleme davranışı taşıyor" % scene_path)
		_expect(gold_badge == null or not gold_badge.visible, "%s Enerji rozeti gösteriyor" % scene_path)
		for badge_name in ["AttackBadge", "ArmorBadge", "HealthBadge", "StatsContainer", "RuntimeStateRail"]:
			var badge := card.get_node_or_null("CardFrame/%s" % badge_name) as Control
			_expect(badge == null or not badge.visible, "%s %s savaş rozeti gösteriyor" % [scene_path, badge_name])
		var art := card.get_node_or_null("CardFrame/ArtRect") as TextureRect
		_expect(art != null and card.card_art != null, "%s ortak veri kaynağından görsel yüklemedi" % scene_path)
		_expect(card.card_description == str(CardDatabase.get_card("effects", str(definition.id)).get("description", "")), "%s açıklamayı merkezi veriden okumuyor" % scene_path)
		card.queue_free()
		await process_frame


func _test_battlefield_selection_and_privacy() -> void:
	MatchSetup.configure_local(65001)
	MatchSetup.fast_mode = true
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	while battlefield._is_dealing_initial_hands:
		await process_frame
	await process_frame
	var manager := battlefield.game_manager as GameManager
	manager.call("_reset_match_state")
	_expect(manager.begin_effect_selection(1), "Etki Kartı seçim fazı yeniden başlatılamadı")
	await process_frame
	_expect(battlefield._effect_selection_overlay.visible, "Etki Kartı seçim overlay'i açılmadı")
	_expect(battlefield._effect_handoff.visible and not battlefield._effect_offer_row.visible, "Yerel hot-seat gizli oyuncu devir ekranıyla başlamadı")
	_expect("GİZLİ SEÇİM" in battlefield._effect_selection_title.text, "Gizli seçim başlığı görünmüyor")

	battlefield.call("_reveal_effect_offers")
	await process_frame
	_expect(battlefield._effect_offer_row.visible and not battlefield._effect_handoff.visible, "Oyuncu hazır olduktan sonra teklifler açılmadı")
	_expect(battlefield._effect_offer_cards.size() == 3, "Seçim overlay'i üç Etki Kartı göstermiyor")
	_expect(
		battlefield._effect_confirm_button != null
		and battlefield._effect_confirm_button.visible
		and battlefield._effect_confirm_button.disabled,
		"Tek ortak SEÇ düğmesi kart seçilene kadar pasif görünmeli"
	)
	_expect(battlefield._effect_offer_stages.size() == 3, "Üç teklif de tıklanabilir kart yüzeyi taşımalı")
	var offer_ids: Array[String] = []
	for card in battlefield._effect_offer_cards:
		_expect(card is EffectCard and not card.is_draggable, "Teklif normal/sürüklenebilir kart kullandı")
		_expect(card.normal_scale.x >= 0.83, "Teklif kartı önceki küçük ölçüden daha büyük gösterilmeli")
		offer_ids.append(card.card_id)
	_expect(_unique_count(offer_ids) == 3, "Seçim overlay'i yinelenen teklifler gösterdi")
	await _capture(SELECTION_CAPTURE)

	var first_choice := offer_ids[0]
	battlefield.call("_on_effect_offer_pressed", first_choice)
	_expect(
		battlefield._selected_effect_offer_id == first_choice
		and not battlefield._effect_confirm_button.disabled
		and battlefield._effect_confirm_button.text == "SEÇ",
		"Karta tıklamak seçimi vurgulayıp ortak SEÇ düğmesini açmalı"
	)
	var selected_card := (battlefield._effect_offer_stages[first_choice] as Dictionary).get("card") as EffectCard
	battlefield.call("_on_effect_offer_hover_changed", first_choice, true)
	_expect(selected_card != null and selected_card.normal_scale.x > BattlefieldUI.EFFECT_OFFER_CARD_SCALE.x, "Üzerine gelinen teklif kartı hafif büyümeli")
	battlefield.call("_on_effect_offer_hover_changed", first_choice, false)
	battlefield.call("_confirm_effect_offer_selection")
	await process_frame
	_expect(manager.get_selected_effect_card(1) == first_choice, "Birinci oyuncunun Etki Kartı ortak SEÇ düğmesiyle uygulanmadı")
	_expect(battlefield._effect_handoff.visible and not battlefield._effect_offer_row.visible, "Birinci seçimden sonra ikinci oyuncu için gizli devir ekranı açılmadı")
	_expect(battlefield._effect_offer_cards.is_empty(), "Birinci oyuncunun teklifleri ikinci oyuncuya görünür kaldı")
	battlefield.call("_reveal_effect_offers")
	await process_frame
	var second_offer := manager.get_effect_offer(2)
	_expect(second_offer.size() == 3 and battlefield._effect_offer_cards.size() == 3, "İkinci oyuncunun bağımsız üçlü teklifi gösterilmedi")
	var second_choice := second_offer[0]
	battlefield.call("_on_effect_offer_pressed", second_choice)
	battlefield.call("_confirm_effect_offer_selection")
	await process_frame
	_expect(manager.get_selected_effect_card(2) == second_choice, "İkinci oyuncunun Etki Kartı ortak SEÇ düğmesiyle uygulanmadı")

	manager.active_player_id = 1
	battlefield.call("_refresh_effect_card_panel")
	battlefield.call("_apply_responsive_layout")
	await process_frame
	_expect(battlefield._effect_panel.visible, "Saha içi Etki Kartı nesneleri görünmüyor")
	_expect(battlefield._effect_panel.get_parent() == battlefield._battlefield_world_objects, "Etki Kartları oyun dünyası katmanına bağlı olmalı")
	_expect(battlefield._effect_panel_own_card is EffectCard, "Oyuncunun kendi Etki Kartı ortak template ile açık gösterilmedi")
	_expect(battlefield._effect_panel_own_card != null and battlefield._effect_panel_own_card.card_id == first_choice, "Sağ saha nesnesi yanlış Etki Kartını gösteriyor")
	_expect(not battlefield._effect_panel_own_card.is_draggable, "Sahadaki Etki Kartı sürüklenebilir")
	var enemy_back := battlefield._effect_panel_enemy_mount.get_node_or_null("NeutralEffectBack") as TextureRect
	_expect(enemy_back != null and enemy_back.texture != null and enemy_back.visible, "Rakip Etki Kartı nötr kart arkasıyla kapatılmadı")
	_expect(not _contains_effect_card(battlefield._effect_panel_enemy_mount), "Rakip slotu gizlice açık EffectCard düğümü taşıyor")
	_expect(battlefield._effect_panel_enemy_label.text == "RAKİP  •  GİZLİ", "Rakip slotu kimlik/nadirlik sızdırmayan etiketi kullanmıyor")
	var second_data := CardDatabase.get_card("effects", second_choice)
	_expect(not _tree_contains_text(battlefield._effect_panel_enemy_mount, str(second_data.get("name", ""))), "Rakip Etki Kartı adı kapalı slotta sızdı")
	_expect(not _tree_contains_text(battlefield._effect_panel_enemy_mount, str(second_data.get("rarity", ""))), "Rakip Etki Kartı nadirliği kapalı slotta sızdı")
	_expect(not battlefield._effect_panel_own_mount.get_global_rect().intersects(battlefield._preview_panel.get_global_rect()), "Etki Kartı nesnesi kart önizleme alanını kapatıyor")
	_expect(battlefield._effect_panel_own_mount.get_global_rect().intersects(battlefield._board_view_rect), "Etki Kartı nesnesi savaş alanının içinde görünmeli")
	var own_effect_local_rect := battlefield._effect_panel_own_mount.get_rect()
	var enemy_effect_local_rect := battlefield._effect_panel_enemy_mount.get_rect()
	_expect(
		absf(own_effect_local_rect.get_center().x - enemy_effect_local_rect.get_center().x) < 0.1
		and absf(own_effect_local_rect.get_center().y + enemy_effect_local_rect.get_center().y - battlefield._board_world_size.y) < 0.1,
		"Oyuncunun açık ve rakibin kapalı Etki Kartları tam karşılıklı dünya ankrajlarında olmalı"
	)
	_expect(battlefield._can_preview_card(battlefield._effect_panel_own_card), "Sahadaki Etki Kartı büyük önizlemeye açılabilmeli")
	battlefield.call("_show_card_preview", battlefield._effect_panel_own_card)
	await process_frame
	_expect(battlefield._preview_card is EffectCard, "Sahadaki Etki Kartı sağdaki büyük önizlemeyi açmalı")
	_expect(battlefield._preview_panel.size.y > battlefield._effect_panel_own_mount.get_global_rect().size.y * 2.0, "Sağ önizleme alanı saha Etki Kartından belirgin büyük kalmalı")
	_expect("BU TUR HAZIR" in battlefield._effect_panel_state_label.text, "Kendi kartında tur başına hazır durumu görünmüyor")
	for viewport_size in [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		await process_frame
		battlefield.call("_apply_responsive_layout")
		await process_frame
		var panel_rect := battlefield._effect_panel_own_mount.get_global_rect()
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_expect(
			viewport_rect.intersects(panel_rect),
			"Oyuncunun Etki Kartı %s çözünürlükte görünür kameradan tamamen kopuyor: card=%s viewport=%s" % [viewport_size, panel_rect, viewport_rect]
		)
		_expect(not panel_rect.intersects(battlefield._preview_panel.get_global_rect()), "Etki Kartı nesnesi %s çözünürlükte önizlemeyi kapatıyor" % viewport_size)
		_expect(panel_rect.intersects(battlefield._board_view_rect), "Etki Kartı nesnesi %s çözünürlükte savaş alanından kopuyor" % viewport_size)
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await process_frame
	battlefield.call("_apply_responsive_layout")
	await process_frame
	manager.mark_effect_triggered(1, "fixture_trigger", {"card_id": first_choice})
	await process_frame
	_expect("BU TUR TETİKLENDİ" in battlefield._effect_panel_state_label.text, "Kendi kartında Türkçe tetik göstergesi güncellenmedi")
	await _capture(PANEL_CAPTURE)

	# Game-over presentation must not reveal the opponent card by default.
	manager.finish_game(1)
	await process_frame
	_expect(enemy_back.visible and battlefield._effect_panel_enemy_label.text == "RAKİP  •  GİZLİ", "Maç sonunda rakip Etki Kartı açıldı")
	_expect(not _tree_contains_text(battlefield._effect_panel_enemy_mount, str(second_data.get("name", ""))), "Maç sonunda rakip Etki Kartı adı sızdı")

	battlefield._active_match_completed = true
	battlefield.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _test_gallery() -> void:
	var menu := (load("res://main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	menu.call("_show_gallery")
	await process_frame
	menu.call("_set_gallery_filter", "effects")
	await process_frame
	var grid := menu.find_child("CardGrid", true, false) as GridContainer
	_expect(grid != null and grid.get_child_count() == 13, "Galeri Etki Kartları filtresi on üç kart göstermiyor")
	var filter_buttons := menu.get("_filter_buttons") as Dictionary
	var effect_filter := filter_buttons.get("effects") as Button
	_expect(effect_filter != null and "13" in effect_filter.text, "Galeri Etki Kartları filtresi oluşturulmadı")
	if grid:
		for cell in grid.get_children():
			var gallery_card := cell.find_child("GalleryCard_effects_*", true, false) as EffectCard
			_expect(gallery_card != null, "Galeri Etki Kartında ortak EffectCard template'ini kullanmıyor")
	await _capture(GALLERY_CAPTURE)

	var legendary_cell := grid.find_child("GalleryCell_effects_son_direnis", true, false) if grid else null
	var inspect_button := legendary_cell.find_child("InspectButton", true, false) as Button if legendary_cell else null
	_expect(inspect_button != null, "Son Direniş galeride incelenebilir değil")
	if inspect_button:
		inspect_button.pressed.emit()
		await process_frame
		var detail_card := menu.find_child("DetailCard", true, false) as EffectCard
		var meta_label := menu.get("_detail_meta_label") as Label
		var stats_label := menu.get("_detail_stats_label") as Label
		_expect(detail_card != null and detail_card.card_id == "son_direnis", "Galeri ayrıntısı doğru Etki Kartını açmadı")
		_expect(meta_label != null and "KALICI PASİF" in meta_label.text and "ENERJİ" not in meta_label.text, "Etki Kartı ayrıntısı Enerji yerine kalıcı pasif meta bilgisini göstermiyor")
		_expect(stats_label != null and "ENERJİ VE SAVAŞ DEĞERİ YOK" in stats_label.text, "Etki Kartı ayrıntısı savaş değeri olmadığını açıklamıyor")

	menu.queue_free()
	current_scene = null
	await process_frame


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("EFFECT_CAPTURE_SKIPPED_DUMMY path=%s" % path)
		return
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s görseli yakalanamadı" % path)
	if image != null and not image.is_empty():
		_expect(image.get_size() == Vector2i(1280, 720), "%s 1280×720 değil" % path)
		if image.save_png(path) == OK:
			_captures_written += 1
		else:
			_expect(false, "%s PNG olarak kaydedilemedi" % path)


func _tree_contains_text(node: Node, needle: String) -> bool:
	if needle.is_empty():
		return false
	if node is Label and needle.to_lower() in (node as Label).text.to_lower():
		return true
	if node is RichTextLabel and needle.to_lower() in (node as RichTextLabel).text.to_lower():
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false


func _contains_effect_card(node: Node) -> bool:
	for child in node.get_children():
		if child is EffectCard or _contains_effect_card(child):
			return true
	return false


func _unique_count(values: Array) -> int:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("EFFECT_CARDS_UI_SMOKE_OK captures=%d" % _captures_written)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("EFFECT_CARDS_UI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
