extends SceneTree

const MATCH_ANALYSIS := preload("res://scripts/match_analysis.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_run_siege_fixture()
	_run_dominion_fixture()
	_run_sparse_fixture()
	_finish()


func _run_siege_fixture() -> void:
	var summary := {
		"telemetry_schema_version": 3,
		"ruleset": MatchSetup.Ruleset.SIEGE,
		"winner_id": 1,
		"round_count": 6,
		"players": {
			1: _metrics({
				"energy_spent": 18,
				"unspent_energy_at_combat": 16,
				"combat_phases": 4,
				"max_unspent_energy_at_combat": 6,
				"attacks_declared": 5,
				"hq_attacks": 2,
				"hq_damage": 9,
				"moves": 3,
				"cross_lane_moves": 2,
				"lane_activity": {
					"0": _lane({"deployments": 1, "attacks": 1}),
					"1": _lane({"deployments": 3, "attacks": 4, "hq_attacks": 2, "moves_in": 2, "effect_damage": 4, "cards_destroyed": 2}),
					"2": _lane(),
				},
			}),
			2: _metrics({"lane_activity": {"0": _lane(), "1": _lane({"deployments": 2}), "2": _lane()}}),
		},
	}
	var analysis: Dictionary = MATCH_ANALYSIS.analyze(summary, 1)
	_expect(bool(analysis.get("valid", false)), "Kuşatma analizi geçerli olmalı")
	_expect(str(analysis.get("result_id", "")) == "victory", "Analiz oyuncu bakış açısında zaferi bulmalı")
	var critical := analysis.get("critical_lane", {}) as Dictionary
	_expect(int(critical.get("lane_id", -1)) == CardSlot.Lane.CENTER, "En yoğun karar alanı Orta koridor olmalı")
	_expect(str(critical.get("confidence_id", "")) == "high", "Yoğun koridor kanıtı yüksek güven üretmeli")
	var energy := analysis.get("energy", {}) as Dictionary
	_expect(is_equal_approx(float(energy.get("average_unspent_energy", 0.0)), 4.0), "Ortalama harcanmamış Enerji doğru hesaplanmalı")
	var insights := analysis.get("insights", []) as Array
	_expect(insights.size() == 3, "Analiz Enerji, baskı ve hareket için üç içgörü üretmeli")
	_expect(str((insights[0] as Dictionary).get("id", "")) == "energy_reserve", "Yüksek Enerji rezervi gelişim alanı olmalı")
	_expect(str((insights[1] as Dictionary).get("id", "")) == "hq_conversion", "Kuşatma doğrudan Merkez baskısını yorumlamalı")
	_expect(str((insights[2] as Dictionary).get("tone", "")) == "strength", "Aktif koridor değişimi güçlü karar olmalı")

	var opponent_analysis: Dictionary = MATCH_ANALYSIS.analyze(summary, 2)
	_expect(str(opponent_analysis.get("result_id", "")) == "defeat", "Bakış açısı değişince sonuç tersine dönmeli")


func _run_dominion_fixture() -> void:
	var summary := {
		"telemetry_schema_version": 3,
		"ruleset": MatchSetup.Ruleset.DOMINION,
		"winner_id": 2,
		"round_count": 5,
		"last_dominion_lane_results": [
			{"lane_id": 0, "control": {1: 2, 2: 3}},
			{"lane_id": 1, "control": {1: 7, 2: 6}},
			{"lane_id": 2, "control": {1: 1, 2: 4}},
		],
		"players": {
			1: _metrics({
				"dominion_score": 9,
				"attacks_declared": 4,
				"hq_attacks": 0,
				"moves": 1,
				"cross_lane_moves": 0,
				"lane_activity": {"0": _lane(), "1": _lane({"deployments": 2, "attacks": 3}), "2": _lane()},
			}),
			2: _metrics({
				"dominion_score": 12,
				"lane_activity": {"0": _lane(), "1": _lane({"deployments": 2, "attacks": 2}), "2": _lane({"deployments": 1})},
			}),
		},
	}
	var analysis: Dictionary = MATCH_ANALYSIS.analyze(summary, 1)
	var critical := analysis.get("critical_lane", {}) as Dictionary
	_expect(int(critical.get("lane_id", -1)) == CardSlot.Lane.CENTER, "Hakimiyet analizi kontrol mücadelesini hesaba katmalı")
	_expect(int(critical.get("player_control", 0)) == 7, "Kritik koridor oyuncu kontrol kanıtını taşımalı")
	var insights := analysis.get("insights", []) as Array
	var pressure := insights[1] as Dictionary
	_expect(str(pressure.get("id", "")) == "dominion_gap", "Hakimiyet skor açığı ayrı yorumlanmalı")
	_expect(str(pressure.get("title_key", "")) == "LANE CONTROL", "Hakimiyet Merkez saldırısı yerine koridor kontrolünü anlatmalı")


func _run_sparse_fixture() -> void:
	var analysis: Dictionary = MATCH_ANALYSIS.analyze({
		"ruleset": MatchSetup.Ruleset.SIEGE,
		"winner_id": 0,
		"players": {1: {}, 2: {}},
	}, 1)
	_expect(str(analysis.get("result_id", "")) == "draw", "Kazanan yoksa analiz beraberlik demeli")
	var critical := analysis.get("critical_lane", {}) as Dictionary
	_expect(not bool(critical.get("has_evidence", true)), "Boş özet uydurma koridor kanıtı üretmemeli")
	_expect(int(critical.get("lane_id", -1)) == CardSlot.Lane.CENTER, "Eşitlikte kararlı Orta koridor varsayımı kullanılmalı")
	_expect(not bool(MATCH_ANALYSIS.analyze({}, 99).get("valid", true)), "Geçersiz oyuncu bakış açısı reddedilmeli")


func _metrics(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"energy_spent": 0,
		"unspent_energy_at_combat": 0,
		"combat_phases": 0,
		"max_unspent_energy_at_combat": 0,
		"attacks_declared": 0,
		"hq_attacks": 0,
		"hq_damage": 0,
		"dominion_score": 0,
		"dominion_points": 0,
		"moves": 0,
		"cross_lane_moves": 0,
		"lane_activity": {"0": _lane(), "1": _lane(), "2": _lane()},
	}
	base.merge(overrides, true)
	return base


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
		print("V0_7_MATCH_ANALYSIS_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_MATCH_ANALYSIS_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
