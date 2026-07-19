class_name HowToPlayPanel extends Control

signal closed

const UI := preload("res://scripts/dark_fantasy_ui.gd")

const PAGE_TITLES := [
	"İKİ OYUN MODU",
	"SAVAŞ ALANI VE ZAFER",
	"DESTE, KARTLAR VE ETKİ",
	"BİR TUR NASIL İŞLER?",
	"KART OYNAMA VE HEDEFLEME",
	"ÇATIŞMA VE HAREKET",
	"GÜÇLENME, DURUMLAR VE İPUÇLARI",
	"KONTROLLER, KAYIT VE YARDIM",
]

const PAGE_SUBTITLES := [
	"Kuşatma ve Hakimiyet aynı savaş alanında bambaşka kararlar ister.",
	"Üç koridoru aç, savunma hattını çöz ve doğru zafer koşuluna ulaş.",
	"Desteni dört kart türüyle kur; maçtan önce tek bir kalıcı Etki seç.",
	"Her tur hazırlıkla başlar, kararlarla şekillenir.",
	"Enerjini öde, uygun alanı veya hedefi seç.",
	"Öncelik sırasını okuyarak koridoru adım adım aç.",
	"Seviye yolları ve etkileri birlikte kullanarak üstünlük kur.",
	"Savaş alanını oku, slotlarını yönet ve gerektiğinde kurallara dön.",
]

const GOLD := UI.BRASS
const GOLD_BRIGHT := UI.BRASS_BRIGHT
const CREAM := UI.PARCHMENT
const MUTED := UI.TEXT_MUTED
const INSET := Color(0.022, 0.024, 0.029, 0.96)

var _panel: PanelContainer
var _page_host: Control
var _title_label: Label
var _subtitle_label: Label
var _page_label: Label
var _previous_button: Button
var _next_button: Button
var _pages: Array[Control] = []
var _current_page := 0


func _ready() -> void:
	theme = UI.create_theme()
	name = "HowToOverlay"
	z_index = 108
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_interface()
	resized.connect(_layout_panel)
	_layout_panel()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func open_panel(page_index := 0) -> void:
	_current_page = clampi(page_index, 0, _pages.size() - 1)
	_refresh_page()
	visible = true
	modulate.a = 1.0
	_next_button.grab_focus()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func get_page_count() -> int:
	return _pages.size()


func get_current_page() -> int:
	return _current_page


func show_next_page() -> void:
	if _current_page >= _pages.size() - 1:
		close_panel()
		return
	_current_page += 1
	_refresh_page()


func show_previous_page() -> void:
	if _current_page <= 0:
		return
	_current_page -= 1
	_refresh_page()


