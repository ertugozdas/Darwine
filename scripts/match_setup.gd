class_name MatchSetup extends RefCounted

## Scene changes keep this lightweight configuration alive without requiring an
## autoload. The menu configures it immediately before opening the battlefield.

enum AIDifficulty { EASY, MEDIUM, HARD }
enum MatchMode { LOCAL, AI, AUTOMATED, MULTIPLAYER_SERVER, MULTIPLAYER_CLIENT, MULTIPLAYER_HOST }
enum CardPoolMode { DECK, ALL_CARDS }
enum Ruleset { SIEGE, DOMINION }

const DEFAULT_MATCH_NAME := "Yeni Kuşatma"
const DEFAULT_DOMINION_MATCH_NAME := "Yeni Hakimiyet"
const MAX_MATCH_NAME_LENGTH := 32
const MIN_TURN_DURATION_SECONDS := 15.0
const MAX_TURN_DURATION_SECONDS := 300.0
const DEFAULT_SAVE_SLOT_ID := "autosave"

static var match_mode: MatchMode = MatchMode.LOCAL
static var match_seed: int = 0
static var match_id := ""
static var ai_difficulties: Dictionary = {}
static var human_player_id: int = 1
static var fast_mode := false
static var telemetry_to_disk := true
static var forced_first_player_id := 0
static var forced_effect_cards: Dictionary = {}
static var card_pool_mode: CardPoolMode = CardPoolMode.DECK
static var ruleset: Ruleset = Ruleset.SIEGE
static var match_name := DEFAULT_MATCH_NAME
static var turn_duration_seconds := GameRules.TURN_DURATION_SECONDS
static var auto_attack_allowed := true
static var player_decks: Dictionary = {}
static var player_deck_names: Dictionary = {}
static var resume_snapshot: Dictionary = {}
static var save_slot_id := ""
static var save_slot_name := ""
static var scenario_context: Dictionary = {}


static func configure_local(seed: int = 0) -> void:
	match_mode = MatchMode.LOCAL
	match_seed = _resolved_seed(seed)
	match_id = _new_match_id(match_seed)
	ai_difficulties.clear()
	human_player_id = 1
	fast_mode = false
	telemetry_to_disk = true
	forced_first_player_id = 0
	forced_effect_cards.clear()
	card_pool_mode = CardPoolMode.DECK
	_reset_match_options()
	_reset_save_slot_context(true)
	_clear_player_decks()
	resume_snapshot.clear()


static func configure_ai(difficulty: int, seed: int = 0) -> void:
	match_mode = MatchMode.AI
	match_seed = _resolved_seed(seed)
	match_id = _new_match_id(match_seed)
	ai_difficulties = {2: clampi(difficulty, AIDifficulty.EASY, AIDifficulty.HARD)}
	human_player_id = 1
	fast_mode = false
	telemetry_to_disk = true
	forced_first_player_id = 0
	forced_effect_cards.clear()
	card_pool_mode = CardPoolMode.DECK
	_reset_match_options()
	_reset_save_slot_context(true)
	_clear_player_decks()
	resume_snapshot.clear()


## Used by the Phase 7 balance suite. Both sides use the production planner and
## rule resolvers; only presentation delays and disk writes are disabled.
static func configure_automated(
	seed: int,
	player_one_difficulty: int = AIDifficulty.MEDIUM,
	player_two_difficulty: int = AIDifficulty.MEDIUM,
	first_player_id: int = 0
) -> void:
	match_mode = MatchMode.AUTOMATED
	match_seed = _resolved_seed(seed)
	match_id = _new_match_id(match_seed)
	ai_difficulties = {
		1: clampi(player_one_difficulty, AIDifficulty.EASY, AIDifficulty.HARD),
		2: clampi(player_two_difficulty, AIDifficulty.EASY, AIDifficulty.HARD),
	}
	human_player_id = 0
	fast_mode = true
	telemetry_to_disk = false
	forced_first_player_id = first_player_id if first_player_id in GameRules.PLAYER_IDS else 0
	forced_effect_cards.clear()
	card_pool_mode = CardPoolMode.DECK
	_reset_match_options()
	_reset_save_slot_context(false)
	_clear_player_decks()
	resume_snapshot.clear()


