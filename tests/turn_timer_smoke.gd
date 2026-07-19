extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_turn_timer_lifecycle()
	await _test_turn_timer_hud()
	await _test_battlefield_timeout_flow()
	_finish()


func _test_turn_timer_lifecycle() -> void:
	var manager := GameManager.new()
	root.add_child(manager)
	await process_frame
	var expired_players: Array[int] = []
	manager.turn_time_expired.connect(func(player_id: int): expired_players.append(player_id))

	_expect(is_equal_approx(GameRules.TURN_DURATION_SECONDS, 30.0), "Tur süresi 30 saniye olmalı")
	_expect(manager.begin_mulligan(1), "Sayaç testi için Mulligan başlamalı")
	_expect(is_equal_approx(manager.turn_time_remaining_seconds, 30.0), "İlk oyuncu 30 saniye ile başlamalı")
	manager._process(10.0)
	_expect(is_equal_approx(manager.turn_time_remaining_seconds, 20.0), "Sayaç gerçek zamanlı olarak azalmalı")
	_expect(manager.confirm_mulligan(1), "İlk oyuncu Mulliganı onaylayabilmeli")
	_expect(manager.active_player_id == 2, "Mulligan ikinci oyuncuya geçmeli")
	_expect(is_equal_approx(manager.turn_time_remaining_seconds, 30.0), "Her oyuncunun turu 30 saniyeye sıfırlanmalı")

	manager._process(30.0)
	_expect(is_equal_approx(manager.turn_time_remaining_seconds, 0.0), "Süre dolunca sayaç sıfıra inmeli")
	_expect(expired_players == [2], "Süre dolumu yalnızca aktif oyuncu için bildirilmelidir")
	manager.queue_free()
	await process_frame


func _test_turn_timer_hud() -> void:
	var hud := TopHud.new()
	root.add_child(hud)
	await process_frame

	hud.set_turn_time(1, 30.0, 30.0, true)
	_expect(hud.own_turn_glow.visible, "Aktif oyuncunun zaman çizgisi görünür olmalı")
	_expect(is_equal_approx(hud.own_turn_glow.scale.x, 1.0), "Zaman çizgisi tam sürede tam uzunlukta olmalı")
	_expect(_line_has_color(hud.own_turn_glow, TopHud.TURN_TIME_SAFE_COLOR), "20 saniyeden fazla süre yeşil olmalı")

	hud.set_turn_time(1, 20.0, 30.0, true)
	_expect(_line_has_color(hud.own_turn_glow, TopHud.TURN_TIME_WARNING_COLOR), "Orta zaman aralığı turuncu olmalı")
	hud.set_turn_time(1, 10.0, 30.0, true)
	_expect(_line_has_color(hud.own_turn_glow, TopHud.TURN_TIME_DANGER_COLOR), "Son zaman aralığı kırmızı olmalı")
	hud.set_turn_time(1, 10.0, 30.0, false)
	_expect(not hud.own_turn_glow.visible, "Aktif tur yokken zaman çizgisi gizlenmeli")

	hud.queue_free()
	await process_frame


func _test_battlefield_timeout_flow() -> void:
	MatchSetup.configure_local(301)
	MatchSetup.fast_mode = true
	MatchSetup.telemetry_to_disk = false
	MatchSetup.forced_first_player_id = 1
	var battlefield_scene := load("res://battlefield.tscn") as PackedScene
	_expect(battlefield_scene != null, "Süre aşımı testi savaş alanını yükleyebilmeli")
	if not battlefield_scene:
		return

	var battlefield := battlefield_scene.instantiate() as BattlefieldUI
	root.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame
	var manager := battlefield.game_manager as GameManager
	manager.cards_drawn_per_turn = 0
	_expect(manager.confirm_mulligan(1), "İlk Mulligan onaylanmalı")
	_expect(manager.confirm_mulligan(2), "İkinci Mulligan onaylanmalı")
	_expect(manager.current_phase == GameManager.TurnPhase.PREPARATION, "Ana tur Hazırlık aşamasında başlamalı")

	manager._process(30.0)
	await process_frame
	_expect(manager.active_player_id == 2, "Süresi dolan oyuncunun turu rakibe geçmeli")
	_expect(manager.current_phase == GameManager.TurnPhase.PREPARATION, "Süre aşımı yeni oyuncuyu Hazırlık aşamasına getirmeli")
	_expect(manager.turn_time_remaining_seconds > 29.5, "Yeni tur 30 saniyeye yakın tam süre ile başlamalı")

	battlefield.queue_free()
	await process_frame


func _line_has_color(line: Panel, expected: Color) -> bool:
	var style := line.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return false
	return (
		is_equal_approx(style.bg_color.r, expected.r)
		and is_equal_approx(style.bg_color.g, expected.g)
		and is_equal_approx(style.bg_color.b, expected.b)
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TURN_TIMER_SMOKE_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("TURN_TIMER_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
