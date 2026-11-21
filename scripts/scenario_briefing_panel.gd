class_name ScenarioBriefingPanel extends Control

signal closed

const UI := preload("res://scripts/dark_fantasy_ui.gd")
const OBJECTIVE_RESOLVER := preload("res://scripts/scenario_objective_resolver.gd")

var _scenario: Dictionary = {}
var _context: Dictionary = {}
var _summary: Dictionary = {}
var _perspective_player_id := 1
var _evaluation: Dictionary = {}
var _heading: Label
var _status_label: Label
var _summary_label: Label
var _lesson_label: Label
var _objective_list: VBoxContainer
var _progress_label: Label


func _ready() -> void:
	name = "ScenarioBriefingOverlay"
	z_index = 950
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	theme = UI.create_theme()
	_build_interface()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func open_panel(
	scenario: Dictionary,
	context: Dictionary,
	summary: Dictionary,
	perspective_player_id: int
) -> void:
	_scenario = scenario.duplicate(true)
	_context = context.duplicate(true)
	_summary = summary.duplicate(true)
	_perspective_player_id = perspective_player_id
	_refresh()
	visible = true
	modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(
		self,
		"modulate:a",
		1.0,
		0.14
	)
	var close_button := find_child("ScenarioBriefingCloseButton", true, false) as Button
	if close_button:
		close_button.grab_focus()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func update_match_state(summary: Dictionary, perspective_player_id: int) -> void:
	_summary = summary.duplicate(true)
	_perspective_player_id = perspective_player_id
	_refresh()


func get_evaluation() -> Dictionary:
	return _evaluation.duplicate(true)


func get_completed_objective_count() -> int:
	return int(_evaluation.get("completed_required_count", 0))


func get_objective_count() -> int:
	return int(_evaluation.get("required_count", 0))


func _build_interface() -> void:
	var dim := ColorRect.new()
	dim.name = "ScenarioBriefingDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.003, 0.006, 0.010, 0.91)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ScenarioBriefingPanel"
	panel.custom_minimum_size = Vector2(820.0, 590.0)
	panel.add_theme_stylebox_override("panel", UI.panel_style(UI.FROST, 24.0, 1.0))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var eyebrow := _muted_label(tr("COMMANDER'S CAMPAIGN • TACTICAL BRIEFING"), 11)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", UI.FROST)
	box.add_child(eyebrow)
	_heading = Label.new()
	_heading.name = "ScenarioBriefingTitle"
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 28)
	UI.style_title(_heading, UI.PARCHMENT)
	box.add_child(_heading)
	_status_label = _muted_label("", 12)
	_status_label.name = "ScenarioBriefingStatus"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	box.add_child(_status_label)

	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", UI.line_style(Color(UI.BRASS, 0.46), 1))
	box.add_child(rule)
	_summary_label = _muted_label("", 16)
	_summary_label.name = "ScenarioBriefingSummary"
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.add_theme_color_override("font_color", Color(UI.PARCHMENT, 0.88))
	box.add_child(_summary_label)
	_lesson_label = _muted_label("", 11)
	_lesson_label.name = "ScenarioBriefingLesson"
	_lesson_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lesson_label.add_theme_color_override("font_color", UI.TEXT_MUTED)
	box.add_child(_lesson_label)

	var objective_header := HBoxContainer.new()
	objective_header.add_theme_constant_override("separation", 12)
	box.add_child(objective_header)
	var objective_title := _muted_label(tr("REQUIRED OBJECTIVES"), 11)
	objective_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_title.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	objective_header.add_child(objective_title)
	_progress_label = _muted_label("0 / 0", 12)
	_progress_label.name = "ScenarioBriefingProgress"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_label.add_theme_color_override("font_color", UI.FROST)
	objective_header.add_child(_progress_label)

	_objective_list = VBoxContainer.new()
	_objective_list.name = "ScenarioBriefingObjectives"
	_objective_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_objective_list.add_theme_constant_override("separation", 8)
	box.add_child(_objective_list)

	var footer_rule := HSeparator.new()
	footer_rule.add_theme_stylebox_override("separator", UI.line_style(Color(UI.FROST, 0.34), 1))
	box.add_child(footer_rule)
	var close_button := Button.new()
	close_button.name = "ScenarioBriefingCloseButton"
	close_button.text = tr("RETURN TO BATTLE")
	close_button.custom_minimum_size = Vector2(260.0, 50.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 15)
	UI.style_button(close_button, UI.FROST, false, false, true)
	close_button.pressed.connect(close_panel)
	box.add_child(close_button)


