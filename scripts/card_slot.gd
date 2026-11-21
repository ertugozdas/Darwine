class_name CardSlot extends Panel

const UI := preload("res://scripts/dark_fantasy_ui.gd")

## Group name used to discover every playable board slot.
const GROUP_NAME := "card_slots"

# Each slot owns a compact Z band. Card art, labels, icons, and slot badges
# stay within this band, so one card cannot draw only part of itself above the
# next card in the board order.
const Z_INDEX_STRIDE := 4
const CONTENT_Z_INDEX := Z_INDEX_STRIDE - 1

signal occupancy_changed(slot: CardSlot)

enum Lane { LEFT, CENTER, RIGHT, NONE }
enum PositionType { FRONT, BACK, STRUCTURE, HQ }
enum CombatHighlight { NONE, ATTACKER, TARGET, SUPPORT_TARGET, MOVE_TARGET, INELIGIBLE }

@export_group("Slot Configuration")
@export var lane_id: Lane = Lane.LEFT
@export var position_type: PositionType = PositionType.FRONT
@export var owner_id: int = 1
@export var is_hq_slot: bool = false

@export_group("Slot Colors")
@export var normal_color: Color = Color(0.15, 0.15, 0.17, 0.5)
@export var hover_highlight_color: Color = Color(0.3, 0.45, 0.7, 0.4)
@export var border_color: Color = Color(0.4, 0.4, 0.45, 0.3)
@export var border_highlight_color: Color = Color(0.4, 0.7, 1.0, 0.8)
@export var open_lane_border_color: Color = Color(0.34, 0.58, 0.36, 0.82)
@export var attacker_highlight_color: Color = Color(0.94, 0.72, 0.30, 1.0)
@export var target_highlight_color: Color = Color(1.0, 0.30, 0.20, 1.0)
@export var support_highlight_color: Color = Color(0.35, 0.94, 0.67, 1.0)
@export var move_highlight_color: Color = Color(0.35, 0.76, 1.0, 1.0)

var is_occupied: bool = false
var occupied_card: Control = null
var card_visual_scale := Vector2(0.30, 0.30)

var _style_box: StyleBoxFlat
var _position_label: Label
var _level_badge: Panel = null
var _level_label: Label = null
var _combat_badge: Panel = null
var _combat_label: Label = null
var _combat_badge_style: StyleBoxFlat = null
var _status_badge: Panel = null
var _status_label: Label = null
var _skill_badge: Panel = null
var _skill_label: Label = null
var _dominion_badge: Panel = null
var _dominion_label: Label = null
var _dominion_badge_style: StyleBoxFlat = null
var _dominion_enabled := false
var _dominion_owner_id := 0
var _dominion_control := {1: 0, 2: 0}
var _is_highlighted := false
var _is_lane_open := false
var _combat_highlight: CombatHighlight = CombatHighlight.NONE
var _combat_hint_text := ""
var _pulse_time := 0.0

func _ready() -> void:
	add_to_group(GROUP_NAME)
	if is_hq_slot:
		position_type = PositionType.HQ
		lane_id = Lane.NONE
	_setup_visual_style()
	_create_position_label()
	_create_dominion_badge()
	_create_card_state_overlays()
	resized.connect(_layout_card_state_overlays)
	resized.connect(_layout_dominion_badge)
	_refresh_position_label()
	_refresh_cursor_shape()
	set_process(true)

func set_draw_order(draw_order: int) -> void:
	# Child CanvasItems use relative Z indices, therefore the band belongs to
	# the slot rather than to individual cards.
	z_as_relative = true
	z_index = max(0, draw_order) * Z_INDEX_STRIDE

func _process(delta: float) -> void:
	if _combat_highlight in [CombatHighlight.NONE, CombatHighlight.INELIGIBLE] and not _is_highlighted:
		return
	_pulse_time += delta
	queue_redraw()

