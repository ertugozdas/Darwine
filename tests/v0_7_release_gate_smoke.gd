extends SceneTree

const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")
const RELEASE_NOTES := preload("res://scripts/release_notes_panel.gd")
const MATCH_TELEMETRY := preload("res://scripts/match_telemetry.gd")
const MATCH_ANALYSIS := preload("res://scripts/match_analysis.gd")
const DECK_ADVISOR := preload("res://scripts/deck_advisor.gd")

const RELEASE_VERSION := "0.7"
const RELEASE_STAGE := "RC"
const TEST_SAVE_PATH := "user://v0_7_release_gate_active.json"
const MANIFEST_PATH := "res://data/release/v0_7_rc_gates.json"
const RUNNER_PATH := "res://tools/run_v0_7_rc.ps1"
const LOCALES := ["en", "de", "fr", "it", "es", "tr"]
const EXPECTED_HEADERS := ["keys", "en", "de", "fr", "it", "es", "tr"]
const LOCALIZATION_SOURCES := [
	"ui.csv",
	"cards.csv",
	"card_descriptions.csv",
	"gameplay.csv",
	"tutorial.csv",
	"profile.csv",
	"decks.csv",
	"scenarios.csv",
	"analysis.csv",
	"deck_advisor.csv",
	"release_v0_7.csv",
]
const V0_7_LOCALIZATION_SOURCES := [
	"scenarios.csv",
	"analysis.csv",
	"deck_advisor.csv",
	"release_v0_7.csv",
]
const REQUIRED_GATE_IDS := [
	"release_contract",
	"scenario_balance",
	"siege_balance",
	"dominion_balance",
	"effect_card_balance",
	"active_match_save",
	"profile_persistence",
	"online_authority",
	"localization",
]

var _failures: Array[String] = []
var _placeholder_regex := RegEx.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_placeholder_regex.compile("%(?:\\d+\\$)?[-+0-9.#]*[a-zA-Z]")
	_test_release_identity()
	_test_contract_versions()
	_test_campaign_contract()
	_test_profile_migration_contract()
	_test_active_match_contract()
	_test_online_context_isolation()
	_test_localization_contract()
	_test_rc_manifest()
	MatchSetup.configure_local(1)
	_finish()


func _test_release_identity() -> void:
	_expect(
		str(ProjectSettings.get_setting("application/config/version", "")) == RELEASE_VERSION,
		"Uygulama sürümü 0.7 olmalı"
	)
	_expect(
		str(ProjectSettings.get_setting("application/config/release_stage", "")) == RELEASE_STAGE,
		"Uygulama sürüm aşaması RC olmalı"
	)
	_expect(not RELEASE_NOTES.RELEASES.is_empty(), "Sürüm notları boş olmamalı")
	if not RELEASE_NOTES.RELEASES.is_empty():
		var current := RELEASE_NOTES.RELEASES[0] as Dictionary
		_expect(str(current.get("version", "")) == RELEASE_VERSION, "Güncel sürüm notu 0.7 olmalı")
		_expect(str(current.get("stage", "")) == "CURRENT", "0.7 sürüm notu CURRENT olmalı")
		_expect((current.get("items", []) as Array).size() >= 8, "0.7 sürüm notu dört teslimi ve RC kapılarını açıklamalı")


func _test_contract_versions() -> void:
	_expect(ProfileRepository.SAVE_VERSION == 5, "Profil kayıt şeması v5 olmalı")
	_expect(ActiveMatchRepository.SAVE_SCHEMA_VERSION == 2, "Aktif maç kayıt şeması v2 olmalı")
	_expect(MATCH_TELEMETRY.TELEMETRY_SCHEMA_VERSION == 3, "Telemetri şeması v3 olmalı")
	_expect(MATCH_ANALYSIS.ANALYSIS_SCHEMA_VERSION == 1, "Maç analizi şeması v1 olmalı")
	_expect(DECK_ADVISOR.ADVISOR_SCHEMA_VERSION == 1, "Deste Danışmanı şeması v1 olmalı")


func _test_campaign_contract() -> void:
	var result := SCENARIO_CATALOG.load_catalog(true)
	_expect(bool(result.get("success", false)), "RC senaryo kataloğu doğrulanamadı")
	var scenarios := SCENARIO_CATALOG.get_scenarios()
	_expect(scenarios.size() == 6, "Komutan Seferi tam altı senaryo içermeli")
	var rewards := 0
	for scenario_variant in scenarios:
		if not scenario_variant is Dictionary:
			continue
		var scenario := scenario_variant as Dictionary
		rewards += int((scenario.get("reward", {}) as Dictionary).get("amount", 0))
		_expect(not (scenario.get("objectives", []) as Array).is_empty(), "%s senaryosu hedef taşımalı" % str(scenario.get("id", "")))
	_expect(rewards == 95, "Komutan Seferi toplam ilk tamamlama ödülü 95 Mühür olmalı")


