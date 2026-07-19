class_name LanguageFlagIcon extends Control

@export_enum("en", "de", "fr", "it", "es", "tr") var locale := "en":
	set(value):
		locale = value
		queue_redraw()


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(54.0, 32.0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var target_ratio := 54.0 / 32.0
	var flag_size := size
	if size.x / maxf(size.y, 1.0) > target_ratio:
		flag_size.x = size.y * target_ratio
	else:
		flag_size.y = size.x / target_ratio
	var flag_rect := Rect2((size - flag_size) * 0.5, flag_size)
	draw_rect(flag_rect, Color(0.05, 0.05, 0.06), true)
	var inset := flag_rect.grow(-2.0)
	match locale:
		"de":
			_draw_horizontal_tricolor(inset, [Color("1a1a1a"), Color("d52b1e"), Color("ffce00")])
		"fr":
			_draw_vertical_tricolor(inset, [Color("0055a4"), Color.WHITE, Color("ef4135")])
		"it":
			_draw_vertical_tricolor(inset, [Color("009246"), Color.WHITE, Color("ce2b37")])
		"es":
			_draw_spanish_flag(inset)
		"tr":
			_draw_turkish_flag(inset)
		_:
			_draw_british_flag(inset)
	draw_rect(inset, Color(1.0, 1.0, 1.0, 0.45), false, 1.0)


func _draw_horizontal_tricolor(rect: Rect2, colors: Array) -> void:
	var stripe_height := rect.size.y / 3.0
	for index in range(3):
		draw_rect(
			Rect2(rect.position + Vector2(0.0, stripe_height * index), Vector2(rect.size.x, stripe_height + 0.5)),
			colors[index] as Color,
			true
		)


func _draw_vertical_tricolor(rect: Rect2, colors: Array) -> void:
	var stripe_width := rect.size.x / 3.0
	for index in range(3):
		draw_rect(
			Rect2(rect.position + Vector2(stripe_width * index, 0.0), Vector2(stripe_width + 0.5, rect.size.y)),
			colors[index] as Color,
			true
		)


func _draw_spanish_flag(rect: Rect2) -> void:
	var band := rect.size.y * 0.25
	draw_rect(rect, Color("aa151b"), true)
	draw_rect(Rect2(rect.position + Vector2(0.0, band), Vector2(rect.size.x, rect.size.y - band * 2.0)), Color("f1bf00"), true)


func _draw_turkish_flag(rect: Rect2) -> void:
	draw_rect(rect, Color("e30a17"), true)
	var center := rect.position + Vector2(rect.size.x * 0.43, rect.size.y * 0.5)
	var radius := rect.size.y * 0.28
	draw_circle(center, radius, Color.WHITE)
	draw_circle(center + Vector2(radius * 0.36, 0.0), radius * 0.80, Color("e30a17"))
	_draw_star(center + Vector2(radius * 1.35, 0.0), radius * 0.52, Color.WHITE)


func _draw_british_flag(rect: Rect2) -> void:
	draw_rect(rect, Color("012169"), true)
	var diagonal_width := maxf(3.0, rect.size.y * 0.18)
	draw_line(rect.position, rect.end, Color.WHITE, diagonal_width)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color.WHITE, diagonal_width)
	draw_line(rect.position, rect.end, Color("c8102e"), diagonal_width * 0.42)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color("c8102e"), diagonal_width * 0.42)
	var cross_width := maxf(5.0, rect.size.y * 0.32)
	draw_rect(Rect2(Vector2(rect.position.x, rect.get_center().y - cross_width * 0.5), Vector2(rect.size.x, cross_width)), Color.WHITE, true)
	draw_rect(Rect2(Vector2(rect.get_center().x - cross_width * 0.5, rect.position.y), Vector2(cross_width, rect.size.y)), Color.WHITE, true)
	var red_width := cross_width * 0.55
	draw_rect(Rect2(Vector2(rect.position.x, rect.get_center().y - red_width * 0.5), Vector2(rect.size.x, red_width)), Color("c8102e"), true)
	draw_rect(Rect2(Vector2(rect.get_center().x - red_width * 0.5, rect.position.y), Vector2(red_width, rect.size.y)), Color("c8102e"), true)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(10):
		var point_radius := radius if index % 2 == 0 else radius * 0.42
		var angle := -PI * 0.5 + (TAU * float(index) / 10.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
	draw_colored_polygon(points, color)
