class_name CommanderProfilePanel extends Control

signal closed

const UI := preload("res://scripts/dark_fantasy_ui.gd")

var _profile_manager: Node
var _commander_name: LineEdit
var _title_label: Label
var _banner_label: Label
var _level_label: Label
var _seal_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _tabs: TabContainer
var _stats_values: Dictionary = {}
var _achievement_list: VBoxContainer
var _daily_mission_list: VBoxContainer
var _weekly_mission_list: VBoxContainer
var _history_list: VBoxContainer
var _title_option: OptionButton
var _banner_option: OptionButton


func _ready() -> void:
	name = "ProfileOverlay"
	theme = UI.create_theme()
	z_index = 610
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_profile_manager = get_node_or_null("/root/ProfileManager")
	_build_interface()
	if _profile_manager:
		var callback := Callable(self, "_refresh")
		if not _profile_manager.is_connected("profile_changed", callback):
			_profile_manager.connect("profile_changed", callback)


func open_panel(tab_index: int = 0) -> void:
	_refresh()
	visible = true
	if _tabs:
		_tabs.current_tab = clampi(tab_index, 0, _tabs.get_tab_count() - 1)
	modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	if _commander_name:
		_commander_name.grab_focus()


func close_panel() -> void:
	_commit_commander_name()
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _build_interface() -> void:
	var dim := ColorRect.new()
	dim.name = "ProfileDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.003, 0.005, 0.009, UI.MODAL_DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var shell := PanelContainer.new()
	shell.name = "ProfilePanel"
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 28.0
	shell.offset_top = 22.0
	shell.offset_right = -28.0
	shell.offset_bottom = -22.0
	shell.add_theme_stylebox_override("panel", UI.panel_style(UI.FROST, 23.0, 1.0))
	add_child(shell)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 9)
	shell.add_child(root_box)
	root_box.add_child(_build_header())
	root_box.add_child(_build_experience_strip())

	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", UI.line_style(Color(UI.BRASS, 0.48), 1))
	root_box.add_child(rule)

	_tabs = TabContainer.new()
	_tabs.name = "ProfileTabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	_tabs.add_theme_font_override("font", UI.DISPLAY_FONT)
	_tabs.add_theme_font_size_override("font_size", 14)
	root_box.add_child(_tabs)
	_tabs.add_child(_build_overview_page())
	_tabs.add_child(_build_missions_page())
	_tabs.add_child(_build_history_page())
	_tabs.set_tab_title(0, "KOMUTANLIK")
	_tabs.set_tab_title(1, "GÖREVLER")
	_tabs.set_tab_title(2, "MAÇ GEÇMİŞİ")


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "ProfileHeader"
	header.add_theme_constant_override("separation", 14)
	var header_balance := Control.new()
	header_balance.name = "ProfileHeaderBalance"
	# Balance the level summary and close button so the profile copy is truly centered.
	header_balance.custom_minimum_size.x = 198.0
	header.add_child(header_balance)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	header.add_child(copy)
	var eyebrow := Label.new()
	eyebrow.text = "YATAY İLERLEME • KART GÜCÜNDEN BAĞIMSIZ"
	eyebrow.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", UI.FROST)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(eyebrow)
	var heading := Label.new()
	heading.name = "ProfileHeading"
	heading.text = "KOMUTAN PROFİLİ"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	UI.style_title(heading, UI.PARCHMENT)
	copy.add_child(heading)
	var identity := HBoxContainer.new()
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 10)
	copy.add_child(identity)
	_commander_name = LineEdit.new()
	_commander_name.name = "ProfileCommanderName"
	_commander_name.max_length = 24
	_commander_name.custom_minimum_size = Vector2(220.0, 34.0)
	_commander_name.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_commander_name.add_theme_font_size_override("font_size", 15)
	_commander_name.add_theme_stylebox_override("normal", UI.inset_style(Color(0.018, 0.024, 0.032, 0.94), UI.FROST))
	_commander_name.add_theme_stylebox_override("focus", UI.inset_style(Color(0.025, 0.035, 0.046, 1.0), UI.FROST))
	_commander_name.text_submitted.connect(func(_value: String): _commit_commander_name())
	_commander_name.focus_exited.connect(_commit_commander_name)
	identity.add_child(_commander_name)
	_title_label = _muted_label("Sancak Taşıyıcısı", 13)
	_title_label.name = "ProfileActiveTitle"
	_title_label.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	identity.add_child(_title_label)
	_banner_label = _muted_label("• Kül ve Pirinç", 13)
	_banner_label.name = "ProfileActiveBanner"
	identity.add_child(_banner_label)

	var currency := VBoxContainer.new()
	currency.custom_minimum_size.x = 140.0
	currency.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(currency)
	_level_label = Label.new()
	_level_label.name = "ProfileLevelLabel"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 20)
	UI.style_title(_level_label, UI.BRASS_BRIGHT)
	currency.add_child(_level_label)
	_seal_label = _muted_label("0 Mühür", 13)
	_seal_label.name = "ProfileSealLabel"
	_seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seal_label.add_theme_color_override("font_color", Color(0.58, 0.84, 0.94))
	currency.add_child(_seal_label)

	var close_button := Button.new()
	close_button.name = "ProfileCloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(44.0, 44.0)
	close_button.add_theme_font_size_override("font_size", 24)
	UI.style_button(close_button, UI.FROST, false, true)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)
	return header


