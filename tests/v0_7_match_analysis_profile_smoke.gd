extends SceneTree

const PROFILE_SCRIPT := preload("res://scripts/profile_manager.gd")
const MATCH_ANALYSIS := preload("res://scripts/match_analysis.gd")
const TEST_PATH := "user://v0_7_match_analysis_profile_smoke.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	SafeJsonStore.remove_family(TEST_PATH, ProfileRepository.BACKUP_COUNT)
	var repository := PROFILE_SCRIPT.new()
	repository.configure_storage_path(TEST_PATH, true)
	root.add_child(repository)
	await process_frame
	var summary := {
		"match_id": "analysis-profile-1",
		"winner_id": 1,
		"ruleset": MatchSetup.Ruleset.SIEGE,
		"ruleset_name": "Kuşatma",
		"round_count": 4,
		"duration_seconds": 80.0,
		"players": {
			1: {
				"cards_played": 4,
				"cards_destroyed": 1,
				"hq_damage": 6,
				"energy_spent": 14,
				"unspent_energy_at_combat": 4,
				"combat_phases": 4,
				"attacks_declared": 3,
				"hq_attacks": 1,
				"moves": 2,
				"cross_lane_moves": 1,
				"lane_activity": {"0": {}, "1": {"deployments": 2, "attacks": 3}, "2": {}},
			},
			2: {"lane_activity": {"0": {}, "1": {"deployments": 1}, "2": {}}},
		},
	}
	summary["match_analysis"] = MATCH_ANALYSIS.analyze(summary, 1)
	var result: Dictionary = repository.record_match(summary, 1, "Yapay Zekâ", "Analiz Destesi")
	_expect(bool(result.get("recorded", false)), "Analizli maç profile kaydedilmeli")
	var history := repository.get_history()
	_expect(history.size() == 1, "Analizli maç geçmişte yer almalı")
	if not history.is_empty():
		var stored := (history[0] as Dictionary).get("match_analysis", {}) as Dictionary
		_expect(bool(stored.get("valid", false)), "Açıklanabilir analiz geçmiş kaydında korunmalı")
		_expect(str(stored.get("ruleset_id", "")) == "siege", "Geçmiş analizi kural setini korumalı")
		_expect((stored.get("insights", []) as Array).size() == 3, "Geçmiş analizi üç içgörüyü korumalı")
	repository.queue_free()
	await process_frame
	SafeJsonStore.remove_family(TEST_PATH, ProfileRepository.BACKUP_COUNT)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_MATCH_ANALYSIS_PROFILE_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_MATCH_ANALYSIS_PROFILE_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
