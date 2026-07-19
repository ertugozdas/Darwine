extends SceneTree

const TEST_PATH := "user://profile_persistence_sync_smoke.json"

var _failures: Array[String] = []


class FakeProfileProvider extends ProfileSyncProvider:
	var last_request_id := ""
	var last_request: Dictionary = {}

	func is_available() -> bool:
		return true

	func get_account_id() -> String:
		return "account-smoke"

	func begin_sync(request_id: String, request: Dictionary) -> bool:
		last_request_id = request_id
		last_request = request.duplicate(true)
		return true

	func complete(result: Dictionary) -> void:
		sync_completed.emit(last_request_id, result.duplicate(true))


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var repository := root.get_node_or_null("ProfileManager") as ProfileRepository
	_expect(repository != null, "ProfileManager autoload yüklenmedi")
	if not repository:
		_finish()
		return

	_test_migration(repository)
	_test_backup_recovery(repository)
	_test_online_merge(repository)

	repository.set_sync_provider(null)
	repository.configure_storage_path(ProfileRepository.DEFAULT_SAVE_PATH, false)
	SafeJsonStore.remove_family(TEST_PATH, ProfileRepository.BACKUP_COUNT)
	_finish()


func _test_migration(repository: ProfileRepository) -> void:
	SafeJsonStore.remove_family(TEST_PATH, ProfileRepository.BACKUP_COUNT)
	var legacy := {
		"save_version": 1,
		"commander_name": "Eski Komutan",
		"level": 3,
		"xp": 17,
		"seals": 41,
		"stats": {"matches": 2, "wins": 1},
		"history": [{"match_id": "legacy-match", "result": "Zafer"}],
		"unlocked_titles": ["sancak_tasiyicisi"],
		"unlocked_banners": ["kul_ve_pirinc"],
	}
	var write_result := SafeJsonStore.write_dictionary_atomic(TEST_PATH, legacy, ProfileRepository.BACKUP_COUNT)
	_expect(bool(write_result.get("success", false)), "Eski profil fixture'ı yazılamadı")
	repository.configure_storage_path(TEST_PATH, false)
	var migrated := repository.get_profile()
	_expect(int(migrated.get("save_version", 0)) == ProfileRepository.SAVE_VERSION, "Profil en güncel şemaya migrate edilmedi")
	_expect(str(migrated.get("commander_name", "")) == "Eski Komutan", "Migration komutan bilgisini korumadı")
	_expect(migrated.get("decks") is Dictionary and migrated.get("settings") is Dictionary, "Migration deste ve ayar önbelleklerini oluşturmadı")
	_expect(migrated.get("competitive") is Dictionary and migrated.get("sync") is Dictionary, "Migration rekabetçi ve sync alanlarını oluşturmadı")
	_expect((migrated.get("migration_history", []) as Array).size() >= 3, "v1→güncel migration adımları kaydedilmedi")
	_expect(not str(migrated.get("profile_id", "")).is_empty(), "Migration sonrası kalıcı profil kimliği üretilmedi")


func _test_backup_recovery(repository: ProfileRepository) -> void:
	_expect(repository.set_commander_name("Yedek Bir"), "İlk yedek değişikliği yazılamadı")
	_expect(repository.set_commander_name("Yedek İki"), "İkinci yedek değişikliği yazılamadı")
	_expect(FileAccess.file_exists(SafeJsonStore.backup_path(TEST_PATH, 1)), "Profil yedeği oluşturulmadı")

	# Atomik yazımın primary rename adımında kesilmesini taklit et: canlı dosya
	# yokken mevcut yedek doğrudan kurtarılabilmeli.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	repository.configure_storage_path(TEST_PATH, false)
	_expect(repository.get_last_load_status() == "yedekten_kurtarıldı", "Eksik ana profil geçerli yedekten kurtarılmadı")
	_expect(str(repository.get_profile().get("commander_name", "")).begins_with("Yedek"), "Eksik primary kurtarması profil verisini korumadı")

	# Bir sonraki yüklemede bozuk ana dosya da aynı yedek zincirini kullanmalı.
	var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	_expect(corrupt != null, "Bozuk profil fixture'ı açılamadı")
	if corrupt:
		corrupt.store_string("{ bu geçerli json değil")
		corrupt = null
	repository.configure_storage_path(TEST_PATH, false)
	_expect(repository.get_last_load_status() == "yedekten_kurtarıldı", "Bozuk profil geçerli yedekten kurtarılmadı")
	_expect(int(repository.get_profile().get("save_version", 0)) == ProfileRepository.SAVE_VERSION, "Kurtarılan profil şeması geçersiz")


