extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	var packed := load("res://main_menu.tscn") as PackedScene
	_expect(packed != null, "Ana menü yüklenebilmeli")
	if packed == null:
		_finish()
		return

	var menu := packed.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	var fade := menu.find_child("SceneFade", true, false) as ColorRect
	if fade:
		fade.color.a = 0.0

	menu.call("_show_difficulty_selection")
	await process_frame
	var overlay := menu.find_child("DifficultyOverlay", true, false) as Control
	var panel := menu.find_child("DifficultyPanel", true, false) as Control
	var form := menu.find_child("GameSetupForm", true, false) as VBoxContainer
	var title := menu.find_child("DifficultyTitle", true, false) as Label
	var game_name_row := menu.find_child("GameNameConfigRow", true, false) as Control
	var card_pool_row := menu.find_child("CardPoolConfigRow", true, false) as Control
	var turn_duration_row := menu.find_child("TurnDurationConfigRow", true, false) as Control
	var difficulty_row := menu.find_child("DifficultyConfigRow", true, false) as Control
	var auto_attack_row := menu.find_child("AutoAttackConfigRow", true, false) as Control
	var game_name_input := menu.find_child("GameNameInput", true, false) as LineEdit
	var start_game_button := menu.find_child("StartConfiguredGameButton", true, false) as Button

	_expect(overlay != null and overlay.visible, "Savaşa Başla oyun ayarları formunu açmalı")
	_expect(panel != null and form != null, "Oyun ayarları tek form panelinde bulunmalı")
	_expect(title != null and title.text == "OYUN AYARLARI", "Form başlığı Oyun Ayarları olmalı")
	_expect(game_name_row != null and game_name_row.visible, "Oyun Adı formda görünmeli")
	_expect(card_pool_row != null and card_pool_row.visible, "Kart Kapsamı formda görünmeli")
	_expect(turn_duration_row != null and turn_duration_row.visible, "Tur Başına Süre formda görünmeli")
	_expect(difficulty_row != null and difficulty_row.visible, "Zorluk formda görünmeli")
	_expect(auto_attack_row != null and auto_attack_row.visible, "Otomatik Savaş formda görünmeli")
	_expect(menu.find_child("AllowAutoAttackButton", true, false) is Button, "Otomatik savaşa izin verme seçeneği bulunmalı")
	_expect(menu.find_child("DisableAutoAttackButton", true, false) is Button, "Otomatik savaşı kapatma seçeneği bulunmalı")
	for button_name in ["EasyDifficultyButton", "MediumDifficultyButton", "HardDifficultyButton"]:
		var difficulty_button := menu.find_child(button_name, true, false) as Button
		var emblem_name: String = str(button_name).trim_suffix("Button") + "Emblem"
		var emblem := menu.find_child(emblem_name, true, false) as Control
		_expect(difficulty_button != null and emblem != null, "%s içeriği bulunmalı" % button_name)
		if difficulty_button and emblem:
			var button_rect := difficulty_button.get_global_rect()
			var emblem_rect := emblem.get_global_rect()
			_expect(
				emblem_rect.position.x >= button_rect.position.x + 16.0
				and emblem_rect.end.x <= button_rect.end.x - 8.0,
				"%s ikonu butonun solundan taşmamalı ve içerik sağa alınmalı" % button_name
			)
	_expect(menu.find_child("GameSetupProgress", true, false) == null, "Aşama göstergesi kaldırılmalı")
	_expect(menu.find_child("GameSetupBackButton", true, false) == null, "Geri düğmesi formda bulunmamalı")
	_expect(menu.find_child("GameSetupNextButton", true, false) == null, "İleri düğmesi formda bulunmamalı")
	_expect(
		start_game_button != null
		and start_game_button.visible
		and start_game_button.text == "OYUNU BAŞLAT",
		"Formun altında tek Oyunu Başlat düğmesi bulunmalı"
	)

	if game_name_input:
		game_name_input.text = ""
		menu.call("_on_game_setup_name_changed", "")
	_expect(start_game_button != null and start_game_button.disabled, "Boş oyun adıyla Oyunu Başlat kapalı olmalı")
	menu.call("_start_game")
	await process_frame
	_expect(current_scene == menu, "Boş oyun adı savaş sahnesine geçmemeli")

	if game_name_input:
		game_name_input.text = "Kuzey Seferi"
		menu.call("_on_game_setup_name_changed", game_name_input.text)
	_expect(start_game_button != null and not start_game_button.disabled, "Oyun adı girilince Oyunu Başlat açılmalı")

	menu.call("_set_card_pool_mode", MatchSetup.CardPoolMode.ALL_CARDS)
	var all_cards_button := menu.find_child("AllCardsPoolButton", true, false) as Button
	_expect(all_cards_button != null and all_cards_button.button_pressed, "Tüm Kartlar kapsamı seçilebilmeli")
	menu.call("_set_turn_duration", 60)
	var sixty_second_button := menu.find_child("TurnDuration60Button", true, false) as Button
	_expect(sixty_second_button != null and sixty_second_button.button_pressed, "60 saniyelik tur süresi seçilebilmeli")
	menu.call("_set_selected_difficulty", MatchSetup.AIDifficulty.HARD)
	var hard_button := menu.find_child("HardDifficultyButton", true, false) as Button
	_expect(hard_button != null and hard_button.button_pressed, "Zor rakip seçilebilmeli")
	menu.call("_set_auto_attack_allowed", false)
	var disable_auto_attack_button := menu.find_child("DisableAutoAttackButton", true, false) as Button
	_expect(disable_auto_attack_button != null and disable_auto_attack_button.button_pressed, "Otomatik savaş kapatılabilmeli")
	var summary := menu.find_child("GameSetupSummary", true, false) as Label
	_expect(
		summary != null
		and "Kuzey Seferi" in summary.text
		and "Tüm Kartlar" in summary.text
		and "60 sn" in summary.text
		and "Zor" in summary.text,
		"Form özeti bütün seçili ayarları göstermeli"
	)
	_expect(summary != null and "Otomatik Savaş Kapalı" in summary.text, "Form özeti otomatik savaş iznini göstermeli")

	menu.call("_start_game")
	var transition_timeout := 5.0
	while current_scene != null and current_scene.name != "Battlefield" and transition_timeout > 0.0:
		await create_timer(0.05).timeout
		transition_timeout -= 0.05
	_expect(current_scene != null and current_scene.name == "Battlefield", "Oyunu Başlat savaş sahnesini açmalı")
	_expect(MatchSetup.match_name == "Kuzey Seferi", "Oyun adı maç yapılandırmasına aktarılmalı")
	_expect(MatchSetup.uses_all_cards(), "Kart kapsamı maç yapılandırmasına aktarılmalı")
	_expect(is_equal_approx(MatchSetup.turn_duration_seconds, 60.0), "Tur süresi maç yapılandırmasına aktarılmalı")
	_expect(MatchSetup.get_ai_difficulty(2) == MatchSetup.AIDifficulty.HARD, "Zorluk maç yapılandırmasına aktarılmalı")
	_expect(not MatchSetup.auto_attack_allowed, "Otomatik savaş izni maç yapılandırmasına aktarılmalı")
	if current_scene:
		var manager := current_scene.find_child("GameManager", true, false) as GameManager
		_expect(manager != null and is_equal_approx(manager.turn_duration_seconds, 60.0), "GameManager seçilen 60 saniyeyi kullanmalı")
		var auto_attack_panel := current_scene.find_child("AutoAttackPanel", true, false) as Control
		_expect(auto_attack_panel != null and not auto_attack_panel.visible, "İzin verilmeyen otomatik savaş kontrolü gizlenmeli")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_SETUP_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("GAME_SETUP_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
