class_name DeckRepository extends Node

signal decks_changed
signal active_deck_changed(deck_id: String)

const DEFAULT_STORAGE_PATH := "user://darwine_decks.json"
const SAVE_VERSION := 1
const MAX_SAVED_DECKS := 8
const STARTER_DECK_ORDER := ["muhafiz_hatti", "firtina_hucumu", "runik_kontrol"]

var storage_path := DEFAULT_STORAGE_PATH
var _decks: Dictionary = {}
var _active_deck_id := ""
var _loaded := false
var _updated_at_unix := 0


func _ready() -> void:
	load_decks()


func load_decks(force_reload: bool = false) -> void:
	if _loaded and not force_reload:
		return
	CardDatabase.load_all()
	_decks.clear()
	_active_deck_id = ""
	_updated_at_unix = 0

	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_load_payload(parsed as Dictionary)

	_ensure_starter_decks()
	if not _decks.has(_active_deck_id):
		_active_deck_id = STARTER_DECK_ORDER[0]
	_loaded = true
	_save()
	decks_changed.emit()
	active_deck_changed.emit(_active_deck_id)


func get_decks() -> Array[Dictionary]:
	load_decks()
	var ordered: Array[Dictionary] = []
	for starter_id in STARTER_DECK_ORDER:
		if _decks.has(starter_id):
			ordered.append((_decks[starter_id] as Dictionary).duplicate(true))
	var custom_ids: Array[String] = []
	for deck_id_variant in _decks.keys():
		var deck_id := str(deck_id_variant)
		if deck_id not in STARTER_DECK_ORDER:
			custom_ids.append(deck_id)
	custom_ids.sort_custom(func(left: String, right: String) -> bool:
		return str((_decks[left] as Dictionary).get("name", left)).naturalnocasecmp_to(
			str((_decks[right] as Dictionary).get("name", right))
		) < 0
	)
	for deck_id in custom_ids:
		ordered.append((_decks[deck_id] as Dictionary).duplicate(true))
	return ordered


func get_deck(deck_id: String) -> Dictionary:
	load_decks()
	var deck_variant: Variant = _decks.get(deck_id, {})
	return (deck_variant as Dictionary).duplicate(true) if deck_variant is Dictionary else {}


func get_active_deck_id() -> String:
	load_decks()
	return _active_deck_id


func get_active_deck() -> Dictionary:
	return get_deck(get_active_deck_id())


func get_active_deck_cards() -> Array:
	var deck := get_active_deck()
	return (deck.get("cards", []) as Array).duplicate(true)


func get_starter_deck_cards(deck_id: String) -> Array:
	var resolved_id := deck_id if deck_id in STARTER_DECK_ORDER else STARTER_DECK_ORDER[0]
	return (get_deck(resolved_id).get("cards", []) as Array).duplicate(true)


func get_ai_deck_cards(difficulty: int) -> Array:
	match difficulty:
		MatchSetup.AIDifficulty.EASY:
			return get_starter_deck_cards("muhafiz_hatti")
		MatchSetup.AIDifficulty.HARD:
			return get_starter_deck_cards("firtina_hucumu")
		_:
			return get_starter_deck_cards("runik_kontrol")


func set_active_deck(deck_id: String) -> Dictionary:
	load_decks()
	if not _decks.has(deck_id):
		return _failure("Deste bulunamadı.")
	var validation := validate_deck_cards((_decks[deck_id] as Dictionary).get("cards", []))
	if not bool(validation.get("success", false)):
		return validation
	_active_deck_id = deck_id
	_updated_at_unix = int(Time.get_unix_time_from_system())
	_save()
	active_deck_changed.emit(deck_id)
	decks_changed.emit()
	return {"success": true, "deck": get_deck(deck_id)}


