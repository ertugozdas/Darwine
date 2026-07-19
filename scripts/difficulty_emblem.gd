class_name DifficultyEmblem
extends Control

## Lightweight vector emblems for the opponent difficulty cards.  Drawing them
## in-engine keeps the three colors crisp at every menu scale and consistent
## with the forged UI treatment.

enum EmblemType { SHIELD, CROSSED_SWORDS, CROWN }

@export var emblem_type: EmblemType = EmblemType.SHIELD:
	set(value):
		emblem_type = value
		queue_redraw()

@export var accent_color := Color(0.72, 0.52, 0.24):
	set(value):
		accent_color = value
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

	var scale_factor := drawing_size / 72.0
	var origin := (size - Vector2.ONE * 72.0 * scale_factor) * 0.5
	var center := origin + Vector2(36.0, 36.0) * scale_factor
	var halo := Color(accent_color, 0.10)
	draw_circle(center, 31.0 * scale_factor, halo)
	draw_circle(center, 30.0 * scale_factor, Color(accent_color, 0.62), false, 1.3 * scale_factor, true)
	draw_circle(center, 24.5 * scale_factor, Color(accent_color, 0.22), false, 0.8 * scale_factor, true)

	match emblem_type:
		EmblemType.SHIELD:
			_draw_shield(origin, scale_factor)
		EmblemType.CROSSED_SWORDS:
			_draw_crossed_swords(origin, scale_factor)
		EmblemType.CROWN:
			_draw_crown(origin, scale_factor)


func _draw_shield(origin: Vector2, scale_factor: float) -> void:
	var shield := PackedVector2Array([
		origin + Vector2(36.0, 14.0) * scale_factor,
		origin + Vector2(54.0, 21.0) * scale_factor,
		origin + Vector2(51.0, 43.0) * scale_factor,
		origin + Vector2(36.0, 57.0) * scale_factor,
		origin + Vector2(21.0, 43.0) * scale_factor,
		origin + Vector2(18.0, 21.0) * scale_factor,
	])
	draw_polygon(shield, PackedColorArray([Color(accent_color, 0.20)]))
	var outline := shield.duplicate()
	outline.append(shield[0])
	draw_polyline(outline, accent_color, 2.0 * scale_factor, true)
	draw_line(
		origin + Vector2(36.0, 20.0) * scale_factor,
		origin + Vector2(36.0, 48.0) * scale_factor,
		Color(accent_color, 0.72),
		1.2 * scale_factor,
		true
	)
	draw_line(
		origin + Vector2(28.0, 31.0) * scale_factor,
		origin + Vector2(44.0, 31.0) * scale_factor,
		Color(accent_color, 0.72),
		1.2 * scale_factor,
		true
	)


func _draw_crossed_swords(origin: Vector2, scale_factor: float) -> void:
	var dark := Color(0.05, 0.04, 0.035, 0.94)
	var blade_color := Color(accent_color, 0.94)
	var first_pommel := origin + Vector2(22.0, 51.0) * scale_factor
	var first_tip := origin + Vector2(50.0, 19.0) * scale_factor
	var second_pommel := origin + Vector2(50.0, 51.0) * scale_factor
	var second_tip := origin + Vector2(22.0, 19.0) * scale_factor
	for blade in [[first_pommel, first_tip], [second_pommel, second_tip]]:
		draw_line(blade[0], blade[1], dark, 4.4 * scale_factor, true)
		draw_line(blade[0], blade[1], blade_color, 1.45 * scale_factor, true)
		draw_circle(blade[0], 2.3 * scale_factor, Color(accent_color, 0.56))

	draw_line(
		origin + Vector2(16.0, 43.0) * scale_factor,
		origin + Vector2(28.0, 54.0) * scale_factor,
		blade_color,
		2.0 * scale_factor,
		true
	)
	draw_line(
		origin + Vector2(44.0, 54.0) * scale_factor,
		origin + Vector2(56.0, 43.0) * scale_factor,
		blade_color,
		2.0 * scale_factor,
		true
	)
	draw_circle(origin + Vector2(36.0, 35.0) * scale_factor, 3.2 * scale_factor, Color(accent_color, 0.24))


func _draw_crown(origin: Vector2, scale_factor: float) -> void:
	var crown := PackedVector2Array([
		origin + Vector2(18.0, 45.0) * scale_factor,
		origin + Vector2(21.0, 22.0) * scale_factor,
		origin + Vector2(30.0, 33.0) * scale_factor,
		origin + Vector2(36.0, 16.0) * scale_factor,
		origin + Vector2(42.0, 33.0) * scale_factor,
		origin + Vector2(51.0, 22.0) * scale_factor,
		origin + Vector2(54.0, 45.0) * scale_factor,
	])
	draw_polygon(crown, PackedColorArray([Color(accent_color, 0.20)]))
	var outline := crown.duplicate()
	outline.append(crown[0])
	draw_polyline(outline, accent_color, 2.0 * scale_factor, true)
	draw_line(
		origin + Vector2(18.0, 45.0) * scale_factor,
		origin + Vector2(54.0, 45.0) * scale_factor,
		accent_color,
		3.2 * scale_factor,
		true
	)
	draw_circle(origin + Vector2(36.0, 44.5) * scale_factor, 3.0 * scale_factor, Color(accent_color, 0.66))