static func configure_multiplayer_server(
	seed: int,
	authoritative_match_id: String = "",
	match_ruleset: int = Ruleset.SIEGE
) -> void:
	match_mode = MatchMode.MULTIPLAYER_SERVER
	match_seed = _resolved_seed(seed)
	match_id = authoritative_match_id if not authoritative_match_id.is_empty() else _new_match_id(match_seed)
	ai_difficulties.clear()
	human_player_id = 0
	fast_mode = true
	telemetry_to_disk = false
	forced_first_player_id = 0
	forced_effect_cards.clear()
	card_pool_mode = CardPoolMode.DECK
	_reset_match_options()
	_reset_save_slot_context(false)
	set_ruleset(match_ruleset)
	_clear_player_decks()
	resume_snapshot.clear()


static func configure_multiplayer_client(
	seed: int,
	player_id: int,
	authoritative_match_id: String = "",
	match_ruleset: int = Ruleset.SIEGE
) -> void:
	match_mode = MatchMode.MULTIPLAYER_CLIENT
	match_seed = _resolved_seed(seed)
	match_id = authoritative_match_id if not authoritative_match_id.is_empty() else _new_match_id(match_seed)
	ai_difficulties.clear()
	human_player_id = player_id if player_id in GameRules.PLAYER_IDS else 0
	fast_mode = false
	telemetry_to_disk = false
	forced_first_player_id = 0
	forced_effect_cards.clear()
	card_pool_mode = CardPoolMode.DECK
	_reset_match_options()
	_reset_save_slot_context(false)
	set_ruleset(match_ruleset)
	_clear_player_decks()
	resume_snapshot.clear()


static func configure_multiplayer_host(
	seed: int,
	player_id: int = 1,
	authoritative_match_id: String = "",
	match_ruleset: int = Ruleset.SIEGE
) -> void:
	match_mode = MatchMode.MULTIPLAYER_HOST
	match_seed = _resolved_seed(seed)
	match_id = authoritative_match_id if not authoritative_match_id.is_empty() else _new_match_id(match_seed)
	ai_difficulties.clear()
	human_player_id = player_id if player_id in GameRules.PLAYER_IDS else 1
	fast_mode = false
	telemetry_to_disk = true
	forced_first_player_id = 0
	forced_effect_cards.clear()
	card_pool_mode = CardPoolMode.DECK
	_reset_match_options()
	_reset_save_slot_context(false)
	set_ruleset(match_ruleset)
	_clear_player_decks()
	resume_snapshot.clear()


static func set_resume_snapshot(snapshot: Dictionary) -> void:
	resume_snapshot = snapshot.duplicate(true)
	match_id = str(snapshot.get("match_id", match_id))
	set_ruleset(int(snapshot.get("ruleset", ruleset)))
	var scenario_variant: Variant = snapshot.get("scenario_context", {})
	if scenario_variant is Dictionary:
		set_scenario_context(scenario_variant as Dictionary)
	else:
		clear_scenario_context()


static func configure_from_snapshot(snapshot: Dictionary, slot_id := "", slot_name := "") -> bool:
	if snapshot.is_empty():
		return false
	var seed := int(snapshot.get("seed", 0))
	var mode := int(snapshot.get("match_mode", MatchMode.LOCAL))
	if mode == MatchMode.AI:
		var ai_variant: Variant = snapshot.get("ai_difficulties", {})
		var ai_data: Dictionary = ai_variant as Dictionary if ai_variant is Dictionary else {}
		var difficulty := int(ai_data.get(2, ai_data.get("2", AIDifficulty.MEDIUM)))
		configure_ai(difficulty, seed)
	else:
		configure_local(seed)
	set_ruleset(int(snapshot.get("ruleset", Ruleset.SIEGE)))
	set_match_name(str(snapshot.get("match_name", get_default_match_name(ruleset))))
	set_turn_duration_seconds(float(snapshot.get("turn_duration_seconds", GameRules.TURN_DURATION_SECONDS)))
	set_auto_attack_allowed(bool(snapshot.get("auto_attack_allowed", true)))
	set_card_pool_mode(int(snapshot.get("card_pool_mode", CardPoolMode.DECK)))
	var configured_decks_variant: Variant = snapshot.get("configured_player_decks", {})
	var configured_names_variant: Variant = snapshot.get("configured_player_deck_names", {})
	if configured_decks_variant is Dictionary:
		for player_id in GameRules.PLAYER_IDS:
			var deck_cards: Variant = (configured_decks_variant as Dictionary).get(
				player_id,
				(configured_decks_variant as Dictionary).get(str(player_id), [])
			)
			var deck_name := ""
			if configured_names_variant is Dictionary:
				deck_name = str((configured_names_variant as Dictionary).get(
					player_id,
					(configured_names_variant as Dictionary).get(str(player_id), "")
				))
			if deck_cards is Array:
				set_player_deck(player_id, deck_cards as Array, deck_name)
	set_save_slot(slot_id, slot_name)
	set_resume_snapshot(snapshot)
	return true


