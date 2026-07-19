extends SceneTree

const TEST_PATH := "user://profile_visual_capture.json"
const OVERVIEW_OUTPUT := "/tmp/tdm_profile_overview_1280x720.png"
const MISSIONS_OUTPUT := "/tmp/tdm_profile_missions_1280x720.png"
const HISTORY_OUTPUT := "/tmp/tdm_profile_history_1280x720.png"
const GAME_OVER_OUTPUT := "/tmp/tdm_match_summary_1280x720.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PROFILE_VISUAL_CAPTURE_SKIPPED")
		quit(0)
		return
	var repository := root.get_node("ProfileManager")
	repository.configure_storage_path(TEST_PATH, true)
	for index in range(6):
		var winner_id := 1 if index in [0, 1, 2, 4] else 2
		repository.record_match(
			_make_summary(index, winner_id),
			1,
			"Çevrimiçi" if index % 2 == 0 else "Yapay Zekâ",
			["Muhafız Hattı", "Rünik Kontrol", "Fırtına Hücumu"][index % 3]
		)
	repository.set_commander_name("Ertuğrul")

	var packed := load("res://main_menu.tscn") as PackedScene
	var menu := packed.instantiate()
	var menu_viewport := SubViewport.new()
	menu_viewport.size = Vector2i(1280, 720)
	menu_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(menu_viewport)
	menu_viewport.add_child(menu)
	await process_frame
	await process_frame
	var fade := menu.find_child("SceneFade", true, false) as ColorRect
	var main_panel := menu.find_child("MainMenuPanel", true, false) as Control
	if fade:
		fade.color.a = 0.0
	if main_panel:
		main_panel.modulate.a = 1.0
	menu.call("_show_profile")
	await create_timer(0.24).timeout
	if not _save_viewport(menu_viewport, OVERVIEW_OUTPUT):
		_finish(repository, 1)
		return
	var tabs := menu.find_child("ProfileTabs", true, false) as TabContainer
	tabs.current_tab = 1
	await create_timer(0.12).timeout
	if not _save_viewport(menu_viewport, MISSIONS_OUTPUT):
		_finish(repository, 1)
		return
	tabs.current_tab = 2
	await create_timer(0.24).timeout
	if not _save_viewport(menu_viewport, HISTORY_OUTPUT):
		_finish(repository, 1)
		return

	MatchSetup.configure_local(7171)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	viewport.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame
	if battlefield._tutorial_overlay:
		battlefield._tutorial_overlay.visible = false
	var history_count_before: int = int(repository.get_history().size())
	battlefield.game_manager.finish_game(1)
	await process_frame
	await process_frame
	if repository.get_history().size() != history_count_before + 1:
		push_error("Gerçek oyun sonu profil geçmişine işlenmedi.")
		_finish(repository, 1)
		return
	battlefield._update_game_over_summary(_make_summary(3, 1), 1)
	battlefield._game_over_reward_label.text = "+109 XP  •  +10 Mühür  •  Başarı: İlk Sancak"
	await create_timer(0.12).timeout
	if not _save_viewport(viewport, GAME_OVER_OUTPUT):
		_finish(repository, 1)
		return

	print("PROFILE_VISUAL_CAPTURE_OK: %s • %s • %s • %s" % [
		OVERVIEW_OUTPUT, MISSIONS_OUTPUT, HISTORY_OUTPUT, GAME_OVER_OUTPUT,
	])
	_finish(repository, 0)


func _make_summary(index: int, winner_id: int) -> Dictionary:
	return {
		"match_id": "profile-visual-%d" % index,
		"seed": 7000 + index,
		"winner_id": winner_id,
		"round_count": 7 + index,
		"duration_seconds": 178.0 + index * 14.0,
		"finished": true,
		"players": {
			1: {
				"cards_played": 9 + index,
				"hq_damage": 14 + index * 3,
				"cards_destroyed": 2 + index % 3,
				"mvp_card_name": ["Siper Muhafızı", "Rün Mührü", "Ateş Mancınığı"][index % 3],
			},
			2: {"cards_played": 8, "hq_damage": 9, "cards_destroyed": 2, "mvp_card_name": "Kara Mızrak"},
		},
	}


func _save_viewport(viewport: SubViewport, path: String) -> bool:
	RenderingServer.force_draw(true, 0.0)
	var image := viewport.get_texture().get_image()
	return _save_image(image, path)


func _save_image(image: Image, path: String) -> bool:
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		push_error("1280×720 görüntü alınamadı: %s" % path)
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("Görüntü kaydedilemedi: %s" % error_string(error))
		return false
	return true


func _finish(repository: Node, code: int) -> void:
	repository.configure_storage_path(ProfileRepository.DEFAULT_SAVE_PATH, false)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	quit(code)
