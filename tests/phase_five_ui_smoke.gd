extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale("tr")
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
	manager.cards_drawn_per_turn = 0
	var active_player := manager.first_player_id
	var opponent := manager.get_opponent_id(active_player)
	_expect(manager.confirm_mulligan(active_player), "İlk oyuncu mulliganı onaylanmalı")
	_expect(manager.confirm_mulligan(opponent), "İkinci oyuncu mulliganı onaylanmalı")
	await process_frame
	manager.player_current_energy[active_player] = 10
	manager.player_temporary_energy[active_player] = 0
	battlefield.sync_player_energy(active_player)

	var left_front := _get_slot(battlefield, active_player, "Slot_F1")
	var center_front := _get_slot(battlefield, active_player, "Slot_F2")
	var right_front := _get_slot(battlefield, active_player, "Slot_F3")
	var left_back := _get_slot(battlefield, active_player, "Slot_B1")
	var structure_slot := _get_slot(battlefield, active_player, "Slot_S1")
	var mover := _place_hero(left_front, active_player, "sovalye")
	await process_frame
	mover.set_combat_state(BaseCard.CombatState.READY)

	battlefield.request_card_action_selection(left_front)
	_expect(battlefield._selected_action_card == mover, "Hazırlıkta dost Kahraman seçilince kart eylem paneli açılmalı")
	_expect(battlefield._card_action_panel.visible, "Kart eylem paneli görünür olmalı")
	_expect(battlefield._move_action_button.visible and not battlefield._move_action_button.disabled, "Hazır Kahramanın Hareket düğmesi etkin olmalı")
	_expect("Seviye 1" in battlefield._card_action_details.text, "Kart eylem paneli mevcut seviyeyi göstermeli")
	_expect("Tecrübe 0/2" in battlefield._card_action_details.text, "Kart eylem paneli sonraki Tecrübe eşiğini göstermeli")

	battlefield._on_move_action_pressed()
	_expect(battlefield._selected_mover == mover, "Hareket düğmesi hedefleme modunu başlatmalı")
	_expect(not battlefield._card_action_panel.visible, "Hareket hedeflerken kart eylem paneli kapanmalı")
	_expect(left_front.get_combat_highlight() == CardSlot.CombatHighlight.ATTACKER, "Hareket eden Kahramanın yuvası vurgulanmalı")
	_expect(center_front.get_combat_highlight() == CardSlot.CombatHighlight.MOVE_TARGET, "Komşu koridor hareket hedefi mavi vurgulanmalı")
	_expect(left_back.get_combat_highlight() == CardSlot.CombatHighlight.MOVE_TARGET, "Aynı koridordaki Ön/Arka hedefi mavi vurgulanmalı")
	_expect(right_front.get_combat_highlight() == CardSlot.CombatHighlight.NONE, "Sol ile Sağ arasındaki geçersiz hedef vurgulanmamalı")
	_expect("HAREKETİ" in battlefield._phase_label.text, "Faz göstergesi hareket hedefleme modunu açıklamalı")

	var energy_before_invalid := manager.get_available_energy(active_player)
	battlefield.request_movement_target_selection(right_front)
	_expect(manager.get_available_energy(active_player) == energy_before_invalid, "UI'daki geçersiz hareket Enerji harcatmamalı")
	_expect(battlefield._selected_mover == mover and mover.current_slot == left_front, "Geçersiz hareketten sonra hedefleme açık ve konum sabit kalmalı")

	battlefield.request_movement_target_selection(center_front)
	await process_frame
	_expect(mover.current_slot == center_front, "UI hareketi Kahramanı seçilen komşu koridora taşımalı")
	_expect(manager.get_available_energy(active_player) == energy_before_invalid - 1, "UI hareketi tam 1 Enerji harcamalı")
	_expect(mover.has_moved_this_turn and not mover.is_ready_for_combat(), "UI hareketi Kahramanı o tur hareket etmiş ve Tükenmiş işaretlemeli")
	_expect(battlefield._selected_mover == null, "Geçerli hareketten sonra hedefleme modu kapanmalı")
	_expect(center_front.get_combat_highlight() == CardSlot.CombatHighlight.NONE, "Hareketten sonra yuva vurguları temizlenmeli")

	var upgrade_hero := _place_hero(left_back, active_player, "sovalye")
	await process_frame
	upgrade_hero.experience = 2
	upgrade_hero.refresh_runtime_badges()
	battlefield.request_card_action_selection(left_back)
	_expect(battlefield._upgrade_action_button.visible and not battlefield._upgrade_action_button.disabled, "Eşiğe ulaşan kartın yükseltme düğmesi etkin olmalı")
	_expect("SEVİYE 2" in battlefield._upgrade_action_button.text and "1 ENERJİ" in battlefield._upgrade_action_button.text, "Seviye 2 düğmesi maliyeti açıkça göstermeli")
	battlefield._on_upgrade_action_pressed()
	_expect(battlefield._visible_action_branches.size() == 2, "Seviye 2 arayüzü tam iki dal göstermeli")
	_expect(battlefield._branch_action_buttons[0].visible and battlefield._branch_action_buttons[1].visible, "İki dal düğmesi görünür olmalı")
	_expect(not battlefield._move_action_button.visible and not battlefield._upgrade_action_button.visible, "Dal seçerken diğer eylem düğmeleri gizlenmeli")
	_expect(not battlefield._branch_action_buttons[0].text.is_empty() and not battlefield._branch_action_buttons[1].text.is_empty(), "Dal düğmeleri ad ve açıklama taşımalı")
	var chosen_branch_id := str(battlefield._visible_action_branches[0].get("id", ""))
	var energy_before_level_two := manager.get_available_energy(active_player)
	battlefield._on_branch_action_pressed(0)
	_expect(upgrade_hero.card_level == 2 and upgrade_hero.selected_branch_id == chosen_branch_id, "Dal düğmesi Seviye 2 seçimini karta uygulamalı")
	_expect(manager.get_available_energy(active_player) == energy_before_level_two - 1, "UI Seviye 2 yükseltmesi 1 Enerji harcamalı")
	_expect(not battlefield._card_action_panel.visible, "Başarılı yükseltmeden sonra panel kapanmalı")
	_expect(upgrade_hero._progression_label.text == "SV 2", "Karta bağlı rozet Seviye 2'yi göstermeli")
	_expect(upgrade_hero.selected_branch_name in upgrade_hero._progression_badge.tooltip_text, "Seviye rozeti seçilen dalı açıklamalı")

	upgrade_hero.experience = 6
	upgrade_hero.refresh_runtime_badges()
	battlefield.request_card_action_selection(left_back)
	_expect(upgrade_hero.selected_branch_name.to_upper() in battlefield._upgrade_action_button.text, "Seviye 3 düğmesi kilitli dalı göstermeli")
	_expect("2 ENERJİ" in battlefield._upgrade_action_button.text, "Seviye 3 düğmesi 2 Enerji maliyetini göstermeli")
	var energy_before_level_three := manager.get_available_energy(active_player)
	battlefield._on_upgrade_action_pressed()
	_expect(upgrade_hero.card_level == 3 and upgrade_hero.selected_branch_id == chosen_branch_id, "Seviye 3 aynı dalı geliştirmeli")
	_expect(manager.get_available_energy(active_player) == energy_before_level_three - 2, "UI Seviye 3 yükseltmesi 2 Enerji harcamalı")
	_expect(upgrade_hero._progression_label.text == "SV 3", "Karta bağlı rozet Seviye 3'ü göstermeli")

	battlefield._show_card_preview(upgrade_hero)
	await process_frame
	_expect(battlefield._preview_card != null, "Yükseltilmiş saha kartının önizlemesi üretilebilmeli")
	if battlefield._preview_card:
		_expect(battlefield._preview_card.card_level == 3, "Önizleme canlı kartın seviyesini kopyalamalı")
		_expect(battlefield._preview_card.experience == 6, "Önizleme canlı kartın Tecrübesini kopyalamalı")
		_expect(battlefield._preview_card.selected_branch_id == chosen_branch_id, "Önizleme canlı kartın dalını kopyalamalı")

	var mine := _place_structure(structure_slot, active_player, "altin_madeni")
	await process_frame
	mine.experience = 2
	mine.refresh_runtime_badges()
	manager.player_current_energy[active_player] = 10
	manager.player_temporary_energy[active_player] = 0
	battlefield.sync_player_energy(active_player)
	battlefield.request_card_action_selection(structure_slot)
	_expect(not battlefield._move_action_button.visible, "Yapı eylem panelinde Hareket düğmesi görünmemeli")
	_expect(not battlefield._upgrade_action_button.disabled, "Yeterli Tecrübeli Yapı yükseltilebilir olmalı")
	battlefield._on_upgrade_action_pressed()
	_expect(battlefield._visible_action_branches.size() == 2, "Yapı için de iki dallı seçim arayüzü açılmalı")
	var visible_structure_branch_ids: Array[String] = []
	for branch_index in range(battlefield._visible_action_branches.size()):
		var branch := battlefield._visible_action_branches[branch_index] as Dictionary
		visible_structure_branch_ids.append(str(branch.get("id", "")))
		_expect(
			str(branch.get("name", "")).to_upper() in battlefield._branch_action_buttons[branch_index].text,
			"Yapı dal düğmesi gerçek dal adını göstermeli"
		)
	_expect(visible_structure_branch_ids.has("tahkimat"), "Yapı dal seçenekleri Tahkimatı içermeli")
	_expect(visible_structure_branch_ids.has("uretim"), "Yapı dal seçenekleri Üretimi içermeli")
	battlefield._clear_card_action_selection()

	mover.reset_owner_turn_tracking()
	mover.set_combat_state(BaseCard.CombatState.READY)
	battlefield.request_card_action_selection(center_front)
	battlefield._on_move_action_pressed()
	_expect(battlefield._selected_mover == mover, "Aşama değişimi öncesinde hareket modu açılabilmeli")
	_expect(manager.advance_phase(active_player), "UI temizleme testi Çatışmaya geçebilmeli")
	_expect(battlefield._selected_mover == null and not battlefield._card_action_panel.visible, "Aşama değişince hareket ve kart eylem seçimleri temizlenmeli")

	battlefield.queue_free()
	await process_frame
	_finish()

func _get_slot(battlefield: BattlefieldUI, player_id: int, slot_name: String) -> CardSlot:
	return battlefield.get_node("Player%dZone/Grid/%s" % [player_id, slot_name]) as CardSlot

func _place_hero(slot: CardSlot, owner_id: int, card_id: String) -> HeroCard:
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = card_id
	slot.add_child(hero)
	return hero

func _place_structure(slot: CardSlot, owner_id: int, card_id: String) -> SettlementCard:
	var structure := SettlementCard.new()
	structure.owner_id = owner_id
	structure.card_id = card_id
	slot.add_child(structure)
	return structure

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PHASE_FIVE_UI_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PHASE_FIVE_UI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
