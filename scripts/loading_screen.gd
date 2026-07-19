extends Control

const UI := preload("res://scripts/dark_fantasy_ui.gd")
const WALLPAPER_PATHS := [
	"res://images/loading/wallpaper_01_citadel.png",
	"res://images/loading/wallpaper_02_ramparts.png",
	"res://images/loading/wallpaper_03_battlefield.png",
	"res://images/loading/wallpaper_04_forge.png",
	"res://images/loading/wallpaper_05_frost_pass.png",
]
const MUSIC_PATHS := [
	"res://sounds/musics/music_1.mp3",
	"res://sounds/musics/music_2.mp3",
	"res://sounds/musics/music_3.mp3",
	"res://sounds/musics/music_4.mp3",
	"res://sounds/musics/music_5.mp3",
]
const TIPS := [
	"Ön saftaki kahramanlar savaşı taşır; destek hattını korumasız bırakma.",
	"Enerjini tek turda tüketme; sonraki hamlen için daima bir plan bırak.",
	"Yapılar uzun savaşları kazanır. Onları baskı kurduğun koridorda güvenceye al.",
	"Doğru zamanda kullanılan bir büyü, kaybedilen koridoru yeniden açabilir.",
	"Merkeze yürürken üç koridordaki baskıyı dengede tut; açık verdiğin hat hedef olur.",
]

var selected_wallpaper_path := ""
var selected_tip := ""

var _rng := RandomNumberGenerator.new()
var _target_scene_path := ""
var _minimum_screen_time := 0.0
var _elapsed := 0.0
var _request_started := false
var _transitioning := false
var _failed := false

var _background: TextureRect
var _status_label: Label
var _percentage_label: Label
var _progress_bar: ProgressBar
var _tip_label: Label
var _loading_music: AudioStreamPlayer
var _fade_overlay: ColorRect


func _ready() -> void:
	theme = UI.create_theme()
	_rng.randomize()
	_target_scene_path = SceneTransition.target_scene_path
	_minimum_screen_time = SceneTransition.minimum_screen_time
	_build_screen()
	_choose_random_content()
	_start_loading_music()
	_fade_in()
	call_deferred("_begin_loading")


func _process(delta: float) -> void:
	_elapsed += delta
	if not _request_started or _transitioning or _failed:
		return

	var progress: Array = []
	var load_status := ResourceLoader.load_threaded_get_status(_target_scene_path, progress)
	var ratio := clampf(float(progress[0]) if not progress.is_empty() else 0.0, 0.0, 1.0)
	_update_progress(ratio)

	match load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_status_label.text = "SAVAŞ ALANI HAZIRLANIYOR"
		ResourceLoader.THREAD_LOAD_LOADED:
			_update_progress(1.0)
			_status_label.text = "KAPILAR AÇILIYOR"
			if _elapsed >= _minimum_screen_time:
				_transitioning = true
				call_deferred("_complete_transition")
		ResourceLoader.THREAD_LOAD_FAILED:
			_show_error("YÜKLEME BAŞARISIZ")
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_show_error("SAHNE BULUNAMADI")


