extends SceneTree

const DECK_ADVISOR := preload("res://scripts/deck_advisor.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var deck_manager := root.get_node_or_null("DeckManager")
	_expect(deck_manager != null, "Deste Danışmanı ortak DeckManager yolundan erişilebilir olmalı")
	if not deck_manager:
		_finish()
		return
	var starter: Array = deck_manager.get_starter_deck_cards("muhafiz_hatti")
	var starter_analysis: Dictionary = deck_manager.get_deck_advice(starter)
	_expect(int(starter_analysis.get("advisor_schema_version", 0)) == 1, "Deste Danışmanı şema sürümü 1 olmalı")
	_expect(bool(starter_analysis.get("valid", false)), "Başlangıç destesi danışman tarafından geçerli okunmalı")
	_expect(bool(starter_analysis.get("is_complete", false)), "30 kartlık başlangıç destesi tamamlanmış görünmeli")
	_expect(_bucket_total(starter_analysis) == GameRules.DECK_SIZE, "Enerji eğrisi tüm fiziksel kartları saymalı")
	_expect(_dictionary_total(starter_analysis.get("types", {}) as Dictionary) == GameRules.DECK_SIZE, "Kart türü dağılımı tam deste boyutuna eşit olmalı")
	_expect(_dictionary_total(starter_analysis.get("roles", {}) as Dictionary) == GameRules.DECK_SIZE, "Her kart tek bir ana rol almalı")
	_expect((starter_analysis.get("suggestions", []) as Array).size() == 3, "Danışman eğri, rol ve uyum için üç öneri üretmeli")
	_expect(_suggestion_categories(starter_analysis) == ["curve", "composition", "synergy"], "Öneri sırası kararlı olmalı")
	_expect(
		JSON.stringify(starter_analysis) == JSON.stringify(DECK_ADVISOR.analyze(starter)),
		"Aynı deste aynı danışman analizini üretmeli"
	)

	var expensive_refs := _find_refs(func(_type: String, data: Dictionary) -> bool:
		return int(data.get("energy_cost", 0)) >= 4
	)
	if expensive_refs.size() < 15:
		for ref_variant in _find_refs(func(_type: String, data: Dictionary) -> bool:
			return int(data.get("energy_cost", 0)) == 3
		):
			if expensive_refs.size() >= 15:
				break
			expensive_refs.append(ref_variant)
	var expensive := _physical_pairs(expensive_refs, 15)
	var expensive_analysis: Dictionary = DECK_ADVISOR.analyze(expensive)
	_expect(expensive.size() == GameRules.DECK_SIZE, "Yüksek maliyet fixture'ı 30 kart olmalı")
	_expect(str((expensive_analysis.get("curve", {}) as Dictionary).get("state_id", "")) == "top_heavy", "Yüksek maliyet yoğunluğu ağır eğri olarak okunmalı")
	_expect(str(((expensive_analysis.get("suggestions", []) as Array)[0] as Dictionary).get("id", "")) == "curve_high", "Ağır eğri erken oyun değişimi önermeli")

	var non_board := _physical_pairs(_find_refs(func(card_type: String, _data: Dictionary) -> bool:
		return card_type in ["special_powers", "upgrades"]
	), 15)
	var non_board_analysis: Dictionary = DECK_ADVISOR.analyze(non_board)
	_expect(int(non_board_analysis.get("board_presence", -1)) == 0, "Sadece Büyü/Beceri destesi saha varlığı üretmemeli")
	_expect(str(((non_board_analysis.get("suggestions", []) as Array)[1] as Dictionary).get("id", "")) == "composition_board", "Saha varlığı olmayan deste Kahraman/Yapı çifti önermeli")

	var incomplete: Array = starter.slice(0, 10)
	var incomplete_analysis: Dictionary = DECK_ADVISOR.analyze(incomplete)
	_expect(int(incomplete_analysis.get("missing_cards", 0)) == 20, "Eksik deste tamamlanacak kart sayısını göstermeli")
	_expect(str(((incomplete_analysis.get("suggestions", []) as Array)[1] as Dictionary).get("id", "")) == "composition_incomplete", "Eksik deste önce tamamlamayı önermeli")

	var echo_deck: Array = []
	_append_pair(echo_deck, "settlements", "yanki_mabedi")
	_append_pair(echo_deck, "special_powers", "kutsal_isik")
	var hero_refs := _find_refs(func(card_type: String, _data: Dictionary) -> bool: return card_type == "heroes")
	for index in range(13):
		var hero_ref := hero_refs[index] as Dictionary
		_append_pair(echo_deck, str(hero_ref.get("card_type", "")), str(hero_ref.get("card_id", "")))
	var echo_analysis: Dictionary = DECK_ADVISOR.analyze(echo_deck)
	_expect(echo_deck.size() == GameRules.DECK_SIZE, "Yankı fixture'ı 30 kart olmalı")
	_expect(str(((echo_analysis.get("suggestions", []) as Array)[2] as Dictionary).get("id", "")) == "synergy_echo", "Büyü desteği az Yankı paketi ek Büyü çifti önermeli")

	var invalid := starter.duplicate(true)
	invalid[0] = {"card_type": "heroes", "card_id": "olmayan_kart"}
	var invalid_analysis: Dictionary = DECK_ADVISOR.analyze(invalid)
	_expect(not bool(invalid_analysis.get("valid", true)) and int(invalid_analysis.get("invalid_card_count", 0)) == 1, "Bilinmeyen kart sessizce geçerli sayılmamalı")
	var excessive := starter.duplicate(true)
	excessive.append((starter[0] as Dictionary).duplicate(true))
	var excessive_analysis: Dictionary = DECK_ADVISOR.analyze(excessive)
	_expect(not bool(excessive_analysis.get("valid", true)) and int(excessive_analysis.get("excess_cards", 0)) == 1, "30 kartı aşan deste geçerli sayılmamalı")
	_finish()


func _find_refs(predicate: Callable) -> Array:
	var refs: Array = []
	for ref_variant in CardDatabase.get_playable_card_refs():
		if not ref_variant is Dictionary:
			continue
		var ref := ref_variant as Dictionary
		var card_type := str(ref.get("card_type", ""))
		var card_id := str(ref.get("card_id", ""))
		var data := CardDatabase.get_card(card_type, card_id)
		if predicate.call(card_type, data):
			refs.append(ref.duplicate(true))
	refs.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return ("%s/%s" % [left.get("card_type", ""), left.get("card_id", "")]) < ("%s/%s" % [right.get("card_type", ""), right.get("card_id", "")])
	)
	return refs


