class_name GameManager extends Node

## Global singleton reference used by cards while they are being dragged.
static var instance: GameManager

signal turn_changed(active_player_id: int)
signal turn_time_changed(active_player_id: int, remaining_seconds: float, total_seconds: float, is_running: bool)
signal turn_time_expired(active_player_id: int)
signal phase_changed(phase: TurnPhase)
signal energy_changed(player_id: int, current_energy: int, maximum_energy: int, temporary_energy: int)
signal turn_draw_requested(player_id: int, card_count: int)
signal effect_draw_requested(player_id: int, card_count: int, source: BaseCard)
signal effect_draw_completed(player_id: int, requested_count: int, drawn_count: int)
signal mulligan_player_changed(player_id: int)
signal mulligan_completed
signal effect_selection_started
signal effect_selection_player_changed(player_id: int)
signal effect_card_selected(player_id: int, card_id: String, was_automatic: bool)
signal effect_selection_completed
signal effect_trigger_state_changed(player_id: int, state: Dictionary)
signal preparation_token_changed(player_id: int, is_available: bool)
signal hq_health_changed(player_id: int, current_health: int, maximum_health: int)
signal fatigue_damage_applied(player_id: int, damage: int, failed_draw_count: int)
signal card_played(card: BaseCard, target: BaseCard)
signal attack_declared(attacker: BaseCard, target: BaseCard)
signal card_moved(card: BaseCard, from_slot: CardSlot, to_slot: CardSlot)
signal effect_resolved(effect_id: String, source: BaseCard, target: BaseCard, result: Dictionary)
signal card_destroyed(card: BaseCard, source: BaseCard)
signal experience_changed(card: BaseCard, current_experience: int, gained: int, reason: String)
signal card_leveled_up(card: BaseCard, level: int, branch_id: String)
signal round_completed(round_number: int)
signal dominion_score_changed(player_id: int, current_score: int, target_score: int)
signal dominion_round_resolved(
	round_number: int,
	lane_results: Array,
	points_awarded: Dictionary,
	scores: Dictionary
)
signal game_over(winner_id: int)

enum TurnPhase { MULLIGAN, PREPARATION, COMBAT, END, EFFECT_SELECTION }

@export_group("Game Settings")
@export var starting_energy: int = GameRules.STARTING_ENERGY
@export var maximum_energy_limit: int = GameRules.MAX_ENERGY
@export var cards_drawn_per_turn: int = GameRules.CARDS_DRAWN_PER_TURN
@export_range(1.0, 120.0, 1.0, "or_greater") var turn_duration_seconds := GameRules.TURN_DURATION_SECONDS

var active_player_id: int = 1
var first_player_id: int = 1
var turn_count: int = 1
var round_count: int = 1
var current_phase: TurnPhase = TurnPhase.MULLIGAN
var is_game_active: bool = true
var is_match_started: bool = false
var turn_time_remaining_seconds := GameRules.TURN_DURATION_SECONDS

var player_max_energy: Dictionary = {}
var player_current_energy: Dictionary = {}
var player_temporary_energy: Dictionary = {}
var player_personal_turns: Dictionary = {}
var preparation_token_available: Dictionary = {}
var player_failed_draws: Dictionary = {}
var player_turn_flags: Dictionary = {}
var destroyed_hero_history: Dictionary = {}
var effect_offers: Dictionary = {}
var selected_effect_cards: Dictionary = {}
var effect_trigger_state: Dictionary = {}
var effect_trigger_totals: Dictionary = {}
var player_dominion_score: Dictionary = {1: 0, 2: 0}
var last_dominion_lane_results: Array[Dictionary] = []
var win_reason := ""

var player_hq_health: Dictionary = {
	1: GameRules.HEADQUARTERS_HEALTH,
	2: GameRules.HEADQUARTERS_HEALTH,
}

var _mulligan_order: Array[int] = []
var _mulligan_index := 0
var _turn_timer_running := false
var _turn_timer_restore_grace_frames := 0
var _effect_selection_order: Array[int] = []
var _effect_selection_index := 0
var _effect_selection_active := false
var _effect_rng := RandomNumberGenerator.new()

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	turn_duration_seconds = MatchSetup.turn_duration_seconds
	_reset_match_state()
	call_deferred("_emit_initial_state")


func _process(delta: float) -> void:
	# Multiplayer clients render authoritative snapshots. Only the dedicated
	# server advances the real turn clock and resolves timeout actions.
	if MatchSetup.is_multiplayer_client():
		return
	if not _turn_timer_running or not is_game_active:
		return
	if _turn_timer_restore_grace_frames > 0:
		_turn_timer_restore_grace_frames -= 1
		_emit_turn_time()
		return

	turn_time_remaining_seconds = maxf(0.0, turn_time_remaining_seconds - delta)
	_emit_turn_time()
	if turn_time_remaining_seconds > 0.0:
		return

	_turn_timer_running = false
	_turn_timer_restore_grace_frames = 0
	if current_phase == TurnPhase.EFFECT_SELECTION and _effect_selection_active:
		_resolve_effect_selection_timeout()
		return
	_emit_turn_time()
	turn_time_expired.emit(active_player_id)

