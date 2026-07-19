class_name TopAlignedCardArt extends TextureRect

## Card art uses a cover crop whose vertical focal point is the top edge. This
## keeps faces, helmets, towers, and roofs visible while still filling the
## complete artwork window.
@export var source_texture: Texture2D:
	set(value):
		source_texture = value
		queue_redraw()

func _ready() -> void:
	# TextureRect's built-in drawing stays disabled; _draw() applies the custom
	# top-aligned crop. The stretch mode still records the intended cover policy.
	texture = null
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func get_visible_source_rect() -> Rect2:
	if not source_texture or size.x <= 0.0 or size.y <= 0.0:
		return Rect2()

	var texture_size := source_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()

	var target_aspect := size.x / size.y
	var source_aspect := texture_size.x / texture_size.y
	if source_aspect > target_aspect:
		var visible_width := texture_size.y * target_aspect
		return Rect2(
			Vector2((texture_size.x - visible_width) * 0.5, 0.0),
			Vector2(visible_width, texture_size.y)
		)

	# Portrait art is cropped only at the bottom so its upper focal area remains.
	var visible_height := texture_size.x / target_aspect
	return Rect2(Vector2.ZERO, Vector2(texture_size.x, visible_height))

func _draw() -> void:
	var source_rect := get_visible_source_rect()
	if source_rect.size == Vector2.ZERO:
		return

	draw_texture_rect_region(
		source_texture,
		Rect2(Vector2.ZERO, size),
		source_rect,
		Color.WHITE,
		false,
		true
	)