func _setup_visual_style() -> void:
	var team_accent := _get_team_accent(owner_id)
	hover_highlight_color = Color(team_accent.darkened(0.52), 0.94)
	border_highlight_color = Color(0.96, 0.76, 0.36, 1.0)
	open_lane_border_color = Color(0.35, 0.49, 0.35, 0.88)
	match position_type:
		PositionType.FRONT:
			normal_color = Color(0.105, 0.090, 0.078, 0.97)
			border_color = Color(0.48, 0.30, 0.19, 0.94)
		PositionType.BACK:
			normal_color = Color(0.080, 0.086, 0.090, 0.97)
			border_color = Color(0.31, 0.43, 0.48, 0.92)
		PositionType.STRUCTURE:
			normal_color = Color(0.115, 0.101, 0.076, 0.98)
			border_color = Color(0.56, 0.43, 0.24, 0.94)
		PositionType.HQ:
			normal_color = Color(0.125, 0.105, 0.074, 0.99)
			border_color = Color(0.72, 0.54, 0.27, 0.98)
			border_highlight_color = Color(1.0, 0.82, 0.38, 1.0)
	# Position material remains readable, while the edge light makes north and
	# south armies identifiable even when cards cover most of the slot surface.
	normal_color = normal_color.lerp(Color(team_accent, normal_color.a), 0.05)
	border_color = border_color.lerp(Color(team_accent, border_color.a), 0.42 if is_hq_slot else 0.30)

	_style_box = StyleBoxFlat.new()
	_style_box.border_width_left = 4
	_style_box.border_width_top = 4
	_style_box.border_width_right = 5
	_style_box.border_width_bottom = 5
	_style_box.corner_radius_top_left = 8
	_style_box.corner_radius_top_right = 8
	_style_box.corner_radius_bottom_left = 9
	_style_box.corner_radius_bottom_right = 9
	_style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.66)
	_style_box.shadow_size = 10
	_style_box.shadow_offset = Vector2(0.0, 5.0)
	_style_box.anti_aliasing = true
	add_theme_stylebox_override("panel", _style_box)
	_refresh_visual_style()

func _create_position_label() -> void:
	_position_label = Label.new()
	_position_label.name = "PositionLabel"
	_position_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_position_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_position_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_position_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_position_label.add_theme_font_size_override("font_size", 9)
	_position_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.75, 0.76))
	_position_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_position_label.add_theme_constant_override("outline_size", 3)
	add_child(_position_label)

func can_accept_card(card: Control) -> bool:
	if not is_visible_in_tree() or position_type == PositionType.HQ or is_hq_slot:
		return false
	if "owner_id" in card and card.owner_id != owner_id:
		return false

	if card is UpgradeCard:
		if not is_occupied or not occupied_card:
			return false
		return card.can_target_card(occupied_card)

	if is_occupied:
		return false

	match position_type:
		PositionType.FRONT, PositionType.BACK:
			return card is HeroCard
		PositionType.STRUCTURE:
			return card is SettlementCard
		_:
			return false

func highlight(active: bool) -> void:
	_is_highlighted = active
	_refresh_visual_style()
	_refresh_cursor_shape()

func set_combat_highlight(value: CombatHighlight, hint_text: String = "") -> void:
	if _combat_highlight == value and _combat_hint_text == hint_text:
		return
	_combat_highlight = value
	_combat_hint_text = hint_text
	_refresh_visual_style()
	_refresh_target_action_badge()
	_refresh_occupied_card_target_focus()
	_refresh_cursor_shape()

func get_combat_highlight() -> CombatHighlight:
	return _combat_highlight

func set_lane_open(value: bool) -> void:
	if _is_lane_open == value:
		return
	_is_lane_open = value
	_refresh_visual_style()
	_refresh_position_label()


func set_dominion_control(enabled: bool, controlling_player_id: int, player_one: int, player_two: int) -> void:
	_dominion_enabled = enabled and position_type != PositionType.HQ
	_dominion_owner_id = controlling_player_id if controlling_player_id in [1, 2] else 0
	_dominion_control = {1: maxi(0, player_one), 2: maxi(0, player_two)}
	_refresh_dominion_badge()
	_refresh_visual_style()

