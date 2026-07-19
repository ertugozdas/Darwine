extends Control

const MAIN_MENU_SCENE := "res://main_menu.tscn"
const LOGO_TEXTURE := preload("res://images/branding/studio_logo.png")
const LOGO_SOUND := preload("res://sounds/splash/splash_logo.mp3")

var _logo: TextureRect
var _logo_audio: AudioStreamPlayer
var _transition_started := false


func _ready() -> void:
	var network_manager := get_node_or_null("/root/NetworkManager")
	if network_manager and network_manager.is_dedicated_boot_requested():
		return
	_build_screen()
	call_deferred("_play_splash")


func _build_screen() -> void:
	var black := ColorRect.new()
	black.name = "BlackBackground"
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)

	_logo = TextureRect.new()
	_logo.name = "StudioLogo"
	_logo.anchor_left = 0.12
	_logo.anchor_top = 0.18
	_logo.anchor_right = 0.88
	_logo.anchor_bottom = 0.82
	_logo.texture = LOGO_TEXTURE
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_logo)

	_logo_audio = AudioStreamPlayer.new()
	_logo_audio.name = "SplashAudio"
	_logo_audio.bus = &"SFX"
	_logo_audio.stream = LOGO_SOUND
	add_child(_logo_audio)


func _play_splash() -> void:
	await get_tree().process_frame
	_logo.pivot_offset = _logo.size * 0.5
	_logo.scale = Vector2(0.68, 0.68)
	_logo_audio.play()

	var reveal := create_tween()
	reveal.set_parallel(true)
	reveal.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_logo, "scale", Vector2.ONE, 4.2)
	reveal.tween_property(_logo, "modulate:a", 1.0, 1.0)
	await reveal.finished

	if _logo_audio.playing:
		await _logo_audio.finished

	var fade := create_tween()
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_property(_logo, "modulate:a", 0.0, 0.42)
	await fade.finished
	_open_main_menu_loading_screen()


func _open_main_menu_loading_screen() -> void:
	if _transition_started:
		return
	_transition_started = true
	var transition_error := SceneTransition.transition_to(MAIN_MENU_SCENE)
	if transition_error != OK:
		_transition_started = false
