extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale("tr")
	CardDatabase.load_all(true)
	_test_content_contract()
	await _test_supporting_ui_and_feedback_nodes()
	_finish()

func _test_content_contract() -> void:
	var playable_refs := CardDatabase.get_playable_card_refs()
	_expect(
		playable_refs.size() >= GameRules.STARTING_CARD_CONTENT_TARGET,
		"En az %d oynanabilir başlangıç kartı tamamlanmış olmalı" % GameRules.STARTING_CARD_CONTENT_TARGET
	)
	_expect(playable_refs.size() == 110, "İçerik seti 110 oynanabilir karta genişlemeli")
	_expect(_count_rarity("heroes", "RARE") == 24, "Kahraman havuzunda yirmi dört Nadir kart olmalı")
	_expect(_count_rarity("heroes", "EPIC") == 20, "Kahraman havuzunda yirmi Destansı kart olmalı")
	_expect(_count_rarity("heroes", "LEGENDARY") == 10, "Kahraman havuzunda on Efsanevi kart olmalı")
	_expect(_count_rarity("settlements", "COMMON", true) == 5, "Yapı havuzunda beş oynanabilir Yaygın kart olmalı")
	_expect(_count_rarity("settlements", "RARE", true) == 5, "Yapı havuzunda beş oynanabilir Nadir kart olmalı")
	_expect(_count_rarity("settlements", "EPIC", true) == 10, "Yapı havuzunda on oynanabilir Destansı kart olmalı")
	_expect(_count_rarity("special_powers", "COMMON") == 3, "Büyü havuzunda üç Yaygın kart olmalı")
	_expect(_count_rarity("special_powers", "RARE") == 7, "Büyü havuzunda yedi Nadir kart olmalı")
	_expect(_count_rarity("special_powers", "EPIC") == 7, "Büyü havuzunda yedi Destansı kart olmalı")
	_expect(_count_rarity("special_powers", "LEGENDARY") == 2, "Büyü havuzunda iki Efsanevi kart olmalı")
	_expect(_count_rarity("upgrades", "COMMON") == 4, "Beceri havuzunda dört Yaygın kart olmalı")
	_expect(_count_rarity("upgrades", "RARE") == 6, "Beceri havuzunda altı Nadir kart olmalı")
	_expect(_count_rarity("upgrades", "EPIC") == 5, "Beceri havuzunda beş Destansı kart olmalı")
	_expect(_count_rarity("upgrades", "LEGENDARY") == 2, "Beceri havuzunda iki Efsanevi kart olmalı")
	_expect(CardKeywordGlossary.KEYWORDS.size() == 31, "Ortak sözlük otuz bir anahtar kelimeyi açıklamalı")

	var supported_keyword_ids: Array = CardKeywordGlossary.KEYWORDS.keys()
	for card_ref_variant in playable_refs:
		var card_ref := card_ref_variant as Dictionary
		var card_type := str(card_ref.get("card_type", ""))
		var card_id := str(card_ref.get("card_id", ""))
		var card_data := CardDatabase.get_card(card_type, card_id)
		var card_label := "%s/%s" % [card_type, card_id]
		_expect(not str(card_data.get("name", "")).strip_edges().is_empty(), "%s adı eksik" % card_label)
		_expect(not str(card_data.get("description", "")).strip_edges().is_empty(), "%s açıklaması eksik" % card_label)
		_expect(ResourceLoader.exists(str(card_data.get("image_url", ""))), "%s görseli bulunamıyor" % card_label)

		if card_type in ["special_powers", "upgrades"]:
			_expect(
				str(card_data.get("description", "")).begins_with("Hedef:"),
				"%s hedef metni ortak 'Hedef:' diliyle başlamalı" % card_label
			)

		for tag_field in ["tags", "granted_tags"]:
			var tags_variant: Variant = card_data.get(tag_field, [])
			if not tags_variant is Array:
				continue
			for tag_variant in tags_variant:
				var tag_id := str(tag_variant).strip_edges().to_lower()
				_expect(tag_id in supported_keyword_ids, "%s sözlük dışı etiket taşıyor: %s" % [card_label, tag_id])

	var reference_text := CardKeywordGlossary.get_reference_text()
	for keyword_entry_variant in CardKeywordGlossary.KEYWORDS.values():
		var keyword_entry := keyword_entry_variant as Dictionary
		_expect(str(keyword_entry.get("name", "")) in reference_text, "Sözlük rehberi tüm anahtar kelime adlarını içermeli")
	for status_entry_variant in CardKeywordGlossary.STATUS_DEFINITIONS.values():
		var status_entry := status_entry_variant as Dictionary
		_expect(str(status_entry.get("name", "")) in reference_text, "Sözlük rehberi tüm geçici durumları içermeli")