func accept_card(card: Control) -> void:
	if is_occupied:
		return

	occupied_card = card
	is_occupied = true
	_connect_occupied_card_signals()
	_apply_card_visual_scale(card)
	_refresh_position_label()
	_refresh_card_state_overlay()
	_refresh_occupied_card_target_focus()
	highlight(false)
	_refresh_cursor_shape()
	occupancy_changed.emit(self)

func set_card_visual_scale(new_scale: Vector2) -> void:
	card_visual_scale = new_scale
	if occupied_card and is_instance_valid(occupied_card):
		_apply_card_visual_scale(occupied_card)
		occupied_card.position = (size - occupied_card.size) * 0.5
	_layout_card_state_overlays()

func _apply_card_visual_scale(card: Control) -> void:
	if card is BaseCard:
		var base_card = card as BaseCard
		base_card.in_slot_scale = card_visual_scale

func release_card() -> void:
	_disconnect_occupied_card_signals()
	if occupied_card and is_instance_valid(occupied_card):
		occupied_card.modulate = Color.WHITE
	occupied_card = null
	is_occupied = false
	_refresh_position_label()
	_refresh_card_state_overlay()
	highlight(false)
	_refresh_cursor_shape()
	occupancy_changed.emit(self)

func _refresh_cursor_shape() -> void:
	var actionable := _is_highlighted or _combat_highlight in [
		CombatHighlight.ATTACKER,
		CombatHighlight.TARGET,
		CombatHighlight.SUPPORT_TARGET,
		CombatHighlight.MOVE_TARGET,
	]
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if actionable or is_occupied
		else Control.CURSOR_ARROW
	)

func get_lane_display_name() -> String:
	match lane_id:
		Lane.LEFT:
			return "SOL"
		Lane.CENTER:
			return "ORTA"
		Lane.RIGHT:
			return "SAĞ"
		_:
			return ""

func get_position_display_name() -> String:
	match position_type:
		PositionType.FRONT:
			return "ÖN HAT"
		PositionType.BACK:
			return "ARKA HAT"
		PositionType.STRUCTURE:
			return "YAPI"
		PositionType.HQ:
			return "MERKEZ"
		_:
			return ""

func _refresh_visual_style() -> void:
	if not _style_box:
		return

	_style_box.border_width_left = 4
	_style_box.border_width_top = 4
	_style_box.border_width_right = 5
	_style_box.border_width_bottom = 5
	if _combat_highlight == CombatHighlight.ATTACKER:
		_style_box.bg_color = Color(0.25, 0.15, 0.045, 0.84)
		_style_box.border_color = attacker_highlight_color
		_set_combat_border_width(5)
	elif _combat_highlight == CombatHighlight.TARGET:
		_style_box.bg_color = Color(0.42, 0.07, 0.055, 0.82) if position_type != PositionType.HQ else Color(0.34, 0.22, 0.04, 0.84)
		_style_box.border_color = target_highlight_color if position_type != PositionType.HQ else Color(1.0, 0.80, 0.22, 1.0)
		_set_combat_border_width(5)
	elif _combat_highlight == CombatHighlight.SUPPORT_TARGET:
		_style_box.bg_color = Color(0.045, 0.30, 0.18, 0.86)
		_style_box.border_color = support_highlight_color
		_set_combat_border_width(5)
	elif _combat_highlight == CombatHighlight.MOVE_TARGET:
		_style_box.bg_color = Color(0.04, 0.19, 0.34, 0.86)
		_style_box.border_color = move_highlight_color
		_set_combat_border_width(5)
	elif _combat_highlight == CombatHighlight.INELIGIBLE:
		_style_box.bg_color = Color(normal_color, 0.24)
		_style_box.border_color = Color(border_color, 0.22)
	elif _is_highlighted:
		_style_box.bg_color = hover_highlight_color
		_style_box.border_color = border_highlight_color
	else:
		_style_box.bg_color = Color(normal_color, 0.82 if is_occupied else 0.34)
		var show_open_lane := _is_lane_open and position_type == PositionType.FRONT
		if _dominion_enabled and _dominion_owner_id in [1, 2]:
			var dominion_accent := _get_team_accent(_dominion_owner_id)
			_style_box.border_color = Color(dominion_accent.lightened(0.12), 0.86)
		elif show_open_lane:
			_style_box.border_color = open_lane_border_color
		else:
			_style_box.border_color = border_color if is_occupied else Color(border_color, minf(border_color.a, 0.52))
	queue_redraw()


