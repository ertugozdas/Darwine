extends Control

enum IconType { SWORD, SHIELD, HEART, MAGIC, BURST, TARGET, LIGHTNING, HOURGLASS }

var icon_type: IconType = IconType.SWORD:
	set(value):
		icon_type = value
		queue_redraw()

var accent_override := Color.TRANSPARENT:
	set(value):
		accent_override = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var drawing_size := minf(size.x, size.y)
	if drawing_size <= 0.0:
		return

	var scale_factor := drawing_size / 18.0
	var origin := (size - Vector2.ONE * 16.0 * scale_factor) * 0.5
	var palette := _get_icon_palette()
	if accent_override.a > 0.0:
		palette["accent"] = accent_override
	var dark: Color = palette.get("dark", Color(0.10, 0.08, 0.06, 0.96))
	var accent: Color = palette.get("accent", Color(0.94, 0.78, 0.45, 0.92))
	match icon_type:
		IconType.SWORD:
			_draw_sword(origin, scale_factor, dark, accent)
		IconType.SHIELD:
			_draw_shield(origin, scale_factor, dark, accent)
		IconType.HEART:
			_draw_heart(origin, scale_factor, dark, accent)
		IconType.MAGIC:
			_draw_magic(origin, scale_factor, dark, accent)
		IconType.BURST:
			_draw_burst(origin, scale_factor, dark, accent)
		IconType.TARGET:
			_draw_target(origin, scale_factor, dark, accent)
		IconType.LIGHTNING:
			_draw_lightning(origin, scale_factor, dark, accent)
		IconType.HOURGLASS:
			_draw_hourglass(origin, scale_factor, dark, accent)

func _get_icon_palette() -> Dictionary:
	match icon_type:
		IconType.SWORD:
			return {"dark": Color(0.08, 0.10, 0.13, 0.98), "accent": Color(0.82, 0.91, 1.0, 0.96)}
		IconType.SHIELD:
			return {"dark": Color(0.06, 0.15, 0.24, 0.98), "accent": Color(0.32, 0.78, 1.0, 0.96)}
		IconType.HEART:
			return {"dark": Color(0.25, 0.035, 0.045, 0.98), "accent": Color(1.0, 0.30, 0.32, 0.98)}
		IconType.MAGIC:
			return {"dark": Color(0.16, 0.06, 0.24, 0.98), "accent": Color(0.75, 0.45, 1.0, 0.98)}
		IconType.BURST:
			return {"dark": Color(0.25, 0.11, 0.025, 0.98), "accent": Color(1.0, 0.67, 0.16, 0.98)}
		IconType.TARGET:
			return {"dark": Color(0.24, 0.035, 0.03, 0.98), "accent": Color(1.0, 0.32, 0.20, 0.98)}
		IconType.LIGHTNING:
			return {"dark": Color(0.22, 0.13, 0.02, 0.98), "accent": Color(1.0, 0.82, 0.22, 0.98)}
		IconType.HOURGLASS:
			return {"dark": Color(0.08, 0.10, 0.08, 0.98), "accent": Color(0.36, 0.88, 0.48, 0.98)}
	return {}

func _draw_sword(origin: Vector2, scale_factor: float, dark: Color, accent: Color) -> void:
	var pommel := origin + Vector2(3.0, 13.0) * scale_factor
	var tip := origin + Vector2(13.0, 3.0) * scale_factor
	var direction := pommel.direction_to(tip)
	var normal := Vector2(-direction.y, direction.x)
	var blade := PackedVector2Array([
		tip,
		pommel + direction * 3.2 * scale_factor + normal * 1.15 * scale_factor,
		pommel + direction * 1.7 * scale_factor,
		pommel + direction * 3.2 * scale_factor - normal * 1.15 * scale_factor,
	])
	draw_polygon(blade, PackedColorArray([accent.darkened(0.12)]))
	var blade_outline := blade.duplicate()
	blade_outline.append(blade[0])
	draw_polyline(blade_outline, dark, 1.15 * scale_factor, true)
	draw_line(pommel + direction * 4.0 * scale_factor, tip - direction * 1.5 * scale_factor, accent.lightened(0.38), 0.7 * scale_factor, true)
	draw_line(
		origin + Vector2(4.0, 8.0) * scale_factor,
		origin + Vector2(8.0, 12.0) * scale_factor,
		Color(0.93, 0.68, 0.25, 1.0),
		2.4 * scale_factor,
		true
	)
	draw_circle(pommel, 1.55 * scale_factor, dark, true)
	draw_circle(pommel, 0.72 * scale_factor, Color(0.98, 0.73, 0.27, 1.0), true)

