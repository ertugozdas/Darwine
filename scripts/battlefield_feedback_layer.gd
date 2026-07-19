class_name BattlefieldFeedbackLayer extends Control

const ATTACK_TELEGRAPH_SECONDS := 0.92
const ATTACK_HOLD_SECONDS := 0.20
const ATTACK_IMPACT_SECONDS := 0.62
const IMPACT_HIT := "hit"
const IMPACT_CRITICAL := "critical"
const IMPACT_BLOCKED := "blocked"
const IMPACT_ARMOR_BREAK := "armor_break"

## Draws persistent open-lane routes and short-lived attack traces. The layer
## never receives pointer input and therefore cannot obstruct card interaction.
var _open_paths: Array[Dictionary] = []
var _attack_from := Vector2.ZERO
var _attack_to := Vector2.ZERO
var _attack_color := Color(1.0, 0.72, 0.24, 1.0)
var _attack_progress := 0.0:
	set(value):
		_attack_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var _attack_alpha := 0.0:
	set(value):
		_attack_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()
var _attack_tween: Tween = null
var _impact_tween: Tween = null
var _impact_strength := 0.0:
	set(value):
		_impact_strength = clampf(value, 0.0, 1.0)
		queue_redraw()
var _impact_kind := IMPACT_HIT
var _impact_power := 1.0
var attack_animation_count := 0
var impact_animation_count := 0
var last_impact_kind := IMPACT_HIT

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# BattlefieldUI owns the clipped, correctly ordered board feedback surface.
	# Keeping this child at zero prevents its custom drawing from escaping above
	# phase banners, the hand dock, or other root-level UI chrome.
	z_index = 0
	queue_redraw()

func set_open_paths(paths: Array[Dictionary]) -> void:
	_open_paths.clear()
	for path in paths:
		_open_paths.append(path.duplicate(true))
	queue_redraw()

func get_open_path_count() -> int:
	return _open_paths.size()

func play_attack_path(from_point: Vector2, to_point: Vector2, color: Color = Color(1.0, 0.72, 0.24)) -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	_attack_from = from_point
	_attack_to = to_point
	_attack_color = color
	_attack_progress = 0.0
	_attack_alpha = 1.0
	_impact_strength = 0.0
	_impact_kind = IMPACT_HIT
	_impact_power = 1.0
	attack_animation_count += 1
	_attack_tween = create_tween().bind_node(self).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.tween_property(self, "_attack_progress", 1.0, ATTACK_TELEGRAPH_SECONDS)
	_attack_tween.tween_interval(ATTACK_HOLD_SECONDS)
	_attack_tween.tween_property(self, "_attack_alpha", 0.0, ATTACK_IMPACT_SECONDS)
	_attack_tween.tween_callback(_clear_attack_path)

func update_attack_path(from_point: Vector2, to_point: Vector2) -> void:
	if not has_active_attack_path():
		return
	_attack_from = from_point
	_attack_to = to_point
	queue_redraw()

func has_active_attack_path() -> bool:
	return _attack_alpha > 0.0 or _impact_strength > 0.0

func get_attack_path_points() -> Dictionary:
	return {
		"from": _attack_from,
		"to": _attack_to,
	}

func trigger_attack_impact(kind: String = IMPACT_HIT, power: float = 1.0) -> void:
	_set_impact_profile(kind, power)
	_attack_progress = 1.0
	_impact_strength = 1.0
	impact_animation_count += 1
	if _impact_tween and _impact_tween.is_valid():
		_impact_tween.kill()
	_impact_tween = create_tween().bind_node(self).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_impact_tween.tween_property(self, "_impact_strength", 0.0, ATTACK_IMPACT_SECONDS)

func enhance_attack_impact(kind: String, power: float = 1.0) -> void:
	_set_impact_profile(kind, power)
	# Damage resolution follows attack_declared synchronously. Refreshing the
	# profile here keeps the already-started impact in time with the hit while
	# swapping in the correct critical, defence, or armour-break language.
	_impact_strength = maxf(_impact_strength, 0.96)

