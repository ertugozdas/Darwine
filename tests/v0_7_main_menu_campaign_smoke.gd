extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	var packed := load("res://main_menu.tscn") as PackedScene
	_expect(packed != null, "Ana menü sahnesi yüklenebilmeli")
	if not packed:
		_finish()
		return
	var menu := packed.instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	var campaign_button := menu.find_child("CampaignButton", true, false) as Button
	_expect(campaign_button != null, "Ana menü Komutan Seferi düğmesini göstermeli")
	_expect(campaign_button != null and campaign_button.text == "KOMUTAN SEFERİ", "Komutan Seferi düğmesi Türkçe görünmeli")
	menu.call("_show_scenario_campaign")
	await process_frame
	var overlay := menu.find_child("ScenarioCampaignOverlay", true, false) as Control
	_expect(overlay != null and overlay.visible, "Komutan Seferi düğmesi seçim ekranını açmalı")
	var scenario_button_count := 0
	for node in menu.find_children("ScenarioButton_*", "Button", true, false):
		if node is Button:
			scenario_button_count += 1
	_expect(scenario_button_count == 6, "Ana menü sefer ekranı altı senaryo göstermeli")
	menu.call("_hide_scenario_campaign")
	_expect(overlay != null and not overlay.visible, "Komutan Seferi ekranı ana menüye kapanabilmeli")
	menu.queue_free()
	await process_frame
	MatchSetup.configure_local(1)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_MAIN_MENU_CAMPAIGN_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_MAIN_MENU_CAMPAIGN_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
