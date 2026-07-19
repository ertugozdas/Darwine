class_name CardDatabase extends RefCounted

const CARD_INDEX_PATH := "res://cards.json"
const CARD_TYPE_PATHS := {
	"heroes": "res://data/cards/heroes.json",
	"settlements": "res://data/cards/settlements.json",
	"special_powers": "res://data/cards/special_powers.json",
	"upgrades": "res://data/cards/upgrades.json",
	"effects": "res://data/cards/effects.json",
}

static var _cards_by_type: Dictionary = {}
static var _card_type_paths: Dictionary = {}
static var _is_loaded: bool = false

static func get_card(card_type: String, card_id: String) -> Dictionary:
	load_all()
	var cards_for_type: Dictionary = _cards_by_type.get(card_type, {})
	if not cards_for_type.has(card_id):
		push_error("Card data not found: %s/%s" % [card_type, card_id])
		return {}

	var card_data = cards_for_type[card_id]
	if card_data is Dictionary:
		return card_data.duplicate(true)

	return {}

static func get_cards_for_type(card_type: String) -> Array:
	load_all()
	var cards_for_type: Dictionary = _cards_by_type.get(card_type, {})
	var cards: Array = []
	for card_id in cards_for_type:
		var card_data = cards_for_type[card_id]
		if card_data is Dictionary:
			cards.append(card_data.duplicate(true))

	return cards

static func get_playable_card_refs() -> Array:
	load_all()
	var card_refs: Array = []
	for card_type in _cards_by_type:
		var cards_for_type: Dictionary = _cards_by_type[card_type]
		for card_id in cards_for_type:
			var card_data = cards_for_type[card_id]
			if card_data is Dictionary and _is_playable_deck_card(card_type, card_id, card_data):
				card_refs.append({
					"card_type": card_type,
					"card_id": card_id,
				})

	return card_refs

static func build_default_deck(copies_per_card: int = 3) -> Array:
	var playable_refs = get_playable_card_refs()
	var deck: Array = []
	var copy_count = max(1, copies_per_card)
	for _copy_index in range(copy_count):
		for card_ref in playable_refs:
			deck.append(card_ref.duplicate(true))

	deck.shuffle()
	return deck

## Builds the fixed prototype deck while enforcing both the exact deck size and
## per-card copy limit from the rules document.
static func build_fixed_deck(deck_size: int = GameRules.DECK_SIZE, max_copies: int = GameRules.MAX_CARD_COPIES) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return build_fixed_deck_with_rng(rng, deck_size, max_copies)

## Deterministic counterpart used by AI matches and repeatable balance tests.
## The supplied RNG owns every shuffle decision, so restoring its seed/state
## reproduces the exact same physical deck order.
static func build_fixed_deck_with_rng(
	rng: RandomNumberGenerator,
	deck_size: int = GameRules.DECK_SIZE,
	max_copies: int = GameRules.MAX_CARD_COPIES
) -> Array:
	var playable_refs: Array = get_playable_card_refs()
	var target_size: int = max(0, deck_size)
	var copy_limit: int = max(1, max_copies)
	if playable_refs.size() * copy_limit < target_size:
		push_error(
			"Not enough unique cards to build a %d-card deck with a %d-copy limit." % [target_size, copy_limit]
		)
		return []

	_shuffle_with_rng(playable_refs, rng)
	var deck: Array = []
	for copy_index in range(copy_limit):
		for card_ref in playable_refs:
			if deck.size() >= target_size:
				break
			var deck_ref: Dictionary = card_ref.duplicate(true)
			deck_ref["copy_index"] = copy_index
			deck.append(deck_ref)
		if deck.size() >= target_size:
			break

	_shuffle_with_rng(deck, rng)
	return deck

static func shuffle_with_rng(values: Array, rng: RandomNumberGenerator) -> void:
	_shuffle_with_rng(values, rng)

static func _shuffle_with_rng(values: Array, rng: RandomNumberGenerator) -> void:
	if not rng or values.size() < 2:
		return
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		if swap_index == index:
			continue
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary

static func load_all(force_reload: bool = false) -> void:
	if _is_loaded and not force_reload:
		return

	_cards_by_type.clear()
	_card_type_paths = _load_card_type_paths()
	for card_type in _card_type_paths:
		_cards_by_type[card_type] = _load_cards_file(card_type, _card_type_paths[card_type])

	_is_loaded = true

static func _load_card_type_paths() -> Dictionary:
	var paths = CARD_TYPE_PATHS.duplicate(true)
	var file = FileAccess.open(CARD_INDEX_PATH, FileAccess.READ)
	if file == null:
		return paths

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Card index file must be a dictionary: %s" % CARD_INDEX_PATH)
		return paths

	var configured_paths = parsed.get("card_data_files", {})
	if not configured_paths is Dictionary:
		return paths

	for card_type in configured_paths:
		var path = str(configured_paths[card_type])
		if not path.is_empty():
			paths[str(card_type)] = path

	return paths

static func _load_cards_file(card_type: String, path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Card data file could not be opened: %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Card data file could not be parsed: %s" % path)
		return {}

	var card_rows: Array = []
	if parsed is Array:
		card_rows = parsed
	elif parsed is Dictionary:
		if parsed.has("cards") and parsed["cards"] is Array:
			card_rows = parsed["cards"]
		elif parsed.has(card_type) and parsed[card_type] is Array:
			card_rows = parsed[card_type]
		else:
			push_error("Card data file has no card array: %s" % path)
			return {}
	else:
		push_error("Card data file root must be an array or dictionary: %s" % path)
		return {}

	var cards: Dictionary = {}
	for row in card_rows:
		if not row is Dictionary:
			push_warning("Skipping invalid card row in %s" % path)
			continue

		var card_id = str(row.get("id", ""))
		if card_id.is_empty():
			push_warning("Skipping card row without id in %s" % path)
			continue

		var card_data = row.duplicate(true)
		card_data["card_type"] = card_type
		cards[card_id] = card_data

	return cards

static func _is_playable_deck_card(_card_type: String, card_id: String, card_data: Dictionary) -> bool:
	if bool(card_data.get("is_hq", false)):
		return false

	if not bool(card_data.get("deck_enabled", true)):
		return false

	var role = str(card_data.get("role", "")).to_lower()
	if role == "hq" or role == "headquarters":
		return false

	var normalized_id = card_id.to_lower()
	if normalized_id.ends_with("_merkez") or normalized_id.contains("merkez"):
		return false

	return true