func _create_dominion_badge() -> void:
	_dominion_badge = Panel.new()
	_dominion_badge.name = "DominionBadge"
	_dominion_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dominion_badge.z_index = CONTENT_Z_INDEX
	_dominion_badge.visible = false
	_dominion_badge_style = StyleBoxFlat.new()
	_dominion_badge_style.bg_color = Color(0.04, 0.045, 0.055, 0.96)
	_dominion_badge_style.border_color = Color(0.58, 0.61, 0.68, 0.88)
	_dominion_badge_style.set_border_width_all(1)
	_dominion_badge_style.set_corner_radius_all(4)
	_dominion_badge.add_theme_stylebox_override("panel", _dominion_badge_style)
	add_child(_dominion_badge)
	_dominion_label = _create_overlay_label(_dominion_badge, "DominionLabel", 7)
	_layout_dominion_badge()


func _layout_dominion_badge() -> void:
	if not _dominion_badge:
		return
	var badge_width := clampf(size.x - 12.0, 42.0, 92.0)
	_dominion_badge.position = Vector2((size.x - badge_width) * 0.5, 4.0)
	_dominion_badge.size = Vector2(badge_width, 17.0)


func _refresh_dominion_badge() -> void:
	if not _dominion_badge or not _dominion_label:
		return
	_dominion_badge.visible = _dominion_enabled and position_type == PositionType.FRONT
	if not _dominion_badge.visible:
		tooltip_text = ""
		return
	var player_one := int(_dominion_control.get(1, 0))
	var player_two := int(_dominion_control.get(2, 0))
	var marker := "◇"
	var accent := Color(0.58, 0.61, 0.68)
	var owner_text := tr("NEUTRAL")
	if _dominion_owner_id == 1:
		marker = "◆"
		accent = _get_team_accent(1)
		owner_text = tr("PLAYER 1 CONTROL")
	elif _dominion_owner_id == 2:
		marker = "◆"
		accent = _get_team_accent(2)
		owner_text = tr("PLAYER 2 CONTROL")
	_dominion_label.text = "%s  %d–%d" % [marker, player_one, player_two]
	_dominion_label.add_theme_color_override("font_color", accent.lightened(0.24))
	if _dominion_badge_style:
		_dominion_badge_style.border_color = Color(accent, 0.92)
		_dominion_badge_style.bg_color = Color(accent.darkened(0.72), 0.96)
	_dominion_badge.queue_redraw()
	tooltip_text = tr("%s • Control power %d–%d • Points resolve at round end.") % [owner_text, player_one, player_two]


func _get_team_accent(player_id: int) -> Color:
	var perspective_player_id := 1
	if (
		(MatchSetup.is_multiplayer_player() or MatchSetup.is_ai_match())
		and MatchSetup.human_player_id in GameRules.PLAYER_IDS
	):
		perspective_player_id = MatchSetup.human_player_id
	return UI.TEAM_PLAYER if player_id == perspective_player_id else UI.TEAM_OPPONENT

