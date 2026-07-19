extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	root.size = Vector2i(1280, 720)
	MatchSetup.configure_local(7419)
	MatchSetup.fast_mode = true
	var battlefield := (load("res://battlefield.tscn") as PackedScene).instantiate() as BattlefieldUI
	root.add_child(battlefield)
	while battlefield._is_dealing_initial_hands:
		await process_frame
	battlefield._apply_responsive_layout()
	await process_frame

	_expect(
		battlefield._arena_texture
		and battlefield._arena_texture.texture
		and battlefield._arena_texture.texture.resource_path == "res://images/environments/battlefield_factions_arena_blue_player.png",
		"Savaş alanı iki ordu için üretilen arena arka planını kullanmalı"
	)
	_expect(BattlefieldUI.BOARD_CENTER_GAP >= 90.0, "İki ordu arasında okunur bir tarafsız alan bulunmalı")
	var south_style := battlefield._zone_styles.get(1) as StyleBoxFlat
	var north_style := battlefield._zone_styles.get(2) as StyleBoxFlat
	_expect(
		south_style and north_style and south_style.border_color != north_style.border_color,
		"Kuzey ve güney cepheleri farklı takım renkleri taşımalı"
	)
	_expect(
		south_style and south_style.border_color.b > south_style.border_color.r,
		"Oyuncunun güney cephesi mavi takım kimliği taşımalı"
	)
	_expect(
		north_style and north_style.border_color.r > north_style.border_color.b,
		"Rakibin kuzey cephesi kırmızı takım kimliği taşımalı"
	)
	var own_health_fill := battlefield.top_hud._own_health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var enemy_health_fill := battlefield.top_hud._enemy_health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_expect(
		own_health_fill and own_health_fill.bg_color.b > own_health_fill.bg_color.r,
		"Bizim merkez HUD çubuğu mavi olmalı"
	)
	_expect(
		enemy_health_fill and enemy_health_fill.bg_color.r > enemy_health_fill.bg_color.b,
		"Rakip merkez HUD çubuğu kırmızı olmalı"
	)
	_expect(
		"GÜNEY CEPHESİ" in (battlefield._zone_labels.get(1) as Label).text
		and "KUZEY CEPHESİ" in (battlefield._zone_labels.get(2) as Label).text,
		"Saha kimlikleri cephe adlarını açıkça göstermeli"
	)

	var checkbox := battlefield._auto_attack_checkbox as CheckBox
	_expect(checkbox != null, "Otomatik Saldırı kontrolü bulunmalı")
	if checkbox:
		_expect(checkbox.get_theme_stylebox("hover") is StyleBoxEmpty, "Checkbox hover yüzeyi siyah bir blok çizmemeli")
		checkbox.mouse_entered.emit()
		var hover_panel_style := battlefield._auto_attack_panel.get_theme_stylebox("panel")
		_expect(hover_panel_style is StyleBoxTexture, "Otomatik Saldırı hover durumunda dövme buton yüzeyi korunmalı")
		checkbox.mouse_exited.emit()

	var feedback := battlefield._feedback_layer as BattlefieldFeedbackLayer
	feedback.play_attack_path(Vector2(90.0, 120.0), Vector2(330.0, 250.0), Color(1.0, 0.42, 0.20))
	feedback.trigger_attack_impact(BattlefieldFeedbackLayer.IMPACT_CRITICAL, 1.35)
	_expect(feedback.get_last_impact_kind() == BattlefieldFeedbackLayer.IMPACT_CRITICAL, "Kritik vuruş ayrı etki profili kullanmalı")
	_expect(feedback.impact_animation_count == 1, "Kritik etki tek bir zamanlı darbe üretmeli")
	feedback.enhance_attack_impact(BattlefieldFeedbackLayer.IMPACT_BLOCKED, 1.0)
	_expect(feedback.get_last_impact_kind() == BattlefieldFeedbackLayer.IMPACT_BLOCKED, "Savunma darbesi kalkan profiline geçmeli")
	feedback.enhance_attack_impact(BattlefieldFeedbackLayer.IMPACT_ARMOR_BREAK, 1.1)
	_expect(feedback.get_last_impact_kind() == BattlefieldFeedbackLayer.IMPACT_ARMOR_BREAK, "Zırh hasarı çatlak profiline geçmeli")

	var target_slot := battlefield.get_node("Player2Zone/Grid/Slot_F1") as CardSlot
	var target := HeroCard.new()
	target.owner_id = 2
	target.card_id = "gladiator"
	target_slot.add_child(target)
	await process_frame
	_expect(
		battlefield._get_damage_feedback_kind(target, {"destroyed": true, "health_damage": 4})
		== BattlefieldFeedbackLayer.IMPACT_CRITICAL,
		"Bitirici hasar kritik görsel dilini seçmeli"
	)
	_expect(
		battlefield._get_damage_feedback_kind(target, {"blocked_damage": 2, "health_damage": 0})
		== BattlefieldFeedbackLayer.IMPACT_BLOCKED,
		"Engellenen hasar savunma görsel dilini seçmeli"
	)
	_expect(
		battlefield._get_damage_feedback_kind(target, {"armor_damage": 2, "health_damage": 0})
		== BattlefieldFeedbackLayer.IMPACT_ARMOR_BREAK,
		"Zırha giden hasar çatlama görsel dilini seçmeli"
	)
	_expect(target.play_attack_lunge(target.get_global_rect().get_center() + Vector2.UP * 100.0), "Kart saldırı lunge animasyonunu oynatabilmeli")
	_expect(target.last_feedback_kind == "attack", "Saldırı lunge kart durumuna kaydedilmeli")
	_expect(target.drag_speed >= 24.0 and target.snap_speed >= 18.0, "Kart sürükleme akıcı takip ve kontrollü bırakma hızlarını kullanmalı")

	var icon_script := load("res://scripts/card_stat_icon.gd") as GDScript
	var sword_icon := icon_script.new() as Control
	var shield_icon := icon_script.new() as Control
	sword_icon.set("icon_type", 0)
	shield_icon.set("icon_type", 1)
	_expect(
		(sword_icon.call("_get_icon_palette") as Dictionary).get("accent")
		!= (shield_icon.call("_get_icon_palette") as Dictionary).get("accent"),
		"Saldırı ve savunma ikonları birbirinden ayrılan renk kimlikleri taşımalı"
	)
	sword_icon.free()
	shield_icon.free()

	battlefield.queue_free()
	await process_frame
	MatchSetup.fast_mode = false
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_FEEL_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("COMBAT_FEEL_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