func _build_experience_strip() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ProfileExperienceStrip"
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.014, 0.019, 0.026, 0.96), UI.FROST, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var label := _muted_label("KOMUTANLIK DENEYİMİ", 10)
	label.custom_minimum_size.x = 170.0
	label.add_theme_color_override("font_color", UI.FROST)
	row.add_child(label)
	_xp_bar = ProgressBar.new()
	_xp_bar.name = "ProfileXPBar"
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.custom_minimum_size.y = 22.0
	_xp_bar.show_percentage = false
	_xp_bar.add_theme_stylebox_override("background", UI.inset_style(Color(0.007, 0.010, 0.014, 0.96), UI.BRASS_DARK, 4))
	_xp_bar.add_theme_stylebox_override("fill", UI.inset_style(Color(0.12, 0.38, 0.52, 0.96), UI.FROST, 4))
	row.add_child(_xp_bar)
	_xp_label = _muted_label("0 / 100 XP", 12)
	_xp_label.name = "ProfileXPLabel"
	_xp_label.custom_minimum_size.x = 130.0
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_xp_label)
	return panel


func _build_overview_page() -> Control:
	var page := MarginContainer.new()
	page.name = "Komutanlik"
	page.add_theme_constant_override("margin_top", 12)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	page.add_child(content)

	var stats := GridContainer.new()
	stats.name = "ProfileStatsGrid"
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 8)
	content.add_child(stats)
	for definition in [
		["matches", "MAÇ"], ["wins", "ZAFER"], ["win_rate", "ZAFER ORANI"],
		["best_streak", "EN İYİ SERİ"], ["hq_damage", "HQ HASARI"], ["cards_played", "KART"],
		["dominion_matches", "HAKİMİYET MAÇ"], ["dominion_wins", "HAK. ZAFER"], ["dominion_points", "HAK. PUAN"],
	]:
		stats.add_child(_build_stat_card(str(definition[0]), str(definition[1])))

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	var achievements_panel := _section_panel("BAŞARILAR", "Kalıcı kayıtlar ve yalnızca kozmetik ödüller")
	achievements_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(achievements_panel)
	var achievement_content := achievements_panel.get_node("Content") as VBoxContainer
	var achievement_scroll := ScrollContainer.new()
	achievement_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	achievement_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	achievement_content.add_child(achievement_scroll)
	_achievement_list = VBoxContainer.new()
	_achievement_list.name = "AchievementList"
	_achievement_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievement_list.add_theme_constant_override("separation", 7)
	achievement_scroll.add_child(_achievement_list)

	var cosmetics_panel := _section_panel("SANCAK ODASI", "Seçimler yalnızca görünümü değiştirir")
	cosmetics_panel.custom_minimum_size.x = 360.0
	columns.add_child(cosmetics_panel)
	var cosmetics := cosmetics_panel.get_node("Content") as VBoxContainer
	cosmetics.add_child(_field_label("AKTİF UNVAN"))
	_title_option = OptionButton.new()
	_title_option.name = "ProfileTitleOption"
	_title_option.custom_minimum_size.y = 42.0
	_title_option.item_selected.connect(_on_title_selected)
	cosmetics.add_child(_title_option)
	cosmetics.add_child(_field_label("AKTİF SANCAK"))
	_banner_option = OptionButton.new()
	_banner_option.name = "ProfileBannerOption"
	_banner_option.custom_minimum_size.y = 42.0
	_banner_option.item_selected.connect(_on_banner_selected)
	cosmetics.add_child(_banner_option)
	var note := _muted_label("Yeni unvan ve sancaklar seviye, başarı ve görevlerden gelir. Kart, Enerji veya savaş gücü vermez.", 12)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.y = 58.0
	cosmetics.add_child(note)
	return page


