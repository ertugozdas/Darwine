class_name BattlefieldArenaOverlay extends Control

const UI := preload("res://scripts/dark_fantasy_ui.gd")

var _playfield_right := 1000.0
var _top_reserved := 100.0
var _divider_y := 360.0
var _board_rect := Rect2()
var _platform_rect := Rect2()
var _board_view_rect := Rect2()
var _player_zone_rects: Dictionary = {}
var _team_standard_centers: Dictionary = {}
var _perspective_player_id := 1
var _active_player_id := 0
var _turn_time_ratio := 1.0
var _turn_timer_running := false
var _pulse_phase := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if _active_player_id not in GameRules.PLAYER_IDS:
		return
	_pulse_phase = fmod(_pulse_phase + delta, TAU * 4.0)
	queue_redraw()


func configure(
	playfield_right: float,
	top_reserved: float,
	divider_y: float,
	board_rect: Rect2 = Rect2(),
	platform_rect: Rect2 = Rect2(),
	board_view_rect: Rect2 = Rect2(),
	player_one_rect: Rect2 = Rect2(),
	player_two_rect: Rect2 = Rect2(),
	team_standard_centers: Dictionary = {}
) -> void:
	_playfield_right = maxf(1.0, playfield_right)
	_top_reserved = maxf(0.0, top_reserved)
	_divider_y = clampf(divider_y, _top_reserved, size.y)
	if board_rect.size.x > 0.0 and board_rect.size.y > 0.0:
		_board_rect = board_rect
		_platform_rect = platform_rect if platform_rect.size.x > 0.0 and platform_rect.size.y > 0.0 else board_rect
	if board_view_rect.size.x > 0.0 and board_view_rect.size.y > 0.0:
		_board_view_rect = board_view_rect
	if player_one_rect.size.x > 0.0 and player_one_rect.size.y > 0.0:
		_player_zone_rects[1] = player_one_rect
	if player_two_rect.size.x > 0.0 and player_two_rect.size.y > 0.0:
		_player_zone_rects[2] = player_two_rect
	_team_standard_centers.clear()
	for player_id in GameRules.PLAYER_IDS:
		var center: Variant = team_standard_centers.get(player_id)
		if center is Vector2:
			_team_standard_centers[player_id] = center
	queue_redraw()


func set_turn_state(active_player_id: int, time_ratio: float = 1.0, is_running: bool = true) -> void:
	_active_player_id = active_player_id if active_player_id in GameRules.PLAYER_IDS else 0
	_turn_time_ratio = clampf(time_ratio, 0.0, 1.0)
	_turn_timer_running = is_running
	queue_redraw()


func set_perspective_player(player_id: int) -> void:
	_perspective_player_id = player_id if player_id in GameRules.PLAYER_IDS else 1
	queue_redraw()


func _get_team_accent(player_id: int) -> Color:
	return UI.TEAM_PLAYER if player_id == _perspective_player_id else UI.TEAM_OPPONENT


