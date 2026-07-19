extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var battlefield_scene := load("res://battlefield.tscn") as PackedScene
	_expect(battlefield_scene != null, "battlefield.tscn yüklenemedi")
	if not battlefield_scene:
		_finish()
		return

	var battlefield := battlefield_scene.instantiate() as BattlefieldUI
	root.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame

	var manager := battlefield.game_manager as GameManager
	_expect(manager.current_phase == GameManager.TurnPhase.MULLIGAN, "Dağıtım sonrası Mulligan başlamalı")
	for player_id in GameRules.PLAYER_IDS:
		var hand: Control = battlefield._get_hand_for_player(player_id)
		var deck: Array = battlefield._player_decks[player_id]
		_expect(battlefield._get_hand_card_count(hand) == GameRules.STARTING_HAND_SIZE, "Oyuncu %d başlangıç eli 5 kart olmalı" % player_id)
		_expect(deck.size() == GameRules.DECK_SIZE - GameRules.STARTING_HAND_SIZE, "Oyuncu %d destesinde dağıtım sonrası 25 kart kalmalı" % player_id)

	var first_player := manager.first_player_id
	var first_hand: Control = battlefield._get_hand_for_player(first_player)
	var selected_card := _first_hand_card(first_hand)
	_expect(selected_card != null, "Mulligan için seçilebilir kart bulunmalı")
	if selected_card:
		battlefield.request_hand_card_selection(selected_card)
		_expect(battlefield._phase_selected_cards.size() == 1, "Mulligan kart seçimini kaydetmeli")
		await battlefield._confirm_mulligan_selection()

	_expect(battlefield._get_hand_card_count(first_hand) == GameRules.STARTING_HAND_SIZE, "Mulligan el boyutunu değiştirmemeli")
	_expect((battlefield._player_decks[first_player] as Array).size() == 25, "Mulligan deste boyutunu değiştirmemeli")
	_expect(manager.active_player_id == manager.get_opponent_id(first_player), "Mulligan sırası diğer oyuncuya geçmeli")

	battlefield._confirm_mulligan_selection()
	while battlefield._is_draw_animation_running:
		await process_frame
	await process_frame

	_expect(manager.current_phase == GameManager.TurnPhase.PREPARATION, "İki mulligan sonrası Hazırlık başlamalı")
	_expect(battlefield._get_hand_card_count(first_hand) == GameRules.STARTING_HAND_SIZE + 1, "İlk oyuncu tur başında otomatik bir kart çekmeli")
	_expect((battlefield._player_decks[first_player] as Array).size() == 24, "Otomatik çekiş ilk oyuncunun destesinden bir kart eksiltmeli")

	# Raise the active hand above the limit and verify that End stays blocked
	# until the active player chooses exactly the required number of discards.
	var extra_ref: Dictionary = (battlefield._player_decks[first_player] as Array)[0]
	for extra_index in range(3):
		var extra_card := battlefield._instantiate_card_from_ref(extra_ref, first_player)
		extra_card.name += "_limit_test_%d" % extra_index
		extra_card.set_meta("deck_ref", extra_ref.duplicate(true))
		first_hand.add_child(extra_card)
	await process_frame
	_expect(battlefield._get_hand_card_count(first_hand) == 9, "El sınırı testi için elde 9 kart olmalı")

	_expect(manager.advance_phase(first_player), "El sınırı öncesi Çatışmaya geçilebilmeli")
	_expect(manager.advance_phase(first_player), "El sınırı öncesi Tur Sonuna geçilebilmeli")
	await process_frame
	_expect(manager.current_phase == GameManager.TurnPhase.END, "Faz, fazla kart atılana kadar Tur Sonunda kalmalı")
	_expect(battlefield._discard_required == 1, "Dokuz kartlık elden bir kart atılması istenmeli")

	var discard_card := _first_hand_card(first_hand)
	battlefield.request_hand_card_selection(discard_card)
	battlefield._confirm_discard_selection()
	while battlefield._is_draw_animation_running:
		await process_frame
	await process_frame
	_expect(battlefield._get_hand_card_count(first_hand) == GameRules.MAX_HAND_SIZE, "Tur sonunda el sekiz karta düşmeli")
	_expect(manager.active_player_id == manager.get_opponent_id(first_player), "El sınırı uygulandıktan sonra sıra rakibe geçmeli")

	battlefield.queue_free()
	await process_frame
	_finish()

func _first_hand_card(hand: Control) -> BaseCard:
	for child in hand.get_children():
		if child is BaseCard:
			return child as BaseCard
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_TWO_UI_SMOKE_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("PHASE_TWO_UI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
