extends SceneTree

const RARITIES := ["common", "rare", "epic", "legendary"]
const TOP_ALIGNED_CARD_ART_SCRIPT := preload("res://scripts/top_aligned_card_art.gd")
const RARITY_TINTS := [
	Color(0.80, 0.80, 0.76, 1.0),
	Color(0.55, 0.76, 1.00, 1.0),
	Color(0.78, 0.54, 1.00, 1.0),
	Color(1.00, 0.72, 0.32, 1.0),
]
const TYPE_CONFIG := {
	"hero": {
		"frame": "res://images/cards/templates/hero_frame.png",
		"plain_frame": "res://images/cards/templates/source/plain/hero_frame.png",
		"art": Rect2(20.0, 18.0, 160.0, 128.0),
		"name": Rect2(20.0, 183.0, 160.0, 23.0),
		"description": Rect2(21.0, 214.0, 158.0, 49.0),
		"fields": {
			"CardFrame/RuntimeStateRail": Rect2(20.0, 124.0, 160.0, 20.0),
			"CardFrame/AttackBadge": Rect2(22.0, 151.0, 55.0, 26.0),
			"CardFrame/ArmorBadge": Rect2(78.0, 151.0, 55.0, 26.0),
			"CardFrame/HealthBadge": Rect2(134.0, 151.0, 55.0, 26.0),
		},
		"subfields": {
			"CardFrame/AttackBadge/AttackLabel": Rect2(27.0, 0.0, 22.0, 26.0),
			"CardFrame/ArmorBadge/ArmorLabel": Rect2(27.0, 0.0, 22.0, 26.0),
			"CardFrame/HealthBadge/HealthLabel": Rect2(27.0, 0.0, 22.0, 26.0),
		},
		"baked_icons": [
			Rect2(13.0, 18.0, 13.0, 18.0),
			Rect2(26.0, 155.0, 15.0, 15.0),
			Rect2(83.0, 155.0, 15.0, 15.0),
			Rect2(139.0, 155.0, 15.0, 15.0),
		],
		"legacy_icon_nodes": [
			"CardFrame/GoldBadge/LightningIcon",
			"CardFrame/AttackBadge/CaptionIcon",
			"CardFrame/ArmorBadge/CaptionIcon",
			"CardFrame/HealthBadge/CaptionIcon",
		],
	},
	"settlement": {
		"frame": "res://images/cards/templates/settlement_frame.png",
		"plain_frame": "res://images/cards/templates/source/plain/settlement_frame.png",
		"art": Rect2(19.0, 18.0, 162.0, 129.0),
		"name": Rect2(20.0, 196.0, 160.0, 22.0),
		"description": Rect2(21.0, 225.0, 158.0, 39.0),
		"fields": {
			"CardFrame/RuntimeStateRail": Rect2(20.0, 125.0, 160.0, 20.0),
			"CardFrame/AttackBadge": Rect2(23.0, 158.0, 64.0, 29.0),
			"CardFrame/HealthBadge": Rect2(113.0, 158.0, 64.0, 29.0),
		},
		"subfields": {
			"CardFrame/AttackBadge/AttackLabel": Rect2(32.0, 0.0, 26.0, 29.0),
			"CardFrame/HealthBadge/HealthLabel": Rect2(32.0, 0.0, 26.0, 29.0),
		},
		"baked_icons": [
			Rect2(13.0, 18.0, 13.0, 18.0),
			Rect2(32.0, 162.0, 21.0, 21.0),
			Rect2(122.0, 162.0, 21.0, 21.0),
		],
		"legacy_icon_nodes": [
			"CardFrame/GoldBadge/LightningIcon",
			"CardFrame/AttackBadge/CaptionIcon",
			"CardFrame/HealthBadge/CaptionIcon",
		],
	},
	"special_power": {
		"frame": "res://images/cards/templates/spell_frame.png",
		"plain_frame": "res://images/cards/templates/source/plain/spell_frame.png",
		"art": Rect2(17.0, 21.0, 166.0, 128.0),
		"name": Rect2(20.0, 175.0, 160.0, 23.0),
		"description": Rect2(21.0, 209.0, 158.0, 53.0),
		"fields": {
			"CardFrame/PowerTypeLabel": Rect2(40.0, 154.0, 74.0, 18.0),
			"CardFrame/IntensityLabel": Rect2(143.0, 154.0, 36.0, 18.0),
		},
		"baked_icons": [
			Rect2(13.0, 18.0, 13.0, 18.0),
			Rect2(23.0, 155.0, 16.0, 16.0),
			Rect2(127.0, 155.0, 16.0, 16.0),
		],
		"legacy_icon_nodes": [
			"CardFrame/GoldBadge/LightningIcon",
			"CardFrame/PowerTypeIcon",
			"CardFrame/IntensityIcon",
		],
	},
	"upgrade": {
		"frame": "res://images/cards/templates/upgrade_frame.png",
		"plain_frame": "res://images/cards/templates/source/plain/upgrade_frame.png",
		"art": Rect2(19.0, 28.0, 162.0, 122.0),
		"name": Rect2(20.0, 181.0, 160.0, 22.0),
		"description": Rect2(21.0, 213.0, 158.0, 50.0),
		"fields": {
			"CardFrame/AllowedTargetsLabel": Rect2(39.0, 154.0, 53.0, 22.0),
			"CardFrame/AttackBadge": Rect2(98.0, 154.0, 24.0, 22.0),
			"CardFrame/ArmorBadge": Rect2(127.0, 154.0, 24.0, 22.0),
			"CardFrame/HealthBadge": Rect2(156.0, 154.0, 24.0, 22.0),
		},
		"subfields": {
			"CardFrame/AttackBadge/AttackLabel": Rect2(9.0, 0.0, 12.0, 22.0),
			"CardFrame/ArmorBadge/ArmorLabel": Rect2(9.0, 0.0, 12.0, 22.0),
			"CardFrame/HealthBadge/HealthLabel": Rect2(9.0, 0.0, 12.0, 22.0),
		},
		"baked_icons": [
			Rect2(13.0, 19.0, 13.0, 18.0),
			Rect2(22.0, 157.0, 16.0, 16.0),
			Rect2(100.0, 160.0, 9.0, 10.0),
			Rect2(129.0, 160.0, 9.0, 10.0),
			Rect2(158.0, 160.0, 9.0, 10.0),
		],
		"legacy_icon_nodes": [
			"CardFrame/GoldBadge/LightningIcon",
			"CardFrame/TargetIcon",
			"CardFrame/AttackBadge/CaptionIcon",
			"CardFrame/ArmorBadge/CaptionIcon",
			"CardFrame/HealthBadge/CaptionIcon",
		],
	},
}

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for type_key in TYPE_CONFIG:
		var config: Dictionary = TYPE_CONFIG[type_key]
		for rarity_index in RARITIES.size():
			await _audit_scene(type_key, config, rarity_index)
	_finish()