func get_last_impact_kind() -> String:
	return last_impact_kind

func _set_impact_profile(kind: String, power: float) -> void:
	var normalized := kind.strip_edges().to_lower()
	if normalized not in [IMPACT_HIT, IMPACT_CRITICAL, IMPACT_BLOCKED, IMPACT_ARMOR_BREAK]:
		normalized = IMPACT_HIT
	_impact_kind = normalized
	last_impact_kind = normalized
	_impact_power = clampf(power, 0.75, 1.65)
	queue_redraw()

func stop_all_feedback() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	if _impact_tween and _impact_tween.is_valid():
		_impact_tween.kill()
	_attack_tween = null
	_impact_tween = null
	_clear_attack_path()

func _clear_attack_path() -> void:
	_attack_alpha = 0.0
	_attack_progress = 0.0
	_impact_strength = 0.0
	queue_redraw()

func _draw() -> void:
	for path in _open_paths:
		var start: Vector2 = path.get("from", Vector2.ZERO)
		var finish: Vector2 = path.get("to", Vector2.ZERO)
		var color: Color = path.get("color", Color(0.42, 0.92, 0.56, 0.42))
		_draw_dashed_route(start, finish, color, 2.2, 10.0, 7.0)
		_draw_arrow_head(start, finish, color, 8.0)

	if _attack_alpha > 0.0:
		var source_aura := _attack_color
		source_aura.a = (0.28 + (sin(_attack_progress * PI * 5.0) * 0.08)) * _attack_alpha
		draw_circle(_attack_from, 18.0 + (4.0 * _attack_progress), source_aura, false, 2.4, true)
		_draw_target_reticle(_attack_to, _attack_color, _attack_alpha, _attack_progress)
		var current_end := _attack_from.lerp(_attack_to, _attack_progress)
		var glow := _attack_color
		glow.a = 0.20 * _attack_alpha
		var core := _attack_color
		core.a = 0.96 * _attack_alpha
		var target_aura := _attack_color
		target_aura.a = (0.22 + (0.20 * _attack_progress)) * _attack_alpha
		draw_circle(_attack_to, 16.0 + 5.0 * _attack_progress, target_aura, false, 2.0, true)
		draw_circle(_attack_to, 8.0, Color(target_aura.r, target_aura.g, target_aura.b, target_aura.a * 0.75), false, 1.0, true)
		if _attack_progress > 0.0:
			draw_line(_attack_from, current_end, Color(glow.r, glow.g, glow.b, glow.a * 0.55), 17.0, true)
			draw_line(_attack_from, current_end, glow, 9.0, true)
			draw_line(_attack_from, current_end, core, 3.4, true)
			_draw_arrow_head(_attack_from, current_end, core, 12.0)
			_draw_sword_wind(_attack_from, current_end, core, _attack_progress)
			draw_circle(current_end, 6.5, core)
	if _impact_strength > 0.0:
		_draw_impact_burst()

func _draw_sword_wind(start: Vector2, finish: Vector2, color: Color, progress: float) -> void:
	var delta := finish - start
	if delta.length_squared() <= 0.01:
		return
	var direction := delta.normalized()
	var normal := Vector2(-direction.y, direction.x)
	for streak_index in range(3):
		var streak_progress := float(streak_index) / 2.0
		var offset := normal * sin(progress * TAU * 2.0 + float(streak_index) * 1.9) * (3.0 + streak_progress * 5.0)
		var tip := finish - direction * float(streak_index * 8) + offset
		var tail := tip - direction * lerpf(17.0, 42.0, streak_progress)
		var wind := color.lightened(0.30)
		wind.a = color.a * lerpf(0.66, 0.18, streak_progress)
		draw_line(tail, tip, wind, lerpf(2.4, 1.0, streak_progress), true)
	var slash := color.lightened(0.42)
	slash.a = color.a * 0.76
	var angle := direction.angle()
	draw_arc(finish - direction * 4.0, 13.0, angle - 2.15, angle - 0.50, 18, slash, 2.2, true)

