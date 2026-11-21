extends SceneTree

const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")
const MATCH_TELEMETRY := preload("res://scripts/match_telemetry.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_result := SCENARIO_CATALOG.load_catalog(true)
	_expect(bool(load_result.get("success", false)), "v0.7 senaryo kataloğu yüklenemedi")
	var campaign := SCENARIO_CATALOG.get_campaign()
	var scenarios := SCENARIO_CATALOG.get_scenarios()
	_expect(str(campaign.get("release_version", "")) == "0.7", "Kampanya sürümü 0.7 olmalı")
	_expect(scenarios.size() == 6, "Komutan Seferi altı senaryo içermeli")
	for index in range(scenarios.size()):
		_expect(int(scenarios[index].get("order", 0)) == index + 1, "Senaryo sırası kesintisiz olmalı")
	_expect(str(scenarios[0].get("lesson", "")) == "deployment", "İlk senaryo yerleşimi öğretmeli")
	_expect(str(scenarios[-1].get("ruleset", "")) == "dominion", "Son senaryo Hakimiyet kullanmalı")

	var invalid_payload := {
		"schema_version": 1,
		"release_version": "0.7",
		"campaign_id": "bozuk",
		"campaign_title": "Bozuk",
		"scenarios": [scenarios[0].duplicate(true), scenarios[0].duplicate(true)],
	}
	var invalid_result := SCENARIO_CATALOG.validate_catalog(invalid_payload)
	_expect(not bool(invalid_result.get("success", true)), "Yinelenen senaryo kimliği reddedilmeli")
	var invalid_deck_scenarios := scenarios.duplicate(true)
	var invalid_deck_setup := (invalid_deck_scenarios[0].get("setup", {}) as Dictionary).duplicate(true)
	invalid_deck_setup["player_deck_id"] = "bilinmeyen_deste"
	invalid_deck_scenarios[0]["setup"] = invalid_deck_setup
	var invalid_deck_result := SCENARIO_CATALOG.validate_catalog({
		"schema_version": 1,
		"release_version": "0.7",
		"campaign_id": "bozuk_deste",
		"campaign_title": "Bozuk Deste",
		"scenarios": invalid_deck_scenarios,
	})
	_expect(not bool(invalid_deck_result.get("success", true)), "Bilinmeyen başlangıç destesi reddedilmeli")

	var context := SCENARIO_CATALOG.build_match_context("cepheye_ilk_adim")
	MatchSetup.configure_ai(MatchSetup.AIDifficulty.EASY, 707001)
	MatchSetup.set_scenario_context(context)
	_expect(MatchSetup.is_scenario_match(), "Senaryo bağlamı etkinleşmeli")
	_expect(MatchSetup.get_scenario_id() == "cepheye_ilk_adim", "Senaryo kimliği MatchSetup'ta korunmalı")
	var snapshot := {
		"match_id": MatchSetup.match_id,
		"seed": MatchSetup.match_seed,
		"match_mode": int(MatchSetup.match_mode),
		"ruleset": int(MatchSetup.ruleset),
		"scenario_context": MatchSetup.get_scenario_context(),
	}
	MatchSetup.configure_local(707002)
	_expect(not MatchSetup.is_scenario_match(), "Normal maç yapılandırması eski senaryo bağlamını temizlemeli")
	_expect(MatchSetup.configure_from_snapshot(snapshot), "Senaryo snapshot bağlamı yapılandırılabilmeli")
	_expect(MatchSetup.get_scenario_id() == "cepheye_ilk_adim", "Senaryo bağlamı snapshot'tan geri yüklenmeli")

	var telemetry := MATCH_TELEMETRY.new()
	root.add_child(telemetry)
	telemetry.setup(null, null, false)
	telemetry.call("_record", "card_played", {"player_id": 1, "card_type": "HeroCard", "energy_cost": 3, "card_name": "Fixture Hero", "lane": 1})
	telemetry.call("_record", "card_played", {"player_id": 1, "card_type": "SettlementCard", "energy_cost": 2, "card_name": "Fixture Structure", "lane": 1})
	telemetry.call("_record", "attack", {"player_id": 1, "target_is_hq": true, "lane": 1})
	telemetry.call("_record", "card_moved", {"player_id": 1, "from_lane": 0, "to_lane": 1})
	telemetry.call("_record", "effect", {"player_id": 1, "damage": 1, "healed": 0, "target_lane": 1})
	telemetry.call("_record", "card_destroyed", {"player_id": 2, "source_player_id": 1, "lane": 1})
	telemetry.call("_record", "effect_card_trigger", {"player_id": 1, "trigger_id": "fixture", "trigger_delta": 1})
	telemetry.call("_record", "phase_changed", {"player_id": 1, "unspent_energy": 2})
	var summary := telemetry.get_summary()
	var player_one := (summary.get("players", {}) as Dictionary).get(1, {}) as Dictionary
	_expect(int(summary.get("telemetry_schema_version", 0)) == 3, "Telemetri şema sürümü 3 olmalı")
	_expect(str(summary.get("scenario_id", "")) == "cepheye_ilk_adim", "Telemetri senaryo kimliğini taşımalı")
	_expect(int(player_one.get("heroes_played", 0)) == 1, "Kahraman kullanımı özetlenmeli")
	_expect(int(player_one.get("settlements_played", 0)) == 1, "Yapı kullanımı özetlenmeli")
	_expect(int(player_one.get("hq_attacks", 0)) == 1, "Merkez saldırısı özetlenmeli")
	_expect(int(player_one.get("cross_lane_moves", 0)) == 1, "Koridorlar arası hareket özetlenmeli")
	_expect(int(player_one.get("effect_resolutions", 0)) == 1, "Etki çözümü özetlenmeli")
	_expect(int(player_one.get("effect_card_triggers", 0)) == 1, "Etki Kartı tetiklemesi özetlenmeli")
	_expect(int(player_one.get("unspent_energy_at_combat", 0)) == 2, "Harcanmamış Enerji özetlenmeli")
	_expect(int(player_one.get("combat_phases", 0)) == 1, "Savaş fazı örnek sayısı özetlenmeli")
	_expect(int(player_one.get("max_unspent_energy_at_combat", 0)) == 2, "En yüksek harcanmamış Enerji özetlenmeli")
	var center_activity := (player_one.get("lane_activity", {}) as Dictionary).get("1", {}) as Dictionary
	_expect(int(center_activity.get("deployments", 0)) == 2, "Koridor yerleşimleri özetlenmeli")
	_expect(int(center_activity.get("attacks", 0)) == 1, "Koridor saldırıları özetlenmeli")
	_expect(int(center_activity.get("hq_attacks", 0)) == 1, "Koridor Merkez saldırıları özetlenmeli")
	_expect(int(center_activity.get("moves_in", 0)) == 1, "Koridora giriş hareketleri özetlenmeli")
	_expect(int(center_activity.get("effect_damage", 0)) == 1, "Koridor etki hasarı özetlenmeli")
	_expect(int(center_activity.get("cards_destroyed", 0)) == 1, "Koridor yıkımları özetlenmeli")

	telemetry.queue_free()
	await process_frame
	MatchSetup.configure_local(1)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_FOUNDATION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_FOUNDATION_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