func _build_missions_page() -> Control:
	var page := MarginContainer.new()
	page.name = "Gorevler"
	page.add_theme_constant_override("margin_top", 12)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	page.add_child(columns)
	var daily_panel := _section_panel("GÜNLÜK GÖREVLER", "Her gün yenilenir • tamamlanınca Mühür otomatik eklenir")
	daily_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(daily_panel)
	_daily_mission_list = _mission_list_for_panel(daily_panel, "DailyMissionList")
	var weekly_panel := _section_panel("HAFTALIK GÖREVLER", "Uzun vadeli hedefler • rekabet gücü sağlamaz")
	weekly_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(weekly_panel)
	_weekly_mission_list = _mission_list_for_panel(weekly_panel, "WeeklyMissionList")
	return page


func _build_history_page() -> Control:
	var page := MarginContainer.new()
	page.name = "MacGecmisi"
	page.add_theme_constant_override("margin_top", 12)
	var panel := _section_panel("SON 30 MAÇ", "Sonuç, deste, süre ve kişisel savaş katkısı")
	page.add_child(panel)
	var content := panel.get_node("Content") as VBoxContainer
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_history_list = VBoxContainer.new()
	_history_list.name = "MatchHistoryList"
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_history_list)
	return page


func _build_stat_card(key: String, title: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.016, 0.020, 0.026, 0.96), UI.BRASS, 5))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var value := Label.new()
	value.name = "ProfileStat%s" % key.to_pascal_case()
	value.text = "0"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 21)
	UI.style_title(value, UI.BRASS_BRIGHT)
	box.add_child(value)
	var label := _muted_label(title, 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	_stats_values[key] = value
	return panel


func _section_panel(title: String, subtitle: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.011, 0.014, 0.019, 0.95), UI.BRASS_DARK, 6))
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	UI.style_title(title_label, UI.PARCHMENT)
	content.add_child(title_label)
	content.add_child(_muted_label(subtitle, 11))
	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", UI.line_style(Color(UI.BRASS, 0.32), 1))
	content.add_child(rule)
	return panel


func _mission_list_for_panel(panel: PanelContainer, node_name: String) -> VBoxContainer:
	var content := panel.get_node("Content") as VBoxContainer
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = node_name
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list


func _refresh() -> void:
	if not _profile_manager or not _commander_name:
		return
	var profile: Dictionary = _profile_manager.get_profile()
	var stats: Dictionary = profile.get("stats", {}) as Dictionary
	var progress: Dictionary = _profile_manager.get_level_progress()
	_commander_name.text = str(profile.get("commander_name", "Komutan"))
	_level_label.text = tr("LEVEL %d") % int(profile.get("level", 1))
	_seal_label.text = tr("%d SEALS") % int(profile.get("seals", 0))
	_xp_bar.max_value = int(progress.get("required_xp", 100))
	_xp_bar.value = int(progress.get("current_xp", 0))
	_xp_label.text = "%d / %d XP" % [int(progress.get("current_xp", 0)), int(progress.get("required_xp", 100))]
	_title_label.text = tr(_profile_manager.get_cosmetic_name("title", str(profile.get("selected_title", "sancak_tasiyicisi"))))
	_banner_label.text = "• %s" % tr(_profile_manager.get_cosmetic_name("banner", str(profile.get("selected_banner", "kul_ve_pirinc"))))
	_set_stat("matches", int(stats.get("matches", 0)))
	_set_stat("wins", int(stats.get("wins", 0)))
	var match_count := int(stats.get("matches", 0))
	var win_rate := int(round(float(stats.get("wins", 0)) * 100.0 / float(maxi(1, match_count))))
	_set_stat("win_rate", "%d%%" % win_rate)
	_set_stat("best_streak", int(stats.get("best_streak", 0)))
	_set_stat("hq_damage", int(stats.get("hq_damage", 0)))
	_set_stat("cards_played", int(stats.get("cards_played", 0)))
	_set_stat("dominion_matches", int(stats.get("dominion_matches", 0)))
	_set_stat("dominion_wins", int(stats.get("dominion_wins", 0)))
	_set_stat("dominion_points", int(stats.get("dominion_points", 0)))
	_refresh_cosmetics(profile)
	_refresh_achievements()
	_refresh_missions()
	_refresh_history()


