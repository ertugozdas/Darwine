class_name ScenarioCampaignPanel extends Control

signal closed
signal scenario_requested(scenario_id: String)

const UI := preload("res://scripts/dark_fantasy_ui.gd")
const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")
const OBJECTIVE_RESOLVER := preload("res://scripts/scenario_objective_resolver.gd")

var _profile_manager: Node = null
var _campaign: Dictionary = {}
var _scenarios: Array[Dictionary] = []
var _selected_scenario_id := ""
var _scenario_list: VBoxContainer
var _progress_label: Label
var _seal_label: Label
var _detail_title: Label
var _detail_status: Label
var _detail_summary: Label
var _detail_setup: Label
var _objectives_list: VBoxContainer
var _reward_label: Label
var _start_button: Button
var _scenario_button_group := ButtonGroup.new()


func _ready() -> void:
	name = "ScenarioCampaignOverlay"
	z_index = 620
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	theme = UI.create_theme()
	if not _profile_manager:
		_profile_manager = get_node_or_null("/root/ProfileManager")
	_build_interface()
	_connect_profile_manager()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func open_panel() -> void:
	var result := SCENARIO_CATALOG.load_catalog()
	if not bool(result.get("success", false)):
		_show_catalog_error(str(result.get("error", tr("Scenario catalog could not be loaded."))))
		visible = true
		return
	_campaign = SCENARIO_CATALOG.get_campaign()
	_scenarios = SCENARIO_CATALOG.get_scenarios()
	_select_recommended_scenario()
	_refresh()
	visible = true
	modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(
		self,
		"modulate:a",
		1.0,
		0.16
	)
	_focus_selected_button()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func get_scenario_count() -> int:
	return _scenarios.size()


func get_selected_scenario_id() -> String:
	return _selected_scenario_id


func configure_profile_manager(manager: Node) -> void:
	var callback := Callable(self, "_refresh")
	if _profile_manager and _profile_manager.has_signal("profile_changed") and _profile_manager.is_connected("profile_changed", callback):
		_profile_manager.disconnect("profile_changed", callback)
	_profile_manager = manager
	_connect_profile_manager()
	if is_node_ready():
		_refresh()


func refresh() -> void:
	_refresh()


func _build_interface() -> void:
	var dim := ColorRect.new()
	dim.name = "ScenarioCampaignDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.003, 0.005, 0.008, 0.95)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var shell := PanelContainer.new()
	shell.name = "ScenarioCampaignPanel"
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 28.0
	shell.offset_top = 22.0
	shell.offset_right = -28.0
	shell.offset_bottom = -22.0
	shell.add_theme_stylebox_override("panel", UI.panel_style(UI.BRASS, 23.0, 1.0))
	add_child(shell)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	shell.add_child(root_box)
	root_box.add_child(_build_header())

	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", UI.line_style(Color(UI.BRASS, 0.50), 1))
	root_box.add_child(rule)

	var body := HBoxContainer.new()
	body.name = "ScenarioCampaignBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root_box.add_child(body)
	body.add_child(_build_scenario_navigation())
	body.add_child(_build_scenario_detail())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "ScenarioCampaignHeader"
	header.custom_minimum_size.y = 68.0
	header.add_theme_constant_override("separation", 14)

	var progress_box := VBoxContainer.new()
	progress_box.custom_minimum_size.x = 190.0
	progress_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(progress_box)
	_progress_label = _muted_label("0 / 6", 19)
	_progress_label.name = "ScenarioCampaignProgress"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_progress_label.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	progress_box.add_child(_progress_label)
	var progress_caption := _muted_label(tr("SCENARIOS COMPLETED"), 10)
	progress_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_box.add_child(progress_caption)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 1)
	header.add_child(copy)
	var eyebrow := _muted_label(tr("v0.7 • GUIDED SINGLE-PLAYER CAMPAIGN"), 10)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", UI.FROST)
	copy.add_child(eyebrow)
	var title := Label.new()
	title.name = "ScenarioCampaignHeading"
	title.text = tr("COMMANDER'S CAMPAIGN")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	UI.style_title(title, UI.PARCHMENT)
	copy.add_child(title)
	var subtitle := _muted_label(tr("Learn the battlefield through six fixed tactical scenarios."), 12)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(subtitle)

	var currency_box := VBoxContainer.new()
	currency_box.custom_minimum_size.x = 130.0
	currency_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(currency_box)
	_seal_label = _muted_label("0", 18)
	_seal_label.name = "ScenarioCampaignSeals"
	_seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seal_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_seal_label.add_theme_color_override("font_color", UI.FROST)
	currency_box.add_child(_seal_label)
	var seal_caption := _muted_label(tr("SEALS"), 10)
	seal_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	currency_box.add_child(seal_caption)

	var close_button := Button.new()
	close_button.name = "ScenarioCampaignCloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(44.0, 44.0)
	close_button.add_theme_font_size_override("font_size", 24)
	UI.style_button(close_button, UI.BRASS, false, true)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)
	return header


