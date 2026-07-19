extends SceneTree

const SETTINGS_MANAGER_SCRIPT := preload("res://scripts/settings_manager.gd")

var _failures: Array[String] = []
var _original: Dictionary = {}
var _changed_sections: Array[String] = []
var _settings: Variant


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_settings = SETTINGS_MANAGER_SCRIPT.new()
	root.add_child(_settings)
	await process_frame
	_snapshot_original_settings()
	_settings.settings_changed.connect(_on_settings_changed)

	_settings.set_master_volume(37.0)
	_settings.set_music_volume(0.0)
	_settings.set_effects_volume(63.0)
	_settings.set_fullscreen(false)
	_settings.set_resolution(Vector2i(1600, 900))
	_settings.set_vsync(false)
	_settings.set_max_fps(60)
	_settings.set_default_difficulty(2)
	_settings.set_tutorial_enabled(false)
	_settings.set_menu_animations(false)
	_settings.set_language("de")
	for _frame in range(5):
		await process_frame

	_expect(is_equal_approx(_settings.master_volume, 37.0), "Ana ses değeri uygulanmalı")
	_expect(is_equal_approx(_settings.music_volume, 0.0), "Müzik ses değeri uygulanmalı")
	_expect(is_equal_approx(_settings.effects_volume, 63.0), "Efekt ses değeri uygulanmalı")
	_expect(not _settings.fullscreen, "Pencereli mod uygulanmalı")
	_expect(_settings.resolution == Vector2i(1600, 900), "1600 × 900 çözünürlük ayarı saklanmalı")
	_expect(not _settings.vsync, "VSync kapatma ayarı saklanmalı")
	_expect(_settings.max_fps == 60 and Engine.max_fps == 60, "60 FPS sınırı motora uygulanmalı")
	_expect(_settings.default_difficulty == 2, "Varsayılan zorluk saklanmalı")
	_expect(not _settings.tutorial_enabled, "Rehber ayarı saklanmalı")
	_expect(not _settings.menu_animations, "Menü animasyonu ayarı saklanmalı")
	_expect(_settings.language == "de" and TranslationServer.get_locale().begins_with("de"), "Dil ayarı uygulanmalı")
	_expect("audio" in _changed_sections, "Ses ayar değişikliği sinyali yayınlanmalı")
	_expect("display" in _changed_sections, "Görüntü ayar değişikliği sinyali yayınlanmalı")
	_expect("gameplay" in _changed_sections, "Oynanış ayar değişikliği sinyali yayınlanmalı")
	_expect("interface" in _changed_sections, "Arayüz ayar değişikliği sinyali yayınlanmalı")
	_expect("language" in _changed_sections, "Dil ayar değişikliği sinyali yayınlanmalı")
	if DisplayServer.get_name() != "headless":
		_expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Pencereli görüntü modu işletim sistemine uygulanmalı")
		_expect(DisplayServer.window_get_size() == _settings.resolution, "Seçilen çözünürlük gerçek pencere boyutuna uygulanmalı")
		_settings.set_fullscreen(true)
		await process_frame
		_expect(
			DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN],
			"Tam ekran modu işletim sistemine uygulanmalı"
		)
		_settings.set_fullscreen(false)
		for _frame in range(4):
			await process_frame
		_expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Tam ekrandan pencereli moda dönülebilmeli")
		_expect(DisplayServer.window_get_size() == _settings.resolution, "Tam ekrandan dönüşte kayıtlı çözünürlük geri uygulanmalı")

	var music_bus := AudioServer.get_bus_index(&"Music")
	var effects_bus := AudioServer.get_bus_index(&"SFX")
	_expect(music_bus >= 0 and AudioServer.is_bus_mute(music_bus), "Müzik %0 olduğunda Music veri yolu sessize alınmalı")
	_expect(effects_bus >= 0 and not AudioServer.is_bus_mute(effects_bus), "Efekt sesi sıfır değilken SFX veri yolu açık kalmalı")

	var config := ConfigFile.new()
	var load_error := config.load(_settings.SETTINGS_PATH)
	_expect(load_error == OK, "Ayar dosyası diske yazılmalı")
	if load_error == OK:
		_expect(is_equal_approx(float(config.get_value("audio", "master_volume", -1.0)), 37.0), "Ana ses ayar dosyasında saklanmalı")
		_expect(config.get_value("display", "resolution", Vector2i.ZERO) == Vector2i(1600, 900), "Çözünürlük ayar dosyasında saklanmalı")
		_expect(int(config.get_value("display", "max_fps", -1)) == 60, "FPS sınırı ayar dosyasında saklanmalı")
		_expect(str(config.get_value("interface", "language", "")) == "de", "Dil ayar dosyasında saklanmalı")

	_settings.master_volume = 100.0
	_settings.max_fps = 144
	_settings.reload_from_disk()
	_expect(is_equal_approx(_settings.master_volume, 37.0), "Ayarlar diskten yeniden yüklenebilmeli")
	_expect(_settings.max_fps == 60, "FPS sınırı diskten yeniden yüklenebilmeli")

	_settings.set_max_fps(999)
	_expect(_settings.max_fps == 0 and Engine.max_fps == 0, "Desteklenmeyen FPS değeri güvenle Limitsiz olmalı")
	_settings.reset_to_defaults()
	_expect(_settings.resolution == _settings.get_safe_resolution(Vector2i(1280, 720)), "Varsayılan çözünürlük geri yüklenmeli")
	_expect(_settings.vsync and _settings.tutorial_enabled, "Varsayılan anahtarlar geri yüklenmeli")
	_expect(_settings.language == "en", "Varsayılan dil İngilizce olmalı")

	_restore_original_settings()
	_finish()


func _snapshot_original_settings() -> void:
	_original = {
		"master_volume": _settings.master_volume,
		"music_volume": _settings.music_volume,
		"effects_volume": _settings.effects_volume,
		"fullscreen": _settings.fullscreen,
		"resolution": _settings.resolution,
		"vsync": _settings.vsync,
		"max_fps": _settings.max_fps,
		"default_difficulty": _settings.default_difficulty,
		"tutorial_enabled": _settings.tutorial_enabled,
		"menu_animations": _settings.menu_animations,
		"language": _settings.language,
	}


func _restore_original_settings() -> void:
	_settings.master_volume = float(_original["master_volume"])
	_settings.music_volume = float(_original["music_volume"])
	_settings.effects_volume = float(_original["effects_volume"])
	_settings.fullscreen = bool(_original["fullscreen"])
	_settings.resolution = Vector2i(_original["resolution"])
	_settings.vsync = bool(_original["vsync"])
	_settings.max_fps = int(_original["max_fps"])
	_settings.default_difficulty = int(_original["default_difficulty"])
	_settings.tutorial_enabled = bool(_original["tutorial_enabled"])
	_settings.menu_animations = bool(_original["menu_animations"])
	_settings.language = str(_original["language"])
	TranslationServer.set_locale(_settings.language)
	_settings.apply_all()
	_settings.save_settings()


func _on_settings_changed(section: String) -> void:
	if section not in _changed_sections:
		_changed_sections.append(section)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SETTINGS_MANAGER_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("SETTINGS_MANAGER_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