func _draw_impact_burst() -> void:
	var impact := _get_impact_color()
	impact.a = _impact_strength
	var expansion := 1.0 - _impact_strength
	var radius := lerpf(10.0, 38.0 * _impact_power, expansion)
	var flash_alpha := 0.055
	if _impact_kind == IMPACT_CRITICAL:
		flash_alpha = 0.13
	elif _impact_kind == IMPACT_BLOCKED:
		flash_alpha = 0.075
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(impact.r, impact.g, impact.b, _impact_strength * flash_alpha),
		true
	)
	draw_circle(_attack_to, radius, Color(impact.r, impact.g, impact.b, impact.a * 0.25))
	draw_circle(_attack_to, radius + 6.0, impact, false, 3.0 + _impact_power, true)
	var ray_count := 18 if _impact_kind == IMPACT_CRITICAL else 12
	for direction_index in range(ray_count):
		var direction := Vector2.RIGHT.rotated(TAU * float(direction_index) / float(ray_count))
		var stagger := 7.0 if direction_index % 2 == 0 else 0.0
		draw_line(
			_attack_to + direction * 8.0,
			_attack_to + direction * (27.0 + stagger + 16.0 * expansion) * _impact_power,
			impact,
			2.8 if direction_index % 2 == 0 else 1.5,
			true
		)

	match _impact_kind:
		IMPACT_BLOCKED:
			_draw_defence_shield(_attack_to, impact, expansion)
		IMPACT_ARMOR_BREAK:
			_draw_cracks(_attack_to, impact, 1.22)
			_draw_armor_shards(_attack_to, impact, expansion)
		IMPACT_CRITICAL:
			_draw_cracks(_attack_to, impact, 1.38)
			_draw_critical_slashes(_attack_to, impact, expansion)
		_:
			_draw_cracks(_attack_to, impact, 0.84)

func _get_impact_color() -> Color:
	match _impact_kind:
		IMPACT_CRITICAL:
			return Color(1.0, 0.74, 0.16, 1.0)
		IMPACT_BLOCKED:
			return Color(0.36, 0.82, 1.0, 1.0)
		IMPACT_ARMOR_BREAK:
			return Color(0.82, 0.90, 1.0, 1.0)
		_:
			return _attack_color.lightened(0.12)

func _draw_defence_shield(center: Vector2, color: Color, expansion: float) -> void:
	var shield_scale := lerpf(0.72, 1.18, expansion) * _impact_power
	var points := PackedVector2Array([
		center + Vector2(0.0, -22.0) * shield_scale,
		center + Vector2(18.0, -13.0) * shield_scale,
		center + Vector2(15.0, 9.0) * shield_scale,
		center + Vector2(0.0, 24.0) * shield_scale,
		center + Vector2(-15.0, 9.0) * shield_scale,
		center + Vector2(-18.0, -13.0) * shield_scale,
	])
	draw_polygon(points, PackedColorArray([Color(color.r, color.g, color.b, color.a * 0.15)]))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color, 3.0, true)
	draw_line(center + Vector2(0.0, -16.0) * shield_scale, center + Vector2(0.0, 14.0) * shield_scale, Color(0.88, 0.97, 1.0, color.a * 0.78), 1.5, true)
	for ring_index in range(2):
		draw_circle(center, (31.0 + float(ring_index) * 11.0) * shield_scale, Color(color.r, color.g, color.b, color.a * (0.34 - float(ring_index) * 0.11)), false, 1.5, true)

