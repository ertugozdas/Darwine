extends SceneTree

const OUTPUT_PATH := "/tmp/tdm_dominion_multiplayer_1280x720.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("DOMINION_MULTIPLAYER_VISUAL_CAPTURE_SKIPPED: etkin görüntü sürücüsü gerekiyor")
		quit(0)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var menu := (load("res://main_menu.tscn") as PackedScene).instantiate()
	viewport.add_child(menu)
	for _frame in range(3):
		await process_frame
	var fade := menu.find_child("SceneFade", true, false) as ColorRect
	if fade:
		fade.color.a = 0.0
	menu.call("_set_ruleset", MatchSetup.Ruleset.DOMINION)
	menu.call("_show_multiplayer")
	menu.call("_show_multiplayer_mode", true)
	var overlay := menu.find_child("MultiplayerOverlay", true, false) as Control
	if overlay:
		overlay.modulate.a = 1.0
	for _frame in range(3):
		await process_frame

	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for node_name in [
		"MultiplayerPanel",
		"HostRoomPanel",
		"HostRulesetRow",
		"HostSiegeRulesetButton",
		"HostDominionRulesetButton",
		"CreateRoomButton",
	]:
		var control := menu.find_child(node_name, true, false) as Control
		if not control or not control.visible or not bounds.encloses(control.get_global_rect()):
			push_error("%s çevrimiçi Hakimiyet panelinde görünür ve ekran sınırlarında olmalı" % node_name)
			quit(1)
			return
	var dominion_button := menu.find_child("HostDominionRulesetButton", true, false) as Button
	if not dominion_button.button_pressed:
		push_error("Çevrimiçi Hakimiyet seçimi görsel yakalamada etkin değil")
		quit(1)
		return

	RenderingServer.force_draw(true, 0.0)
	var image := viewport.get_texture().get_image()
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		push_error("Çevrimiçi Hakimiyet görüntüsü alınamadı")
		quit(1)
		return
	var save_error := image.save_png(OUTPUT_PATH)
	if save_error != OK:
		push_error("Çevrimiçi Hakimiyet görüntüsü kaydedilemedi: %s" % error_string(save_error))
		quit(1)
		return
	print("DOMINION_MULTIPLAYER_VISUAL_CAPTURE_OK: %s" % OUTPUT_PATH)
	viewport.queue_free()
	await process_frame
	quit(0)
