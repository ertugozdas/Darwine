extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("tr")
	MatchSetup.configure_local(707201)
	MatchSetup.fast_mode = true
	var packed := load("res://battlefield.tscn") as PackedScene
	_expect(packed != null, "Savaş alanı analiz arayüzü için yüklenemedi")
	if not packed:
		_finish()
		return
	var battlefield := packed.instantiate() as BattlefieldUI
	root.add_child(battlefield)
	current_scene = battlefield
	await process_frame
	await process_frame
	var analysis_panel := battlefield.find_child("MatchAnalysisPanel", true, false) as Control
	var modal := battlefield.find_child("GameOverModal", true, false) as Control
	_expect(analysis_panel != null, "Maç analizi oyun sonu modalına eklenmeli")
	_expect(modal != null and modal.size.x >= 980.0 and modal.size.y >= 680.0, "Oyun sonu modalı analiz alanına sığmalı")
	var summary := {
		"telemetry_schema_version": 3,
		"ruleset": MatchSetup.Ruleset.SIEGE,
		"winner_id": 1,
		"round_count": 5,
		"duration_seconds": 95.0,
		"players": {
			1: {
				"cards_played": 5,
				"cards_destroyed": 2,
				"mvp_card_name": "—",
				"energy_spent": 17,
				"unspent_energy_at_combat": 12,
				"combat_phases": 4,
				"max_unspent_energy_at_combat": 5,
				"attacks_declared": 4,
				"hq_attacks": 1,
				"hq_damage": 7,
				"moves": 3,
				"cross_lane_moves": 2,
				"lane_activity": {
					"0": _lane(),
					"1": _lane({"deployments": 3, "attacks": 4, "hq_attacks": 1, "moves_in": 2}),
					"2": _lane(),
				},
			},
			2: {"lane_activity": {"0": _lane(), "1": _lane({"deployments": 2}), "2": _lane()}},
		},
	}
	battlefield.call("_update_game_over_summary", summary, 1)
	await process_frame
	_expect(summary.has("match_analysis"), "Oyun sonu özeti kalıcı analiz sözleşmesini taşımalı")
	if analysis_panel:
		_expect(bool(analysis_panel.visible), "Geçerli analiz paneli görünür olmalı")
		_expect(int(analysis_panel.call("get_insight_count")) == 3, "Panel üç karar içgörüsü göstermeli")
		_expect(str(analysis_panel.call("get_critical_lane_text")) == "ORTA", "Kritik koridor seçili dilde gösterilmeli")
		var energy_body := str(analysis_panel.call("get_rendered_insight_body", 0))
		_expect("Enerji" in energy_body and "3.0" in energy_body, "Enerji içgörüsü Türkçe ve kanıt değeriyle gösterilmeli")
	var stored_analysis := summary.get("match_analysis", {}) as Dictionary
	_expect(str(stored_analysis.get("ruleset_id", "")) == "siege", "Analiz kural seti kimliği özete yazılmalı")
	battlefield.queue_free()
	await process_frame
	MatchSetup.configure_local(1)
	_finish()


func _lane(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"deployments": 0,
		"attacks": 0,
		"hq_attacks": 0,
		"moves_in": 0,
		"moves_out": 0,
		"effect_damage": 0,
		"cards_destroyed": 0,
	}
	base.merge(overrides, true)
	return base


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_MATCH_ANALYSIS_UI_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_MATCH_ANALYSIS_UI_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
