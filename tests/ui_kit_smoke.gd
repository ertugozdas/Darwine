extends SceneTree

const UI := preload("res://scripts/dark_fantasy_ui.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(FileAccess.file_exists("res://docs/UI_KIT.md"), "UI kit kullanım rehberi bulunamadı")
	_expect(UI.BUTTON_TEXTURE != null, "Dokulu buton yüzeyi yüklenemedi")
	_expect(UI.PANEL_TEXTURE != null, "Dokulu panel yüzeyi yüklenemedi")
	_expect(UI.DISPLAY_FONT.has_char("İ".unicode_at(0)), "Cinzel fontunda Türkçe İ glifi bulunmalı")
	_expect(UI.BODY_FONT.has_char("ş".unicode_at(0)), "Alegreya Sans fontunda Türkçe ş glifi bulunmalı")

	var ui_theme := UI.create_theme()
	_expect(ui_theme.default_font == UI.BODY_FONT, "Gövde fontu ortak temaya bağlanmalı")
	_expect(ui_theme.get_font("font", "Button") == UI.DISPLAY_FONT, "Butonlar gösterim fontunu kullanmalı")

	var button := Button.new()
	UI.style_button(button, UI.BRASS, false, false, true)
	var normal_style := button.get_theme_stylebox("normal")
	var hover_style := button.get_theme_stylebox("hover")
	_expect(normal_style is StyleBoxTexture, "Buton normal durumu dokulu 9-slice olmalı")
	_expect(hover_style is StyleBoxTexture, "Buton hover durumu dokulu 9-slice olmalı")
	if normal_style is StyleBoxTexture:
		_expect((normal_style as StyleBoxTexture).texture == UI.BUTTON_TEXTURE, "Buton UI kit dokusunu kullanmalı")

	var panel_style := UI.panel_style(UI.BRASS, 24.0, 1.0)
	_expect(panel_style.texture == UI.PANEL_TEXTURE, "Panel UI kit dokusunu kullanmalı")
	_expect(panel_style.content_margin_left == 24.0, "Panel aralık tokenını korumalı")
	button.free()

	if _failures.is_empty():
		print("UI_KIT_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("UI_KIT_SMOKE_FAILED: %d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