func _build_interface() -> void:
	var dim := ColorRect.new()
	dim.name = "HowToDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.003, 0.005, 0.008, 0.91)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "HowToPanel"
	_panel.add_theme_stylebox_override("panel", UI.panel_style(GOLD, 22.0, 0.99))
	add_child(_panel)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	_panel.add_child(shell)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 60.0
	header.add_theme_constant_override("separation", 16)
	shell.add_child(header)
	var header_balance := Label.new()
	header_balance.name = "HowToHeaderBalance"
	header_balance.custom_minimum_size.x = 44.0
	header_balance.text = "◆"
	header_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_balance.add_theme_font_size_override("font_size", 18)
	header_balance.add_theme_color_override("font_color", Color(GOLD, 0.72))
	header.add_child(header_balance)

	var header_copy := VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.add_theme_constant_override("separation", 1)
	header.add_child(header_copy)

	var eyebrow := Label.new()
	eyebrow.name = "HowToEyebrow"
	eyebrow.text = "DARWINE  •  KOMUTANIN EL KİTABI"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", GOLD_BRIGHT)
	header_copy.add_child(eyebrow)

	_title_label = Label.new()
	_title_label.name = "HowToPageTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 27)
	UI.style_title(_title_label, CREAM)
	header_copy.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "HowToPageSubtitle"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 13)
	_subtitle_label.add_theme_color_override("font_color", MUTED)
	header_copy.add_child(_subtitle_label)

	var close_button := Button.new()
	close_button.name = "HowToCloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(44.0, 44.0)
	close_button.add_theme_font_size_override("font_size", 25)
	UI.style_button(close_button, GOLD, false, true)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)

	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", UI.line_style(Color(GOLD, 0.46), 1))
	shell.add_child(rule)

	_page_host = Control.new()
	_page_host.name = "HowToPages"
	_page_host.custom_minimum_size.y = 475.0
	_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_page_host)

	_pages = [
		_build_modes_page(),
		_build_goal_page(),
		_build_card_types_page(),
		_build_turn_page(),
		_build_targeting_page(),
		_build_combat_page(),
		_build_mastery_page(),
		_build_controls_page(),
	]
	for page in _pages:
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_page_host.add_child(page)

	var footer_rule := HSeparator.new()
	footer_rule.add_theme_stylebox_override("separator", UI.line_style(Color(GOLD, 0.28), 1))
	shell.add_child(footer_rule)

	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 46.0
	footer.add_theme_constant_override("separation", 12)
	shell.add_child(footer)

	_previous_button = _make_button("HowToPreviousButton", "←  ÖNCEKİ", false)
	_previous_button.pressed.connect(show_previous_page)
	footer.add_child(_previous_button)

	_page_label = Label.new()
	_page_label.name = "HowToPageCounter"
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", 12)
	_page_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	footer.add_child(_page_label)

	_next_button = _make_button("HowToNextButton", "SONRAKİ  →", true)
	_next_button.pressed.connect(show_next_page)
	footer.add_child(_next_button)

	_refresh_page()


func _build_modes_page() -> Control:
	var page := _make_page_root("HowToModesPage")
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	page.add_child(content)

	var mode_row := HBoxContainer.new()
	mode_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mode_row.add_theme_constant_override("separation", 18)
	content.add_child(mode_row)
	mode_row.add_child(_make_mode_panel(
		"I", "KUŞATMA", "MERKEZİ YIK",
		"Rakibin 30 Canlı Merkez Binasını 0 Cana indir. Koridorun Ön Hat, Arka Hat ve Yapı savunmasını sırayla aş; açılan yoldan Merkeze vur.",
		"Doğrudan baskı  •  Kuşatma hasarı  •  Merkez savunması",
		Color(0.78, 0.36, 0.22),
		"res://images/settlements/merkez_kalesi.png"
	))
	mode_row.add_child(_make_mode_panel(
		"II", "HAKİMİYET", "12 PUANA ULAŞ",
		"Tam raund sonunda üstün olduğun her koridor 1 Hakimiyet puanı kazandırır. Kahramanlar 2, Yapılar 1 kontrol gücü verir; eşit koridor puan üretmez.",
		"Alan kontrolü  •  Üç koridor  •  Raund planlaması",
		Color(0.28, 0.58, 0.86),
		"res://images/environments/battlefield_factions_arena_blue_player.png"
	))

	var oath := PanelContainer.new()
	oath.name = "HowToModeOath"
	oath.add_theme_stylebox_override("panel", UI.inset_style(Color(0.075, 0.052, 0.020, 0.92), GOLD_BRIGHT, 4))
	content.add_child(oath)
	var oath_label := Label.new()
	oath_label.text = "ORTAK KURAL  •  Hakimiyet oynarken de rakip Merkezi yıkmak savaşı anında kazandırır. Modu, maç kurulumundaki OYUN MODU mühründen seçersin."
	oath_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oath_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	oath_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	oath_label.add_theme_font_size_override("font_size", 12)
	oath_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	oath.add_child(oath_label)
	return page


