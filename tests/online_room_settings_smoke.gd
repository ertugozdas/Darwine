extends SceneTree

const NETWORK_MANAGER_SCRIPT := preload("res://scripts/network_manager.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	_test_room_settings_contract()
	await _test_online_settings_ui()
	MatchSetup.configure_local(1)
	_finish()


func _test_room_settings_contract() -> void:
	var manager := NETWORK_MANAGER_SCRIPT.new()
	manager.call(
		"_set_room_settings",
		MatchSetup.Ruleset.DOMINION,
		"Gece Hakimiyeti",
		MatchSetup.CardPoolMode.ALL_CARDS,
		90.0,
		false
	)
	var settings := manager.get_room_settings()
	_expect(int(settings.get("ruleset", -1)) == MatchSetup.Ruleset.DOMINION, "Oda ayarı Hakimiyet modunu taşımalı")
	_expect(str(settings.get("match_name", "")) == "Gece Hakimiyeti", "Oda ayarı maç adını taşımalı")
	_expect(int(settings.get("card_pool_mode", -1)) == MatchSetup.CardPoolMode.ALL_CARDS, "Oda ayarı Tüm Kartlar kapsamını taşımalı")
	_expect(is_equal_approx(float(settings.get("turn_duration_seconds", 0.0)), 90.0), "Oda ayarı 90 saniyeyi taşımalı")
	_expect(not bool(settings.get("auto_attack_allowed", true)), "Oda ayarı otomatik savaşı kapatabilmeli")

	manager.call("_apply_room_settings_to_match_setup")
	_expect(MatchSetup.is_dominion(), "Sunucudan gelen oyun modu MatchSetup'a uygulanmalı")
	_expect(MatchSetup.match_name == "Gece Hakimiyeti", "Sunucudan gelen maç adı MatchSetup'a uygulanmalı")
	_expect(MatchSetup.uses_all_cards(), "Sunucudan gelen kart kapsamı MatchSetup'a uygulanmalı")
	_expect(is_equal_approx(MatchSetup.turn_duration_seconds, 90.0), "Sunucudan gelen süre MatchSetup'a uygulanmalı")
	_expect(not MatchSetup.auto_attack_allowed, "Sunucudan gelen otomatik savaş izni MatchSetup'a uygulanmalı")

	manager.call("_reset_client_runtime", true)
	_expect(
		str(manager.get_room_settings().get("match_name", "")) == "Gece Hakimiyeti",
		"Yeniden bağlanma temizliği oda ayarlarını korumalı"
	)
	manager.call("_reset_client_runtime", false)
	var reset_settings := manager.get_room_settings()
	_expect(int(reset_settings.get("ruleset", -1)) == MatchSetup.Ruleset.SIEGE, "Tam çıkış oyun modunu varsayılana döndürmeli")
	_expect(int(reset_settings.get("card_pool_mode", -1)) == MatchSetup.CardPoolMode.DECK, "Tam çıkış kart kapsamını varsayılana döndürmeli")
	_expect(bool(reset_settings.get("auto_attack_allowed", false)), "Tam çıkış otomatik savaş iznini varsayılana döndürmeli")
	manager.free()


func _test_online_settings_ui() -> void:
	var packed := load("res://main_menu.tscn") as PackedScene
	_expect(packed != null, "Ana menü yüklenemedi")
	if not packed:
		return
	var menu := packed.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame

	for locale in ["En", "De", "Fr", "It", "Es", "Tr"]:
		var flag := menu.find_child("Language%sFlag" % locale, true, false) as LanguageFlagIcon
		_expect(
			flag != null
			and is_equal_approx(flag.custom_minimum_size.x, 54.0)
			and is_equal_approx(flag.custom_minimum_size.y, 32.0)
			and flag.size_flags_vertical == Control.SIZE_SHRINK_CENTER,
			"%s bayrağı kısa, sabit oranlı ölçü kullanmalı" % locale
		)

	menu.call("_show_multiplayer")
	await process_frame
	await process_frame
	var panel := menu.find_child("MultiplayerPanel", true, false) as Control
	_expect(panel != null and panel.get_global_rect().size.x >= 900.0, "Online penceresi tam ayar formuna yetecek genişlikte olmalı")
	for node_name in [
		"HostGameNameInput",
		"HostRulesetRow",
		"HostCardPoolRow",
		"HostTurnDurationRow",
		"HostAutoAttackRow",
		"HostSettingsSummary",
	]:
		var control := menu.find_child(node_name, true, false) as Control
		_expect(control != null and control.visible, "%s online oda formunda görünmeli" % node_name)
		if panel and control:
			_expect(panel.get_global_rect().grow(1.0).encloses(control.get_global_rect()), "%s online panelden taşmamalı" % node_name)

	var game_name_input := menu.find_child("HostGameNameInput", true, false) as LineEdit
	game_name_input.text = "Gece Hakimiyeti"
	menu.call("_on_multiplayer_game_name_changed", game_name_input.text)
	menu.call("_set_ruleset", MatchSetup.Ruleset.DOMINION)
	menu.call("_set_card_pool_mode", MatchSetup.CardPoolMode.ALL_CARDS)
	menu.call("_set_turn_duration", 90)
	menu.call("_set_auto_attack_allowed", false)
	await process_frame
	var summary := menu.find_child("HostSettingsSummary", true, false) as Label
	_expect(
		summary != null
		and "Gece Hakimiyeti" in summary.text
		and "Hakimiyet" in summary.text
		and "Tüm Kartlar" in summary.text
		and "90" in summary.text
		and "Kapalı" in summary.text,
		"Online ayar özeti tüm seçimleri birlikte göstermeli"
	)
	menu.call("_set_multiplayer_settings_locked", true)
	_expect(not game_name_input.editable, "Oda kurulduktan sonra maç adı kilitlenmeli")
	_expect((menu.find_child("HostDominionRulesetButton", true, false) as Button).disabled, "Oda kurulduktan sonra oyun modu kilitlenmeli")
	_expect((menu.find_child("HostAllCardsPoolButton", true, false) as Button).disabled, "Oda kurulduktan sonra kart kapsamı kilitlenmeli")
	menu.call("_set_multiplayer_settings_locked", false)

	var network_manager := root.get_node_or_null("NetworkManager")
	if network_manager:
		network_manager.call(
			"_set_room_settings",
			MatchSetup.Ruleset.DOMINION,
			"Sunucu Odası",
			MatchSetup.CardPoolMode.ALL_CARDS,
			60.0,
			false
		)
		menu.call("_show_multiplayer_mode", false)
		menu.call("_on_network_lobby_changed", {
			1: {"name": "Komutan A", "deck_name": "Kuzey", "connected": true},
		})
		await process_frame
		var joined_settings := menu.find_child("JoinedRoomSettings", true, false) as Label
		_expect(
			joined_settings != null
			and "Sunucu Odası" in joined_settings.text
			and "Tüm Kartlar" in joined_settings.text
			and "60" in joined_settings.text,
			"Katılan oyuncu hosttan gelen tam oda ayarlarını görmeli"
		)
		network_manager.call("_reset_room_settings")

	menu.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ONLINE_ROOM_SETTINGS_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("ONLINE_ROOM_SETTINGS_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