func _refresh() -> void:
	if not is_node_ready() or _heading == null or _scenario.is_empty():
		return
	_evaluation = OBJECTIVE_RESOLVER.evaluate(_context, _summary, _perspective_player_id)
	_heading.text = "%02d • %s" % [
		int(_scenario.get("order", 0)),
		tr(str(_scenario.get("title", _context.get("scenario_id", "")))),
	]
	_summary_label.text = tr(str(_scenario.get("summary", "")))
	_lesson_label.text = "%s: %s" % [tr("TACTICAL LESSON"), tr(_lesson_name(str(_scenario.get("lesson", ""))))]
	var completed_count := int(_evaluation.get("completed_required_count", 0))
	var required_count := int(_evaluation.get("required_count", 0))
	_progress_label.text = "%d / %d" % [completed_count, required_count]
	_status_label.text = (
		tr("ALL OBJECTIVES COMPLETE")
		if required_count > 0 and completed_count == required_count
		else tr("Complete every objective in the same match.")
	)
	_rebuild_objectives()


func _rebuild_objectives() -> void:
	for child in _objective_list.get_children():
		_objective_list.remove_child(child)
		child.queue_free()
	for result_variant in _evaluation.get("objective_results", []) as Array:
		if not result_variant is Dictionary:
			continue
		var result := result_variant as Dictionary
		var complete := bool(result.get("completed", false))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override(
			"panel",
			UI.inset_style(Color(0.010, 0.014, 0.019, 0.96), UI.MOSS if complete else UI.BRASS_DARK, 5)
		)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var marker := _muted_label("✓" if complete else "◇", 20)
		marker.custom_minimum_size.x = 34.0
		marker.add_theme_color_override("font_color", UI.MOSS.lightened(0.30) if complete else UI.BRASS_BRIGHT)
		row.add_child(marker)
		var description := _muted_label(_objective_description(result), 16)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", UI.PARCHMENT)
		row.add_child(description)
		var progress := _muted_label(_localized_progress(result), 13)
		progress.custom_minimum_size.x = 150.0
		progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		progress.add_theme_color_override("font_color", UI.MOSS.lightened(0.30) if complete else UI.FROST)
		row.add_child(progress)
		_objective_list.add_child(panel)


func _objective_description(result: Dictionary) -> String:
	var metric := str(result.get("metric", ""))
	if metric == "match_won":
		return tr("Win the match")
	var label := tr(OBJECTIVE_RESOLVER.metric_label(metric))
	var target := int(result.get("target", 0))
	match str(result.get("operator", "at_least")):
		"at_most": return tr("%s: at most %d") % [label, target]
		"equals": return tr("%s: exactly %d") % [label, target]
		_: return tr("%s: at least %d") % [label, target]


func _lesson_name(lesson: String) -> String:
	match lesson:
		"deployment": return "Deployment"
		"energy": return "Energy management"
		"open_lane": return "Opening a lane"
		"movement": return "Cross-lane movement"
		"effects": return "Effect Card doctrine"
		"dominion": return "Dominion control"
		_: return lesson.capitalize()


func _localized_progress(result: Dictionary) -> String:
	if str(result.get("metric", "")) == "match_won":
		return tr("COMPLETED") if bool(result.get("completed", false)) else tr("PENDING")
	var value := int(round(float(result.get("value", 0.0))))
	var target := int(round(float(result.get("target", 0.0))))
	match str(result.get("operator", "at_least")):
		"at_most": return tr("%d / at most %d") % [value, target]
		"equals": return tr("%d / exactly %d") % [value, target]
		_: return "%d / %d" % [mini(value, target), target]


func _muted_label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UI.TEXT_MUTED)
	return label