func _build_goal_page() -> Control:
	var page := _make_page_root("HowToGoalPage")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	page.add_child(row)

	var fortress := _make_art_panel(
		"res://images/settlements/merkez_kalesi.png",
		"MERKEZ BİNASI",
		"Her iki komutan 30 Canlı bir Merkez Binasıyla başlar. Rakibinki 0 Cana indiğinde savaş biter.",
		Vector2(300.0, 420.0),
		Color(0.70, 0.38, 0.23)
	)
	row.add_child(fortress)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 10)
	row.add_child(copy)
	copy.add_child(_make_section_title("SAVAŞ ALANI: ÜÇ BAĞIMSIZ KORİDOR"))
	copy.add_child(_make_lane_diagram())
	copy.add_child(_make_rich_text(
		"[b][color=#edbf63]1. Koridoru aç:[/color][/b] Ön Hattaki düşmanlar temizlenmeden geridekilere saldıramazsın.\n"
		+ "[b][color=#edbf63]2. Savunmayı yık:[/color][/b] Ön ve Arka Hat boşalınca Yapı hedef olur.\n"
		+ "[b][color=#edbf63]3. Kaleye ulaş:[/color][/b] Koridorda düşman kart kalmadığında saldırı Merkez Binasına geçer.\n\n"
		+ "[b][color=#ff9870]Kuşatma:[/color][/b] Rakibin Merkez Binasını yık.\n"
		+ "[b][color=#9fd5ff]Hakimiyet:[/color][/b] Kahramanlar 2, Yapılar 1 kontrol gücü verir. Tam raund sonunda üstün olduğun her koridor 1 puan kazandırır; 12 puana ulaş. Eşit koridor tarafsızdır ve Merkezi yıkmak yine anlık zaferdir.",
		154.0
	))
	return page


func _build_card_types_page() -> Control:
	var page := _make_page_root("HowToCardTypesPage")
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	page.add_child(content)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	grid.add_child(_make_art_panel(
		"res://images/heroes/sovalye.webp",
		"KAHRAMAN",
		"Ön veya Arka Hatta konuşlanır. Hazır olduğunda saldırır ya da 1 Enerjiyle komşu koridora hareket eder.",
		Vector2(0.0, 370.0),
		Color(0.31, 0.57, 0.88)
	))
	grid.add_child(_make_art_panel(
		"res://images/settlements/altin_madeni.png",
		"YAPI",
		"Koridorun Yapı alanına kurulur. Gelir, savunma, iyileştirme veya otomatik saldırı sağlar.",
		Vector2(0.0, 370.0),
		Color(0.65, 0.42, 0.23)
	))
	grid.add_child(_make_art_panel(
		"res://images/spells/yildirim.png",
		"BÜYÜ",
		"Tek kullanımlık güçlü etkidir. Kartı seç, parlayan geçerli hedefe tıkla; etkiden sonra Mezarlığa gider.",
		Vector2(0.0, 370.0),
		Color(0.60, 0.33, 0.86)
	))
	grid.add_child(_make_art_panel(
		"res://images/skills/celik_kalkan.png",
		"BECERİ",
		"Dost kartı kalıcı olarak geliştirir; Saldırı, Zırh, Can veya yeni bir anahtar özellik kazandırır.",
		Vector2(0.0, 370.0),
		Color(0.18, 0.65, 0.70)
	))
	var effect_note := PanelContainer.new()
	effect_note.name = "HowToEffectCardNote"
	effect_note.custom_minimum_size.y = 60.0
	effect_note.add_theme_stylebox_override("panel", UI.inset_style(Color(0.035, 0.045, 0.070, 0.96), Color(0.46, 0.58, 0.82), 4))
	content.add_child(effect_note)
	var effect_copy := Label.new()
	effect_copy.text = "ETKİ KARTI  •  Mulligan'dan önce üç tekliften birini seçersin. Eline girmez ve Enerji harcamaz; maç boyunca pasif kalır. Rakibin seçimi gizlidir."
	effect_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_copy.add_theme_font_size_override("font_size", 12)
	effect_copy.add_theme_color_override("font_color", Color(0.76, 0.83, 0.96))
	effect_note.add_child(effect_copy)
	return page