func _build_scenario_navigation() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ScenarioCampaignNavigation"
	panel.custom_minimum_size.x = 335.0
	panel.add_theme_stylebox_override(
		"panel",
		UI.inset_style(Color(0.012, 0.015, 0.020, 0.98), UI.BRASS, 6)
	)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading := _muted_label(tr("CAMPAIGN MAP"), 11)
	heading.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	box.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.name = "ScenarioCampaignScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_scenario_list = VBoxContainer.new()
	_scenario_list.name = "ScenarioCampaignList"
	_scenario_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scenario_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_scenario_list)
	return panel


func _build_scenario_detail() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ScenarioCampaignDetail"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		UI.inset_style(Color(0.014, 0.018, 0.024, 0.98), UI.FROST, 6)
	)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	box.add_child(title_row)
	_detail_title = Label.new()
	_detail_title.name = "ScenarioDetailTitle"
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.add_theme_font_size_override("font_size", 27)
	UI.style_title(_detail_title, UI.PARCHMENT)
	title_row.add_child(_detail_title)
	_detail_status = _muted_label("", 11)
	_detail_status.name = "ScenarioDetailStatus"
	_detail_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_detail_status)

	_detail_summary = _muted_label("", 16)
	_detail_summary.name = "ScenarioDetailSummary"
	_detail_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_summary.add_theme_color_override("font_color", Color(UI.PARCHMENT, 0.86))
	box.add_child(_detail_summary)

	_detail_setup = _muted_label("", 12)
	_detail_setup.name = "ScenarioDetailSetup"
	_detail_setup.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_setup.add_theme_color_override("font_color", UI.FROST)
	box.add_child(_detail_setup)

	var objective_heading := _muted_label(tr("REQUIRED OBJECTIVES"), 11)
	objective_heading.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	box.add_child(objective_heading)
	_objectives_list = VBoxContainer.new()
	_objectives_list.name = "ScenarioObjectiveList"
	_objectives_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_objectives_list.add_theme_constant_override("separation", 7)
	box.add_child(_objectives_list)

	var footer_rule := HSeparator.new()
	footer_rule.add_theme_stylebox_override("separator", UI.line_style(Color(UI.FROST, 0.34), 1))
	box.add_child(footer_rule)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	box.add_child(footer)
	_reward_label = _muted_label("", 14)
	_reward_label.name = "ScenarioRewardLabel"
	_reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_label.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	footer.add_child(_reward_label)
	_start_button = Button.new()
	_start_button.name = "ScenarioStartButton"
	_start_button.text = tr("BEGIN CAMPAIGN")
	_start_button.custom_minimum_size = Vector2(230.0, 48.0)
	_start_button.add_theme_font_size_override("font_size", 15)
	UI.style_button(_start_button, UI.BRASS_BRIGHT, false, false, true)
	_start_button.pressed.connect(_on_start_pressed)
	footer.add_child(_start_button)
	return panel


