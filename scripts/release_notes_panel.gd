class_name ReleaseNotesPanel extends Control

signal closed

const UI := preload("res://scripts/dark_fantasy_ui.gd")

const RELEASES := [
	{
		"version": "0.7",
		"title": "Commander Campaign and mastery",
		"stage": "CURRENT",
		"items": [
			"Added Commander's Campaign with six fixed tactical scenarios.",
			"Added live objectives, unlock progression and first-completion Seal rewards.",
			"Added evidence-based Siege and Dominion match analysis with a critical-lane read.",
			"Expanded telemetry with real Energy spend and lane-level decisions.",
			"Added a live Deck Advisor for Energy curve, role coverage and keyword synergy.",
			"Preserved campaign and match analysis through safe profile and active-match storage.",
			"Completed English, German, French, Italian, Spanish and Turkish coverage for v0.7.",
			"Added release-candidate gates for balance, saves, online authority and localization.",
		],
	},
	{
		"version": "0.6",
		"title": "Languages and battle preferences",
		"stage": "HISTORY",
		"items": [
			"Refined the main-menu title and renamed Card Gallery to Cards.",
			"Expanded the Commander's Handbook with Siege, Dominion, controls and missing rules.",
			"Added named save slots with safe backups and explicit Save/Load flows.",
			"Added complete English, German, French, Italian, Spanish and Turkish language selection.",
			"Added flag-based language controls to Settings; English is now the default language.",
			"Added an automatic-battle permission choice to the new-match setup.",
			"Improved difficulty-card alignment and kept its icons inside the buttons.",
			"Added this release-notes archive.",
		],
	},
	{
		"version": "0.5",
		"title": "Profiles, saves and presentation",
		"stage": "HISTORY",
		"items": [
			"Added commander profiles, progression, achievements, missions and match history.",
			"Added active-match saving, recovery and compatibility checks.",
			"Expanded display, audio and gameplay settings.",
			"Added the menu soundtrack player and battlefield feedback effects.",
		],
	},
	{
		"version": "0.4",
		"title": "Dominion and persistent effects",
		"stage": "HISTORY",
		"items": [
			"Added Dominion as an alternative ruleset with lane-control scoring.",
			"Added persistent Effect Cards and expanded status interactions.",
			"Improved online authority, reconnect and invite-code flows.",
		],
	},
	{
		"version": "0.3",
		"title": "Deck building and smarter opponents",
		"stage": "HISTORY",
		"items": [
			"Added deck building, card gallery and card-detail views.",
			"Added Easy, Medium and Hard opponent profiles.",
			"Expanded card upgrades, level paths and tactical AI planning.",
		],
	},
	{
		"version": "0.2",
		"title": "Three-lane siege",
		"stage": "HISTORY",
		"items": [
			"Established the three-lane battlefield and front/back-line targeting rules.",
			"Added combat, movement, energy, turn phases and headquarters victory.",
			"Added Heroes, Structures, Spells and Skills as the core card families.",
		],
	},
	{
		"version": "0.1",
		"title": "First playable build",
		"stage": "HISTORY",
		"items": [
			"Created the first playable Darwine prototype.",
			"Added the initial card database, local match flow and dark-fantasy interface.",
		],
	},
]

var _panel: PanelContainer


func _ready() -> void:
	name = "ReleaseNotesOverlay"
	z_index = 112
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	theme = UI.create_theme()
	_build_interface()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func open_panel() -> void:
	visible = true
	modulate.a = 1.0
	var close_button := find_child("ReleaseNotesCloseButton", true, false) as Button
	if close_button:
		close_button.grab_focus()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func get_release_count() -> int:
	return RELEASES.size()


func _build_interface() -> void:
	var dim := ColorRect.new()
	dim.name = "ReleaseNotesDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.003, 0.005, 0.008, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "ReleaseNotesPanel"
	_panel.custom_minimum_size = Vector2(900.0, 620.0)
	_panel.add_theme_stylebox_override("panel", UI.panel_style(UI.BRASS, 24.0, 0.995))
	center.add_child(_panel)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 11)
	_panel.add_child(shell)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 62.0
	header.add_theme_constant_override("separation", 14)
	shell.add_child(header)
	var balance := Control.new()
	balance.custom_minimum_size.x = 44.0
	header.add_child(balance)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	header.add_child(copy)
	var eyebrow := Label.new()
	eyebrow.name = "ReleaseNotesEyebrow"
	eyebrow.text = "DARWINE DEVELOPMENT ARCHIVE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	copy.add_child(eyebrow)
	var title := Label.new()
	title.name = "ReleaseNotesTitle"
	title.text = "RELEASE NOTES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	UI.style_title(title, UI.PARCHMENT)
	copy.add_child(title)
	var subtitle := Label.new()
	subtitle.name = "ReleaseNotesSubtitle"
	subtitle.text = "Current changes and the complete version history"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", UI.TEXT_MUTED)
	copy.add_child(subtitle)
	var close_button := Button.new()
	close_button.name = "ReleaseNotesCloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(44.0, 44.0)
	close_button.add_theme_font_size_override("font_size", 24)
	UI.style_button(close_button, UI.BRASS, false, true)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)

	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", UI.line_style(Color(UI.BRASS, 0.42), 1))
	shell.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.name = "ReleaseNotesScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	var releases_box := VBoxContainer.new()
	releases_box.name = "ReleaseNotesList"
	releases_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	releases_box.add_theme_constant_override("separation", 12)
	scroll.add_child(releases_box)
	for release in RELEASES:
		releases_box.add_child(_build_release_card(release as Dictionary))


func _build_release_card(release: Dictionary) -> PanelContainer:
	var current := str(release.get("stage", "")) == "CURRENT"
	var accent := UI.BRASS_BRIGHT if current else Color(0.43, 0.48, 0.55)
	var card := PanelContainer.new()
	card.name = "Release%s" % str(release.get("version", "")).replace(".", "_")
	card.add_theme_stylebox_override("panel", UI.inset_style(Color(0.018, 0.020, 0.025, 0.96), accent, 5))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	card.add_child(content)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	content.add_child(heading)
	var version := Label.new()
	version.text = "v%s" % str(release.get("version", ""))
	version.custom_minimum_size.x = 76.0
	version.add_theme_font_size_override("font_size", 21)
	UI.style_title(version, accent)
	heading.add_child(version)
	var title := Label.new()
	title.text = tr(str(release.get("title", "")))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", UI.PARCHMENT)
	heading.add_child(title)
	if current:
		var badge := Label.new()
		badge.text = tr("CURRENT VERSION")
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", UI.BODY_BOLD_FONT)
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
		heading.add_child(badge)
	for item in release.get("items", []) as Array:
		var item_label := Label.new()
		item_label.text = "•  %s" % tr(str(item))
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_label.add_theme_font_override("font", UI.BODY_FONT)
		item_label.add_theme_font_size_override("font_size", 13)
		item_label.add_theme_color_override("font_color", Color(UI.PARCHMENT, 0.82))
		content.add_child(item_label)
	return card