func _reset_match_state() -> void:
	is_game_active = true
	is_match_started = false
	turn_count = 1
	round_count = 1
	current_phase = TurnPhase.MULLIGAN
	turn_time_remaining_seconds = maxf(0.0, turn_duration_seconds)
	_mulligan_order.clear()
	_mulligan_index = 0
	_effect_selection_order.clear()
	_effect_selection_index = 0
	_effect_selection_active = false
	effect_offers.clear()
	selected_effect_cards.clear()
	effect_trigger_totals.clear()
	_turn_timer_running = false
	_turn_timer_restore_grace_frames = 0
	win_reason = ""
	last_dominion_lane_results.clear()
	_effect_rng = MatchSetup.create_rng(21)

	for player_id in GameRules.PLAYER_IDS:
		player_max_energy[player_id] = starting_energy
		player_current_energy[player_id] = starting_energy
		player_temporary_energy[player_id] = 0
		player_personal_turns[player_id] = 0
		preparation_token_available[player_id] = false
		player_failed_draws[player_id] = 0
		player_turn_flags[player_id] = {}
		destroyed_hero_history[player_id] = []
		effect_trigger_totals[player_id] = 0
		effect_trigger_state[player_id] = _new_effect_trigger_state()
		player_hq_health[player_id] = GameRules.HEADQUARTERS_HEALTH
		player_dominion_score[player_id] = 0

func _emit_initial_state() -> void:
	for player_id in GameRules.PLAYER_IDS:
		_emit_energy(player_id)
		preparation_token_changed.emit(player_id, false)
		hq_health_changed.emit(player_id, int(player_hq_health[player_id]), GameRules.HEADQUARTERS_HEALTH)
		dominion_score_changed.emit(player_id, int(player_dominion_score[player_id]), GameRules.DOMINION_SCORE_TARGET)
	turn_changed.emit(active_player_id)
	_emit_turn_time()
	phase_changed.emit(current_phase)


func begin_effect_selection(chosen_first_player_id: int = 0) -> bool:
	if is_match_started or not is_game_active or _effect_selection_active or not _mulligan_order.is_empty():
		return false
	first_player_id = chosen_first_player_id
	if first_player_id not in GameRules.PLAYER_IDS:
		first_player_id = GameRules.PLAYER_IDS[_effect_rng.randi_range(0, GameRules.PLAYER_IDS.size() - 1)]
	_effect_selection_order = [first_player_id, get_opponent_id(first_player_id)]
	_effect_selection_index = 0
	_effect_selection_active = true
	effect_offers.clear()
	selected_effect_cards.clear()
	for player_id in GameRules.PLAYER_IDS:
		var offer := EffectCardCatalog.create_offer(_effect_rng)
		var forced_card := MatchSetup.get_forced_effect_card(player_id)
		if forced_card in EffectCardCatalog.get_all_ids() and forced_card not in offer and not offer.is_empty():
			offer[0] = forced_card
		effect_offers[player_id] = offer
		effect_trigger_state[player_id] = _new_effect_trigger_state()
	active_player_id = first_player_id
	current_phase = TurnPhase.EFFECT_SELECTION
	effect_selection_started.emit()
	turn_changed.emit(active_player_id)
	phase_changed.emit(current_phase)
	effect_selection_player_changed.emit(active_player_id)
	_restart_turn_timer()
	return true


func submit_effect_selection(requesting_player_id: int, card_id: String, was_automatic: bool = false) -> bool:
	if not _effect_selection_active or current_phase != TurnPhase.EFFECT_SELECTION:
		return false
	if requesting_player_id not in GameRules.PLAYER_IDS or has_effect_selection(requesting_player_id):
		return false
	if not MatchSetup.is_multiplayer_match() and requesting_player_id != active_player_id:
		return false
	var offer := get_effect_offer(requesting_player_id)
	if card_id not in offer:
		return false
	selected_effect_cards[requesting_player_id] = card_id
	effect_card_selected.emit(requesting_player_id, card_id, was_automatic)
	if selected_effect_cards.size() >= GameRules.PLAYER_IDS.size():
		_effect_selection_active = false
		_turn_timer_running = false
		effect_selection_completed.emit()
		return begin_mulligan(first_player_id)

	if not MatchSetup.is_multiplayer_match():
		_effect_selection_index += 1
		active_player_id = _effect_selection_order[_effect_selection_index]
		turn_changed.emit(active_player_id)
		effect_selection_player_changed.emit(active_player_id)
		_restart_turn_timer()
	return true