func _audit_scene(type_key: String, config: Dictionary, rarity_index: int) -> void:
	var scene_path := "res://scenes/card_templates/%s_%s.tscn" % [type_key, RARITIES[rarity_index]]
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "%s yüklenemedi" % scene_path)
	if not packed:
		return

	var card := packed.instantiate() as BaseCard
	_expect(card != null, "%s BaseCard üretmedi" % scene_path)
	if not card:
		return

	root.add_child(card)
	await process_frame

	_expect(_rect_matches(Rect2(card.position, card.size), Rect2(0.0, 0.0, 200.0, 280.0)), "%s kart ölçüsü 200x280 olmalı" % scene_path)
	_expect(card.rarity == rarity_index, "%s nadirlik değeri yanlış" % scene_path)
	_expect(_control_matches(card, "CardFrame/GoldBadge", Rect2(10.0, 10.0 if type_key != "upgrade" else 11.0, 34.0, 34.0)), "%s kaynak alanı yanlış" % scene_path)
	_expect(_control_matches(card, "CardFrame/ArtRect", config.art), "%s resim alanı yanlış" % scene_path)
	_expect(_control_matches(card, "CardFrame/NameLabel", config.name), "%s isim alanı yanlış" % scene_path)
	_expect(_control_matches(card, "CardFrame/DescLabel", config.description), "%s açıklama alanı yanlış" % scene_path)

	for node_path in config.fields:
		_expect(_control_matches(card, node_path, config.fields[node_path]), "%s içinde %s alanı yanlış" % [scene_path, node_path])
	for node_path in config.get("subfields", {}):
		_expect(_control_matches(card, node_path, config.subfields[node_path]), "%s içinde %s alt alanı yanlış" % [scene_path, node_path])

	var resource_caption := card.get_node_or_null("CardFrame/GoldBadge/CaptionLabel") as Label
	_expect(resource_caption == null, "%s Enerji alanına çalışma anında açıklama eklememeli" % scene_path)
	_expect(_control_matches(card, "CardFrame/GoldBadge/GoldLabel", Rect2(11.0, 0.0, 19.0, 34.0)), "%s Enerji sayısı şimşek yanında değil" % scene_path)
	var energy_label := card.get_node_or_null("CardFrame/GoldBadge/GoldLabel") as Label
	_expect(_is_centered_label(energy_label), "%s Enerji sayısının hizası ortada olmalı" % scene_path)
	for node_path in config.get("legacy_icon_nodes", []):
		_expect(card.get_node_or_null(str(node_path)) == null, "%s çalışma anında ikon üretmemeli: %s" % [scene_path, node_path])
	for node_path in config.get("text_prefixes", {}):
		var metadata_label := card.get_node_or_null(node_path) as Label
		_expect(metadata_label != null and metadata_label.text.begins_with(str(config.text_prefixes[node_path])), "%s içinde %s anlam etiketi eksik" % [scene_path, node_path])
	for node_path in config.fields:
		var field_label := card.get_node_or_null(node_path) as Label
		if field_label:
			_expect(_is_centered_label(field_label), "%s içinde %s ortalanmalı" % [scene_path, node_path])
	if type_key in ["hero", "settlement"]:
		var runtime_rail := card.get_node_or_null("CardFrame/RuntimeStateRail") as Panel
		_expect(runtime_rail != null, "%s durumlar için şablon içi bir şerit taşımalı" % scene_path)
		for runtime_badge in [card._progression_badge, card._effect_state_badge, card._combat_state_badge]:
			_expect(
				runtime_badge != null and runtime_badge.get_parent() == runtime_rail,
				"%s seviye, etki ve tükenmişlik rozetlerini şablon şeridinde tutmalı" % scene_path
			)

	var background := card.get_node_or_null("CardFrame/TemplateBackground") as TextureRect
	var art := card.get_node_or_null("CardFrame/ArtRect") as TextureRect
	var name_label := card.get_node_or_null("CardFrame/NameLabel") as Label
	var description_label := card.get_node_or_null("CardFrame/DescLabel") as Label
	_expect(background != null and background.texture != null, "%s çerçevesi yok" % scene_path)
	_expect(art != null and art.get_script() == TOP_ALIGNED_CARD_ART_SCRIPT, "%s üstten hizalı cover resim alanı kullanmalı" % scene_path)
	_expect(art != null and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "%s resim alanı cover olmalı" % scene_path)
	_expect(card.get_node_or_null("CardFrame/ArtBackdrop") == null, "%s resim alanında boşluk dolgusu kalmamalı" % scene_path)
	_expect(_is_centered_label(name_label), "%s kart adı ortalanmalı" % scene_path)
	_expect(_is_centered_label(description_label), "%s açıklaması ortalanmalı" % scene_path)
	if background and background.texture:
		_expect(background.texture.resource_path == str(config.frame), "%s yanlış çerçeve kullanıyor" % scene_path)
		_expect(background.self_modulate.is_equal_approx(RARITY_TINTS[rarity_index]), "%s nadirlik rengi yanlış" % scene_path)
		var image := background.texture.get_image()
		_expect(image != null, "%s çerçeve görseli okunamadı" % scene_path)
		if image:
			var center_alpha := image.get_pixel(image.get_width() / 2, image.get_height() / 3).a
			var panel_alpha := image.get_pixel(image.get_width() / 2, int(image.get_height() * 0.9)).a
			_expect(center_alpha < 0.05, "%s resim penceresi şeffaf değil" % scene_path)
			_expect(panel_alpha > 0.95, "%s bilgi panelleri opak kalmalı" % scene_path)
	if background and art:
		_expect(art.z_index < background.z_index, "%s resim çerçevenin arkasında olmalı" % scene_path)
	if background and name_label:
		_expect(name_label.z_index > background.z_index, "%s metin çerçevenin üstünde olmalı" % scene_path)
	for baked_icon_rect in config.get("baked_icons", []):
		_expect(
			_baked_region_differs(str(config.frame), str(config.plain_frame), baked_icon_rect),
			"%s sabit ikon bölgesi kaynak çerçeveye gömülmemiş: %s" % [scene_path, baked_icon_rect]
		)
	if type_key == "hero":
		_expect(_hero_health_well_is_normalized(str(config.frame)), "%s sağlık yuvasındaki kalkan kabartması temizlenmemiş" % scene_path)

	card.queue_free()
	await process_frame

