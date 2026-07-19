class_name FirstMatchTutorial extends Control

signal tutorial_closed(skipped: bool)

const UI := preload("res://scripts/dark_fantasy_ui.gd")

const STEPS: Array[Dictionary] = [
	{
		"eyebrow": "AMAÇ",
		"title": "Üç koridoru aç, Merkez Binasını yık",
		"body": "Her oyuncunun [b]30 Canlı Merkez Binası[/b] vardır. Sol, Orta ve Sağ koridorlarda rakibin Ön Hat, Arka Hat ve Yapı kartlarını temizle. Bir koridor açıldığında o koridordaki saldırılar doğrudan Merkez Binasına ulaşır.",
		"hint": "Yeşil kesik rota, Merkez Binasına açık saldırı yolunu gösterir.",
	},
	{
		"eyebrow": "BAŞLANGIÇ",
		"title": "Başlangıç elini hazırla",
		"body": "İstemediğin başlangıç kartlarına tıkla; seçilen kartlar altın renkle işaretlenir. Sağdaki düğmeyle seçtiğin kartları bir kez değiştirebilirsin. İkinci oyuncunun Merkezi, ilk hasarda [b]Korumalı 6[/b] veren tek kullanımlık Açılış Kalkanıyla başlar.",
		"hint": "Kart ayrıntısını görmek için elindeki veya sahadaki kartın üzerine gel. Saha durumları artık kart şeridinde görünür.",
	},
	{
		"eyebrow": "HAZIRLIK",
		"title": "Enerjini kullan ve kart oyna",
		"body": "Bir [b]Kahramanı[/b] Ön/Arka Hatta, bir [b]Yapıyı[/b] Yapı yuvasında bırak. Mavi yuva yerleştirme/hareketi, yeşil hedef dost desteğini, kırmızı hedef saldırı veya düşman etkisini gösterir. Sahadaki dost karta tıklayarak hareket veya seviye yükseltme eylemlerini açabilirsin.",
		"hint": "Hedef plakasındaki YERLEŞTİR, BECERİ VER, İYİLEŞTİR veya VUR fiili yapılacak hamleyi söyler.",
	},
	{
		"eyebrow": "ÇATIŞMA",
		"title": "Hazır saldırganı ve kırmızı hedefi seç",
		"body": "Önce yeşil çerçeveli, [b]Hazır[/b] Kahramanına ya da saldırabilen Yapına tıkla. Ardından kırmızı hedefe tıkla. Aynı koridorda daima Ön Hat, sonra Arka Hat, sonra Yapı hedeflenir; açık koridorda hedef Merkez Binasıdır.",
		"hint": "Menzilli kartlar Arka Hattan saldırabilir. Saldıran kart Tükenmiş olur.",
	},
	{
		"eyebrow": "TUR AKIŞI",
		"title": "Aşamayı sağdaki ana düğmeyle ilerlet",
		"body": "[b]Çatışmaya Geç[/b] Hazırlığı bitirir. [b]Turu Bitir[/b] Tur Sonu etkilerini çözer ve sırayı rakibe verir. Sonraki turda bir kart çekersin; bu çekiş elini üç karta ulaştırmıyorsa takviye kartları gelir. Taktik Değişim bir el kartını yeniler, İkmal Emri iki kart çeker.",
		"hint": "Alanı sürükleyebilir, fare tekeriyle yakınlaşabilir ve SOL/SAĞ düğmeleriyle yatay tarayabilirsin.",
	},
]

var _panel: Panel = null
var _step_label: Label = null
var _eyebrow_label: Label = null
var _title_label: Label = null
var _body_label: RichTextLabel = null
var _hint_label: Label = null
var _back_button: Button = null
var _next_button: Button = null
var _skip_button: Button = null
var _current_step := 0

func _ready() -> void:
	name = "FirstMatchTutorial"
	theme = UI.create_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 900
	_create_ui()
	visibility_changed.connect(_on_visibility_changed)
	resized.connect(_layout_panel)
	visible = false

func open_tutorial(step_index: int = 0) -> void:
	_current_step = clampi(step_index, 0, STEPS.size() - 1)
	visible = true
	_layout_panel()
	_refresh_step()
	_next_button.grab_focus()

func close_tutorial(skipped: bool = false) -> void:
	if not visible:
		return
	visible = false
	tutorial_closed.emit(skipped)

func is_open() -> bool:
	return visible

func get_step_count() -> int:
	return STEPS.size()

func get_current_step() -> int:
	return _current_step

