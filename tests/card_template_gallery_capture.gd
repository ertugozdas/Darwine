extends SceneTree

const OUTPUT_PATH := "/tmp/tdm_card_template_gallery.png"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var gallery_scene := load("res://tests/card_template_gallery.tscn") as PackedScene
	if not gallery_scene:
		push_error("Kart galerisi yüklenemedi")
		quit(1)
		return

	var gallery := gallery_scene.instantiate()
	root.add_child(gallery)
	await process_frame
	await process_frame
	await process_frame
	# Headless macOS can leave frame_post_draw pending indefinitely. Force the
	# viewport draw synchronously before reading its texture.
	RenderingServer.force_draw(false)

	var viewport_texture := root.get_viewport().get_texture()
	if viewport_texture == null:
		push_error("Kart galerisi için renderer viewport texture üretmedi")
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("Kart galerisi için renderer görüntü üretmedi")
		quit(1)
		return
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Kart galerisi kaydedilemedi: %s" % error_string(error))
		quit(1)
		return

	print("CARD_TEMPLATE_GALLERY_CAPTURED: %s" % OUTPUT_PATH)
	quit(0)