func _draw_shield(origin: Vector2, scale_factor: float, dark: Color, accent: Color) -> void:
	var points := PackedVector2Array([
		origin + Vector2(8.0, 1.5) * scale_factor,
		origin + Vector2(13.5, 4.0) * scale_factor,
		origin + Vector2(12.5, 10.5) * scale_factor,
		origin + Vector2(8.0, 14.5) * scale_factor,
		origin + Vector2(3.5, 10.5) * scale_factor,
		origin + Vector2(2.5, 4.0) * scale_factor,
	])
	draw_polygon(points, PackedColorArray([accent.darkened(0.52)]))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, accent, 1.35 * scale_factor, true)
	draw_line(origin + Vector2(8.0, 3.1) * scale_factor, origin + Vector2(8.0, 12.5) * scale_factor, accent.lightened(0.36), 0.9 * scale_factor, true)
	draw_line(origin + Vector2(4.5, 6.0) * scale_factor, origin + Vector2(11.5, 6.0) * scale_factor, Color(accent, 0.72), 0.75 * scale_factor, true)

func _draw_heart(origin: Vector2, scale_factor: float, dark: Color, accent: Color) -> void:
	var points := PackedVector2Array([
		origin + Vector2(8.0, 14.5) * scale_factor,
		origin + Vector2(2.0, 8.5) * scale_factor,
		origin + Vector2(2.0, 4.5) * scale_factor,
		origin + Vector2(5.0, 2.0) * scale_factor,
		origin + Vector2(8.0, 5.0) * scale_factor,
		origin + Vector2(11.0, 2.0) * scale_factor,
		origin + Vector2(14.0, 4.5) * scale_factor,
		origin + Vector2(14.0, 8.5) * scale_factor,
	])
	draw_polygon(points, PackedColorArray([accent.darkened(0.38)]))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, dark, 1.25 * scale_factor, true)
	draw_line(origin + Vector2(4.1, 4.7) * scale_factor, origin + Vector2(6.5, 3.6) * scale_factor, accent.lightened(0.44), 1.0 * scale_factor, true)

func _draw_magic(origin: Vector2, scale_factor: float, dark: Color, accent: Color) -> void:
	var points := PackedVector2Array([
		origin + Vector2(8.0, 1.0) * scale_factor,
		origin + Vector2(10.0, 6.0) * scale_factor,
		origin + Vector2(15.0, 8.0) * scale_factor,
		origin + Vector2(10.0, 10.0) * scale_factor,
		origin + Vector2(8.0, 15.0) * scale_factor,
		origin + Vector2(6.0, 10.0) * scale_factor,
		origin + Vector2(1.0, 8.0) * scale_factor,
		origin + Vector2(6.0, 6.0) * scale_factor,
	])
	draw_polygon(points, PackedColorArray([accent.darkened(0.54)]))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, accent, 1.2 * scale_factor, true)
	draw_circle(origin + Vector2(8.0, 8.0) * scale_factor, 2.1 * scale_factor, Color(accent.lightened(0.42), 0.88), true)

func _draw_burst(origin: Vector2, scale_factor: float, dark: Color, accent: Color) -> void:
	var center := origin + Vector2(8.0, 8.0) * scale_factor
	draw_circle(center, 3.2 * scale_factor, dark, true)
	draw_circle(center, 2.0 * scale_factor, accent.lightened(0.16), true)
	for direction in [
		Vector2(0.0, -1.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0),
		Vector2(-0.707, -0.707), Vector2(0.707, -0.707), Vector2(-0.707, 0.707), Vector2(0.707, 0.707),
	]:
		draw_line(center + direction * 4.3 * scale_factor, center + direction * 7.3 * scale_factor, accent, 1.5 * scale_factor, true)

