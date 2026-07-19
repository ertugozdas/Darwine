extends SceneTree

var _failures: Array[String] = []
var _draw_requests: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_fixed_deck()
	await _test_turn_energy_and_phase_flow()
	_finish()

func _test_fixed_deck() -> void:
	CardDatabase.load_all(true)
	var deck := CardDatabase.build_fixed_deck()
	_expect(deck.size() == GameRules.DECK_SIZE, "Sabit deste tam olarak 30 kart olmalı")

	var copies: Dictionary = {}
	for card_ref in deck:
		var key := "%s/%s" % [card_ref.get("card_type", ""), card_ref.get("card_id", "")]
		copies[key] = int(copies.get(key, 0)) + 1
	for key in copies:
		_expect(int(copies[key]) <= GameRules.MAX_CARD_COPIES, "%s iki kopya sınırını aşmamalı" % key)

func _test_turn_energy_and_phase_flow() -> void:
	var manager := GameManager.new()
	root.add_child(manager)
	await process_frame
	manager.turn_draw_requested.connect(_on_turn_draw_requested)

	_expect(manager.begin_mulligan(1), "Mulligan başlatılabilmeli")
	_expect(manager.current_phase == GameManager.TurnPhase.MULLIGAN, "Maç Mulligan aşamasında başlamalı")
	_expect(manager.has_preparation_token(2), "İkinci oyuncu Hazırlık jetonu almalı")
	_expect(not manager.confirm_mulligan(2), "Aktif olmayan oyuncu mulliganı ilerletememeli")
	_expect(manager.confirm_mulligan(1), "İlk oyuncu mulliganı onaylayabilmeli")
	_expect(manager.active_player_id == 2, "Mulligan sırası ikinci oyuncuya geçmeli")
	_expect(manager.confirm_mulligan(2), "İkinci oyuncu mulliganı onaylayabilmeli")

	var p1_energy_by_round: Array[int] = [int(manager.player_max_energy[1])]
	var p2_energy_by_round: Array[int] = []
	_expect(p1_energy_by_round == [3], "İlk oyuncu ilk turuna 3/3 Enerji ile başlamalı")
	_expect(manager.current_phase == GameManager.TurnPhase.PREPARATION, "Mulligan sonrası Hazırlık aşaması başlamalı")

	var before_invalid := manager.get_available_energy(1)
	_expect(not manager.spend_energy(2, 1), "Aktif olmayan oyuncu Enerji harcayamamalı")
	_expect(not manager.spend_energy(1, before_invalid + 1), "Yetersiz Enerjili hamle reddedilmeli")
	_expect(manager.get_available_energy(1) == before_invalid, "Geçersiz hamle Enerji harcamamalı")
	_expect(manager.spend_energy(1, 2), "Geçerli hamle Enerji harcamalı")
	_expect(manager.get_available_energy(1) == 1, "Geçerli maliyet mevcut Enerjiden düşmeli")

	_expect(not manager.advance_phase(2), "Aktif olmayan oyuncu fazı ilerletememeli")
	_expect(manager.advance_phase(1), "Hazırlık aşamasından Çatışmaya geçilebilmeli")
	_expect(manager.current_phase == GameManager.TurnPhase.COMBAT, "İkinci aşama Çatışma olmalı")
	var combat_energy := manager.get_available_energy(1)
	_expect(not manager.spend_energy(1, 1), "Çatışma aşamasında kart maliyeti harcanmamalı")
	_expect(manager.get_available_energy(1) == combat_energy, "Yanlış aşamadaki hamle Enerji harcamamalı")
	_expect(manager.advance_phase(1), "Çatışmadan Tur Sonuna geçilebilmeli")
	_expect(not manager.complete_end_phase(2), "Aktif olmayan oyuncu turu devredememeli")
	_expect(manager.complete_end_phase(1), "Aktif oyuncu Tur Sonunu tamamlayabilmeli")

	p2_energy_by_round.append(int(manager.player_max_energy[2]))
	_expect(p2_energy_by_round == [4], "İkinci oyuncunun ilk tur azami Enerjisi 4 olmalı")
	_expect(manager.use_preparation_token(2), "İkinci oyuncu Hazırlık jetonunu kullanabilmeli")
	_expect(manager.get_available_energy(2) == 5, "Hazırlık jetonu +1 geçici Enerji vermeli")
	_expect(not manager.has_preparation_token(2), "Hazırlık jetonu tek kullanımlık olmalı")
	_expect(manager.spend_energy(2, 2), "Geçici Enerji kart maliyetinde kullanılabilmeli")
	_expect(int(manager.player_temporary_energy[2]) == 0, "Geçici Enerji önce harcanmalı")
	_expect(int(manager.player_current_energy[2]) == 3, "Kalan maliyet mevcut Enerjiden düşmeli")

	for _round_index in range(2, 6):
		_finish_current_turn(manager)
		p1_energy_by_round.append(int(manager.player_max_energy[1]))
		_finish_current_turn(manager)
		p2_energy_by_round.append(int(manager.player_max_energy[2]))

	_expect(p1_energy_by_round == [3, 4, 5, 6, 7], "Oyuncu 1'in ilk beş raund Enerjisi 3,4,5,6,7 olmalı")
	_expect(p2_energy_by_round == [4, 5, 6, 7, 8], "Oyuncu 2'nin ilk beş raund Enerjisi 4,5,6,7,8 olmalı")
	_expect(manager.round_count == 5, "On kişisel tur başlangıcında raund sayısı 5 olmalı")
	_expect(_draw_requests.size() == 10, "Her kişisel tur başında bir otomatik çekiş istenmeli")
	for request in _draw_requests:
		_expect(int(request.get("count", 0)) == GameRules.CARDS_DRAWN_PER_TURN, "Otomatik tur çekişi bir kart olmalı")

	manager.queue_free()
	await process_frame

func _finish_current_turn(manager: GameManager) -> void:
	var player_id := manager.active_player_id
	_expect(manager.advance_phase(player_id), "Hazırlık fazı ilerlemeli")
	_expect(manager.advance_phase(player_id), "Çatışma fazı ilerlemeli")
	_expect(manager.complete_end_phase(player_id), "Tur Sonu tamamlanmalı")

func _on_turn_draw_requested(player_id: int, count: int) -> void:
	_draw_requests.append({"player_id": player_id, "count": count})

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_TWO_RULES_SMOKE_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("PHASE_TWO_RULES_SMOKE_FAILED: %d" % _failures.size())
	quit(1)

