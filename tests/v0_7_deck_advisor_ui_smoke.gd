extends SceneTree

const DECK_BUILDER_PANEL_SCRIPT := preload("res://scripts/deck_builder_panel.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	var panel := DECK_BUILDER_PANEL_SCRIPT.new()
	root.add_child(panel)
	await process_frame
	panel.open_panel()
	await process_frame
	var advisor := panel.find_child("DeckAdvisorPanel", true, false) as Control
	var shell := panel.find_child("DeckBuilderPanel", true, false) as Control
	_expect(advisor != null, "Deste Danışmanı seçili deste sütununda oluşturulmalı")
	_expect(advisor != null and shell != null and shell.get_global_rect().encloses(advisor.get_global_rect()), "Deste Danışmanı Atölye sınırları içinde kalmalı")
	var advice := panel.get_current_advice() as Dictionary
	_expect(bool(advice.get("is_complete", false)), "Açılışta etkin 30 kartlık deste analiz edilmeli")
	_expect((advice.get("suggestions", []) as Array).size() == 3, "Canlı görünüm üç öneri göstermeli")
	if advisor:
		var curve_counts := advisor.call("get_curve_counts") as Array
		var curve_total := 0
		for count_variant in curve_counts:
			curve_total += int(count_variant)
		_expect(curve_total == GameRules.DECK_SIZE, "Arayüz Enerji eğrisi 30 kartı göstermeli")
		_expect(int(advisor.call("get_suggestion_count")) == 3, "Arayüz üç karar satırı oluşturmalı")
		_expect(int(advisor.call("get_visible_suggestion_count")) == 1, "Danışman kart listesini korumak için kompakt açılmalı")
		advisor.call("set_expanded", true)
		await process_frame
		_expect(bool(advisor.call("is_expanded")) and int(advisor.call("get_visible_suggestion_count")) == 3, "Üç içgörü tek eylemle genişletilebilmeli")
		advisor.call("set_expanded", false)

	var cards := panel.get_working_cards() as Array
	var removed := (cards[0] as Dictionary).duplicate(true)
	panel.call("_remove_card", removed)
	await process_frame
	var changed := panel.get_current_advice() as Dictionary
	_expect(int(changed.get("card_count", 0)) == GameRules.DECK_SIZE - 1, "Kart çıkarınca danışman aynı anda güncellenmeli")
	_expect(int(changed.get("missing_cards", 0)) == 1, "Canlı danışman eksik kart sayısını güncellemeli")
	if advisor:
		var composition_text := str(advisor.call("get_rendered_suggestion", 1))
		_expect("1 kart daha" in composition_text, "Eksik deste önerisi Türkçe ve sayısal olmalı")
	panel.call("_add_card", removed)
	await process_frame
	_expect(bool((panel.get_current_advice() as Dictionary).get("is_complete", false)), "Kart geri eklenince danışman tamamlanmış duruma dönmeli")
	panel.close_panel()
	panel.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_DECK_ADVISOR_UI_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_DECK_ADVISOR_UI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