func _test_online_merge(repository: ProfileRepository) -> void:
	repository.configure_storage_path(TEST_PATH, true)
	_expect(repository.set_commander_name("Yerel Komutan"), "Yerel komutan değişikliği kuyruğa alınamadı")
	repository.update_settings_cache({"updated_at_unix": 200, "values": {"music_volume": 0.35}}, true)
	repository.update_decks_cache({"updated_at_unix": 100, "active_deck_id": "local", "decks": [{"id": "local"}]}, true)
	var local_match := {
		"match_id": "sync-shared-match",
		"seed": 77,
		"winner_id": 1,
		"round_count": 4,
		"duration_seconds": 80.0,
		"players": {1: {"cards_played": 3}, 2: {"cards_played": 2}},
	}
	var recorded := repository.record_match(local_match, 1, "Yerel", "Yerel Deste")
	_expect(bool(recorded.get("recorded", false)), "Sync fixture maçı profile işlenmedi")

	var pending_before := repository.get_pending_sync_operations()
	_expect(pending_before.size() >= 4, "Çevrimdışı değişiklikler güvenli kuyruğa alınmadı")
	var operation_ids := {}
	for operation_variant in pending_before:
		var operation := operation_variant as Dictionary
		var operation_id := str(operation.get("operation_id", ""))
		_expect(not operation_id.is_empty() and operation_id == str(operation.get("idempotency_key", "")), "Sync işlemi idempotency anahtarı taşımıyor")
		_expect(not operation_ids.has(operation_id), "Sync işlem kimliği yinelendi")
		operation_ids[operation_id] = true

	var provider := FakeProfileProvider.new()
	repository.set_sync_provider(provider)
	var begin_result := repository.begin_online_sync()
	_expect(bool(begin_result.get("success", false)), "Gerçek sağlayıcı sözleşmesiyle sync başlatılamadı")
	_expect(str(provider.last_request.get("account_id", "")) == "account-smoke", "Sync isteği hesap kimliğini taşımıyor")
	_expect((provider.last_request.get("pending_operations", []) as Array).size() == pending_before.size(), "Sync isteği çevrimdışı kuyruğu eksik taşıyor")

	var local_profile := repository.get_profile()
	var authoritative_stats := (local_profile.get("stats", {}) as Dictionary).duplicate(true)
	authoritative_stats["matches"] = 42
	authoritative_stats["wins"] = 24
	var acknowledged_id := str((pending_before[0] as Dictionary).get("operation_id", ""))
	provider.complete({
		"success": true,
		"server_authoritative": true,
		"revision": 12,
		"acknowledged_operation_ids": [acknowledged_id],
		"profile": {
			"level": 9,
			"xp": 11,
			"total_xp": 900,
			"seals": 777,
			"stats": authoritative_stats,
			"competitive": {"rating": 1540, "tier": "Altın"},
			"unlocked_titles": ["sunucu_unvani"],
			"unlocked_banners": ["sunucu_sancagi"],
			"selected_title": "sunucu_unvani",
			"selected_banner": "sunucu_sancagi",
			"history": [
				{"match_id": "sync-shared-match", "result": "Sunucu Kaydı"},
				{"match_id": "server-only-match", "result": "Zafer"},
			],
			"settings": {"updated_at_unix": 150, "values": {"music_volume": 1.0}},
			"decks": {"updated_at_unix": 300, "active_deck_id": "remote", "decks": [{"id": "remote"}]},
			"commander_name": "Sunucu Komutanı",
			"commander_updated_at_unix": int(Time.get_unix_time_from_system()) + 100,
		},
	})

	var merged := repository.get_profile()
	_expect(int(merged.get("level", 0)) == 9 and int(merged.get("seals", 0)) == 777, "Para/ilerleme sunucu otoritesiyle değiştirilmedi")
	_expect(int((merged.get("stats", {}) as Dictionary).get("matches", 0)) == 42, "Rekabetçi istatistikler sunucu otoritesinden gelmedi")
	_expect(int((merged.get("competitive", {}) as Dictionary).get("rating", 0)) == 1540, "Rekabetçi profil bölümü uygulanmadı")
	_expect("sunucu_unvani" in (merged.get("unlocked_titles", []) as Array), "Kozmetik birleşim kümesi uzak unvanı kaybetti")
	_expect("sancak_tasiyicisi" in (merged.get("unlocked_titles", []) as Array), "Kozmetik birleşim kümesi yerel unvanı kaybetti")
	_expect(_history_match_count(merged.get("history", []) as Array, "sync-shared-match") == 1, "Maç geçmişi match_id ile tekilleştirilmedi")
	_expect(_history_match_count(merged.get("history", []) as Array, "server-only-match") == 1, "Sunucu maç geçmişi birleşime alınmadı")
	_expect(int((merged.get("settings", {}) as Dictionary).get("updated_at_unix", 0)) == 200, "Eski uzak ayarlar yeni yerel ayarların üzerine yazdı")
	_expect(str((merged.get("decks", {}) as Dictionary).get("active_deck_id", "")) == "remote", "Yeni uzak deste bölümü LWW ile uygulanmadı")
	_expect(str(merged.get("commander_name", "")) == "Sunucu Komutanı", "Yeni zaman damgalı komutan bilgisi uygulanmadı")
	_expect(repository.get_pending_sync_operations().size() == pending_before.size() - 1, "Yalnızca onaylanan sync işlemi kuyruktan çıkarılmadı")
	_expect(int((merged.get("sync", {}) as Dictionary).get("last_server_revision", 0)) == 12, "Sunucu sync revizyonu kaydedilmedi")

	# Base provider deliberately unavailable: local JSON must never masquerade as cloud.
	var unavailable_provider := ProfileSyncProvider.new()
	repository.set_sync_provider(unavailable_provider)
	var unavailable := repository.begin_online_sync()
	_expect(bool(unavailable.get("unavailable", false)), "Sağlayıcısız yerel profil sahte online kayıt gibi sunuldu")
	repository.set_sync_provider(null)
	provider.free()
	unavailable_provider.free()


func _history_match_count(history: Array, match_id: String) -> int:
	var count := 0
	for entry_variant in history:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("match_id", "")) == match_id:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PROFILE_PERSISTENCE_SYNC_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PROFILE_PERSISTENCE_SYNC_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