func _draw() -> void:
	if size.x < 12.0 or size.y < 12.0:
		return
	var accent := _style_box.border_color if _style_box else border_color
	var stone_rect := Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
	var upper_bevel := Color(0.68, 0.64, 0.54, 0.17 if is_occupied else 0.07)
	var lower_bevel := Color(0.0, 0.0, 0.0, 0.52 if is_occupied else 0.22)
	draw_line(stone_rect.position + Vector2(2.0, 2.0), Vector2(stone_rect.end.x - 2.0, stone_rect.position.y + 2.0), upper_bevel, 2.0, true)
	draw_line(stone_rect.position + Vector2(2.0, 2.0), Vector2(stone_rect.position.x + 2.0, stone_rect.end.y - 2.0), upper_bevel, 2.0, true)
	draw_line(Vector2(stone_rect.position.x + 3.0, stone_rect.end.y - 2.0), stone_rect.end - Vector2(2.0, 2.0), lower_bevel, 3.0, true)
	draw_line(Vector2(stone_rect.end.x - 2.0, stone_rect.position.y + 3.0), stone_rect.end - Vector2(2.0, 2.0), lower_bevel, 3.0, true)

	# Fixed fissures and mineral flecks imply carved stone without relying on a
	# repeating bitmap, so the slab remains crisp at every responsive scale.
	var crack_color := Color(0.015, 0.014, 0.013, 0.72)
	draw_polyline(PackedVector2Array([
		Vector2(size.x * 0.18, 6.0),
		Vector2(size.x * 0.23, size.y * 0.18),
		Vector2(size.x * 0.19, size.y * 0.30),
		Vector2(size.x * 0.27, size.y * 0.41),
	]), crack_color, 1.2, true)
	draw_polyline(PackedVector2Array([
		Vector2(size.x - 7.0, size.y * 0.62),
		Vector2(size.x * 0.84, size.y * 0.67),
		Vector2(size.x * 0.79, size.y * 0.80),
		Vector2(size.x * 0.70, size.y - 6.0),
	]), crack_color, 1.2, true)
	for normalized_point in [
		Vector2(0.16, 0.72),
		Vector2(0.32, 0.14),
		Vector2(0.72, 0.22),
		Vector2(0.86, 0.48),
		Vector2(0.43, 0.86),
	]:
		var fleck := Vector2(size.x * normalized_point.x, size.y * normalized_point.y)
		draw_circle(fleck, 1.2, Color(0.72, 0.67, 0.57, 0.15))

	if _combat_highlight != CombatHighlight.NONE or _is_highlighted:
		var pulse := 0.54 + (sin(_pulse_time * 4.6) * 0.22)
		var outer_color := Color(accent.r, accent.g, accent.b, pulse)
		draw_rect(Rect2(Vector2(1.5, 1.5), size - Vector2(3.0, 3.0)), outer_color, false, 4.0, true)
		draw_rect(Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0)), Color(accent.r, accent.g, accent.b, pulse * 0.42), false, 2.0, true)
	draw_rect(stone_rect, Color(accent.r, accent.g, accent.b, 0.27), false, 1.4, true)

	var tick := minf(13.0, minf(size.x, size.y) * 0.16)
	var soft := Color(accent.r, accent.g, accent.b, 0.64)
	for corner in [
		Vector2(8.0, 8.0),
		Vector2(size.x - 8.0, 8.0),
		Vector2(8.0, size.y - 8.0),
		Vector2(size.x - 8.0, size.y - 8.0),
	]:
		var sx := 1.0 if corner.x < size.x * 0.5 else -1.0
		var sy := 1.0 if corner.y < size.y * 0.5 else -1.0
		draw_line(corner, corner + Vector2(tick * sx, 0.0), soft, 1.5, true)
		draw_line(corner, corner + Vector2(0.0, tick * sy), soft, 1.5, true)

	_draw_slot_rune(accent)

