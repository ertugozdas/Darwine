extends SceneTree

const MAIN_OUTPUT := "/tmp/tdm_main_menu_updated.png"
const HOW_TO_OUTPUT := "/tmp/tdm_how_to_modes_updated.png"
const HOW_TO_CONTROLS_OUTPUT := "/tmp/tdm_how_to_controls_updated.png"
const SAVE_OUTPUT := "/tmp/tdm_save_slots_updated.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("MENU_SAVE_VISUAL_CAPTURE_SKIPPED")
		quit(0)
		return
	TranslationServer.set_locale("tr")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var menu := (load("res://main_menu.tscn") as PackedScene).instantiate()
	viewport.add_child(menu)
	await process_frame
	await process_frame
	if not _save(viewport, MAIN_OUTPUT):
		quit(1)
		return

	menu.call("_show_how_to_play")
	await create_timer(0.18).timeout
	if not _save(viewport, HOW_TO_OUTPUT):
		quit(1)
		return
	var how_to_panel := menu.find_child("HowToOverlay", true, false) as HowToPlayPanel
	how_to_panel.open_panel(7)
	await process_frame
	if not _save(viewport, HOW_TO_CONTROLS_OUTPUT):
		quit(1)
		return
	menu.call("_hide_how_to_play")
	var save_panel := menu.find_child("SaveSlotsOverlay", true, false) as SaveSlotsPanel
	var sample_slots: Array[Dictionary] = [
		{
			"slot_id": "north-gate",
			"slot_name": "Kuzey Kapısı",
			"state": "valid",
			"ruleset": MatchSetup.Ruleset.SIEGE,
			"round_count": 3,
			"turn_count": 7,
			"saved_at_utc": "2026-07-17T18:42:00Z",
		},
		{
			"slot_id": "blue-banner",
			"slot_name": "Mavi Sancak",
			"state": "recoverable",
			"ruleset": MatchSetup.Ruleset.DOMINION,
			"round_count": 6,
			"turn_count": 12,
			"saved_at_utc": "2026-07-17T17:18:00Z",
		},
	]
	save_panel.open_panel(sample_slots, "north-gate", "Kuzey Kapısı", true, false)
	await process_frame
	var save_panel_frame := save_panel.find_child("SaveSlotsPanel", true, false) as Control
	if save_panel_frame == null or not Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(save_panel_frame.get_rect()):
		push_error("Kayıt slotu paneli 1280×720 alanına sığmıyor: %s" % [save_panel_frame.get_rect() if save_panel_frame else Rect2()])
		quit(1)
		return
	if not _save(viewport, SAVE_OUTPUT):
		quit(1)
		return

	print("MENU_SAVE_VISUAL_CAPTURE_OK: %s • %s • %s • %s" % [MAIN_OUTPUT, HOW_TO_OUTPUT, HOW_TO_CONTROLS_OUTPUT, SAVE_OUTPUT])
	menu.queue_free()
	viewport.queue_free()
	await process_frame
	quit(0)


func _save(viewport: SubViewport, output_path: String) -> bool:
	RenderingServer.force_draw(true, 0.0)
	var image := viewport.get_texture().get_image()
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		push_error("1280×720 görüntü alınamadı: %s" % output_path)
		return false
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Görüntü kaydedilemedi: %s" % error_string(save_error))
		return false
	return true
