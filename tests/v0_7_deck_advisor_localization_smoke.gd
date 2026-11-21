extends SceneTree

const EXPECTED_TITLES := {
	"en": "DECK ADVISOR",
	"de": "DECKBERATER",
	"fr": "CONSEILLER DE DECK",
	"it": "CONSULENTE DEL MAZZO",
	"es": "ASESOR DE MAZO",
	"tr": "DESTE DANIŞMANI",
}

var _failures: Array[String] = []


func _initialize() -> void:
	for locale in EXPECTED_TITLES:
		TranslationServer.set_locale(locale)
		_expect(
			TranslationServer.translate(&"DECK ADVISOR") == EXPECTED_TITLES[locale],
			"%s Deste Danışmanı başlığı yanlış" % locale
		)
		var curve := TranslationServer.translate(
			&"The curve averages %.1f Energy, with %d cards at 0–2 and %d at 4+."
		) % [2.7, 12, 6]
		_expect("%" not in curve and "2.7" in curve and "12" in curve and "6" in curve, "%s Enerji eğrisi şablonu biçimlenemedi" % locale)
		var roles := TranslationServer.translate(
			&"FRONT %d • PRESSURE %d • CONTROL %d • SUSTAIN %d • RESOURCE %d • SUPPORT %d"
		) % [4, 8, 3, 5, 2, 8]
		_expect("%" not in roles and "4" in roles and "8" in roles, "%s rol dağılımı şablonu biçimlenemedi" % locale)
		var synergy := TranslationServer.translate(
			&"%s already connects %d cards. Keep it as the plan's anchor or add a second supporting package."
		) % [TranslationServer.translate(&"Guard package"), 6]
		_expect("%" not in synergy and "6" in synergy, "%s anahtar kelime şablonu biçimlenemedi" % locale)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_DECK_ADVISOR_LOCALIZATION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_DECK_ADVISOR_LOCALIZATION_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
