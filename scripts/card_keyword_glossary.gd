class_name CardKeywordGlossary extends RefCounted

## Reusable keywords shared by card data, rules text, and the in-game guide.
## Card JSON tags and player-facing copy are validated against this source.
const KEYWORDS: Dictionary = {
	"ranged": {
		"name": "Menzilli",
		"definition": "Arka Hattayken saldırabilir.",
	},
	"fast": {
		"name": "Hızlı",
		"definition": "Oynandığı tur Hazır başlar; saldırabilir veya hareket edebilir.",
	},
	"guard": {
		"name": "Muhafız",
		"definition": "Aynı koridordaki dost Yapıya giden ilk hasarı üstlenir; sahibinin tur başında yenilenir.",
	},
	"siege": {
		"name": "Kuşatma",
		"definition": "Yapılara ve Merkez Binasına belirtilen ilave hasarı verir.",
	},
	"healer": {
		"name": "Şifacı",
		"definition": "Tur Sonunda aynı koridordaki en yaralı dosta belirtilen Canı verir.",
	},
	"lifesteal": {
		"name": "Can Çalma",
		"definition": "Normal saldırıda düşman Cana verilen hasar kadar saldırganı iyileştirir.",
	},
	"wanderer": {
		"name": "Gezgin",
		"definition": "Hareket için Enerji ödemez ve hareketten sonra Hazır kalır.",
	},
	"retaliate": {
		"name": "Misilleme",
		"definition": "Normal bir saldırıdan sağ çıkarsa saldırgana belirtilen hasarı verir.",
	},
	"fog_weaver": {
		"name": "Sis Perdesi",
		"definition": "Aynı koridordaki düşman Menzilli Kahramanların Arka Hattan saldırmasını engeller.",
	},
	"bulwark": {
		"name": "Siper",
		"definition": "Sahibinin Tur Başlangıcından sonraki ilk normal saldırının hasarını belirtilen miktarda azaltır.",
	},
	"war_banner": {
		"name": "Savaş Sancağı",
		"definition": "Aynı koridordaki dost Kahramanların normal saldırı hasarını belirtilen miktarda artırır; Sancaktar da etkilenir ve birden fazlası birikmez.",
	},
	"stormstep": {
		"name": "Akım İzi",
		"definition": "Başka bir koridora hareket ettikten sonra varış koridorundaki ilk düşmana belirtilen hasarı verir.",
	},
	"cleave": {
		"name": "Yarma",
		"definition": "Normal saldırıdan sonra aynı koridordaki sıradaki düşmana belirtilen hasarı verir.",
	},
	"time_thief": {
		"name": "Çalınan An",
		"definition": "Turda ilk kez bir düşman Kahramanı yok ettiğinde belirtilen Canı yeniler ve Hazır olur.",
	},
	"phasewalk": {
		"name": "Faz Yürüyüşü",
		"definition": "Hazırlıkta boş herhangi bir dost Ön veya Arka Hat yuvasına tek hamlede hareket edebilir.",
	},
	"eclipse": {
		"name": "Tutulma",
		"definition": "Aynı koridordaki düşmanların normal saldırı hasarını belirtilen miktarda azaltır; birden fazlası birikmez.",
	},
	"soulbond": {
		"name": "Ruh Bağı",
		"definition": "Raundda bir kez aynı koridordaki başka bir dost Kahraman yok edilince Can yeniler ve Korumalı kazanır.",
	},
	"last_breath": {
		"name": "Son Nefes",
		"definition": "Canı azami Canının yarısı veya altındayken normal saldırıları belirtilen ilave hasarı verir.",
	},
	"steadfast": {
		"name": "Kök Salma",
		"definition": "Tur Sonunda bu tur hareket etmediyse belirtilen Canı ve Zırhı yeniler.",
	},
	"spore_drift": {
		"name": "Spor Sürüklenmesi",
		"definition": "Başka koridora hareket ettikten sonra varış koridorundaki ilk düşman Kahramana belirtilen Zehri verir.",
	},
	"afterburn": {
		"name": "Kor Hasarı",
		"definition": "Turda ilk normal saldırısı düşman Kahramanın Canına hasar verirse belirtilen Zehri verir.",
	},
	"petrify": {
		"name": "Taş Bakış",
		"definition": "Turda ilk normal saldırısı düşman Kahramanın Canına hasar verirse onu belirtilen süreyle Sersemletir.",
	},
	"armor_siphon": {
		"name": "Yansıyan Kabuk",
		"definition": "Turda ilk normal saldırısı düşman Kahramanın Canına hasar verirse belirtilen azami ve mevcut Zırhı kazanır.",
	},
	"starlight_ward": {
		"name": "Ay Kalkanı",
		"definition": "Tur Sonunda Hazır ve Korumalı değilse belirtilen Korumalıyı kazanır.",
	},
	"devourer": {
		"name": "Etçil Büyüme",
		"definition": "Bir düşman Kahramanı yok ettiğinde belirtilen azami ve mevcut Canı kazanır.",
	},
	"hive_mind": {
		"name": "Simbiyoz Korosu",
		"definition": "Tur Başlangıcında aynı koridorda başka dost Kahraman varsa geçici Enerji kazandırır; birden fazlası birikmez.",
	},
	"sporeburst": {
		"name": "Son Spor",
		"definition": "Yok edilince aynı koridordaki ilk düşman Kahramana belirtilen Zehri verir.",
	},
	"gravity_well": {
		"name": "Ağır Alan",
		"definition": "Aynı koridorda hareketine başlayan düşman Kahramanın hareket maliyetini belirtilen Enerji kadar artırır; birden fazlası birikmez.",
	},
	"void_bite": {
		"name": "Boşluk Dikeni",
		"definition": "Normal saldırıların düşman Kahramanın belirtilen Zırhını delerek doğrudan Cana işlemesini sağlar.",
	},
	"last_will": {
		"name": "Son Vasiyet",
		"definition": "Bu kart hasarla yok edildiğinde sahibi belirtilen sayıda kart çeker.",
	},
	"cloaked": {
		"name": "Örtülü",
		"definition": "İlk normal saldırısını yapana kadar doğrudan düşman Özel Güçlerine hedef olamaz; alan etkileri işler.",
	},
}

