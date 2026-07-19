class_name AIController extends Node

signal action_executed(player_id: int, action: Dictionary)
signal invalid_action(player_id: int, action: Dictionary, error: String)
signal thinking_changed(player_id: int, is_thinking: bool)

const MAX_SEQUENCE_ACTIONS := 1800

var invalid_action_count := 0
var executed_action_count := 0

var _battlefield: BattlefieldUI
var _game_manager: GameManager
var _planner := AIActionPlanner.new()
var _rng: RandomNumberGenerator
var _scheduled := false
var _running := false
var _phase_marker := ""
var _actions_taken_in_phase := 0


func setup(battlefield: BattlefieldUI, game_manager: GameManager) -> void:
	_battlefield = battlefield
	_game_manager = game_manager
	_rng = MatchSetup.create_rng(31)
	_planner.setup(_battlefield, _game_manager, _rng)
	_game_manager.turn_changed.connect(_on_turn_changed)
	_game_manager.phase_changed.connect(_on_phase_changed)
	_game_manager.mulligan_player_changed.connect(_on_mulligan_player_changed)
	_game_manager.effect_selection_player_changed.connect(_on_effect_selection_player_changed)
	_game_manager.game_over.connect(_on_game_over)
	_schedule_if_needed()


func is_thinking() -> bool:
	return _running and _game_manager != null and MatchSetup.is_ai_player(_game_manager.active_player_id)


func get_rng_snapshot() -> Dictionary:
	if not _rng:
		return {}
	return {"seed": str(_rng.seed), "state": str(_rng.state)}


func apply_rng_snapshot(snapshot: Dictionary) -> void:
	if not _rng or snapshot.is_empty():
		return
	_rng.seed = str(snapshot.get("seed", _rng.seed)).to_int()
	_rng.state = str(snapshot.get("state", _rng.state)).to_int()


func _on_turn_changed(_player_id: int) -> void:
	_schedule_if_needed()


func _on_phase_changed(_phase: GameManager.TurnPhase) -> void:
	_schedule_if_needed()


func _on_mulligan_player_changed(_player_id: int) -> void:
	_schedule_if_needed()


func _on_effect_selection_player_changed(_player_id: int) -> void:
	_schedule_if_needed()


func _on_game_over(_winner_id: int) -> void:
	_scheduled = false
	if _running:
		thinking_changed.emit(_game_manager.active_player_id, false)


func _schedule_if_needed() -> void:
	if _scheduled or _running or not _game_manager or not _game_manager.is_game_active:
		return
	if not MatchSetup.is_ai_player(_game_manager.active_player_id):
		return
	_scheduled = true
	call_deferred("_run_ai_sequence")


func _run_ai_sequence() -> void:
	_scheduled = false
	if _running or not _game_manager or not _game_manager.is_game_active:
		return
	_running = true
	var sequence_actions := 0

	while (
		_game_manager
		and _game_manager.is_game_active
		and MatchSetup.is_ai_player(_game_manager.active_player_id)
	):
		sequence_actions += 1
		if sequence_actions > MAX_SEQUENCE_ACTIONS:
			invalid_action_count += 1
			invalid_action.emit(
				_game_manager.active_player_id,
				{"type": "safety_stop"},
				"Yapay zekâ güvenlik eylem sınırına ulaştı."
			)
			break

		await _wait_until_resolution_ready()
		if not _game_manager.is_game_active:
			break
		var player_id := _game_manager.active_player_id
		if not MatchSetup.is_ai_player(player_id):
			break
		_refresh_phase_counter(player_id)
		thinking_changed.emit(player_id, true)

		var difficulty := MatchSetup.get_ai_difficulty(player_id)
		match _game_manager.current_phase:
			GameManager.TurnPhase.EFFECT_SELECTION:
				await _wait_before_action(difficulty)
				var offer := _game_manager.get_effect_offer(player_id)
				var forced_choice := MatchSetup.get_forced_effect_card(player_id)
				var choice := (
					forced_choice
					if forced_choice in offer
					else EffectCardCatalog.choose_for_ai(offer, MatchSetup.get_player_deck(player_id))
				)
				var selected_ok := _battlefield.resolve_effect_card_choice_for_player(player_id, choice, false)
				var selection_action := {
					"type": "select_effect_card",
					"player_id": player_id,
					"card_id": choice,
				}
				if not selected_ok:
					_record_invalid(player_id, selection_action, "Etki Kartı seçilemedi.")
					break
				_record_success(player_id, selection_action)
			GameManager.TurnPhase.MULLIGAN:
				await _wait_before_action(difficulty)
				var selected := _planner.choose_mulligan_cards(player_id, difficulty)
				var mulligan_ok: bool = await _battlefield.resolve_mulligan_for_player(player_id, selected)
				var mulligan_action := {
					"type": "confirm_mulligan",
					"player_id": player_id,
					"returned_count": selected.size(),
				}
				if not mulligan_ok:
					_record_invalid(player_id, mulligan_action, "Başlangıç eli onaylanamadı.")
					break
				_record_success(player_id, mulligan_action)
			GameManager.TurnPhase.END:
				var discard_count := _battlefield.get_required_discard_count(player_id)
				var discards := _planner.choose_discards(player_id, discard_count)
				var end_ok := _battlefield.resolve_ai_end_phase(player_id, discards)
				var end_action := {
					"type": "complete_end",
					"player_id": player_id,
					"discarded_count": discards.size(),
				}
				if not end_ok:
					_record_invalid(player_id, end_action, "Tur sonu çözülemedi.")
					break
				_record_success(player_id, end_action)
			_:
				var legal_actions := _planner.generate_legal_actions(player_id)
				if legal_actions.is_empty():
					_record_invalid(player_id, {"type": "no_legal_action"}, "Yasal hamle üretilemedi.")
					break
				var action := _planner.choose_action(legal_actions, difficulty, _actions_taken_in_phase)
				# Some actions consume and free their source/target cards while the
				# awaited resolver is running (notably hand redraw/draw tactics).
				# Freeze telemetry while every referenced object is still alive.
				var action_summary := _planner.describe_action(action)
				await _wait_before_action(difficulty)
				var result: Dictionary = await _execute_action(action)
				if not bool(result.get("success", false)):
					_record_invalid(player_id, action_summary, str(result.get("error", "Hamle çözülemedi.")))
					break
				_actions_taken_in_phase += 1
				var summary := action_summary.duplicate(true)
				if result.has("damage"):
					summary["damage"] = int(result.get("damage", 0))
				if result.has("destroyed"):
					summary["destroyed"] = bool(result.get("destroyed", false))
				_record_success(player_id, summary)
				_battlefield.refresh_after_ai_action()

	thinking_changed.emit(_game_manager.active_player_id if _game_manager else 0, false)
	_running = false
	_schedule_if_needed()