func _build_turn_page() -> Control:
	var page := _make_page_root("HowToTurnPage")
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	page.add_child(content)

	var phases := HBoxContainer.new()
	phases.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phases.add_theme_constant_override("separation", 14)
	content.add_child(phases)
	phases.add_child(_make_phase_panel(
		"01", "HAZIRLIK",
		"res://images/settlements/altin_madeni.png",
		"Kart çekersin; Enerjin yenilenir ve kapasiten 1 artar (3'ten 10'a). Sonra kart oynar, Büyü/Beceri kullanır, hareket eder veya seviye yükseltirsin.",
		Color(0.72, 0.52, 0.24)
	))
	phases.add_child(_make_phase_panel(
		"02", "ÇATIŞMA",
		"res://images/heroes/firtina_avcisi.png",
		"Hazır Kahraman ve saldırabilen Yapıları istediğin sırada kullan. Her saldırgan bir kez vurur ve Tükenmiş olur; bütün kartlarla saldırmak zorunda değilsin.",
		Color(0.31, 0.57, 0.88)
	))
	phases.add_child(_make_phase_panel(
		"03", "TUR SONU",
		"res://images/spells/zehir_yagmuru.png",
		"TURU BİTİR ile Çatışmayı kapatırsın. Zehir, iyileştirme ve Yapı etkileri çalışır; el sınırı uygulanır ve sıra rakibe geçer.",
		Color(0.48, 0.66, 0.32)
	))

	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", UI.inset_style(Color(0.07, 0.045, 0.018, 0.86), GOLD, 4))
	content.add_child(note)
	var note_label := Label.new()
	note_label.text = "EL SINIRI 8  •  TURDA 1 KART ÇEKİLİR  •  ENERJİ TAŞINMAZ  •  ÇATIŞMAYA GEÇ → TURU BİTİR"
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.add_theme_font_size_override("font_size", 12)
	note_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	note.add_child(note_label)
	return page


func _build_targeting_page() -> Control:
	var page := _make_page_root("HowToTargetingPage")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	page.add_child(row)

	var guide := VBoxContainer.new()
	guide.custom_minimum_size.x = 530.0
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.add_theme_constant_override("separation", 10)
	row.add_child(guide)
	guide.add_child(_make_section_title("YERLEŞİM ALANINI OKU"))
	guide.add_child(_make_lane_diagram(true))
	guide.add_child(_make_rich_text(
		"[b]Kahraman:[/b] Boş bir Ön veya Arka Hat alanına oynanır. [color=#edbf63]Menzilli[/color] Kahramanlar Arka Hattan saldırabilir.\n"
		+ "[b]Yapı:[/b] Yalnızca koridorun Yapı alanına kurulur; her koridorda bir Yapı bulunabilir.\n"
		+ "[b]Hareket:[/b] Kahramanı seçip komşu koridordaki aynı sıranın boş alanına tıkla; 1 Enerji harcanır.",
		124.0
	))

	var targeting := VBoxContainer.new()
	targeting.custom_minimum_size.x = 420.0
	targeting.add_theme_constant_override("separation", 10)
	row.add_child(targeting)
	var arts := HBoxContainer.new()
	arts.add_theme_constant_override("separation", 10)
	targeting.add_child(arts)
	arts.add_child(_make_art_panel(
		"res://images/spells/koruyucu_muhur.png", "DOST HEDEF", "Koruma ve iyileştirme.", Vector2(195.0, 266.0), Color(0.35, 0.62, 0.85)
	))
	arts.add_child(_make_art_panel(
		"res://images/spells/alev_dalgasi.png", "DÜŞMAN HEDEF", "Hasar ve kontrol.", Vector2(195.0, 266.0), Color(0.86, 0.34, 0.20)
	))
	targeting.add_child(_make_rich_text(
		"[b][color=#edbf63]Hedefli kartlarda:[/color][/b] Elindeki kartı seçtiğinde yalnızca geçerli hedefler parlar. "
		+ "Bir hedefe tıklayınca Enerji ödenir ve etki çözülür. Geçersiz alanı seçmek Enerji harcamaz. "
		+ "Seçimi iptal etmek için seçili kartına yeniden tıkla.",
		106.0
	))
	return page


