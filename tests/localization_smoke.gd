extends SceneTree

const SETTINGS_MANAGER_SCRIPT := preload("res://scripts/settings_manager.gd")

const EXPECTED := {
	"en": ["START BATTLE", "GAME LANGUAGE", "Knight", "Target: Allied Hero. Grants +1 Armor and +1 Health.", "Sunless Queen", "Eclipse: Reduces normal attack damage from enemies in the same lane by 1; multiple Eclipses do not stack.", "Eclipse"],
	"de": ["SCHLACHT BEGINNEN", "SPIELSPRACHE", "Ritter", "Ziel: Verbündeter Held. Gewährt +1 Rüstung und +1 Leben.", "Sonnenlose Königin", "Finsternis: Verringert den Schaden normaler Angriffe von Gegnern derselben Gasse um 1; mehrere Effekte sind nicht kumulativ.", "Finsternis"],
	"fr": ["COMMENCER LA BATAILLE", "LANGUE DU JEU", "Chevalier", "Cible : Héros allié. Accorde +1 Armure et +1 Santé.", "Reine sans soleil", "Éclipse : réduit de 1 les dégâts des attaques normales des ennemis de la même voie ; plusieurs Éclipses ne se cumulent pas.", "Éclipse"],
	"it": ["INIZIA BATTAGLIA", "LINGUA DEL GIOCO", "Cavaliere", "Bersaglio: Eroe alleato. Conferisce +1 Armatura e +1 Salute.", "Regina senza sole", "Eclissi: riduce di 1 i danni degli attacchi normali dei nemici nella stessa corsia; più Eclissi non si sommano.", "Eclissi"],
	"es": ["INICIAR BATALLA", "IDIOMA DEL JUEGO", "Caballero", "Objetivo: Héroe aliado. Otorga +1 Armadura y +1 Salud.", "Reina sin sol", "Eclipse: reduce en 1 el daño de los ataques normales de los enemigos del mismo carril; varios Eclipses no se acumulan.", "Eclipse"],
	"tr": ["SAVAŞA BAŞLA", "OYUN DİLİ", "Şövalye", "Hedef: Dost Kahraman. +1 Zırh ve +1 Can kazandırır.", "Güneşsiz Kraliçe", "Tutulma: Aynı koridordaki düşmanların normal saldırı hasarını 1 azaltır; birden fazlası birikmez.", "Tutulma"],
}

const INTERACTION_COPY_EXPECTED := {
	"en": ["CLICK OR DRAG A CARD • SPACE: ADVANCE PHASE", "Action selection cancelled."],
	"de": ["KARTE ANKLICKEN ODER ZIEHEN • LEERTASTE: PHASE WEITER", "Aktionsauswahl abgebrochen."],
	"fr": ["CLIQUEZ OU FAITES GLISSER UNE CARTE • ESPACE : PHASE SUIVANTE", "Sélection d’action annulée."],
	"it": ["FAI CLIC O TRASCINA UNA CARTA • SPAZIO: FASE SUCCESSIVA", "Selezione azione annullata."],
	"es": ["PULSA O ARRASTRA UNA CARTA • ESPACIO: AVANZAR FASE", "Selección de acción cancelada."],
	"tr": ["KARTA TIKLA VEYA SÜRÜKLE • SPACE: AŞAMAYI İLERLET", "Hamle seçimi iptal edildi."],
}

const STEADFAST_SOURCE := "Kök Salma: Tur Sonunda bu tur hareket etmediyse 1 Can yeniler; Canı tam ise bunun yerine 1 Zırh yeniler."
const STEADFAST_EXPECTED := {
	"en": "Take Root: At Turn End, if it did not move this turn, restores 1 Health; if already at full Health, restores 1 Armor instead.",
	"de": "Wurzeln schlagen: Stellt am Zugende, wenn er sich in diesem Zug nicht bewegt hat, 1 Leben wieder her; bei vollem Leben stattdessen 1 Rüstung.",
	"fr": "Enracinement : à la Fin du tour, s’il ne s’est pas déplacé, récupère 1 Santé ; s’il est déjà à pleine Santé, récupère 1 Armure à la place.",
	"it": "Radicamento: a Fine turno, se non si è mosso, ripristina 1 Salute; se è già a Salute massima, ripristina invece 1 Armatura.",
	"es": "Echar raíces: al Final del turno, si no se movió, restaura 1 de Salud; si ya tiene la Salud al máximo, restaura 1 de Armadura en su lugar.",
	"tr": STEADFAST_SOURCE,
}