static func set_save_slot(slot_id: String, slot_name: String = "") -> void:
	save_slot_id = slot_id.strip_edges().to_lower()
	save_slot_name = slot_name.replace("\n", " ").replace("\r", " ").strip_edges().left(40)
	if save_slot_id == DEFAULT_SAVE_SLOT_ID and save_slot_name.is_empty():
		save_slot_name = match_name


static func clear_save_slot() -> void:
	save_slot_id = ""
	save_slot_name = ""


static func take_resume_snapshot() -> Dictionary:
	var snapshot := resume_snapshot.duplicate(true)
	resume_snapshot.clear()
	return snapshot


static func has_resume_snapshot() -> bool:
	return not resume_snapshot.is_empty()


static func is_ai_match() -> bool:
	return not ai_difficulties.is_empty()


static func is_multiplayer_match() -> bool:
	return match_mode in [MatchMode.MULTIPLAYER_SERVER, MatchMode.MULTIPLAYER_CLIENT, MatchMode.MULTIPLAYER_HOST]


static func is_multiplayer_server() -> bool:
	return match_mode in [MatchMode.MULTIPLAYER_SERVER, MatchMode.MULTIPLAYER_HOST]


static func is_multiplayer_client() -> bool:
	return match_mode == MatchMode.MULTIPLAYER_CLIENT


static func is_multiplayer_host() -> bool:
	return match_mode == MatchMode.MULTIPLAYER_HOST


## A human-controlled online seat. Dedicated servers are intentionally excluded:
## they own the simulation but never submit local player input.
static func is_multiplayer_player() -> bool:
	return match_mode in [MatchMode.MULTIPLAYER_CLIENT, MatchMode.MULTIPLAYER_HOST]


static func set_card_pool_mode(mode: int) -> void:
	card_pool_mode = (
		CardPoolMode.ALL_CARDS
		if mode == CardPoolMode.ALL_CARDS
		else CardPoolMode.DECK
	)


static func uses_all_cards() -> bool:
	return card_pool_mode == CardPoolMode.ALL_CARDS


static func set_ruleset(value: int) -> void:
	var had_default_name := match_name in [DEFAULT_MATCH_NAME, DEFAULT_DOMINION_MATCH_NAME]
	ruleset = Ruleset.DOMINION if value == Ruleset.DOMINION else Ruleset.SIEGE
	if had_default_name:
		match_name = get_default_match_name(ruleset)
		if save_slot_id == DEFAULT_SAVE_SLOT_ID:
			save_slot_name = match_name


static func is_dominion() -> bool:
	return ruleset == Ruleset.DOMINION


static func get_ruleset_name() -> String:
	return "Hakimiyet" if is_dominion() else "Kuşatma"


static func get_default_match_name(value: int) -> String:
	return DEFAULT_DOMINION_MATCH_NAME if value == Ruleset.DOMINION else DEFAULT_MATCH_NAME


static func set_match_name(value: String) -> void:
	var sanitized := value.replace("\n", " ").replace("\r", " ").strip_edges()
	match_name = sanitized.left(MAX_MATCH_NAME_LENGTH) if not sanitized.is_empty() else get_default_match_name(ruleset)
	if save_slot_id == DEFAULT_SAVE_SLOT_ID:
		save_slot_name = match_name


static func set_turn_duration_seconds(value: float) -> void:
	turn_duration_seconds = clampf(value, MIN_TURN_DURATION_SECONDS, MAX_TURN_DURATION_SECONDS)


static func set_auto_attack_allowed(allowed: bool) -> void:
	auto_attack_allowed = allowed