func _refresh() -> void:
	if not is_node_ready() or _scenario_list == null:
		return
	if _scenarios.is_empty():
		var result := SCENARIO_CATALOG.load_catalog()
		if not bool(result.get("success", false)):
			_show_catalog_error(str(result.get("error", tr("Scenario catalog could not be loaded."))))
			return
		_campaign = SCENARIO_CATALOG.get_campaign()
		_scenarios = SCENARIO_CATALOG.get_scenarios()
		_select_recommended_scenario()
	_refresh_header()
	_rebuild_scenario_list()
	_refresh_detail()


func _refresh_header() -> void:
	var completed_count := 0
	for scenario in _scenarios:
		if bool(_scenario_state(str(scenario.get("id", ""))).get("completed", false)):
			completed_count += 1
	_progress_label.text = "%d / %d" % [completed_count, _scenarios.size()]
	var seals := 0
	if _profile_manager and _profile_manager.has_method("get_profile"):
		seals = int(_profile_manager.get_profile().get("seals", 0))
	_seal_label.text = str(seals)


func _rebuild_scenario_list() -> void:
	for child in _scenario_list.get_children():
		_scenario_list.remove_child(child)
		child.queue_free()
	for scenario in _scenarios:
		var scenario_id := str(scenario.get("id", ""))
		var unlocked := _is_unlocked(scenario)
		var completed := bool(_scenario_state(scenario_id).get("completed", false))
		var button := Button.new()
		button.name = "ScenarioButton_%s" % scenario_id
		button.toggle_mode = true
		button.button_group = _scenario_button_group
		button.button_pressed = scenario_id == _selected_scenario_id
		button.custom_minimum_size.y = 58.0
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		var status := tr("COMPLETED") if completed else (tr("AVAILABLE") if unlocked else tr("LOCKED"))
		var marker := "✓" if completed else ("◆" if unlocked else "×")
		button.text = "%02d  %s\n     %s  •  %s" % [
			int(scenario.get("order", 0)),
			tr(str(scenario.get("title", scenario_id))),
			marker,
			status,
		]
		button.tooltip_text = tr(str(scenario.get("summary", "")))
		button.disabled = not unlocked
		UI.style_button(button, UI.MOSS if completed else UI.FROST, false, true)
		button.pressed.connect(_select_scenario.bind(scenario_id))
		_scenario_list.add_child(button)


func _refresh_detail() -> void:
	var scenario := _selected_scenario()
	if scenario.is_empty():
		_show_catalog_error(tr("No playable scenario was found."))
		return
	var scenario_id := str(scenario.get("id", ""))
	var unlocked := _is_unlocked(scenario)
	var state := _scenario_state(scenario_id)
	var completed := bool(state.get("completed", false))
	_detail_title.text = "%02d • %s" % [int(scenario.get("order", 0)), tr(str(scenario.get("title", scenario_id)))]
	_detail_summary.text = tr(str(scenario.get("summary", "")))
	_detail_status.text = tr("COMPLETED") if completed else (tr("AVAILABLE") if unlocked else tr("LOCKED"))
	_detail_status.add_theme_color_override(
		"font_color",
		UI.MOSS.lightened(0.30) if completed else (UI.FROST if unlocked else UI.TEXT_MUTED)
	)
	_detail_setup.text = _setup_description(scenario)
	_rebuild_objectives(scenario, state)
	_reward_label.text = _reward_description(scenario, completed)
	_start_button.disabled = not unlocked
	_start_button.text = tr("REPLAY SCENARIO") if completed else tr("BEGIN CAMPAIGN")