func get_effect_offer(player_id: int) -> Array[String]:
	var offer_variant: Variant = _player_dictionary_value(effect_offers, player_id, [])
	var offer: Array[String] = []
	if offer_variant is Array:
		for card_id_variant in offer_variant as Array:
			offer.append(str(card_id_variant))
	return offer


func get_selected_effect_card(player_id: int) -> String:
	return str(_player_dictionary_value(selected_effect_cards, player_id, ""))


func has_effect_selection(player_id: int) -> bool:
	return not get_selected_effect_card(player_id).is_empty()


func get_effect_selection_public_state(perspective_player_id: int) -> Dictionary:
	var own_id := perspective_player_id if perspective_player_id in GameRules.PLAYER_IDS else active_player_id
	var opponent_id := get_opponent_id(own_id)
	return {
		"active": _effect_selection_active,
		"own_offer": get_effect_offer(own_id),
		"own_selected_card": get_selected_effect_card(own_id),
		"opponent_selected": has_effect_selection(opponent_id),
	}


func has_effect_triggered(player_id: int, trigger_id: String) -> bool:
	var state_variant: Variant = _player_dictionary_value(effect_trigger_state, player_id, {})
	if not state_variant is Dictionary:
		return false
	return bool((state_variant as Dictionary).get(trigger_id, false))


func mark_effect_triggered(player_id: int, trigger_id: String, details: Dictionary = {}) -> void:
	if player_id not in GameRules.PLAYER_IDS or trigger_id.is_empty():
		return
	var state_variant: Variant = _player_dictionary_value(effect_trigger_state, player_id, {})
	var state: Dictionary = (state_variant as Dictionary).duplicate(true) if state_variant is Dictionary else _new_effect_trigger_state()
	state[trigger_id] = true
	state["last_trigger_id"] = trigger_id
	state["last_trigger_turn"] = turn_count
	state["last_trigger_details"] = details.duplicate(true)
	state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
	effect_trigger_totals[player_id] = int(effect_trigger_totals.get(player_id, 0)) + 1
	state["match_trigger_count"] = int(effect_trigger_totals[player_id])
	effect_trigger_state[player_id] = state
	effect_trigger_state_changed.emit(player_id, state.duplicate(true))


func mark_effect_checked(player_id: int, check_id: String) -> void:
	if player_id not in GameRules.PLAYER_IDS or check_id.is_empty():
		return
	var state_variant: Variant = _player_dictionary_value(effect_trigger_state, player_id, {})
	var state: Dictionary = (state_variant as Dictionary).duplicate(true) if state_variant is Dictionary else _new_effect_trigger_state()
	state[check_id] = true
	effect_trigger_state[player_id] = state
	effect_trigger_state_changed.emit(player_id, state.duplicate(true))


func get_effect_trigger_state(player_id: int) -> Dictionary:
	var state_variant: Variant = _player_dictionary_value(effect_trigger_state, player_id, {})
	return (state_variant as Dictionary).duplicate(true) if state_variant is Dictionary else {}


func _resolve_effect_selection_timeout() -> void:
	if MatchSetup.is_multiplayer_match():
		for player_id in GameRules.PLAYER_IDS:
			if has_effect_selection(player_id):
				continue
			var timed_choice := EffectCardCatalog.choose_timeout(get_effect_offer(player_id), _effect_rng)
			if not timed_choice.is_empty():
				submit_effect_selection(player_id, timed_choice, true)
		return
	var player_id := active_player_id
	var timed_choice := EffectCardCatalog.choose_timeout(get_effect_offer(player_id), _effect_rng)
	if not timed_choice.is_empty():
		submit_effect_selection(player_id, timed_choice, true)

## Starts the one-time mulligan flow. Supplying a player id makes tests and
## future match modes deterministic; 0 chooses the first player randomly.
func begin_mulligan(chosen_first_player_id: int = 0) -> bool:
	if is_match_started or not is_game_active or not _mulligan_order.is_empty():
		return false

	first_player_id = chosen_first_player_id
	if first_player_id not in GameRules.PLAYER_IDS:
		first_player_id = GameRules.PLAYER_IDS.pick_random()

	var second_player_id := get_opponent_id(first_player_id)
	_mulligan_order = [first_player_id, second_player_id]
	_mulligan_index = 0
	active_player_id = first_player_id
	# Dominion scores after the responding player's turn, so the second mover
	# already owns the tactical response advantage. Move the one-shot opening
	# Energy compensation to the first mover in that ruleset only.
	var preparation_token_player_id := first_player_id if MatchSetup.is_dominion() else second_player_id
	preparation_token_available[preparation_token_player_id] = true
	current_phase = TurnPhase.MULLIGAN

	turn_changed.emit(active_player_id)
	phase_changed.emit(current_phase)
	mulligan_player_changed.emit(active_player_id)
	preparation_token_changed.emit(preparation_token_player_id, true)
	_restart_turn_timer()
	return true

