extends SceneTree

const SPLASH_OUTPUT := "/tmp/tdm_splash_screen.png"
const LOADING_OUTPUT := "/tmp/tdm_loading_screen.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var splash_scene := load("res://splash_screen.tscn") as PackedScene
	var splash := splash_scene.instantiate()
	root.add_child(splash)
	current_scene = splash
	await create_timer(2.4).timeout
	_capture(SPLASH_OUTPUT)
	splash.free()
	await process_frame

	var scene_transition := root.get_node("SceneTransition")
	scene_transition.target_scene_path = "res://battlefield.tscn"
	scene_transition.minimum_screen_time = 10.0
	scene_transition.transition_active = true
	var loading_scene := load("res://loading_screen.tscn") as PackedScene
	var loading := loading_scene.instantiate()
	root.add_child(loading)
	current_scene = loading
	await create_timer(0.75).timeout
	_capture(LOADING_OUTPUT)
	print("SPLASH_LOADING_VISUAL_CAPTURE_OK")
	quit(0)


func _capture(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Görsel yakalanamadı: %s" % path)
		return
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("Görsel kaydedilemedi: %s" % path)