func _rebuild_objectives(scenario: Dictionary, state: Dictionary) -> void:
	for child in _objectives_list.get_children():
		_objectives_list.remove_child(child)
		child.queue_free()
	var previous_results := {}
	var evaluation_variant: Variant = state.get("last_evaluation", {})
	if evaluation_variant is Dictionary:
		for result_variant in (evaluation_variant as Dictionary).get("objective_results", []) as Array:
			if result_variant is Dictionary:
				previous_results[str((result_variant as Dictionary).get("id", ""))] = result_variant
	for objective_variant in scenario.get("objectives", []) as Array:
		if not objective_variant is Dictionary:
			continue
		var objective := objective_variant as Dictionary
		var objective_id := str(objective.get("id", ""))
		var result_variant: Variant = previous_results.get(objective_id, {})
		var result: Dictionary = result_variant as Dictionary if result_variant is Dictionary else {}
		var objective_panel := PanelContainer.new()
		objective_panel.add_theme_stylebox_override(
			"panel",
			UI.inset_style(Color(0.010, 0.014, 0.018, 0.94), UI.MOSS if bool(result.get("completed", false)) else UI.BRASS_DARK, 4)
		)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		objective_panel.add_child(row)
		var marker := _muted_label("✓" if bool(result.get("completed", false)) else "◇", 18)
		marker.custom_minimum_size.x = 28.0
		marker.add_theme_color_override("font_color", UI.MOSS.lightened(0.30) if bool(result.get("completed", false)) else UI.BRASS_BRIGHT)
		row.add_child(marker)
		var metric := str(objective.get("metric", ""))
		var objective_copy := _muted_label(_objective_description(objective), 15)
		objective_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		objective_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective_copy.add_theme_color_override("font_color", UI.PARCHMENT)
		row.add_child(objective_copy)
		var progress := _muted_label("", 12)
		progress.custom_minimum_size.x = 130.0
		progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if not result.is_empty():
			progress.text = _localized_progress(result)
		elif metric == "match_won":
			progress.text = tr("PENDING")
		else:
			progress.text = "0 / %d" % int(objective.get("target", 0))
		row.add_child(progress)
		_objectives_list.add_child(objective_panel)


func _select_recommended_scenario() -> void:
	if not _selected_scenario_id.is_empty():
		var current := SCENARIO_CATALOG.get_scenario(_selected_scenario_id)
		if not current.is_empty() and _is_unlocked(current):
			return
	_selected_scenario_id = ""
	for scenario in _scenarios:
		if _is_unlocked(scenario) and not bool(_scenario_state(str(scenario.get("id", ""))).get("completed", false)):
			_selected_scenario_id = str(scenario.get("id", ""))
			return
	for scenario in _scenarios:
		if _is_unlocked(scenario):
			_selected_scenario_id = str(scenario.get("id", ""))
			return


func _select_scenario(scenario_id: String) -> void:
	var scenario := SCENARIO_CATALOG.get_scenario(scenario_id)
	if scenario.is_empty() or not _is_unlocked(scenario):
		return
	_selected_scenario_id = scenario_id
	_refresh_detail()


func _on_start_pressed() -> void:
	var scenario := _selected_scenario()
	if scenario.is_empty() or not _is_unlocked(scenario):
		return
	scenario_requested.emit(_selected_scenario_id)


func _selected_scenario() -> Dictionary:
	return SCENARIO_CATALOG.get_scenario(_selected_scenario_id)


func _scenario_state(scenario_id: String) -> Dictionary:
	if not _profile_manager or not _profile_manager.has_method("get_scenario_state"):
		return {}
	return _profile_manager.get_scenario_state(str(_campaign.get("campaign_id", "")), scenario_id)


func _is_unlocked(scenario: Dictionary) -> bool:
	if not _profile_manager or not _profile_manager.has_method("is_scenario_unlocked"):
		var unlock_variant: Variant = scenario.get("unlock", {})
		return unlock_variant is Dictionary and ((unlock_variant as Dictionary).get("requires", []) as Array).is_empty()
	return _profile_manager.is_scenario_unlocked(str(_campaign.get("campaign_id", "")), scenario)


