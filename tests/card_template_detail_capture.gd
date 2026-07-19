extends SceneTree

const OUTPUT_PATH := "/tmp/tdm_card_template_detail.png"
const CARD_SCALE := 1.5
const CARD_TYPES := [
	{
		"scene": "res://scenes/card_templates/hero_common.tscn",
		"title": "KAHRAMAN — ZIRH 0",
		"name": "Savaş Rahibi",
		"description": "Dost birlikleri savunur ve cepheyi güçlendirir.",
		"art": "res://images/heroes/savas_rahibi.png",
	},
	{
		"scene": "res://scenes/card_templates/settlement_common.tscn",
		"title": "YAPI — SALDIRI 0",
		"name": "Merkez Kalesi",
		"description": "Dayanıklı savunma merkezi ve güvenli üs.",
		"art": "res://images/settlements/merkez_kalesi.png",
	},
	{
		"scene": "res://scenes/card_templates/special_power_common.tscn",
		"title": "BÜYÜ — UZUN TÜR",
		"name": "Şifa Dalgası",
		"description": "Hedefe iyileştirici bir enerji dalgası gönderir.",
		"art": "res://images/spells/kutsal_isik.png",
	},
	{
		"scene": "res://scenes/card_templates/upgrade_common.tscn",
		"title": "BECERİ — 0 / +2 / 0",
		"name": "Çelik Kalkan",
		"description": "Kahramana zırh ve dayanıklılık kazandırır.",
		"art": "res://images/skills/celik_kalkan.png",
	},
]

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.022, 0.02)
	stage.add_child(background)

	for index in CARD_TYPES.size():
		var config: Dictionary = CARD_TYPES[index]
		var packed := load(str(config.scene)) as PackedScene
		var card := packed.instantiate() as BaseCard
		card.card_name = str(config.name)
		card.card_description = str(config.description)
		card.card_art = load(str(config.art)) as Texture2D
		card.energy_cost = index + 1
		card.is_draggable = false
		card.normal_scale = Vector2.ONE * CARD_SCALE
		card.hover_scale = Vector2.ONE
		card.scale = Vector2.ONE * CARD_SCALE
		var visual_top_left := Vector2(20.0 + index * 310.0, 130.0)
		card.position = visual_top_left + Vector2(100.0, 140.0) * (CARD_SCALE - 1.0)
		_configure_stats(card)
		stage.add_child(card)
		_add_title(stage, str(config.title), Vector2(20.0 + index * 310.0, 55.0))

	await process_frame
	await process_frame
	await process_frame
	# Headless macOS can leave frame_post_draw pending indefinitely. Force the
	# viewport draw synchronously before reading its texture.
	RenderingServer.force_draw(false)
	var viewport_texture := root.get_viewport().get_texture()
	if viewport_texture == null:
		push_error("Detay galerisi için renderer viewport texture üretmedi")
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("Detay galerisi için renderer görüntü üretmedi")
		quit(1)
		return
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Detay galerisi kaydedilemedi: %s" % error_string(error))
		quit(1)
		return
	print("CARD_TEMPLATE_DETAIL_CAPTURED: %s" % OUTPUT_PATH)
	quit(0)

func _configure_stats(card: BaseCard) -> void:
	if card is HeroCard:
		card.attack = 7
		card.armor = 0
		card.health = 12
	elif card is SettlementCard:
		card.attack = 0
		card.health = 18
	elif card is SpecialPowerCard:
		card.power_type = "İyileştirme"
		card.intensity = 8
	elif card is UpgradeCard:
		card.allowed_targets = "Hero"
		card.bonus_attack = 0
		card.bonus_armor = 2
		card.bonus_health = 0

func _add_title(parent: Control, title: String, title_position: Vector2) -> void:
	var label := Label.new()
	label.position = title_position
	label.size = Vector2(300.0, 48.0)
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.68))
	parent.add_child(label)