func _test_profile_migration_contract() -> void:
	var repository := ProfileRepository.new()
	var migrated := repository.call("_migrate_profile", {
		"save_version": 4,
		"commander_name": "RC Eski Komutan",
		"stats": {},
		"history": [],
	}) as Dictionary
	_expect(int(migrated.get("save_version", 0)) == 5, "v4 profil v5 şemasına taşınmalı")
	_expect(migrated.get("campaigns", null) is Dictionary, "Profil göçü sefer bölümünü oluşturmalı")
	_expect(str(migrated.get("commander_name", "")) == "RC Eski Komutan", "Profil göçü mevcut veriyi korumalı")
	repository.free()


func _test_active_match_contract() -> void:
	SafeJsonStore.remove_family(TEST_SAVE_PATH, ActiveMatchRepository.BACKUP_COUNT)
	var repository := ActiveMatchRepository.new()
	repository.configure_path(TEST_SAVE_PATH)
	var legacy_snapshot := _minimal_snapshot("rc-legacy-save")
	_expect(bool(repository.validate_snapshot(legacy_snapshot).get("success", false)), "Senaryo alanı olmayan aktif kayıt geçerli kalmalı")

	MatchSetup.configure_local(70701)
	MatchSetup.set_scenario_context(SCENARIO_CATALOG.build_match_context("cepheye_ilk_adim"))
	_expect(MatchSetup.configure_from_snapshot(legacy_snapshot), "Eski aktif kayıt MatchSetup tarafından kabul edilmeli")
	_expect(MatchSetup.get_scenario_context().is_empty(), "Eski aktif kayıt önceki senaryo bağlamını temizlemeli")
	MatchSetup.take_resume_snapshot()

	var scenario_snapshot := _minimal_snapshot("rc-scenario-save")
	scenario_snapshot["scenario_context"] = SCENARIO_CATALOG.build_match_context("kanat_degistir")
	var save_result := repository.save_snapshot(scenario_snapshot)
	_expect(bool(save_result.get("success", false)), "Senaryolu aktif kayıt yazılabilmeli")
	var raw := SafeJsonStore.read_dictionary(TEST_SAVE_PATH)
	var payload := raw.get("data", {}) as Dictionary
	_expect(int(payload.get("save_schema_version", 0)) == 2, "Aktif kayıt kabı şema v2 yazmalı")
	var loaded := repository.load_primary()
	_expect(bool(loaded.get("success", false)), "Senaryolu aktif kayıt geri yüklenebilmeli")
	if bool(loaded.get("success", false)):
		var loaded_snapshot := loaded.get("snapshot", {}) as Dictionary
		_expect(MatchSetup.configure_from_snapshot(loaded_snapshot), "Senaryolu snapshot MatchSetup'a uygulanabilmeli")
		_expect(MatchSetup.get_scenario_id() == "kanat_degistir", "Senaryo bağlamı aktif kayıt turunda korunmalı")
		MatchSetup.take_resume_snapshot()
	SafeJsonStore.remove_family(TEST_SAVE_PATH, ActiveMatchRepository.BACKUP_COUNT)


func _test_online_context_isolation() -> void:
	var context := SCENARIO_CATALOG.build_match_context("doktrin_sinavi")
	MatchSetup.set_scenario_context(context)
	MatchSetup.configure_multiplayer_server(70711, "rc-server")
	_expect(MatchSetup.get_scenario_context().is_empty(), "Dedicated sunucu kurulumu sefer bağlamını temizlemeli")
	MatchSetup.set_scenario_context(context)
	MatchSetup.configure_multiplayer_client(70712, 2, "rc-client")
	_expect(MatchSetup.get_scenario_context().is_empty(), "Çevrimiçi istemci kurulumu sefer bağlamını temizlemeli")
	MatchSetup.set_scenario_context(context)
	MatchSetup.configure_multiplayer_host(70713, 1, "rc-host")
	_expect(MatchSetup.get_scenario_context().is_empty(), "Çevrimiçi host kurulumu sefer bağlamını temizlemeli")


