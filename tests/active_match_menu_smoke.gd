extends SceneTree

const TEST_PATH := "user://active_match_menu_smoke.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	SafeJsonStore.remove_family(TEST_PATH, ActiveMatchRepository.BACKUP_COUNT)
	var packed := load("res://main_menu.tscn") as PackedScene
	_expect(packed != null, "main_menu.tscn yüklenemedi")
	if packed == null:
		_finish()
		return

	var menu := packed.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame

	var repository := menu.get("_active_match_repository") as ActiveMatchRepository
	repository.configure_path(TEST_PATH)
	var snapshot := _fixture_snapshot()
	var first_save := repository.save_snapshot(snapshot)
	_expect(bool(first_save.get("success", false)), "Geçerli aktif maç fixture'ı yazılamadı")
	menu.call("_refresh_continue_game_state")
	var continue_button := menu.find_child("ContinueGameButton", true, false) as Button
	_expect(
		continue_button != null and continue_button.visible and not continue_button.disabled and continue_button.text == "YÜKLE",
		"Geçerli kayıtta ana menü etkin YÜKLE düğmesini göstermeli"
	)

	# A second valid save creates backup 1; corrupting the primary must never
	# silently start a fresh match.
	var second_save := repository.save_snapshot(snapshot)
	_expect(bool(second_save.get("success", false)), "Kurtarma yedeği oluşturulamadı")
	var corrupt_file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	_expect(corrupt_file != null, "Aktif maç fixture'ı bozulmak üzere açılamadı")
	if corrupt_file:
		corrupt_file.store_string("[bozuk aktif maç")
		corrupt_file = null
	menu.call("_refresh_continue_game_state")
	_expect(
		continue_button != null and continue_button.visible and not continue_button.disabled and continue_button.text == "YÜKLE",
		"Bozuk birincil kayıtta ana menü slot seçimi için YÜKLE düğmesini korumalı"
	)

	menu.call("_on_continue_game_pressed")
	await process_frame
	var recovery_overlay := menu.find_child("ActiveSaveRecoveryOverlay", true, false) as Control
	var recover_button := menu.find_child("RecoverActiveSaveButton", true, false) as Button
	var delete_button := menu.find_child("DeleteActiveSaveButton", true, false) as Button
	_expect(recovery_overlay != null and recovery_overlay.visible, "Bozuk kayıt kurtarma penceresini açmadı")
	_expect(
		recover_button != null
		and recover_button.visible
		and recover_button.text.to_lower() == "yedekten kurtar".to_lower(),
		"Geçerli yedek için Yedekten Kurtar seçeneği görünmeli"
	)
	_expect(
		delete_button != null and delete_button.text == "KAYDI SİL",
		"Kaydı Sil seçeneği görünmeli"
	)
	_expect(
		_tree_contains_text(recovery_overlay, "Yeni maç başlatılmadı."),
		"Bozuk kayıt sessizce yeni maç başlatılmayacağını açıklamalı"
	)

	menu.call("_delete_active_save")
	await process_frame
	_expect(not FileAccess.file_exists(TEST_PATH), "Kaydı Sil birincil dosyayı kaldırmadı")
	_expect(not FileAccess.file_exists(SafeJsonStore.backup_path(TEST_PATH, 1)), "Kaydı Sil yedekleri kaldırmadı")
	_expect(
		continue_button != null and continue_button.visible and continue_button.disabled and continue_button.text == "YÜKLE",
		"Kayıt silinince Yükle düğmesi görünür kalıp devre dışı olmalı"
	)

	# Production flow uses the named-slot archive instead of loading a hidden
	# single file directly.
	var named_slot_id := "menu-picker-smoke-%d" % Time.get_ticks_usec()
	repository.configure_path(ActiveMatchRepository.DEFAULT_SAVE_PATH)
	var named_save := repository.save_snapshot_to_slot(snapshot, "Ana Menü Slotu", named_slot_id)
	_expect(bool(named_save.get("success", false)), "Ana menü slot seçici fixture'ı yazılamadı")
	menu.call("_refresh_continue_game_state")
	menu.call("_on_continue_game_pressed")
	await process_frame
	var save_slots_overlay := menu.find_child("SaveSlotsOverlay", true, false) as SaveSlotsPanel
	_expect(save_slots_overlay != null and save_slots_overlay.is_open(), "Ana menü Yükle eylemi slot seçiciyi açmadı")
	_expect(save_slots_overlay != null and save_slots_overlay.get_selected_slot_id() == named_slot_id, "Ana menü slot seçici etkin kaydı seçmedi")
	var save_action := menu.find_child("SaveToSlotButton", true, false) as Button
	_expect(save_action != null and not save_action.visible, "Ana menüdeki slot seçici Kaydet eylemini göstermemeli")
	if save_slots_overlay:
		save_slots_overlay.close_panel()
	repository.delete_slot(named_slot_id)

	menu.queue_free()
	current_scene = null
	await process_frame
	SafeJsonStore.remove_family(TEST_PATH, ActiveMatchRepository.BACKUP_COUNT)
	_finish()


func _fixture_snapshot() -> Dictionary:
	return {
		"match_id": "active-match-menu-smoke",
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0.0")),
		"seed": 58001,
		"match_mode": MatchSetup.MatchMode.LOCAL,
		"manager": {},
		"zones": {},
		"rng": {},
		"effect_cards": {},
	}


func _tree_contains_text(node: Node, needle: String) -> bool:
	if node is Label and needle in (node as Label).text:
		return true
	if node is Button and needle in (node as Button).text:
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ACTIVE_MATCH_MENU_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("ACTIVE_MATCH_MENU_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
