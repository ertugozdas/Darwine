class_name DeckAdvisorPanel extends PanelContainer

const UI := preload("res://scripts/dark_fantasy_ui.gd")

var _pending_analysis: Dictionary = {}
var _average_label: Label
var _curve_counts: Array[Label] = []
var _roles_label: Label
var _suggestion_bodies: Array[Label] = []
var _suggestion_bars: Array[ColorRect] = []
var _suggestion_rows: Array[Control] = []
var _toggle_button: Button
var _expanded := false


func _ready() -> void:
	_build_ui()
	if not _pending_analysis.is_empty():
		_apply_analysis(_pending_analysis)


func set_analysis(analysis: Dictionary) -> void:
	_pending_analysis = analysis.duplicate(true)
	if is_node_ready():
		_apply_analysis(_pending_analysis)


func get_curve_counts() -> Array[int]:
	var counts: Array[int] = []
	for label in _curve_counts:
		counts.append(label.text.to_int())
	return counts


func get_suggestion_count() -> int:
	return _suggestion_bodies.size()


func get_rendered_suggestion(index: int) -> String:
	if index < 0 or index >= _suggestion_bodies.size():
		return ""
	return _suggestion_bodies[index].text


func get_visible_suggestion_count() -> int:
	var count := 0
	for row in _suggestion_rows:
		if row.visible:
			count += 1
	return count


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	custom_minimum_size.y = 212.0 if _expanded else 132.0
	for index in range(_suggestion_rows.size()):
		_suggestion_rows[index].visible = _expanded or index == 0
	if _toggle_button:
		_toggle_button.text = tr("COLLAPSE") if _expanded else tr("3 INSIGHTS")


func is_expanded() -> bool:
	return _expanded


func _build_ui() -> void:
	name = "DeckAdvisorPanel"
	custom_minimum_size.y = 132.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var advisor_style := UI.inset_style(Color(0.015, 0.018, 0.024, 0.97), UI.FROST, 5)
	advisor_style.content_margin_left = 10.0
	advisor_style.content_margin_right = 10.0
	advisor_style.content_margin_top = 8.0
	advisor_style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", advisor_style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	stack.add_child(header)
	var title := Label.new()
	title.name = "DeckAdvisorTitle"
	title.text = tr("DECK ADVISOR")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	header.add_child(title)
	var live := Label.new()
	live.name = "DeckAdvisorLiveRead"
	live.text = tr("LIVE READ")
	live.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	live.add_theme_font_size_override("font_size", 10)
	live.add_theme_color_override("font_color", UI.FROST.lightened(0.28))
	header.add_child(live)
	_toggle_button = Button.new()
	_toggle_button.name = "DeckAdvisorToggle"
	_toggle_button.custom_minimum_size = Vector2(82.0, 26.0)
	_toggle_button.add_theme_font_size_override("font_size", 10)
	UI.style_button(_toggle_button, UI.FROST, false, true)
	_toggle_button.pressed.connect(func(): set_expanded(not _expanded))
	header.add_child(_toggle_button)

	var curve_row := HBoxContainer.new()
	curve_row.name = "DeckAdvisorCurve"
	curve_row.add_theme_constant_override("separation", 4)
	stack.add_child(curve_row)
	var curve_title := Label.new()
	curve_title.text = tr("ENERGY CURVE")
	curve_title.custom_minimum_size.x = 68.0
	curve_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	curve_title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	curve_title.add_theme_font_size_override("font_size", 10)
	curve_title.add_theme_color_override("font_color", UI.TEXT_MUTED)
	curve_row.add_child(curve_title)
	for label_text in ["0–1", "2", "3", "4", "5+"]:
		curve_row.add_child(_build_curve_bucket(label_text))
	_average_label = Label.new()
	_average_label.name = "DeckAdvisorAverage"
	_average_label.custom_minimum_size.x = 54.0
	_average_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_average_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_average_label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_average_label.add_theme_font_size_override("font_size", 10)
	_average_label.add_theme_color_override("font_color", UI.PARCHMENT)
	curve_row.add_child(_average_label)

	_roles_label = Label.new()
	_roles_label.name = "DeckAdvisorRoles"
	_roles_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roles_label.add_theme_font_size_override("font_size", 10)
	_roles_label.add_theme_color_override("font_color", UI.TEXT_MUTED)
	stack.add_child(_roles_label)

	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", UI.line_style(Color(UI.FROST, 0.34), 1))
	stack.add_child(divider)

	for index in range(3):
		var suggestion_row := _build_suggestion_row(index)
		_suggestion_rows.append(suggestion_row)
		stack.add_child(suggestion_row)
	set_expanded(false)