func _draw_slot_rune(accent: Color) -> void:
	var center := size * 0.5
	var rune := Color(accent.r, accent.g, accent.b, 0.34 if not is_occupied else 0.15)
	var radius := minf(size.x, size.y) * 0.18
	match position_type:
		PositionType.FRONT:
			draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), rune, 2.0, true)
			draw_line(center - Vector2(radius * 0.55, radius * 0.35), center - Vector2(0.0, radius), rune, 2.0, true)
			draw_line(center + Vector2(radius * 0.55, -radius * 0.35), center - Vector2(0.0, radius), rune, 2.0, true)
			draw_line(center - Vector2(radius * 0.65, -radius * 0.05), center + Vector2(radius * 0.65, -radius * 0.05), rune, 2.0, true)
		PositionType.BACK:
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius),
				center + Vector2(-radius, 0.0),
				center + Vector2(0.0, -radius),
			])
			draw_polyline(diamond, rune, 2.0, true)
			draw_line(center - Vector2(radius * 0.65, 0.0), center + Vector2(radius * 0.65, 0.0), rune, 1.5, true)
		PositionType.STRUCTURE:
			var left := center.x - radius
			var right := center.x + radius
			var top := center.y - radius * 0.72
			var bottom := center.y + radius
			draw_polyline(PackedVector2Array([
				Vector2(left, bottom),
				Vector2(left, top),
				Vector2(center.x - radius * 0.36, top - radius * 0.28),
				Vector2(center.x, top),
				Vector2(center.x + radius * 0.36, top - radius * 0.28),
				Vector2(right, top),
				Vector2(right, bottom),
			]), rune, 2.0, true)
			draw_line(Vector2(left - 2.0, bottom), Vector2(right + 2.0, bottom), rune, 2.0, true)
		PositionType.HQ:
			draw_circle(center, radius * 1.22, rune, false, 2.0, true)
			draw_circle(center, radius * 0.66, rune, false, 1.5, true)
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius),
				center + Vector2(-radius, 0.0),
				center + Vector2(0.0, -radius),
			])
			draw_polyline(diamond, rune, 1.5, true)

func _set_combat_border_width(width: int) -> void:
	_style_box.border_width_left = width
	_style_box.border_width_top = width
	_style_box.border_width_right = width
	_style_box.border_width_bottom = width

func _refresh_position_label() -> void:
	if not _position_label:
		return

	_position_label.visible = not is_occupied
	if position_type == PositionType.HQ:
		_position_label.text = tr("HQ")
		return

	if size.x < 64.0:
		var compact_position := ""
		match position_type:
			PositionType.FRONT:
				compact_position = tr("FRONT")
			PositionType.BACK:
				compact_position = tr("BACK")
			PositionType.STRUCTURE:
				compact_position = tr("STRUCTURE")
		_position_label.text = "%s\n%s" % [_translated_lane_display_name(), compact_position]
		return

	var open_suffix := "\n" + tr("OPEN") if _is_lane_open and position_type == PositionType.FRONT else ""
	_position_label.text = "%s\n%s%s" % [
		_translated_lane_display_name(),
		_translated_position_display_name(),
		open_suffix,
	]


func _translated_lane_display_name() -> String:
	match lane_id:
		Lane.LEFT:
			return tr("LEFT")
		Lane.CENTER:
			return tr("CENTER")
		Lane.RIGHT:
			return tr("RIGHT")
		_:
			return ""


func _translated_position_display_name() -> String:
	match position_type:
		PositionType.FRONT:
			return tr("FRONT ROW")
		PositionType.BACK:
			return tr("BACK ROW")
		PositionType.STRUCTURE:
			return tr("STRUCTURE")
		PositionType.HQ:
			return tr("HQ")
		_:
			return ""