func _build_combat_page() -> Control:
	var page := _make_page_root("HowToCombatPage")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	page.add_child(row)

	var attacker := _make_art_panel(
		"res://images/heroes/demir_dev.png",
		"SALDIRAN",
		"Hazır Kahramanı veya saldırabilen Yapıyı seç; ardından kuralların izin verdiği hedefe tıkla.",
		Vector2(285.0, 420.0),
		Color(0.77, 0.48, 0.23)
	)
	row.add_child(attacker)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 10)
	row.add_child(copy)
	copy.add_child(_make_section_title("HEDEF ÖNCELİĞİ"))
	var priority := HBoxContainer.new()
	priority.add_theme_constant_override("separation", 8)
	copy.add_child(priority)
	priority.add_child(_make_priority_step("1", "ÖN HAT", Color(0.75, 0.32, 0.24)))
	priority.add_child(_make_arrow())
	priority.add_child(_make_priority_step("2", "ARKA HAT", Color(0.51, 0.42, 0.72)))
	priority.add_child(_make_arrow())
	priority.add_child(_make_priority_step("3", "YAPI", Color(0.58, 0.43, 0.27)))
	priority.add_child(_make_arrow())
	priority.add_child(_make_priority_step("4", "MERKEZ", GOLD))
	copy.add_child(_make_rich_text(
		"[b]Saldırı:[/b] Saldıran, Saldırısı kadar hasar verir; savunan otomatik karşı saldırı yapmaz. Hasar önce Zırhı, sonra Canı azaltır.\n\n"
		+ "[b]Hazır / Tükenmiş:[/b] Normal Kahraman oynandığı tur Tükenmiş başlar. Saldırı veya hareketten sonra yine Tükenmiş olur. "
		+ "[color=#edbf63]Hızlı[/color] Kahraman oynandığı tur Hazırdır.\n\n"
		+ "[b]Özel kurallar:[/b] [color=#edbf63]Muhafız[/color] dost Yapıya giden ilk hasarı üstlenir. "
		+ "[color=#edbf63]Kuşatma[/color] Yapı ve Merkeze ek hasar verir. Menzilli birlik Arka Hattan saldırabilir.",
		235.0
	))
	return page


func _build_mastery_page() -> Control:
	var page := _make_page_root("HowToMasteryPage")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	page.add_child(row)

	var levels := _make_info_panel("SEVİYE YOLLARI", Color(0.34, 0.56, 0.82))
	levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(levels)
	levels.get_child(0).add_child(_make_art_strip("res://images/heroes/sovalye.webp", 118.0))
	levels.get_child(0).add_child(_make_rich_text(
		"Kahraman ve Yapılar savaşta XP kazanabilir; yalnızca iki seviye yolu bulunan kartlar XP harcayarak yükselir.\n\n"
		+ "[color=#edbf63][b]Seviye 2:[/b][/color] 2 XP + 1 Enerji\n"
		+ "[color=#edbf63][b]Seviye 3:[/b][/color] toplam 6 XP + 2 Enerji\n\n"
		+ "Kartı seç, SEVİYE YÜKSELT'e bas ve iki uzmanlık yolundan birini seç. Yol seçimi kalıcıdır.",
		175.0
	))

	var statuses := _make_info_panel("DURUMLAR", Color(0.60, 0.33, 0.78))
	statuses.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(statuses)
	statuses.get_child(0).add_child(_make_status_row("SERSEMLEMİŞ", "Bir sonraki Hazır olma adımını atlatır.", Color(0.43, 0.67, 0.92)))
	statuses.get_child(0).add_child(_make_status_row("ZEHİRLİ", "Tur Sonunda Can kaybettirir.", Color(0.46, 0.72, 0.30)))
	statuses.get_child(0).add_child(_make_status_row("KORUMALI", "Gelecek hasarı belirtilen miktarda azaltır.", Color(0.90, 0.71, 0.30)))
	statuses.get_child(0).add_child(_make_rich_text(
		"Durum simgesinin üzerindeki sayı, kalan güç veya süreyi gösterir. Aynı etki tekrar uygulandığında kart üzerindeki değer güncellenir.",
		90.0
	))

	var keywords := _make_info_panel("ANAHTARLAR & TAKTİK", Color(0.28, 0.67, 0.61))
	keywords.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(keywords)
	var keyword_box := keywords.get_child(0) as VBoxContainer
	for keyword in ["MENZİLLİ", "HIZLI", "MUHAFIZ", "KUŞATMA", "ŞİFACI", "CAN ÇALMA"]:
		keyword_box.add_child(_make_keyword_chip(keyword))
	keyword_box.add_child(_make_rich_text(
		"[b][color=#edbf63]İpucu:[/color][/b] Enerji üretimini erken kur; bütün koridorları savunmaya çalışma. "
		+ "Bir koridorda tempo kazan, alan hasarıyla kalabalığı cezalandır ve yükseltmeleri hayatta kalacak karta yatır.",
		112.0
	))
	return page