func _control_matches(card: BaseCard, node_path: String, expected: Rect2) -> bool:
	var control := card.get_node_or_null(node_path) as Control
	if not control:
		return false
	var actual := Rect2(control.position, control.size)
	if not _rect_matches(actual, expected):
		print("RECT_MISMATCH %s actual=%s expected=%s" % [node_path, actual, expected])
		return false
	return true

func _rect_matches(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.is_equal_approx(expected.position) and actual.size.is_equal_approx(expected.size)

func _is_centered_label(label: Label) -> bool:
	return (
		label != null
		and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER
	)

func _baked_region_differs(frame_path: String, plain_frame_path: String, card_rect: Rect2) -> bool:
	var baked := Image.load_from_file(ProjectSettings.globalize_path(frame_path))
	var plain := Image.load_from_file(ProjectSettings.globalize_path(plain_frame_path))
	if baked == null or plain == null or baked.is_empty() or plain.is_empty() or baked.get_size() != plain.get_size():
		return false
	var scale := Vector2(float(baked.get_width()) / 200.0, float(baked.get_height()) / 280.0)
	var pixel_rect := Rect2i(
		Vector2i(floori(card_rect.position.x * scale.x), floori(card_rect.position.y * scale.y)),
		Vector2i(ceili(card_rect.size.x * scale.x), ceili(card_rect.size.y * scale.y))
	)
	var changed_pixels := 0
	for y in range(pixel_rect.position.y, mini(pixel_rect.end.y, baked.get_height())):
		for x in range(pixel_rect.position.x, mini(pixel_rect.end.x, baked.get_width())):
			var current := baked.get_pixel(x, y)
			var source := plain.get_pixel(x, y)
			var difference := (
				absf(current.r - source.r)
				+ absf(current.g - source.g)
				+ absf(current.b - source.b)
				+ absf(current.a - source.a)
			)
			if difference > 0.10:
				changed_pixels += 1
	var minimum_changed := maxi(20, ceili(float(pixel_rect.size.x * pixel_rect.size.y) / 50.0))
	return changed_pixels >= minimum_changed

func _hero_health_well_is_normalized(frame_path: String) -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path(frame_path))
	if image == null or image.is_empty():
		return false
	var scale := Vector2(float(image.get_width()) / 200.0, float(image.get_height()) / 280.0)
	var source_center := Vector2i(roundi(33.6 * scale.x), roundi(162.6 * scale.y))
	var destination_center := Vector2i(roundi(146.4 * scale.x), roundi(162.6 * scale.y))
	var inner_radius := roundi(11.5 * minf(scale.x, scale.y))
	var outer_radius := roundi(13.0 * minf(scale.x, scale.y))
	var compared_pixels := 0
	var total_difference := 0.0
	for offset_y in range(-outer_radius, outer_radius + 1):
		for offset_x in range(-outer_radius, outer_radius + 1):
			var distance := Vector2(float(offset_x), float(offset_y)).length()
			if distance < float(inner_radius) or distance > float(outer_radius):
				continue
			var source := image.get_pixelv(source_center + Vector2i(offset_x, offset_y))
			var destination := image.get_pixelv(destination_center + Vector2i(offset_x, offset_y))
			total_difference += (
				absf(source.r - destination.r)
				+ absf(source.g - destination.g)
				+ absf(source.b - destination.b)
				+ absf(source.a - destination.a)
			)
			compared_pixels += 1
	if compared_pixels == 0:
		return false
	return total_difference / float(compared_pixels) < 0.02

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("CARD_TEMPLATE_AUDIT_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("CARD_TEMPLATE_AUDIT_FAILED: %d" % _failures.size())
	quit(1)
