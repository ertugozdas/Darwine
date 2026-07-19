extends SceneTree

const DECK_REPOSITORY_SCRIPT := preload("res://scripts/deck_manager.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_repository_and_persistence()
	await _test_match_deck_integration()
	await _test_menu_editor_contract()
	_finish()


func _test_repository_and_persistence() -> void:
	var test_path := "user://deck_builder_smoke.json"
	_remove(test_path)
	var repository := DECK_REPOSITORY_SCRIPT.new()
	repository.storage_path = test_path
	root.add_child(repository)
	await process_frame

	var starters: Array[Dictionary] = repository.get_decks()
	_expect(starters.size() == 3, "Üç başlangıç arketipi oluşturulmalı")
	var expected_names := ["Muhafız Hattı", "Fırtına Hücumu", "Rünik Kontrol"]
	for index in range(starters.size()):
		var deck := starters[index]
		_expect(str(deck.get("name", "")) == expected_names[index], "Başlangıç destesi sırası ve adı sabit olmalı")
		var cards := deck.get("cards", []) as Array
		var validation: Dictionary = repository.validate_deck_cards(cards)
		_expect(bool(validation.get("success", false)), "%s 30 kart ve kopya sınırına uymalı" % expected_names[index])

	var active_cards: Array = repository.get_active_deck_cards()
	var create_result: Dictionary = repository.create_deck("Duman Testi", active_cards)
	_expect(bool(create_result.get("success", false)), "Geçerli desteden özel deste oluşturulabilmeli")
	var custom := create_result.get("deck", {}) as Dictionary
	var custom_id := str(custom.get("id", ""))
	_expect(not custom_id.is_empty() and not bool(custom.get("is_starter", true)), "Özel deste kimliği ve türü kaydedilmeli")
	_expect(bool(repository.set_active_deck(custom_id).get("success", false)), "Özel deste etkinleştirilebilmeli")

	var invalid_cards := active_cards.duplicate(true)
	invalid_cards.pop_back()
	var invalid_result: Dictionary = repository.save_deck(custom_id, "Eksik", invalid_cards)
	_expect(not bool(invalid_result.get("success", true)), "29 kartlık deste kaydedilememeli")
	var duplicate_overflow := active_cards.duplicate(true)
	duplicate_overflow[0] = duplicate_overflow[1].duplicate(true)
	duplicate_overflow[2] = duplicate_overflow[1].duplicate(true)
	_expect(
		not bool(repository.validate_deck_cards(duplicate_overflow).get("success", true)),
		"Bir karttan üç kopya içeren deste reddedilmeli"
	)

	repository.queue_free()
	await process_frame
	var reloaded := DECK_REPOSITORY_SCRIPT.new()
	reloaded.storage_path = test_path
	root.add_child(reloaded)
	await process_frame
	_expect(reloaded.get_active_deck_id() == custom_id, "Etkin deste diskten geri yüklenmeli")
	_expect(reloaded.get_deck(custom_id).get("cards", []).size() == GameRules.DECK_SIZE, "Özel deste kartları diskten geri yüklenmeli")
	reloaded.queue_free()
	await process_frame
	_remove(test_path)


func _test_match_deck_integration() -> void:
	var deck_manager := root.get_node_or_null("DeckManager")
	_expect(deck_manager != null, "DeckManager autoload olarak yüklenmeli")
	if not deck_manager:
		return
	var player_deck: Array = deck_manager.get_starter_deck_cards("firtina_hucumu")
	var ai_deck: Array = deck_manager.get_starter_deck_cards("muhafiz_hatti")
	MatchSetup.configure_ai(MatchSetup.AIDifficulty.EASY, 8128)
	MatchSetup.set_card_pool_mode(MatchSetup.CardPoolMode.DECK)
	MatchSetup.set_player_deck(1, player_deck, "Fırtına Hücumu")
	MatchSetup.set_player_deck(2, ai_deck, "Muhafız Hattı")
	MatchSetup.fast_mode = true
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	while battlefield._is_dealing_initial_hands:
		await process_frame
	var p1_physical := battlefield.get_hand_cards(1).size() + battlefield.get_deck_card_count(1)
	var p2_physical := battlefield.get_hand_cards(2).size() + battlefield.get_deck_card_count(2)
	_expect(p1_physical == GameRules.DECK_SIZE and p2_physical == GameRules.DECK_SIZE, "Seçilen desteler tam 30 fiziksel kartla maça girmeli")
	_expect(_all_cards_belong_to(player_deck, battlefield.get_hand_cards(1)), "Oyuncu eli etkin desteden gelmeli")
	_expect(_all_cards_belong_to(ai_deck, battlefield.get_hand_cards(2)), "AI eli zorluğa bağlı arketipten gelmeli")
	battlefield.queue_free()
	current_scene = null
	await process_frame

	MatchSetup.configure_ai(MatchSetup.AIDifficulty.EASY, 8128)
	MatchSetup.set_card_pool_mode(MatchSetup.CardPoolMode.ALL_CARDS)
	# Valid configured decks are deliberately present to prove that this mode
	# takes its composition from the complete playable pool instead.
	MatchSetup.set_player_deck(1, player_deck, "Yok Sayılacak Deste")
	MatchSetup.set_player_deck(2, ai_deck, "Yok Sayılacak Deste")
	MatchSetup.fast_mode = true
	var expected_all_cards_deck := CardDatabase.get_playable_card_refs()
	var all_cards_battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(all_cards_battlefield)
	current_scene = all_cards_battlefield
	while all_cards_battlefield._is_dealing_initial_hands:
		await process_frame
	for player_id in GameRules.PLAYER_IDS:
		var physical_refs := _collect_physical_card_refs(all_cards_battlefield, player_id)
		_expect(physical_refs.size() == expected_all_cards_deck.size(), "Tüm Kartlar modu oynanabilir kartların tamamını kullanmalı")
		_expect(
			_card_multiset(physical_refs) == _card_multiset(expected_all_cards_deck),
			"Tüm Kartlar modu oyuncu %d için eksiksiz oynanabilir havuzu kullanmalı" % player_id
		)
	all_cards_battlefield.queue_free()
	current_scene = null
	await process_frame
	MatchSetup.configure_local(1)


func _test_menu_editor_contract() -> void:
	var menu := (load("res://main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	_expect(menu.find_child("DecksButton", true, false) is Button, "Ana menü Desteler düğmesini göstermeli")
	menu.call("_show_deck_builder")
	await process_frame
	var overlay := menu.find_child("DeckBuilderOverlay", true, false) as Control
	_expect(overlay != null and overlay.visible, "Deste Atölyesi ana menüden açılmalı")
	var deck_panel := menu.find_child("DeckBuilderPanel", true, false) as Control
	var deck_title := menu.find_child("DeckBuilderTitle", true, false) as Label
	_expect(_is_horizontally_centered(deck_title, deck_panel), "Deste Atölyesi başlığı pencerenin ortasında olmalı")
	_expect(menu.find_child("SavedDeckList", true, false) is VBoxContainer, "Deste Atölyesi kayıtlı desteleri göstermeli")
	_expect(menu.find_child("DeckCollectionList", true, false) is VBoxContainer, "Deste Atölyesi kart havuzunu göstermeli")
	_expect(menu.find_child("CurrentDeckList", true, false) is VBoxContainer, "Deste Atölyesi seçili deste listesini göstermeli")
	var stats := menu.find_child("DeckStatsLabel", true, false) as Label
	_expect(stats != null and "30/30" in stats.text, "Deste Atölyesi kart sayısı ve dağılımını göstermeli")
	var save_button := menu.find_child("SaveDeckButton", true, false) as Button
	var activate_button := menu.find_child("ActivateDeckButton", true, false) as Button
	_expect(save_button != null and save_button.disabled, "Değişiklik yokken Kaydet düğmesi kapalı olmalı")
	_expect(activate_button != null and not activate_button.disabled, "Geçerli deste etkinleştirilebilir olmalı")
	menu.call("_hide_deck_builder")
	_expect(not overlay.visible, "Deste Atölyesi kapatılabilmeli")
	menu.queue_free()
	current_scene = null
	await process_frame


func _all_cards_belong_to(deck: Array, cards: Array[BaseCard]) -> bool:
	var allowed := {}
	for ref_variant in deck:
		if ref_variant is Dictionary:
			var ref := ref_variant as Dictionary
			allowed["%s/%s" % [ref.get("card_type", ""), ref.get("card_id", "")]] = true
	for card in cards:
		var deck_ref := card.get_meta("deck_ref", {}) as Dictionary
		if not allowed.has("%s/%s" % [deck_ref.get("card_type", ""), deck_ref.get("card_id", "")]):
			return false
	return true


func _collect_physical_card_refs(battlefield: BattlefieldUI, player_id: int) -> Array:
	var refs: Array = (battlefield._player_decks[player_id] as Array).duplicate(true)
	for card in battlefield.get_hand_cards(player_id):
		refs.append((card.get_meta("deck_ref", {}) as Dictionary).duplicate(true))
	return refs


func _card_multiset(cards: Array) -> Dictionary:
	var counts := {}
	for card_variant in cards:
		if not card_variant is Dictionary:
			continue
		var card := card_variant as Dictionary
		var key := "%s/%s" % [card.get("card_type", ""), card.get("card_id", "")]
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _is_horizontally_centered(control: Control, container: Control, tolerance := 1.5) -> bool:
	if control == null or container == null:
		return false
	return absf(control.get_global_rect().get_center().x - container.get_global_rect().get_center().x) <= tolerance


func _finish() -> void:
	if _failures.is_empty():
		print("DECK_BUILDER_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("DECK_BUILDER_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
