extends Node

signal settings_changed(section: String)

const SETTINGS_PATH := "user://settings.cfg"
const WINDOW_RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const FPS_LIMITS := [0, 60, 120, 144]
const DEFAULT_LANGUAGE := "en"
const SUPPORTED_LANGUAGES := ["en", "de", "fr", "it", "es", "tr"]

var master_volume := 80.0
var music_volume := 70.0
var effects_volume := 85.0
var fullscreen := false
var resolution := Vector2i(1280, 720)
var vsync := true
var max_fps := 0
var default_difficulty := 1
var tutorial_enabled := true
var menu_animations := true
var language := DEFAULT_LANGUAGE

var _display_apply_serial := 0
var _updated_at_unix := 0


func _ready() -> void:
	reload_from_disk()


func reload_from_disk() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(SETTINGS_PATH)
	if load_error == OK:
		_updated_at_unix = int(config.get_value("metadata", "updated_at_unix", 0))
		master_volume = clampf(float(config.get_value("audio", "master_volume", 80.0)), 0.0, 100.0)
		music_volume = clampf(float(config.get_value("audio", "music_volume", 70.0)), 0.0, 100.0)
		effects_volume = clampf(float(config.get_value("audio", "effects_volume", 85.0)), 0.0, 100.0)
		fullscreen = bool(config.get_value("display", "fullscreen", false))
		resolution = _parse_resolution(config.get_value("display", "resolution", Vector2i(1280, 720)))
		vsync = bool(config.get_value("display", "vsync", true))
		max_fps = _normalize_fps(int(config.get_value("display", "max_fps", 0)))
		default_difficulty = clampi(int(config.get_value("gameplay", "default_difficulty", 1)), 0, 2)
		tutorial_enabled = bool(config.get_value("gameplay", "tutorial_enabled", true))
		menu_animations = bool(config.get_value("interface", "menu_animations", true))
		language = _normalize_language(str(config.get_value("interface", "language", DEFAULT_LANGUAGE)))
	else:
		language = DEFAULT_LANGUAGE
	TranslationServer.set_locale(language)
	resolution = get_safe_resolution(resolution)
	apply_all()


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "effects_volume", effects_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "max_fps", max_fps)
	config.set_value("gameplay", "default_difficulty", default_difficulty)
	config.set_value("gameplay", "tutorial_enabled", tutorial_enabled)
	config.set_value("interface", "menu_animations", menu_animations)
	config.set_value("interface", "language", language)
	config.set_value("metadata", "updated_at_unix", _updated_at_unix)
	var save_error := config.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("Ayarlar kaydedilemedi: %s" % error_string(save_error))
	return save_error


func reset_to_defaults() -> void:
	master_volume = 80.0
	music_volume = 70.0
	effects_volume = 85.0
	fullscreen = false
	resolution = get_safe_resolution(Vector2i(1280, 720))
	vsync = true
	max_fps = 0
	default_difficulty = 1
	tutorial_enabled = true
	menu_animations = true
	language = DEFAULT_LANGUAGE
	TranslationServer.set_locale(language)
	_updated_at_unix = int(Time.get_unix_time_from_system())
	apply_all()
	save_settings()
	settings_changed.emit("all")


func apply_all() -> void:
	_apply_bus_volume(&"Master", master_volume)
	_apply_bus_volume(&"Music", music_volume)
	_apply_bus_volume(&"SFX", effects_volume)
	Engine.max_fps = max_fps
	if not _can_use_display_server():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		_schedule_windowed_resolution()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 100.0)
	_apply_bus_volume(&"Master", master_volume)
	_commit("audio")


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 100.0)
	_apply_bus_volume(&"Music", music_volume)
	_commit("audio")


func set_effects_volume(value: float) -> void:
	effects_volume = clampf(value, 0.0, 100.0)
	_apply_bus_volume(&"SFX", effects_volume)
	_commit("audio")


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	if _can_use_display_server():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not fullscreen:
			_schedule_windowed_resolution()
	_commit("display")


func set_resolution(value: Vector2i) -> void:
	resolution = get_safe_resolution(value)
	if not fullscreen:
		_schedule_windowed_resolution()
	_commit("display")


func set_vsync(enabled: bool) -> void:
	vsync = enabled
	if _can_use_display_server():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
	_commit("display")


func set_max_fps(value: int) -> void:
	max_fps = _normalize_fps(value)
	Engine.max_fps = max_fps
	_commit("display")


func set_default_difficulty(value: int) -> void:
	default_difficulty = clampi(value, 0, 2)
	_commit("gameplay")


func set_tutorial_enabled(enabled: bool) -> void:
	tutorial_enabled = enabled
	_commit("gameplay")


func set_menu_animations(enabled: bool) -> void:
	menu_animations = enabled
	_commit("interface")


