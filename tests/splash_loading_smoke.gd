extends SceneTree

const WALLPAPER_PATHS := [
	"res://images/loading/wallpaper_01_citadel.png",
	"res://images/loading/wallpaper_02_ramparts.png",
	"res://images/loading/wallpaper_03_battlefield.png",
	"res://images/loading/wallpaper_04_forge.png",
	"res://images/loading/wallpaper_05_frost_pass.png",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ProjectSettings.get_setting("application/run/main_scene") == "res://splash_screen.tscn", "Açılış sahnesi splash olmalı")
	_expect(ResourceLoader.exists("res://images/branding/studio_logo.png"), "Stüdyo logosu bulunamadı")
	_expect(ResourceLoader.exists("res://sounds/splash/splash_logo.mp3"), "Splash sesi bulunamadı")
	_expect(WALLPAPER_PATHS.size() == 5, "Beş yükleme duvar kağıdı tanımlanmalı")
	for wallpaper_path in WALLPAPER_PATHS:
		_expect(ResourceLoader.exists(wallpaper_path), "Yükleme duvar kağıdı bulunamadı: %s" % wallpaper_path)

	var splash_scene := load("res://splash_screen.tscn") as PackedScene
	_expect(splash_scene != null, "Splash sahnesi yüklenemedi")
	if splash_scene:
		var splash := splash_scene.instantiate()
		root.add_child(splash)
		await process_frame
		await process_frame
		_expect(splash.find_child("BlackBackground", true, false) is ColorRect, "Splash tam siyah arka plana sahip olmalı")
		_expect(splash.find_child("StudioLogo", true, false) is TextureRect, "Splash logosu bulunamadı")
		var splash_audio := splash.find_child("SplashAudio", true, false) as AudioStreamPlayer
		_expect(splash_audio != null and splash_audio.playing, "Logo büyürken splash sesi başlamalı")
		splash.free()
		await process_frame

	var scene_transition := root.get_node_or_null("SceneTransition")
	_expect(scene_transition != null, "SceneTransition autoload bulunamadı")
	if scene_transition == null:
		_finish()
		return
	scene_transition.target_scene_path = "res://main_menu.tscn"
	scene_transition.minimum_screen_time = 0.45
	scene_transition.transition_active = true
	var loading_scene := load("res://loading_screen.tscn") as PackedScene
	_expect(loading_scene != null, "Yükleme sahnesi yüklenemedi")
	if loading_scene == null:
		_finish()
		return

	var loading := loading_scene.instantiate()
	root.add_child(loading)
	current_scene = loading
	await process_frame
	await process_frame

	var title := loading.find_child("DarwineTitle", true, false) as Label
	var progress := loading.find_child("RealLoadingProgress", true, false) as ProgressBar
	var tip := loading.find_child("LoadingTip", true, false) as Label
	var music := loading.find_child("LoadingMusic", true, false) as AudioStreamPlayer
	_expect(title != null and title.text == "DARWINE", "Yükleme ekranının ortasında DARWINE görünmeli")
	_expect(progress != null, "Gerçek yükleme çubuğu bulunamadı")
	_expect(tip != null and not tip.text.is_empty(), "Rastgele yükleme ipucu gösterilmeli")
	_expect(loading.selected_wallpaper_path in WALLPAPER_PATHS, "Yükleme duvar kağıdı listeden seçilmeli")
	_expect(music != null and music.playing, "Yükleme ekranında müzik başlamalı")

	var timeout := 3.0
	while current_scene != null and current_scene.name != "MainMenu" and timeout > 0.0:
		await create_timer(0.05).timeout
		timeout -= 0.05
	_expect(current_scene != null and current_scene.name == "MainMenu", "Threaded yükleme ana menü sahnesini açmadı")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SPLASH_LOADING_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("SPLASH_LOADING_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