func _physical_pairs(unique_refs: Array, pair_count: int) -> Array:
	var cards: Array = []
	for index in range(mini(pair_count, unique_refs.size())):
		var ref := unique_refs[index] as Dictionary
		cards.append(ref.duplicate(true))
		cards.append(ref.duplicate(true))
	return cards


func _append_pair(cards: Array, card_type: String, card_id: String) -> void:
	cards.append({"card_type": card_type, "card_id": card_id})
	cards.append({"card_type": card_type, "card_id": card_id})


func _bucket_total(analysis: Dictionary) -> int:
	var total := 0
	for bucket_variant in (analysis.get("curve", {}) as Dictionary).get("buckets", []) as Array:
		if bucket_variant is Dictionary:
			total += int((bucket_variant as Dictionary).get("count", 0))
	return total


func _dictionary_total(values: Dictionary) -> int:
	var total := 0
	for value_variant in values.values():
		total += int(value_variant)
	return total


func _suggestion_categories(analysis: Dictionary) -> Array[String]:
	var categories: Array[String] = []
	for suggestion_variant in analysis.get("suggestions", []) as Array:
		if suggestion_variant is Dictionary:
			categories.append(str((suggestion_variant as Dictionary).get("category", "")))
	return categories


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_DECK_ADVISOR_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_DECK_ADVISOR_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
