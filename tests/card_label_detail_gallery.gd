extends Control

const CARDS := [
	{"scene": "res://scenes/card_templates/hero_rare.tscn", "label": "KAHRAMAN", "art": "res://images/heroes/savas_rahibi.png"},
	{"scene": "res://scenes/card_templates/settlement_rare.tscn", "label": "YAPI", "art": "res://images/settlements/merkez_kalesi.png"},
	{"scene": "res://scenes/card_templates/special_power_rare.tscn", "label": "BÜYÜ", "art": "res://images/spells/buz_muhru.png"},
	{"scene": "res://scenes/card_templates/upgrade_rare.tscn", "label": "BECERİ", "art": "res://images/skills/celik_kalkan.png"},
]

func _ready() -> void:
	_add_label("KART DEĞERLERİ — HİZALAMA VE ANLAMLANDIRMA", Vector2(0.0, 24.0), Vector2(1280.0, 42.0), 24)
	for index in CARDS.size():
		var config: Dictionary = CARDS[index]
		_add_label(config.label, Vector2(40.0 + index * 300.0, 92.0), Vector2(280.0, 34.0), 18)
		var card := (load(config.scene) as PackedScene).instantiate() as BaseCard
		card.card_art = load(config.art) as Texture2D
		card.card_name = _sample_name(index)
		card.card_description = "Değer alanları açık, hizalı ve kolay okunur."
		card.energy_cost = index + 2
		card.is_draggable = false
		card.normal_scale = Vector2.ONE * 1.25
		card.hover_scale = Vector2.ONE
		card.scale = Vector2.ONE * 1.25
		var visual_position := Vector2(55.0 + index * 300.0, 155.0)
		card.position = visual_position - Vector2(100.0, 140.0) * (1.0 - 1.25)
		_set_stats(card)
		add_child(card)

func _sample_name(index: int) -> String:
	return ["Savaş Rahibi", "Merkez Kalesi", "Buz Mührü", "Çelik Kalkan"][index]

func _set_stats(card: BaseCard) -> void:
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

func _add_label(text_value: String, label_position: Vector2, label_size: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