## Confirms the current player's mulligan. After both confirmations the first
## turn starts and its mandatory card draw is requested automatically.
func confirm_mulligan(requesting_player_id: int) -> bool:
	if current_phase != TurnPhase.MULLIGAN or _mulligan_order.is_empty():
		return false
	if requesting_player_id != active_player_id:
		return false

	_mulligan_index += 1
	if _mulligan_index < _mulligan_order.size():
		active_player_id = _mulligan_order[_mulligan_index]
		turn_changed.emit(active_player_id)
		mulligan_player_changed.emit(active_player_id)
		_restart_turn_timer()
		return true

	is_match_started = true
	mulligan_completed.emit()
	_start_turn(first_player_id, true)
	return true

## Advances Preparation -> Combat or Combat -> End. End remains active until
## BattlefieldUI has applied the hand-limit discard and calls complete_end_phase.
func advance_phase(requesting_player_id: int) -> bool:
	if not is_game_active or not is_match_started:
		return false
	if requesting_player_id != active_player_id:
		return false

	match current_phase:
		TurnPhase.PREPARATION:
			_set_phase(TurnPhase.COMBAT)
			return true
		TurnPhase.COMBAT:
			_set_phase(TurnPhase.END)
			EffectResolver.resolve_turn_end(self, active_player_id)
			return true
		_:
			return false

## Completes end-of-turn cleanup after the UI has enforced the hand limit.
func complete_end_phase(requesting_player_id: int) -> bool:
	if not is_game_active or current_phase != TurnPhase.END:
		return false
	if requesting_player_id != active_player_id:
		return false

	player_temporary_energy[active_player_id] = 0
	_emit_energy(active_player_id)
	if turn_count % GameRules.PLAYER_IDS.size() == 0:
		round_completed.emit(round_count)
	if not is_game_active:
		return true
	_start_turn(get_opponent_id(active_player_id), false)
	return true

## Compatibility entry point for the existing button and external callers.
## A call advances exactly one legal phase; it never lets a non-active player act.
func end_turn(requesting_player_id: int = 0) -> bool:
	var player_id := requesting_player_id if requesting_player_id != 0 else active_player_id
	return advance_phase(player_id)

func can_play_card(player_id: int) -> bool:
	return (
		is_game_active
		and is_match_started
		and current_phase == TurnPhase.PREPARATION
		and player_id == active_player_id
	)

func has_enough_energy(player_id: int, cost: int) -> bool:
	var normalized_cost: int = max(0, cost)
	return get_available_energy(player_id) >= normalized_cost

## Energy can only be spent by the active player during Preparation. Temporary
## energy is consumed first so the one-turn preparation bonus cannot be banked.
func spend_energy(player_id: int, cost: int) -> bool:
	var normalized_cost: int = max(0, cost)
	if not can_play_card(player_id) or not has_enough_energy(player_id, normalized_cost):
		return false

	var temporary_spend: int = min(int(player_temporary_energy.get(player_id, 0)), normalized_cost)
	player_temporary_energy[player_id] = int(player_temporary_energy[player_id]) - temporary_spend
	player_current_energy[player_id] = int(player_current_energy[player_id]) - (normalized_cost - temporary_spend)
	_emit_energy(player_id)
	return true

func get_available_energy(player_id: int) -> int:
	return int(player_current_energy.get(player_id, 0)) + int(player_temporary_energy.get(player_id, 0))

func add_temporary_energy(player_id: int, amount: int) -> bool:
	var normalized_amount: int = max(0, amount)
	if not is_game_active or normalized_amount <= 0:
		return false
	if player_id != active_player_id or not player_temporary_energy.has(player_id):
		return false
	player_temporary_energy[player_id] = int(player_temporary_energy[player_id]) + normalized_amount
	_emit_energy(player_id)
	return true

func use_preparation_token(player_id: int) -> bool:
	if not can_play_card(player_id):
		return false
	if not bool(preparation_token_available.get(player_id, false)):
		return false

	preparation_token_available[player_id] = false
	player_temporary_energy[player_id] = int(player_temporary_energy.get(player_id, 0)) + GameRules.PREPARATION_TOKEN_ENERGY
	preparation_token_changed.emit(player_id, false)
	_emit_energy(player_id)
	return true

func has_preparation_token(player_id: int) -> bool:
	return bool(preparation_token_available.get(player_id, false))