func _build_controls_page() -> Control:
	var page := _make_page_root("HowToControlsPage")
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	page.add_child(content)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	var battlefield := _make_info_panel("SAVAŞ ALANI", Color(0.31, 0.57, 0.88))
	battlefield.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(battlefield)
	var battlefield_box := battlefield.get_child(0) as VBoxContainer
	battlefield_box.add_child(_make_command_row("SOL TIK", "Kart seç, geçerli alanı veya hedefi onayla."))
	battlefield_box.add_child(_make_command_row("SÜRÜKLE", "Boş araziyi sürükleyerek savaş alanında gezin."))
	battlefield_box.add_child(_make_command_row("TEKERLEK", "Yakınlaştır veya uzaklaştır; oklarla yatay ilerle."))
	battlefield_box.add_child(_make_command_row("KART ÖNİZLEME", "Eldeki veya sahadaki karta gelerek ayrıntıyı sağda aç."))

	var turn_tools := _make_info_panel("TUR ARAÇLARI", Color(0.31, 0.62, 0.42))
	turn_tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(turn_tools)
	var turn_box := turn_tools.get_child(0) as VBoxContainer
	turn_box.add_child(_make_command_row("KIRMIZI SÜRE ÇİZGİSİ", "Yeşilden turuncuya ve kırmızıya dönerek kalan süreyi gösterir."))
	turn_box.add_child(_make_command_row("OTOMATİK SALDIRI", "Açıksa uygun saldırıları sırayla çözer; kurulurken kapatılabilir."))
	turn_box.add_child(_make_command_row("KURALLAR", "Duraklatma menüsünden hedef önceliği ve anahtarları yeniden aç."))
	turn_box.add_child(_make_command_row("ESC", "Duraklatma menüsünü aç veya açık pencereyi kapat."))

	var saves := _make_info_panel("KAYIT SLOTU", Color(0.72, 0.52, 0.24))
	saves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(saves)
	var save_box := saves.get_child(0) as VBoxContainer
	save_box.add_child(_make_command_row("SLOT ADI", "Kayıdına hatırlanabilir bir ad ver; mevcut slotu seçersen üzerine yazılır."))
	save_box.add_child(_make_command_row("KAYDET", "Yerel ve yapay zekâ maçlarında o anki bütün savaş durumunu saklar."))
	save_box.add_child(_make_command_row("YÜKLE", "Duraklatma menüsünden veya ana menüdeki YÜKLE ekranından slot seç."))
	save_box.add_child(_make_command_row("YEDEK", "Hasarlı bir slot için son üç güvenli yedekten kurtarma sunulur."))

	var warning := PanelContainer.new()
	warning.add_theme_stylebox_override("panel", UI.inset_style(Color(0.070, 0.030, 0.026, 0.92), Color(0.82, 0.35, 0.25), 4))
	content.add_child(warning)
	var warning_label := Label.new()
	warning_label.text = "ÇEVRİMİÇİ MAÇLAR  •  Adil otorite için yerel kaydet/yükle kapalıdır. Bağlantı koparsa oda yeniden bağlanma akışını kullanır."
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.add_theme_font_size_override("font_size", 12)
	warning_label.add_theme_color_override("font_color", Color(0.96, 0.67, 0.58))
	warning.add_child(warning_label)
	return page


