class_name TopHud extends Control

const UI := preload("res://scripts/dark_fantasy_ui.gd")
const CARD_STAT_ICON_SCRIPT := preload("res://scripts/card_stat_icon.gd")
const TURN_TIME_SAFE_COLOR := Color(0.25, 0.82, 0.42)
const TURN_TIME_WARNING_COLOR := Color(1.0, 0.58, 0.18)
const TURN_TIME_DANGER_COLOR := Color(0.90, 0.20, 0.14)

var round_label: Label = null
var active_player_label: Label = null
var own_turn_glow: Panel = null
var enemy_turn_glow: Panel = null

var _phase_label: Label = null
var _own_health_title: Label = null
var _enemy_health_title: Label = null
var _own_health_label: Label = null
var _enemy_health_label: Label = null
var _own_health_bar: ProgressBar = null
var _enemy_health_bar: ProgressBar = null
var _own_dominion_label: Label = null
var _enemy_dominion_label: Label = null
var _own_energy_badge: PanelContainer = null
var _own_energy_caption: Label = null
var _own_energy_label: Label = null
var _own_energy_icon: Control = null
var _own_energy_style: StyleBoxFlat = null
var _active_player_id := 1
var _perspective_player_id := 1
var _turn_count := 1
var _player_energy: Dictionary = {
	1: {"current": 0, "maximum": 0, "temporary": 0},
	2: {"current": 0, "maximum": 0, "temporary": 0},
}
var _hq_health: Dictionary = {
	1: {"current": GameRules.HEADQUARTERS_HEALTH, "maximum": GameRules.HEADQUARTERS_HEALTH},
	2: {"current": GameRules.HEADQUARTERS_HEALTH, "maximum": GameRules.HEADQUARTERS_HEALTH},
}
var _dominion_score: Dictionary = {1: 0, 2: 0}
var _dominion_target := GameRules.DOMINION_SCORE_TARGET
var _dominion_enabled := false
var _phase_name := "BAŞLANGIÇ ELİ"
var _own_glow_tween: Tween = null
var _enemy_glow_tween: Tween = null
var _turn_time_remaining := GameRules.TURN_DURATION_SECONDS
var _turn_time_total := GameRules.TURN_DURATION_SECONDS
var _turn_timer_running := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_refresh_text()
	_refresh_glow()


func set_perspective_player(player_id: int) -> void:
	_perspective_player_id = player_id if player_id in GameRules.PLAYER_IDS else 1
	_refresh_text()
	_refresh_glow()


func set_turn_state(active_player_id: int, turn_count: int) -> void:
	_active_player_id = active_player_id
	_turn_count = max(1, turn_count)
	_refresh_text()
	_refresh_glow()


func set_turn_time(
	active_player_id: int,
	remaining_seconds: float,
	total_seconds: float,
	is_running: bool
) -> void:
	_active_player_id = active_player_id
	_turn_time_total = maxf(0.0, total_seconds)
	_turn_time_remaining = clampf(remaining_seconds, 0.0, _turn_time_total)
	_turn_timer_running = is_running
	_refresh_glow()


func set_player_energy(player_id: int, current_energy: int, maximum_energy: int, temporary_energy: int = 0) -> void:
	_player_energy[player_id] = {
		"current": max(0, current_energy),
		"maximum": max(0, maximum_energy),
		"temporary": max(0, temporary_energy),
	}
	_refresh_text()


func set_hq_health(player_id: int, current_health: int, maximum_health: int) -> void:
	if player_id not in GameRules.PLAYER_IDS:
		return
	_hq_health[player_id] = {
		"current": clampi(current_health, 0, maximum_health),
		"maximum": max(1, maximum_health),
	}
	_refresh_text()


func set_ruleset(ruleset: int) -> void:
	_dominion_enabled = ruleset == MatchSetup.Ruleset.DOMINION
	_refresh_text()


func set_dominion_score(player_id: int, current_score: int, target_score: int) -> void:
	if player_id not in GameRules.PLAYER_IDS:
		return
	_dominion_score[player_id] = maxi(0, current_score)
	_dominion_target = maxi(1, target_score)
	_refresh_text()


