extends SceneTree

const DECK_SCRIPT := preload("res://scripts/deck_manager.gd")
const PROFILE_SCRIPT := preload("res://scripts/profile_manager.gd")
const CAMPAIGN_PANEL_SCRIPT := preload("res://scripts/scenario_campaign_panel.gd")
const BRIEFING_PANEL_SCRIPT := preload("res://scripts/scenario_briefing_panel.gd")
const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")
const MATCH_CONFIGURATOR := preload("res://scripts/scenario_match_configurator.gd")
const TEST_DECK_PATH := "user://v0_7_campaign_setup_decks.json"
const TEST_PROFILE_PATH := "user://v0_7_campaign_setup_profile.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	SafeJsonStore.remove_family(TEST_DECK_PATH, 0)
	var deck_repository := DECK_SCRIPT.new()
	deck_repository.storage_path = TEST_DECK_PATH
	root.add_child(deck_repository)
	await process_frame

	var load_result := SCENARIO_CATALOG.load_catalog(true)
	_expect(bool(load_result.get("success", false)), "Senaryo kataloğu yüklenemedi")
	var scenarios := SCENARIO_CATALOG.get_scenarios()
	for scenario in scenarios:
		var scenario_id := str(scenario.get("id", ""))
		var setup := scenario.get("setup", {}) as Dictionary
		var result := MATCH_CONFIGURATOR.configure(scenario_id, deck_repository)
		_expect(bool(result.get("success", false)), "%s kurulamadı" % scenario_id)
		_expect(MatchSetup.match_mode == MatchSetup.MatchMode.AI, "%s AI maçı olmalı" % scenario_id)
		_expect(MatchSetup.get_scenario_id() == scenario_id, "%s bağlamı korunmalı" % scenario_id)
		_expect(MatchSetup.forced_first_player_id == int(setup.get("forced_first_player_id", 0)), "%s ilk oyuncusu sabitlenmeli" % scenario_id)
		_expect(is_equal_approx(MatchSetup.turn_duration_seconds, float(setup.get("turn_duration_seconds", 0))), "%s tur süresi uygulanmalı" % scenario_id)
		_expect(MatchSetup.auto_attack_allowed == bool(setup.get("auto_attack_allowed", true)), "%s otomatik saldırı tercihi uygulanmalı" % scenario_id)
		_expect(MatchSetup.get_forced_effect_card(1) == str(setup.get("player_effect_card_id", "")), "%s oyuncu Etki Kartını sabitlemeli" % scenario_id)
		_expect(MatchSetup.get_forced_effect_card(2) == str(setup.get("opponent_effect_card_id", "")), "%s rakip Etki Kartını sabitlemeli" % scenario_id)
		_expect(not MatchSetup.get_player_deck(1).is_empty(), "%s oyuncu destesi boş olmamalı" % scenario_id)
		_expect(not MatchSetup.get_player_deck(2).is_empty(), "%s rakip destesi boş olmamalı" % scenario_id)
		var expects_dominion := str(scenario.get("ruleset", "")) == "dominion"
		_expect(MatchSetup.is_dominion() == expects_dominion, "%s oyun kuralı uygulanmalı" % scenario_id)

	var configured_scenario_id := MatchSetup.get_scenario_id()
	var missing_result := MATCH_CONFIGURATOR.configure("olmayan_senaryo", deck_repository)
	_expect(not bool(missing_result.get("success", true)), "Bilinmeyen senaryo reddedilmeli")
	_expect(MatchSetup.get_scenario_id() == configured_scenario_id, "Geçersiz kurulum etkin bağlamı bozmamalı")

	var profile_repository := PROFILE_SCRIPT.new()
	profile_repository.configure_storage_path(TEST_PROFILE_PATH, true)
	root.add_child(profile_repository)
	await process_frame
	var campaign_panel := CAMPAIGN_PANEL_SCRIPT.new()
	campaign_panel.configure_profile_manager(profile_repository)
	root.add_child(campaign_panel)
	await process_frame
	var requested_scenarios: Array[String] = []
	campaign_panel.scenario_requested.connect(func(scenario_id: String): requested_scenarios.append(scenario_id))
	campaign_panel.open_panel()
	await process_frame
	_expect(campaign_panel.is_open(), "Komutan Seferi paneli açılmalı")
	_expect(campaign_panel.get_scenario_count() == 6, "Komutan Seferi paneli altı senaryo göstermeli")
	_expect(campaign_panel.get_selected_scenario_id() == "cepheye_ilk_adim", "Temiz profilde ilk senaryo seçilmeli")
	var first_button := campaign_panel.find_child("ScenarioButton_cepheye_ilk_adim", true, false) as Button
	var second_button := campaign_panel.find_child("ScenarioButton_enerji_disiplini", true, false) as Button
	_expect(first_button != null and not first_button.disabled, "İlk senaryo düğmesi kullanılabilir olmalı")
	_expect(second_button != null and second_button.disabled, "İkinci senaryo temiz profilde kilitli olmalı")
	campaign_panel.call("_on_start_pressed")
	_expect(requested_scenarios == ["cepheye_ilk_adim"], "Başlat düğmesi seçili senaryoyu istemeli")
	campaign_panel.close_panel()
	_expect(not campaign_panel.is_open(), "Komutan Seferi paneli kapanmalı")
	var briefing_panel := BRIEFING_PANEL_SCRIPT.new()
	root.add_child(briefing_panel)
	await process_frame
	var first_scenario := SCENARIO_CATALOG.get_scenario("cepheye_ilk_adim")
	var first_context := SCENARIO_CATALOG.build_match_context("cepheye_ilk_adim")
	var partial_summary := {
		"match_id": "briefing-smoke",
		"winner_id": 0,
		"players": {1: {"heroes_played": 1, "settlements_played": 1}},
	}
	briefing_panel.open_panel(first_scenario, first_context, partial_summary, 1)
	_expect(briefing_panel.is_open(), "Savaş içi senaryo brifingi açılmalı")
	_expect(briefing_panel.get_objective_count() == 3, "Brifing üç zorunlu hedef göstermeli")
	_expect(briefing_panel.get_completed_objective_count() == 2, "Brifing canlı hedef ilerlemesini hesaplamalı")
	partial_summary["winner_id"] = 1
	briefing_panel.update_match_state(partial_summary, 1)
	_expect(bool(briefing_panel.get_evaluation().get("completed", false)), "Brifing maç sonu tamamlanmasını hesaplamalı")
	briefing_panel.close_panel()

	briefing_panel.queue_free()
	campaign_panel.queue_free()
	profile_repository.queue_free()
	deck_repository.queue_free()
	await process_frame
	SafeJsonStore.remove_family(TEST_PROFILE_PATH, ProfileRepository.BACKUP_COUNT)
	SafeJsonStore.remove_family(TEST_DECK_PATH, 0)
	MatchSetup.configure_local(1)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_CAMPAIGN_SETUP_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_CAMPAIGN_SETUP_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
