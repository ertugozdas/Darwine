extends SceneTree

const OUTPUT_PATH := "/tmp/tdm_deck_builder_1280x720.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("DECK_BUILDER_VISUAL_CAPTURE_SKIPPED")
		quit(0)
		return
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
	menu.call("_show_deck_builder")
	for _frame in range(8):
		await process_frame
	var panel := menu.find_child("DeckBuilderPanel", true, false) as Control
	if not panel or not Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(panel.get_global_rect()):
		push_error("Deste Atölyesi 1280×720 sınırlarının dışına taşıyor")
		quit(1)
		return
	RenderingServer.force_draw(true, 0.0)
	var image := viewport.get_texture().get_image()
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		push_error("Deste Atölyesi görseli alınamadı")
		quit(1)
		return
	var save_error := image.save_png(OUTPUT_PATH)
	if save_error != OK:
		push_error("Deste Atölyesi görseli kaydedilemedi")
		quit(1)
		return
	print("DECK_BUILDER_VISUAL_CAPTURE_OK: %s" % OUTPUT_PATH)
	quit(0)
