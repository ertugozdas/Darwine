extends SceneTree

var _failures: Array[String] = []
var _save_request := {"name": "", "id": ""}
var _load_request := ""
var _delete_request := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("en")
	_expect(tr("KARTLAR") == "CARDS", "Kartlar başlığı İngilizce çeviriye bağlanmadı")
	_expect(tr("KAYIT YÜKLE") == "LOAD SAVE", "Kayıt Yükle başlığı İngilizce çeviriye bağlanmadı")
	_expect(tr("İKİ OYUN MODU") == "TWO GAME MODES", "Yeni oyun modu rehberi İngilizce çeviriye bağlanmadı")
	TranslationServer.set_locale("tr")
	var unique_suffix := "%d" % Time.get_ticks_usec()
	var first_slot_id := "smoke-north-%s" % unique_suffix
	var second_slot_id := "smoke-dominion-%s" % unique_suffix
	var repository := ActiveMatchRepository.new()
	repository.delete_slot(first_slot_id)
	repository.delete_slot(second_slot_id)

	var first_snapshot := _fixture_snapshot("save-slots-north", "Kuzey Kapısı", MatchSetup.Ruleset.SIEGE, 2, 5)
	var first_save := repository.save_snapshot_to_slot(first_snapshot, "Kuzey Kapısı", first_slot_id)
	_expect(bool(first_save.get("success", false)), "İlk adlandırılmış kayıt slotu yazılamadı")
	_expect(str(first_save.get("slot_id", "")) == first_slot_id, "İlk slot kimliği korunmadı")
	_expect(str(first_save.get("slot_name", "")) == "Kuzey Kapısı", "İlk slot adı korunmadı")

	# Writing the same slot again must overwrite the primary and keep a safe backup.
	var updated_snapshot := _fixture_snapshot("save-slots-north", "Kuzey Kapısı", MatchSetup.Ruleset.SIEGE, 3, 7)
	var overwrite := repository.save_snapshot_to_slot(updated_snapshot, "Kuzey Kapısı", first_slot_id)
	_expect(bool(overwrite.get("success", false)), "Mevcut slotun üzerine güvenli kayıt yazılamadı")
	var first_status := repository.inspect_slot(first_slot_id)
	_expect(str(first_status.get("state", "")) == "valid", "İlk slot geçerli görünmüyor")
	_expect(str(first_status.get("slot_name", "")) == "Kuzey Kapısı", "Slot listesi kayıt adını göstermiyor")
	_expect(int(first_status.get("round_count", 0)) == 3, "Slot listesi raund bilgisini göstermiyor")
	_expect(int(first_status.get("turn_count", 0)) == 7, "Slot listesi tur bilgisini göstermiyor")
	_expect(bool(first_status.get("has_backup", false)), "Üzerine yazılan slot güvenli yedek üretmedi")

	var second_snapshot := _fixture_snapshot("save-slots-dominion", "Mavi Sancak", MatchSetup.Ruleset.DOMINION, 4, 8)
	var second_save := repository.save_snapshot_to_slot(second_snapshot, "Mavi Sancak", second_slot_id)
	_expect(bool(second_save.get("success", false)), "İkinci adlandırılmış kayıt slotu yazılamadı")
	var second_status := repository.inspect_slot(second_slot_id)
	_expect(int(second_status.get("ruleset", -1)) == MatchSetup.Ruleset.DOMINION, "Hakimiyet slotunun oyun modu korunmadı")
	var allocated_save := repository.save_snapshot_to_slot(first_snapshot, "Gece Kuşatması")
	var allocated_slot_id := str(allocated_save.get("slot_id", ""))
	_expect(bool(allocated_save.get("success", false)) and not allocated_slot_id.is_empty(), "Yeni slot için güvenli kimlik üretilemedi")
	_expect(str(allocated_save.get("slot_name", "")) == "Gece Kuşatması", "Otomatik kimlik üretilirken slot adı korunmadı")

	var listed_ids: Array[String] = []
	for slot in repository.list_slots():
		var listed_id := str(slot.get("slot_id", ""))
		if listed_id == first_slot_id or listed_id == second_slot_id:
			listed_ids.append(listed_id)
	_expect(first_slot_id in listed_ids and second_slot_id in listed_ids, "Adlandırılmış slotlar kayıt arşivinde listelenmiyor")

	var loaded := repository.load_slot(second_slot_id)
	_expect(bool(loaded.get("success", false)), "Seçilen slot yüklenemedi")
	_expect(str((loaded.get("snapshot", {}) as Dictionary).get("match_id", "")) == "save-slots-dominion", "Yüklenen slot yanlış maçı döndürdü")
	_expect(repository.get_current_slot_id() == second_slot_id, "Yüklenen slot etkin kayıt bağlamına alınmadı")

	# Damage only the test slot's primary file; the previous valid snapshot must be recoverable.
	var first_path := str(first_status.get("path", ""))
	var corrupt_file := FileAccess.open(first_path, FileAccess.WRITE)
	_expect(corrupt_file != null, "Test slotu bozulmak üzere açılamadı")
	if corrupt_file:
		corrupt_file.store_string("[bozuk slot")
		corrupt_file = null
	var recoverable := repository.inspect_slot(first_slot_id)
	_expect(str(recoverable.get("state", "")) == "recoverable", "Bozuk slot kurtarılabilir olarak işaretlenmedi")
	_expect(bool(recoverable.get("has_backup", false)), "Bozuk slot için yedek bilgisi sunulmadı")
	repository.configure_slot(first_slot_id, "Kuzey Kapısı")
	var recovered := repository.recover_backup()
	_expect(bool(recovered.get("success", false)), "Bozuk slot güvenli yedekten kurtarılamadı")
	_expect(str(repository.inspect_slot(first_slot_id).get("state", "")) == "valid", "Kurtarılan slot tekrar geçerli olmadı")

	var panel := SaveSlotsPanel.new()
	root.add_child(panel)
	await process_frame
	panel.save_requested.connect(_on_save_requested)
	panel.load_requested.connect(_on_load_requested)
	panel.delete_requested.connect(_on_delete_requested)
	var panel_slots: Array[Dictionary] = [repository.inspect_slot(first_slot_id), repository.inspect_slot(second_slot_id)]
	panel.open_panel(panel_slots, first_slot_id, "Gece Kuşatması", true, false)
	await process_frame
	_expect(panel.is_open() and panel.get_slot_count() == 2, "Kaydet/Yükle paneli iki slotu göstermiyor")
	_expect(panel.get_selected_slot_id() == first_slot_id, "Kaydet/Yükle paneli etkin slotu seçmiyor")
	_expect(panel.get_slot_name_input().text == "Kuzey Kapısı", "Seçili slot adı düzenleme alanına gelmiyor")
	var save_button := panel.find_child("SaveToSlotButton", true, false) as Button
	var load_button := panel.find_child("LoadSaveSlotButton", true, false) as Button
	var delete_button := panel.find_child("DeleteSaveSlotButton", true, false) as Button
	var name_section := panel.find_child("SaveSlotNameSection", true, false) as Control
	_expect(save_button != null and save_button.visible and not save_button.disabled, "Kaydet düğmesi kayıt modunda etkin değil")
	_expect(load_button != null and load_button.visible and not load_button.disabled, "Yükle düğmesi seçili slotta etkin değil")
	_expect(delete_button != null and not delete_button.disabled, "Sil düğmesi seçili slotta etkin değil")
	_expect(name_section != null and name_section.visible, "Slot adı alanı kayıt modunda görünmüyor")

	panel.call("_begin_new_slot")
	panel.get_slot_name_input().text = "Güney Hattı"
	await process_frame
	_expect(panel.get_selected_slot_id().is_empty(), "Yeni ad girildiğinde yeni slot modu açılmıyor")
	(save_button as Button).pressed.emit()
	_expect(str(_save_request.get("name", "")) == "Güney Hattı" and str(_save_request.get("id", "x")).is_empty(), "Kaydet eylemi yeni slot adını doğru iletmiyor")

	panel.open_panel(panel_slots, second_slot_id, "", false, false)
	await process_frame
	_expect(name_section != null and not name_section.visible, "Ana menü yükleme görünümünde slot adı alanı gizlenmeli")
	_expect(save_button != null and not save_button.visible, "Ana menü yükleme görünümünde Kaydet düğmesi gizlenmeli")
	(load_button as Button).pressed.emit()
	_expect(_load_request == second_slot_id, "Yükle eylemi seçili slot kimliğini iletmiyor")
	(delete_button as Button).pressed.emit()
	_expect(_delete_request == second_slot_id, "Sil eylemi seçili slot kimliğini iletmiyor")

	panel.queue_free()
	await process_frame
	repository.delete_slot(first_slot_id)
	repository.delete_slot(second_slot_id)
	if not allocated_slot_id.is_empty():
		repository.delete_slot(allocated_slot_id)
	_expect(str(repository.inspect_slot(first_slot_id).get("state", "")) == "missing", "İlk test slotu temizlenemedi")
	_expect(str(repository.inspect_slot(second_slot_id).get("state", "")) == "missing", "İkinci test slotu temizlenemedi")
	_finish()


func _fixture_snapshot(match_id: String, match_name: String, ruleset: int, round_count: int, turn_count: int) -> Dictionary:
	return {
		"match_id": match_id,
		"match_name": match_name,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0.0")),
		"seed": 74119,
		"match_mode": MatchSetup.MatchMode.LOCAL,
		"ruleset": ruleset,
		"manager": {"round_count": round_count, "turn_count": turn_count},
		"zones": {},
		"rng": {},
		"effect_cards": {},
	}


func _on_save_requested(slot_name: String, slot_id: String) -> void:
	_save_request = {"name": slot_name, "id": slot_id}


func _on_load_requested(slot_id: String) -> void:
	_load_request = slot_id


func _on_delete_requested(slot_id: String) -> void:
	_delete_request = slot_id


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SAVE_SLOTS_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("SAVE_SLOTS_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