func _draw_target(origin: Vector2, scale_factor: float, dark: Color, accent: Color) -> void:
	var center := origin + Vector2(8.0, 8.0) * scale_factor
	draw_arc(center, 6.0 * scale_factor, 0.0, TAU, 24, dark, 2.0 * scale_factor, true)
	draw_arc(center, 5.2 * scale_factor, 0.0, TAU, 24, accent, 1.0 * scale_factor, true)
	draw_circle(center, 2.2 * scale_factor, accent.lightened(0.18), true)
	draw_line(center + Vector2(-8.0, 0.0) * scale_factor, center + Vector2(-4.0, 0.0) * scale_factor, accent, 1.0 * scale_factor, true)
	draw_line(center + Vector2(4.0, 0.0) * scale_factor, center + Vector2(8.0, 0.0) * scale_factor, accent, 1.0 * scale_factor, true)
	draw_line(center + Vector2(0.0, -8.0) * scale_factor, center + Vector2(0.0, -4.0) * scale_factor, accent, 1.0 * scale_factor, true)
	draw_line(center + Vector2(0.0, 4.0) * scale_factor, center + Vector2(0.0, 8.0) * scale_factor, accent, 1.0 * scale_factor, true)

func _draw_lightning(origin: Vector2, scale_factor: float, dark: Color, accent: Color) -> void:
	var points := PackedVector2Array([
		origin + Vector2(9.2, 0.8) * scale_factor,
		origin + Vector2(3.0, 8.8) * scale_factor,
		origin + Vector2(7.2, 8.8) * scale_factor,
		origin + Vector2(5.2, 15.4) * scale_factor,
		origin + Vector2(13.4, 6.4) * scale_factor,
		origin + Vector2(9.3, 6.4) * scale_factor,
	])
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polygon(points, PackedColorArray([accent.lightened(0.08)]))
	draw_polyline(outline, dark, 1.5 * scale_factor, true)
	draw_line(
		origin + Vector2(8.8, 2.5) * scale_factor,
		origin + Vector2(5.1, 8.0) * scale_factor,
		accent.lightened(0.34),
		0.8 * scale_factor,
		true
	)


func _draw_hourglass(origin: Vector2, scale_factor: float, dark: Color, accent: Color) -> void:
	var top_left := origin + Vector2(3.0, 1.8) * scale_factor
	var top_right := origin + Vector2(13.0, 1.8) * scale_factor
	var bottom_left := origin + Vector2(3.0, 14.2) * scale_factor
	var bottom_right := origin + Vector2(13.0, 14.2) * scale_factor
	draw_line(top_left, top_right, dark, 2.8 * scale_factor, true)
	draw_line(bottom_left, bottom_right, dark, 2.8 * scale_factor, true)
	draw_line(top_left + Vector2(1.0, 1.0) * scale_factor, bottom_right - Vector2(1.0, 1.0) * scale_factor, accent, 1.25 * scale_factor, true)
	draw_line(top_right + Vector2(-1.0, 1.0) * scale_factor, bottom_left + Vector2(1.0, -1.0) * scale_factor, accent, 1.25 * scale_factor, true)
	var upper_sand := PackedVector2Array([
		origin + Vector2(5.0, 4.0) * scale_factor,
		origin + Vector2(11.0, 4.0) * scale_factor,
		origin + Vector2(8.0, 7.2) * scale_factor,
	])
	var lower_sand := PackedVector2Array([
		origin + Vector2(8.0, 8.8) * scale_factor,
		origin + Vector2(11.0, 12.2) * scale_factor,
		origin + Vector2(5.0, 12.2) * scale_factor,
	])
	draw_colored_polygon(upper_sand, accent.lightened(0.24))
	draw_colored_polygon(lower_sand, accent.lightened(0.10))
