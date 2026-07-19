extends SceneTree

const BOARD_OUTPUT_PATH := "/tmp/tdm_phase6_1280x720.png"
const STARTING_HAND_OUTPUT_PATH := "/tmp/tdm_phase6_starting_hand_1280x720.png"
const TUTORIAL_OUTPUT_PATH := "/tmp/tdm_phase6_tutorial_1280x720.png"
const PREVIEW_OUTPUT_PATH := "/tmp/tdm_phase6_preview_1280x720.png"
const PAUSE_OUTPUT_PATH := "/tmp/tdm_phase6_pause_1280x720.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PHASE_SIX_VISUAL_CAPTURE_SKIPPED: etkin görüntü sürücüsü gerekiyor")
		quit(0)
		return
	var capture_viewport := SubViewport.new()
	capture_viewport.size = Vector2i(1280, 720)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var battlefield_scene := load("res://battlefield.tscn") as PackedScene
	if not battlefield_scene:
		push_error("battlefield.tscn yüklenemedi")
		quit(1)
		return
	var battlefield := battlefield_scene.instantiate() as BattlefieldUI
	capture_viewport.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame
	battlefield._apply_responsive_layout()
	# Texture and custom-draw layers can settle over several Metal frames after
	# the responsive layout changes inside a SubViewport.
	for _frame in range(45):
		await process_frame

	var manager := battlefield.game_manager as GameManager
	manager.cards_drawn_per_turn = 0
	var active_player := manager.first_player_id
	var opponent := manager.get_opponent_id(active_player)
	if not _save_viewport(capture_viewport, STARTING_HAND_OUTPUT_PATH):
		quit(1)
		return
	manager.confirm_mulligan(active_player)
	manager.confirm_mulligan(opponent)
	await process_frame

	var knight := _place_hero(_get_slot(battlefield, active_player, "Slot_F1"), active_player, "sovalye")
	var fairy := _place_hero(_get_slot(battlefield, active_player, "Slot_B2"), active_player, "peri")
	_place_structure(_get_slot(battlefield, active_player, "Slot_S1"), active_player, "altin_madeni")
	var opponent_front_slot := _get_slot(battlefield, opponent, "Slot_F1")
	_place_hero(opponent_front_slot, opponent, "gladiator")
	_place_structure(_get_slot(battlefield, opponent, "Slot_S2"), opponent, "okcu_kulesi")
	await process_frame

	knight.experience = 2
	knight.selected_branch_id = "muhafiz"
	knight.selected_branch_name = "Muhafız"
	knight.set_progression_level(2)
	knight.apply_status("poison", 2, 1)
	knight.apply_status("protected", 2, 1)
	knight.set_combat_state(BaseCard.CombatState.READY)
	fairy.set_combat_state(BaseCard.CombatState.EXHAUSTED)
	battlefield._refresh_lane_visuals()
	battlefield.force_show_tutorial(0)
	battlefield._show_phase_banner()
	for _frame in range(4):
		await process_frame
	if not _save_viewport(capture_viewport, TUTORIAL_OUTPUT_PATH):
		quit(1)
		return

	# Hide directly so visual QA never writes the player's tutorial preference.
	battlefield._tutorial_overlay.visible = false
	battlefield._refresh_phase_ui()
	battlefield._show_phase_banner()
	for _frame in range(3):
		await process_frame
	if not _save_viewport(capture_viewport, BOARD_OUTPUT_PATH):
		quit(1)
		return

	battlefield._hide_phase_banner()
	battlefield._preview_occupied_slot(knight.current_slot)
	# Let the inspector's short reveal tween settle before visual QA capture.
	for _frame in range(10):
		await process_frame
	if not _save_viewport(capture_viewport, PREVIEW_OUTPUT_PATH):
		quit(1)
		return

	battlefield._open_pause_menu()
	for _frame in range(2):
		await process_frame
	if not _save_viewport(capture_viewport, PAUSE_OUTPUT_PATH):
		quit(1)
		return
	battlefield._resume_from_pause()
	print("PHASE_SIX_VISUAL_CAPTURE_OK: %s • %s • %s • %s • %s" % [STARTING_HAND_OUTPUT_PATH, BOARD_OUTPUT_PATH, TUTORIAL_OUTPUT_PATH, PREVIEW_OUTPUT_PATH, PAUSE_OUTPUT_PATH])
	capture_viewport.queue_free()
	await process_frame
	quit(0)

func _save_viewport(viewport: SubViewport, output_path: String) -> bool:
	# Headless CI may not emit frame_post_draw continuously. Godot 4.7 exposes
	# force_draw for deterministic main-thread viewport capture.
	RenderingServer.force_draw(true, 0.0)
	var viewport_texture := viewport.get_texture()
	if not viewport_texture:
		push_error("Etkin görüntü sürücüsü bir ViewportTexture üretmedi")
		return false
	var image := viewport_texture.get_image()
	if not image or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		var captured_size := image.get_size() if image else Vector2i.ZERO
		push_error("1280×720 görüntü yakalanamadı: %s" % captured_size)
		return false
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Görsel kaydedilemedi: %s" % error_string(save_error))
		return false
	return true

func _get_slot(battlefield: BattlefieldUI, player_id: int, slot_name: String) -> CardSlot:
	return battlefield.get_node("Player%dZone/Grid/%s" % [player_id, slot_name]) as CardSlot

func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)
	return hero

func _place_structure(slot: CardSlot, owner_id: int, card_id: String) -> SettlementCard:
	var structure := SettlementCard.new()
	structure.owner_id = owner_id
	structure.card_id = card_id
	slot.add_child(structure)
	return structure