func set_phase(phase_name: String) -> void:
	_phase_name = phase_name
	_refresh_text()


func _build_ui() -> void:
	var frame := Panel.new()
	frame.name = "ForgedFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UI.panel_style(UI.BRASS, 10.0, 1.0))
	add_child(frame)

	own_turn_glow = _create_edge_glow("OwnTurnGlow", UI.TEAM_PLAYER, true)
	enemy_turn_glow = _create_edge_glow("EnemyTurnGlow", UI.TEAM_OPPONENT, false)
	frame.add_child(own_turn_glow)
	frame.add_child(enemy_turn_glow)

	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "HudRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 15)
	margin.add_child(row)

	var own_cell := _create_health_cell(true)
	row.add_child(own_cell)
	row.add_child(_create_separator())

	var center := HBoxContainer.new()
	center.name = "TurnCell"
	center.custom_minimum_size = Vector2(245.0, 70.0)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 8)
	row.add_child(center)

	var turn_stack := VBoxContainer.new()
	turn_stack.name = "TurnStatus"
	turn_stack.custom_minimum_size.x = 132.0
	turn_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	turn_stack.add_theme_constant_override("separation", -4)
	center.add_child(turn_stack)

	round_label = _make_label("RoundLabel", 9, UI.TEXT_MUTED, true)
	round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_stack.add_child(round_label)

	active_player_label = _make_label("ActivePlayerLabel", 10, UI.PARCHMENT, true)
	active_player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_stack.add_child(active_player_label)

	_phase_label = _make_label("PhaseLabel", 11, UI.BRASS_BRIGHT, true)
	_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_stack.add_child(_phase_label)

	_own_energy_badge = _create_own_energy_badge()
	center.add_child(_own_energy_badge)

	row.add_child(_create_separator())
	var enemy_cell := _create_health_cell(false)
	row.add_child(enemy_cell)


func _create_health_cell(is_own: bool) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.name = "OwnHealthCell" if is_own else "EnemyHealthCell"
	cell.custom_minimum_size = Vector2(170.0, 74.0)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", -1)

	var title := _make_label("Title", 10, UI.TEXT_MUTED, true)
	var value := _make_label("Value", 24, UI.PARCHMENT, true)
	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	bar.custom_minimum_size = Vector2(160.0, 8.0)
	bar.max_value = GameRules.HEADQUARTERS_HEALTH
	bar.value = GameRules.HEADQUARTERS_HEALTH
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_health_bar(bar, UI.TEAM_PLAYER if is_own else UI.TEAM_OPPONENT)
	cell.add_child(title)
	cell.add_child(value)
	cell.add_child(bar)
	var dominion := _make_label("DominionScore", 10, UI.BRASS_BRIGHT, true)
	dominion.text = tr("DOMINION  0 / %d") % GameRules.DOMINION_SCORE_TARGET
	dominion.visible = false
	cell.add_child(dominion)
	if is_own:
		_own_health_title = title
		_own_health_label = value
		_own_health_bar = bar
		_own_dominion_label = dominion
	else:
		_enemy_health_title = title
		_enemy_health_label = value
		_enemy_health_bar = bar
		_enemy_dominion_label = dominion
	return cell