func _draw_cracks(center: Vector2, color: Color, scale_value: float) -> void:
	for crack_index in range(7):
		var direction := Vector2.RIGHT.rotated(-2.68 + float(crack_index) * 0.84)
		var tangent := Vector2(-direction.y, direction.x)
		var start := center + direction * 7.0
		var joint := center + direction * (16.0 * scale_value) + tangent * (3.5 if crack_index % 2 == 0 else -3.5)
		var finish := center + direction * (29.0 * scale_value)
		draw_line(start, joint, color, 2.0, true)
		draw_line(joint, finish, Color(color.r, color.g, color.b, color.a * 0.72), 1.35, true)
		if crack_index % 2 == 0:
			draw_line(joint, joint + tangent * 7.0 + direction * 4.0, Color(color.r, color.g, color.b, color.a * 0.48), 1.0, true)

func _draw_armor_shards(center: Vector2, color: Color, expansion: float) -> void:
	for shard_index in range(6):
		var direction := Vector2.RIGHT.rotated(float(shard_index) * TAU / 6.0 + 0.28)
		var tangent := Vector2(-direction.y, direction.x)
		var distance := lerpf(16.0, 38.0, expansion) * _impact_power
		var shard_center := center + direction * distance
		var shard := PackedVector2Array([
			shard_center + direction * 7.0,
			shard_center - direction * 5.0 + tangent * 3.5,
			shard_center - direction * 3.0 - tangent * 3.5,
		])
		draw_polygon(shard, PackedColorArray([Color(color.r, color.g, color.b, color.a * 0.72)]))

func _draw_critical_slashes(center: Vector2, color: Color, expansion: float) -> void:
	var slash_color := Color(1.0, 0.94, 0.72, color.a)
	var reach := lerpf(26.0, 44.0, expansion) * _impact_power
	draw_line(center + Vector2(-reach, reach * 0.62), center + Vector2(reach, -reach * 0.62), slash_color, 4.4, true)
	draw_line(center + Vector2(-reach * 0.58, -reach), center + Vector2(reach * 0.58, reach), Color(color.r, color.g, color.b, color.a * 0.82), 3.0, true)

func _draw_target_reticle(center: Vector2, color: Color, alpha: float, progress: float) -> void:
	var reticle := color
	reticle.a = (0.62 + (sin(progress * PI * 4.0) * 0.16)) * alpha
	var radius := lerpf(27.0, 20.0, progress)
	draw_circle(center, radius, Color(reticle.r, reticle.g, reticle.b, reticle.a * 0.22), false, 1.5, true)
	for direction_variant in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var direction := direction_variant as Vector2
		var tangent := Vector2(-direction.y, direction.x)
		var start: Vector2 = center + direction * radius - tangent * 6.0
		var corner: Vector2 = center + direction * radius
		var finish: Vector2 = center + direction * radius + tangent * 6.0
		draw_line(start, corner, reticle, 2.4, true)
		draw_line(corner, finish, reticle, 2.4, true)

func _draw_dashed_route(
	start: Vector2,
	finish: Vector2,
	color: Color,
	width: float,
	dash_length: float,
	gap_length: float
) -> void:
	var distance := start.distance_to(finish)
	if distance <= 0.01:
		return
	var direction := (finish - start) / distance
	var cursor := 0.0
	while cursor < distance:
		var segment_end := minf(distance, cursor + dash_length)
		draw_line(start + direction * cursor, start + direction * segment_end, color, width, true)
		cursor += dash_length + gap_length

func _draw_arrow_head(start: Vector2, finish: Vector2, color: Color, size: float) -> void:
	var delta := finish - start
	if delta.length_squared() <= 0.01:
		return
	var direction := delta.normalized()
	var normal := Vector2(-direction.y, direction.x)
	var tip := finish
	var base := finish - direction * size
	draw_line(tip, base + normal * size * 0.55, color, 2.2, true)
	draw_line(tip, base - normal * size * 0.55, color, 2.2, true)