func _draw() -> void:
	var right := minf(_playfield_right, size.x)
	if right <= 1.0 or size.y <= 1.0:
		return

	var arena_top := minf(_top_reserved, size.y)
	var divider_y := clampf(_divider_y, arena_top, size.y)
	var arena_rect := Rect2(0.0, arena_top, right, maxf(0.0, size.y - arena_top))
	# The backdrop is the battlefield. This layer only gives the terrain a soft
	# tactical read; it deliberately avoids putting a second opaque board on top.
	draw_rect(Rect2(0.0, arena_top, right, 34.0), Color(0.0, 0.0, 0.0, 0.16))
	draw_rect(Rect2(0.0, size.y - 42.0, right, 42.0), Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(Rect2(0.0, arena_top, 28.0, arena_rect.size.y), Color(0.0, 0.0, 0.0, 0.11))
	draw_rect(Rect2(right - 30.0, arena_top, 30.0, arena_rect.size.y), Color(0.0, 0.0, 0.0, 0.14))
	var upper_height := maxf(0.0, divider_y - arena_top)
	var lower_height := maxf(0.0, size.y - divider_y)
	# Opposing temperature washes reinforce the two armies without masking the
	# hand-painted terrain beneath them.
	for band_index in range(5):
		var band_progress := float(band_index) / 5.0
		var band_alpha := lerpf(0.060, 0.012, band_progress)
		draw_rect(
			Rect2(0.0, arena_top + upper_height * band_progress, right, upper_height / 5.0 + 1.0),
			Color(UI.TEAM_OPPONENT, band_alpha)
		)
		draw_rect(
			Rect2(0.0, divider_y + lower_height * (1.0 - band_progress - 0.2), right, lower_height / 5.0 + 1.0),
			Color(UI.TEAM_PLAYER, band_alpha)
		)

	var no_mans_land := Rect2(0.0, divider_y - 32.0, right, 64.0)
	draw_rect(no_mans_land, Color(0.025, 0.021, 0.019, 0.16))
	draw_line(
		Vector2(0.0, divider_y - 31.0),
		Vector2(right, divider_y - 31.0),
		Color(UI.TEAM_OPPONENT, 0.18),
		1.0,
		true
	)
	draw_line(
		Vector2(0.0, divider_y + 31.0),
		Vector2(right, divider_y + 31.0),
		Color(UI.TEAM_PLAYER, 0.18),
		1.0,
		true
	)

	if _board_rect.size.x > 0.0 and _board_rect.size.y > 0.0:
		var platform := _platform_rect.grow(12.0).intersection(arena_rect)
		draw_rect(platform, Color(0.025, 0.022, 0.017, 0.055), true)
		draw_rect(platform, Color(0.63, 0.48, 0.26, 0.10), false, 1.0, true)

		var clipped_board := _board_rect.intersection(arena_rect)
		var lane_width := clipped_board.size.x / 3.0
		for lane_index in range(3):
			var lane_center_x := clipped_board.position.x + lane_width * (float(lane_index) + 0.5)
			var trail := _build_natural_trail(
				lane_center_x,
				clipped_board.position.y + 5.0,
				clipped_board.end.y - 5.0,
				lane_width * 0.075,
				lane_index
			)
			# Broad soil and trampled-grass strokes keep routes legible without
			# turning the scene into three rigid UI columns.
			draw_polyline(trail, Color(0.020, 0.016, 0.011, 0.23), lane_width * 0.34, true)
			draw_polyline(trail, Color(0.19, 0.14, 0.075, 0.15), lane_width * 0.24, true)
			draw_polyline(trail, Color(0.54, 0.42, 0.23, 0.15), 1.35, true)
			_draw_trail_markers(trail, lane_index)

	var center_x := _board_rect.get_center().x if _board_rect.size.x > 0.0 else right * 0.54
	var center := Vector2(center_x, divider_y)
	var front_line := PackedVector2Array()
	var line_left := _board_rect.position.x if _board_rect.size.x > 0.0 else 32.0
	var line_right := _board_rect.end.x if _board_rect.size.x > 0.0 else right - 32.0
	for point_index in range(15):
		var progress := float(point_index) / 14.0
		var line_x := lerpf(line_left, line_right, progress)
		var line_y := divider_y + sin(progress * TAU * 2.35 + 0.7) * 3.5
		front_line.append(Vector2(line_x, line_y))
	draw_polyline(front_line, Color(0.015, 0.012, 0.009, 0.34), 5.0, true)
	draw_polyline(front_line, Color(0.68, 0.50, 0.25, 0.19), 1.0, true)

	draw_circle(center, 31.0, Color(0.02, 0.018, 0.015, 0.23))
	draw_circle(center, 31.0, Color(0.78, 0.57, 0.25, 0.15), false, 1.0, true)
	draw_circle(center, 23.0, Color(0.78, 0.57, 0.25, 0.085), false, 1.0, true)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -14.0),
		center + Vector2(14.0, 0.0),
		center + Vector2(0.0, 14.0),
		center + Vector2(-14.0, 0.0),
		center + Vector2(0.0, -14.0),
	])
	draw_polyline(diamond, Color(0.88, 0.68, 0.34, 0.20), 1.0, true)

	var stable_view := _board_view_rect if _board_view_rect.size.x > 0.0 else arena_rect
	var standard_centers := get_team_standard_centers()
	var opponent_player_id := 2 if _perspective_player_id == 1 else 1
	_draw_team_standard(
		standard_centers[opponent_player_id],
		UI.TEAM_OPPONENT,
		1.0
	)
	_draw_team_standard(
		standard_centers[_perspective_player_id],
		UI.TEAM_PLAYER,
		-1.0
	)

	if _turn_timer_running and _active_player_id in GameRules.PLAYER_IDS:
		var active_rect := _player_zone_rects.get(_active_player_id, Rect2()) as Rect2
		if active_rect.size.x > 0.0 and active_rect.size.y > 0.0:
			var clipped_active_rect := active_rect.intersection(stable_view)
			if clipped_active_rect.size.x > 4.0 and clipped_active_rect.size.y > 4.0:
				_draw_fire_border(
					clipped_active_rect.grow(5.0),
					_get_team_accent(_active_player_id)
				)


func get_team_standard_centers() -> Dictionary:
	if _team_standard_centers.has(1) and _team_standard_centers.has(2):
		return _team_standard_centers.duplicate()
	var stable_view := (
		_board_view_rect
		if _board_view_rect.size.x > 0.0 and _board_view_rect.size.y > 0.0
		else Rect2(0.0, _top_reserved, _playfield_right, maxf(1.0, size.y - _top_reserved))
	)
	# Fallback used before the battlefield supplies its world-space anchors.
	var standard_x := clampf(stable_view.position.x + 164.0, 148.0, _playfield_right - 210.0)
	var opponent_player_id := 2 if _perspective_player_id == 1 else 1
	return {
		_perspective_player_id: Vector2(standard_x, stable_view.position.y + stable_view.size.y * 0.75),
		opponent_player_id: Vector2(standard_x, stable_view.position.y + stable_view.size.y * 0.25),
	}