func _create_own_energy_badge() -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "OwnEnergyBadge"
	badge.custom_minimum_size = Vector2(96.0, 50.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_own_energy_style = StyleBoxFlat.new()
	_own_energy_style.bg_color = Color(0.075, 0.055, 0.025, 0.96)
	_own_energy_style.border_color = Color(UI.BRASS_BRIGHT, 0.84)
	_own_energy_style.set_border_width_all(2)
	_own_energy_style.set_corner_radius_all(7)
	_own_energy_style.content_margin_left = 7.0
	_own_energy_style.content_margin_top = 4.0
	_own_energy_style.content_margin_right = 8.0
	_own_energy_style.content_margin_bottom = 4.0
	_own_energy_style.shadow_color = Color(UI.BRASS_BRIGHT, 0.28)
	_own_energy_style.shadow_size = 7
	_own_energy_style.shadow_offset = Vector2.ZERO
	badge.add_theme_stylebox_override("panel", _own_energy_style)

	var content := HBoxContainer.new()
	content.name = "EnergyContent"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(content)

	_own_energy_icon = CARD_STAT_ICON_SCRIPT.new() as Control
	_own_energy_icon.name = "EnergyLightningIcon"
	_own_energy_icon.custom_minimum_size = Vector2(22.0, 31.0)
	_own_energy_icon.set("icon_type", CARD_STAT_ICON_SCRIPT.IconType.LIGHTNING)
	content.add_child(_own_energy_icon)

	var value_stack := VBoxContainer.new()
	value_stack.name = "EnergyValueStack"
	value_stack.custom_minimum_size.x = 54.0
	value_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	value_stack.add_theme_constant_override("separation", -5)
	value_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(value_stack)

	_own_energy_caption = _make_label("OwnEnergyCaption", 8, UI.BRASS, true)
	_own_energy_caption.text = "ENERJİN"
	value_stack.add_child(_own_energy_caption)

	_own_energy_label = _make_label("OwnEnergyValue", 18, UI.BRASS_BRIGHT, true)
	_own_energy_label.text = "0 / 0"
	value_stack.add_child(_own_energy_label)
	return badge


func _create_separator() -> VSeparator:
	var separator := VSeparator.new()
	separator.custom_minimum_size.x = 1.0
	separator.add_theme_stylebox_override("separator", UI.line_style(Color(UI.BRASS, 0.42), 1))
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return separator


func _create_edge_glow(node_name: String, color: Color, left_side: bool) -> Panel:
	var glow := Panel.new()
	glow.name = node_name
	glow.anchor_left = 0.0 if left_side else 0.5
	glow.anchor_top = 1.0
	glow.anchor_right = 0.5 if left_side else 1.0
	glow.anchor_bottom = 1.0
	glow.offset_left = 16.0 if left_side else 4.0
	glow.offset_top = -7.0
	glow.offset_right = -4.0 if left_side else -16.0
	glow.offset_bottom = -3.0
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.88)
	style.shadow_color = Color(color.r, color.g, color.b, 0.48)
	style.shadow_size = 8
	glow.add_theme_stylebox_override("panel", style)
	return glow


func _make_label(node_name: String, font_size: int, color: Color, display_font: bool) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	if display_font:
		UI.style_title(label, color)
		label.add_theme_constant_override("outline_size", 2)
	return label


func _style_health_bar(bar: ProgressBar, color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.015, 0.015, 0.018, 0.94)
	background.border_color = Color(UI.BRASS_DARK, 0.72)
	background.set_border_width_all(1)
	background.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)


func _refresh_text() -> void:
	if not round_label or not active_player_label or not _own_energy_label:
		return
	var own_id := _perspective_player_id
	var enemy_id := 2 if own_id == 1 else 1
	round_label.text = tr("TURN %02d") % _turn_count
	active_player_label.text = _get_turn_text(own_id)
	active_player_label.add_theme_color_override(
		"font_color",
		UI.TEAM_PLAYER.lightened(0.30) if _active_player_id == own_id else UI.TEAM_OPPONENT.lightened(0.26)
	)
	_apply_own_energy_display(own_id)
	if _phase_label:
		_phase_label.text = tr(_phase_name)
	if _own_health_title:
		_own_health_title.text = tr("BİZİM MERKEZ")
	if _enemy_health_title:
		_enemy_health_title.text = tr("RAKİP MERKEZ")
	_apply_health_display(_own_health_label, _own_health_bar, own_id)
	_apply_health_display(_enemy_health_label, _enemy_health_bar, enemy_id)
	_apply_dominion_display(_own_dominion_label, own_id, UI.TEAM_PLAYER)
	_apply_dominion_display(_enemy_dominion_label, enemy_id, UI.TEAM_OPPONENT)


func _apply_own_energy_display(player_id: int) -> void:
	var energy: Dictionary = _player_energy.get(player_id, {})
	var current := int(energy.get("current", 0))
	var maximum := int(energy.get("maximum", 0))
	var temporary := int(energy.get("temporary", 0))
	var available := current + temporary
	_own_energy_label.text = "%d / %d" % [available, maximum]
	_own_energy_caption.text = tr("YOUR ENERGY") if temporary <= 0 else tr("YOUR ENERGY  +%d") % temporary
	var accent := Color(1.0, 0.42, 0.28) if available <= 0 else UI.BRASS_BRIGHT
	_own_energy_label.add_theme_color_override("font_color", accent)
	if _own_energy_style:
		_own_energy_style.border_color = Color(accent, 0.86)
		_own_energy_style.shadow_color = Color(accent, 0.30)
	if _own_energy_badge:
		_own_energy_badge.queue_redraw()


