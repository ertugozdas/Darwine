extends SceneTree

const SAVE_PATH := "user://dominion_active_match_smoke.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	SafeJsonStore.remove_family(SAVE_PATH, ActiveMatchRepository.BACKUP_COUNT)
	var snapshot := await _build_snapshot()
	await _restore_snapshot(snapshot)
	SafeJsonStore.remove_family(SAVE_PATH, ActiveMatchRepository.BACKUP_COUNT)
	MatchSetup.configure_local(1)
	_finish()


func _build_snapshot() -> Dictionary:
	MatchSetup.configure_local(11101)
	MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
	MatchSetup.set_match_name("Hakimiyet Kayıt Testi")
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	battlefield._active_match_repository.configure_path(SAVE_PATH)
	root.add_child(battlefield)
	current_scene = battlefield
	for _frame in range(5):
		await process_frame
	var manager := battlefield.get_node("GameManager") as GameManager
	while manager.current_phase == GameManager.TurnPhase.EFFECT_SELECTION:
		var offer := manager.get_effect_offer(manager.active_player_id)
		if offer.is_empty():
			break
		manager.submit_effect_selection(manager.active_player_id, offer[0], false)
	if manager.current_phase == GameManager.TurnPhase.MULLIGAN:
		manager.confirm_mulligan(manager.active_player_id)
		manager.confirm_mulligan(manager.active_player_id)
	manager.round_count = 4
	manager.player_dominion_score = {1: 5, 2: 3}
	manager.last_dominion_lane_results = [
		{"lane_id": CardSlot.Lane.LEFT, "owner_id": 1, "control": {1: 3, 2: 2}},
		{"lane_id": CardSlot.Lane.CENTER, "owner_id": 0, "control": {1: 2, 2: 2}},
		{"lane_id": CardSlot.Lane.RIGHT, "owner_id": 2, "control": {1: 1, 2: 3}},
	]
	var snapshot := battlefield.build_active_match_snapshot("test")
	_expect(int(snapshot.get("ruleset", -1)) == MatchSetup.Ruleset.DOMINION, "Aktif maç kaydı Hakimiyet ruleset kimliğini taşımalı")
	var manager_data := snapshot.get("manager", {}) as Dictionary
	_expect(
		int((manager_data.get("player_dominion_score", {}) as Dictionary).get(1, 0)) == 5,
		"Aktif maç kaydı Hakimiyet skorunu taşımalı"
	)
	var save_result := battlefield._active_match_repository.save_snapshot(snapshot)
	_expect(bool(save_result.get("success", false)), "Hakimiyet aktif maç kaydı diske yazılmalı")

	battlefield.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	return snapshot


func _restore_snapshot(snapshot: Dictionary) -> void:
	MatchSetup.configure_local(int(snapshot.get("seed", 11101)))
	MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
	MatchSetup.set_resume_snapshot(snapshot)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	battlefield._active_match_repository.configure_path(SAVE_PATH)
	root.add_child(battlefield)
	current_scene = battlefield
	for _frame in range(8):
		await process_frame

	var manager := battlefield.get_node("GameManager") as GameManager
	_expect(MatchSetup.is_dominion(), "Devam edilen maç Hakimiyet ruleset'ini korumalı")
	_expect(manager.round_count == 4, "Devam edilen Hakimiyet maçı raundu korumalı")
	_expect(int(manager.player_dominion_score.get(1, 0)) == 5, "Devam edilen maç Oyuncu 1 Hakimiyet skorunu korumalı")
	_expect(int(manager.player_dominion_score.get(2, 0)) == 3, "Devam edilen maç Oyuncu 2 Hakimiyet skorunu korumalı")
	_expect(manager.last_dominion_lane_results.size() == 3, "Devam edilen maç son koridor çözümünü korumalı")
	var own_score_label := battlefield.top_hud.get("_own_dominion_label") as Label
	_expect(own_score_label != null and "5 / 12" in own_score_label.text, "Devam edilen maç HUD skorunu geri yüklemeli")
	var save_status := battlefield._active_match_repository.inspect_save()
	_expect(str(save_status.get("state", "")) == "valid", "Hakimiyet aktif maç dosyası doğrulanabilir kalmalı")

	battlefield._active_match_completed = true
	battlefield.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DOMINION_PERSISTENCE_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("DOMINION_PERSISTENCE_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