func create_deck(name: String, source_cards: Array = []) -> Dictionary:
	load_decks()
	if _decks.size() >= MAX_SAVED_DECKS:
		return _failure("En fazla %d deste kaydedebilirsin." % MAX_SAVED_DECKS)
	var cards := source_cards.duplicate(true)
	if cards.is_empty():
		cards = get_active_deck_cards()
	var validation := validate_deck_cards(cards)
	if not bool(validation.get("success", false)):
		return validation
	var deck_id := _generate_deck_id()
	_decks[deck_id] = {
		"id": deck_id,
		"name": _sanitize_name(name, "Yeni Deste"),
		"archetype": "custom",
		"description": "Komutan tarafından hazırlanan özel deste.",
		"is_starter": false,
		"cards": _sanitize_card_refs(cards),
		"updated_at": Time.get_datetime_string_from_system(true, true),
	}
	_updated_at_unix = int(Time.get_unix_time_from_system())
	_save()
	decks_changed.emit()
	return {"success": true, "deck": get_deck(deck_id)}


func save_deck(deck_id: String, name: String, cards: Array) -> Dictionary:
	load_decks()
	if not _decks.has(deck_id):
		return _failure("Kaydedilecek deste bulunamadı.")
	var validation := validate_deck_cards(cards)
	if not bool(validation.get("success", false)):
		return validation
	var deck := (_decks[deck_id] as Dictionary).duplicate(true)
	deck["name"] = _sanitize_name(name, str(deck.get("name", "İsimsiz Deste")))
	deck["cards"] = _sanitize_card_refs(cards)
	deck["updated_at"] = Time.get_datetime_string_from_system(true, true)
	_decks[deck_id] = deck
	_updated_at_unix = int(Time.get_unix_time_from_system())
	_save()
	decks_changed.emit()
	return {"success": true, "deck": get_deck(deck_id)}


func delete_deck(deck_id: String) -> Dictionary:
	load_decks()
	if not _decks.has(deck_id):
		return _failure("Silinecek deste bulunamadı.")
	if bool((_decks[deck_id] as Dictionary).get("is_starter", false)):
		return _failure("Başlangıç desteleri silinemez; istersen kopyasını düzenleyebilirsin.")
	_decks.erase(deck_id)
	if _active_deck_id == deck_id:
		_active_deck_id = STARTER_DECK_ORDER[0]
		active_deck_changed.emit(_active_deck_id)
	_updated_at_unix = int(Time.get_unix_time_from_system())
	_save()
	decks_changed.emit()
	return {"success": true}


func validate_deck_cards(cards_variant: Variant, require_exact_size: bool = true) -> Dictionary:
	if not cards_variant is Array:
		return _failure("Deste kart listesi geçersiz.")
	var cards := cards_variant as Array
	if require_exact_size and cards.size() != GameRules.DECK_SIZE:
		return _failure("Deste tam olarak %d kart içermeli; şu an %d kart var." % [GameRules.DECK_SIZE, cards.size()])
	if cards.size() > GameRules.DECK_SIZE:
		return _failure("Deste %d kart sınırını aşamaz." % GameRules.DECK_SIZE)

	var playable := _playable_lookup()
	var copies := {}
	for card_variant in cards:
		if not card_variant is Dictionary:
			return _failure("Deste içinde geçersiz bir kart kaydı var.")
		var card := card_variant as Dictionary
		var key := _card_key(str(card.get("card_type", "")), str(card.get("card_id", "")))
		if key.is_empty() or not playable.has(key):
			return _failure("Deste oynanabilir olmayan bir kart içeriyor: %s" % key)
		copies[key] = int(copies.get(key, 0)) + 1
		if int(copies[key]) > GameRules.MAX_CARD_COPIES:
			var data := playable[key] as Dictionary
			return _failure("%s kartından en fazla %d kopya kullanılabilir." % [
				str(data.get("name", key)), GameRules.MAX_CARD_COPIES,
			])
	return {"success": true, "card_count": cards.size(), "copies": copies}