func _refresh_cosmetics(profile: Dictionary) -> void:
	_title_option.clear()
	var title_index := 0
	for entry_variant in _profile_manager.get_unlocked_titles():
		var entry := entry_variant as Dictionary
		_title_option.add_item(tr(str(entry.get("name", "Unvan"))))
		_title_option.set_item_metadata(_title_option.item_count - 1, str(entry.get("id", "")))
		if str(entry.get("id", "")) == str(profile.get("selected_title", "")):
			title_index = _title_option.item_count - 1
	_title_option.select(title_index)
	_banner_option.clear()
	var banner_index := 0
	for entry_variant in _profile_manager.get_unlocked_banners():
		var entry := entry_variant as Dictionary
		_banner_option.add_item(tr(str(entry.get("name", "Sancak"))))
		_banner_option.set_item_metadata(_banner_option.item_count - 1, str(entry.get("id", "")))
		if str(entry.get("id", "")) == str(profile.get("selected_banner", "")):
			banner_index = _banner_option.item_count - 1
	_banner_option.select(banner_index)


func _refresh_achievements() -> void:
	_clear_children(_achievement_list)
	for entry_variant in _profile_manager.get_achievement_entries():
		var entry := entry_variant as Dictionary
		var complete := bool(entry.get("completed", false))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.inset_style(
			Color(0.025, 0.055, 0.042, 0.96) if complete else Color(0.018, 0.020, 0.025, 0.96),
			UI.MOSS if complete else UI.BRASS_DARK,
			5
		))
		_achievement_list.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		var title := Label.new()
		title.text = "%s  %s" % ["✓" if complete else "◇", tr(str(entry.get("title", "Başarı")))]
		title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
		title.add_theme_color_override("font_color", Color(0.55, 0.90, 0.65) if complete else UI.PARCHMENT)
		copy.add_child(title)
		copy.add_child(_muted_label(tr(str(entry.get("description", ""))), 11))
		var progress := _muted_label("%d/%d\n%s" % [
			int(entry.get("progress", 0)), int(entry.get("target", 1)), tr(str(entry.get("reward_name", "")))
		], 11)
		progress.custom_minimum_size.x = 145.0
		progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(progress)


func _refresh_missions() -> void:
	_refresh_mission_list(_daily_mission_list, _profile_manager.get_mission_entries("daily"))
	_refresh_mission_list(_weekly_mission_list, _profile_manager.get_mission_entries("weekly"))


func _refresh_mission_list(list: VBoxContainer, entries: Array) -> void:
	_clear_children(list)
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		var complete := bool(entry.get("completed", false))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.inset_style(
			Color(0.023, 0.050, 0.040, 0.96) if complete else Color(0.017, 0.020, 0.026, 0.96),
			UI.MOSS if complete else UI.FROST,
			5
		))
		list.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		panel.add_child(box)
		var header := HBoxContainer.new()
		box.add_child(header)
		var title := Label.new()
		title.text = "%s%s" % ["✓ " if complete else "", tr(str(entry.get("title", "Görev")))]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
		header.add_child(title)
		var reward := _muted_label(tr("+%d Seals") % int(entry.get("reward", 0)), 11)
		reward.add_theme_color_override("font_color", Color(0.52, 0.84, 0.94))
		header.add_child(reward)
		box.add_child(_muted_label(tr(str(entry.get("description", ""))), 11))
		var progress := ProgressBar.new()
		progress.max_value = int(entry.get("target", 1))
		progress.value = int(entry.get("progress", 0))
		progress.custom_minimum_size.y = 17.0
		progress.add_theme_font_size_override("font_size", 10)
		progress.add_theme_stylebox_override("background", UI.inset_style(Color(0.006, 0.008, 0.012, 0.96), UI.BRASS_DARK, 3))
		progress.add_theme_stylebox_override("fill", UI.inset_style(Color(0.18, 0.46, 0.34, 0.96) if complete else Color(0.10, 0.30, 0.42, 0.96), UI.MOSS if complete else UI.FROST, 3))
		box.add_child(progress)