func _apply_health_display(label: Label, bar: ProgressBar, player_id: int) -> void:
	var health: Dictionary = _hq_health.get(player_id, {})
	var current := int(health.get("current", GameRules.HEADQUARTERS_HEALTH))
	var maximum: int = max(1, int(health.get("maximum", GameRules.HEADQUARTERS_HEALTH)))
	if label:
		label.text = "%d / %d" % [current, maximum]
		label.add_theme_color_override("font_color", UI.PARCHMENT if current > maximum * 0.3 else Color(1.0, 0.45, 0.34))
	if bar:
		bar.max_value = maximum
		bar.value = current


func _apply_dominion_display(label: Label, player_id: int, accent: Color) -> void:
	if not label:
		return
	label.visible = _dominion_enabled
	label.text = tr("◆  DOMINION  %d / %d") % [
		int(_dominion_score.get(player_id, 0)),
		_dominion_target,
	]
	label.add_theme_color_override("font_color", accent.lightened(0.22))


func _get_turn_text(own_id: int) -> String:
	if _active_player_id == own_id:
		return "SIRA SENDE"
	if MatchSetup.is_ai_player(_active_player_id):
		return "RAKİP HAMLESİ"
	return "SIRA RAKİPTE"


func _refresh_glow() -> void:
	var is_own_turn := _active_player_id == _perspective_player_id
	_set_glow_enabled(own_turn_glow, _turn_timer_running and is_own_turn, true)
	_set_glow_enabled(enemy_turn_glow, _turn_timer_running and not is_own_turn, false)
	if not _turn_timer_running:
		return

	var active_line := own_turn_glow if is_own_turn else enemy_turn_glow
	_update_turn_timer_line(active_line, get_turn_time_ratio(), is_own_turn)


func get_turn_time_ratio() -> float:
	if _turn_time_total <= 0.0:
		return 0.0
	return clampf(_turn_time_remaining / _turn_time_total, 0.0, 1.0)


func _update_turn_timer_line(panel: Panel, ratio: float, grows_from_left: bool) -> void:
	if not panel:
		return

	var fill_ratio := clampf(ratio, 0.0, 1.0)
	panel.pivot_offset = Vector2(0.0, panel.size.y * 0.5) if grows_from_left else Vector2(panel.size.x, panel.size.y * 0.5)
	panel.scale = Vector2(fill_ratio, 1.0)
	_set_turn_timer_line_color(panel, _get_turn_timer_color(fill_ratio))


func _get_turn_timer_color(ratio: float) -> Color:
	if ratio > (2.0 / 3.0):
		return TURN_TIME_SAFE_COLOR
	if ratio > (1.0 / 3.0):
		return TURN_TIME_WARNING_COLOR
	return TURN_TIME_DANGER_COLOR


func _set_turn_timer_line_color(panel: Panel, color: Color) -> void:
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return
	style.bg_color = Color(color.r, color.g, color.b, 0.92)
	style.shadow_color = Color(color.r, color.g, color.b, 0.50)
	panel.queue_redraw()


func _set_glow_enabled(panel: Panel, enabled: bool, is_own: bool) -> void:
	if not panel:
		return
	var previous := _own_glow_tween if is_own else _enemy_glow_tween
	if not enabled:
		if previous and previous.is_valid():
			previous.kill()
		panel.visible = false
		panel.modulate.a = 0.0
		return
	if panel.visible:
		return

	panel.visible = true
	panel.modulate.a = 0.48
	var tween := create_tween().bind_node(panel).set_loops()
	tween.tween_property(panel, "modulate:a", 1.0, 0.52)
	tween.tween_property(panel, "modulate:a", 0.42, 0.68)
	if is_own:
		_own_glow_tween = tween
	else:
		_enemy_glow_tween = tween