func get_visible_hand_player_id() -> int:
	return active_player_id

func get_phase_display_name() -> String:
	match current_phase:
		TurnPhase.EFFECT_SELECTION:
			return "ETKİ KARTI SEÇİMİ"
		TurnPhase.MULLIGAN:
			return "BAŞLANGIÇ ELİNİ DÜZENLE"
		TurnPhase.PREPARATION:
			return "HAZIRLIK"
		TurnPhase.COMBAT:
			return "ÇATIŞMA"
		TurnPhase.END:
			return "TUR SONU"
		_:
			return ""


func get_turn_time_ratio() -> float:
	if turn_duration_seconds <= 0.0:
		return 0.0
	return clampf(turn_time_remaining_seconds / turn_duration_seconds, 0.0, 1.0)

func get_opponent_id(player_id: int) -> int:
	return 2 if player_id == 1 else 1

func has_player_turn_flag(player_id: int, flag_id: String) -> bool:
	var flags_variant: Variant = player_turn_flags.get(player_id, {})
	if not flags_variant is Dictionary:
		return false
	return bool((flags_variant as Dictionary).get(flag_id.strip_edges().to_lower(), false))

func set_player_turn_flag(player_id: int, flag_id: String, enabled: bool = true) -> void:
	var flags_variant: Variant = player_turn_flags.get(player_id, {})
	var flags: Dictionary = (flags_variant as Dictionary).duplicate(true) if flags_variant is Dictionary else {}
	var normalized_flag := flag_id.strip_edges().to_lower()
	if normalized_flag.is_empty():
		return
	if enabled:
		flags[normalized_flag] = true
	else:
		flags.erase(normalized_flag)
	player_turn_flags[player_id] = flags

func record_card_destroyed(card: BaseCard, source: BaseCard, banished: bool = false) -> void:
	if not card:
		return
	if card is HeroCard and not banished and not card.card_id.is_empty():
		var history_variant: Variant = destroyed_hero_history.get(card.owner_id, [])
		var history: Array = (history_variant as Array).duplicate(true) if history_variant is Array else []
		history.append({
			"card_type": "heroes",
			"card_id": card.card_id,
			"owner_id": card.owner_id,
			"destroyed_turn": turn_count,
		})
		while history.size() > GameRules.DECK_SIZE:
			history.pop_front()
		destroyed_hero_history[card.owner_id] = history
	card_destroyed.emit(card, source)

func peek_last_destroyed_hero(player_id: int) -> Dictionary:
	var history_variant: Variant = destroyed_hero_history.get(player_id, [])
	if not history_variant is Array or (history_variant as Array).is_empty():
		return {}
	var entry_variant: Variant = (history_variant as Array).back()
	return (entry_variant as Dictionary).duplicate(true) if entry_variant is Dictionary else {}

func consume_last_destroyed_hero(player_id: int) -> Dictionary:
	var history_variant: Variant = destroyed_hero_history.get(player_id, [])
	if not history_variant is Array:
		return {}
	var history: Array = (history_variant as Array).duplicate(true)
	if history.is_empty():
		return {}
	var entry_variant: Variant = history.pop_back()
	destroyed_hero_history[player_id] = history
	return (entry_variant as Dictionary).duplicate(true) if entry_variant is Dictionary else {}

func _start_turn(player_id: int, is_first_turn_of_match: bool) -> void:
	active_player_id = player_id
	player_turn_flags[player_id] = {}
	if not is_first_turn_of_match:
		turn_count += 1
		round_count = int(ceil(float(turn_count) / 2.0))

	player_personal_turns[player_id] = int(player_personal_turns.get(player_id, 0)) + 1
	var is_first_players_opening_turn := (
		player_id == first_player_id
		and int(player_personal_turns[player_id]) == 1
	)
	var is_dominion_opening_turn := (
		MatchSetup.is_dominion()
		and int(player_personal_turns[player_id]) == 1
	)
	if not is_first_players_opening_turn and not is_dominion_opening_turn:
		player_max_energy[player_id] = min(
		maximum_energy_limit,
		int(player_max_energy.get(player_id, starting_energy)) + 1
		)

	player_current_energy[player_id] = int(player_max_energy[player_id])
	player_temporary_energy[player_id] = 0
	_reset_effect_trigger_ledger()
	_set_phase(TurnPhase.PREPARATION)
	_emit_energy(player_id)
	turn_changed.emit(active_player_id)
	_restart_turn_timer()
	turn_draw_requested.emit(active_player_id, cards_drawn_per_turn)
	_reset_cards_for_active_player()
	EffectResolver.resolve_turn_start(self, active_player_id)


