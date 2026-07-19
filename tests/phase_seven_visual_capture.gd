extends SceneTree

const OUTPUT_PATH := "/tmp/tdm_phase7_difficulty_1280x720.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PHASE_SEVEN_VISUAL_CAPTURE_SKIPPED: etkin görüntü sürücüsü gerekiyor")
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
	menu.call("_show_difficulty_selection")
	var overlay := menu.find_child("DifficultyOverlay", true, false) as Control
	if overlay:
		overlay.modulate.a = 1.0
	for _frame in range(3):
		await process_frame

	var panel := menu.find_child("DifficultyPanel", true, false) as Control
	if not panel or not Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(panel.get_global_rect()):
		push_error("Zorluk paneli 1280×720 sınırlarının dışına taşıyor")
		quit(1)
		return
	for button_name in ["EasyDifficultyButton", "MediumDifficultyButton", "HardDifficultyButton"]:
		var button := menu.find_child(button_name, true, false) as Button
		if not button or not Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(button.get_global_rect()):
			push_error("%s 1280×720 sınırlarının dışına taşıyor" % button_name)
			quit(1)
			return

	RenderingServer.force_draw(true, 0.0)
	var image := viewport.get_texture().get_image()
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		push_error("Aşama 7 için 1280×720 görüntü alınamadı")
		quit(1)
		return
	var save_error := image.save_png(OUTPUT_PATH)
	if save_error != OK:
		push_error("Aşama 7 görüntüsü kaydedilemedi: %s" % error_string(save_error))
		quit(1)
		return
	print("PHASE_SEVEN_VISUAL_CAPTURE_OK: %s" % OUTPUT_PATH)
	viewport.queue_free()
	await process_frame
	quit(0)