func _make_mode_panel(
	numeral: String,
	title_text: String,
	goal_text: String,
	description: String,
	keywords: String,
	accent: Color,
	art_path: String
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.025, 0.027, 0.032, 0.98), accent, 5))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size = Vector2(180.0, 330.0)
	art_frame.add_theme_stylebox_override("panel", UI.inset_style(Color(0.010, 0.012, 0.016, 1.0), Color(accent, 0.68), 3))
	row.add_child(art_frame)
	var art := TextureRect.new()
	art.texture = load(art_path) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.modulate = Color(0.78, 0.78, 0.78)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(art)
	var art_wash := ColorRect.new()
	art_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_wash.color = Color(accent.darkened(0.62), 0.28)
	art_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(art_wash)
	var seal := Label.new()
	seal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	seal.offset_left = -52.0
	seal.offset_top = -42.0
	seal.offset_right = 52.0
	seal.offset_bottom = 42.0
	seal.text = numeral
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_theme_font_size_override("font_size", 44)
	UI.style_title(seal, accent.lightened(0.30))
	seal.add_theme_constant_override("outline_size", 6)
	art_frame.add_child(seal)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 9)
	row.add_child(copy)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 23)
	UI.style_title(title, accent.lightened(0.24))
	copy.add_child(title)
	var goal := Label.new()
	goal.text = goal_text
	goal.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	goal.add_theme_font_size_override("font_size", 14)
	goal.add_theme_color_override("font_color", GOLD_BRIGHT)
	copy.add_child(goal)
	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", UI.line_style(Color(accent, 0.48), 1))
	copy.add_child(rule)
	var body := Label.new()
	body.text = description
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", CREAM)
	copy.add_child(body)
	var keyword_label := Label.new()
	keyword_label.text = keywords
	keyword_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keyword_label.add_theme_font_size_override("font_size", 11)
	keyword_label.add_theme_color_override("font_color", accent.lightened(0.28))
	copy.add_child(keyword_label)
	return panel


func _make_command_row(command: String, description: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.020, 0.022, 0.027, 0.86), Color(GOLD, 0.34), 3))
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 2)
	panel.add_child(copy)
	var title := Label.new()
	title.text = command
	title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	copy.add_child(title)
	var body := Label.new()
	body.text = description
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", MUTED)
	copy.add_child(body)
	return panel


func _make_page_root(node_name: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = node_name
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	return margin


func _make_art_panel(path: String, heading: String, description: String, minimum: Vector2, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.028, 0.030, 0.035, 0.98), accent, 5))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	var art_backdrop := PanelContainer.new()
	art_backdrop.custom_minimum_size.y = maxf(150.0, minimum.y - 150.0) if minimum.y > 0.0 else 270.0
	art_backdrop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_backdrop.add_theme_stylebox_override("panel", UI.inset_style(Color(0.012, 0.014, 0.018, 1.0), Color(accent, 0.42), 3))
	content.add_child(art_backdrop)

	var art := TextureRect.new()
	art.texture = load(path) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_backdrop.add_child(art)

	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	UI.style_title(title, accent.lightened(0.24))
	content.add_child(title)

	var body := Label.new()
	body.text = description
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", MUTED)
	content.add_child(body)
	return panel


func _make_art_strip(path: String, height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = height
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.01, 0.012, 0.016, 0.96), GOLD, 3))
	var art := TextureRect.new()
	art.texture = load(path) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(art)
	return panel


func _make_phase_panel(index_text: String, heading: String, art_path: String, description: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.add_theme_stylebox_override("panel", UI.inset_style(INSET, accent, 5))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var number := Label.new()
	number.text = index_text
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 11)
	number.add_theme_color_override("font_color", accent.lightened(0.25))
	content.add_child(number)
	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	UI.style_title(title, accent.lightened(0.25))
	content.add_child(title)
	content.add_child(_make_art_strip(art_path, 205.0))
	var body := Label.new()
	body.text = description
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", MUTED)
	content.add_child(body)
	return panel