func _draw_team_standard(center: Vector2, color: Color, facing: float) -> void:
	var glow := Color(color, 0.10)
	var edge := Color(color.lightened(0.26), 0.34)
	draw_circle(center, 25.0, glow)
	draw_circle(center, 24.0, edge, false, 1.4, true)
	var tip_y := 18.0 * facing
	var shoulder_y := -9.0 * facing
	var sigil := PackedVector2Array([
		center + Vector2(0.0, tip_y),
		center + Vector2(14.0, shoulder_y),
		center + Vector2(7.0, -16.0 * facing),
		center,
		center + Vector2(-7.0, -16.0 * facing),
		center + Vector2(-14.0, shoulder_y),
		center + Vector2(0.0, tip_y),
	])
	draw_polyline(sigil, edge, 2.0, true)
	draw_line(
		center + Vector2(0.0, -13.0 * facing),
		center + Vector2(0.0, 12.0 * facing),
		Color(color.lightened(0.42), 0.30),
		1.2,
		true
	)


func _draw_fire_border(rect: Rect2, color: Color) -> void:
	var pulse := 0.5 + (sin(_pulse_phase * 3.2) * 0.5)
	var urgency := lerpf(0.86, 1.16, 1.0 - _turn_time_ratio)
	for glow_index in range(4):
		var growth := float(glow_index) * 3.0
		var alpha := (0.22 - float(glow_index) * 0.042) * urgency
		draw_rect(rect.grow(growth), Color(color, alpha), false, 5.0 - float(glow_index) * 0.8, true)
	draw_rect(rect, Color(color.lightened(0.32), 0.72 + pulse * 0.20), false, 2.1, true)

	var perimeter := maxf(1.0, (rect.size.x + rect.size.y) * 2.0)
	for spark_index in range(32):
		var distance := perimeter * float(spark_index) / 32.0
		var sample := _sample_rect_perimeter(rect, distance)
		var base: Vector2 = sample["point"]
		var outward: Vector2 = sample["normal"]
		var flicker := 0.5 + 0.5 * sin(_pulse_phase * 5.0 + float(spark_index) * 1.73)
		var flame_length := (3.0 + flicker * 7.0) * urgency
		draw_line(
			base,
			base + outward * flame_length,
			Color(color.lightened(0.38), 0.26 + flicker * 0.46),
			1.0 + flicker * 1.2,
			true
		)


func _sample_rect_perimeter(rect: Rect2, distance: float) -> Dictionary:
	var horizontal := rect.size.x
	var vertical := rect.size.y
	var wrapped := fposmod(distance, maxf(1.0, (horizontal + vertical) * 2.0))
	if wrapped < horizontal:
		return {"point": rect.position + Vector2(wrapped, 0.0), "normal": Vector2.UP}
	wrapped -= horizontal
	if wrapped < vertical:
		return {"point": Vector2(rect.end.x, rect.position.y + wrapped), "normal": Vector2.RIGHT}
	wrapped -= vertical
	if wrapped < horizontal:
		return {"point": Vector2(rect.end.x - wrapped, rect.end.y), "normal": Vector2.DOWN}
	wrapped -= horizontal
	return {"point": Vector2(rect.position.x, rect.end.y - wrapped), "normal": Vector2.LEFT}


func _build_natural_trail(
	center_x: float,
	top_y: float,
	bottom_y: float,
	amplitude: float,
	lane_index: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var phase := float(lane_index) * 1.77 + 0.35
	for point_index in range(17):
		var progress := float(point_index) / 16.0
		var y := lerpf(top_y, bottom_y, progress)
		var primary_wobble := sin(progress * TAU * 1.45 + phase) * amplitude
		var secondary_wobble := sin(progress * TAU * 3.1 + phase * 0.6) * amplitude * 0.32
		points.append(Vector2(center_x + primary_wobble + secondary_wobble, y))
	return points


func _draw_trail_markers(trail: PackedVector2Array, lane_index: int) -> void:
	for marker_index in [3, 7, 11, 14]:
		if marker_index >= trail.size():
			continue
		var point := trail[marker_index]
		var side := -1.0 if (marker_index + lane_index) % 2 == 0 else 1.0
		var offset := Vector2(side * (13.0 + lane_index * 2.0), float((marker_index % 3) - 1) * 3.0)
		var marker_center := point + offset
		draw_circle(marker_center, 3.0 + float((marker_index + lane_index) % 2), Color(0.08, 0.075, 0.064, 0.42))
		draw_circle(marker_center, 3.0 + float((marker_index + lane_index) % 2), Color(0.58, 0.49, 0.34, 0.16), false, 1.0, true)