func _refresh_history() -> void:
	_clear_children(_history_list)
	var history: Array = _profile_manager.get_history()
	if history.is_empty():
		var empty := _muted_label("Henüz kayıtlı maç yok. İlk savaşın burada ayrıntılarıyla görünecek.", 15)
		empty.custom_minimum_size.y = 90.0
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_history_list.add_child(empty)
		return
	for entry_variant in history:
		var entry := entry_variant as Dictionary
		var result_text := str(entry.get("result", "Maç"))
		var accent := UI.MOSS if result_text == "Zafer" else (UI.BRASS if result_text == "Beraberlik" else UI.BLOOD)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.016, 0.019, 0.025, 0.96), accent, 5))
		_history_list.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var result := Label.new()
		result.text = tr(result_text).to_upper()
		result.custom_minimum_size.x = 112.0
		result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		result.add_theme_font_size_override("font_size", 15)
		UI.style_title(result, accent.lightened(0.25))
		row.add_child(result)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		var headline := Label.new()
		headline.text = tr("%s • %s • %s • %d rounds") % [
			tr(str(entry.get("ruleset_name", "Kuşatma"))), tr(str(entry.get("mode", "Yerel"))),
			tr(str(entry.get("deck_name", "İsimsiz Deste"))), int(entry.get("rounds", 0))
		]
		headline.add_theme_font_override("font", UI.BODY_BOLD_FONT)
		copy.add_child(headline)
		copy.add_child(_muted_label(tr("%s • Featured: %s") % [
			_format_duration(float(entry.get("duration_seconds", 0.0))), tr(str(entry.get("mvp_card_name", "—")))
		], 11))
		var metrics_text := tr("%d cards  •  %d HQ damage  •  %d destroyed  •  +%d XP") % [
			int(entry.get("cards_played", 0)), int(entry.get("hq_damage", 0)),
			int(entry.get("cards_destroyed", 0)), int(entry.get("xp_gained", 0))
		]
		if int(entry.get("ruleset", MatchSetup.Ruleset.SIEGE)) == MatchSetup.Ruleset.DOMINION:
			metrics_text = tr("%d cards  •  Dominion %d–%d  •  %d lane points  •  +%d XP") % [
				int(entry.get("cards_played", 0)), int(entry.get("dominion_score", 0)),
				int(entry.get("opponent_dominion_score", 0)), int(entry.get("dominion_points", 0)),
				int(entry.get("xp_gained", 0)),
			]
		var metrics := _muted_label(metrics_text, 12)
		metrics.custom_minimum_size.x = 330.0
		metrics.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		metrics.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(metrics)


func _on_title_selected(index: int) -> void:
	if _profile_manager and index >= 0:
		_profile_manager.select_title(str(_title_option.get_item_metadata(index)))


func _on_banner_selected(index: int) -> void:
	if _profile_manager and index >= 0:
		_profile_manager.select_banner(str(_banner_option.get_item_metadata(index)))


func _commit_commander_name() -> void:
	if _profile_manager and _commander_name:
		_profile_manager.set_commander_name(_commander_name.text)


func _set_stat(key: String, value: Variant) -> void:
	if _stats_values.has(key):
		(_stats_values[key] as Label).text = str(value)


func _field_label(text_value: String) -> Label:
	var label := _muted_label(text_value, 10)
	label.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	return label


func _muted_label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UI.TEXT_MUTED)
	return label


func _clear_children(container: Node) -> void:
	if not container:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _format_duration(seconds: float) -> String:
	var total := maxi(0, int(round(seconds)))
	return "%02d:%02d" % [total / 60, total % 60]