func _make_lane_diagram(compact := false) -> PanelContainer:
	var board := PanelContainer.new()
	board.custom_minimum_size.y = 170.0 if compact else 192.0
	board.add_theme_stylebox_override("panel", UI.inset_style(Color(0.015, 0.019, 0.024, 0.98), Color(0.42, 0.56, 0.63), 4))
	var lanes := HBoxContainer.new()
	lanes.add_theme_constant_override("separation", 8)
	board.add_child(lanes)
	for lane_index in range(3):
		var lane := PanelContainer.new()
		lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane.add_theme_stylebox_override("panel", UI.inset_style(Color(0.035, 0.039, 0.045, 0.96), Color(0.34, 0.45, 0.53), 3))
		lanes.add_child(lane)
		var lane_box := VBoxContainer.new()
		lane_box.add_theme_constant_override("separation", 4)
		lane.add_child(lane_box)
		var lane_title := Label.new()
		lane_title.text = tr("LANE %d") % (lane_index + 1)
		lane_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lane_title.add_theme_font_size_override("font_size", 10)
		lane_title.add_theme_color_override("font_color", GOLD_BRIGHT)
		lane_box.add_child(lane_title)
		lane_box.add_child(_make_lane_slot("ÖN HAT", Color(0.60, 0.25, 0.22)))
		lane_box.add_child(_make_lane_slot("ARKA HAT", Color(0.35, 0.36, 0.56)))
		lane_box.add_child(_make_lane_slot("YAPI", Color(0.47, 0.37, 0.24)))
	return board


func _make_lane_slot(text_value: String, accent: Color) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := UI.inset_style(Color(accent, 0.23), accent, 2)
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	slot.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", CREAM)
	slot.add_child(label)
	return slot


func _make_priority_step(number: String, text_value: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(106.0, 72.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(accent, 0.18), accent, 4))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var index_label := Label.new()
	index_label.text = number
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index_label.add_theme_font_size_override("font_size", 11)
	index_label.add_theme_color_override("font_color", accent.lightened(0.24))
	box.add_child(index_label)
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	UI.style_title(label, CREAM)
	box.add_child(label)
	return panel


func _make_arrow() -> Label:
	var label := Label.new()
	label.text = "›"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(GOLD, 0.62))
	return label


func _make_info_panel(title_text: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 320.0
	panel.add_theme_stylebox_override("panel", UI.inset_style(INSET, accent, 5))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	UI.style_title(title, accent.lightened(0.24))
	box.add_child(title)
	return panel


func _make_status_row(title_text: String, description: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(accent, 0.12), accent, 3))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", accent.lightened(0.25))
	box.add_child(title)
	var body := Label.new()
	body.text = description
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", MUTED)
	box.add_child(body)
	return panel


func _make_keyword_chip(text_value: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.035, 0.075, 0.073, 0.90), Color(0.28, 0.67, 0.61), 3))
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.64, 0.91, 0.84))
	panel.add_child(label)
	return panel


func _make_section_title(text_value: String) -> Label:
	var title := Label.new()
	title.text = text_value
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	UI.style_title(title, GOLD_BRIGHT)
	return title


func _make_rich_text(bbcode: String, minimum_height: float) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.text = _translate_rich_lines(bbcode)
	rich.custom_minimum_size.y = minimum_height
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich.fit_content = false
	rich.scroll_active = true
	rich.add_theme_font_size_override("normal_font_size", 13)
	rich.add_theme_font_size_override("bold_font_size", 13)
	UI.style_rich_text(rich)
	return rich


func _translate_rich_lines(bbcode: String) -> String:
	var translated_lines: PackedStringArray = []
	for line in bbcode.split("\n", true):
		translated_lines.append("" if line.is_empty() else tr(line))
	return "\n".join(translated_lines)


func _make_button(node_name: String, text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(150.0, 42.0)
	button.add_theme_font_size_override("font_size", 13)
	UI.style_button(button, GOLD, false, true, primary)
	return button


func _refresh_page() -> void:
	if _pages.is_empty():
		return
	for index in range(_pages.size()):
		_pages[index].visible = index == _current_page
	_title_label.text = tr(PAGE_TITLES[_current_page])
	_subtitle_label.text = tr(PAGE_SUBTITLES[_current_page])
	_page_label.text = "%02d  /  %02d" % [_current_page + 1, _pages.size()]
	_previous_button.disabled = _current_page == 0
	_next_button.text = tr("KAPAT  ✓") if _current_page == _pages.size() - 1 else tr("SONRAKİ  →")


func _layout_panel() -> void:
	if _panel == null:
		return
	var viewport_size := size
	var panel_size := Vector2(
		minf(1180.0, maxf(760.0, viewport_size.x - 32.0)),
		minf(680.0, maxf(620.0, viewport_size.y - 24.0))
	)
	_panel.position = (viewport_size - panel_size) * 0.5
	_panel.size = panel_size
