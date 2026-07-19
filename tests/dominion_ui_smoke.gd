extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	await _test_battlefield_hud_and_lane_badges()
	await _test_siege_hides_dominion_ui()
	await _test_menu_and_help_copy()
	MatchSetup.configure_local(1)
	_finish()


func _test_battlefield_hud_and_lane_badges() -> void:
	MatchSetup.configure_local(7001)
	MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	await process_frame
	await process_frame

	var hud := battlefield.get_node("TopHud") as TopHud
	var score_labels := hud.find_children("DominionScore", "Label", true, false)
	_expect(score_labels.size() == 2, "HUD iki Hakimiyet skoru üretmeli")
	for label_variant in score_labels:
		_expect((label_variant as Label).visible, "Hakimiyet maçında skor etiketleri görünmeli")

	var p1_left := battlefield.get_node("Player1Zone/Grid/Slot_F1") as CardSlot
	var hero := HeroCard.new()
	hero.owner_id = 1
	p1_left.add_child(hero)
	hero.current_slot = p1_left
	p1_left.accept_card(hero)
	await process_frame
	battlefield._refresh_lane_visuals()
	var lane_badge := p1_left.get_node("DominionBadge") as Panel
	var lane_label := lane_badge.get_node("DominionLabel") as Label
	_expect(lane_badge.visible, "Hakimiyet koridor rozeti görünmeli")
	_expect("2" in lane_label.text and "0" in lane_label.text, "Koridor rozeti canlı 2–0 kontrol gücünü göstermeli")
	_expect("raund sonunda" in p1_left.tooltip_text.to_lower(), "Koridor açıklaması puanlama zamanını söylemeli")

	var manager := battlefield.get_node("GameManager") as GameManager
	manager.apply_dominion_round_result({
		"round_number": 1,
		"lane_results": DominionResolver.calculate_board(battlefield, 1).get("lane_results", []),
		"points_awarded": {1: 3, 2: 0},
	})
	await process_frame
	var own_score_label := hud.get("_own_dominion_label") as Label
	_expect(own_score_label != null and "3 / 12" in own_score_label.text, "HUD kazanılmış Hakimiyet puanını güncellemeli")

	battlefield.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _test_siege_hides_dominion_ui() -> void:
	MatchSetup.configure_local(7002)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	await process_frame
	await process_frame
	var hud := battlefield.get_node("TopHud") as TopHud
	for label_variant in hud.find_children("DominionScore", "Label", true, false):
		_expect(not (label_variant as Label).visible, "Kuşatma maçında Hakimiyet skoru gizli olmalı")
	for badge_variant in battlefield.find_children("DominionBadge", "Panel", true, false):
		_expect(not (badge_variant as Panel).visible, "Kuşatma maçında koridor Hakimiyet rozeti gizli olmalı")
	battlefield.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _test_menu_and_help_copy() -> void:
	var menu := (load("res://main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	menu.call("_show_difficulty_selection")
	await process_frame
	var siege_button := menu.find_child("SiegeRulesetButton", true, false) as Button
	var dominion_button := menu.find_child("DominionRulesetButton", true, false) as Button
	var host_siege_button := menu.find_child("HostSiegeRulesetButton", true, false) as Button
	var host_dominion_button := menu.find_child("HostDominionRulesetButton", true, false) as Button
	_expect(siege_button != null and siege_button.button_pressed, "Oyun ayarları varsayılan olarak Kuşatma seçmeli")
	_expect(dominion_button != null, "Oyun ayarlarında Hakimiyet seçeneği bulunmalı")
	_expect(host_siege_button != null and host_dominion_button != null, "Çevrimiçi oda kurucusu ruleset seçimi sunmalı")
	menu.call("_set_ruleset", MatchSetup.Ruleset.DOMINION)
	await process_frame
	var description := menu.find_child("RulesetDescription", true, false) as Label
	var summary := menu.find_child("GameSetupSummary", true, false) as Label
	var game_name_input := menu.find_child("GameNameInput", true, false) as LineEdit
	_expect(dominion_button != null and dominion_button.button_pressed, "Hakimiyet seçimi etkinleşmeli")
	_expect(host_dominion_button != null and host_dominion_button.button_pressed, "Çevrimiçi oda seçimi Hakimiyet ile eşleşmeli")
	_expect(description != null and "12 puana" in description.text, "Hakimiyet seçimi kısa kural açıklaması göstermeli")
	_expect(summary != null and "Hakimiyet" in summary.text, "Maç özeti seçili kurallar bütününü göstermeli")
	_expect(game_name_input != null and game_name_input.text == "Yeni Hakimiyet", "Hakimiyet varsayılan maç adını ruleset ile eşlemeli")
	menu.call("_set_multiplayer_ruleset_locked", true)
	_expect(host_siege_button.disabled and host_dominion_button.disabled, "Oda açılınca çevrimiçi ruleset değiştirilememeli")
	menu.call("_set_multiplayer_ruleset_locked", false)

	MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
	var tutorial := FirstMatchTutorial.new()
	root.add_child(tutorial)
	await process_frame
	tutorial.open_tutorial()
	_expect("Hakimiyet" in CardKeywordGlossary.get_reference_text(), "Hızlı kural rehberi Hakimiyet kurallarını açıklamalı")
	var found_objective_copy := false
	for label_variant in tutorial.find_children("*", "Label", true, false):
		if "12 puana" in (label_variant as Label).text:
			found_objective_copy = true
			break
	_expect(found_objective_copy, "İlk maç öğreticisi Hakimiyet hedefini göstermeli")

	tutorial.queue_free()
	menu.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DOMINION_UI_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("DOMINION_UI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