func _reset_effect_trigger_ledger() -> void:
	for player_id in GameRules.PLAYER_IDS:
		var state := _new_effect_trigger_state()
		state["match_trigger_count"] = int(effect_trigger_totals.get(player_id, 0))
		effect_trigger_state[player_id] = state
		effect_trigger_state_changed.emit(player_id, get_effect_trigger_state(player_id))


func _new_effect_trigger_state() -> Dictionary:
	return {
		"turn_count": turn_count,
		"building_masters": false,
		"field_medics": false,
		"flanking_maneuver": false,
		"vanguard_doctrine": false,
		"hidden_arsenal": false,
		"protective_oath": false,
		"siege_plan": false,
		"forge": false,
		"supply_line_checked": false,
		"supply_line": false,
		"last_stand": false,
		"primal_harmony": false,
		"last_trigger_id": "",
		"last_trigger_turn": 0,
		"last_trigger_details": {},
		"trigger_count": 0,
		"match_trigger_count": 0,
	}

func _set_phase(next_phase: TurnPhase) -> void:
	current_phase = next_phase
	phase_changed.emit(current_phase)

func _emit_energy(player_id: int) -> void:
	energy_changed.emit(
		player_id,
		int(player_current_energy.get(player_id, 0)),
		int(player_max_energy.get(player_id, starting_energy)),
		int(player_temporary_energy.get(player_id, 0))
	)

func damage_hq(player_id: int, damage: int) -> void:
	if not is_game_active:
		return

	if player_hq_health.has(player_id):
		set_hq_health(player_id, int(player_hq_health[player_id]) - max(0, damage))

## Applies the escalating 1, 2, 3... Headquarters damage caused by an empty
## deck. BattlefieldUI mirrors the resulting health onto the HQ card node.
func resolve_failed_draw(player_id: int) -> Dictionary:
	if not is_game_active or not player_hq_health.has(player_id):
		return {"success": false, "damage": 0, "failed_draw_count": 0}
	var failed_draw_count := int(player_failed_draws.get(player_id, 0)) + 1
	player_failed_draws[player_id] = failed_draw_count
	var damage := GameRules.FATIGUE_START_DAMAGE + failed_draw_count - 1
	fatigue_damage_applied.emit(player_id, damage, failed_draw_count)
	damage_hq(player_id, damage)
	return {
		"success": true,
		"player_id": player_id,
		"damage": damage,
		"failed_draw_count": failed_draw_count,
		"remaining_health": int(player_hq_health[player_id]),
	}

## Resolves an atomic double-KO deterministically. The active player's effect
## owns the resolution, so that player wins if both Headquarters reach zero in
## the same effect batch. Only one game_over event can be emitted.
func set_hq_healths_simultaneously(health_by_player: Dictionary) -> int:
	if not is_game_active:
		return 0
	for player_id in GameRules.PLAYER_IDS:
		if not health_by_player.has(player_id):
			continue
		var health := clampi(int(health_by_player[player_id]), 0, GameRules.HEADQUARTERS_HEALTH)
		player_hq_health[player_id] = health
		hq_health_changed.emit(player_id, health, GameRules.HEADQUARTERS_HEALTH)
	var defeated: Array[int] = []
	for player_id in GameRules.PLAYER_IDS:
		if int(player_hq_health[player_id]) <= 0:
			defeated.append(player_id)
	if defeated.is_empty():
		return 0
	var winner_id := active_player_id if defeated.size() > 1 else get_opponent_id(defeated[0])
	finish_game(winner_id, "headquarters")
	return winner_id

func set_hq_health(player_id: int, health: int) -> void:
	if not player_hq_health.has(player_id):
		return
	var normalized_health: int = clampi(health, 0, GameRules.HEADQUARTERS_HEALTH)
	if int(player_hq_health[player_id]) == normalized_health:
		if normalized_health <= 0 and is_game_active:
			finish_game(get_opponent_id(player_id), "headquarters")
		return
	player_hq_health[player_id] = normalized_health
	hq_health_changed.emit(player_id, normalized_health, GameRules.HEADQUARTERS_HEALTH)
	if normalized_health <= 0 and is_game_active:
		finish_game(get_opponent_id(player_id), "headquarters")

