extends Control

const RARITIES := ["COMMON", "RARE", "EPIC", "LEGENDARY"]
const ROWS := [
	{"key": "hero", "label": "KAHRAMAN", "art": "res://images/heroes/savas_rahibi.png"},
	{"key": "settlement", "label": "YAPI", "art": "res://images/settlements/merkez_kalesi.png"},
	{"key": "special_power", "label": "BÜYÜ", "art": "res://images/spells/buz_muhru.png"},
	{"key": "upgrade", "label": "BECERİ", "art": "res://images/skills/celik_kalkan.png"},
]

func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	var column_width := (viewport_size.x - 180.0) / 4.0
	var row_height := (viewport_size.y - 92.0) / 4.0
	var card_scale: float = min(0.78, min((column_width - 45.0) / 200.0, (row_height - 16.0) / 280.0))

	for column in RARITIES.size():
		_add_label(RARITIES[column], Vector2(180.0 + column * column_width, 22.0), Vector2(column_width, 36.0), 22, HORIZONTAL_ALIGNMENT_CENTER)

	for row in ROWS.size():
		var row_data: Dictionary = ROWS[row]
		_add_label(row_data.label, Vector2(20.0, 70.0 + row * row_height), Vector2(145.0, row_height), 19, HORIZONTAL_ALIGNMENT_CENTER)
		for column in RARITIES.size():
			var rarity_key: String = str(RARITIES[column]).to_lower()
			var scene_path := "res://scenes/card_templates/%s_%s.tscn" % [row_data.key, rarity_key]
			var card := (load(scene_path) as PackedScene).instantiate() as BaseCard
			card.card_name = _sample_name(row)
			card.card_description = "Kısa ve okunaklı kart açıklaması."
			card.energy_cost = 2 + column
			card.card_art = load(row_data.art) as Texture2D
			card.is_draggable = false
			card.normal_scale = Vector2.ONE * card_scale
			card.hover_scale = Vector2.ONE
			card.scale = Vector2.ONE * card_scale
			var visual_position := Vector2(
				180.0 + column * column_width + (column_width - 200.0 * card_scale) * 0.5,
				70.0 + row * row_height + (row_height - 280.0 * card_scale) * 0.5
			)
			card.position = visual_position - Vector2(100.0, 140.0) * (1.0 - card_scale)
			_set_sample_stats(card)
			add_child(card)

func _sample_name(row: int) -> String:
	match row:
		0:
			return "Savaş Rahibi"
		1:
			return "Merkez Kalesi"
		2:
			return "Buz Mührü"
		_:
			return "Çelik Kalkan"

func _set_sample_stats(card: BaseCard) -> void:
	if card is HeroCard:
		card.attack = 7
		card.armor = 4
		card.health = 12
	elif card is SettlementCard:
		card.attack = 5
		card.health = 18
	elif card is SpecialPowerCard:
		card.power_type = "Kontrol"
		card.intensity = 8
	elif card is UpgradeCard:
		card.allowed_targets = "Kahraman"
		card.bonus_attack = 2
		card.bonus_armor = 3
		card.bonus_health = 4

func _add_label(text_value: String, label_position: Vector2, label_size: Vector2, font_size: int, alignment: HorizontalAlignment) -> void:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.text = text_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
