extends SceneTree

const OUTPUT_PATH := "/tmp/tdm_card_runtime_state.png"
const CARD_SCALE := 1.65


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.018, 0.016, 0.015)
	stage.add_child(background)

	var hero := _make_card(
		stage,
		"res://scenes/card_templates/hero_rare.tscn",
		"Sınır Muhafızı",
		"res://images/heroes/sovalye.webp",
		Vector2(170.0, 150.0)
	)
	hero.set_progression_level(2)
	hero.selected_branch_name = "Muhafız"
	hero.apply_status(EffectResolver.STATUS_PROTECTED, 2)
	hero.set_combat_state(BaseCard.CombatState.EXHAUSTED)
	hero.refresh_runtime_badges()

	var structure := _make_card(
		stage,
		"res://scenes/card_templates/settlement_epic.tscn",
		"Runik Burç",
		"res://images/settlements/runik_siginak.png",
		Vector2(650.0, 150.0)
	)
	structure.set_progression_level(3)
	structure.selected_branch_name = "Tahkimat"
	structure.apply_status(EffectResolver.STATUS_POISON, 1)
	structure.set_combat_state(BaseCard.CombatState.EXHAUSTED)
	structure.refresh_runtime_badges()

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Kart durum galerisi kaydedilemedi: %s" % error_string(error))
		quit(1)
		return
	print("CARD_RUNTIME_STATE_CAPTURED: %s" % OUTPUT_PATH)
	quit(0)


func _make_card(parent: Control, scene_path: String, card_name: String, art_path: String, visual_position: Vector2) -> BaseCard:
	var card := (load(scene_path) as PackedScene).instantiate() as BaseCard
	card.card_name = card_name
	card.card_description = "Seviye, geçici etki ve Tükenmişlik şablon içindeki ortak şeritte görünür."
	card.card_art = load(art_path) as Texture2D
	card.energy_cost = 3
	card.is_draggable = false
	card.in_slot_scale = Vector2.ONE * CARD_SCALE
	card.normal_scale = Vector2.ONE * CARD_SCALE
	card.hover_scale = Vector2.ONE
	card.scale = Vector2.ONE * CARD_SCALE
	card.position = visual_position + Vector2(100.0, 140.0) * (CARD_SCALE - 1.0)
	parent.add_child(card)
	var state_anchor := CardSlot.new()
	state_anchor.visible = false
	parent.add_child(state_anchor)
	card._pending_slot = state_anchor
	if card is HeroCard:
		(card as HeroCard).attack = 6
		(card as HeroCard).armor = 3
		(card as HeroCard).health = 10
	elif card is SettlementCard:
		(card as SettlementCard).attack = 3
		(card as SettlementCard).health = 15
	return card
