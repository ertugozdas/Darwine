class_name TopAlignedCardArt extends TextureRect

## Card art uses a cover crop whose vertical focal point can be tuned per card
## type (0.12 for hero portraits so faces/helmets stay visible; 0.38-0.46 for
## settlements, skills and spells so the central subject is never cut in half).
@export var source_texture: Texture2D:
	set(value):
		source_texture = value
		queue_redraw()

@export_range(0.0, 1.0, 0.01) var vertical_focus: float = 0.14:
	set(value):
		vertical_focus = clampf(value, 0.0, 1.0)
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

	# Portrait art uses vertical_focus to keep faces or central subjects framed.
	var visible_height := texture_size.x / target_aspect
	var max_offset := maxf(0.0, texture_size.y - visible_height)
	return Rect2(Vector2(0.0, max_offset * vertical_focus), Vector2(texture_size.x, visible_height))

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