const CREATURE_SOURCE := "Kıvılcım Mantarı Kolonisi"
const CREATURE_DESCRIPTION_SOURCE := "Spor Sürüklenmesi: Başka koridora hareket ettikten sonra varış koridorundaki ilk düşman Kahramana 1 Zehir verir."
const CREATURE_KEYWORD_SOURCE := "Spor Sürüklenmesi"
const CREATURE_EXPECTED := {
	"en": ["Sparkcap Colony", "Spore Drift: After moving to another lane, gives Poison 1 to the first enemy Hero in the destination lane.", "Spore Drift"],
	"de": ["Funkenpilzkolonie", "Sporentrift: Nach dem Wechsel in eine andere Gasse gibt sie dem ersten gegnerischen Helden der Zielgasse Vergiftet 1.", "Sporentrift"],
	"fr": ["Colonie de champignons étincelants", "Dérive de spores : après avoir changé de voie, applique Empoisonné 1 au premier Héros ennemi de la voie d’arrivée.", "Dérive de spores"],
	"it": ["Colonia di funghi scintillanti", "Deriva di spore: dopo essersi spostata in un'altra corsia, applica Avvelenato 1 al primo Eroe nemico nella corsia di arrivo.", "Deriva di spore"],
	"es": ["Colonia de hongos chispeantes", "Deriva de esporas: tras moverse a otro carril, aplica Envenenado 1 al primer Héroe enemigo del carril de destino.", "Deriva de esporas"],
	"tr": [CREATURE_SOURCE, CREATURE_DESCRIPTION_SOURCE, CREATURE_KEYWORD_SOURCE],
}

const CREATIVE_CARD_EXPECTED := {
	"en": ["Dreamwalker", "The first Hero you play onto the board each of your turns gains Protected 2.", "Time"],
	"de": ["Traumwandler", "Der erste Held, den du in jedem deiner Züge aufs Spielfeld spielst, erhält Geschützt 2.", "Zeit"],
	"fr": ["Marche-rêve", "Le premier Héros que vous jouez sur le plateau à chacun de vos tours gagne Protégé 2.", "Temps"],
	"it": ["Camminasogni", "Il primo Eroe che giochi sul campo in ogni tuo turno ottiene Protetto 2.", "Tempo"],
	"es": ["Caminasueños", "El primer Héroe que juegues al campo en cada uno de tus turnos obtiene Protegido 2.", "Tiempo"],
	"tr": ["Düş Yürüyeni", "Her kendi turunda sahaya oynadığın ilk Kahraman Korumalı 2 kazanır.", "Zaman"],
}