func _setup_description(scenario: Dictionary) -> String:
	var setup_variant: Variant = scenario.get("setup", {})
	var setup: Dictionary = setup_variant as Dictionary if setup_variant is Dictionary else {}
	var ruleset_name := tr("DOMINION") if str(scenario.get("ruleset", "")) == "dominion" else tr("SIEGE")
	var difficulty_names := {
		"easy": tr("EASY"),
		"medium": tr("MEDIUM"),
		"hard": tr("HARD"),
	}
	var difficulty := str(difficulty_names.get(str(setup.get("ai_difficulty", "medium")), tr("MEDIUM")))
	var deck_manager := get_node_or_null("/root/DeckManager")
	var deck_name := str(setup.get("player_deck_id", ""))
	if deck_manager and deck_manager.has_method("get_deck"):
		deck_name = str(deck_manager.get_deck(deck_name).get("name", deck_name))
	return tr("%s • %s opponent • %s deck • %d sec turns") % [
		ruleset_name,
		difficulty,
		tr(deck_name),
		int(setup.get("turn_duration_seconds", 120)),
	]


func _objective_description(objective: Dictionary) -> String:
	var metric := str(objective.get("metric", ""))
	if metric == "match_won":
		return tr("Win the match")
	var label := tr(OBJECTIVE_RESOLVER.metric_label(metric))
	var target := int(objective.get("target", 0))
	var operator := str(objective.get("operator", "at_least"))
	if operator == "at_most":
		return tr("%s: at most %d") % [label, target]
	if operator == "equals":
		return tr("%s: exactly %d") % [label, target]
	return tr("%s: at least %d") % [label, target]


func _reward_description(scenario: Dictionary, completed: bool) -> String:
	var reward_variant: Variant = scenario.get("reward", {})
	var reward: Dictionary = reward_variant as Dictionary if reward_variant is Dictionary else {}
	if str(reward.get("kind", "")) == "seals":
		var amount := int(reward.get("amount", 0))
		return (
			tr("First completion reward claimed: %d Seals") % amount
			if completed
			else tr("First completion reward: %d Seals") % amount
		)
	return tr("Cosmetic first-completion reward")


func _localized_progress(result: Dictionary) -> String:
	if str(result.get("metric", "")) == "match_won":
		return tr("COMPLETED") if bool(result.get("completed", false)) else tr("PENDING")
	var value := int(round(float(result.get("value", 0.0))))
	var target := int(round(float(result.get("target", 0.0))))
	match str(result.get("operator", "at_least")):
		"at_most": return tr("%d / at most %d") % [value, target]
		"equals": return tr("%d / exactly %d") % [value, target]
		_: return "%d / %d" % [mini(value, target), target]


func _show_catalog_error(message: String) -> void:
	if _detail_title:
		_detail_title.text = tr("CAMPAIGN UNAVAILABLE")
	if _detail_summary:
		_detail_summary.text = message
	if _detail_status:
		_detail_status.text = tr("ERROR")
	if _start_button:
		_start_button.disabled = true


func _focus_selected_button() -> void:
	for child in _scenario_list.get_children():
		if child is Button and str(child.name) == "ScenarioButton_%s" % _selected_scenario_id:
			(child as Button).grab_focus()
			return
	var close_button := find_child("ScenarioCampaignCloseButton", true, false) as Button
	if close_button:
		close_button.grab_focus()


func _connect_profile_manager() -> void:
	if not _profile_manager or not _profile_manager.has_signal("profile_changed"):
		return
	var callback := Callable(self, "_refresh")
	if not _profile_manager.is_connected("profile_changed", callback):
		_profile_manager.connect("profile_changed", callback)


func _muted_label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UI.TEXT_MUTED)
	return label