func set_language(locale: String) -> void:
	var normalized := _normalize_language(locale)
	if normalized == language:
		return
	language = normalized
	TranslationServer.set_locale(language)
	_commit("language")


func is_resolution_supported(value: Vector2i) -> bool:
	if not _can_use_display_server():
		return true
	var usable := _get_usable_screen_rect()
	if usable.size.x <= 0 or usable.size.y <= 0:
		return true
	return value.x <= usable.size.x - 24 and value.y <= usable.size.y - 24


func get_safe_resolution(value: Vector2i) -> Vector2i:
	var normalized := Vector2i(maxi(640, value.x), maxi(360, value.y))
	if is_resolution_supported(normalized):
		return normalized
	for index in range(WINDOW_RESOLUTIONS.size() - 1, -1, -1):
		var candidate: Vector2i = WINDOW_RESOLUTIONS[index]
		if is_resolution_supported(candidate):
			return candidate
	if not _can_use_display_server():
		return WINDOW_RESOLUTIONS[0]
	var usable := _get_usable_screen_rect().size - Vector2i(24, 24)
	if usable.x <= 0 or usable.y <= 0:
		return WINDOW_RESOLUTIONS[0]
	var scale_factor := minf(float(usable.x) / 1280.0, float(usable.y) / 720.0)
	return Vector2i(maxi(640, int(1280.0 * scale_factor)), maxi(360, int(720.0 * scale_factor)))


func _schedule_windowed_resolution() -> void:
	_display_apply_serial += 1
	_apply_windowed_resolution.call_deferred(_display_apply_serial)


func _apply_windowed_resolution(serial: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if serial != _display_apply_serial or fullscreen or not _can_use_display_server():
		return
	resolution = get_safe_resolution(resolution)
	DisplayServer.window_set_size(resolution)
	var usable := _get_usable_screen_rect()
	var centered_position := usable.position + (usable.size - resolution) / 2
	DisplayServer.window_set_position(centered_position)


func _get_usable_screen_rect() -> Rect2i:
	var screen := DisplayServer.window_get_current_screen()
	return DisplayServer.screen_get_usable_rect(screen)


func _parse_resolution(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	return Vector2i(1280, 720)


func _normalize_fps(value: int) -> int:
	return value if value in FPS_LIMITS else 0


func _apply_bus_volume(bus_name: StringName, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var normalized := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(normalized, 0.001)))


func _commit(section: String) -> void:
	_updated_at_unix = int(Time.get_unix_time_from_system())
	save_settings()
	settings_changed.emit(section)


func export_profile_payload() -> Dictionary:
	return {
		"updated_at_unix": _updated_at_unix,
		"values": {
			"master_volume": master_volume,
			"music_volume": music_volume,
			"effects_volume": effects_volume,
			"fullscreen": fullscreen,
			"resolution": [resolution.x, resolution.y],
			"vsync": vsync,
			"max_fps": max_fps,
			"default_difficulty": default_difficulty,
			"tutorial_enabled": tutorial_enabled,
			"menu_animations": menu_animations,
			"language": language,
		},
	}


func import_profile_payload(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var values_variant: Variant = payload.get("values", {})
	if not values_variant is Dictionary:
		return
	var values := values_variant as Dictionary
	master_volume = clampf(float(values.get("master_volume", master_volume)), 0.0, 100.0)
	music_volume = clampf(float(values.get("music_volume", music_volume)), 0.0, 100.0)
	effects_volume = clampf(float(values.get("effects_volume", effects_volume)), 0.0, 100.0)
	fullscreen = bool(values.get("fullscreen", fullscreen))
	var resolution_variant: Variant = values.get("resolution", [resolution.x, resolution.y])
	if resolution_variant is Array and (resolution_variant as Array).size() >= 2:
		resolution = get_safe_resolution(Vector2i(int(resolution_variant[0]), int(resolution_variant[1])))
	vsync = bool(values.get("vsync", vsync))
	max_fps = _normalize_fps(int(values.get("max_fps", max_fps)))
	default_difficulty = clampi(int(values.get("default_difficulty", default_difficulty)), 0, 2)
	tutorial_enabled = bool(values.get("tutorial_enabled", tutorial_enabled))
	menu_animations = bool(values.get("menu_animations", menu_animations))
	language = _normalize_language(str(values.get("language", language)))
	TranslationServer.set_locale(language)
	_updated_at_unix = int(payload.get("updated_at_unix", _updated_at_unix))
	apply_all()
	save_settings()
	settings_changed.emit("all")


func _can_use_display_server() -> bool:
	return DisplayServer.get_name() != "headless"


func _normalize_language(locale: String) -> String:
	var normalized := locale.strip_edges().to_lower().replace("-", "_")
	var language_code := normalized.get_slice("_", 0)
	return language_code if language_code in SUPPORTED_LANGUAGES else DEFAULT_LANGUAGE