static func set_scenario_context(context: Dictionary) -> void:
	if context.is_empty() or str(context.get("scenario_id", "")).strip_edges().is_empty():
		clear_scenario_context()
		return
	scenario_context = {
		"campaign_id": str(context.get("campaign_id", "")),
		"campaign_version": str(context.get("campaign_version", "")),
		"scenario_id": str(context.get("scenario_id", "")),
		"scenario_order": maxi(0, int(context.get("scenario_order", 0))),
		"content_version": maxi(1, int(context.get("content_version", 1))),
		"lesson": str(context.get("lesson", "")),
		"objectives": (
			(context.get("objectives", []) as Array).duplicate(true)
			if context.get("objectives", []) is Array
			else []
		),
	}


static func clear_scenario_context() -> void:
	scenario_context.clear()


static func is_scenario_match() -> bool:
	return not get_scenario_id().is_empty()


static func get_scenario_id() -> String:
	return str(scenario_context.get("scenario_id", ""))


static func get_scenario_context() -> Dictionary:
	return scenario_context.duplicate(true)


static func _reset_match_options() -> void:
	match_name = DEFAULT_MATCH_NAME
	turn_duration_seconds = GameRules.TURN_DURATION_SECONDS
	auto_attack_allowed = true
	ruleset = Ruleset.SIEGE
	clear_scenario_context()


static func _reset_save_slot_context(enable_autosave: bool) -> void:
	if enable_autosave:
		save_slot_id = DEFAULT_SAVE_SLOT_ID
		save_slot_name = match_name
	else:
		clear_save_slot()


static func set_player_deck(player_id: int, cards: Array, deck_name: String = "") -> void:
	if player_id not in GameRules.PLAYER_IDS:
		return
	player_decks[player_id] = cards.duplicate(true)
	player_deck_names[player_id] = deck_name


static func get_player_deck(player_id: int) -> Array:
	var cards_variant: Variant = player_decks.get(player_id, [])
	return (cards_variant as Array).duplicate(true) if cards_variant is Array else []


static func get_player_deck_name(player_id: int) -> String:
	return str(player_deck_names.get(player_id, ""))


static func set_forced_effect_card(player_id: int, card_id: String) -> void:
	if player_id not in GameRules.PLAYER_IDS:
		return
	if card_id.is_empty():
		forced_effect_cards.erase(player_id)
	else:
		forced_effect_cards[player_id] = card_id


static func get_forced_effect_card(player_id: int) -> String:
	return str(forced_effect_cards.get(player_id, forced_effect_cards.get(str(player_id), "")))


static func is_ai_player(player_id: int) -> bool:
	return ai_difficulties.has(player_id)


static func get_ai_difficulty(player_id: int) -> int:
	return int(ai_difficulties.get(player_id, AIDifficulty.MEDIUM))


static func get_difficulty_name(difficulty: int) -> String:
	match difficulty:
		AIDifficulty.EASY:
			return "Kolay"
		AIDifficulty.HARD:
			return "Zor"
		_:
			return "Orta"


static func get_ai_label(player_id: int) -> String:
	if not is_ai_player(player_id):
		return "Oyuncu %d" % player_id
	return "Yapay Zekâ • %s" % get_difficulty_name(get_ai_difficulty(player_id))


static func get_first_player_id() -> int:
	if forced_first_player_id in GameRules.PLAYER_IDS:
		return forced_first_player_id
	var rng := RandomNumberGenerator.new()
	rng.seed = _resolved_seed(match_seed) ^ 0x51A7
	return GameRules.PLAYER_IDS[rng.randi_range(0, GameRules.PLAYER_IDS.size() - 1)]


static func create_rng(stream: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var base_seed := _resolved_seed(match_seed)
	rng.seed = base_seed + (stream * 104729)
	return rng


static func _resolved_seed(seed: int) -> int:
	if seed != 0:
		return abs(seed)
	var generated := int(Time.get_unix_time_from_system() * 1000.0) ^ int(Time.get_ticks_usec())
	return max(1, abs(generated))


static func _new_match_id(seed: int) -> String:
	return "%d-%d" % [seed, Time.get_ticks_usec()]


static func _clear_player_decks() -> void:
	player_decks.clear()
	player_deck_names.clear()