func _build_curve_bucket(label_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(36.0, 32.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bucket_style := UI.inset_style(Color(0.022, 0.026, 0.034, 0.94), Color(UI.BRASS_DARK, 0.68), 3)
	bucket_style.content_margin_left = 3.0
	bucket_style.content_margin_right = 3.0
	bucket_style.content_margin_top = 2.0
	bucket_style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", bucket_style)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -2)
	panel.add_child(stack)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", UI.TEXT_MUTED)
	stack.add_child(label)
	var count := Label.new()
	count.name = "CurveCount_%s" % label_text.replace("–", "_").replace("+", "plus")
	count.text = "0"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	count.add_theme_font_size_override("font_size", 12)
	count.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	stack.add_child(count)
	_curve_counts.append(count)
	return panel


func _build_suggestion_row(index: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "DeckAdvisorSuggestion%d" % (index + 1)
	row.custom_minimum_size.y = 40.0
	row.add_theme_constant_override("separation", 6)
	var bar := ColorRect.new()
	bar.custom_minimum_size.x = 3.0
	bar.color = UI.TEXT_MUTED
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	_suggestion_bars.append(bar)
	var body := Label.new()
	body.name = "SuggestionBody"
	body.custom_minimum_size.y = 40.0
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = 3
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_theme_font_size_override("font_size", 9)
	body.add_theme_color_override("font_color", UI.PARCHMENT)
	row.add_child(body)
	_suggestion_bodies.append(body)
	return row


func _apply_analysis(analysis: Dictionary) -> void:
	var curve_variant: Variant = analysis.get("curve", {})
	var curve := curve_variant as Dictionary if curve_variant is Dictionary else {}
	var buckets_variant: Variant = curve.get("buckets", [])
	var buckets := buckets_variant as Array if buckets_variant is Array else []
	for index in range(_curve_counts.size()):
		var bucket := buckets[index] as Dictionary if index < buckets.size() and buckets[index] is Dictionary else {}
		_curve_counts[index].text = str(maxi(0, int(bucket.get("count", 0))))
	_average_label.text = tr("AVG. %.1f") % float(curve.get("average_energy", 0.0))
	var roles_variant: Variant = analysis.get("roles", {})
	var roles := roles_variant as Dictionary if roles_variant is Dictionary else {}
	_roles_label.text = tr("FRONT %d • PRESSURE %d • CONTROL %d • SUSTAIN %d • RESOURCE %d • SUPPORT %d") % [
		int(roles.get("frontline", 0)),
		int(roles.get("pressure", 0)),
		int(roles.get("control", 0)),
		int(roles.get("sustain", 0)),
		int(roles.get("resource", 0)),
		int(roles.get("support", 0)),
	]
	var suggestions_variant: Variant = analysis.get("suggestions", [])
	var suggestions := suggestions_variant as Array if suggestions_variant is Array else []
	for index in range(_suggestion_bodies.size()):
		var suggestion := suggestions[index] as Dictionary if index < suggestions.size() and suggestions[index] is Dictionary else {}
		var title_text := tr(str(suggestion.get("title_key", "")))
		var args_variant: Variant = suggestion.get("body_args", [])
		var args: Array = (args_variant as Array).duplicate(true) if args_variant is Array else []
		var translate_indexes_variant: Variant = suggestion.get("translate_arg_indexes", [])
		var translate_indexes: Array = translate_indexes_variant as Array if translate_indexes_variant is Array else []
		for arg_index_variant in translate_indexes:
			var arg_index := int(arg_index_variant)
			if arg_index >= 0 and arg_index < args.size():
				args[arg_index] = tr(str(args[arg_index]))
		var body_text := tr(str(suggestion.get("body_key", "")))
		if not args.is_empty():
			body_text = body_text % args
		var rendered := "%s  •  %s" % [title_text, body_text]
		_suggestion_bodies[index].text = rendered
		_suggestion_bodies[index].tooltip_text = rendered
		var accent := _tone_color(str(suggestion.get("tone", "neutral")))
		_suggestion_bars[index].color = accent


func _tone_color(tone: String) -> Color:
	match tone:
		"solid":
			return Color(0.42, 0.84, 0.62)
		"consider":
			return Color(0.92, 0.61, 0.35)
		"identity":
			return Color(0.64, 0.50, 0.92)
		_:
			return Color(0.50, 0.82, 0.92)
