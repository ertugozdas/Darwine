extends SceneTree

const EXPECTED_TITLES := {
	"en": "MATCH ANALYSIS",
	"de": "SPIELANALYSE",
	"fr": "ANALYSE DU MATCH",
	"it": "ANALISI DELLA PARTITA",
	"es": "ANÁLISIS DE LA PARTIDA",
	"tr": "MAÇ ANALİZİ",
}

var _failures: Array[String] = []


func _initialize() -> void:
	for locale in EXPECTED_TITLES:
		TranslationServer.set_locale(locale)
		_expect(
			TranslationServer.translate(&"MATCH ANALYSIS") == EXPECTED_TITLES[locale],
			"%s maç analizi başlığı yanlış" % locale
		)
		var energy := TranslationServer.translate(
			&"You entered Combat with %.1f unspent Energy on average and converted %d Energy into actions."
		) % [1.5, 12]
		_expect("%" not in energy and "1.5" in energy and "12" in energy, "%s Enerji analiz şablonu biçimlenemedi" % locale)
		var dominion := TranslationServer.translate(
			&"You converted lane control into %d Dominion points against %d."
		) % [12, 8]
		_expect("%" not in dominion and "12" in dominion and "8" in dominion, "%s Hakimiyet analiz şablonu biçimlenemedi" % locale)
		var movement := TranslationServer.translate(
			&"You used %d cross-lane moves across %d moves to redirect pressure."
		) % [2, 3]
		_expect("%" not in movement and "2" in movement and "3" in movement, "%s hareket analiz şablonu biçimlenemedi" % locale)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_MATCH_ANALYSIS_LOCALIZATION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_MATCH_ANALYSIS_LOCALIZATION_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