func _build_screen() -> void:
	_background = TextureRect.new()
	_background.name = "LoadingWallpaper"
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	var wash := TextureRect.new()
	wash.name = "CinematicWash"
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.texture = _make_gradient_texture(
		PackedColorArray([
			Color(0.004, 0.005, 0.007, 0.52),
			Color(0.008, 0.009, 0.012, 0.12),
			Color(0.004, 0.005, 0.007, 0.72),
			Color(0.003, 0.004, 0.006, 0.96),
		]),
		PackedFloat32Array([0.0, 0.30, 0.67, 1.0])
	)
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var title := Label.new()
	title.name = "DarwineTitle"
	title.anchor_left = 0.08
	title.anchor_top = 0.27
	title.anchor_right = 0.92
	title.anchor_bottom = 0.56
	title.text = "DARWINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI.DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 82)
	title.add_theme_color_override("font_color", UI.PARCHMENT)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
	title.add_theme_constant_override("outline_size", 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var title_rule := ColorRect.new()
	title_rule.name = "TitleRule"
	title_rule.anchor_left = 0.41
	title_rule.anchor_top = 0.535
	title_rule.anchor_right = 0.59
	title_rule.anchor_bottom = 0.535
	title_rule.offset_top = -1.0
	title_rule.offset_bottom = 1.0
	title_rule.color = Color(UI.BRASS_BRIGHT, 0.78)
	title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_rule)

	var loading_panel := VBoxContainer.new()
	loading_panel.name = "LoadingPanel"
	loading_panel.anchor_left = 0.16
	loading_panel.anchor_top = 0.70
	loading_panel.anchor_right = 0.84
	loading_panel.anchor_bottom = 0.94
	loading_panel.add_theme_constant_override("separation", 9)
	loading_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(loading_panel)

	var status_row := HBoxContainer.new()
	status_row.name = "StatusRow"
	status_row.add_theme_constant_override("separation", 12)
	loading_panel.add_child(status_row)

	_status_label = Label.new()
	_status_label.name = "LoadingStatus"
	_status_label.text = "SAVAŞ ALANI HAZIRLANIYOR"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", UI.PARCHMENT)
	status_row.add_child(_status_label)

	_percentage_label = Label.new()
	_percentage_label.name = "LoadingPercentage"
	_percentage_label.text = "0%"
	_percentage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percentage_label.custom_minimum_size.x = 56.0
	_percentage_label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_percentage_label.add_theme_font_size_override("font_size", 14)
	_percentage_label.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	status_row.add_child(_percentage_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "RealLoadingProgress"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size.y = 10.0
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.add_theme_stylebox_override("background", _make_progress_background())
	_progress_bar.add_theme_stylebox_override("fill", _make_progress_fill())
	loading_panel.add_child(_progress_bar)

	var tip_row := HBoxContainer.new()
	tip_row.name = "TipRow"
	tip_row.add_theme_constant_override("separation", 12)
	loading_panel.add_child(tip_row)

	var tip_heading := Label.new()
	tip_heading.name = "TipHeading"
	tip_heading.text = "SAVAŞ NOTU"
	tip_heading.add_theme_font_override("font", UI.DISPLAY_FONT)
	tip_heading.add_theme_font_size_override("font_size", 11)
	tip_heading.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	tip_row.add_child(tip_heading)

	_tip_label = Label.new()
	_tip_label.name = "LoadingTip"
	_tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_font_override("font", UI.BODY_FONT)
	_tip_label.add_theme_font_size_override("font_size", 13)
	_tip_label.add_theme_color_override("font_color", Color(UI.PARCHMENT, 0.84))
	tip_row.add_child(_tip_label)

	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "LoadingFade"
	_fade_overlay.z_index = 100
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color.BLACK
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)


func _choose_random_content() -> void:
	selected_wallpaper_path = WALLPAPER_PATHS[_rng.randi_range(0, WALLPAPER_PATHS.size() - 1)]
	selected_tip = TIPS[_rng.randi_range(0, TIPS.size() - 1)]
	_background.texture = load(selected_wallpaper_path) as Texture2D
	_tip_label.text = selected_tip


func _start_loading_music() -> void:
	var music_path: String = MUSIC_PATHS[_rng.randi_range(0, MUSIC_PATHS.size() - 1)]
	var music_stream := load(music_path) as AudioStream
	if music_stream == null:
		push_warning("Yükleme müziği açılamadı: %s" % music_path)
		return
	_loading_music = AudioStreamPlayer.new()
	_loading_music.name = "LoadingMusic"
	_loading_music.bus = &"Music"
	_loading_music.stream = music_stream
	add_child(_loading_music)
	_loading_music.play()


func _fade_in() -> void:
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(
		_fade_overlay,
		"color:a",
		0.0,
		0.42
	)


func _begin_loading() -> void:
	await get_tree().process_frame
	var request_error := ResourceLoader.load_threaded_request(_target_scene_path)
	if request_error != OK:
		_show_error("YÜKLEME BAŞLATILAMADI")
		push_error("Sahne yükleme isteği başarısız: %s" % error_string(request_error))
		return
	_request_started = true


func _update_progress(ratio: float) -> void:
	var percent := clampf(ratio, 0.0, 1.0) * 100.0
	_progress_bar.value = percent
	_percentage_label.text = "%d%%" % int(round(percent))


func _complete_transition() -> void:
	var packed_scene := ResourceLoader.load_threaded_get(_target_scene_path) as PackedScene
	if packed_scene == null:
		_transitioning = false
		_show_error("SAHNE AÇILAMADI")
		return

	var fade_out := create_tween()
	fade_out.set_parallel(true)
	fade_out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_out.tween_property(_fade_overlay, "color:a", 1.0, 0.28)
	if _loading_music:
		fade_out.tween_property(_loading_music, "volume_db", -28.0, 0.28)
	await fade_out.finished

	SceneTransition.mark_completed()
	var change_error := get_tree().change_scene_to_packed(packed_scene)
	if change_error != OK:
		_transitioning = false
		_show_error("SAHNE AÇILAMADI")
		push_error("Yüklenen sahne açılamadı: %s" % error_string(change_error))


func _show_error(message: String) -> void:
	_failed = true
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.34))
	_percentage_label.text = "—"


func _make_progress_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.016, 0.019, 0.92)
	style.border_color = Color(UI.BRASS, 0.46)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


func _make_progress_fill() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UI.BRASS_BRIGHT
	style.set_corner_radius_all(2)
	return style


func _make_gradient_texture(colors: PackedColorArray, offsets: PackedFloat32Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = colors
	gradient.offsets = offsets
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 512
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	return texture