func _create_card_state_overlays() -> void:
	_level_badge = _create_overlay_panel(
		"LevelBadge",
		Color(0.08, 0.07, 0.025, 0.96),
		Color(1.0, 0.75, 0.24, 0.94)
	)
	_level_badge.anchor_left = 0.0
	_level_badge.anchor_top = 0.0
	_level_badge.anchor_right = 0.0
	_level_badge.anchor_bottom = 0.0
	_level_label = _create_overlay_label(_level_badge, "LevelLabel", 7)

	_combat_badge = _create_overlay_panel(
		"CombatBadge",
		Color(0.06, 0.20, 0.10, 0.96),
		Color(0.35, 1.0, 0.55, 0.94)
	)
	_combat_badge_style = _combat_badge.get_theme_stylebox("panel") as StyleBoxFlat
	_combat_badge.anchor_left = 0.0
	_combat_badge.anchor_top = 0.0
	_combat_badge.anchor_right = 0.0
	_combat_badge.anchor_bottom = 0.0
	_combat_label = _create_overlay_label(_combat_badge, "CombatLabel", 8)

	_status_badge = _create_overlay_panel(
		"StatusBadge",
		Color(0.055, 0.06, 0.11, 0.97),
		Color(0.63, 0.48, 1.0, 0.94)
	)
	_status_badge.anchor_left = 0.0
	_status_badge.anchor_top = 0.0
	_status_badge.anchor_right = 0.0
	_status_badge.anchor_bottom = 0.0
	_status_label = _create_overlay_label(_status_badge, "StatusLabel", 8)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	_skill_badge = _create_overlay_panel(
		"SkillBadge",
		Color(0.06, 0.15, 0.16, 0.97),
		Color(0.28, 0.80, 0.76, 0.96)
	)
	_skill_badge.anchor_left = 0.0
	_skill_badge.anchor_top = 0.0
	_skill_badge.anchor_right = 0.0
	_skill_badge.anchor_bottom = 0.0
	_skill_label = _create_overlay_label(_skill_badge, "SkillLabel", 8)
	_skill_label.text = "+"

	_layout_card_state_overlays()
	_refresh_card_state_overlay()

func _create_overlay_panel(panel_name: String, background: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.name = panel_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = CONTENT_Z_INDEX
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel

func _create_overlay_label(parent: Panel, label_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 1.0
	label.offset_right = -1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.98, 0.97, 0.90))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	return label

func _layout_card_state_overlays() -> void:
	if not _level_badge or not _combat_badge or not _status_badge or not _skill_badge:
		return

	var source_card_size := occupied_card.size if occupied_card and is_instance_valid(occupied_card) else Vector2(200.0, 280.0)
	var visual_size := source_card_size * card_visual_scale
	var visual_rect := Rect2((size - visual_size) * 0.5, visual_size)
	var edge_pad := clampf(visual_rect.size.x * 0.045, 1.0, 3.0)
	var badge_height := clampf(visual_rect.size.y * 0.18, 10.0, 16.0)
	var available_width := maxf(34.0, visual_rect.size.x - (edge_pad * 2.0))
	var level_width := clampf(available_width * 0.42, 16.0, 32.0)
	var combat_width := maxf(16.0, available_width - level_width - 2.0)
	var top_left := visual_rect.position + Vector2(edge_pad, edge_pad)

	_set_state_overlay_rect(_level_badge, Rect2(top_left, Vector2(level_width, badge_height)))
	_set_state_overlay_rect(
		_combat_badge,
		Rect2(
			Vector2(visual_rect.position.x + edge_pad, visual_rect.position.y + edge_pad),
			Vector2(available_width, maxf(16.0, badge_height))
		)
	)

	var status_height := clampf(visual_rect.size.y * 0.17, 13.0, 17.0)
	_set_state_overlay_rect(
		_status_badge,
		Rect2(
			Vector2(visual_rect.position.x + edge_pad, visual_rect.end.y - status_height - edge_pad - 3.0),
			Vector2(available_width, status_height)
		)
	)

	var skill_size := Vector2(15.0, 15.0)
	_set_state_overlay_rect(
		_skill_badge,
		Rect2(
			Vector2(visual_rect.end.x - skill_size.x - edge_pad, top_left.y + badge_height + 2.0),
			skill_size
		)
	)

func _set_state_overlay_rect(panel: Panel, rect: Rect2) -> void:
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.position = rect.position
	panel.size = rect.size

func _connect_occupied_card_signals() -> void:
	if not occupied_card is BaseCard:
		return
	var card := occupied_card as BaseCard
	if not card.preview_state_changed.is_connected(_refresh_card_state_overlay):
		card.preview_state_changed.connect(_refresh_card_state_overlay)

func _disconnect_occupied_card_signals() -> void:
	if not occupied_card is BaseCard or not is_instance_valid(occupied_card):
		return
	var card := occupied_card as BaseCard
	if card.preview_state_changed.is_connected(_refresh_card_state_overlay):
		card.preview_state_changed.disconnect(_refresh_card_state_overlay)

