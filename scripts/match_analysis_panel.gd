class_name MatchAnalysisPanel extends PanelContainer

const UI := preload("res://scripts/dark_fantasy_ui.gd")

var _pending_analysis: Dictionary = {}
var _critical_lane_value: Label
var _critical_lane_evidence: Label
var _critical_lane_body: Label
var _insight_titles: Array[Label] = []
var _insight_tones: Array[Label] = []
var _insight_bodies: Array[Label] = []
var _insight_bars: Array[ColorRect] = []


func _ready() -> void:
	_build_ui()
	if not _pending_analysis.is_empty():
		_apply_analysis(_pending_analysis)


func set_analysis(analysis: Dictionary) -> void:
	_pending_analysis = analysis.duplicate(true)
	if is_node_ready():
		_apply_analysis(_pending_analysis)


func get_insight_count() -> int:
	return _insight_bodies.size()


func get_critical_lane_text() -> String:
	return _critical_lane_value.text if _critical_lane_value else ""


func get_rendered_insight_body(index: int) -> String:
	if index < 0 or index >= _insight_bodies.size():
		return ""
	return _insight_bodies[index].text


func _build_ui() -> void:
	name = "MatchAnalysisPanel"
	custom_minimum_size = Vector2(0.0, 166.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override(
		"panel",
		UI.inset_style(Color(0.010, 0.014, 0.020, 0.97), Color(UI.BRASS_DARK, 0.92), 7)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	stack.add_child(heading)
	var title := Label.new()
	title.name = "AnalysisTitle"
	title.text = tr("MATCH ANALYSIS")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	heading.add_child(title)
	var trace := Label.new()
	trace.name = "DecisionTrace"
	trace.text = tr("DECISION TRACE")
	trace.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	trace.add_theme_font_size_override("font_size", 10)
	trace.add_theme_color_override("font_color", Color(0.50, 0.82, 0.92))
	heading.add_child(trace)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	body.add_child(_build_critical_lane_card())
	for index in range(3):
		body.add_child(_build_insight_card(index))


func _build_critical_lane_card() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CriticalLaneCard"
	panel.custom_minimum_size = Vector2(244.0, 118.0)
	panel.add_theme_stylebox_override(
		"panel",
		UI.inset_style(Color(0.050, 0.035, 0.020, 0.82), Color(UI.BRASS, 0.76), 5)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	var eyebrow := Label.new()
	eyebrow.text = tr("CRITICAL LANE")
	eyebrow.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	eyebrow.add_theme_font_size_override("font_size", 9)
	eyebrow.add_theme_color_override("font_color", UI.TEXT_MUTED)
	stack.add_child(eyebrow)
	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 7)
	stack.add_child(value_row)
	_critical_lane_value = Label.new()
	_critical_lane_value.name = "CriticalLaneValue"
	_critical_lane_value.text = "—"
	_critical_lane_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_critical_lane_value.add_theme_font_override("font", UI.DISPLAY_FONT)
	_critical_lane_value.add_theme_font_size_override("font_size", 18)
	_critical_lane_value.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	value_row.add_child(_critical_lane_value)
	_critical_lane_evidence = Label.new()
	_critical_lane_evidence.name = "CriticalLaneEvidence"
	_critical_lane_evidence.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_critical_lane_evidence.add_theme_font_size_override("font_size", 8)
	_critical_lane_evidence.add_theme_color_override("font_color", Color(0.50, 0.82, 0.92))
	value_row.add_child(_critical_lane_evidence)
	_critical_lane_body = Label.new()
	_critical_lane_body.name = "CriticalLaneExplanation"
	_critical_lane_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_critical_lane_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_critical_lane_body.add_theme_font_size_override("font_size", 10)
	_critical_lane_body.add_theme_color_override("font_color", UI.PARCHMENT)
	stack.add_child(_critical_lane_body)
	return panel


func _build_insight_card(index: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "InsightCard%d" % (index + 1)
	panel.custom_minimum_size = Vector2(202.0, 118.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		UI.inset_style(Color(0.015, 0.019, 0.026, 0.92), Color(UI.BRASS_DARK, 0.72), 4)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	var bar := ColorRect.new()
	bar.name = "ToneBar"
	bar.custom_minimum_size.x = 3.0
	bar.color = UI.TEXT_MUTED
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	_insight_bars.append(bar)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 7)
	row.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	var title := Label.new()
	title.name = "InsightTitle"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	stack.add_child(title)
	_insight_titles.append(title)
	var tone := Label.new()
	tone.name = "InsightTone"
	tone.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	tone.add_theme_font_size_override("font_size", 10)
	stack.add_child(tone)
	_insight_tones.append(tone)
	var body := Label.new()
	body.name = "InsightBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", UI.PARCHMENT)
	stack.add_child(body)
	_insight_bodies.append(body)
	return panel


func _apply_analysis(analysis: Dictionary) -> void:
	visible = bool(analysis.get("valid", false))
	if not visible:
		return
	var critical_variant: Variant = analysis.get("critical_lane", {})
	var critical := critical_variant as Dictionary if critical_variant is Dictionary else {}
	_critical_lane_value.text = tr(str(critical.get("lane_name_key", "CENTER")))
	var confidence_key := "%s EVIDENCE" % str(critical.get("confidence_id", "low")).to_upper()
	_critical_lane_evidence.text = tr(confidence_key)
	_critical_lane_body.text = _localized_format(
		str(critical.get("explanation_key", "No lane produced enough activity for a confident critical-lane read.")),
		critical.get("explanation_args", []) as Array
	)
	var insights_variant: Variant = analysis.get("insights", [])
	var insights := insights_variant as Array if insights_variant is Array else []
	for index in range(_insight_bodies.size()):
		var insight := insights[index] as Dictionary if index < insights.size() and insights[index] is Dictionary else {}
		_insight_titles[index].text = tr(str(insight.get("title_key", "")))
		var tone := str(insight.get("tone", "neutral"))
		var tone_key := "BALANCED READ" if tone == "neutral" else tone.to_upper()
		_insight_tones[index].text = tr(tone_key)
		var accent := _tone_color(tone)
		_insight_tones[index].add_theme_color_override("font_color", accent)
		_insight_bars[index].color = accent
		_insight_bodies[index].text = _localized_format(
			str(insight.get("body_key", "")),
			insight.get("body_args", []) as Array
		)


func _localized_format(key: String, args: Array) -> String:
	var localized := tr(key)
	return localized % args if not args.is_empty() else localized


func _tone_color(tone: String) -> Color:
	match tone:
		"strength":
			return Color(0.42, 0.84, 0.62)
		"opportunity":
			return Color(0.92, 0.61, 0.35)
		_:
			return Color(0.50, 0.82, 0.92)