func apply_dominion_round_result(result: Dictionary) -> int:
	if not is_game_active or not MatchSetup.is_dominion():
		return 0
	var points_variant: Variant = result.get("points_awarded", {})
	if not points_variant is Dictionary:
		return 0
	var points := points_variant as Dictionary
	var lanes_variant: Variant = result.get("lane_results", [])
	last_dominion_lane_results.clear()
	if lanes_variant is Array:
		for lane_variant in lanes_variant as Array:
			if lane_variant is Dictionary:
				last_dominion_lane_results.append((lane_variant as Dictionary).duplicate(true))

	for player_id in GameRules.PLAYER_IDS:
		var awarded := maxi(0, int(points.get(player_id, points.get(str(player_id), 0))))
		player_dominion_score[player_id] = int(player_dominion_score.get(player_id, 0)) + awarded
		dominion_score_changed.emit(
			player_id,
			int(player_dominion_score[player_id]),
			GameRules.DOMINION_SCORE_TARGET
		)

	dominion_round_resolved.emit(
		int(result.get("round_number", round_count)),
		last_dominion_lane_results.duplicate(true),
		points.duplicate(true),
		player_dominion_score.duplicate(true)
	)

	var player_one_score := int(player_dominion_score.get(1, 0))
	var player_two_score := int(player_dominion_score.get(2, 0))
	if maxi(player_one_score, player_two_score) < GameRules.DOMINION_SCORE_TARGET:
		return 0
	# Equal scores beyond the target enter transparent sudden death: scoring
	# continues until one player ends a full round ahead of the other.
	if player_one_score == player_two_score:
		return 0
	var winner_id := 1 if player_one_score > player_two_score else 2
	finish_game(winner_id, "dominion")
	return winner_id


func finish_game(winner_id: int, reason: String = "headquarters") -> void:
	if not is_game_active:
		return
	is_game_active = false
	win_reason = reason.strip_edges().to_lower()
	_turn_timer_running = false
	_turn_timer_restore_grace_frames = 0
	_emit_turn_time()
	game_over.emit(winner_id)


func _restart_turn_timer() -> void:
	turn_time_remaining_seconds = maxf(0.0, turn_duration_seconds)
	_turn_timer_running = is_game_active and turn_time_remaining_seconds > 0.0
	_turn_timer_restore_grace_frames = 0
	_emit_turn_time()


func _emit_turn_time() -> void:
	turn_time_changed.emit(
		active_player_id,
		turn_time_remaining_seconds,
		turn_duration_seconds,
		_turn_timer_running
	)


func build_state_snapshot() -> Dictionary:
	return {
		"active_player_id": active_player_id,
		"first_player_id": first_player_id,
		"turn_count": turn_count,
		"round_count": round_count,
		"current_phase": int(current_phase),
		"is_game_active": is_game_active,
		"is_match_started": is_match_started,
		"turn_duration_seconds": turn_duration_seconds,
		"turn_time_remaining_seconds": turn_time_remaining_seconds,
		"turn_timer_running": _turn_timer_running,
		"player_max_energy": player_max_energy.duplicate(true),
		"player_current_energy": player_current_energy.duplicate(true),
		"player_temporary_energy": player_temporary_energy.duplicate(true),
		"player_personal_turns": player_personal_turns.duplicate(true),
		"preparation_token_available": preparation_token_available.duplicate(true),
		"player_failed_draws": player_failed_draws.duplicate(true),
		"player_turn_flags": player_turn_flags.duplicate(true),
		"destroyed_hero_history": destroyed_hero_history.duplicate(true),
		"player_hq_health": player_hq_health.duplicate(true),
		"player_dominion_score": player_dominion_score.duplicate(true),
		"last_dominion_lane_results": last_dominion_lane_results.duplicate(true),
		"win_reason": win_reason,
		"mulligan_order": _mulligan_order.duplicate(),
		"mulligan_index": _mulligan_index,
		"effect_offers": effect_offers.duplicate(true),
		"selected_effect_cards": selected_effect_cards.duplicate(true),
		"effect_trigger_state": effect_trigger_state.duplicate(true),
		"effect_trigger_totals": effect_trigger_totals.duplicate(true),
		"effect_selection_order": _effect_selection_order.duplicate(),
		"effect_selection_index": _effect_selection_index,
		"effect_selection_active": _effect_selection_active,
		"effect_rng_seed": str(_effect_rng.seed),
		"effect_rng_state": str(_effect_rng.state),
	}


