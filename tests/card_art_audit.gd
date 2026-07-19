extends SceneTree

const EXPECTED_COUNTS := {
	"heroes": 54,
	"settlements": 22,
	"special_powers": 19,
	"upgrades": 17,
	"effects": 13,
}

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale("tr")
	CardDatabase.load_all(true)
	var seen_ids: Dictionary = {}

	for card_type in EXPECTED_COUNTS:
		var cards := CardDatabase.get_cards_for_type(card_type)
		_expect(cards.size() == int(EXPECTED_COUNTS[card_type]), "%s kart sayısı %d olmalı" % [card_type, EXPECTED_COUNTS[card_type]])
		for card_data in cards:
			var card_id := str(card_data.get("id", ""))
			var unique_key := "%s/%s" % [card_type, card_id]
			_expect(not seen_ids.has(unique_key), "Tekrarlanan kart kimliği: %s" % unique_key)
			seen_ids[unique_key] = true

			var image_path := str(card_data.get("image_url", ""))
			_expect(not image_path.is_empty(), "%s görsel yolu boş olmamalı" % unique_key)
			if image_path.is_empty():
				continue
			_expect(ResourceLoader.exists(image_path), "%s görseli bulunamadı: %s" % [unique_key, image_path])
			if ResourceLoader.exists(image_path):
				var texture := load(image_path)
				_expect(texture is Texture2D, "%s görseli Texture2D olarak yüklenmeli" % unique_key)

	var playable_refs := CardDatabase.get_playable_card_refs()
	_expect(playable_refs.size() == 110, "Oynanabilir havuz yeni içerikle 110 farklı kart içermeli")
	var deck := CardDatabase.build_fixed_deck()
	_expect(deck.size() == GameRules.DECK_SIZE, "Varsayılan deste tam olarak 30 kart içermeli")

	var battlefield_scene := load("res://battlefield.tscn") as PackedScene
	_expect(battlefield_scene != null, "Kart şablonlarını sınamak için battlefield.tscn yüklenemedi")
	if battlefield_scene:
		var card_factory := battlefield_scene.instantiate() as BattlefieldUI
		var rendered_cards: Array[BaseCard] = []
		for card_ref in playable_refs:
			var card := card_factory._instantiate_card_from_ref(card_ref, 1)
			_expect(card != null, "%s/%s kart şablonu oluşturulamadı" % [card_ref.get("card_type", ""), card_ref.get("card_id", "")])
			if card:
				root.add_child(card)
				rendered_cards.append(card)
		await process_frame
		for card in rendered_cards:
			_expect(card.card_art != null, "%s kart görselini şablona yükleyemedi" % card.card_id)
			var art_rect := card.get_node_or_null("CardFrame/ArtRect") as TextureRect
			_expect(
				art_rect != null and art_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
				"%s kart görseli alanı tamamen doldurmalı" % card.card_id
			)
			_expect(art_rect != null and art_rect.has_method("get_visible_source_rect"), "%s üstten hizalı cover çizicisini kullanmalı" % card.card_id)
			_expect(art_rect != null and art_rect.get("source_texture") == card.card_art, "%s kart görseli cover çizicisine aktarılmalı" % card.card_id)
			if art_rect and art_rect.has_method("get_visible_source_rect"):
				var source_rect := art_rect.call("get_visible_source_rect") as Rect2
				_expect(is_zero_approx(source_rect.position.y), "%s görselinin üst kenarı görünür kalmalı" % card.card_id)
				_expect(not source_rect.size.is_zero_approx(), "%s görünür kaynak alanı hesaplanmalı" % card.card_id)
				if source_rect.size.y > 0.0 and art_rect.size.y > 0.0:
					var source_aspect := source_rect.size.x / source_rect.size.y
					var target_aspect := art_rect.size.x / art_rect.size.y
					_expect(is_equal_approx(source_aspect, target_aspect), "%s cover kırpma oranı yanlış" % card.card_id)
			_expect(card.get_node_or_null("CardFrame/ArtBackdrop") == null, "%s görsel alanında boş mat bırakmamalı" % card.card_id)
			_audit_populated_fields(card)
			card.queue_free()
		card_factory.free()
		await process_frame

	_finish()

func _audit_populated_fields(card: BaseCard) -> void:
	if card is HeroCard:
		_expect_visible_badge(card, "AttackBadge", "AttackLabel", str(card.attack))
		_expect_visible_badge(card, "ArmorBadge", "ArmorLabel", str(card.armor))
		_expect_visible_badge(card, "HealthBadge", "HealthLabel", str(card.health))
	elif card is SettlementCard:
		_expect_visible_badge(card, "AttackBadge", "AttackLabel", str(card.attack))
		_expect_visible_badge(card, "HealthBadge", "HealthLabel", str(card.health))
	elif card is UpgradeCard:
		_expect_visible_badge(card, "AttackBadge", "AttackLabel", _format_bonus(card.bonus_attack))
		_expect_visible_badge(card, "ArmorBadge", "ArmorLabel", _format_bonus(card.bonus_armor))
		_expect_visible_badge(card, "HealthBadge", "HealthLabel", _format_bonus(card.bonus_health))
		var target_label := card.get_node_or_null("CardFrame/AllowedTargetsLabel") as Label
		_expect(target_label != null and not target_label.text.strip_edges().is_empty(), "%s hedef alanı boş kalmamalı" % card.card_id)
		_expect(card.get_node_or_null("CardFrame/TargetIcon") == null, "%s hedef ikonunu çalışma anında üretmemeli" % card.card_id)
	elif card is SpecialPowerCard:
		var power_label := card.get_node_or_null("CardFrame/PowerTypeLabel") as Label
		var intensity_label := card.get_node_or_null("CardFrame/IntensityLabel") as Label
		_expect(power_label != null and power_label.text == tr(card.power_type), "%s büyü türü eksik" % card.card_id)
		_expect(intensity_label != null and intensity_label.text == str(card.intensity), "%s büyü değeri eksik" % card.card_id)

func _expect_visible_badge(card: BaseCard, badge_name: String, label_name: String, expected_text: String) -> void:
	var badge := card.get_node_or_null("CardFrame/%s" % badge_name) as Panel
	var label := card.get_node_or_null("CardFrame/%s/%s" % [badge_name, label_name]) as Label
	_expect(badge != null and badge.visible, "%s kartında %s boş bırakılmamalı" % [card.card_id, badge_name])
	_expect(label != null and label.text == expected_text, "%s kartında %s değeri eksik" % [card.card_id, badge_name])

func _format_bonus(value: int) -> String:
	return ("+" if value > 0 else "") + str(value)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("CARD_ART_AUDIT_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("CARD_ART_AUDIT_FAILED: %d" % _failures.size())
	quit(1)
