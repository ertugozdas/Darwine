extends SceneTree

const PROFILE_SCRIPT := preload("res://scripts/profile_manager.gd")
const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")
const OBJECTIVE_RESOLVER := preload("res://scripts/scenario_objective_resolver.gd")
const TEST_SAVE_PATH := "user://v0_7_campaign_end_to_end.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_result := SCENARIO_CATALOG.load_catalog(true)
	_expect(bool(load_result.get("success", false)), "Senaryo kataloğu yüklenemedi")
	var campaign := SCENARIO_CATALOG.get_campaign()
	var campaign_id := str(campaign.get("campaign_id", ""))
	var scenarios := SCENARIO_CATALOG.get_scenarios()
	var repository := PROFILE_SCRIPT.new()
	repository.configure_storage_path(TEST_SAVE_PATH, true)
	root.add_child(repository)
	await process_frame

	var expected_total_seals := 0
	for index in range(scenarios.size()):
		var scenario := scenarios[index]
		var scenario_id := str(scenario.get("id", ""))
		_expect(repository.is_scenario_unlocked(campaign_id, scenario), "%s sırası geldiğinde açık olmalı" % scenario_id)
		if index + 1 < scenarios.size():
			_expect(not repository.is_scenario_unlocked(campaign_id, scenarios[index + 1]), "%s tamamlanmadan sonraki senaryo kilitli olmalı" % scenario_id)
		var metrics := {}
		for objective_variant in scenario.get("objectives", []) as Array:
			if not objective_variant is Dictionary:
				continue
			var objective := objective_variant as Dictionary
			var metric := str(objective.get("metric", ""))
			if metric != "match_won":
				metrics[metric] = objective.get("target", 0)
		var match_id := "campaign-e2e-%02d" % (index + 1)
		var summary := {
			"match_id": match_id,
			"winner_id": 1,
			"players": {1: metrics},
		}
		var context := SCENARIO_CATALOG.build_match_context(scenario_id)
		var evaluation := OBJECTIVE_RESOLVER.evaluate(context, summary, 1)
		_expect(bool(evaluation.get("completed", false)), "%s hedefleri tamamlanmalı" % scenario_id)
		var result := repository.record_scenario_result(campaign_id, scenario, evaluation, match_id)
		_expect(bool(result.get("recorded", false)), "%s sonucu kaydedilmeli" % scenario_id)
		_expect(bool(result.get("completed_now", false)), "%s ilk kez tamamlanmalı" % scenario_id)
		var reward := scenario.get("reward", {}) as Dictionary
		var expected_seals := int(reward.get("amount", 0)) if str(reward.get("kind", "")) == "seals" else 0
		expected_total_seals += expected_seals
		_expect(int(result.get("seals_gained", 0)) == expected_seals, "%s katalog ödülünü vermeli" % scenario_id)

	_expect(expected_total_seals == 95, "Altı senaryonun toplam ilk tamamlama ödülü 95 Mühür olmalı")
	_expect(int(repository.get_profile().get("seals", 0)) == expected_total_seals, "Sefer ödülleri profile eksiksiz yazılmalı")
	for scenario in scenarios:
		var state := repository.get_scenario_state(campaign_id, str(scenario.get("id", "")))
		_expect(bool(state.get("completed", false)), "%s tamamlandı olarak saklanmalı" % str(scenario.get("id", "")))
		_expect(int(state.get("attempts", 0)) == 1, "%s tek denemede tamamlanmış olmalı" % str(scenario.get("id", "")))

	repository.queue_free()
	await process_frame
	SafeJsonStore.remove_family(TEST_SAVE_PATH, ProfileRepository.BACKUP_COUNT)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_CAMPAIGN_END_TO_END_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_CAMPAIGN_END_TO_END_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