const ORIGINAL_HERO_SOURCE := "Kehribar Gövde"
const ORIGINAL_HERO_DESCRIPTION_SOURCE := "Muhafız ve Misilleme: Aynı koridordaki dost Yapıya giden ilk hasarı üstlenir; normal bir saldırıdan sağ çıkarsa saldırgana 1 hasar verir."
const ORIGINAL_SKILL_SOURCE := "Kadim Kabuk"
const ORIGINAL_EFFECT_SOURCE := "İlkel Uyum"
const ORIGINAL_EFFECT_DESCRIPTION_SOURCE := "Kendi Tur Başlangıcında en az iki farklı koridorda dost Kahramanın varsa 1 geçici Enerji kazanır ve Merkez dışındaki en yaralı dost kart 1 Can iyileşir."
const ORIGINAL_CARD_EXPECTED := {
	"en": ["Amber Carapace", "Guardian and Retaliate: Takes the first damage aimed at an allied Structure in the same lane; if it survives a normal attack, deals 1 damage to the attacker.", "Ancient Carapace", "Primal Harmony", "At the start of your turn, if you have allied Heroes in at least two different lanes, gain 1 temporary Energy and restore 1 Health to your most wounded allied non-Headquarters card."],
	"de": ["Bernsteinpanzer", "Wächter und Vergeltung: Übernimmt den ersten Schaden für ein verbündetes Bauwerk derselben Gasse; überlebt er einen normalen Angriff, fügt er dem Angreifer 1 Schaden zu.", "Uralter Panzer", "Ursprüngliche Harmonie", "Wenn du zu Beginn deines Zuges verbündete Helden in mindestens zwei verschiedenen Gassen hast, erhältst du 1 temporäre Energie und stellst bei deiner verwundetsten verbündeten Karte außerhalb des Hauptquartiers 1 Leben wieder her."],
	"fr": ["Carapace d’ambre", "Gardien et Riposte : subit les premiers dégâts destinés à une Structure alliée de la même voie ; s’il survit à une attaque normale, inflige 1 dégât à l’attaquant.", "Carapace ancestrale", "Harmonie primordiale", "Au début de votre tour, si vous avez des Héros alliés dans au moins deux voies différentes, gagnez 1 Énergie temporaire et rendez 1 Santé à votre carte alliée hors Quartier général la plus blessée."],
	"it": ["Carapace d’ambra", "Guardiano e Ritorsione: subisce il primo danno diretto a una Struttura alleata nella stessa corsia; se sopravvive a un attacco normale, infligge 1 danno all’attaccante.", "Carapace ancestrale", "Armonia primordiale", "All'inizio del tuo turno, se hai Eroi alleati in almeno due corsie diverse, ottieni 1 Energia temporanea e ripristina 1 Salute alla tua carta alleata non Quartier generale più ferita."],
	"es": ["Caparazón de ámbar", "Guardián y Represalia: recibe el primer daño dirigido a una Estructura aliada del mismo carril; si sobrevive a un ataque normal, inflige 1 de daño al atacante.", "Caparazón ancestral", "Armonía primordial", "Al inicio de tu turno, si tienes Héroes aliados en al menos dos carriles distintos, obtén 1 de Energía temporal y restaura 1 de Salud a tu carta aliada que no sea Cuartel General más herida."],
	"tr": [ORIGINAL_HERO_SOURCE, ORIGINAL_HERO_DESCRIPTION_SOURCE, ORIGINAL_SKILL_SOURCE, ORIGINAL_EFFECT_SOURCE, ORIGINAL_EFFECT_DESCRIPTION_SOURCE],
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var loaded := TranslationServer.get_loaded_locales()
	for locale in EXPECTED:
		_expect(locale in loaded, "%s çeviri kaynağı yüklenmeli" % locale)
		TranslationServer.set_locale(locale)
		var expected_values: Array = EXPECTED[locale]
		_expect(TranslationServer.translate(&"SAVAŞA BAŞLA") == expected_values[0], "%s ana menü çevirisi yanlış" % locale)
		_expect(TranslationServer.translate(&"GAME LANGUAGE") == expected_values[1], "%s dil ekranı çevirisi yanlış" % locale)
		_expect(TranslationServer.translate(&"Şövalye") == expected_values[2], "%s kart adı çevirisi yanlış" % locale)
		_expect(
			TranslationServer.translate(&"Hedef: Dost Kahraman. +1 Zırh ve +1 Can kazandırır.") == expected_values[3],
			"%s kart açıklaması çevirisi yanlış" % locale
		)
		_expect(TranslationServer.translate(&"Güneşsiz Kraliçe") == expected_values[4], "%s yeni kahraman adı çevirisi yanlış" % locale)
		_expect(
			TranslationServer.translate(&"Tutulma: Aynı koridordaki düşmanların normal saldırı hasarını 1 azaltır; birden fazlası birikmez.") == expected_values[5],
			"%s yeni kahraman açıklaması çevirisi yanlış" % locale
		)
		_expect(TranslationServer.translate(&"Tutulma") == expected_values[6], "%s yeni anahtar kelime çevirisi yanlış" % locale)
		var interaction_copy: Array = INTERACTION_COPY_EXPECTED[locale]
		_expect(
			TranslationServer.translate(&"CLICK OR DRAG A CARD • SPACE: ADVANCE PHASE") == interaction_copy[0],
			"%s tıkla/sürükle aşama kılavuzu çevirisi yanlış" % locale
		)
		_expect(
			TranslationServer.translate(&"Action selection cancelled.") == interaction_copy[1],
			"%s etkileşim iptal bildirimi çevirisi yanlış" % locale
		)
		_expect(
			TranslationServer.translate(STEADFAST_SOURCE) == STEADFAST_EXPECTED[locale],
			"%s dengelenmiş Kök Salma açıklaması çevirisi yanlış" % locale
		)
		var creature_values: Array = CREATURE_EXPECTED[locale]
		_expect(TranslationServer.translate(CREATURE_SOURCE) == creature_values[0], "%s yaratık kahraman adı çevirisi yanlış" % locale)
		_expect(TranslationServer.translate(CREATURE_DESCRIPTION_SOURCE) == creature_values[1], "%s yaratık kahraman açıklaması çevirisi yanlış" % locale)
		_expect(TranslationServer.translate(CREATURE_KEYWORD_SOURCE) == creature_values[2], "%s yaratık anahtar kelime çevirisi yanlış" % locale)
		var creative_values: Array = CREATIVE_CARD_EXPECTED[locale]
		_expect(TranslationServer.translate(&"Düş Yürüyeni") == creative_values[0], "%s yaratıcı Kahraman adı çevirisi yanlış" % locale)
		_expect(
			TranslationServer.translate(&"Her kendi turunda sahaya oynadığın ilk Kahraman Korumalı 2 kazanır.") == creative_values[1],
			"%s yaratıcı Etki açıklaması çevirisi yanlış" % locale
		)
		_expect(TranslationServer.translate(&"Zaman") == creative_values[2], "%s yaratıcı Beceri türü çevirisi yanlış" % locale)
		var original_values: Array = ORIGINAL_CARD_EXPECTED[locale]
		_expect(TranslationServer.translate(ORIGINAL_HERO_SOURCE) == original_values[0], "%s özgün Kahraman adı çevirisi yanlış" % locale)
		_expect(TranslationServer.translate(ORIGINAL_HERO_DESCRIPTION_SOURCE) == original_values[1], "%s özgün Kahraman açıklaması çevirisi yanlış" % locale)
		_expect(TranslationServer.translate(ORIGINAL_SKILL_SOURCE) == original_values[2], "%s efsanevi Beceri adı çevirisi yanlış" % locale)
		_expect(TranslationServer.translate(ORIGINAL_EFFECT_SOURCE) == original_values[3], "%s efsanevi Etki adı çevirisi yanlış" % locale)
		_expect(TranslationServer.translate(ORIGINAL_EFFECT_DESCRIPTION_SOURCE) == original_values[4], "%s efsanevi Etki açıklaması çevirisi yanlış" % locale)

	var settings := SETTINGS_MANAGER_SCRIPT.new()
	root.add_child(settings)
	await process_frame
	settings.reset_to_defaults()
	_expect(settings.language == "en", "Yeni ve sıfırlanmış ayarlarda varsayılan dil İngilizce olmalı")
	settings.set_language("es_MX")
	_expect(settings.language == "es", "Bölgesel dil kodu desteklenen ana dile indirgenmeli")
	settings.set_language("xx")
	_expect(settings.language == "en", "Desteklenmeyen dil İngilizceye dönmeli")
	settings.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("LOCALIZATION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("LOCALIZATION_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
