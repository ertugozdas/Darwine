extends SceneTree

const TELEMETRY_PATH := "user://dominion_telemetry_smoke.jsonl"
const PROFILE_PATH := "user://dominion_profile_smoke.json"
const PROFILE_PANEL_SCRIPT := preload("res://scripts/profile_panel.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_files()
	var summary := await _build_dominion_telemetry_summary()
	await _test_profile_migration_and_record(summary)
	_remove_test_files()
	MatchSetup.configure_local(1)
	_finish()


func _build_dominion_telemetry_summary() -> Dictionary:
	MatchSetup.configure_local(10101)
	MatchSetup.set_ruleset(MatchSetup.Ruleset.DOMINION)
	var manager := GameManager.new()
	root.add_child(manager)
	await process_frame
	var telemetry := MatchTelemetry.new()
	root.add_child(telemetry)
	telemetry.setup(manager, null, true, TELEMETRY_PATH)
	_expect(manager.begin_mulligan(1), "Hakimiyet telemetrisi için mulligan başlamalı")

	var lane_results: Array[Dictionary] = []
	for lane_id in DominionResolver.LANES:
		lane_results.append({
			"lane_id": lane_id,
			"owner_id": 1,
			"control": {1: 2, 2: 0},
		})
	for round_number in range(1, 5):
		manager.round_count = round_number
		manager.apply_dominion_round_result({
			"round_number": round_number,
			"lane_results": lane_results,
			"points_awarded": {1: 3, 2: 0},
		})

	var summary := telemetry.get_summary()
	_expect(bool(summary.get("finished", false)), "Hakimiyet telemetrisi maç sonunu kaydetmeli")
	_expect(int(summary.get("ruleset", -1)) == MatchSetup.Ruleset.DOMINION, "Özet Hakimiyet ruleset kimliğini taşımalı")
	_expect(str(summary.get("win_reason", "")) == "dominion", "Özet Hakimiyet zafer nedenini taşımalı")
	_expect(int(summary.get("first_dominion_score_round", 0)) == 1, "İlk Hakimiyet puanı raundu kaydedilmeli")
	_expect(int((summary.get("dominion_scores", {}) as Dictionary).get(1, 0)) == 12, "Özet final Hakimiyet skorunu taşımalı")
	_expect(int((summary.get("dominion_lane_wins", {}) as Dictionary).get(1, 0)) == 12, "Özet kazanılan koridor puanlarını toplamalı")
	var player_one := (summary.get("players", {}) as Dictionary).get(1, {}) as Dictionary
	_expect(int(player_one.get("dominion_score", 0)) == 12, "Oyuncu telemetrisi Hakimiyet skorunu taşımalı")
	_expect(int(player_one.get("dominion_points", 0)) == 12, "Oyuncu telemetrisi toplam koridor puanını taşımalı")
	_test_json_lines()

	telemetry.queue_free()
	manager.queue_free()
	await process_frame
	return summary


func _test_json_lines() -> void:
	var file := FileAccess.open(TELEMETRY_PATH, FileAccess.READ)
	_expect(file != null, "Hakimiyet JSONL telemetri dosyası oluşturulmalı")
	if not file:
		return
	var dominion_rounds := 0
	var found_end := false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if not parsed is Dictionary:
			continue
		var event := parsed as Dictionary
		if str(event.get("event", "")) == "dominion_round":
			dominion_rounds += 1
			_expect((event.get("total_control", {}) as Dictionary).has("1"), "Koridor olayı toplam kontrol verisini taşımalı")
		if str(event.get("event", "")) == "match_end":
			found_end = str(event.get("ruleset_name", "")) == "Hakimiyet" and str(event.get("win_reason", "")) == "dominion"
	_expect(dominion_rounds == 4, "Her tam Hakimiyet raundu ayrı telemetri olayı üretmeli")
	_expect(found_end, "Maç sonu JSONL satırı Hakimiyet zaferini açıklamalı")


func _test_profile_migration_and_record(summary: Dictionary) -> void:
	var profile_manager := root.get_node_or_null("ProfileManager")
	_expect(profile_manager != null, "ProfileManager autoload yüklenmeli")
	if not profile_manager:
		return
	var legacy_profile := {
		"save_version": 3,
		"commander_name": "Eski Komutan",
		"stats": {"matches": 1, "wins": 0},
		"history": [{
			"match_id": "legacy-siege",
			"result": "Mağlubiyet",
			"mode": "Yerel",
			"deck_name": "Eski Deste",
			"rounds": 3,
		}],
	}
	var write_result := SafeJsonStore.write_dictionary_atomic(PROFILE_PATH, legacy_profile, 3)
	_expect(bool(write_result.get("success", false)), "Eski profil test kaydı yazılmalı")
	profile_manager.configure_storage_path(PROFILE_PATH, false)
	var migrated: Dictionary = profile_manager.get_profile()
	_expect(int(migrated.get("save_version", 0)) == 5, "v3 profil Hakimiyet ve sefer alanlarıyla güncel v5'e taşınmalı")
	var migrated_stats := migrated.get("stats", {}) as Dictionary
	_expect(int(migrated_stats.get("dominion_matches", -1)) == 0, "Eski profilde Hakimiyet maç sayısı sıfırdan başlamalı")
	var migrated_history := migrated.get("history", []) as Array
	_expect(
		not migrated_history.is_empty() and str((migrated_history[0] as Dictionary).get("ruleset_name", "")) == "Kuşatma",
		"Eski geçmiş kayıtları Kuşatma olarak korunmalı"
	)

	var record_result: Dictionary = profile_manager.record_match(summary, 1, "Yapay Zekâ", "Hakimiyet Destesi")
	_expect(bool(record_result.get("recorded", false)), "Hakimiyet sonucu profile kaydedilmeli")
	_expect(int(record_result.get("xp_gained", 0)) == 103, "Hakimiyet aynı mevcut XP formülünü kullanmalı")
	var profile: Dictionary = profile_manager.get_profile()
	var stats := profile.get("stats", {}) as Dictionary
	_expect(int(stats.get("matches", 0)) == 2, "Genel maç sayacı Hakimiyet maçını içermeli")
	_expect(int(stats.get("dominion_matches", 0)) == 1, "Hakimiyet maç sayacı ilerlemeli")
	_expect(int(stats.get("dominion_wins", 0)) == 1, "Hakimiyet zafer sayacı ilerlemeli")
	_expect(int(stats.get("dominion_points", 0)) == 12, "Hakimiyet puan toplamı ilerlemeli")
	var history: Array = profile_manager.get_history()
	var newest := history[0] as Dictionary
	_expect(str(newest.get("ruleset_name", "")) == "Hakimiyet", "Geçmiş ruleset adını göstermeli")
	_expect(str(newest.get("win_reason", "")) == "dominion", "Geçmiş zafer nedenini saklamalı")
	_expect(int(newest.get("dominion_score", 0)) == 12, "Geçmiş oyuncu Hakimiyet skorunu saklamalı")
	_expect(int(newest.get("opponent_dominion_score", -1)) == 0, "Geçmiş rakip Hakimiyet skorunu saklamalı")

	var panel := PROFILE_PANEL_SCRIPT.new() as CommanderProfilePanel
	root.add_child(panel)
	await process_frame
	panel.open_panel()
	await process_frame
	_expect(panel.find_child("ProfileStatDominionMatches", true, false) is Label, "Profil Hakimiyet maç sayacını göstermeli")
	_expect(panel.find_child("ProfileStatDominionWins", true, false) is Label, "Profil Hakimiyet zafer sayacını göstermeli")
	_expect(panel.find_child("ProfileStatDominionPoints", true, false) is Label, "Profil Hakimiyet puan sayacını göstermeli")
	_expect(_tree_contains_text(panel, "Hakimiyet"), "Profil geçmişi Hakimiyet ruleset adını göstermeli")
	_expect(_tree_contains_text(panel, "12–0"), "Profil geçmişi Hakimiyet skorunu göstermeli")
	panel.queue_free()
	await process_frame
	profile_manager.configure_storage_path(ProfileRepository.DEFAULT_SAVE_PATH, false)


func _tree_contains_text(node: Node, needle: String) -> bool:
	if node is Label and needle in (node as Label).text:
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false


func _remove_test_files() -> void:
	SafeJsonStore.remove_family(PROFILE_PATH, 3)
	if FileAccess.file_exists(TELEMETRY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TELEMETRY_PATH))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DOMINION_TELEMETRY_PROFILE_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("DOMINION_TELEMETRY_PROFILE_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
