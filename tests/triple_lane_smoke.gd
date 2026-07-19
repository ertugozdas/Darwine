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
	await process_frame
	await process_frame

	var all_slots := get_nodes_in_group(CardSlot.GROUP_NAME)
	_expect(all_slots.size() == 20, "18 savaş yuvası + 2 merkez yuvası olmalı")

	for player_id in [1, 2]:
		for lane_id in [CardSlot.Lane.LEFT, CardSlot.Lane.CENTER, CardSlot.Lane.RIGHT]:
			var lane_slots := battlefield.get_lane_slots(player_id, lane_id)
			_expect(lane_slots.size() == 3, "Oyuncu %d, koridor %d üç yuvaya sahip olmalı" % [player_id, lane_id])
			if lane_slots.size() == 3:
				_expect(lane_slots[0].position_type == CardSlot.PositionType.FRONT, "Koridorun ilk yuvası Ön Hat olmalı")
				_expect(lane_slots[1].position_type == CardSlot.PositionType.BACK, "Koridorun ikinci yuvası Arka Hat olmalı")
				_expect(lane_slots[2].position_type == CardSlot.PositionType.STRUCTURE, "Koridorun üçüncü yuvası Yapı olmalı")
			_expect(battlefield.is_lane_open(player_id, lane_id), "Boş koridor açık sayılmalı")

	var p1_front := battlefield.get_node("Player1Zone/Grid/Slot_F1") as CardSlot
	var p1_back := battlefield.get_node("Player1Zone/Grid/Slot_B1") as CardSlot
	var p1_structure := battlefield.get_node("Player1Zone/Grid/Slot_S1") as CardSlot
	var p2_front := battlefield.get_node("Player2Zone/Grid/Slot_F1") as CardSlot
	var p2_back := battlefield.get_node("Player2Zone/Grid/Slot_B1") as CardSlot
	var p2_structure := battlefield.get_node("Player2Zone/Grid/Slot_S1") as CardSlot
	var p1_hq_slot := battlefield.get_node("Player1Zone/HQSlot") as CardSlot
	var p2_hq_slot := battlefield.get_node("Player2Zone/HQSlot") as CardSlot
	var p1_hq := p1_hq_slot.occupied_card as SettlementCard
	var p2_hq := p2_hq_slot.occupied_card as SettlementCard

	_expect(p1_front.position.y < p1_back.position.y and p1_back.position.y < p1_structure.position.y, "Oyuncu 1 sıralaması Ön > Arka > Yapı olmalı")
	_expect(p2_structure.position.y < p2_back.position.y and p2_back.position.y < p2_front.position.y, "Oyuncu 2 sıralaması Yapı > Arka > Ön olarak aynalanmalı")
	_expect(battlefield._can_preview_card(p1_hq), "Dost saha kartı sağ önizlemede incelenebilmeli")
	_expect(battlefield._can_preview_card(p2_hq), "Rakip saha kartı sağ önizlemede incelenebilmeli")

	var hq_health_before_upgrade := p1_hq.health
	var hq_upgrade := UpgradeCard.new()
	hq_upgrade.bonus_health = 7
	p1_hq_slot.mouse_entered.emit()
	await create_timer(BattlefieldUI.CARD_PREVIEW_DELAY + 0.02).timeout
	_expect(battlefield._preview_card is SettlementCard, "Dolu saha yuvası hover edildiğinde sağ önizleme açılmalı")
	if battlefield._preview_card is SettlementCard:
		_expect((battlefield._preview_card as SettlementCard).health == hq_health_before_upgrade, "Saha önizlemesi kartın güncel canını göstermeli")

	p1_hq._apply_upgrade(hq_upgrade)
	if battlefield._preview_card is SettlementCard:
		_expect((battlefield._preview_card as SettlementCard).health == hq_health_before_upgrade + 7, "Açık önizleme uygulanan yükseltmeyi anında yansıtmalı")
	p1_hq_slot.mouse_exited.emit()
	hq_upgrade.free()

	var hero := HeroCard.new()
	hero.owner_id = 1
	var opponent_hero := HeroCard.new()
	opponent_hero.owner_id = 2
	var structure := SettlementCard.new()
	structure.owner_id = 1
	var spell := SpecialPowerCard.new()
	spell.owner_id = 1
	var hero_skill := UpgradeCard.new()
	hero_skill.owner_id = 1
	hero_skill.allowed_targets = "Hero"

	_expect(p1_front.can_accept_card(hero), "Ön Hat dost Kahramanı kabul etmeli")
	_expect(p1_back.can_accept_card(hero), "Arka Hat dost Kahramanı kabul etmeli")
	_expect(not p1_structure.can_accept_card(hero), "Yapı alanı Kahramanı reddetmeli")
	_expect(p1_structure.can_accept_card(structure), "Yapı alanı dost Yapıyı kabul etmeli")
	_expect(not p1_front.can_accept_card(structure), "Ön Hat Yapıyı reddetmeli")
	_expect(not p1_front.can_accept_card(opponent_hero), "Düşman kartı dost yuvaya yerleşememeli")
	_expect(not p1_front.can_accept_card(spell), "Büyü savaş yuvasına kalıcı kart gibi yerleşememeli")

	p1_front.accept_card(hero)
	_expect(not battlefield.is_lane_open(1, CardSlot.Lane.LEFT), "Dolu bir yuva koridoru kapatmalı")
	_expect(p1_front.can_accept_card(hero_skill), "Kahraman hedefli Beceri Kahramana uygulanabilmeli")
	p1_front.release_card()
	_expect(battlefield.is_lane_open(1, CardSlot.Lane.LEFT), "Kart ayrılınca tamamen boş koridor yeniden açılmalı")

	p1_structure.accept_card(structure)
	_expect(not p1_structure.can_accept_card(hero_skill), "Kahraman hedefli Beceri Yapıya uygulanamamalı")
	p1_structure.release_card()

	hero.free()
	opponent_hero.free()
	structure.free()
	spell.free()
	hero_skill.free()
	battlefield.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("TRIPLE_LANE_SMOKE_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("TRIPLE_LANE_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