func _count_rarity(card_type: String, rarity: String, playable_only := false) -> int:
	var count := 0
	for card_data_variant in CardDatabase.get_cards_for_type(card_type):
		var card_data := card_data_variant as Dictionary
		if playable_only and not bool(card_data.get("deck_enabled", true)):
			continue
		if str(card_data.get("rarity", "")) == rarity:
			count += 1
	return count

func _test_supporting_ui_and_feedback_nodes() -> void:
	var tutorial := FirstMatchTutorial.new()
	root.add_child(tutorial)
	await process_frame
	_expect(tutorial.get_step_count() == 5, "İlk maç öğreticisi beş kısa adımdan oluşmalı")
	_expect("Mavi yuva" in str(FirstMatchTutorial.STEPS[2].get("body", "")), "Öğretici hedef renklerinin anlamını açıklamalı")
	_expect("Taktik Değişim" in str(FirstMatchTutorial.STEPS[4].get("body", "")), "Öğretici yeni el taktiklerini açıklamalı")
	tutorial.open_tutorial(2)
	_expect(tutorial.is_open() and tutorial.get_current_step() == 2, "Öğretici istenen adımdan açılabilmeli")
	tutorial.close_tutorial(true)
	_expect(not tutorial.is_open(), "Öğretici atlanabilir olmalı")

	var reference := RulesReferencePanel.new()
	root.add_child(reference)
	await process_frame
	reference.open_reference()
	_expect("ANAHTAR KELİMELER" in reference.get_reference_text(), "Hızlı kural paneli ortak sözlüğü göstermeli")
	_expect("HEDEF VE KART AKIŞI" in reference.get_reference_text(), "Hızlı kural paneli hedef renkleri ve takviye çekişini açıklamalı")
	reference.close_reference()

	var feedback_layer := BattlefieldFeedbackLayer.new()
	root.add_child(feedback_layer)
	await process_frame
	feedback_layer.set_open_paths([{
		"from": Vector2(10.0, 20.0),
		"to": Vector2(220.0, 160.0),
		"color": Color.GREEN,
	}])
	_expect(feedback_layer.get_open_path_count() == 1, "Açık koridor katmanı kalıcı rotayı saklamalı")
	feedback_layer.play_attack_path(Vector2(10.0, 20.0), Vector2(120.0, 80.0))
	_expect(feedback_layer.attack_animation_count == 1, "Saldırı rotası animasyonu tetiklenebilmeli")

	var audio := FeedbackAudio.new()
	root.add_child(audio)
	await process_frame
	for event_id in ["attack", "damage", "heal", "destroy", "upgrade", "invalid", "victory"]:
		_expect(audio.has_event(event_id), "Ses sistemi '%s' olayını desteklemeli" % event_id)
	audio.set_muted(true)
	_expect(not audio.play_event("attack"), "Sessiz mod geri bildirim sesini çalmamalı")
	audio.set_muted(false)
	_expect(audio.play_event("attack"), "Ses açıkken geçerli olay çalınabilmeli")
	audio.set_muted(true)
	for player in audio._players:
		player.stream = null
	feedback_layer.stop_all_feedback()
	await create_timer(0.20).timeout

	for node in [tutorial, reference, feedback_layer, audio]:
		node.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_SIX_CONTENT_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PHASE_SIX_CONTENT_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
