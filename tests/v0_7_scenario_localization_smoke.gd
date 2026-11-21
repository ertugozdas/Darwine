extends SceneTree

const EXPECTED := {
	"en": ["COMMANDER'S CAMPAIGN", "First Step to the Front", "Heroes played", "CAMPAIGN OBJECTIVES 2/3"],
	"de": ["KOMMANDANTENFELDZUG", "Erster Schritt an die Front", "Gespielte Helden", "FELDZUGZIELE 2/3"],
	"fr": ["CAMPAGNE DU COMMANDANT", "Premier pas au front", "Héros joués", "OBJECTIFS DE CAMPAGNE 2/3"],
	"it": ["CAMPAGNA DEL COMANDANTE", "Primo passo al fronte", "Eroi giocati", "OBIETTIVI CAMPAGNA 2/3"],
	"es": ["CAMPAÑA DEL COMANDANTE", "Primer paso al frente", "Héroes jugados", "OBJETIVOS DE CAMPAÑA 2/3"],
	"tr": ["KOMUTAN SEFERİ", "Cepheye İlk Adım", "Oynanan Kahraman", "SEFER HEDEFLERİ 2/3"],
}

var _failures: Array[String] = []


func _initialize() -> void:
	for locale in EXPECTED:
		TranslationServer.set_locale(locale)
		var expected: Array = EXPECTED[locale]
		_expect(TranslationServer.translate(&"COMMANDER'S CAMPAIGN") == expected[0], "%s sefer başlığı yanlış" % locale)
		_expect(TranslationServer.translate(&"Cepheye İlk Adım") == expected[1], "%s senaryo adı yanlış" % locale)
		_expect(TranslationServer.translate(&"Oynanan Kahraman") == expected[2], "%s hedef metriği yanlış" % locale)
		var progress := TranslationServer.translate(&"CAMPAIGN OBJECTIVES %d/%d") % [2, 3]
		_expect(progress == expected[3], "%s savaş içi hedef özeti yanlış" % locale)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0_7_SCENARIO_LOCALIZATION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("V0_7_SCENARIO_LOCALIZATION_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