const STATUS_DEFINITIONS: Dictionary = {
	"stunned": {
		"name": "Sersemlemiş",
		"definition": "Bir sonraki Hazır olma adımını atlar.",
	},
	"poison": {
		"name": "Zehirli",
		"definition": "Sahibinin Tur Sonunda belirtilen hasarı alır.",
	},
	"protected": {
		"name": "Korumalı",
		"definition": "Alacağı bir sonraki hasarı belirtilen miktarda azaltır.",
	},
}

static func is_supported_keyword(keyword_id: String) -> bool:
	return KEYWORDS.has(keyword_id.strip_edges().to_lower())

static func get_keyword_name(keyword_id: String) -> String:
	var normalized := keyword_id.strip_edges().to_lower()
	var entry_variant: Variant = KEYWORDS.get(normalized, {})
	if not entry_variant is Dictionary:
		return ""
	return _translate(str((entry_variant as Dictionary).get("name", "")))

static func get_keyword_definition(keyword_id: String) -> String:
	var normalized := keyword_id.strip_edges().to_lower()
	var entry_variant: Variant = KEYWORDS.get(normalized, {})
	if not entry_variant is Dictionary:
		return ""
	return _translate(str((entry_variant as Dictionary).get("definition", "")))

static func get_reference_text() -> String:
	var lines: Array[String] = [
		"[font_size=22][color=#f2c45c]%s[/color][/font_size]" % _translate("ZAFER KOŞULU"),
	]
	if MatchSetup.is_dominion():
		lines.append("[b][color=#9fd5ff]%s[/color][/b] — %s" % [
			_translate("Hakimiyet"),
			_translate("Heroes provide 2 Control and Structures 1. At the end of a full round, each leading lane grants 1 point; reach %d and finish ahead of the opponent.") % GameRules.DOMINION_SCORE_TARGET,
		])
		lines.append(_translate("Tied lanes are neutral. If both sides reach the target together, sudden-death rounds are played. Destroying Headquarters still wins instantly."))
	else:
		lines.append("[b][color=#ff9870]%s[/color][/b] — %s" % [
			_translate("Kuşatma"),
			_translate("Open the Left, Center or Right lane and destroy the enemy Headquarters with %d Health.") % GameRules.HEADQUARTERS_HEALTH,
		])
	lines.append("")
	lines.append(
		"[font_size=22][color=#f2c45c]%s[/color][/font_size]" % _translate("ANAHTAR KELİMELER"),
	)
	for keyword_id_variant in KEYWORDS.keys():
		var keyword_id := str(keyword_id_variant)
		var entry := KEYWORDS[keyword_id] as Dictionary
		lines.append(
			"[b][color=#9fd5ff]%s[/color][/b] — %s" % [
				_translate(str(entry.get("name", keyword_id))),
				_translate(str(entry.get("definition", ""))),
			]
		)

	lines.append("")
	lines.append("[font_size=20][color=#f2c45c]%s[/color][/font_size]" % _translate("GEÇİCİ DURUMLAR"))
	for status_id_variant in STATUS_DEFINITIONS.keys():
		var status_id := str(status_id_variant)
		var status_entry := STATUS_DEFINITIONS[status_id] as Dictionary
		lines.append(
			"[b][color=#c7b4ff]%s[/color][/b] — %s" % [
				_translate(str(status_entry.get("name", status_id))),
				_translate(str(status_entry.get("definition", ""))),
			]
		)

	lines.append("")
	lines.append("[font_size=20][color=#f2c45c]%s[/color][/font_size]" % _translate("HAMLE SIRASI"))
	lines.append("[b]%s[/b] — %s" % [_translate("Hazırlık"), _translate("Play a card, use a Skill/Spell, move or level up.")])
	lines.append("[b]%s[/b] — %s" % [_translate("Çatışma"), _translate("Select a Ready attacker, then select a red target.")])
	lines.append("[b]%s[/b] — %s" % [_translate("Tur Sonu"), _translate("Effects resolve, the hand limit of 8 is applied and the turn passes.")])
	lines.append("")
	lines.append("[font_size=20][color=#f2c45c]%s[/color][/font_size]" % _translate("HEDEF VE KART AKIŞI"))
	lines.append("[color=#74bfff][b]%s[/b][/color] — %s" % [_translate("Mavi"), _translate("Placement or movement target.")])
	lines.append("[color=#70e5a2][b]%s[/b][/color] — %s" % [_translate("Yeşil"), _translate("Allied support, healing or Skill target.")])
	lines.append("[color=#ff6751][b]%s[/b][/color] — %s" % [_translate("Kırmızı"), _translate("Attack or enemy Spell target.")])
	lines.append(_translate("After the start-of-turn draw, draw reinforcements if your hand has fewer than %d cards.") % GameRules.MINIMUM_TURN_START_HAND)
	lines.append(_translate("The second player's Headquarters has an Opening Shield of %d against the first damage.") % GameRules.SECOND_PLAYER_HQ_PROTECTION)
	return "\n".join(lines)


static func _translate(value: String) -> String:
	return TranslationServer.translate(value)
