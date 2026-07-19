class_name EffectCardCatalog extends RefCounted

const CARD_TYPE := "effects"
const OFFER_SIZE := 3


static func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for card_variant in CardDatabase.get_cards_for_type(CARD_TYPE):
		if card_variant is Dictionary:
			ids.append(str((card_variant as Dictionary).get("id", "")))
	ids = ids.filter(func(card_id: String): return not card_id.is_empty())
	ids.sort()
	return ids


static func create_offer(rng: RandomNumberGenerator) -> Array[String]:
	var ids := get_all_ids()
	CardDatabase.shuffle_with_rng(ids, rng)
	var offer: Array[String] = []
	for index in range(mini(OFFER_SIZE, ids.size())):
		offer.append(ids[index])
	return offer


static func choose_timeout(offer: Array[String], rng: RandomNumberGenerator) -> String:
	if offer.is_empty():
		return ""
	return offer[rng.randi_range(0, offer.size() - 1)]


static func choose_for_ai(offer: Array[String], deck_refs: Array) -> String:
	if offer.is_empty():
		return ""
	var counts := {
		"heroes": 0,
		"settlements": 0,
		"special_powers": 0,
		"upgrades": 0,
		"siege": 0,
		"energy_total": 0,
	}
	for ref_variant in deck_refs:
		if not ref_variant is Dictionary:
			continue
		var ref := ref_variant as Dictionary
		var card_type := str(ref.get("card_type", ""))
		if counts.has(card_type):
			counts[card_type] = int(counts[card_type]) + 1
		var data := CardDatabase.get_card(card_type, str(ref.get("card_id", "")))
		counts["energy_total"] = int(counts["energy_total"]) + int(data.get("energy_cost", 0))
		if "siege" in (data.get("tags", []) as Array):
			counts["siege"] = int(counts["siege"]) + 1

	var best_id := offer[0]
	var best_score := -INF
	for card_id in offer:
		var score := _score_for_deck(card_id, counts, deck_refs.size())
		if score > best_score or (is_equal_approx(score, best_score) and card_id < best_id):
			best_score = score
			best_id = card_id
	return best_id


static func _score_for_deck(card_id: String, counts: Dictionary, deck_size: int) -> float:
	var heroes := float(counts.get("heroes", 0))
	var settlements := float(counts.get("settlements", 0))
	var spells := float(counts.get("special_powers", 0))
	var upgrades := float(counts.get("upgrades", 0))
	var average_energy := float(counts.get("energy_total", 0)) / float(maxi(1, deck_size))
	match card_id:
		"yapi_ustalari": return 8.0 + settlements * 0.75
		"saha_hekimleri": return 10.0 + (heroes + settlements) * 0.22
		"kanat_manevrasi": return 8.5 + heroes * 0.55
		"oncu_doktrini": return 8.0 + heroes * 0.70 + average_energy
		"gizli_cephanelik": return 8.0 + spells * 0.80
		"koruyucu_yemin": return 9.0 + heroes * 0.25 + settlements * 0.35
		"kusatma_plani": return 8.0 + float(counts.get("siege", 0)) * 1.4 + heroes * 0.18
		"dovme_ocagi": return 8.0 + upgrades * 0.95
		"ikmal_hatti": return 9.0 + maxf(0.0, 3.5 - average_energy) * 1.8
		"son_direnis": return 11.0 + settlements * 0.18
		"muhafiz_nobeti": return 9.0 + heroes * 0.58
		"usta_zanaatkarlar": return 8.0 + settlements * 0.78
		"ilkel_uyum": return 10.0 + heroes * 0.72
		_: return 0.0