func apply_state_snapshot(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {"success": false, "error": "GameManager snapshot'ı boş."}
	active_player_id = int(data.get("active_player_id", 1))
	first_player_id = int(data.get("first_player_id", 1))
	turn_count = maxi(1, int(data.get("turn_count", 1)))
	round_count = maxi(1, int(data.get("round_count", 1)))
	current_phase = clampi(
		int(data.get("current_phase", TurnPhase.MULLIGAN)),
		TurnPhase.MULLIGAN,
		TurnPhase.EFFECT_SELECTION
	) as TurnPhase
	is_game_active = bool(data.get("is_game_active", true))
	is_match_started = bool(data.get("is_match_started", false))
	turn_duration_seconds = maxf(1.0, float(data.get("turn_duration_seconds", MatchSetup.turn_duration_seconds)))
	turn_time_remaining_seconds = clampf(
		float(data.get("turn_time_remaining_seconds", turn_duration_seconds)),
		0.0,
		turn_duration_seconds
	)
	_turn_timer_running = bool(data.get("turn_timer_running", false)) and is_game_active
	_turn_timer_restore_grace_frames = 3 if _turn_timer_running else 0
	player_max_energy = _normalize_player_dictionary(data.get("player_max_energy", {}), starting_energy)
	player_current_energy = _normalize_player_dictionary(data.get("player_current_energy", {}), starting_energy)
	player_temporary_energy = _normalize_player_dictionary(data.get("player_temporary_energy", {}), 0)
	player_personal_turns = _normalize_player_dictionary(data.get("player_personal_turns", {}), 0)
	preparation_token_available = _normalize_player_dictionary(data.get("preparation_token_available", {}), false)
	player_failed_draws = _normalize_player_dictionary(data.get("player_failed_draws", {}), 0)
	player_turn_flags = _normalize_player_dictionary(data.get("player_turn_flags", {}), {})
	destroyed_hero_history = _normalize_player_dictionary(data.get("destroyed_hero_history", {}), [])
	player_hq_health = _normalize_player_dictionary(data.get("player_hq_health", {}), GameRules.HEADQUARTERS_HEALTH)
	player_dominion_score = _normalize_player_dictionary(data.get("player_dominion_score", {}), 0)
	var lane_results_variant: Variant = data.get("last_dominion_lane_results", [])
	last_dominion_lane_results.clear()
	if lane_results_variant is Array:
		for lane_variant in lane_results_variant as Array:
			if lane_variant is Dictionary:
				last_dominion_lane_results.append((lane_variant as Dictionary).duplicate(true))
	win_reason = str(data.get("win_reason", ""))

	_mulligan_order.clear()
	var mulligan_order_variant: Variant = data.get("mulligan_order", [])
	if mulligan_order_variant is Array:
		for player_id_variant in mulligan_order_variant as Array:
			var player_id := int(player_id_variant)
			if player_id in GameRules.PLAYER_IDS:
				_mulligan_order.append(player_id)
	_mulligan_index = clampi(int(data.get("mulligan_index", 0)), 0, maxi(0, _mulligan_order.size()))

	effect_offers = _normalize_player_dictionary(data.get("effect_offers", {}), [])
	selected_effect_cards = _normalize_player_dictionary(data.get("selected_effect_cards", {}), "", false)
	effect_trigger_state = _normalize_player_dictionary(data.get("effect_trigger_state", {}), _new_effect_trigger_state())
	effect_trigger_totals = _normalize_player_dictionary(data.get("effect_trigger_totals", {}), 0)
	_effect_selection_order.clear()
	var effect_order_variant: Variant = data.get("effect_selection_order", [])
	if effect_order_variant is Array:
		for player_id_variant in effect_order_variant as Array:
			var player_id := int(player_id_variant)
			if player_id in GameRules.PLAYER_IDS:
				_effect_selection_order.append(player_id)
	_effect_selection_index = clampi(int(data.get("effect_selection_index", 0)), 0, maxi(0, _effect_selection_order.size()))
	_effect_selection_active = bool(data.get("effect_selection_active", false))
	_effect_rng = RandomNumberGenerator.new()
	_effect_rng.seed = str(data.get("effect_rng_seed", MatchSetup.match_seed)).to_int()
	_effect_rng.state = str(data.get("effect_rng_state", _effect_rng.state)).to_int()
	return {"success": true}


func _normalize_player_dictionary(raw_variant: Variant, fallback: Variant, include_missing: bool = true) -> Dictionary:
	var raw: Dictionary = raw_variant as Dictionary if raw_variant is Dictionary else {}
	var normalized := {}
	for player_id in GameRules.PLAYER_IDS:
		if raw.has(player_id):
			normalized[player_id] = raw[player_id].duplicate(true) if raw[player_id] is Dictionary or raw[player_id] is Array else raw[player_id]
		elif raw.has(str(player_id)):
			var value: Variant = raw[str(player_id)]
			normalized[player_id] = value.duplicate(true) if value is Dictionary or value is Array else value
		elif include_missing:
			normalized[player_id] = fallback.duplicate(true) if fallback is Dictionary or fallback is Array else fallback
	return normalized


func _player_dictionary_value(dictionary: Dictionary, player_id: int, fallback: Variant) -> Variant:
	if dictionary.has(player_id):
		return dictionary[player_id]
	return dictionary.get(str(player_id), fallback)

func _reset_cards_for_active_player() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(BaseCard.GROUP_NAME):
		var card := node as BaseCard
		if not card or not card.current_slot:
			continue
		if card.owner_id == active_player_id:
			ProgressionResolver.begin_owner_turn(self, card)