func _create_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UI.VOID, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = Panel.new()
	_panel.name = "TutorialPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _build_panel_style())
	add_child(_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 30.0
	content.offset_top = 24.0
	content.offset_right = -30.0
	content.offset_bottom = -24.0
	content.add_theme_constant_override("separation", 13)
	_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)

	_eyebrow_label = Label.new()
	_eyebrow_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eyebrow_label.add_theme_font_size_override("font_size", 14)
	UI.style_title(_eyebrow_label, UI.FROST.lightened(0.18))
	header.add_child(_eyebrow_label)

	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_step_label.add_theme_font_size_override("font_size", 13)
	_step_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82))
	header.add_child(_step_label)

	_title_label = Label.new()
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 25)
	UI.style_title(_title_label, UI.BRASS_BRIGHT)
	content.add_child(_title_label)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = false
	_body_label.scroll_active = true
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.custom_minimum_size = Vector2(0.0, 150.0)
	_body_label.add_theme_font_size_override("normal_font_size", 17)
	_body_label.add_theme_font_size_override("bold_font_size", 17)
	UI.style_rich_text(_body_label)
	content.add_child(_body_label)

	var hint_panel := PanelContainer.new()
	hint_panel.custom_minimum_size.y = 58.0
	hint_panel.add_theme_stylebox_override("panel", _build_hint_style())
	content.add_child(hint_panel)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(0.78, 0.91, 1.0))
	hint_panel.add_child(_hint_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)

	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.text = "ATLA"
	_style_button(_skip_button, Color(0.16, 0.08, 0.09), Color(0.76, 0.30, 0.30))
	buttons.add_child(_skip_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "GERİ"
	_style_button(_back_button, Color(0.08, 0.12, 0.20), Color(0.34, 0.56, 0.82))
	buttons.add_child(_back_button)

	_next_button = Button.new()
	_next_button.name = "NextButton"
	_style_button(_next_button, Color(0.25, 0.16, 0.045), Color(0.96, 0.68, 0.22))
	buttons.add_child(_next_button)

	_skip_button.pressed.connect(close_tutorial.bind(true))
	_back_button.pressed.connect(_on_back_pressed)
	_next_button.pressed.connect(_on_next_pressed)

func _refresh_step() -> void:
	var step := STEPS[_current_step].duplicate(true)
	if _current_step == 0 and MatchSetup.is_dominion():
		step = {
			"eyebrow": "HAKİMİYET AMACI",
			"title": "Koridorları kontrol et, 12 puana ulaş",
			"body": "Her [b]Kahraman 2[/b], her [b]Yapı 1[/b] kontrol gücü verir. Sol, Orta ve Sağ koridorda rakipten daha yüksek güce sahipsen tam raund sonunda o koridordan [b]1 Hakimiyet puanı[/b] kazanırsın. Eşit koridor tarafsızdır.",
			"hint": "Koridor rozetleri canlı gücü gösterir; puan iki oyuncu da turunu tamamlayınca işlenir. Merkez Binasını yıkmak yine anlık zaferdir.",
		}
	_eyebrow_label.text = tr(str(step.get("eyebrow", "")))
	_step_label.text = "%d / %d" % [_current_step + 1, STEPS.size()]
	_title_label.text = tr(str(step.get("title", "")))
	_body_label.text = tr(str(step.get("body", "")))
	_hint_label.text = tr("TIP  •  %s") % tr(str(step.get("hint", "")))
	_back_button.disabled = _current_step == 0
	_next_button.text = tr("START PLAYING") if _current_step == STEPS.size() - 1 else tr("NEXT")

func _on_back_pressed() -> void:
	if _current_step <= 0:
		return
	_current_step -= 1
	_refresh_step()

func _on_next_pressed() -> void:
	if _current_step >= STEPS.size() - 1:
		close_tutorial(false)
		return
	_current_step += 1
	_refresh_step()

func _on_visibility_changed() -> void:
	set_process_unhandled_input(visible)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	close_tutorial(true)
	get_viewport().set_input_as_handled()

func _layout_panel() -> void:
	if not _panel:
		return
	var panel_size := Vector2(
		minf(700.0, maxf(320.0, size.x - 48.0)),
		minf(480.0, maxf(360.0, size.y - 48.0))
	)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -panel_size.x * 0.5
	_panel.offset_top = -panel_size.y * 0.5
	_panel.offset_right = panel_size.x * 0.5
	_panel.offset_bottom = panel_size.y * 0.5

func _build_panel_style() -> StyleBoxTexture:
	return UI.panel_style(UI.BRASS, 14.0, 1.0)

func _build_hint_style() -> StyleBoxFlat:
	var style := UI.inset_style(Color(0.035, 0.075, 0.10, 0.92), UI.FROST, 4)
	style.border_width_left = 3
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _style_button(button: Button, _background: Color, border: Color) -> void:
	button.custom_minimum_size = Vector2(128.0, 42.0)
	button.add_theme_font_size_override("font_size", 14)
	UI.style_button(button, border, button.name == "SkipButton", true, button.name == "NextButton")
