extends SceneTree

const PROFILE_SCRIPT := preload("res://scripts/profile_manager.gd")
const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")
const OBJECTIVE_RESOLVER := preload("res://scripts/scenario_objective_resolver.gd")
const TEST_SAVE_PATH := "user://v0_7_campaign_progress_smoke.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_result := SCENARIO_CATALOG.load_catalog(true)
	_expect(bool(load_result.get("success", false)), "Senaryo kataloğu yüklenemedi")
	var campaign := SCENARIO_CATALOG.get_campaign()
	var campaign_id := str(campaign.get("campaign_id", ""))
	var first_scenario := SCENARIO_CATALOG.get_scenario("cepheye_ilk_adim")
	var second_scenario := SCENARIO_CATALOG.get_scenario("enerji_disiplini")

	var repository := PROFILE_SCRIPT.new()
	repository.configure_storage_path(TEST_SAVE_PATH, true)
	root.add_child(repository)
	await process_frame

	_expect(int(repository.get_profile().get("save_version", 0)) == 5, "Profil şeması v5 olmalı")
	_expect(repository.is_scenario_unlocked(campaign_id, first_scenario), "İlk senaryo açık başlamalı")
	_expect(not repository.is_scenario_unlocked(campaign_id, second_scenario), "İkinci senaryo başlangıçta kilitli olmalı")

	var context := SCENARIO_CATALOG.build_match_context("cepheye_ilk_adim")
	var summary := {
		"match_id": "campaign-smoke-1",
		"winner_id": 1,
		"players": {
			1: {
				"heroes_played": 1,
				"settlements_played": 1,
			},
		},
	}
	var evaluation := OBJECTIVE_RESOLVER.evaluate(context, summary, 1)
	_expect(bool(evaluation.get("completed", false)), "İlk senaryonun tüm zorunlu hedefleri tamamlanmalı")
	_expect(int(evaluation.get("completed_required_count", 0)) == 3, "Üç zorunlu hedef tamamlanmalı")

	var tampered_scenario := first_scenario.duplicate(true)
	tampered_scenario["reward"] = {"kind": "seals", "amount": 999}
	var first_result := repository.record_scenario_result(
		campaign_id,
		tampered_scenario,
		evaluation,
		"campaign-smoke-1"
	)
	_expect(bool(first_result.get("recorded", false)), "Senaryo sonucu kaydedilmeli")
	_expect(bool(first_result.get("completed_now", false)), "İlk tamamlama işaretlenmeli")
	_expect(int(first_result.get("seals_gained", 0)) == 10, "İlk tamamlama yalnız katalogdaki 10 Mührü kazandırmalı")
	_expect(int(repository.get_profile().get("seals", 0)) == 10, "Mühür bakiyesi güncellenmeli")
	_expect(repository.is_scenario_unlocked(campaign_id, second_scenario), "İlk tamamlamadan sonra ikinci senaryo açılmalı")

	var duplicate_result := repository.record_scenario_result(
		campaign_id,
		first_scenario,
		evaluation,
		"campaign-smoke-1"
	)
	_expect(bool(duplicate_result.get("duplicate", false)), "Aynı maç sonucu yinelenmemeli")
	_expect(int(repository.get_profile().get("seals", 0)) == 10, "Yinelenen sonuç tekrar ödül vermemeli")

	var replay_summary := summary.duplicate(true)
	replay_summary["match_id"] = "campaign-smoke-2"
	var replay_evaluation := OBJECTIVE_RESOLVER.evaluate(context, replay_summary, 1)
	var replay_result := repository.record_scenario_result(
		campaign_id,
		first_scenario,
		replay_evaluation,
		"campaign-smoke-2"
	)
	_expect(bool(replay_result.get("recorded", false)), "Farklı maç kimliğine sahip tekrar oynama kaydedilmeli")
	_expect(not bool(replay_result.get("completed_now", true)), "Tamamlanmış senaryo yeniden ilk tamamlama sayılmamalı")
	_expect(int(replay_result.get("seals_gained", -1)) == 0, "Tekrar oynama tamamlanma ödülü vermemeli")

	var state := repository.get_scenario_state(campaign_id, "cepheye_ilk_adim")
	_expect(bool(state.get("completed", false)), "Senaryo durumu tamamlandı olarak saklanmalı")
	_expect(int(state.get("attempts", 0)) == 2, "Yinelenmeyen iki deneme sayılmalı")

	repository.queue_free()
	await process_frame
	var reloaded_repository := PROFILE_SCRIPT.new()
	reloaded_repository.configure_storage_path(TEST_SAVE_PATH, false)
	root.add_child(reloaded_repository)
	await process_frame
	var persisted_state := reloaded_repository.get_scenario_state(campaign_id, "cepheye_ilk_adim")
	_expect(bool(persisted_state.get("completed", false)), "Kampanya ilerlemesi yeniden yüklemede korunmalı")
	_expect(int(persisted_state.get("attempts", 0)) == 2, "Deneme sayısı yeniden yüklemede korunmalı")
	_expect(int(reloaded_repository.get_profile().get("seals", 0)) == 10, "Ödül bakiyesi yeniden yüklemede korunmalı")

	reloaded_repository.queue_free()
	await process_frame
	SafeJsonStore.remove_family(TEST_SAVE_PATH, ProfileRepository.BACKUP_COUNT)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_CAMPAIGN_PROGRESS_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_CAMPAIGN_PROGRESS_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