func _execute_action(action: Dictionary) -> Dictionary:
	var player_id := int(action.get("player_id", 0))
	if not _game_manager or player_id != _game_manager.active_player_id:
		return {"success": false, "error": "Aktif oyuncu değişti."}
	match str(action.get("type", "")):
		"use_preparation_token":
			return {
				"success": _game_manager.use_preparation_token(player_id),
				"error": "Hazırlık Jetonu kullanılamadı.",
			}
		"play_card":
			return _battlefield.play_hand_card_to_slot(
				action.get("card") as BaseCard,
				action.get("target_slot") as CardSlot
			)
		"play_effect":
			return EffectResolver.resolve_targeted_card(
				_game_manager,
				action.get("card") as BaseCard,
				action.get("target_slot") as CardSlot
			)
		"play_hand_tactic":
			return await _battlefield.resolve_hand_tactic(
				action.get("card") as SpecialPowerCard,
				action.get("hand_target") as BaseCard
			)
		"move":
			return MovementResolver.resolve_move(
				_game_manager,
				action.get("card") as BaseCard,
				action.get("target_slot") as CardSlot
			)
		"upgrade_level":
			return ProgressionResolver.resolve_upgrade(
				_game_manager,
				action.get("card") as BaseCard,
				str(action.get("branch_id", ""))
			)
		"attack":
			return await _battlefield.resolve_attack_with_feedback(
				action.get("card") as BaseCard,
				action.get("target_slot") as CardSlot
			)
		"advance_phase":
			return {
				"success": _game_manager.advance_phase(player_id),
				"error": "Aşama ilerletilemedi.",
			}
		_:
			return {"success": false, "error": "Bilinmeyen AI hamlesi."}


func _refresh_phase_counter(player_id: int) -> void:
	var marker := "%d:%d:%d" % [player_id, int(_game_manager.current_phase), _game_manager.turn_count]
	if marker == _phase_marker:
		return
	_phase_marker = marker
	_actions_taken_in_phase = 0


func _wait_until_resolution_ready() -> void:
	while (
		_battlefield
		and _game_manager
		and _game_manager.is_game_active
		and _battlefield.is_ai_resolution_busy()
	):
		if MatchSetup.fast_mode:
			await get_tree().process_frame
		else:
			await get_tree().create_timer(0.05).timeout


func _wait_before_action(difficulty: int) -> void:
	if MatchSetup.fast_mode:
		return
	var delay := 0.22
	match difficulty:
		MatchSetup.AIDifficulty.EASY:
			delay = 0.16
		MatchSetup.AIDifficulty.HARD:
			delay = 0.34
	await get_tree().create_timer(delay).timeout


func _record_success(player_id: int, summary: Dictionary) -> void:
	executed_action_count += 1
	action_executed.emit(player_id, summary)


func _record_invalid(player_id: int, summary: Dictionary, error: String) -> void:
	invalid_action_count += 1
	invalid_action.emit(player_id, summary, error)