func get_deck_stats(cards_variant: Variant) -> Dictionary:
	var stats := {
		"total": 0, "heroes": 0, "settlements": 0,
		"special_powers": 0, "upgrades": 0,
		"energy_total": 0, "average_energy": 0.0,
	}
	if not cards_variant is Array:
		return stats
	for card_variant in cards_variant as Array:
		if not card_variant is Dictionary:
			continue
		var card_ref := card_variant as Dictionary
		var card_type := str(card_ref.get("card_type", ""))
		var card_id := str(card_ref.get("card_id", ""))
		var data := CardDatabase.get_card(card_type, card_id)
		if data.is_empty():
			continue
		stats["total"] = int(stats["total"]) + 1
		if stats.has(card_type):
			stats[card_type] = int(stats[card_type]) + 1
		stats["energy_total"] = int(stats["energy_total"]) + int(data.get("energy_cost", 0))
	if int(stats["total"]) > 0:
		stats["average_energy"] = float(stats["energy_total"]) / float(stats["total"])
	return stats


func reset_to_starters() -> void:
	_decks.clear()
	_active_deck_id = ""
	_ensure_starter_decks()
	_active_deck_id = STARTER_DECK_ORDER[0]
	_loaded = true
	_updated_at_unix = int(Time.get_unix_time_from_system())
	_save()
	decks_changed.emit()
	active_deck_changed.emit(_active_deck_id)


func _load_payload(payload: Dictionary) -> void:
	_updated_at_unix = int(payload.get("updated_at_unix", 0))
	var rows_variant: Variant = payload.get("decks", [])
	if rows_variant is Array:
		for row_variant in rows_variant as Array:
			if not row_variant is Dictionary:
				continue
			var row := row_variant as Dictionary
			var deck_id := str(row.get("id", "")).strip_edges()
			var validation := validate_deck_cards(row.get("cards", []))
			if deck_id.is_empty() or not bool(validation.get("success", false)):
				continue
			_decks[deck_id] = {
				"id": deck_id,
				"name": _sanitize_name(str(row.get("name", "")), "İsimsiz Deste"),
				"archetype": str(row.get("archetype", "custom")),
				"description": str(row.get("description", "")),
				"is_starter": bool(row.get("is_starter", deck_id in STARTER_DECK_ORDER)),
				"cards": _sanitize_card_refs(row.get("cards", [])),
				"updated_at": str(row.get("updated_at", "")),
			}
	_active_deck_id = str(payload.get("active_deck_id", ""))


func _ensure_starter_decks() -> void:
	var starters := _starter_deck_definitions()
	for deck_id in STARTER_DECK_ORDER:
		if not _decks.has(deck_id):
			_decks[deck_id] = (starters[deck_id] as Dictionary).duplicate(true)


func _starter_deck_definitions() -> Dictionary:
	return {
		"muhafiz_hatti": _starter(
			"muhafiz_hatti", "Muhafız Hattı", "Savunma",
			"Dayanıklı ön hat, iyileştirme ve koruma ile rakibin kaynaklarını tüketir.",
			[
				"heroes/sovalye", "heroes/ayaz_muhafizi", "heroes/run_muhafizi",
				"heroes/peri", "heroes/savas_rahibi", "heroes/kan_buyucusu",
				"settlements/tas_sur", "settlements/runik_siginak",
				"settlements/sifa_cadiri", "settlements/ruh_pinari",
				"special_powers/kutsal_isik", "special_powers/koruyucu_muhur",
				"special_powers/onarim_ritueli", "upgrades/celik_kalkan",
				"upgrades/guclendirilmis_temel",
			]
		),
		"firtina_hucumu": _starter(
			"firtina_hucumu", "Fırtına Hücumu", "Tempo",
			"Hızlı Kahramanlar, alan hasarı ve Kuşatma ile açık koridoru erken cezalandırır.",
			[
				"heroes/capulcu", "heroes/golge_suikastcisi", "heroes/simsek_suvarisi",
				"heroes/troll", "heroes/mancinik_ustasi", "heroes/alev_duellocusu",
				"settlements/balista", "settlements/firtina_kulesi", "settlements/savas_davulu",
				"special_powers/yildirim", "special_powers/alev_dalgasi",
				"special_powers/zincir_yildirim", "special_powers/kivilcim",
				"upgrades/kusatma_muhimmati", "upgrades/ejderha_yemini",
			]
		),
		"runik_kontrol": _starter(
			"runik_kontrol", "Rünik Kontrol", "Kontrol",
			"Menzil, Zehir ve el düzenleme ile rakibin planını bozup geç oyunu yönetir.",
			[
				"heroes/okcu", "heroes/firtina_avcisi", "heroes/buyucu",
				"heroes/sihirbaz", "heroes/kan_buyucusu", "heroes/ucbaslikopek",
				"settlements/simyaci_kulesi", "settlements/gozcu_feneri", "settlements/altin_madeni",
				"special_powers/zehir_yagmuru", "special_powers/buz_muhru",
				"special_powers/yer_degistiren_ruzgar", "special_powers/taktik_degisim",
				"special_powers/ikmal_emri", "upgrades/keskin_nisancilik",
			]
		),
	}


