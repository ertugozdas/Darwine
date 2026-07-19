extends SceneTree

const TEST_PATH := "user://profile_progression_smoke.json"
const PROFILE_PANEL_SCRIPT := preload("res://scripts/profile_panel.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var repository := root.get_node_or_null("ProfileManager")
	_expect(repository != null, "ProfileManager autoload yüklenmedi")
	if not repository:
		_finish()
		return
	repository.configure_storage_path(TEST_PATH, true)
	var initial: Dictionary = repository.get_profile()
	_expect(int(initial.get("level", 0)) == 1, "Yeni profil birinci seviyeden başlamalı")
	_expect(int(initial.get("stats", {}).get("matches", -1)) == 0, "Yeni profil maç sayısı sıfır olmalı")
	_expect(repository.get_unlocked_titles().size() == 1, "Başlangıçta tek temel unvan açık olmalı")
	_expect(repository.get_unlocked_banners().size() == 1, "Başlangıçta tek temel sancak açık olmalı")

	var first_summary := _summary("profile-smoke-1", 1, 8, 7, 18, 3, "Siper Muhafızı")
	var first_result: Dictionary = repository.record_match(first_summary, 1, "Yapay Zekâ", "Muhafız Hattı")
	_expect(bool(first_result.get("recorded", false)), "İlk maç profile kaydedilmedi")
	_expect(int(first_result.get("xp_gained", 0)) > 0, "Maç XP kazandırmalı")
	_expect("İlk Sancak" in (first_result.get("new_achievements", []) as Array), "İlk zafer başarısı tamamlanmalı")
	var after_first: Dictionary = repository.get_profile()
	var first_stats := after_first.get("stats", {}) as Dictionary
	_expect(int(first_stats.get("matches", 0)) == 1 and int(first_stats.get("wins", 0)) == 1, "Zafer istatistikleri işlenmedi")
	_expect(_contains_cosmetic(repository.get_unlocked_titles(), "zafer_nobetcisi"), "İlk zafer kozmetik unvanı açılmadı")
	_expect(repository.select_title("zafer_nobetcisi"), "Açılmış unvan seçilemedi")
	_expect(not repository.select_banner("kilitli_sancak"), "Kilitli sancak seçilememeli")

	var duplicate: Dictionary = repository.record_match(first_summary, 1, "Yapay Zekâ", "Muhafız Hattı")
	_expect(not bool(duplicate.get("recorded", true)) and bool(duplicate.get("duplicate", false)), "Aynı maç iki kez yazılmamalı")
	_expect(repository.get_history().size() == 1, "Tekrarlanan maç geçmişi büyütmemeli")

	var second_summary := _summary("profile-smoke-2", 2, 6, 9, 4, 1, "Rün Mührü")
	var second_result: Dictionary = repository.record_match(second_summary, 1, "Çevrimiçi", "Rünik Kontrol")
	_expect(bool(second_result.get("recorded", false)), "İkinci maç profile kaydedilmedi")
	_expect("Meydana Çık" in (second_result.get("completed_missions", []) as Array), "İki maçlık günlük görev tamamlanmadı")
	var after_second: Dictionary = repository.get_profile()
	var second_stats := after_second.get("stats", {}) as Dictionary
	_expect(int(second_stats.get("matches", 0)) == 2, "Maç toplamı iki olmalı")
	_expect(int(second_stats.get("online_matches", 0)) == 1, "Çevrimiçi maç sayacı ilerlemedi")
	_expect(repository.get_history().size() == 2, "Maç geçmişi iki kayıt içermeli")
	_expect(str(repository.get_history()[0].get("match_id", "")) == "profile-smoke-2", "En yeni maç geçmişin başında olmalı")
	var daily_entries: Array = repository.get_mission_entries("daily")
	_expect(_mission_completed(daily_entries, "gunluk_meydan"), "Günlük görev tamamlanmış görünmeli")
	_expect(int(after_second.get("seals", 0)) >= 30, "Temel ve görev Mühür ödülleri eklenmedi")

	var panel := PROFILE_PANEL_SCRIPT.new() as CommanderProfilePanel
	root.add_child(panel)
	await process_frame
	panel.open_panel()
	await process_frame
	_expect(panel.visible and panel.is_open(), "Komutan profili açılamadı")
	var tabs := panel.find_child("ProfileTabs", true, false) as TabContainer
	_expect(tabs != null and tabs.get_tab_count() == 3, "Profil; komutanlık, görevler ve geçmiş olmak üzere üç sekmeli olmalı")
	_expect(panel.find_child("ProfileStatsGrid", true, false) is GridContainer, "Profil istatistik özeti bulunamadı")
	_expect(panel.find_child("AchievementList", true, false).get_child_count() == 4, "Başarı listesi eksik")
	_expect(panel.find_child("DailyMissionList", true, false).get_child_count() == 3, "Günlük görev listesi eksik")
	_expect(panel.find_child("WeeklyMissionList", true, false).get_child_count() == 3, "Haftalık görev listesi eksik")
	_expect(panel.find_child("MatchHistoryList", true, false).get_child_count() == 2, "Maç geçmişi satırları oluşturulmadı")
	_expect(panel.find_child("ProfileTitleOption", true, false) is OptionButton, "Unvan seçici bulunamadı")
	_expect(panel.find_child("ProfileBannerOption", true, false) is OptionButton, "Sancak seçici bulunamadı")
	panel.close_panel()
	panel.queue_free()
	await process_frame

	repository.configure_storage_path(ProfileRepository.DEFAULT_SAVE_PATH, false)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_finish()


func _summary(
	match_id: String,
	winner_id: int,
	rounds: int,
	cards_played: int,
	hq_damage: int,
	cards_destroyed: int,
	mvp_card_name: String
) -> Dictionary:
	return {
		"match_id": match_id,
		"seed": match_id.hash(),
		"winner_id": winner_id,
		"round_count": rounds,
		"duration_seconds": 185.0,
		"finished": true,
		"players": {
			1: {
				"cards_played": cards_played,
				"hq_damage": hq_damage,
				"cards_destroyed": cards_destroyed,
				"mvp_card_name": mvp_card_name,
			},
			2: {
				"cards_played": 5,
				"hq_damage": 6,
				"cards_destroyed": 1,
				"mvp_card_name": "Kara Mızrak",
			},
		},
	}


func _contains_cosmetic(entries: Array, cosmetic_id: String) -> bool:
	for entry_variant in entries:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("id", "")) == cosmetic_id:
			return true
	return false


func _mission_completed(entries: Array, mission_id: String) -> bool:
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		if str(entry.get("id", "")) == mission_id:
			return bool(entry.get("completed", false))
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PROFILE_PROGRESSION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