func _test_localization_contract() -> void:
	var entries_by_key := {}
	for source_name in LOCALIZATION_SOURCES:
		var path := "res://localization/%s" % source_name
		var file := FileAccess.open(path, FileAccess.READ)
		_expect(file != null, "%s çeviri kaynağı açılamadı" % source_name)
		if not file:
			continue
		var headers := Array(file.get_csv_line(","))
		_expect(headers == EXPECTED_HEADERS, "%s dil başlıkları keys,en,de,fr,it,es,tr olmalı" % source_name)
		var source_keys := {}
		var row_count := 0
		while not file.eof_reached():
			var columns := Array(file.get_csv_line(","))
			if columns.size() == 1 and str(columns[0]).is_empty():
				continue
			row_count += 1
			_expect(columns.size() == EXPECTED_HEADERS.size(), "%s satırı yedi sütun taşımalı" % source_name)
			if columns.size() != EXPECTED_HEADERS.size():
				continue
			var key := str(columns[0]).strip_edges()
			_expect(not key.is_empty(), "%s boş çeviri anahtarı içermemeli" % source_name)
			if source_name in V0_7_LOCALIZATION_SOURCES:
				_expect(not source_keys.has(key), "%s yinelenen v0.7 anahtarı içeriyor: %s" % [source_name, key])
			source_keys[key] = true
			var english_signature := _placeholder_signature(str(columns[1]))
			var values: Array[String] = []
			for column_index in range(1, EXPECTED_HEADERS.size()):
				var locale := str(EXPECTED_HEADERS[column_index])
				var value := str(columns[column_index])
				values.append(value)
				_expect(not value.strip_edges().is_empty(), "%s / %s / %s çevirisi boş olmamalı" % [source_name, key, locale])
				_expect(
					_placeholder_signature(value) == english_signature,
					"%s / %s / %s biçim yer tutucularını korumalı" % [source_name, key, locale]
				)
			var entries: Array = entries_by_key.get(key, [])
			entries.append({"file": source_name, "signature": "\u001f".join(values)})
			entries_by_key[key] = entries
		_expect(row_count > 0, "%s en az bir çeviri satırı taşımalı" % source_name)

	for key_variant in entries_by_key.keys():
		var key := str(key_variant)
		var entries := entries_by_key[key] as Array
		var contains_v0_7_source := false
		var signatures := {}
		var source_names: Array[String] = []
		for entry_variant in entries:
			var entry := entry_variant as Dictionary
			var source_name := str(entry.get("file", ""))
			contains_v0_7_source = contains_v0_7_source or source_name in V0_7_LOCALIZATION_SOURCES
			signatures[str(entry.get("signature", ""))] = true
			source_names.append(source_name)
		_expect(
			not contains_v0_7_source or signatures.size() == 1,
			"v0.7 anahtarı kaynaklar arasında çelişmemeli: %s (%s)" % [key, ", ".join(source_names)]
		)

	var registered_variant: Variant = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	var registered := registered_variant as PackedStringArray if registered_variant is PackedStringArray else PackedStringArray()
	for source_name in LOCALIZATION_SOURCES:
		var base_name: String = str(source_name).trim_suffix(".csv")
		for locale in LOCALES:
			var resource_path := "res://localization/%s.%s.translation" % [base_name, locale]
			_expect(ResourceLoader.exists(resource_path), "%s üretilmiş çeviri kaynağı bulunmalı" % resource_path)
			_expect(resource_path in registered, "%s proje çeviri listesine kayıtlı olmalı" % resource_path)
			var translation := load(resource_path) as Translation
			_expect(translation != null and translation.locale == locale, "%s doğru locale ile yüklenmeli" % resource_path)


func _test_rc_manifest() -> void:
	_expect(FileAccess.file_exists(MANIFEST_PATH), "v0.7 RC kapı manifesti bulunmalı")
	_expect(FileAccess.file_exists(RUNNER_PATH), "v0.7 RC çalıştırıcısı bulunmalı")
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "v0.7 RC manifesti geçerli JSON olmalı")
	if not parsed is Dictionary:
		return
	var manifest := parsed as Dictionary
	_expect(int(manifest.get("schema_version", 0)) == 1, "RC manifest şeması v1 olmalı")
	_expect(str(manifest.get("release_version", "")) == RELEASE_VERSION, "RC manifesti 0.7 sürümünü hedeflemeli")
	_expect(str(manifest.get("release_stage", "")) == RELEASE_STAGE, "RC manifesti RC aşamasını hedeflemeli")
	var gates_variant: Variant = manifest.get("gates", [])
	_expect(gates_variant is Array, "RC manifesti kapı listesi taşımalı")
	if not gates_variant is Array:
		return
	var ids := {}
	for gate_variant in gates_variant as Array:
		if not gate_variant is Dictionary:
			_failures.append("RC manifestindeki her kapı sözlük olmalı")
			continue
		var gate := gate_variant as Dictionary
		var gate_id := str(gate.get("id", ""))
		_expect(not gate_id.is_empty() and not ids.has(gate_id), "RC kapı kimliği boş veya yinelenen olmamalı: %s" % gate_id)
		ids[gate_id] = true
		var test_path := str(gate.get("test", ""))
		_expect(test_path.begins_with("res://tests/") and FileAccess.file_exists(test_path), "%s kapısı geçerli test dosyasına bağlanmalı" % gate_id)
		_expect(str(gate.get("marker", "")).ends_with("_OK"), "%s kapısı açık başarı işareti taşımalı" % gate_id)
	for required_id in REQUIRED_GATE_IDS:
		_expect(ids.has(required_id), "RC manifestinde zorunlu kapı eksik: %s" % required_id)


func _minimal_snapshot(match_id: String) -> Dictionary:
	return {
		"match_id": match_id,
		"game_version": RELEASE_VERSION,
		"seed": 70700,
		"match_mode": MatchSetup.MatchMode.LOCAL,
		"match_name": "RC Sözleşme Maçı",
		"ruleset": MatchSetup.Ruleset.SIEGE,
		"manager": {},
		"zones": {},
		"rng": {},
		"effect_cards": {},
	}


func _placeholder_signature(value: String) -> String:
	var tokens: Array[String] = []
	for result in _placeholder_regex.search_all(value):
		tokens.append(result.get_string())
	tokens.sort()
	return "|".join(tokens)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_RELEASE_GATE_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_RELEASE_GATE_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
