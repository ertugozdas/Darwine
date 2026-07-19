extends SceneTree

const OUTPUT_PATH := "/tmp/tdm_online_room_settings_1280x720.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("ONLINE_SETTINGS_VISUAL_CAPTURE_SKIPPED: etkin görüntü sürücüsü gerekiyor")
		quit(0)
		return
	TranslationServer.set_locale("tr")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var menu := (load("res://main_menu.tscn") as PackedScene).instantiate()
	viewport.add_child(menu)
	for _frame in range(4):
		await process_frame
	var fade := menu.find_child("SceneFade", true, false) as ColorRect
	if fade:
		fade.color.a = 0.0
	menu.call("_show_multiplayer")
	menu.call("_set_ruleset", MatchSetup.Ruleset.DOMINION)
	menu.call("_set_card_pool_mode", MatchSetup.CardPoolMode.ALL_CARDS)
	menu.call("_set_turn_duration", 60)
	menu.call("_set_auto_attack_allowed", false)
	var game_name := menu.find_child("HostGameNameInput", true, false) as LineEdit
	if game_name:
		game_name.text = "Gece Hakimiyeti"
		menu.call("_on_multiplayer_game_name_changed", game_name.text)
	var overlay := menu.find_child("MultiplayerOverlay", true, false) as Control
	if overlay:
		overlay.modulate.a = 1.0
	for _frame in range(5):
		await process_frame

	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var panel := menu.find_child("MultiplayerPanel", true, false) as Control
	if not panel or not bounds.encloses(panel.get_global_rect()):
		push_error("Online oda ayarları paneli 1280×720 sınırlarının dışına taşıyor")
		quit(1)
		return
	for node_name in [
		"HostGameNameInput",
		"HostRulesetRow",
		"HostCardPoolRow",
		"HostTurnDurationRow",
		"HostAutoAttackRow",
		"HostSettingsSummary",
		"HostInviteRow",
		"HostRoomActions",
	]:
		var control := menu.find_child(node_name, true, false) as Control
		if not control or not control.is_visible_in_tree() or not panel.get_global_rect().grow(1.0).encloses(control.get_global_rect()):
			push_error("%s online oda formunda görünür ve panel içinde olmalı" % node_name)
			quit(1)
			return

	RenderingServer.force_draw(true, 0.0)
	var image := viewport.get_texture().get_image()
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		push_error("Online oda ayarları görüntüsü alınamadı")
		quit(1)
		return
	var save_error := image.save_png(OUTPUT_PATH)
	if save_error != OK:
		push_error("Online oda ayarları görüntüsü kaydedilemedi: %s" % error_string(save_error))
		quit(1)
		return
	print("ONLINE_SETTINGS_VISUAL_CAPTURE_OK: %s" % OUTPUT_PATH)
	viewport.queue_free()
	await process_frame
	quit(0)