func _starter(deck_id: String, deck_name: String, archetype: String, description: String, unique_cards: Array) -> Dictionary:
	var cards: Array = []
	for _copy_index in range(GameRules.MAX_CARD_COPIES):
		for encoded_variant in unique_cards:
			var parts := str(encoded_variant).split("/", false, 1)
			if parts.size() == 2:
				cards.append({"card_type": parts[0], "card_id": parts[1]})
	return {
		"id": deck_id, "name": deck_name, "archetype": archetype,
		"description": description, "is_starter": true, "cards": cards,
		"updated_at": Time.get_datetime_string_from_system(true, true),
	}


func _playable_lookup() -> Dictionary:
	var lookup := {}
	for card_variant in CardDatabase.get_playable_card_refs():
		if card_variant is Dictionary:
			var card_ref := card_variant as Dictionary
			var card_type := str(card_ref.get("card_type", ""))
			var card_id := str(card_ref.get("card_id", ""))
			lookup[_card_key(card_type, card_id)] = CardDatabase.get_card(card_type, card_id)
	return lookup


func _sanitize_card_refs(cards_variant: Variant) -> Array:
	var sanitized: Array = []
	if not cards_variant is Array:
		return sanitized
	for card_variant in cards_variant as Array:
		if card_variant is Dictionary:
			var card := card_variant as Dictionary
			sanitized.append({
				"card_type": str(card.get("card_type", "")),
				"card_id": str(card.get("card_id", "")),
			})
	return sanitized


func _card_key(card_type: String, card_id: String) -> String:
	return "%s/%s" % [card_type, card_id] if not card_type.is_empty() and not card_id.is_empty() else ""


func _sanitize_name(value: String, fallback: String) -> String:
	var normalized := value.strip_edges()
	return (normalized if not normalized.is_empty() else fallback).left(32)


func _generate_deck_id() -> String:
	var base := "deste_%d" % Time.get_ticks_usec()
	var candidate := base
	var suffix := 2
	while _decks.has(candidate):
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	return candidate


func _save() -> Error:
	var deck_rows: Array = []
	for deck_variant in _decks.values():
		if deck_variant is Dictionary:
			deck_rows.append((deck_variant as Dictionary).duplicate(true))
	if _updated_at_unix <= 0:
		_updated_at_unix = int(Time.get_unix_time_from_system())
	var payload := {
		"version": SAVE_VERSION,
		"updated_at_unix": _updated_at_unix,
		"active_deck_id": _active_deck_id,
		"decks": deck_rows,
	}
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if not file:
		push_warning("Deste dosyası açılamadı: %s" % error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	return OK


func export_profile_payload() -> Dictionary:
	load_decks()
	var rows: Array = []
	for deck_variant in _decks.values():
		if deck_variant is Dictionary:
			rows.append((deck_variant as Dictionary).duplicate(true))
	return {
		"updated_at_unix": _updated_at_unix,
		"active_deck_id": _active_deck_id,
		"decks": rows,
	}


func import_profile_payload(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	_decks.clear()
	_active_deck_id = ""
	_load_payload(payload)
	_ensure_starter_decks()
	if not _decks.has(_active_deck_id):
		_active_deck_id = STARTER_DECK_ORDER[0]
	_loaded = true
	_save()
	decks_changed.emit()
	active_deck_changed.emit(_active_deck_id)


func _failure(message: String) -> Dictionary:
	return {"success": false, "error": message}