func _refresh_card_state_overlay() -> void:
	var card := occupied_card as BaseCard
	var show_runtime_state := (
		is_occupied
		and card != null
		and is_instance_valid(card)
		and not is_hq_slot
		and position_type != PositionType.HQ
		and (card is HeroCard or card is SettlementCard)
	)
	if _level_badge:
		# Seviye artık slotta değil, kartın kendi görsel çerçevesinde yaşar.
		_level_badge.visible = false
	if _combat_badge:
		# This slot badge is reserved for the current interaction verb (VUR,
		# DESTEKLE, HAREKET). Persistent exhaustion stays inside the card template.
		_combat_badge.visible = false
	if _status_badge:
		_status_badge.visible = false
	if _skill_badge:
		_skill_badge.visible = show_runtime_state and not card.attached_skill_name.is_empty()
		_skill_badge.tooltip_text = tr("Attached Skill: %s") % tr(card.attached_skill_name) if show_runtime_state and not card.attached_skill_name.is_empty() else ""
	if not show_runtime_state:
		_layout_card_state_overlays()
		_refresh_target_action_badge()
		return

	var statuses: Array[String] = []
	var status_tooltips: Array[String] = []
	var stunned := card.get_status_amount("stunned")
	var poison := card.get_status_amount("poison")
	var protected_amount := card.get_status_amount("protected")
	if stunned > 0:
		statuses.append(tr("SER %d") % stunned)
		status_tooltips.append(tr("Sersemlemiş %d") % stunned)
	if poison > 0:
		statuses.append(tr("ZEH %d") % poison)
		status_tooltips.append(tr("Zehirli %d") % poison)
	if protected_amount > 0:
		statuses.append(tr("KOR %d") % protected_amount)
		status_tooltips.append(tr("Korumalı %d") % protected_amount)
	if not statuses.is_empty():
		_status_badge.visible = true
		_status_label.text = " ".join(statuses)
		_status_badge.tooltip_text = "\n".join(status_tooltips)

	_layout_card_state_overlays()
	_refresh_target_action_badge()

func _refresh_target_action_badge() -> void:
	if not _combat_badge or not _combat_label:
		return
	var visible_state := _combat_highlight in [
		CombatHighlight.ATTACKER,
		CombatHighlight.TARGET,
		CombatHighlight.SUPPORT_TARGET,
		CombatHighlight.MOVE_TARGET,
	]
	_combat_badge.visible = visible_state
	if not visible_state:
		return
	var background := Color(0.12, 0.08, 0.025, 0.97)
	var border := attacker_highlight_color
	var fallback_text := "SEÇİLİ"
	match _combat_highlight:
		CombatHighlight.TARGET:
			background = Color(0.34, 0.045, 0.035, 0.97)
			border = target_highlight_color
			fallback_text = "VUR"
		CombatHighlight.SUPPORT_TARGET:
			background = Color(0.035, 0.24, 0.14, 0.97)
			border = support_highlight_color
			fallback_text = "DESTEKLE"
		CombatHighlight.MOVE_TARGET:
			background = Color(0.035, 0.15, 0.28, 0.97)
			border = move_highlight_color
			fallback_text = "HAREKET"
		_:
			pass
	if _combat_badge_style:
		_combat_badge_style.bg_color = background
		_combat_badge_style.border_color = border
	_combat_label.text = tr(_combat_hint_text if not _combat_hint_text.is_empty() else fallback_text)
	_combat_label.add_theme_font_size_override("font_size", 7)
	_layout_card_state_overlays()

func _refresh_occupied_card_target_focus() -> void:
	if not occupied_card or not is_instance_valid(occupied_card):
		return
	if _combat_highlight == CombatHighlight.INELIGIBLE:
		occupied_card.modulate = Color(0.48, 0.50, 0.54, 0.58)
	else:
		occupied_card.modulate = Color.WHITE
