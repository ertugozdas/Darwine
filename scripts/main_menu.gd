extends Control

const GAME_SCENE := "res://battlefield.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const ONBOARDING_PATH := "user://darwine_settings.cfg"
const APPLICATION_NAME_SETTING := "application/config/name"
const APPLICATION_VERSION_SETTING := "application/config/version"
const APPLICATION_RELEASE_STAGE_SETTING := "application/config/release_stage"
const BACKDROP_PATH := "res://images/settlements/merkez_kalesi.png"
const MENU_MUSIC_PLAYER_SCRIPT := preload("res://scripts/menu_music_player.gd")
const HOW_TO_PLAY_PANEL_SCRIPT := preload("res://scripts/how_to_play_panel.gd")
const SAVE_SLOTS_PANEL_SCRIPT := preload("res://scripts/save_slots_panel.gd")
const SETTINGS_MANAGER_SCRIPT := preload("res://scripts/settings_manager.gd")
const DIFFICULTY_EMBLEM_SCRIPT := preload("res://scripts/difficulty_emblem.gd")
const DECK_BUILDER_PANEL_SCRIPT := preload("res://scripts/deck_builder_panel.gd")
const PROFILE_PANEL_SCRIPT := preload("res://scripts/profile_panel.gd")
const RELEASE_NOTES_PANEL_SCRIPT := preload("res://scripts/release_notes_panel.gd")
const LANGUAGE_FLAG_ICON_SCRIPT := preload("res://scripts/language_flag_icon.gd")
const UI := preload("res://scripts/dark_fantasy_ui.gd")
const WINDOW_RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const TURN_DURATION_CHOICES := [
	{"seconds": 30, "label": "30 SN", "caption": "HIZLI"},
	{"seconds": 45, "label": "45 SN", "caption": "DENGELİ"},
	{"seconds": 60, "label": "60 SN", "caption": "RAHAT"},
	{"seconds": 90, "label": "90 SN", "caption": "UZUN"},
]
const LANGUAGE_OPTIONS := [
	{"code": "en", "label": "English", "native": "English"},
	{"code": "de", "label": "German", "native": "Deutsch"},
	{"code": "fr", "label": "French", "native": "Français"},
	{"code": "it", "label": "Italian", "native": "Italiano"},
	{"code": "es", "label": "Spanish", "native": "Español"},
	{"code": "tr", "label": "Turkish", "native": "Türkçe"},
]

const TYPE_ORDER := ["heroes", "settlements", "special_powers", "upgrades", "effects"]
const TYPE_INFO := {
	"all": {"label": "Tümü", "singular": "Kart", "icon": "◆", "accent": Color(0.78, 0.61, 0.28)},
	"heroes": {"label": "Kahramanlar", "singular": "Kahraman", "icon": "⚔", "accent": Color(0.31, 0.57, 0.88)},
	"settlements": {"label": "Yapılar", "singular": "Yapı", "icon": "⌂", "accent": Color(0.65, 0.42, 0.23)},
	"special_powers": {"label": "Büyüler", "singular": "Büyü", "icon": "✦", "accent": Color(0.60, 0.33, 0.86)},
	"upgrades": {"label": "Beceriler", "singular": "Beceri", "icon": "⚒", "accent": Color(0.18, 0.65, 0.70)},
	"effects": {"label": "Etki Kartları", "singular": "Etki", "icon": "◈", "accent": Color(0.46, 0.58, 0.82)},
}
const RARITY_NAMES := {
	"COMMON": "Yaygın",
	"RARE": "Nadir",
	"EPIC": "Destansı",
	"LEGENDARY": "Efsanevi",
}
const RARITY_ORDER := ["COMMON", "RARE", "EPIC", "LEGENDARY"]
const RARITY_INFO := {
	"all": {"label": "Tümü", "icon": "✦", "accent": Color(0.78, 0.61, 0.28)},
	"COMMON": {"label": "Yaygın", "icon": "●", "accent": Color(0.63, 0.67, 0.72)},
	"RARE": {"label": "Nadir", "icon": "◆", "accent": Color(0.20, 0.62, 0.94)},
	"EPIC": {"label": "Destansı", "icon": "✦", "accent": Color(0.82, 0.35, 0.78)},
	"LEGENDARY": {"label": "Efsanevi", "icon": "♛", "accent": Color(0.96, 0.64, 0.18)},
}
const CARD_SCENE_KEYS := {
	"heroes": "hero",
	"settlements": "settlement",
	"special_powers": "special_power",
	"upgrades": "upgrade",
	"effects": "effect",
}

const INK := UI.VOID
const PANEL_INK := Color(UI.OBSIDIAN, 0.96)
const PANEL_SOFT := Color(UI.IRON, 0.94)
const GOLD := UI.BRASS
const GOLD_BRIGHT := UI.BRASS_BRIGHT
const CREAM := UI.PARCHMENT
const MUTED := UI.TEXT_MUTED
const DANGER := UI.BLOOD
const CARD_CELL_SIZE := Vector2(218.0, 304.0)
const CARD_GALLERY_SCALE := Vector2(0.82, 0.82)
const MAIN_MENU_BUTTON_NAMES := [
	"StartButton",
	"ContinueGameButton",
	"OnlineButton",
	"HowToButton",
	"SettingsButton",
	"DecksButton",
	"GalleryButton",
	"ProfileButton",
	"SoundtrackButton",
	"QuitButton",
]

var _main_shell: PanelContainer
var _version_label: Button
var _mini_music_panel: PanelContainer
var _mini_music_track_label: Label
var _mini_music_index_label: Label
var _mini_music_play_pause_button: Button
var _how_to_overlay: HowToPlayPanel
var _difficulty_overlay: Control
var _difficulty_panel: PanelContainer
var _difficulty_eyebrow: Label
var _difficulty_deck_label: Label
var _ruleset_description: Label
var _ruleset_buttons: Dictionary = {}
var _multiplayer_ruleset_buttons: Dictionary = {}
var _multiplayer_card_pool_buttons: Dictionary = {}
var _multiplayer_turn_duration_buttons: Dictionary = {}
var _multiplayer_auto_attack_buttons: Dictionary = {}
var _selected_ruleset := MatchSetup.Ruleset.SIEGE
var _card_pool_mode_description: Label
var _card_pool_mode_buttons: Dictionary = {}
var _selected_card_pool_mode := MatchSetup.CardPoolMode.DECK
var _game_setup_game_name_input: LineEdit
var _game_setup_name_feedback: Label
var _game_setup_summary: Label
var _game_setup_start_button: Button
var _turn_duration_buttons: Dictionary = {}
var _auto_attack_buttons: Dictionary = {}
var _difficulty_buttons: Dictionary = {}
var _difficulty_button_group := ButtonGroup.new()
var _selected_turn_duration_seconds := int(GameRules.TURN_DURATION_SECONDS)
var _selected_auto_attack_allowed := true
var _selected_difficulty := MatchSetup.AIDifficulty.MEDIUM
var _deck_builder_overlay: Control
var _profile_overlay: CommanderProfilePanel
var _release_notes_overlay: ReleaseNotesPanel
var _multiplayer_overlay: Control
var _multiplayer_panel: PanelContainer
var _multiplayer_name_input: LineEdit
var _multiplayer_code_input: LineEdit
var _multiplayer_status_label: Label
var _multiplayer_players_label: Label
var _multiplayer_join_button: Button
var _multiplayer_host_panel: VBoxContainer
var _multiplayer_join_panel: VBoxContainer
var _multiplayer_steam_panel: VBoxContainer
var _multiplayer_host_mode_button: Button
var _multiplayer_join_mode_button: Button
var _multiplayer_steam_mode_button: Button
var _multiplayer_host_name_input: LineEdit
var _multiplayer_host_address_input: LineEdit
var _multiplayer_host_port_input: LineEdit
var _multiplayer_game_name_input: LineEdit
var _multiplayer_settings_summary: Label
var _multiplayer_room_settings_label: Label
var _multiplayer_host_create_button: Button
var _multiplayer_host_invite_input: LineEdit
var _multiplayer_copy_invite_button: Button
var _multiplayer_leave_room_button: Button
var _multiplayer_reconnect_button: Button
var _steam_identity_label: Label
var _steam_game_name_input: LineEdit
var _steam_ruleset_option: OptionButton
var _steam_card_pool_option: OptionButton
var _steam_turn_duration_option: OptionButton
var _steam_auto_attack_check: CheckButton
var _steam_lobby_list: VBoxContainer
var _steam_host_button: Button
var _steam_refresh_button: Button
var _steam_invite_button: Button
var _steam_leave_button: Button
var _steam_reconnect_button: Button
var _settings_overlay: Control
var _settings_panel: PanelContainer
var _settings_tabs: TabContainer
var _gallery_overlay: Control
var _gallery_panel: PanelContainer
var _gallery_grid: GridContainer
var _gallery_count_label: Label
var _gallery_title_label: Label
var _soundtrack_overlay: Control
var _soundtrack_panel: PanelContainer
var _soundtrack_track_list: VBoxContainer
var _soundtrack_count_label: Label
var _soundtrack_now_index_label: Label
var _soundtrack_now_title_label: Label
var _soundtrack_now_subtitle_label: Label
var _soundtrack_seal_label: Label
var _soundtrack_progress_slider: HSlider
var _soundtrack_time_label: Label
var _soundtrack_duration_label: Label
var _soundtrack_play_pause_button: Button
var _soundtrack_track_buttons: Array[Button] = []
var _soundtrack_track_number_labels: Array[Label] = []
var _soundtrack_track_title_labels: Array[Label] = []
var _soundtrack_track_meta_labels: Array[Label] = []
var _soundtrack_seek_dragging := false
var _detail_overlay: Control
var _detail_panel: PanelContainer
var _detail_card_stage: Control
var _detail_type_label: Label
var _detail_name_label: Label
var _detail_meta_label: Label
var _detail_description_label: Label
var _detail_stats_label: Label
var _detail_effect_label: Label
var _detail_close_button: Button
var _quit_overlay: Control
var _quit_panel: PanelContainer
var _fade_overlay: ColorRect
var _volume_slider: HSlider
var _volume_value_label: Label
var _music_volume_slider: HSlider
var _music_volume_value_label: Label
var _effects_volume_slider: HSlider
var _effects_volume_value_label: Label
var _fullscreen_toggle: CheckButton
var _resolution_option: OptionButton
var _vsync_toggle: CheckButton
var _fps_limit_option: OptionButton
var _default_difficulty_option: OptionButton
var _tutorial_toggle: CheckButton
var _menu_animation_toggle: CheckButton
var _language_buttons: Dictionary = {}
var _language_button_group := ButtonGroup.new()
var _tutorial_status_label: Label
var _filter_group := ButtonGroup.new()
var _filter_buttons: Dictionary = {}
var _active_filter := "all"
var _rarity_filter_group := ButtonGroup.new()
var _rarity_filter_buttons: Dictionary = {}
var _active_rarity_filter := "all"
var _settings_are_loading := false
var _transitioning := false
var _menu_feedback_audio: FeedbackAudio = null
var _menu_music_player: MenuMusicPlayer = null
var _settings_manager: Variant = null
var _active_match_repository := ActiveMatchRepository.new()
var _continue_game_button: Button = null
var _save_slots_overlay: SaveSlotsPanel = null
var _save_recovery_overlay: Control = null
var _save_recovery_message: Label = null
var _recover_backup_button: Button = null


func _ready() -> void:
	_settings_manager = _resolve_settings_manager()
	theme = UI.create_theme()
	CardDatabase.load_all()
	_build_backdrop()
	_build_main_screen()
	_build_mini_music_player()
	_build_how_to_overlay()
	_build_deck_builder_overlay()
	_build_profile_overlay()
	_build_release_notes_overlay()
	_build_difficulty_overlay()
	_build_multiplayer_overlay()
	_build_settings_overlay()
	_build_gallery_overlay()
	_build_soundtrack_overlay()
	_build_save_slots_overlay()
	_build_save_recovery_overlay()
	_build_quit_overlay()
	_build_fade_overlay()
	_create_audio()
	_load_settings()
	_connect_network_manager()
	_connect_steam_manager_ui()
	_refresh_collection_brief()
	_refresh_continue_game_state()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	call_deferred("_animate_entry")
	call_deferred("_focus_start_button")


func _resolve_settings_manager() -> Variant:
	var existing := get_node_or_null("/root/SettingsManager")
	if existing:
		return existing
	var fallback := SETTINGS_MANAGER_SCRIPT.new()
	fallback.name = "SettingsManager"
	get_tree().root.add_child(fallback)
	return fallback


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if _how_to_overlay and _how_to_overlay.is_open():
		_hide_how_to_play()
	elif _deck_builder_overlay and _deck_builder_overlay.is_open():
		_hide_deck_builder()
	elif _profile_overlay and _profile_overlay.is_open():
		_hide_profile()
	elif _release_notes_overlay and _release_notes_overlay.is_open():
		_hide_release_notes()
	elif _multiplayer_overlay and _multiplayer_overlay.visible:
		_hide_multiplayer()
	elif _save_slots_overlay and _save_slots_overlay.is_open():
		_save_slots_overlay.close_panel()
		_focus_start_button()
	elif _save_recovery_overlay and _save_recovery_overlay.visible:
		_save_recovery_overlay.visible = false
		_focus_start_button()
	elif _detail_overlay.visible:
		_hide_card_detail()
	elif _gallery_overlay.visible:
		_hide_gallery()
	elif _soundtrack_overlay.visible:
		_hide_soundtrack()
	elif _settings_overlay.visible:
		_hide_settings()
	elif _difficulty_overlay.visible:
		_hide_difficulty_selection()
	elif _quit_overlay.visible:
		_hide_quit_confirmation()
	else:
		_show_quit_confirmation()
	get_viewport().set_input_as_handled()


func _build_backdrop() -> void:
	var backdrop := TextureRect.new()
	backdrop.name = "CastleBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = load(BACKDROP_PATH) as Texture2D
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backdrop.modulate = Color(0.70, 0.67, 0.62)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var horizontal_wash := TextureRect.new()
	horizontal_wash.name = "HorizontalWash"
	horizontal_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	horizontal_wash.texture = _make_gradient_texture(
		PackedColorArray([
			Color(0.012, 0.014, 0.018, 0.99),
			Color(0.018, 0.019, 0.022, 0.92),
			Color(0.025, 0.026, 0.029, 0.50),
			Color(0.018, 0.018, 0.020, 0.22),
		]),
		PackedFloat32Array([0.0, 0.35, 0.66, 1.0]),
		Vector2(0.0, 0.5),
		Vector2(1.0, 0.5)
	)
	horizontal_wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	horizontal_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(horizontal_wash)

	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.texture = _make_gradient_texture(
		PackedColorArray([
			Color(0.01, 0.012, 0.016, 0.04),
			Color(0.01, 0.012, 0.016, 0.18),
			Color(0.01, 0.012, 0.016, 0.80),
		]),
		PackedFloat32Array([0.0, 0.62, 1.0]),
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0)
	)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	var lower_glow := TextureRect.new()
	lower_glow.name = "LowerGoldGlow"
	lower_glow.anchor_left = 0.0
	lower_glow.anchor_top = 0.82
	lower_glow.anchor_right = 1.0
	lower_glow.anchor_bottom = 1.0
	lower_glow.texture = _make_gradient_texture(
		PackedColorArray([Color(0.34, 0.20, 0.07, 0.0), Color(0.34, 0.20, 0.07, 0.18)]),
		PackedFloat32Array([0.0, 1.0]),
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0)
	)
	lower_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lower_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower_glow)

	var bottom_rule := ColorRect.new()
	bottom_rule.name = "BottomGoldRule"
	bottom_rule.anchor_top = 1.0
	bottom_rule.anchor_right = 1.0
	bottom_rule.anchor_bottom = 1.0
	bottom_rule.offset_top = -3.0
	bottom_rule.color = Color(GOLD, 0.72)
	bottom_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_rule)


func _build_main_screen() -> void:
	_main_shell = PanelContainer.new()
	_main_shell.name = "MainMenuPanel"
	_main_shell.add_theme_stylebox_override(
		"panel",
		_make_stylebox(PANEL_INK, Color(GOLD, 0.58), 1, 10, 34.0)
	)
	add_child(_main_shell)

	var content := VBoxContainer.new()
	content.name = "MainContent"
	content.add_theme_constant_override("separation", 8)
	_main_shell.add_child(content)

	var title_top_spacer := Control.new()
	title_top_spacer.name = "TitleTopSpacer"
	title_top_spacer.custom_minimum_size.y = 8.0
	content.add_child(title_top_spacer)

	var title := Label.new()
	title.name = "GameTitle"
	title.text = str(ProjectSettings.get_setting(APPLICATION_NAME_SETTING, "Darwine")).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", CREAM)
	title.add_theme_color_override("font_outline_color", Color(0.09, 0.06, 0.025))
	title.add_theme_constant_override("outline_size", 7)
	UI.style_title(title, CREAM)
	title.add_theme_constant_override("outline_size", 7)
	content.add_child(title)

	var title_rule := HSeparator.new()
	title_rule.custom_minimum_size.y = 8.0
	title_rule.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.78), 2))
	content.add_child(title_rule)

	var menu_spacer := Control.new()
	menu_spacer.custom_minimum_size.y = 4.0
	content.add_child(menu_spacer)

	var menu_buttons := VBoxContainer.new()
	menu_buttons.name = "MenuButtons"
	menu_buttons.add_theme_constant_override("separation", 4)
	content.add_child(menu_buttons)

	var start_button := _make_menu_button("StartButton", "Savaşa Başla", "", GOLD_BRIGHT)
	start_button.pressed.connect(_show_difficulty_selection)
	menu_buttons.add_child(start_button)

	_continue_game_button = _make_menu_button("ContinueGameButton", "YÜKLE", "", Color(0.34, 0.68, 0.54))
	_continue_game_button.pressed.connect(_on_continue_game_pressed)
	menu_buttons.add_child(_continue_game_button)

	# Keep the dotted Turkish İ explicit; locale-neutral to_upper() would turn
	# "çevrimiçi" into the visually incorrect "ÇEVRIMIÇI".
	var online_button := _make_menu_button("OnlineButton", "ÇEVRİMİÇİ OYNA", "", Color(0.28, 0.68, 0.86))
	online_button.pressed.connect(_show_multiplayer)
	menu_buttons.add_child(online_button)

	var how_to_button := _make_menu_button("HowToButton", "Nasıl Oynanır?", "", Color(0.47, 0.66, 0.72))
	how_to_button.pressed.connect(_show_how_to_play)
	menu_buttons.add_child(how_to_button)

	var settings_button := _make_menu_button("SettingsButton", "Ayarlar", "", Color(0.72, 0.65, 0.51))
	settings_button.pressed.connect(_show_settings)
	menu_buttons.add_child(settings_button)

	var deck_gallery_row := HBoxContainer.new()
	deck_gallery_row.name = "DeckGalleryRow"
	deck_gallery_row.add_theme_constant_override("separation", 8)
	menu_buttons.add_child(deck_gallery_row)
	var decks_button := _make_menu_button("DecksButton", "Desteler", "", Color(0.33, 0.58, 0.48))
	decks_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decks_button.pressed.connect(_show_deck_builder)
	deck_gallery_row.add_child(decks_button)
	var gallery_button := _make_menu_button("GalleryButton", "Kartlar", "", Color(0.69, 0.58, 0.39))
	gallery_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery_button.pressed.connect(_show_gallery)
	deck_gallery_row.add_child(gallery_button)

	var profile_soundtrack_row := HBoxContainer.new()
	profile_soundtrack_row.name = "ProfileSoundtrackRow"
	profile_soundtrack_row.add_theme_constant_override("separation", 8)
	menu_buttons.add_child(profile_soundtrack_row)
	var profile_button := _make_menu_button("ProfileButton", "PROFİL", "", Color(0.34, 0.58, 0.68))
	profile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_button.pressed.connect(_show_profile)
	profile_soundtrack_row.add_child(profile_button)
	var soundtrack_button := _make_menu_button("SoundtrackButton", "Soundtrack", "", Color(0.72, 0.52, 0.24))
	soundtrack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	soundtrack_button.add_theme_font_size_override("font_size", 15)
	soundtrack_button.pressed.connect(_show_soundtrack)
	profile_soundtrack_row.add_child(soundtrack_button)

	var quit_button := _make_menu_button("QuitButton", "Oyundan Çık", "", Color(0.72, 0.39, 0.32), true)
	quit_button.pressed.connect(_show_quit_confirmation)
	menu_buttons.add_child(quit_button)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(footer_spacer)
	_build_version_label(content)


func _build_version_label(parent: Container) -> void:
	_version_label = Button.new()
	_version_label.name = "VersionLabel"
	_version_label.text = _application_version_label()
	_version_label.custom_minimum_size.y = 18.0
	_version_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_label.tooltip_text = "Open release notes and version history"
	_version_label.focus_mode = Control.FOCUS_ALL
	_version_label.flat = true
	_version_label.add_theme_font_override("font", UI.BODY_FONT)
	_version_label.add_theme_font_size_override("font_size", 13)
	_version_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.78))
	_version_label.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	_version_label.add_theme_color_override("font_pressed_color", CREAM)
	_version_label.pressed.connect(_show_release_notes)
	parent.add_child(_version_label)


func _application_version_label() -> String:
	var version := str(ProjectSettings.get_setting(APPLICATION_VERSION_SETTING, "0.0"))
	var release_stage := str(ProjectSettings.get_setting(APPLICATION_RELEASE_STAGE_SETTING, "")).strip_edges()
	return "%s %s%s  •  %s" % [
		tr("Version"),
		version,
		" %s" % release_stage if not release_stage.is_empty() else "",
		tr("RELEASE NOTES"),
	]


func _build_mini_music_player() -> void:
	_mini_music_panel = PanelContainer.new()
	_mini_music_panel.name = "MiniMusicPlayer"
	_mini_music_panel.z_index = 5
	_mini_music_panel.anchor_left = 1.0
	_mini_music_panel.anchor_top = 1.0
	_mini_music_panel.anchor_right = 1.0
	_mini_music_panel.anchor_bottom = 1.0
	_mini_music_panel.offset_left = -410.0
	_mini_music_panel.offset_top = -150.0
	_mini_music_panel.offset_right = -30.0
	_mini_music_panel.offset_bottom = -30.0
	_mini_music_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(0.018, 0.019, 0.023, 0.92), Color(GOLD, 0.48), 1, 8, 16.0)
	)
	add_child(_mini_music_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_mini_music_panel.add_child(content)

	var header := Control.new()
	header.name = "MiniMusicHeader"
	header.custom_minimum_size.y = 16.0
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(header)
	_mini_music_index_label = Label.new()
	_mini_music_index_label.name = "MiniMusicTrackIndex"
	_mini_music_index_label.text = "-- / --"
	_mini_music_index_label.anchor_left = 1.0
	_mini_music_index_label.anchor_right = 1.0
	_mini_music_index_label.offset_left = -68.0
	_mini_music_index_label.offset_top = 3.0
	_mini_music_index_label.offset_right = -10.0
	_mini_music_index_label.offset_bottom = 19.0
	_mini_music_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mini_music_index_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mini_music_index_label.add_theme_font_size_override("font_size", 10)
	_mini_music_index_label.add_theme_color_override("font_color", Color(0.72, 0.69, 0.63))
	header.add_child(_mini_music_index_label)

	var track_copy := VBoxContainer.new()
	track_copy.name = "MiniMusicTrackCopy"
	track_copy.add_theme_constant_override("separation", 0)
	content.add_child(track_copy)
	var now_playing := Label.new()
	now_playing.name = "MiniMusicNowPlaying"
	now_playing.text = "ŞİMDİ ÇALIYOR"
	now_playing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	now_playing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	now_playing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	now_playing.clip_text = true
	now_playing.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
	now_playing.add_theme_font_size_override("font_size", 10)
	now_playing.add_theme_color_override("font_color", GOLD_BRIGHT)
	track_copy.add_child(now_playing)

	_mini_music_track_label = Label.new()
	_mini_music_track_label.name = "MiniMusicTrackTitle"
	_mini_music_track_label.text = "Soundtrack yükleniyor"
	_mini_music_track_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mini_music_track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mini_music_track_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mini_music_track_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_mini_music_track_label.clip_text = true
	_mini_music_track_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_mini_music_track_label.tooltip_text = _mini_music_track_label.text
	_mini_music_track_label.add_theme_font_size_override("font_size", 17)
	UI.style_title(_mini_music_track_label, CREAM)
	track_copy.add_child(_mini_music_track_label)

	var controls_offset := Control.new()
	controls_offset.name = "MiniMusicControlsOffset"
	controls_offset.custom_minimum_size.y = 1.0
	content.add_child(controls_offset)
	var controls := HBoxContainer.new()
	controls.name = "MiniMusicControls"
	controls.add_theme_constant_override("separation", 7)
	content.add_child(controls)
	var previous_button := _make_action_button("MiniPreviousTrackButton", "<", Color(0.60, 0.52, 0.40), true)
	previous_button.custom_minimum_size = Vector2(42.0, 34.0)
	previous_button.add_theme_font_size_override("font_size", 14)
	previous_button.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	previous_button.tooltip_text = "Önceki parça"
	previous_button.pressed.connect(_on_soundtrack_previous_pressed)
	controls.add_child(previous_button)
	_mini_music_play_pause_button = _make_action_button("MiniPlayPauseButton", "II", GOLD_BRIGHT)
	_mini_music_play_pause_button.custom_minimum_size = Vector2(64.0, 34.0)
	_mini_music_play_pause_button.add_theme_font_size_override("font_size", 13)
	_mini_music_play_pause_button.tooltip_text = "Müziği duraklat"
	_mini_music_play_pause_button.pressed.connect(_on_soundtrack_play_pause_pressed)
	controls.add_child(_mini_music_play_pause_button)
	var next_button := _make_action_button("MiniNextTrackButton", ">", Color(0.60, 0.52, 0.40), true)
	next_button.custom_minimum_size = Vector2(42.0, 34.0)
	next_button.add_theme_font_size_override("font_size", 14)
	next_button.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	next_button.tooltip_text = "Sonraki parça"
	next_button.pressed.connect(_on_soundtrack_next_pressed)
	controls.add_child(next_button)
	var control_spacer := Control.new()
	control_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(control_spacer)
	var library_button := _make_action_button("MiniSoundtrackButton", "Soundtrack", Color(0.58, 0.52, 0.42), true)
	library_button.custom_minimum_size = Vector2(118.0, 34.0)
	library_button.add_theme_font_size_override("font_size", 12)
	library_button.pressed.connect(_show_soundtrack)
	controls.add_child(library_button)


func _build_how_to_overlay() -> void:
	_how_to_overlay = HOW_TO_PLAY_PANEL_SCRIPT.new() as HowToPlayPanel
	_how_to_overlay.closed.connect(_focus_start_button)
	add_child(_how_to_overlay)


func _build_deck_builder_overlay() -> void:
	_deck_builder_overlay = DECK_BUILDER_PANEL_SCRIPT.new() as Control
	_deck_builder_overlay.closed.connect(_focus_start_button)
	add_child(_deck_builder_overlay)


func _build_profile_overlay() -> void:
	_profile_overlay = PROFILE_PANEL_SCRIPT.new() as CommanderProfilePanel
	_profile_overlay.closed.connect(_focus_start_button)
	add_child(_profile_overlay)


func _build_release_notes_overlay() -> void:
	_release_notes_overlay = RELEASE_NOTES_PANEL_SCRIPT.new() as ReleaseNotesPanel
	_release_notes_overlay.closed.connect(_focus_start_button)
	add_child(_release_notes_overlay)

func _build_difficulty_overlay() -> void:
	_difficulty_overlay = _make_modal_overlay("DifficultyOverlay", Color(0.004, 0.006, 0.009, 0.82))
	add_child(_difficulty_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_difficulty_overlay.add_child(center)

	_difficulty_panel = PanelContainer.new()
	_difficulty_panel.name = "DifficultyPanel"
	_difficulty_panel.custom_minimum_size = Vector2(980.0, 650.0)
	_difficulty_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(0.035, 0.038, 0.044, 0.985), Color(GOLD, 0.78), 1, 11, 26.0)
	)
	center.add_child(_difficulty_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	_difficulty_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	content.add_child(header)
	var header_balance := Control.new()
	header_balance.name = "DifficultyHeaderBalance"
	header_balance.custom_minimum_size.x = 42.0
	header.add_child(header_balance)
	var header_copy := VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.add_theme_constant_override("separation", 0)
	header.add_child(header_copy)
	_difficulty_eyebrow = _make_muted_label("TEK OYUNCULU KUŞATMA", 10)
	_difficulty_eyebrow.name = "DifficultyEyebrow"
	_difficulty_eyebrow.add_theme_color_override("font_color", GOLD_BRIGHT)
	header_copy.add_child(_difficulty_eyebrow)
	var title := _make_heading("OYUN AYARLARI", 28)
	title.name = "DifficultyTitle"
	header_copy.add_child(title)
	var close_button := _make_icon_button("DifficultyCloseButton", "×")
	close_button.pressed.connect(_hide_difficulty_selection)
	header.add_child(close_button)

	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.28), 1))
	content.add_child(rule)

	var form_panel := PanelContainer.new()
	form_panel.name = "GameSetupFormPanel"
	form_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_panel.add_theme_stylebox_override(
		"panel",
		_make_button_style(Color(0.012, 0.014, 0.018, 0.90), Color(GOLD, 0.26), 1, 8, 16.0)
	)
	content.add_child(form_panel)
	var form := VBoxContainer.new()
	form.name = "GameSetupForm"
	form.add_theme_constant_override("separation", 5)
	form_panel.add_child(form)

	var game_name_controls := _make_game_config_row(
		form,
		"GameNameConfigRow",
		"OYUN ADI",
		"Karşılaşmayı ayırt edecek kısa bir ad."
	)
	_game_setup_game_name_input = LineEdit.new()
	_game_setup_game_name_input.name = "GameNameInput"
	_game_setup_game_name_input.text = tr(MatchSetup.DEFAULT_MATCH_NAME)
	_game_setup_game_name_input.placeholder_text = "Örn. Gece Kuşatması"
	_game_setup_game_name_input.max_length = MatchSetup.MAX_MATCH_NAME_LENGTH
	_game_setup_game_name_input.custom_minimum_size.y = 44.0
	_game_setup_game_name_input.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_game_setup_game_name_input.add_theme_font_size_override("font_size", 16)
	_game_setup_game_name_input.add_theme_color_override("font_color", CREAM)
	_game_setup_game_name_input.add_theme_color_override("font_placeholder_color", Color(MUTED, 0.62))
	_game_setup_game_name_input.add_theme_stylebox_override(
		"normal",
		_make_button_style(Color(0.018, 0.019, 0.023, 0.98), Color(GOLD, 0.46), 1, 7, 14.0)
	)
	_game_setup_game_name_input.add_theme_stylebox_override(
		"focus",
		_make_button_style(Color(0.028, 0.026, 0.021, 1.0), Color(GOLD_BRIGHT, 0.94), 2, 7, 14.0)
	)
	_game_setup_game_name_input.text_changed.connect(_on_game_setup_name_changed)
	_game_setup_game_name_input.text_submitted.connect(_on_game_setup_name_submitted)
	game_name_controls.add_child(_game_setup_game_name_input)
	_game_setup_name_feedback = _make_muted_label(
		tr("Up to %d characters.") % MatchSetup.MAX_MATCH_NAME_LENGTH,
		10,
	)
	_game_setup_name_feedback.name = "GameNameFeedback"
	_game_setup_name_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	game_name_controls.add_child(_game_setup_name_feedback)

	_add_game_config_separator(form)
	var ruleset_controls := _make_game_config_row(
		form,
		"RulesetConfigRow",
		"OYUN MODU",
		"Zafer koşulunu belirle."
	)
	_build_ruleset_selector(ruleset_controls)

	_add_game_config_separator(form)
	var card_pool_controls := _make_game_config_row(
		form,
		"CardPoolConfigRow",
		"KART KAPSAMI",
		"Etkin desteyi veya tüm kart havuzunu kullan."
	)
	_build_card_pool_mode_selector(card_pool_controls, false)
	_difficulty_deck_label = Label.new()
	_difficulty_deck_label.name = "DifficultyActiveDeck"
	_difficulty_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_difficulty_deck_label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_difficulty_deck_label.add_theme_font_size_override("font_size", 10)
	_difficulty_deck_label.add_theme_color_override("font_color", Color(0.52, 0.78, 0.64))
	card_pool_controls.add_child(_difficulty_deck_label)

	_add_game_config_separator(form)
	var turn_duration_controls := _make_game_config_row(
		form,
		"TurnDurationConfigRow",
		"TUR BAŞINA SÜRE",
		"Sayaç her oyuncu değişiminde yenilenir."
	)
	var duration_choices := HBoxContainer.new()
	duration_choices.name = "TurnDurationChoices"
	duration_choices.add_theme_constant_override("separation", 8)
	turn_duration_controls.add_child(duration_choices)
	var duration_group := ButtonGroup.new()
	duration_group.allow_unpress = false
	for definition in TURN_DURATION_CHOICES:
		var seconds := int(definition["seconds"])
		var duration_button := _make_action_button(
			"TurnDuration%dButton" % seconds,
			"%s  •  %s" % [tr(str(definition["label"])), tr(str(definition["caption"]))],
			Color(0.42, 0.64, 0.84),
			seconds != int(GameRules.TURN_DURATION_SECONDS)
		)
		duration_button.toggle_mode = true
		duration_button.button_group = duration_group
		duration_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		duration_button.custom_minimum_size = Vector2(105.0, 48.0)
		duration_button.add_theme_font_size_override("font_size", 12)
		duration_button.pressed.connect(_set_turn_duration.bind(seconds))
		duration_choices.add_child(duration_button)
		_turn_duration_buttons[seconds] = duration_button

	_add_game_config_separator(form)
	var auto_attack_controls := _make_game_config_row(
		form,
		"AutoAttackConfigRow",
		"OTOMATİK SAVAŞ",
		"Çatışma fazında otomatik saldırıya izin verilsin mi?"
	)
	var auto_attack_choices := HBoxContainer.new()
	auto_attack_choices.name = "AutoAttackChoices"
	auto_attack_choices.add_theme_constant_override("separation", 10)
	auto_attack_controls.add_child(auto_attack_choices)
	var auto_attack_group := ButtonGroup.new()
	auto_attack_group.allow_unpress = false
	for definition in [
		{"allowed": true, "name": "AllowAutoAttackButton", "text": "İZİN VER", "accent": Color(0.30, 0.72, 0.41)},
		{"allowed": false, "name": "DisableAutoAttackButton", "text": "KAPALI", "accent": Color(0.64, 0.42, 0.34)},
	]:
		var allowed := bool(definition["allowed"])
		var auto_attack_button := _make_action_button(
			str(definition["name"]),
			str(definition["text"]),
			definition["accent"] as Color,
			not allowed
		)
		auto_attack_button.toggle_mode = true
		auto_attack_button.button_group = auto_attack_group
		auto_attack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		auto_attack_button.custom_minimum_size.y = 40.0
		auto_attack_button.pressed.connect(_set_auto_attack_allowed.bind(allowed))
		auto_attack_choices.add_child(auto_attack_button)
		_auto_attack_buttons[allowed] = auto_attack_button

	_add_game_config_separator(form)
	var difficulty_controls := _make_game_config_row(
		form,
		"DifficultyConfigRow",
		"ZORLUK",
		"Rakibin karar kalitesini belirle."
	)
	_difficulty_button_group.allow_unpress = false
	var choices := HBoxContainer.new()
	choices.name = "DifficultyChoices"
	choices.add_theme_constant_override("separation", 8)
	difficulty_controls.add_child(choices)
	choices.add_child(_make_difficulty_button(
		"EasyDifficultyButton",
		"KOLAY",
		tr("Rahat tempo") + "\n" + tr("Daha seyrek baskı"),
		Color(0.30, 0.72, 0.41),
		0,
		MatchSetup.AIDifficulty.EASY
	))
	choices.add_child(_make_difficulty_button(
		"MediumDifficultyButton",
		"ORTA",
		tr("Dengeli kararlar") + "\n" + tr("Önerilen"),
		Color(0.91, 0.70, 0.24),
		1,
		MatchSetup.AIDifficulty.MEDIUM
	))
	choices.add_child(_make_difficulty_button(
		"HardDifficultyButton",
		"ZOR",
		tr("Agresif hamleler") + "\n" + tr("Yüksek baskı"),
		Color(0.86, 0.28, 0.23),
		2,
		MatchSetup.AIDifficulty.HARD
	))

	var footer_rule := HSeparator.new()
	footer_rule.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.28), 1))
	content.add_child(footer_rule)
	var footer := HBoxContainer.new()
	footer.name = "GameSetupFooter"
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	_game_setup_summary = _make_muted_label("", 11)
	_game_setup_summary.name = "GameSetupSummary"
	_game_setup_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_setup_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_game_setup_summary.clip_text = true
	_game_setup_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(_game_setup_summary)
	_game_setup_start_button = _make_action_button(
		"StartConfiguredGameButton",
		"OYUNU BAŞLAT",
		Color(0.30, 0.72, 0.41)
	)
	_game_setup_start_button.custom_minimum_size = Vector2(210.0, 48.0)
	_game_setup_start_button.pressed.connect(_start_game)
	footer.add_child(_game_setup_start_button)

	_set_card_pool_mode(_selected_card_pool_mode)
	_set_ruleset(_selected_ruleset)
	_set_turn_duration(_selected_turn_duration_seconds)
	_set_auto_attack_allowed(_selected_auto_attack_allowed)
	_set_selected_difficulty(_selected_difficulty)
	_refresh_game_setup_summary()


func _make_game_config_row(
	parent: VBoxContainer,
	node_name: String,
	title_text: String,
	description_text: String
) -> VBoxContainer:
	var row := HBoxContainer.new()
	row.name = node_name
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var label_column := VBoxContainer.new()
	label_column.name = "%sLabelColumn" % node_name
	label_column.custom_minimum_size.x = 205.0
	label_column.add_theme_constant_override("separation", 1)
	row.add_child(label_column)
	var title := Label.new()
	title.name = "%sTitle" % node_name
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	label_column.add_child(title)
	var description := _make_muted_label(description_text, 10)
	description.name = "%sDescription" % node_name
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description.custom_minimum_size.y = 28.0
	label_column.add_child(description)
	var controls := VBoxContainer.new()
	controls.name = "%sControls" % node_name
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 3)
	row.add_child(controls)
	return controls


func _add_game_config_separator(parent: VBoxContainer) -> void:
	var separator := HSeparator.new()
	separator.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.14), 1))
	parent.add_child(separator)


func _build_card_pool_mode_selector(parent: Container, show_heading := true) -> void:
	var section := VBoxContainer.new()
	section.name = "CardPoolModeSection"
	section.add_theme_constant_override("separation", 3)
	parent.add_child(section)

	if show_heading:
		var heading := _make_muted_label("KART KAYNAĞI", 10)
		heading.name = "CardPoolModeHeading"
		heading.add_theme_color_override("font_color", GOLD_BRIGHT)
		section.add_child(heading)

	var row := HBoxContainer.new()
	row.name = "CardPoolModeChoices"
	row.add_theme_constant_override("separation", 10)
	section.add_child(row)

	var group := ButtonGroup.new()
	group.allow_unpress = false
	for definition in [
		{
			"mode": MatchSetup.CardPoolMode.DECK,
			"name": "DeckCardPoolButton",
			"text": "ETKİN DESTE",
			"accent": Color(0.33, 0.68, 0.48),
		},
		{
			"mode": MatchSetup.CardPoolMode.ALL_CARDS,
			"name": "AllCardsPoolButton",
			"text": "TÜM KARTLAR",
			"accent": Color(0.48, 0.62, 0.90),
		},
	]:
		var mode := int(definition["mode"])
		var accent: Color = definition["accent"]
		var button := _make_action_button(
			str(definition["name"]),
			str(definition["text"]),
			accent,
			mode != MatchSetup.CardPoolMode.DECK
		)
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 40.0
		button.pressed.connect(_set_card_pool_mode.bind(mode))
		row.add_child(button)
		_card_pool_mode_buttons[mode] = button

	_card_pool_mode_description = _make_muted_label("", 11)
	_card_pool_mode_description.name = "CardPoolModeDescription"
	_card_pool_mode_description.custom_minimum_size.y = 20.0
	_card_pool_mode_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	section.add_child(_card_pool_mode_description)
	_set_card_pool_mode(_selected_card_pool_mode)


func _build_ruleset_selector(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.name = "RulesetChoices"
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for definition in [
		{
			"ruleset": MatchSetup.Ruleset.SIEGE,
			"name": "SiegeRulesetButton",
			"text": "KUŞATMA",
			"accent": Color(0.78, 0.49, 0.25),
		},
		{
			"ruleset": MatchSetup.Ruleset.DOMINION,
			"name": "DominionRulesetButton",
			"text": "HAKİMİYET",
			"accent": Color(0.38, 0.68, 0.92),
		},
	]:
		var ruleset := int(definition["ruleset"])
		var button := _make_action_button(
			str(definition["name"]),
			str(definition["text"]),
			definition["accent"] as Color,
			ruleset != MatchSetup.Ruleset.SIEGE
		)
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 40.0
		button.pressed.connect(_set_ruleset.bind(ruleset))
		row.add_child(button)
		_ruleset_buttons[ruleset] = button
	_ruleset_description = _make_muted_label("", 11)
	_ruleset_description.name = "RulesetDescription"
	_ruleset_description.custom_minimum_size.y = 20.0
	_ruleset_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(_ruleset_description)


func _set_ruleset(value: int) -> void:
	_selected_ruleset = MatchSetup.Ruleset.DOMINION if value == MatchSetup.Ruleset.DOMINION else MatchSetup.Ruleset.SIEGE
	for ruleset_variant in _ruleset_buttons:
		var button := _ruleset_buttons[ruleset_variant] as Button
		if button:
			button.button_pressed = int(ruleset_variant) == _selected_ruleset
	for ruleset_variant in _multiplayer_ruleset_buttons:
		var multiplayer_button := _multiplayer_ruleset_buttons[ruleset_variant] as Button
		if multiplayer_button:
			multiplayer_button.button_pressed = int(ruleset_variant) == _selected_ruleset
	if _multiplayer_game_name_input:
		var online_name := _multiplayer_game_name_input.text.strip_edges()
		if online_name.is_empty() or _is_default_game_name_text(online_name):
			_multiplayer_game_name_input.text = tr(MatchSetup.get_default_match_name(_selected_ruleset))
	if _game_setup_game_name_input:
		var current_name := _game_setup_game_name_input.text.strip_edges()
		if _is_default_game_name_text(current_name):
			_game_setup_game_name_input.text = tr(MatchSetup.get_default_match_name(_selected_ruleset))
		_game_setup_game_name_input.placeholder_text = (
			"Örn. Gece Hakimiyeti"
			if _selected_ruleset == MatchSetup.Ruleset.DOMINION
			else "Örn. Gece Kuşatması"
		)
	if _ruleset_description:
		_ruleset_description.text = (
			"Kahramanlar 2, Yapılar 1 kontrol gücü verir; tam raund sonunda 12 puana ulaş."
			if _selected_ruleset == MatchSetup.Ruleset.DOMINION
			else "Koridoru aç, rakibin 30 Canlı Merkez Binasını yık."
		)
	if _difficulty_eyebrow:
		_difficulty_eyebrow.text = (
			"TEK OYUNCULU HAKİMİYET"
			if _selected_ruleset == MatchSetup.Ruleset.DOMINION
			else "TEK OYUNCULU KUŞATMA"
		)
	_refresh_game_setup_summary()
	_refresh_multiplayer_settings_summary()


func _set_card_pool_mode(mode: int) -> void:
	_selected_card_pool_mode = (
		MatchSetup.CardPoolMode.ALL_CARDS
		if mode == MatchSetup.CardPoolMode.ALL_CARDS
		else MatchSetup.CardPoolMode.DECK
	)
	for mode_variant in _card_pool_mode_buttons:
		var button := _card_pool_mode_buttons[mode_variant] as Button
		if button:
			button.button_pressed = int(mode_variant) == _selected_card_pool_mode
	for mode_variant in _multiplayer_card_pool_buttons:
		var multiplayer_button := _multiplayer_card_pool_buttons[mode_variant] as Button
		if multiplayer_button:
			multiplayer_button.button_pressed = int(mode_variant) == _selected_card_pool_mode
	_refresh_card_pool_mode_copy()
	_refresh_game_setup_summary()
	_refresh_multiplayer_settings_summary()


func _refresh_card_pool_mode_copy() -> void:
	if _selected_card_pool_mode == MatchSetup.CardPoolMode.ALL_CARDS:
		var playable_card_count := CardDatabase.get_playable_card_refs().size()
		if _card_pool_mode_description:
			_card_pool_mode_description.text = (
				tr("Both sides start with all %d playable cards; each card order is shuffled separately.")
				% playable_card_count
			)
		if _difficulty_deck_label:
			_difficulty_deck_label.text = tr("ALL CARDS  •  %d CARDS IN MATCH") % playable_card_count
		_refresh_game_setup_summary()
		return

	if _card_pool_mode_description:
		_card_pool_mode_description.text = tr(
			"Your custom 30-card deck faces the opponent's themed deck for the selected difficulty."
		)
	if not _difficulty_deck_label:
		return
	var deck_manager := get_node_or_null("/root/DeckManager")
	if not deck_manager:
		_difficulty_deck_label.text = "ETKİN DESTE BULUNAMADI"
		return
	var active_deck: Dictionary = deck_manager.get_active_deck()
	_difficulty_deck_label.text = tr("ACTIVE DECK  •  %s  •  %d CARDS") % [
		tr(str(active_deck.get("name", "İsimsiz Deste"))),
		(active_deck.get("cards", []) as Array).size(),
	]
	_refresh_game_setup_summary()


func _on_game_setup_name_changed(_value: String) -> void:
	if _game_setup_name_feedback:
		_game_setup_name_feedback.text = tr("Up to %d characters.") % MatchSetup.MAX_MATCH_NAME_LENGTH
		_game_setup_name_feedback.add_theme_color_override("font_color", MUTED)
	_refresh_game_setup_summary()


func _focus_game_setup_form() -> void:
	if _game_setup_game_name_input and _game_setup_game_name_input.is_visible_in_tree():
		_game_setup_game_name_input.grab_focus()
		_game_setup_game_name_input.select_all()


func _on_game_setup_name_submitted(_value: String) -> void:
	_start_game()


func _set_turn_duration(seconds: int) -> void:
	_selected_turn_duration_seconds = clampi(seconds, 15, 300)
	for seconds_variant in _turn_duration_buttons:
		var button := _turn_duration_buttons[seconds_variant] as Button
		if button:
			button.button_pressed = int(seconds_variant) == _selected_turn_duration_seconds
	_refresh_game_setup_summary()
	for seconds_variant in _multiplayer_turn_duration_buttons:
		var multiplayer_button := _multiplayer_turn_duration_buttons[seconds_variant] as Button
		if multiplayer_button:
			multiplayer_button.button_pressed = int(seconds_variant) == _selected_turn_duration_seconds
	_refresh_multiplayer_settings_summary()


func _set_auto_attack_allowed(allowed: bool) -> void:
	_selected_auto_attack_allowed = allowed
	for allowed_variant in _auto_attack_buttons:
		var button := _auto_attack_buttons[allowed_variant] as Button
		if button:
			button.button_pressed = bool(allowed_variant) == _selected_auto_attack_allowed
	_refresh_game_setup_summary()
	for allowed_variant in _multiplayer_auto_attack_buttons:
		var multiplayer_button := _multiplayer_auto_attack_buttons[allowed_variant] as Button
		if multiplayer_button:
			multiplayer_button.button_pressed = bool(allowed_variant) == _selected_auto_attack_allowed
	_refresh_multiplayer_settings_summary()


func _set_selected_difficulty(difficulty: int) -> void:
	_selected_difficulty = clampi(difficulty, MatchSetup.AIDifficulty.EASY, MatchSetup.AIDifficulty.HARD)
	for difficulty_variant in _difficulty_buttons:
		var button := _difficulty_buttons[difficulty_variant] as Button
		if button:
			button.button_pressed = int(difficulty_variant) == _selected_difficulty
	_refresh_game_setup_summary()


func _configured_game_name() -> String:
	if not _game_setup_game_name_input:
		return ""
	var entered_name := _game_setup_game_name_input.text.strip_edges()
	if entered_name in [MatchSetup.DEFAULT_MATCH_NAME, tr(MatchSetup.DEFAULT_MATCH_NAME)]:
		return MatchSetup.DEFAULT_MATCH_NAME
	if entered_name in [MatchSetup.DEFAULT_DOMINION_MATCH_NAME, tr(MatchSetup.DEFAULT_DOMINION_MATCH_NAME)]:
		return MatchSetup.DEFAULT_DOMINION_MATCH_NAME
	return entered_name


func _is_default_game_name_text(value: String) -> bool:
	return value in [
		MatchSetup.DEFAULT_MATCH_NAME,
		MatchSetup.DEFAULT_DOMINION_MATCH_NAME,
		tr(MatchSetup.DEFAULT_MATCH_NAME),
		tr(MatchSetup.DEFAULT_DOMINION_MATCH_NAME),
	]


func _refresh_game_setup_summary() -> void:
	if not _game_setup_summary:
		return
	var game_name := _configured_game_name()
	var summary_game_name := tr(game_name) if game_name in [MatchSetup.DEFAULT_MATCH_NAME, MatchSetup.DEFAULT_DOMINION_MATCH_NAME] else game_name
	var scope_name := tr("Tüm Kartlar") if _selected_card_pool_mode == MatchSetup.CardPoolMode.ALL_CARDS else tr("Etkin Deste")
	var ruleset_name := tr("Hakimiyet") if _selected_ruleset == MatchSetup.Ruleset.DOMINION else tr("Kuşatma")
	var auto_attack_name := tr("Otomatik Savaş Açık") if _selected_auto_attack_allowed else tr("Otomatik Savaş Kapalı")
	_game_setup_summary.text = "%s  •  %s  •  %s  •  %s  •  %s  •  %s" % [
		summary_game_name if not summary_game_name.is_empty() else tr("Oyun adı bekleniyor"),
		ruleset_name,
		scope_name,
		tr("%d sec") % _selected_turn_duration_seconds,
		tr(MatchSetup.get_difficulty_name(_selected_difficulty)),
		auto_attack_name,
	]
	var missing_name := game_name.is_empty()
	if _game_setup_start_button:
		_game_setup_start_button.disabled = missing_name


func _configured_multiplayer_game_name() -> String:
	if not _multiplayer_game_name_input:
		return MatchSetup.get_default_match_name(_selected_ruleset)
	var entered_name := _multiplayer_game_name_input.text.strip_edges()
	if entered_name.is_empty() or _is_default_game_name_text(entered_name):
		return MatchSetup.get_default_match_name(_selected_ruleset)
	return entered_name.left(MatchSetup.MAX_MATCH_NAME_LENGTH)


func _on_multiplayer_game_name_changed(_value: String) -> void:
	_refresh_multiplayer_settings_summary()


func _get_selected_multiplayer_settings() -> Dictionary:
	return {
		"ruleset": _selected_ruleset,
		"match_name": _configured_multiplayer_game_name(),
		"card_pool_mode": _selected_card_pool_mode,
		"turn_duration_seconds": _selected_turn_duration_seconds,
		"auto_attack_allowed": _selected_auto_attack_allowed,
	}


func _format_multiplayer_settings(settings: Dictionary) -> String:
	var ruleset := int(settings.get("ruleset", MatchSetup.Ruleset.SIEGE))
	var raw_name := str(settings.get("match_name", MatchSetup.get_default_match_name(ruleset)))
	var display_name := tr(raw_name) if _is_default_game_name_text(raw_name) else raw_name
	var ruleset_name := tr("Hakimiyet") if ruleset == MatchSetup.Ruleset.DOMINION else tr("Kuşatma")
	var card_pool_name := (
		tr("Tüm Kartlar")
		if int(settings.get("card_pool_mode", MatchSetup.CardPoolMode.DECK)) == MatchSetup.CardPoolMode.ALL_CARDS
		else tr("Etkin Deste")
	)
	var auto_attack_name := (
		tr("Otomatik Savaş Açık")
		if bool(settings.get("auto_attack_allowed", true))
		else tr("Otomatik Savaş Kapalı")
	)
	return "%s  •  %s  •  %s  •  %d sn  •  %s" % [
		display_name,
		ruleset_name,
		card_pool_name,
		int(round(float(settings.get("turn_duration_seconds", GameRules.TURN_DURATION_SECONDS)))),
		auto_attack_name,
	]


func _refresh_multiplayer_settings_summary(room_settings: Dictionary = {}) -> void:
	var selected_settings := _get_selected_multiplayer_settings()
	if _multiplayer_settings_summary:
		_multiplayer_settings_summary.text = _format_multiplayer_settings(selected_settings)
	if _multiplayer_host_create_button:
		_multiplayer_host_create_button.disabled = _configured_multiplayer_game_name().is_empty()
	if _multiplayer_room_settings_label and not room_settings.is_empty():
		_multiplayer_room_settings_label.text = _format_multiplayer_settings(room_settings)


func _build_multiplayer_overlay() -> void:
	_multiplayer_overlay = _make_modal_overlay("MultiplayerOverlay", Color(0.003, 0.007, 0.012, 0.86))
	add_child(_multiplayer_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_multiplayer_overlay.add_child(center)

	_multiplayer_panel = PanelContainer.new()
	_multiplayer_panel.name = "MultiplayerPanel"
	_multiplayer_panel.custom_minimum_size = Vector2(980.0, 684.0)
	_multiplayer_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(0.025, 0.035, 0.046, 0.99), Color(0.28, 0.68, 0.86, 0.86), 1, 11, 22.0)
	)
	center.add_child(_multiplayer_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_multiplayer_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_stack)
	var eyebrow := _make_muted_label("ÖZEL ODA  •  HOST AYARLARI SENKRON", 11)
	eyebrow.add_theme_color_override("font_color", Color(0.44, 0.78, 0.94))
	title_stack.add_child(eyebrow)
	var title := _make_heading("ÇEVRİMİÇİ SAVAŞ", 28)
	title.name = "MultiplayerTitle"
	title_stack.add_child(title)
	var close_button := _make_icon_button("MultiplayerCloseButton", "×")
	close_button.pressed.connect(_hide_multiplayer)
	header.add_child(close_button)

	var intro := _make_muted_label(
		"Odayı kuran komutan maç adını, modu, kart kapsamını, tur süresini ve otomatik savaş iznini belirler.",
		12
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.y = 30.0
	content.add_child(intro)

	var mode_row := HBoxContainer.new()
	mode_row.name = "MultiplayerModeRow"
	mode_row.add_theme_constant_override("separation", 10)
	content.add_child(mode_row)
	_multiplayer_host_mode_button = _make_action_button("HostModeButton", "ODA KUR", Color(0.38, 0.72, 0.50))
	_multiplayer_host_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_multiplayer_host_mode_button.pressed.connect(_show_multiplayer_mode.bind(true))
	mode_row.add_child(_multiplayer_host_mode_button)
	_multiplayer_join_mode_button = _make_action_button("JoinModeButton", "KODLA KATIL", Color(0.28, 0.68, 0.86))
	_multiplayer_join_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_multiplayer_join_mode_button.pressed.connect(_show_multiplayer_mode.bind(false))
	mode_row.add_child(_multiplayer_join_mode_button)
	_multiplayer_steam_mode_button = _make_action_button("SteamModeButton", "STEAM P2P", Color(0.36, 0.62, 0.92))
	_multiplayer_steam_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_multiplayer_steam_mode_button.pressed.connect(_show_steam_multiplayer_mode)
	mode_row.add_child(_multiplayer_steam_mode_button)

	var mode_stack := Control.new()
	mode_stack.name = "MultiplayerModeStack"
	mode_stack.custom_minimum_size.y = 390.0
	mode_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(mode_stack)
	_build_multiplayer_host_panel(mode_stack)
	_build_multiplayer_join_panel(mode_stack)
	_build_multiplayer_steam_panel(mode_stack)

	_multiplayer_players_label = _make_muted_label("2 oyuncu dolunca maç otomatik başlar.", 12)
	_multiplayer_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_multiplayer_players_label)

	_multiplayer_status_label = Label.new()
	_multiplayer_status_label.name = "MultiplayerStatus"
	_multiplayer_status_label.text = "Kod bekleniyor."
	_multiplayer_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplayer_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_multiplayer_status_label.custom_minimum_size.y = 30.0
	_multiplayer_status_label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_multiplayer_status_label.add_theme_font_size_override("font_size", 13)
	_multiplayer_status_label.add_theme_color_override("font_color", Color(CREAM, 0.84))
	content.add_child(_multiplayer_status_label)

	_show_multiplayer_mode(true)


func _build_multiplayer_host_panel(parent: Control) -> void:
	_multiplayer_host_panel = VBoxContainer.new()
	_multiplayer_host_panel.name = "HostRoomPanel"
	_multiplayer_host_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_multiplayer_host_panel.add_theme_constant_override("separation", 6)
	parent.add_child(_multiplayer_host_panel)

	var identity_row := HBoxContainer.new()
	identity_row.name = "HostIdentityRow"
	identity_row.add_theme_constant_override("separation", 10)
	_multiplayer_host_panel.add_child(identity_row)
	_multiplayer_host_name_input = _make_multiplayer_line_edit("HostPlayerNameInput", "Komutan adı")
	_multiplayer_host_name_input.max_length = 24
	_multiplayer_host_name_input.custom_minimum_size.y = 38.0
	_multiplayer_host_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_row.add_child(_multiplayer_host_name_input)
	_multiplayer_host_address_input = _make_multiplayer_line_edit("HostAddressInput", "IPv4 adresi")
	_multiplayer_host_address_input.custom_minimum_size.y = 38.0
	_multiplayer_host_address_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_row.add_child(_multiplayer_host_address_input)
	_multiplayer_host_port_input = _make_multiplayer_line_edit("HostPortInput", "7777")
	_multiplayer_host_port_input.custom_minimum_size.x = 112.0
	_multiplayer_host_port_input.custom_minimum_size.y = 38.0
	_multiplayer_host_port_input.max_length = 5
	_multiplayer_host_port_input.text = "7777"
	identity_row.add_child(_multiplayer_host_port_input)

	var settings_plate := PanelContainer.new()
	settings_plate.name = "HostGameSettingsPlate"
	settings_plate.add_theme_stylebox_override(
		"panel",
		_make_button_style(Color(0.010, 0.017, 0.025, 0.94), Color(0.28, 0.68, 0.86, 0.34), 1, 8, 12.0)
	)
	_multiplayer_host_panel.add_child(settings_plate)
	var settings_grid := GridContainer.new()
	settings_grid.name = "HostGameSettingsGrid"
	settings_grid.columns = 2
	settings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_grid.add_theme_constant_override("h_separation", 14)
	settings_grid.add_theme_constant_override("v_separation", 4)
	settings_plate.add_child(settings_grid)

	settings_grid.add_child(_make_multiplayer_setting_copy("MAÇ ADI", "Lobide ve maç geçmişinde görünür."))
	_multiplayer_game_name_input = _make_multiplayer_line_edit("HostGameNameInput", "Maç adı")
	_multiplayer_game_name_input.max_length = MatchSetup.MAX_MATCH_NAME_LENGTH
	_multiplayer_game_name_input.custom_minimum_size.y = 36.0
	_multiplayer_game_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_multiplayer_game_name_input.text = tr(MatchSetup.get_default_match_name(_selected_ruleset))
	_multiplayer_game_name_input.text_changed.connect(_on_multiplayer_game_name_changed)
	settings_grid.add_child(_multiplayer_game_name_input)

	settings_grid.add_child(_make_multiplayer_setting_copy("OYUN MODU", "Zafer koşulunu seç."))
	var ruleset_row := HBoxContainer.new()
	ruleset_row.name = "HostRulesetRow"
	ruleset_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ruleset_row.add_theme_constant_override("separation", 8)
	settings_grid.add_child(ruleset_row)
	var ruleset_group := ButtonGroup.new()
	ruleset_group.allow_unpress = false
	for definition in [
		{
			"ruleset": MatchSetup.Ruleset.SIEGE,
			"name": "HostSiegeRulesetButton",
			"text": "KUŞATMA",
			"accent": Color(0.78, 0.49, 0.25),
		},
		{
			"ruleset": MatchSetup.Ruleset.DOMINION,
			"name": "HostDominionRulesetButton",
			"text": "HAKİMİYET",
			"accent": Color(0.38, 0.68, 0.92),
		},
	]:
		var ruleset := int(definition["ruleset"])
		var button := _make_action_button(
			str(definition["name"]),
			str(definition["text"]),
			definition["accent"] as Color,
			ruleset == MatchSetup.Ruleset.DOMINION
		)
		button.toggle_mode = true
		button.button_group = ruleset_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 34.0
		button.pressed.connect(_set_ruleset.bind(ruleset))
		ruleset_row.add_child(button)
		_multiplayer_ruleset_buttons[ruleset] = button

	settings_grid.add_child(_make_multiplayer_setting_copy("KART KAPSAMI", "Etkin deste veya tüm kartlar."))
	var card_pool_row := HBoxContainer.new()
	card_pool_row.name = "HostCardPoolRow"
	card_pool_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_pool_row.add_theme_constant_override("separation", 8)
	settings_grid.add_child(card_pool_row)
	var card_pool_group := ButtonGroup.new()
	card_pool_group.allow_unpress = false
	for definition in [
		{"mode": MatchSetup.CardPoolMode.DECK, "name": "HostDeckCardPoolButton", "text": "ETKİN DESTE"},
		{"mode": MatchSetup.CardPoolMode.ALL_CARDS, "name": "HostAllCardsPoolButton", "text": "TÜM KARTLAR"},
	]:
		var mode := int(definition["mode"])
		var pool_button := _make_action_button(
			str(definition["name"]),
			str(definition["text"]),
			Color(0.52, 0.72, 0.88),
			mode == MatchSetup.CardPoolMode.ALL_CARDS
		)
		pool_button.toggle_mode = true
		pool_button.button_group = card_pool_group
		pool_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pool_button.custom_minimum_size.y = 34.0
		pool_button.pressed.connect(_set_card_pool_mode.bind(mode))
		card_pool_row.add_child(pool_button)
		_multiplayer_card_pool_buttons[mode] = pool_button

	settings_grid.add_child(_make_multiplayer_setting_copy("TUR SÜRESİ", "Her oyuncu değişiminde yenilenir."))
	var duration_row := HBoxContainer.new()
	duration_row.name = "HostTurnDurationRow"
	duration_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_row.add_theme_constant_override("separation", 6)
	settings_grid.add_child(duration_row)
	var duration_group := ButtonGroup.new()
	duration_group.allow_unpress = false
	for definition in TURN_DURATION_CHOICES:
		var seconds := int(definition["seconds"])
		var duration_button := _make_action_button(
			"HostTurnDuration%dButton" % seconds,
			tr(str(definition["label"])),
			Color(0.42, 0.64, 0.84),
			seconds != int(GameRules.TURN_DURATION_SECONDS)
		)
		duration_button.toggle_mode = true
		duration_button.button_group = duration_group
		duration_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		duration_button.custom_minimum_size = Vector2(72.0, 34.0)
		duration_button.add_theme_font_size_override("font_size", 11)
		duration_button.pressed.connect(_set_turn_duration.bind(seconds))
		duration_row.add_child(duration_button)
		_multiplayer_turn_duration_buttons[seconds] = duration_button

	settings_grid.add_child(_make_multiplayer_setting_copy("OTOMATİK SAVAŞ", "Oyuncular isterse seri saldırı kullanır."))
	var auto_attack_row := HBoxContainer.new()
	auto_attack_row.name = "HostAutoAttackRow"
	auto_attack_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_attack_row.add_theme_constant_override("separation", 8)
	settings_grid.add_child(auto_attack_row)
	var auto_attack_group := ButtonGroup.new()
	auto_attack_group.allow_unpress = false
	for definition in [
		{"allowed": true, "name": "HostAllowAutoAttackButton", "text": "İZİN VER", "accent": Color(0.30, 0.72, 0.41)},
		{"allowed": false, "name": "HostDisableAutoAttackButton", "text": "KAPALI", "accent": Color(0.64, 0.42, 0.34)},
	]:
		var allowed := bool(definition["allowed"])
		var auto_button := _make_action_button(
			str(definition["name"]),
			str(definition["text"]),
			definition["accent"] as Color,
			not allowed
		)
		auto_button.toggle_mode = true
		auto_button.button_group = auto_attack_group
		auto_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		auto_button.custom_minimum_size.y = 34.0
		auto_button.pressed.connect(_set_auto_attack_allowed.bind(allowed))
		auto_attack_row.add_child(auto_button)
		_multiplayer_auto_attack_buttons[allowed] = auto_button

	_multiplayer_settings_summary = _make_muted_label("", 10)
	_multiplayer_settings_summary.name = "HostSettingsSummary"
	_multiplayer_settings_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplayer_settings_summary.add_theme_color_override("font_color", Color(0.58, 0.82, 0.94))
	_multiplayer_host_panel.add_child(_multiplayer_settings_summary)

	var hint := _make_muted_label("Yerel ağda önerilen IPv4 yeterlidir; internet davetinde UDP portunu yönlendiricide aç.", 10)
	hint.name = "HostNetworkHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplayer_host_panel.add_child(hint)

	var invite_row := HBoxContainer.new()
	invite_row.name = "HostInviteRow"
	invite_row.add_theme_constant_override("separation", 8)
	_multiplayer_host_panel.add_child(invite_row)
	_multiplayer_host_invite_input = _make_multiplayer_line_edit("HostedInviteCode", "Oda kurulunca davet kodu burada görünür")
	_multiplayer_host_invite_input.editable = false
	_multiplayer_host_invite_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplayer_host_invite_input.custom_minimum_size.y = 38.0
	_multiplayer_host_invite_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invite_row.add_child(_multiplayer_host_invite_input)
	_multiplayer_copy_invite_button = _make_action_button("CopyInviteButton", "KODU KOPYALA", Color(0.28, 0.68, 0.86), true)
	_multiplayer_copy_invite_button.disabled = true
	_multiplayer_copy_invite_button.custom_minimum_size.y = 38.0
	_multiplayer_copy_invite_button.pressed.connect(_copy_hosted_invite)
	invite_row.add_child(_multiplayer_copy_invite_button)

	var actions := HBoxContainer.new()
	actions.name = "HostRoomActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	_multiplayer_host_panel.add_child(actions)
	_multiplayer_host_create_button = _make_action_button("CreateRoomButton", "ODAYI OLUŞTUR", Color(0.38, 0.72, 0.50))
	_multiplayer_host_create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_multiplayer_host_create_button.custom_minimum_size.y = 38.0
	_multiplayer_host_create_button.pressed.connect(_create_multiplayer_room)
	actions.add_child(_multiplayer_host_create_button)
	_multiplayer_leave_room_button = _make_action_button("LeaveRoomButton", "ODAYI KAPAT", Color(0.72, 0.39, 0.32), true)
	_multiplayer_leave_room_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_multiplayer_leave_room_button.custom_minimum_size.y = 38.0
	_multiplayer_leave_room_button.visible = false
	_multiplayer_leave_room_button.pressed.connect(_leave_hosted_room)
	actions.add_child(_multiplayer_leave_room_button)

	_set_ruleset(_selected_ruleset)
	_set_card_pool_mode(_selected_card_pool_mode)
	_set_turn_duration(_selected_turn_duration_seconds)
	_set_auto_attack_allowed(_selected_auto_attack_allowed)
	_refresh_multiplayer_settings_summary()


func _build_multiplayer_join_panel(parent: Control) -> void:
	_multiplayer_join_panel = VBoxContainer.new()
	_multiplayer_join_panel.name = "JoinRoomPanel"
	_multiplayer_join_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_multiplayer_join_panel.add_theme_constant_override("separation", 12)
	parent.add_child(_multiplayer_join_panel)

	var join_intro := PanelContainer.new()
	join_intro.name = "JoinRoomIntroPlate"
	join_intro.add_theme_stylebox_override(
		"panel",
		_make_button_style(Color(0.010, 0.017, 0.025, 0.94), Color(0.28, 0.68, 0.86, 0.34), 1, 8, 16.0)
	)
	_multiplayer_join_panel.add_child(join_intro)
	var intro_copy := VBoxContainer.new()
	intro_copy.add_theme_constant_override("separation", 3)
	join_intro.add_child(intro_copy)
	var join_title := _make_heading("DAVET KODUYLA KATIL", 19)
	join_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_copy.add_child(join_title)
	var join_description := _make_muted_label(
		"Oda kurucusunun belirlediği maç ayarları bağlandığında otomatik uygulanır; yalnızca komutan adını ve kodu girmen yeterli.",
		11
	)
	join_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_copy.add_child(join_description)

	var form := GridContainer.new()
	form.name = "JoinRoomForm"
	form.columns = 2
	form.add_theme_constant_override("h_separation", 12)
	form.add_theme_constant_override("v_separation", 10)
	_multiplayer_join_panel.add_child(form)
	form.add_child(_make_multiplayer_setting_copy("KOMUTAN ADI", "Rakibin savaş alanında görür."))
	_multiplayer_name_input = _make_multiplayer_line_edit("PlayerNameInput", "Komutan")
	_multiplayer_name_input.max_length = 24
	form.add_child(_multiplayer_name_input)
	form.add_child(_make_multiplayer_setting_copy("DAVET KODU", "Oda sahibinden aldığın 20 karakter."))
	_multiplayer_code_input = _make_multiplayer_line_edit("InviteCodeInput", "XXXXX-XXXXX-XXXXX-XXXXX")
	_multiplayer_code_input.max_length = 23
	_multiplayer_code_input.text_changed.connect(_on_invite_code_changed)
	_multiplayer_code_input.text_submitted.connect(func(_value: String): _join_multiplayer())
	form.add_child(_multiplayer_code_input)

	var room_settings_plate := PanelContainer.new()
	room_settings_plate.name = "JoinedRoomSettingsPlate"
	room_settings_plate.add_theme_stylebox_override(
		"panel",
		_make_button_style(Color(0.025, 0.045, 0.055, 0.88), Color(0.38, 0.72, 0.90, 0.48), 1, 8, 16.0)
	)
	_multiplayer_join_panel.add_child(room_settings_plate)
	var room_settings_copy := VBoxContainer.new()
	room_settings_copy.add_theme_constant_override("separation", 4)
	room_settings_plate.add_child(room_settings_copy)
	var room_settings_title := _make_muted_label("ODA AYARLARI", 10)
	room_settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_settings_title.add_theme_color_override("font_color", Color(0.54, 0.84, 1.0))
	room_settings_copy.add_child(room_settings_title)
	_multiplayer_room_settings_label = Label.new()
	_multiplayer_room_settings_label.name = "JoinedRoomSettings"
	_multiplayer_room_settings_label.text = "Bağlantı kurulunca maç adı ve tüm oyun kuralları burada görünecek."
	_multiplayer_room_settings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplayer_room_settings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_multiplayer_room_settings_label.custom_minimum_size.y = 48.0
	_multiplayer_room_settings_label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_multiplayer_room_settings_label.add_theme_font_size_override("font_size", 12)
	_multiplayer_room_settings_label.add_theme_color_override("font_color", CREAM)
	room_settings_copy.add_child(_multiplayer_room_settings_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	_multiplayer_join_panel.add_child(actions)
	_multiplayer_reconnect_button = _make_action_button("ReconnectButton", "YENİDEN BAĞLAN", Color(0.91, 0.70, 0.24), true)
	_multiplayer_reconnect_button.visible = false
	_multiplayer_reconnect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_multiplayer_reconnect_button.pressed.connect(_reconnect_multiplayer)
	actions.add_child(_multiplayer_reconnect_button)
	_multiplayer_join_button = _make_action_button("MultiplayerJoinButton", "SUNUCUYA KATIL", Color(0.28, 0.68, 0.86))
	_multiplayer_join_button.disabled = true
	_multiplayer_join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_multiplayer_join_button.pressed.connect(_join_multiplayer)
	actions.add_child(_multiplayer_join_button)


func _build_multiplayer_steam_panel(parent: Control) -> void:
	_multiplayer_steam_panel = VBoxContainer.new()
	_multiplayer_steam_panel.name = "SteamP2PPanel"
	_multiplayer_steam_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_multiplayer_steam_panel.add_theme_constant_override("separation", 8)
	parent.add_child(_multiplayer_steam_panel)

	var identity_plate := PanelContainer.new()
	identity_plate.name = "SteamIdentityPlate"
	identity_plate.add_theme_stylebox_override(
		"panel",
		_make_button_style(Color(0.012, 0.022, 0.034, 0.96), Color(0.36, 0.62, 0.92, 0.54), 1, 8, 12.0)
	)
	_multiplayer_steam_panel.add_child(identity_plate)
	_steam_identity_label = _make_muted_label("Steam istemcisi denetleniyor…", 12)
	_steam_identity_label.name = "SteamIdentityStatus"
	_steam_identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_steam_identity_label.add_theme_color_override("font_color", Color(0.58, 0.82, 1.0))
	identity_plate.add_child(_steam_identity_label)

	var settings := GridContainer.new()
	settings.name = "SteamRoomSettings"
	settings.columns = 5
	settings.add_theme_constant_override("h_separation", 8)
	settings.add_theme_constant_override("v_separation", 4)
	_multiplayer_steam_panel.add_child(settings)
	_steam_game_name_input = _make_multiplayer_line_edit("SteamGameNameInput", "Maç adı")
	_steam_game_name_input.max_length = MatchSetup.MAX_MATCH_NAME_LENGTH
	_steam_game_name_input.text = tr(MatchSetup.get_default_match_name(_selected_ruleset))
	_steam_game_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steam_game_name_input.custom_minimum_size.x = 220.0
	settings.add_child(_steam_game_name_input)

	_steam_ruleset_option = OptionButton.new()
	_steam_ruleset_option.name = "SteamRulesetOption"
	_steam_ruleset_option.add_item("Kuşatma", MatchSetup.Ruleset.SIEGE)
	_steam_ruleset_option.add_item("Hakimiyet", MatchSetup.Ruleset.DOMINION)
	_steam_ruleset_option.select(_steam_ruleset_option.get_item_index(_selected_ruleset))
	_steam_ruleset_option.tooltip_text = "Oyun modu"
	settings.add_child(_steam_ruleset_option)

	_steam_card_pool_option = OptionButton.new()
	_steam_card_pool_option.name = "SteamCardPoolOption"
	_steam_card_pool_option.add_item("Etkin deste", MatchSetup.CardPoolMode.DECK)
	_steam_card_pool_option.add_item("Tüm kartlar", MatchSetup.CardPoolMode.ALL_CARDS)
	_steam_card_pool_option.select(_steam_card_pool_option.get_item_index(_selected_card_pool_mode))
	_steam_card_pool_option.tooltip_text = "Kart kapsamı"
	settings.add_child(_steam_card_pool_option)

	_steam_turn_duration_option = OptionButton.new()
	_steam_turn_duration_option.name = "SteamTurnDurationOption"
	for definition in TURN_DURATION_CHOICES:
		var seconds := int(definition.get("seconds", GameRules.TURN_DURATION_SECONDS))
		_steam_turn_duration_option.add_item(tr(str(definition.get("label", "%d sn" % seconds))), seconds)
	_steam_turn_duration_option.select(
		_steam_turn_duration_option.get_item_index(_selected_turn_duration_seconds)
	)
	_steam_turn_duration_option.tooltip_text = "Tur süresi"
	settings.add_child(_steam_turn_duration_option)

	_steam_auto_attack_check = CheckButton.new()
	_steam_auto_attack_check.name = "SteamAutoAttackCheck"
	_steam_auto_attack_check.text = "Oto savaş"
	_steam_auto_attack_check.button_pressed = _selected_auto_attack_allowed
	_steam_auto_attack_check.tooltip_text = "Otomatik savaş izni"
	settings.add_child(_steam_auto_attack_check)

	var actions := HBoxContainer.new()
	actions.name = "SteamLobbyActions"
	actions.add_theme_constant_override("separation", 8)
	_multiplayer_steam_panel.add_child(actions)
	_steam_host_button = _make_action_button("SteamCreateLobbyButton", "STEAM ODASI AÇ", Color(0.38, 0.72, 0.50))
	_steam_host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steam_host_button.pressed.connect(_create_steam_room)
	actions.add_child(_steam_host_button)
	_steam_refresh_button = _make_action_button("SteamRefreshLobbiesButton", "LOBİLERİ YENİLE", Color(0.36, 0.62, 0.92), true)
	_steam_refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steam_refresh_button.pressed.connect(_refresh_steam_lobbies)
	actions.add_child(_steam_refresh_button)
	_steam_invite_button = _make_action_button("SteamInviteFriendsButton", "ARKADAŞ DAVET ET", Color(0.52, 0.70, 0.94), true)
	_steam_invite_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steam_invite_button.disabled = true
	_steam_invite_button.pressed.connect(_invite_steam_friends)
	actions.add_child(_steam_invite_button)
	_steam_leave_button = _make_action_button("SteamLeaveLobbyButton", "LOBİDEN AYRIL", Color(0.72, 0.39, 0.32), true)
	_steam_leave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steam_leave_button.visible = false
	_steam_leave_button.pressed.connect(_leave_steam_lobby)
	actions.add_child(_steam_leave_button)
	_steam_reconnect_button = _make_action_button("SteamReconnectButton", "YENİDEN BAĞLAN", Color(0.91, 0.70, 0.24), true)
	_steam_reconnect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steam_reconnect_button.visible = false
	_steam_reconnect_button.pressed.connect(_reconnect_multiplayer)
	actions.add_child(_steam_reconnect_button)

	var list_title := _make_muted_label("AÇIK DARWINE LOBİLERİ", 10)
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplayer_steam_panel.add_child(list_title)
	var scroll := ScrollContainer.new()
	scroll.name = "SteamLobbyScroll"
	scroll.custom_minimum_size.y = 178.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_multiplayer_steam_panel.add_child(scroll)
	_steam_lobby_list = VBoxContainer.new()
	_steam_lobby_list.name = "SteamLobbyList"
	_steam_lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steam_lobby_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_steam_lobby_list)
	_render_steam_lobbies([])


func _make_multiplayer_setting_copy(title_text: String, caption_text: String) -> VBoxContainer:
	var copy := VBoxContainer.new()
	copy.custom_minimum_size.x = 170.0
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 0)
	var title := Label.new()
	title.text = title_text
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.76, 0.88, 0.96))
	copy.add_child(title)
	var caption := _make_muted_label(caption_text, 9)
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(caption)
	return copy


func _make_multiplayer_line_edit(node_name: String, placeholder: String) -> LineEdit:
	var input := LineEdit.new()
	input.name = node_name
	input.placeholder_text = placeholder
	input.custom_minimum_size.y = 48.0
	input.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	input.add_theme_font_size_override("font_size", 16)
	input.add_theme_color_override("font_color", CREAM)
	input.add_theme_color_override("font_placeholder_color", Color(MUTED, 0.70))
	input.add_theme_stylebox_override("normal", _make_button_style(Color(0.012, 0.018, 0.026, 0.98), Color(0.28, 0.68, 0.86, 0.50), 1, 7, 15.0))
	input.add_theme_stylebox_override("focus", _make_button_style(Color(0.018, 0.029, 0.042, 1.0), Color(0.44, 0.82, 1.0, 0.92), 2, 7, 15.0))
	return input
func _make_difficulty_button(
	node_name: String,
	title_text: String,
	description_text: String,
	accent: Color,
	emblem_type: int,
	difficulty: int
	) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(180.0, 98.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = tr("%s difficulty level") % tr(title_text).capitalize()
	UI.style_button(button, accent, false, true, difficulty == MatchSetup.AIDifficulty.MEDIUM)
	button.toggle_mode = true
	button.button_group = _difficulty_button_group
	button.pressed.connect(_set_selected_difficulty.bind(difficulty))
	_difficulty_buttons[difficulty] = button

	var content_margin := MarginContainer.new()
	content_margin.name = "%sContent" % node_name.trim_suffix("Button")
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_top", 9)
	content_margin.add_theme_constant_override("margin_right", 8)
	content_margin.add_theme_constant_override("margin_bottom", 9)
	button.add_child(content_margin)

	var content := HBoxContainer.new()
	content.name = "%sContentRow" % node_name.trim_suffix("Button")
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	content_margin.add_child(content)

	var emblem := DIFFICULTY_EMBLEM_SCRIPT.new() as Control
	emblem.name = "%sEmblem" % node_name.trim_suffix("Button")
	emblem.custom_minimum_size = Vector2(46.0, 46.0)
	emblem.set("emblem_type", emblem_type)
	emblem.set("accent_color", accent)
	content.add_child(emblem)

	var copy := VBoxContainer.new()
	copy.name = "%sCopy" % node_name.trim_suffix("Button")
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 1)
	content.add_child(copy)

	var title := Label.new()
	title.name = "%sTitle" % node_name.trim_suffix("Button")
	title.text = title_text
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", CREAM)
	copy.add_child(title)

	var description := Label.new()
	description.name = "%sDescription" % node_name.trim_suffix("Button")
	description.text = description_text
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font", UI.BODY_FONT)
	description.add_theme_font_size_override("font_size", 10)
	description.add_theme_color_override("font_color", Color(CREAM, 0.74))
	copy.add_child(description)
	return button


func _build_settings_overlay() -> void:
	_settings_overlay = _make_modal_overlay("SettingsOverlay")
	add_child(_settings_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(center)

	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.custom_minimum_size = Vector2(880.0, 610.0)
	_settings_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(0.045, 0.041, 0.038, 0.985), Color(GOLD, 0.72), 1, 5, 26.0)
	)
	center.add_child(_settings_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var header_balance := Control.new()
	header_balance.name = "SettingsHeaderBalance"
	header_balance.custom_minimum_size.x = 42.0
	header.add_child(header_balance)

	var header_copy := VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.add_theme_constant_override("separation", 2)
	header.add_child(header_copy)

	var title := _make_heading("AYARLAR", 30)
	title.name = "SettingsTitle"
	header_copy.add_child(title)
	var subtitle := _make_muted_label("Oyun deneyimini düzenle.", 13)
	subtitle.name = "SettingsSubtitle"
	header_copy.add_child(subtitle)

	var close_button := _make_icon_button("SettingsCloseButton", "×")
	close_button.pressed.connect(_hide_settings)
	header.add_child(close_button)

	var header_rule := HSeparator.new()
	header_rule.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.30), 1))
	content.add_child(header_rule)

	_settings_tabs = TabContainer.new()
	_settings_tabs.name = "SettingsTabs"
	_settings_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_tabs.custom_minimum_size.y = 405.0
	_settings_tabs.add_theme_stylebox_override(
		"panel",
		_make_button_style(Color(0.025, 0.024, 0.023, 0.72), Color(GOLD, 0.24), 1, 3, 0.0)
	)
	content.add_child(_settings_tabs)
	_style_settings_tabs(_settings_tabs)

	_settings_tabs.add_child(_build_display_settings_tab())
	_settings_tabs.set_tab_title(_settings_tabs.get_tab_count() - 1, "GÖRÜNTÜ")
	_settings_tabs.add_child(_build_audio_settings_tab())
	_settings_tabs.set_tab_title(_settings_tabs.get_tab_count() - 1, "SES")
	_settings_tabs.add_child(_build_gameplay_settings_tab())
	_settings_tabs.set_tab_title(_settings_tabs.get_tab_count() - 1, "OYNANIŞ")
	_settings_tabs.add_child(_build_language_settings_tab())
	_settings_tabs.set_tab_title(_settings_tabs.get_tab_count() - 1, "LANGUAGE")

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	content.add_child(actions)
	var note := Label.new()
	note.text = "DEĞİŞİKLİKLER OTOMATİK KAYDEDİLİR"
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.46, 0.47, 0.46))
	actions.add_child(note)
	var reset_button := _make_action_button("SettingsResetButton", "Varsayılanlar", Color(0.49, 0.46, 0.40), true)
	reset_button.pressed.connect(_reset_settings_to_defaults)
	actions.add_child(reset_button)
	var done_button := _make_action_button("SettingsDoneButton", "Tamam", GOLD)
	done_button.pressed.connect(_hide_settings)
	actions.add_child(done_button)


func _style_settings_tabs(tabs: TabContainer) -> void:
	var tab_bar := tabs.get_tab_bar()
	tab_bar.add_theme_font_size_override("font_size", 13)
	tab_bar.add_theme_color_override("font_unselected_color", Color(0.57, 0.55, 0.51))
	tab_bar.add_theme_color_override("font_hovered_color", CREAM)
	tab_bar.add_theme_color_override("font_selected_color", GOLD_BRIGHT)
	tab_bar.add_theme_stylebox_override(
		"tab_unselected",
		_make_button_style(Color(0.035, 0.033, 0.031, 0.94), Color(GOLD, 0.16), 1, 2, 24.0)
	)
	tab_bar.add_theme_stylebox_override(
		"tab_hovered",
		_make_button_style(Color(GOLD, 0.10), Color(GOLD, 0.42), 1, 2, 24.0)
	)
	tab_bar.add_theme_stylebox_override(
		"tab_selected",
		_make_button_style(Color(0.18, 0.12, 0.05, 0.96), Color(GOLD_BRIGHT, 0.78), 1, 2, 24.0)
	)
	tab_bar.add_theme_stylebox_override(
		"tab_focus",
		_make_button_style(Color(0.0, 0.0, 0.0, 0.0), Color(GOLD_BRIGHT, 0.90), 2, 2, 24.0)
	)


func _build_display_settings_tab() -> MarginContainer:
	var page := _make_settings_page("DisplayTab")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	page.add_child(box)
	box.add_child(_make_settings_group_label("PENCERE VE GÖRÜNTÜ"))

	_fullscreen_toggle = _make_settings_toggle("FullscreenToggle", true)
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	box.add_child(_make_setting_row(
		"Tam Ekran",
		"Pencere çerçevesini kaldırarak ekranı tamamen kullanır.",
		_fullscreen_toggle
	))
	box.add_child(_make_settings_divider())

	_resolution_option = _make_settings_option("ResolutionOption")
	for resolution in WINDOW_RESOLUTIONS:
		_resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
	_resolution_option.item_selected.connect(_on_resolution_selected)
	box.add_child(_make_setting_row(
		"Çözünürlük",
		"Pencereli modda kullanılacak görüntü boyutu.",
		_resolution_option
	))
	box.add_child(_make_settings_divider())

	_vsync_toggle = _make_settings_toggle("VSyncToggle", true)
	_vsync_toggle.toggled.connect(_on_vsync_toggled)
	box.add_child(_make_setting_row(
		"Dikey Senkronizasyon",
		"Ekran yırtılmasını azaltmak için kareleri monitörle eşler.",
		_vsync_toggle
	))
	box.add_child(_make_settings_divider())

	_fps_limit_option = _make_settings_option("FpsLimitOption")
	_fps_limit_option.add_item("Limitsiz", 0)
	_fps_limit_option.add_item("60 FPS", 60)
	_fps_limit_option.add_item("120 FPS", 120)
	_fps_limit_option.add_item("144 FPS", 144)
	_fps_limit_option.item_selected.connect(_on_fps_limit_selected)
	box.add_child(_make_setting_row(
		"Kare Hızı Sınırı",
		"Güç tüketimini ve kare hızını tercihine göre sınırlar.",
		_fps_limit_option
	))
	return page


func _build_audio_settings_tab() -> MarginContainer:
	var page := _make_settings_page("AudioTab")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	page.add_child(box)
	box.add_child(_make_settings_group_label("SES DÜZEYLERİ"))

	var master := _make_volume_setting(
		"MasterVolumeSlider", "VolumeValue", "Ana Ses", 80.0, _on_volume_changed
	)
	_volume_slider = master["slider"] as HSlider
	_volume_value_label = master["value_label"] as Label
	box.add_child(master["control"] as Control)

	var music := _make_volume_setting(
		"MusicVolumeSlider", "MusicVolumeValue", "Müzik", 70.0, _on_music_volume_changed
	)
	_music_volume_slider = music["slider"] as HSlider
	_music_volume_value_label = music["value_label"] as Label
	box.add_child(music["control"] as Control)

	var effects := _make_volume_setting(
		"EffectsVolumeSlider", "EffectsVolumeValue", "Efektler", 85.0, _on_effects_volume_changed
	)
	_effects_volume_slider = effects["slider"] as HSlider
	_effects_volume_value_label = effects["value_label"] as Label
	box.add_child(effects["control"] as Control)
	return page


func _build_gameplay_settings_tab() -> MarginContainer:
	var page := _make_settings_page("GameplayTab")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	page.add_child(box)
	box.add_child(_make_settings_group_label("KARŞILAŞMA"))

	_default_difficulty_option = _make_settings_option("DefaultDifficultyOption")
	_default_difficulty_option.add_item("Kolay", MatchSetup.AIDifficulty.EASY)
	_default_difficulty_option.add_item("Orta", MatchSetup.AIDifficulty.MEDIUM)
	_default_difficulty_option.add_item("Zor", MatchSetup.AIDifficulty.HARD)
	_default_difficulty_option.item_selected.connect(_on_default_difficulty_selected)
	box.add_child(_make_setting_row(
		"Varsayılan Rakip",
		"Rakip seçim ekranı açıldığında odaklanacak zorluk.",
		_default_difficulty_option
	))
	box.add_child(_make_settings_divider())

	_tutorial_toggle = _make_settings_toggle("TutorialToggle", true)
	_tutorial_toggle.toggled.connect(_on_tutorial_toggled)
	box.add_child(_make_setting_row(
		"İlk Maç Rehberi",
		"İlk karşılaşmada kısa oyun anlatımını gösterir.",
		_tutorial_toggle
	))
	box.add_child(_make_settings_divider())

	_menu_animation_toggle = _make_settings_toggle("MenuAnimationsToggle", true)
	_menu_animation_toggle.toggled.connect(_on_menu_animations_toggled)
	box.add_child(_make_setting_row(
		"Menü Geçişleri",
		"Panel açılışlarında kısa hareket ve solma efektleri kullanır.",
		_menu_animation_toggle
	))
	box.add_child(_make_settings_divider())

	var reset_button := _make_action_button("TutorialResetButton", "Rehberi Sıfırla", Color(0.58, 0.50, 0.38), true)
	reset_button.custom_minimum_size.x = 154.0
	reset_button.pressed.connect(_reset_tutorial_progress)
	box.add_child(_make_setting_row(
		"Rehberi Yeniden Göster",
		"Tamamlanmış ilk maç rehberini bir sonraki maç için hazırlar.",
		reset_button
	))
	_tutorial_status_label = _make_muted_label("", 11)
	_tutorial_status_label.add_theme_color_override("font_color", Color(0.56, 0.72, 0.52))
	box.add_child(_tutorial_status_label)
	return page


func _build_language_settings_tab() -> MarginContainer:
	var page := _make_settings_page("LanguageTab")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	page.add_child(box)
	box.add_child(_make_settings_group_label("GAME LANGUAGE"))
	var description := _make_muted_label(
		"Choose the language used by menus, cards, tutorials and battlefield messages.",
		12
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)

	var grid := GridContainer.new()
	grid.name = "LanguageChoices"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	_language_button_group.allow_unpress = false
	for option in LANGUAGE_OPTIONS:
		grid.add_child(_make_language_button(option as Dictionary))

	var note := _make_muted_label(
		"English is used by default. Your choice is saved automatically.",
		11
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(0.58, 0.72, 0.62))
	box.add_child(note)
	return page


func _make_language_button(option: Dictionary) -> Button:
	var locale := str(option.get("code", "en"))
	var button := Button.new()
	button.name = "Language%sButton" % locale.capitalize()
	button.custom_minimum_size = Vector2(220.0, 86.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.button_group = _language_button_group
	button.tooltip_text = tr("Switch game language to %s") % tr(str(option.get("label", locale)))
	button.pressed.connect(_on_language_selected.bind(locale))
	_language_buttons[locale] = button

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 13)
	margin.add_child(row)
	var flag := LANGUAGE_FLAG_ICON_SCRIPT.new() as LanguageFlagIcon
	flag.name = "Language%sFlag" % locale.capitalize()
	flag.locale = locale
	flag.custom_minimum_size = Vector2(54.0, 32.0)
	flag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flag)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 0)
	row.add_child(copy)
	var label := Label.new()
	label.name = "Language%sLabel" % locale.capitalize()
	label.text = str(option.get("label", locale))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", CREAM)
	copy.add_child(label)
	var native_name := Label.new()
	native_name.text = str(option.get("native", locale))
	native_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	native_name.add_theme_font_override("font", UI.BODY_FONT)
	native_name.add_theme_font_size_override("font_size", 11)
	native_name.add_theme_color_override("font_color", MUTED)
	copy.add_child(native_name)
	return button


func _refresh_language_buttons() -> void:
	if not _settings_manager:
		return
	var selected_locale := str(_settings_manager.language)
	for locale_variant in _language_buttons:
		var locale := str(locale_variant)
		var button := _language_buttons[locale_variant] as Button
		if not button:
			continue
		var selected := locale == selected_locale
		button.set_pressed_no_signal(selected)
		UI.style_button(button, GOLD_BRIGHT if selected else Color(0.48, 0.50, 0.54), false, true, selected)


func _make_settings_page(node_name: String) -> MarginContainer:
	var page := MarginContainer.new()
	page.name = node_name
	page.add_theme_constant_override("margin_left", 22)
	page.add_theme_constant_override("margin_top", 20)
	page.add_theme_constant_override("margin_right", 22)
	page.add_theme_constant_override("margin_bottom", 18)
	return page


func _make_settings_group_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", GOLD)
	return label


func _make_settings_divider() -> HSeparator:
	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.13), 1))
	return divider


func _make_setting_row(title_text: String, hint_text: String, trailing: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 62.0
	row.add_theme_constant_override("separation", 24)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 3)
	row.add_child(copy)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", CREAM)
	copy.add_child(title)
	copy.add_child(_make_muted_label(hint_text, 11))
	trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(trailing)
	return row


func _make_settings_toggle(node_name: String, enabled: bool) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.text = "Açık" if enabled else "Kapalı"
	toggle.button_pressed = enabled
	toggle.custom_minimum_size.x = 108.0
	toggle.add_theme_font_size_override("font_size", 13)
	toggle.add_theme_color_override("font_color", MUTED)
	toggle.add_theme_color_override("font_hover_color", CREAM)
	toggle.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
	toggle.add_theme_color_override("font_focus_color", GOLD_BRIGHT)
	return toggle


func _make_settings_option(node_name: String) -> OptionButton:
	var option := OptionButton.new()
	option.name = node_name
	option.custom_minimum_size = Vector2(190.0, 42.0)
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option.add_theme_font_size_override("font_size", 13)
	UI.style_button(option, GOLD, false, true)
	option.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
	return option


func _make_volume_setting(
	slider_name: String,
	value_name: String,
	label_text: String,
	default_value: float,
	callback: Callable
) -> Dictionary:
	var control := VBoxContainer.new()
	control.add_theme_constant_override("separation", 6)
	var header := HBoxContainer.new()
	control.add_child(header)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", CREAM)
	header.add_child(label)
	var value_label := Label.new()
	value_label.name = value_name
	value_label.text = "%d%%" % int(default_value)
	value_label.custom_minimum_size.x = 52.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = default_value
	slider.custom_minimum_size.y = 28.0
	slider.value_changed.connect(callback)
	_style_settings_slider(slider)
	control.add_child(slider)
	return {"control": control, "slider": slider, "value_label": value_label}


func _style_settings_slider(slider: HSlider) -> void:
	var track := _make_button_style(Color(0.018, 0.018, 0.018, 0.92), Color(GOLD, 0.18), 1, 4, 0.0)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var fill := _make_button_style(Color(GOLD, 0.72), Color(GOLD_BRIGHT, 0.82), 1, 4, 0.0)
	fill.content_margin_top = 3.0
	fill.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", _make_button_style(Color(GOLD_BRIGHT, 0.88), GOLD_BRIGHT, 1, 4, 0.0))


func _build_gallery_overlay() -> void:
	_gallery_overlay = _make_modal_overlay("GalleryOverlay")
	add_child(_gallery_overlay)

	_gallery_panel = PanelContainer.new()
	_gallery_panel.name = "GalleryPanel"
	_gallery_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gallery_panel.offset_left = 28.0
	_gallery_panel.offset_top = 24.0
	_gallery_panel.offset_right = -28.0
	_gallery_panel.offset_bottom = -24.0
	_gallery_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(0.032, 0.033, 0.037, 0.985), Color(GOLD, 0.64), 1, 9, 24.0)
	)
	_gallery_overlay.add_child(_gallery_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 13)
	_gallery_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	content.add_child(header)
	var header_balance := Control.new()
	header_balance.name = "GalleryHeaderBalance"
	header_balance.custom_minimum_size.x = 152.0
	header.add_child(header_balance)

	var header_copy := VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.add_theme_constant_override("separation", 2)
	header.add_child(header_copy)

	_gallery_title_label = _make_heading("KARTLAR", 28)
	_gallery_title_label.name = "GalleryTitle"
	header_copy.add_child(_gallery_title_label)
	header_copy.add_child(_make_muted_label("Kuşatma arşivindeki tüm kartları tür ve nadirliklerine göre incele.", 13))

	_gallery_count_label = Label.new()
	_gallery_count_label.name = "GalleryCount"
	_gallery_count_label.text = "0 KART"
	_gallery_count_label.custom_minimum_size.x = 92.0
	_gallery_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gallery_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gallery_count_label.add_theme_font_size_override("font_size", 13)
	_gallery_count_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	_gallery_count_label.add_theme_stylebox_override(
		"normal",
		_make_stylebox(Color(0.12, 0.10, 0.07, 0.85), Color(GOLD, 0.45), 1, 6, 10.0)
	)
	header.add_child(_gallery_count_label)

	var close_button := _make_icon_button("GalleryCloseButton", "×")
	close_button.pressed.connect(_hide_gallery)
	header.add_child(close_button)

	var filter_section := VBoxContainer.new()
	filter_section.name = "GalleryFilters"
	filter_section.add_theme_constant_override("separation", 6)
	content.add_child(filter_section)

	filter_section.add_child(_make_filter_heading("KART TÜRÜ"))
	var type_filter_row := HBoxContainer.new()
	type_filter_row.name = "TypeFilters"
	type_filter_row.add_theme_constant_override("separation", 8)
	filter_section.add_child(type_filter_row)

	for type_key in ["all"] + TYPE_ORDER:
		var info: Dictionary = TYPE_INFO[type_key]
		var filter_button := _make_filter_button(
			"%sFilter" % type_key.capitalize(),
			str(info["icon"]),
			str(info["label"]),
			info["accent"]
		)
		filter_button.button_group = _filter_group
		filter_button.pressed.connect(_set_gallery_filter.bind(type_key))
		type_filter_row.add_child(filter_button)
		_filter_buttons[type_key] = filter_button
	_filter_buttons["all"].set_pressed_no_signal(true)

	filter_section.add_child(_make_filter_heading("NADİRLİK"))
	var rarity_filter_row := HBoxContainer.new()
	rarity_filter_row.name = "RarityFilters"
	rarity_filter_row.add_theme_constant_override("separation", 8)
	filter_section.add_child(rarity_filter_row)

	for rarity_key in ["all"] + RARITY_ORDER:
		var rarity_info: Dictionary = RARITY_INFO[rarity_key]
		var rarity_button := _make_filter_button(
			"%sRarityFilter" % rarity_key.capitalize(),
			str(rarity_info["icon"]),
			str(rarity_info["label"]),
			rarity_info["accent"]
		)
		rarity_button.button_group = _rarity_filter_group
		rarity_button.pressed.connect(_set_gallery_rarity_filter.bind(rarity_key))
		rarity_filter_row.add_child(rarity_button)
		_rarity_filter_buttons[rarity_key] = rarity_button
	_rarity_filter_buttons["all"].set_pressed_no_signal(true)

	var filter_rule := HSeparator.new()
	filter_rule.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.22), 1))
	content.add_child(filter_rule)

	var scroll := ScrollContainer.new()
	scroll.name = "CardScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_gallery_grid = GridContainer.new()
	_gallery_grid.name = "CardGrid"
	_gallery_grid.columns = 4
	_gallery_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gallery_grid.add_theme_constant_override("h_separation", 15)
	_gallery_grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(_gallery_grid)

	var hint := Label.new()
	hint.text = "Bir kartı seçerek ayrıntılarını aç  •  Esc ile galeriye dön"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.47, 0.47, 0.46))
	content.add_child(hint)

	_build_detail_overlay()


func _build_detail_overlay() -> void:
	_detail_overlay = _make_modal_overlay("CardDetailOverlay", Color(0.005, 0.006, 0.009, 0.86))
	_gallery_overlay.add_child(_detail_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_overlay.add_child(center)

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "CardDetailPanel"
	_detail_panel.custom_minimum_size = Vector2(900.0, 570.0)
	_detail_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(0.050, 0.048, 0.048, 0.99), Color(GOLD, 0.82), 1, 10, 28.0)
	)
	center.add_child(_detail_panel)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	_detail_panel.add_child(root_box)

	var top_bar := HBoxContainer.new()
	root_box.add_child(top_bar)
	var top_bar_balance := Control.new()
	top_bar_balance.name = "CardDetailHeaderBalance"
	top_bar_balance.custom_minimum_size.x = 42.0
	top_bar.add_child(top_bar_balance)

	var detail_eyebrow := Label.new()
	detail_eyebrow.name = "CardDetailTitle"
	detail_eyebrow.text = "KART KAYDI"
	detail_eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_eyebrow.add_theme_font_size_override("font_size", 11)
	detail_eyebrow.add_theme_color_override("font_color", GOLD)
	top_bar.add_child(detail_eyebrow)

	_detail_close_button = _make_icon_button("CardDetailCloseButton", "×")
	_detail_close_button.pressed.connect(_hide_card_detail)
	top_bar.add_child(_detail_close_button)

	var detail_body := HBoxContainer.new()
	detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_body.add_theme_constant_override("separation", 30)
	root_box.add_child(detail_body)

	_detail_card_stage = Control.new()
	_detail_card_stage.name = "DetailCardStage"
	_detail_card_stage.custom_minimum_size = Vector2(330.0, 455.0)
	detail_body.add_child(_detail_card_stage)

	var divider := VSeparator.new()
	divider.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.28), 1))
	detail_body.add_child(divider)

	var info_box := VBoxContainer.new()
	info_box.name = "DetailInfo"
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 12)
	detail_body.add_child(info_box)

	_detail_type_label = Label.new()
	_detail_type_label.add_theme_font_size_override("font_size", 12)
	_detail_type_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	info_box.add_child(_detail_type_label)

	_detail_name_label = Label.new()
	_detail_name_label.add_theme_font_size_override("font_size", 32)
	_detail_name_label.add_theme_color_override("font_color", CREAM)
	_detail_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_detail_name_label.add_theme_constant_override("outline_size", 4)
	_detail_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(_detail_name_label)

	_detail_meta_label = Label.new()
	_detail_meta_label.add_theme_font_size_override("font_size", 14)
	_detail_meta_label.add_theme_color_override("font_color", GOLD)
	info_box.add_child(_detail_meta_label)

	var description_rule := HSeparator.new()
	description_rule.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.25), 1))
	info_box.add_child(description_rule)

	_detail_description_label = Label.new()
	_detail_description_label.add_theme_font_size_override("font_size", 17)
	_detail_description_label.add_theme_color_override("font_color", Color(0.86, 0.83, 0.77))
	_detail_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description_label.add_theme_constant_override("line_spacing", 4)
	info_box.add_child(_detail_description_label)

	_detail_stats_label = Label.new()
	_detail_stats_label.add_theme_font_size_override("font_size", 15)
	_detail_stats_label.add_theme_color_override("font_color", Color(0.76, 0.75, 0.72))
	_detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_stats_label.add_theme_constant_override("line_spacing", 5)
	info_box.add_child(_detail_stats_label)

	_detail_effect_label = Label.new()
	_detail_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_detail_effect_label.add_theme_font_size_override("font_size", 12)
	_detail_effect_label.add_theme_color_override("font_color", Color(0.48, 0.62, 0.64))
	_detail_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(_detail_effect_label)


func _build_soundtrack_overlay() -> void:
	_soundtrack_overlay = _make_modal_overlay("SoundtrackOverlay", Color(0.004, 0.005, 0.008, 0.84))
	add_child(_soundtrack_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_soundtrack_overlay.add_child(center)

	_soundtrack_panel = PanelContainer.new()
	_soundtrack_panel.name = "SoundtrackPanel"
	_soundtrack_panel.custom_minimum_size = Vector2(1020.0, 610.0)
	_soundtrack_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(0.028, 0.029, 0.034, 0.99), Color(GOLD, 0.72), 1, 9, 28.0)
	)
	center.add_child(_soundtrack_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_soundtrack_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	content.add_child(header)
	var header_balance := Control.new()
	header_balance.name = "SoundtrackHeaderBalance"
	header_balance.custom_minimum_size.x = 150.0
	header.add_child(header_balance)

	var header_copy := VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.add_theme_constant_override("separation", 2)
	header.add_child(header_copy)
	var eyebrow := Label.new()
	eyebrow.name = "SoundtrackEyebrow"
	eyebrow.text = "DARWINE  /  ORIGINAL SCORE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", GOLD_BRIGHT)
	header_copy.add_child(eyebrow)
	var title := _make_heading("KUŞATMA EZGİLERİ", 29)
	title.name = "SoundtrackTitle"
	header_copy.add_child(title)
	header_copy.add_child(_make_muted_label(
		"Parçanı seç, sırada ilerle veya zaman çizgisinden istediğin ana dön.",
		13
	))

	_soundtrack_count_label = Label.new()
	_soundtrack_count_label.name = "SoundtrackCount"
	_soundtrack_count_label.text = "0 PARÇA"
	_soundtrack_count_label.custom_minimum_size.x = 92.0
	_soundtrack_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_soundtrack_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_soundtrack_count_label.add_theme_font_size_override("font_size", 12)
	_soundtrack_count_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	_soundtrack_count_label.add_theme_stylebox_override(
		"normal",
		_make_stylebox(Color(0.12, 0.10, 0.07, 0.84), Color(GOLD, 0.44), 1, 5, 10.0)
	)
	header.add_child(_soundtrack_count_label)

	var close_button := _make_icon_button("SoundtrackCloseButton", "×")
	close_button.pressed.connect(_hide_soundtrack)
	header.add_child(close_button)

	var header_rule := HSeparator.new()
	header_rule.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.28), 1))
	content.add_child(header_rule)

	var body := HBoxContainer.new()
	body.name = "SoundtrackBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	content.add_child(body)

	var now_panel := PanelContainer.new()
	now_panel.name = "NowPlayingPanel"
	now_panel.custom_minimum_size.x = 365.0
	now_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	now_panel.add_theme_stylebox_override(
		"panel",
		_make_button_style(Color(0.020, 0.021, 0.025, 0.96), Color(GOLD, 0.30), 1, 7, 20.0)
	)
	body.add_child(now_panel)

	var now_box := VBoxContainer.new()
	now_box.add_theme_constant_override("separation", 10)
	now_panel.add_child(now_box)

	_soundtrack_now_index_label = Label.new()
	_soundtrack_now_index_label.name = "NowPlayingIndex"
	_soundtrack_now_index_label.text = "ŞİMDİ ÇALIYOR"
	_soundtrack_now_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_soundtrack_now_index_label.add_theme_font_size_override("font_size", 11)
	_soundtrack_now_index_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	now_box.add_child(_soundtrack_now_index_label)

	var seal := PanelContainer.new()
	seal.name = "SoundtrackSeal"
	seal.custom_minimum_size.y = 158.0
	seal.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(0.11, 0.075, 0.025, 0.66), Color(GOLD_BRIGHT, 0.58), 1, 8, 14.0)
	)
	now_box.add_child(seal)
	var seal_center := CenterContainer.new()
	seal.add_child(seal_center)
	var seal_copy := VBoxContainer.new()
	seal_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	seal_copy.add_theme_constant_override("separation", 0)
	seal_center.add_child(seal_copy)
	_soundtrack_seal_label = _make_heading("I", 62)
	_soundtrack_seal_label.name = "SoundtrackSealNumber"
	_soundtrack_seal_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	seal_copy.add_child(_soundtrack_seal_label)
	var seal_caption := Label.new()
	seal_caption.text = "DARWINE  SCORE"
	seal_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_caption.add_theme_font_size_override("font_size", 10)
	seal_caption.add_theme_color_override("font_color", Color(GOLD, 0.82))
	seal_copy.add_child(seal_caption)

	_soundtrack_now_title_label = _make_heading("Parça yükleniyor", 25)
	_soundtrack_now_title_label.name = "NowPlayingTitle"
	_soundtrack_now_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	now_box.add_child(_soundtrack_now_title_label)

	_soundtrack_now_subtitle_label = _make_muted_label("", 13)
	_soundtrack_now_subtitle_label.name = "NowPlayingSubtitle"
	now_box.add_child(_soundtrack_now_subtitle_label)

	_soundtrack_progress_slider = HSlider.new()
	_soundtrack_progress_slider.name = "SoundtrackProgress"
	_soundtrack_progress_slider.min_value = 0.0
	_soundtrack_progress_slider.max_value = 1.0
	_soundtrack_progress_slider.step = 0.1
	_soundtrack_progress_slider.custom_minimum_size.y = 27.0
	_soundtrack_progress_slider.drag_started.connect(_on_soundtrack_seek_drag_started)
	_soundtrack_progress_slider.drag_ended.connect(_on_soundtrack_seek_drag_ended)
	_soundtrack_progress_slider.value_changed.connect(_on_soundtrack_seek_value_changed)
	_style_settings_slider(_soundtrack_progress_slider)
	now_box.add_child(_soundtrack_progress_slider)

	var time_row := HBoxContainer.new()
	now_box.add_child(time_row)
	_soundtrack_time_label = _make_muted_label("0:00", 11)
	_soundtrack_time_label.name = "SoundtrackElapsedTime"
	_soundtrack_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_soundtrack_time_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_soundtrack_time_label.custom_minimum_size.x = 44.0
	_soundtrack_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(_soundtrack_time_label)
	_soundtrack_duration_label = _make_muted_label("0:00", 11)
	_soundtrack_duration_label.name = "SoundtrackDuration"
	_soundtrack_duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_soundtrack_duration_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_soundtrack_duration_label.custom_minimum_size.x = 44.0
	time_row.add_child(_soundtrack_duration_label)

	var controls := HBoxContainer.new()
	controls.name = "SoundtrackControls"
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	now_box.add_child(controls)
	var previous_button := _make_action_button("PreviousTrackButton", "<  Önceki", Color(0.60, 0.52, 0.40), true)
	previous_button.custom_minimum_size.x = 96.0
	previous_button.add_theme_font_size_override("font_size", 13)
	previous_button.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	previous_button.clip_text = true
	previous_button.pressed.connect(_on_soundtrack_previous_pressed)
	controls.add_child(previous_button)
	_soundtrack_play_pause_button = _make_action_button("PlayPauseTrackButton", "Duraklat", GOLD_BRIGHT)
	_soundtrack_play_pause_button.custom_minimum_size.x = 108.0
	_soundtrack_play_pause_button.add_theme_font_size_override("font_size", 13)
	_soundtrack_play_pause_button.clip_text = true
	_soundtrack_play_pause_button.pressed.connect(_on_soundtrack_play_pause_pressed)
	controls.add_child(_soundtrack_play_pause_button)
	var next_button := _make_action_button("NextTrackButton", "Sonraki  >", Color(0.60, 0.52, 0.40), true)
	next_button.custom_minimum_size.x = 96.0
	next_button.add_theme_font_size_override("font_size", 13)
	next_button.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	next_button.clip_text = true
	next_button.pressed.connect(_on_soundtrack_next_pressed)
	controls.add_child(next_button)

	var divider := VSeparator.new()
	divider.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.20), 1))
	body.add_child(divider)

	var library := VBoxContainer.new()
	library.name = "SoundtrackLibrary"
	library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library.add_theme_constant_override("separation", 10)
	body.add_child(library)
	var library_title := Label.new()
	library_title.text = "TÜM PARÇALAR"
	library_title.add_theme_font_size_override("font_size", 12)
	library_title.add_theme_color_override("font_color", GOLD)
	library.add_child(library_title)
	var library_rule := HSeparator.new()
	library_rule.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.18), 1))
	library.add_child(library_rule)

	var scroll := ScrollContainer.new()
	scroll.name = "SoundtrackScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	library.add_child(scroll)
	_soundtrack_track_list = VBoxContainer.new()
	_soundtrack_track_list.name = "SoundtrackTrackList"
	_soundtrack_track_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_soundtrack_track_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_soundtrack_track_list)

func _build_save_slots_overlay() -> void:
	_save_slots_overlay = SAVE_SLOTS_PANEL_SCRIPT.new() as SaveSlotsPanel
	add_child(_save_slots_overlay)
	_save_slots_overlay.load_requested.connect(_load_save_slot)
	_save_slots_overlay.delete_requested.connect(_delete_save_slot_from_picker)
	_save_slots_overlay.closed.connect(_focus_start_button)


func _build_save_recovery_overlay() -> void:
	_save_recovery_overlay = _make_modal_overlay("ActiveSaveRecoveryOverlay", Color(0.004, 0.005, 0.008, 0.90))
	add_child(_save_recovery_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_recovery_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ActiveSaveRecoveryPanel"
	panel.custom_minimum_size = Vector2(650.0, 390.0)
	panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.035, 0.035, 0.040, 0.99), Color(0.88, 0.46, 0.24), 2, 10, 28.0))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	var kicker := _make_muted_label("AKTİF MAÇ KAYDI", 12)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(kicker)
	var title := _make_heading("KAYIT KURTARMA GEREKİYOR", 27)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_save_recovery_message = Label.new()
	_save_recovery_message.name = "ActiveSaveRecoveryMessage"
	_save_recovery_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_recovery_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_recovery_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_recovery_message.custom_minimum_size.y = 105.0
	_save_recovery_message.add_theme_font_size_override("font_size", 15)
	_save_recovery_message.add_theme_color_override("font_color", Color(0.84, 0.80, 0.73))
	content.add_child(_save_recovery_message)
	_recover_backup_button = _make_menu_button("RecoverActiveSaveButton", "Yedekten Kurtar", "", Color(0.30, 0.68, 0.52))
	_recover_backup_button.pressed.connect(_recover_active_save_backup)
	content.add_child(_recover_backup_button)
	# Locale-neutral to_upper() turns the Turkish dotted İ into plain I, so keep
	# this visible action label explicitly Turkish in its rendered uppercase form.
	var delete_button := _make_menu_button("DeleteActiveSaveButton", "KAYDI SİL", "", Color(0.76, 0.32, 0.26), true)
	delete_button.pressed.connect(_delete_active_save)
	content.add_child(delete_button)
	var cancel_button := _make_menu_button("CancelActiveSaveRecoveryButton", "Vazgeç", "", Color(0.48, 0.47, 0.44))
	cancel_button.pressed.connect(func():
		_save_recovery_overlay.visible = false
		_focus_start_button()
	)
	content.add_child(cancel_button)
	_save_recovery_overlay.visible = false


func _refresh_continue_game_state() -> void:
	if not _continue_game_button:
		return
	var slots := _active_match_repository.list_slots()
	_continue_game_button.visible = true
	_continue_game_button.disabled = slots.is_empty()
	_continue_game_button.text = tr("YÜKLE")
	_continue_game_button.tooltip_text = tr("Kayıt slotu bulunamadı") if slots.is_empty() else tr("Kayıt slotlarından birini yükle")
	if _save_slots_overlay and _save_slots_overlay.is_open():
		_save_slots_overlay.set_slots(slots, _save_slots_overlay.get_selected_slot_id())


func _on_continue_game_pressed() -> void:
	# Test and migration callers can still point the repository at one explicit
	# legacy file. Production menu flow always opens the named slot picker.
	if _active_match_repository.is_custom_path():
		var status := _active_match_repository.inspect_save()
		if str(status.get("state", "")) == "valid":
			var loaded := _active_match_repository.load_primary()
			if bool(loaded.get("success", false)):
				_resume_active_match(loaded.get("snapshot", {}) as Dictionary)
				return
		_show_active_save_recovery(status)
		return
	_show_save_slots()


func _show_save_slots() -> void:
	if not _save_slots_overlay:
		return
	_save_slots_overlay.open_panel(
		_active_match_repository.list_slots(),
		_active_match_repository.get_current_slot_id(),
		"",
		false,
		false
	)


func _load_save_slot(slot_id: String) -> void:
	var status := _active_match_repository.inspect_slot(slot_id)
	if str(status.get("state", "")) == "valid":
		var loaded := _active_match_repository.load_slot(slot_id)
		if bool(loaded.get("success", false)):
			_save_slots_overlay.close_panel()
			_resume_active_match(
				loaded.get("snapshot", {}) as Dictionary,
				str(loaded.get("slot_id", slot_id)),
				str(loaded.get("slot_name", status.get("slot_name", "Kayıt")))
			)
			return
		_save_slots_overlay.set_status(str(loaded.get("error", "Kayıt yüklenemedi.")), true)
		return
	if slot_id != "configured":
		_active_match_repository.configure_slot(slot_id, str(status.get("slot_name", "Kayıt")))
	_save_slots_overlay.close_panel()
	_show_active_save_recovery(status)


func _delete_save_slot_from_picker(slot_id: String) -> void:
	if not _active_match_repository.delete_slot(slot_id):
		_save_slots_overlay.set_status(tr("Kayıt slotu silinemedi."), true)
		return
	_save_slots_overlay.set_slots(_active_match_repository.list_slots())
	_save_slots_overlay.set_status(tr("Kayıt slotu silindi."))
	_refresh_continue_game_state()


func _show_active_save_recovery(status: Dictionary) -> void:
	var recovery_error := _localize_runtime_text(
		str(status.get("error", "The save is damaged, outdated or incompatible with this game version.")),
		"The save could not be loaded.",
	)
	_save_recovery_message.text = "%s\n%s" % [
		recovery_error,
		tr("No new match was started. Restore a valid backup or delete the save."),
	]
	_recover_backup_button.visible = bool(status.get("has_backup", false))
	_recover_backup_button.disabled = not bool(status.get("has_backup", false))
	_reveal_control(_save_recovery_overlay, 0.16)
	if _recover_backup_button.visible:
		_recover_backup_button.grab_focus()


func _recover_active_save_backup() -> void:
	var recovered := _active_match_repository.recover_backup()
	if not bool(recovered.get("success", false)):
		_save_recovery_message.text = _localize_runtime_text(
			str(recovered.get("error", "Backup recovery failed.")),
			"Backup recovery failed.",
		)
		return
	_save_recovery_overlay.visible = false
	_resume_active_match(
		recovered.get("snapshot", {}) as Dictionary,
		_active_match_repository.get_current_slot_id(),
		_active_match_repository.get_current_slot_name()
	)


func _delete_active_save() -> void:
	_active_match_repository.delete_all()
	_save_recovery_overlay.visible = false
	_refresh_continue_game_state()
	if _active_match_repository.list_slots().is_empty():
		_focus_start_button()
	else:
		_show_save_slots()


func _resume_active_match(snapshot: Dictionary, slot_id := "", slot_name := "") -> void:
	if _transitioning or snapshot.is_empty():
		return
	var resolved_slot_id := slot_id if not slot_id.is_empty() else str(snapshot.get("save_slot_id", ""))
	var resolved_slot_name := slot_name if not slot_name.is_empty() else str(snapshot.get("save_slot_name", snapshot.get("match_name", "Kayıt")))
	if not MatchSetup.configure_from_snapshot(snapshot, resolved_slot_id, resolved_slot_name):
		return
	_transitioning = true
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_fade_overlay, "color", Color(0.006, 0.007, 0.01, 1.0), 0.28)
	await tween.finished
	var error := SceneTransition.transition_to(GAME_SCENE)
	if error != OK:
		_transitioning = false
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		push_error("Aktif maç yüklenemedi: %s" % error_string(error))


func _build_quit_overlay() -> void:
	_quit_overlay = _make_modal_overlay("QuitOverlay")
	add_child(_quit_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quit_overlay.add_child(center)

	_quit_panel = PanelContainer.new()
	_quit_panel.name = "QuitPanel"
	_quit_panel.custom_minimum_size = Vector2(510.0, 265.0)
	_quit_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(PANEL_SOFT, Color(DANGER, 0.82), 1, 10, 30.0)
	)
	center.add_child(_quit_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_quit_panel.add_child(content)

	var eyebrow := Label.new()
	eyebrow.name = "QuitEyebrow"
	eyebrow.text = "KUŞATMAYI TERK ET"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", Color(0.86, 0.43, 0.34))
	content.add_child(eyebrow)

	var title := _make_heading("Çıkış yapılsın mı?", 27)
	title.name = "QuitTitle"
	content.add_child(title)
	content.add_child(_make_muted_label("Kaydedilmemiş karşılaşma ilerlemesi kaybolabilir.", 14))

	var flexible_space := Control.new()
	flexible_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(flexible_space)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)

	var cancel_button := _make_action_button("QuitCancelButton", "Vazgeç", Color(0.48, 0.48, 0.46), true)
	cancel_button.pressed.connect(_hide_quit_confirmation)
	actions.add_child(cancel_button)

	var quit_button := _make_action_button("QuitConfirmButton", "Çıkış Yap", DANGER)
	quit_button.pressed.connect(_quit_game)
	actions.add_child(quit_button)


func _build_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "SceneFade"
	_fade_overlay.z_index = 1000
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color(0.006, 0.007, 0.01, 1.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)


func _create_audio() -> void:
	_menu_feedback_audio = FeedbackAudio.new()
	_menu_feedback_audio.name = "MenuFeedbackAudio"
	add_child(_menu_feedback_audio)
	_menu_feedback_audio.bind_button_feedback(self)

	_menu_music_player = MENU_MUSIC_PLAYER_SCRIPT.new() as MenuMusicPlayer
	_menu_music_player.name = "MenuMusicPlayer"
	_menu_music_player.playback_allowed = float(_settings_manager.music_volume) > 0.001
	_menu_music_player.track_changed.connect(_on_music_track_changed)
	_menu_music_player.playback_state_changed.connect(_on_music_playback_state_changed)
	add_child(_menu_music_player)
	_refresh_soundtrack_list()
	_update_soundtrack_track(_menu_music_player.current_track_index, _menu_music_player.get_current_track_data())
	_update_mini_music_player(_menu_music_player.current_track_index, _menu_music_player.get_current_track_data())
	_on_music_playback_state_changed(_menu_music_player.is_playback_active())


func _process(_delta: float) -> void:
	if (
		_menu_music_player == null
		or _soundtrack_overlay == null
		or not _soundtrack_overlay.visible
		or _soundtrack_seek_dragging
		or _menu_music_player.current_track_index < 0
	):
		return
	var track_data := _menu_music_player.get_current_track_data()
	var duration := float(track_data.get("duration", 0.0))
	var playback_position := clampf(_menu_music_player.get_current_position(), 0.0, duration)
	_soundtrack_progress_slider.max_value = maxf(duration, 0.1)
	_soundtrack_progress_slider.set_value_no_signal(playback_position)
	_soundtrack_time_label.text = _format_track_time(playback_position)
	_soundtrack_duration_label.text = _format_track_time(duration)


func _refresh_soundtrack_list() -> void:
	if _soundtrack_track_list == null:
		return
	for child in _soundtrack_track_list.get_children():
		_soundtrack_track_list.remove_child(child)
		child.queue_free()
	_soundtrack_track_buttons.clear()
	_soundtrack_track_number_labels.clear()
	_soundtrack_track_title_labels.clear()
	_soundtrack_track_meta_labels.clear()
	if _menu_music_player == null:
		_soundtrack_count_label.text = "0 PARÇA"
		return

	var tracks := _menu_music_player.get_all_track_data()
	_soundtrack_count_label.text = tr("%d TRACKS") % tracks.size()
	for track_index in range(tracks.size()):
		var track_data: Dictionary = tracks[track_index]
		var track_button := Button.new()
		track_button.name = "SoundtrackTrackButton%d" % (track_index + 1)
		track_button.text = ""
		track_button.tooltip_text = tr("Play %s") % tr(str(track_data.get("title", "This track")))
		track_button.custom_minimum_size = Vector2(0.0, 88.0)
		track_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track_button.toggle_mode = true
		track_button.clip_contents = true
		track_button.pressed.connect(_on_soundtrack_track_selected.bind(track_index))
		_soundtrack_track_list.add_child(track_button)

		var content_margin := MarginContainer.new()
		content_margin.name = "TrackContent"
		content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_margin.add_theme_constant_override("margin_left", 24)
		content_margin.add_theme_constant_override("margin_top", 12)
		content_margin.add_theme_constant_override("margin_right", 24)
		content_margin.add_theme_constant_override("margin_bottom", 12)
		content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track_button.add_child(content_margin)

		var row := HBoxContainer.new()
		row.name = "TrackRow"
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_margin.add_child(row)

		var number_label := Label.new()
		number_label.name = "TrackNumber%02d" % (track_index + 1)
		number_label.text = "%02d" % (track_index + 1)
		number_label.custom_minimum_size.x = 42.0
		number_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number_label.add_theme_font_override("font", UI.DISPLAY_FONT)
		number_label.add_theme_font_size_override("font_size", 17)
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(number_label)

		var track_divider := VSeparator.new()
		track_divider.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.20), 1))
		track_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(track_divider)

		var copy := VBoxContainer.new()
		copy.name = "TrackCopy"
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.add_theme_constant_override("separation", 3)
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(copy)

		var title_label := Label.new()
		title_label.name = "TrackTitle%02d" % (track_index + 1)
		title_label.text = tr(str(track_data.get("title", "İsimsiz Parça")))
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		title_label.clip_text = true
		title_label.add_theme_font_size_override("font_size", 17)
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.style_title(title_label, CREAM)
		copy.add_child(title_label)

		var meta_label := Label.new()
		meta_label.name = "TrackMeta%02d" % (track_index + 1)
		meta_label.text = "%s   •   %s" % [
			tr(str(track_data.get("subtitle", "Darwine Soundtrack"))),
			_format_track_time(float(track_data.get("duration", 0.0))),
		]
		meta_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		meta_label.clip_text = true
		meta_label.add_theme_font_size_override("font_size", 13)
		meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(meta_label)

		_soundtrack_track_buttons.append(track_button)
		_soundtrack_track_number_labels.append(number_label)
		_soundtrack_track_title_labels.append(title_label)
		_soundtrack_track_meta_labels.append(meta_label)
	_update_soundtrack_track(_menu_music_player.current_track_index, _menu_music_player.get_current_track_data())


func _update_soundtrack_track(track_index: int, track_data: Dictionary) -> void:
	if _soundtrack_now_title_label == null or track_data.is_empty():
		return
	_soundtrack_now_index_label.text = tr("NOW PLAYING   •   %02d / %02d") % [
		track_index + 1,
		_menu_music_player.track_count,
	]
	_soundtrack_now_title_label.text = tr(str(track_data.get("title", "İsimsiz Parça")))
	_soundtrack_now_subtitle_label.text = tr(str(track_data.get("subtitle", "Darwine Soundtrack")))
	_soundtrack_seal_label.text = _track_seal(track_index)
	var duration := float(track_data.get("duration", 0.0))
	_soundtrack_progress_slider.max_value = maxf(duration, 0.1)
	_soundtrack_progress_slider.set_value_no_signal(0.0)
	_soundtrack_time_label.text = "0:00"
	_soundtrack_duration_label.text = _format_track_time(duration)
	for button_index in range(_soundtrack_track_buttons.size()):
		var button := _soundtrack_track_buttons[button_index]
		var is_current := button_index == track_index
		button.set_pressed_no_signal(is_current)
		UI.style_button(
			button,
			GOLD_BRIGHT if is_current else Color(0.53, 0.46, 0.35),
			false,
			false,
			is_current
		)
		_soundtrack_track_number_labels[button_index].add_theme_color_override(
			"font_color",
			GOLD_BRIGHT if is_current else Color(GOLD, 0.72)
		)
		_soundtrack_track_title_labels[button_index].add_theme_color_override(
			"font_color",
			CREAM if is_current else Color(0.76, 0.73, 0.67)
		)
		_soundtrack_track_meta_labels[button_index].add_theme_color_override(
			"font_color",
			Color(0.76, 0.70, 0.58) if is_current else MUTED
		)


func _on_music_track_changed(track_index: int, track_data: Dictionary) -> void:
	_update_soundtrack_track(track_index, track_data)
	_update_mini_music_player(track_index, track_data)


func _on_music_playback_state_changed(is_playing: bool) -> void:
	var playback_blocked := _menu_music_player != null and not _menu_music_player.playback_allowed
	if _soundtrack_play_pause_button:
		_soundtrack_play_pause_button.disabled = playback_blocked
		_soundtrack_play_pause_button.text = "Ses %0" if playback_blocked else ("Duraklat" if is_playing else "Devam Et")
	if _mini_music_play_pause_button:
		_mini_music_play_pause_button.disabled = playback_blocked
		_mini_music_play_pause_button.text = "0%" if playback_blocked else ("II" if is_playing else "▶")
		_mini_music_play_pause_button.tooltip_text = (
			"Müzik sesi %0" if playback_blocked
			else ("Müziği duraklat" if is_playing else "Müziği oynat")
		)


func _update_mini_music_player(track_index: int, track_data: Dictionary) -> void:
	if _mini_music_track_label == null or _mini_music_index_label == null or track_data.is_empty():
		return
	_mini_music_track_label.text = tr(str(track_data.get("title", "İsimsiz Parça")))
	_mini_music_track_label.tooltip_text = _mini_music_track_label.text
	_mini_music_index_label.text = "%02d / %02d" % [track_index + 1, _menu_music_player.track_count]


func _on_soundtrack_track_selected(track_index: int) -> void:
	if _menu_music_player:
		_menu_music_player.play_track(track_index)


func _on_soundtrack_previous_pressed() -> void:
	if _menu_music_player:
		_menu_music_player.previous_track()


func _on_soundtrack_next_pressed() -> void:
	if _menu_music_player:
		_menu_music_player.next_track()


func _on_soundtrack_play_pause_pressed() -> void:
	if _menu_music_player:
		_menu_music_player.toggle_pause()


func _on_soundtrack_seek_drag_started() -> void:
	_soundtrack_seek_dragging = true


func _on_soundtrack_seek_value_changed(value: float) -> void:
	if _soundtrack_seek_dragging and _soundtrack_time_label:
		_soundtrack_time_label.text = _format_track_time(value)


func _on_soundtrack_seek_drag_ended(value_changed: bool) -> void:
	if value_changed and _menu_music_player:
		_menu_music_player.seek_to(_soundtrack_progress_slider.value)
	_soundtrack_seek_dragging = false


func _format_track_time(seconds: float) -> String:
	var total_seconds := maxi(int(floor(seconds)), 0)
	return "%d:%02d" % [total_seconds / 60, total_seconds % 60]


func _track_seal(track_index: int) -> String:
	var seals := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
	if track_index >= 0 and track_index < seals.size():
		return seals[track_index]
	return str(track_index + 1)


func _make_menu_button(node_name: String, label_text: String, _index_text: String, accent: Color, destructive := false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label_text.to_upper()
	button.custom_minimum_size = Vector2(0.0, 44.0 if node_name in MAIN_MENU_BUTTON_NAMES else 52.0)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.86))
	var primary := node_name == "StartButton"
	UI.style_button(button, accent, destructive, false, primary)
	button.mouse_entered.connect(_on_menu_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_menu_button_hover.bind(button, false))
	return button


func _make_action_button(node_name: String, text_value: String, accent: Color, quiet := false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(132.0, 45.0)
	button.add_theme_font_size_override("font_size", 15)
	UI.style_button(button, accent, false, true, not quiet)
	return button


func _make_icon_button(node_name: String, glyph: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = glyph
	button.custom_minimum_size = Vector2(42.0, 42.0)
	button.add_theme_font_size_override("font_size", 25)
	UI.style_button(button, GOLD, false, true)
	return button


func _make_filter_heading(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", MUTED)
	return label


func _make_filter_button(node_name: String, icon: String, text_value: String, accent: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = _format_filter_button_text(icon, text_value)
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(132.0, 40.0)
	button.add_theme_font_size_override("font_size", 13)
	button.tooltip_text = text_value
	_style_filter_button(button, accent)
	return button


func _style_filter_button(button: Button, accent: Color) -> void:
	UI.style_button(button, accent, false, true)
	_apply_filter_button_tint(button, "normal", UI.ButtonState.NORMAL, accent, 0.13)
	_apply_filter_button_tint(button, "hover", UI.ButtonState.HOVER, accent, 0.27)
	_apply_filter_button_tint(button, "pressed", UI.ButtonState.PRESSED, accent, 0.32)


func _apply_filter_button_tint(button: Button, state_name: String, state: int, accent: Color, tint_strength: float) -> void:
	var style := UI.button_style(state, accent, 10.0, true)
	if style is StyleBoxTexture:
		var texture_style := style as StyleBoxTexture
		texture_style.modulate_color = Color(0.82, 0.80, 0.76, 1.0).lerp(accent, tint_strength)
		if state == UI.ButtonState.PRESSED:
			texture_style.modulate_color = texture_style.modulate_color.darkened(0.12)
	button.add_theme_stylebox_override(state_name, style)


func _format_filter_button_text(icon: String, label: String, count: int = -1) -> String:
	var text_value := "%s  %s" % [icon, tr(label)]
	return "%s  %d" % [text_value, count] if count >= 0 else text_value


func _make_heading(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	UI.style_title(label, CREAM)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _make_muted_label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_section_rule(text_value: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", GOLD)
	box.add_child(label)
	var line := HSeparator.new()
	line.add_theme_stylebox_override("separator", _make_line_style(Color(GOLD, 0.26), 1))
	box.add_child(line)
	return box


func _make_modal_overlay(node_name: String, dim_color := Color(0.005, 0.006, 0.008, 0.76)) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.z_index = 100
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = dim_color
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	return overlay


func _make_stylebox(background: Color, border: Color, _border_width: int, _radius: int, padding: float) -> StyleBox:
	return UI.panel_style(border, padding, clampf(background.a, 0.78, 1.0))


func _make_button_style(background: Color, border: Color, border_width: int, radius := 7, horizontal_padding := 18.0) -> StyleBoxFlat:
	var style := UI.inset_style(background, border, radius)
	style.set_border_width_all(border_width)
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
func _make_line_style(color_value: Color, thickness: int) -> StyleBoxLine:
	return UI.line_style(color_value, thickness)


func _make_gradient_texture(colors: PackedColorArray, offsets: PackedFloat32Array, fill_from: Vector2, fill_to: Vector2) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = colors
	gradient.offsets = offsets
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.gradient = gradient
	texture.fill_from = fill_from
	texture.fill_to = fill_to
	return texture


func _show_difficulty_selection() -> void:
	if _transitioning or not _difficulty_overlay:
		return
	if _default_difficulty_option:
		_set_selected_difficulty(_default_difficulty_option.get_selected_id())
	_reveal_control(_difficulty_overlay, 0.18)
	_refresh_card_pool_mode_copy()
	call_deferred("_focus_game_setup_form")


func _show_how_to_play() -> void:
	if _transitioning or _how_to_overlay == null:
		return
	_how_to_overlay.open_panel()


func _hide_how_to_play() -> void:
	if _how_to_overlay:
		_how_to_overlay.close_panel()


func _show_deck_builder() -> void:
	if _transitioning or not _deck_builder_overlay:
		return
	_deck_builder_overlay.open_panel()


func _hide_deck_builder() -> void:
	if _deck_builder_overlay:
		_deck_builder_overlay.close_panel()


func _show_profile() -> void:
	if _transitioning or not _profile_overlay:
		return
	_profile_overlay.open_panel()


func _hide_profile() -> void:
	if _profile_overlay:
		_profile_overlay.close_panel()


func _show_release_notes() -> void:
	if _transitioning or not _release_notes_overlay:
		return
	_release_notes_overlay.open_panel()


func _hide_release_notes() -> void:
	if _release_notes_overlay:
		_release_notes_overlay.close_panel()


func _hide_difficulty_selection() -> void:
	if not _difficulty_overlay or not _difficulty_overlay.visible:
		return
	_difficulty_overlay.visible = false
	_focus_start_button()


func _show_multiplayer() -> void:
	if _transitioning or not _multiplayer_overlay:
		return
	_reveal_control(_multiplayer_overlay, 0.18)
	var network_manager := get_node_or_null("/root/NetworkManager")
	if network_manager:
		if _multiplayer_host_address_input.text.strip_edges().is_empty():
			_multiplayer_host_address_input.text = str(network_manager.get_suggested_host_ipv4())
		if network_manager.can_reconnect():
			if str(network_manager.get_reconnect_descriptor()).begins_with("STEAM:"):
				_show_steam_multiplayer_mode()
				_steam_reconnect_button.visible = true
				_steam_reconnect_button.disabled = false
				_steam_reconnect_button.text = tr("RECONNECT (%d sec)") % network_manager.get_reconnect_seconds_remaining()
			else:
				_show_multiplayer_mode(false)
			_multiplayer_reconnect_button.visible = true
			_multiplayer_reconnect_button.text = tr("RECONNECT (%d sec)") % network_manager.get_reconnect_seconds_remaining()
		if not str(network_manager.last_status).is_empty():
			_on_network_status_changed(str(network_manager.last_status), bool(network_manager.last_status_is_error))
		if network_manager.has_method("get_room_settings") and not network_manager.get_lobby_players().is_empty():
			_refresh_multiplayer_settings_summary(network_manager.get_room_settings())
	_refresh_multiplayer_settings_summary()
	_refresh_steam_availability()
	if _multiplayer_steam_panel.visible:
		_refresh_steam_lobbies()
	elif _multiplayer_host_panel.visible:
		_multiplayer_host_name_input.grab_focus()
	else:
		_multiplayer_code_input.grab_focus()


func _hide_multiplayer() -> void:
	if not _multiplayer_overlay or not _multiplayer_overlay.visible:
		return
	var network_manager := get_node_or_null("/root/NetworkManager")
	if network_manager and (network_manager.is_client() or network_manager.is_hosting_player()):
		network_manager.leave_network(false)
	_set_multiplayer_settings_locked(false)
	if _multiplayer_host_create_button:
		_multiplayer_host_create_button.disabled = false
	if _multiplayer_copy_invite_button:
		_multiplayer_copy_invite_button.disabled = true
	if _multiplayer_leave_room_button:
		_multiplayer_leave_room_button.visible = false
	if _steam_invite_button:
		_steam_invite_button.disabled = true
	if _steam_leave_button:
		_steam_leave_button.visible = false
	if _steam_reconnect_button:
		_steam_reconnect_button.visible = false
	_multiplayer_overlay.visible = false
	_multiplayer_players_label.text = "2 oyuncu dolunca maç otomatik başlar."
	_on_invite_code_changed(_multiplayer_code_input.text)
	_focus_start_button()


func _show_multiplayer_mode(host_mode: bool) -> void:
	if not _multiplayer_host_panel or not _multiplayer_join_panel:
		return
	_multiplayer_host_panel.visible = host_mode
	_multiplayer_join_panel.visible = not host_mode
	if _multiplayer_steam_panel:
		_multiplayer_steam_panel.visible = false
	_multiplayer_host_mode_button.disabled = host_mode
	_multiplayer_join_mode_button.disabled = not host_mode
	if _multiplayer_steam_mode_button:
		_multiplayer_steam_mode_button.disabled = false
	if is_inside_tree() and _multiplayer_overlay and _multiplayer_overlay.visible:
		if host_mode:
			_multiplayer_host_name_input.grab_focus()
		else:
			_multiplayer_code_input.grab_focus()


func _show_steam_multiplayer_mode() -> void:
	if not _multiplayer_steam_panel:
		return
	_multiplayer_host_panel.visible = false
	_multiplayer_join_panel.visible = false
	_multiplayer_steam_panel.visible = true
	_multiplayer_host_mode_button.disabled = false
	_multiplayer_join_mode_button.disabled = false
	_multiplayer_steam_mode_button.disabled = true
	_refresh_steam_availability()
	var steam_manager := get_node_or_null("/root/SteamManager")
	if steam_manager and not str(steam_manager.get("last_status")).is_empty():
		_on_network_status_changed(
			str(steam_manager.get("last_status")),
			bool(steam_manager.get("last_status_is_error"))
		)
	if is_inside_tree() and _multiplayer_overlay and _multiplayer_overlay.visible:
		_refresh_steam_lobbies()
		if _steam_game_name_input.editable:
			_steam_game_name_input.grab_focus()


func _set_multiplayer_ruleset_locked(locked: bool) -> void:
	for ruleset_variant in _multiplayer_ruleset_buttons:
		var button := _multiplayer_ruleset_buttons[ruleset_variant] as Button
		if button:
			button.disabled = locked


func _set_multiplayer_settings_locked(locked: bool) -> void:
	_set_multiplayer_ruleset_locked(locked)
	for button_dictionary in [
		_multiplayer_card_pool_buttons,
		_multiplayer_turn_duration_buttons,
		_multiplayer_auto_attack_buttons,
	]:
		for key_variant in button_dictionary:
			var button := button_dictionary[key_variant] as Button
			if button:
				button.disabled = locked
	for input in [
		_multiplayer_host_name_input,
		_multiplayer_host_address_input,
		_multiplayer_host_port_input,
		_multiplayer_game_name_input,
	]:
		if input is LineEdit:
			(input as LineEdit).editable = not locked


func _set_steam_settings_locked(locked: bool) -> void:
	if _steam_game_name_input:
		_steam_game_name_input.editable = not locked
	for option in [_steam_ruleset_option, _steam_card_pool_option, _steam_turn_duration_option]:
		if option is OptionButton:
			(option as OptionButton).disabled = locked
	if _steam_auto_attack_check:
		_steam_auto_attack_check.disabled = locked


func _create_steam_room() -> void:
	var network_manager := get_node_or_null("/root/NetworkManager")
	var steam_manager := get_node_or_null("/root/SteamManager")
	if not network_manager or not steam_manager or not bool(steam_manager.get("is_available")):
		_on_network_status_changed("Steam istemcisi bağlı değil.", true)
		_refresh_steam_availability()
		return
	var room_name := _steam_game_name_input.text.replace("\n", " ").strip_edges()
	if room_name.is_empty():
		_on_network_status_changed("Steam odasını oluşturmak için maç adı gir.", true)
		_steam_game_name_input.grab_focus()
		return
	_steam_host_button.disabled = true
	var ruleset := _steam_ruleset_option.get_selected_id()
	var card_pool := _steam_card_pool_option.get_selected_id()
	var turn_duration := _steam_turn_duration_option.get_selected_id()
	var create_error: Error = network_manager.start_steam_hosted_room(
		str(steam_manager.call("get_persona_name")),
		ruleset,
		room_name,
		card_pool,
		float(turn_duration),
		_steam_auto_attack_check.button_pressed
	)
	if create_error != OK:
		_refresh_steam_availability()


func _refresh_steam_lobbies() -> void:
	if not _steam_lobby_list:
		return
	var network_manager := get_node_or_null("/root/NetworkManager")
	if not network_manager or not network_manager.is_steam_available():
		_render_steam_lobbies([])
		_refresh_steam_availability()
		return
	_steam_refresh_button.disabled = true
	var request_error: Error = network_manager.request_steam_lobbies()
	if request_error != OK:
		_steam_refresh_button.disabled = false


func _render_steam_lobbies(lobbies: Array) -> void:
	if not _steam_lobby_list:
		return
	for child in _steam_lobby_list.get_children():
		child.queue_free()
	if lobbies.is_empty():
		var empty_label := _make_muted_label(
			"Steam bağlantısı yok. Steam istemcisini açıp oyunu yeniden başlat."
			if not _is_steam_ui_available()
			else "Açık lobi bulunamadı. Bir Steam odası açabilir veya listeyi yenileyebilirsin.",
			11
		)
		empty_label.name = "SteamLobbyEmptyState"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.custom_minimum_size.y = 52.0
		_steam_lobby_list.add_child(empty_label)
		return
	for lobby_variant in lobbies:
		if not lobby_variant is Dictionary:
			continue
		var lobby := lobby_variant as Dictionary
		var metadata := lobby.get("metadata", {}) as Dictionary
		var lobby_id := int(lobby.get("lobby_id", 0))
		var member_count := int(lobby.get("member_count", 0))
		var max_members := int(lobby.get("max_members", 2))
		var ruleset_name := "Hakimiyet" if int(metadata.get("ruleset", 0)) == MatchSetup.Ruleset.DOMINION else "Kuşatma"
		var state_name := str(metadata.get("state", "waiting"))
		var button := _make_action_button(
			"SteamLobby%d" % lobby_id,
			"%s  •  %s  •  %s  •  %d/%d" % [
				str(metadata.get("match_name", "İsimsiz Steam Maçı")),
				str(lobby.get("owner_name", "Steam Komutanı")),
				ruleset_name,
				member_count,
				max_members,
			],
			Color(0.36, 0.62, 0.92),
			true
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42.0
		button.disabled = lobby_id <= 0 or member_count >= max_members or state_name != "waiting"
		button.tooltip_text = "Katıl" if not button.disabled else "Lobi dolu veya maç başlamış."
		button.pressed.connect(_join_steam_lobby_from_list.bind(lobby_id))
		_steam_lobby_list.add_child(button)


func _join_steam_lobby_from_list(lobby_id: int) -> void:
	var network_manager := get_node_or_null("/root/NetworkManager")
	var steam_manager := get_node_or_null("/root/SteamManager")
	if not network_manager or not steam_manager:
		return
	var join_error: Error = network_manager.join_steam_lobby(
		lobby_id,
		str(steam_manager.call("get_persona_name"))
	)
	if join_error == OK:
		_set_steam_settings_locked(true)
		_steam_host_button.disabled = true
		_steam_refresh_button.disabled = true
		_steam_invite_button.disabled = false
		_steam_leave_button.visible = true


func _invite_steam_friends() -> void:
	var network_manager := get_node_or_null("/root/NetworkManager")
	if not network_manager or network_manager.invite_steam_friends() != OK:
		_on_network_status_changed("Steam arkadaş daveti yalnızca etkin bir lobide açılabilir.", true)


func _leave_steam_lobby() -> void:
	var network_manager := get_node_or_null("/root/NetworkManager")
	if network_manager:
		network_manager.leave_network(false)
	_set_steam_settings_locked(false)
	_refresh_steam_availability()
	_refresh_steam_lobbies()


func _is_steam_ui_available() -> bool:
	var steam_manager := get_node_or_null("/root/SteamManager")
	return steam_manager != null and bool(steam_manager.get("is_available"))


func _refresh_steam_availability() -> void:
	if not _steam_identity_label:
		return
	var steam_manager := get_node_or_null("/root/SteamManager")
	var network_manager := get_node_or_null("/root/NetworkManager")
	var available: bool = steam_manager != null and bool(steam_manager.get("is_available"))
	var in_lobby: bool = (
		network_manager != null
		and network_manager.is_using_steam_transport()
		and network_manager.get_steam_lobby_id() > 0
	)
	var steam_engaged: bool = (
		network_manager != null
		and network_manager.is_using_steam_transport()
		and int(network_manager.get("state")) != 0
	)
	_steam_identity_label.text = (
		"Steam bağlı • %s • App ID %d" % [
			str(steam_manager.get("persona_name")),
			int(steam_manager.get("app_id")),
		]
		if available
		else str(steam_manager.get("last_status")) if steam_manager and not str(steam_manager.get("last_status")).is_empty()
		else "Steam çevrimdışı; kodlu UDP odaları kullanılabilir."
	)
	_steam_identity_label.add_theme_color_override(
		"font_color",
		Color(0.58, 0.86, 1.0) if available else Color(0.96, 0.58, 0.42)
	)
	_steam_host_button.disabled = not available or steam_engaged
	_steam_refresh_button.disabled = not available or steam_engaged
	_steam_invite_button.disabled = not in_lobby
	_steam_leave_button.visible = in_lobby
	_set_steam_settings_locked(steam_engaged)


func _create_multiplayer_room() -> void:
	var network_manager := get_node_or_null("/root/NetworkManager")
	if not network_manager:
		_on_network_status_changed("Ağ yöneticisi yüklenemedi.", true)
		return
	var port := int(_multiplayer_host_port_input.text)
	if port < 1 or port > 65535:
		_on_network_status_changed("Port 1-65535 arasında olmalı.", true)
		_multiplayer_host_port_input.grab_focus()
		return
	var room_name := _configured_multiplayer_game_name()
	if room_name.is_empty():
		_on_network_status_changed("Odayı oluşturmak için maç adı gir.", true)
		_multiplayer_game_name_input.grab_focus()
		return
	_multiplayer_host_create_button.disabled = true
	var create_error: Error = network_manager.start_hosted_room(
		_multiplayer_host_address_input.text,
		_multiplayer_host_name_input.text,
		port,
		0,
		_selected_ruleset,
		room_name,
		_selected_card_pool_mode,
		float(_selected_turn_duration_seconds),
		_selected_auto_attack_allowed
	)
	if create_error != OK:
		_multiplayer_host_create_button.disabled = false


func _copy_hosted_invite() -> void:
	var code := _multiplayer_host_invite_input.text.strip_edges()
	if code.is_empty():
		return
	DisplayServer.clipboard_set(code)
	_on_network_status_changed("Davet kodu panoya kopyalandı.", false)


func _leave_hosted_room() -> void:
	var network_manager := get_node_or_null("/root/NetworkManager")
	if network_manager:
		network_manager.leave_network(false)
	_multiplayer_host_invite_input.text = ""
	_multiplayer_host_create_button.disabled = false
	_multiplayer_copy_invite_button.disabled = true
	_multiplayer_leave_room_button.visible = false
	_set_multiplayer_settings_locked(false)
	_multiplayer_players_label.text = "2 oyuncu dolunca maç otomatik başlar."
	_refresh_multiplayer_settings_summary()


func _reconnect_multiplayer() -> void:
	var network_manager := get_node_or_null("/root/NetworkManager")
	if not network_manager:
		return
	_multiplayer_reconnect_button.disabled = true
	if _steam_reconnect_button:
		_steam_reconnect_button.disabled = true
	var reconnect_error: Error = network_manager.reconnect_last_session()
	if reconnect_error != OK:
		_multiplayer_reconnect_button.disabled = false
		if _steam_reconnect_button:
			_steam_reconnect_button.disabled = false


func _join_multiplayer() -> void:
	if not _multiplayer_join_button or _multiplayer_join_button.disabled:
		return
	var network_manager := get_node_or_null("/root/NetworkManager")
	if not network_manager:
		_on_network_status_changed("Ağ yöneticisi yüklenemedi.", true)
		return
	_multiplayer_join_button.disabled = true
	var join_error: Error = network_manager.join_with_invite(
		_multiplayer_code_input.text,
		_multiplayer_name_input.text
	)
	if join_error != OK:
		_on_invite_code_changed(_multiplayer_code_input.text)


func _on_invite_code_changed(raw_value: String) -> void:
	if not _multiplayer_code_input:
		return
	var compact := raw_value.to_upper().replace("-", "").replace(" ", "").replace("_", "")
	compact = compact.replace("O", "0").replace("I", "1").replace("L", "1")
	if compact.length() > 20:
		compact = compact.left(20)
	var groups: Array[String] = []
	for offset in range(0, compact.length(), 5):
		groups.append(compact.substr(offset, mini(5, compact.length() - offset)))
	var formatted := "-".join(groups)
	if _multiplayer_code_input.text != formatted:
		_multiplayer_code_input.set_text(formatted)
		_multiplayer_code_input.caret_column = formatted.length()
	_multiplayer_join_button.disabled = compact.length() != 20


func _connect_network_manager() -> void:
	var network_manager := get_node_or_null("/root/NetworkManager")
	if not network_manager:
		return
	var status_callback := Callable(self, "_on_network_status_changed")
	if not network_manager.is_connected("status_changed", status_callback):
		network_manager.connect("status_changed", status_callback)
	var lobby_callback := Callable(self, "_on_network_lobby_changed")
	if not network_manager.is_connected("lobby_changed", lobby_callback):
		network_manager.connect("lobby_changed", lobby_callback)
	var match_callback := Callable(self, "_on_network_match_starting")
	if not network_manager.is_connected("match_starting", match_callback):
		network_manager.connect("match_starting", match_callback)
	var closed_callback := Callable(self, "_on_network_connection_closed")
	if not network_manager.is_connected("connection_closed", closed_callback):
		network_manager.connect("connection_closed", closed_callback)
	var hosted_callback := Callable(self, "_on_network_room_hosted")
	if not network_manager.is_connected("room_hosted", hosted_callback):
		network_manager.connect("room_hosted", hosted_callback)
	var steam_hosted_callback := Callable(self, "_on_network_steam_room_hosted")
	if not network_manager.is_connected("steam_room_hosted", steam_hosted_callback):
		network_manager.connect("steam_room_hosted", steam_hosted_callback)
	var steam_lobbies_callback := Callable(self, "_on_network_steam_lobbies_changed")
	if not network_manager.is_connected("steam_lobbies_changed", steam_lobbies_callback):
		network_manager.connect("steam_lobbies_changed", steam_lobbies_callback)
	var reconnect_callback := Callable(self, "_on_network_reconnect_available")
	if not network_manager.is_connected("reconnect_available", reconnect_callback):
		network_manager.connect("reconnect_available", reconnect_callback)
	if not str(network_manager.last_status).is_empty():
		_on_network_status_changed(str(network_manager.last_status), bool(network_manager.last_status_is_error))


func _connect_steam_manager_ui() -> void:
	var steam_manager := get_node_or_null("/root/SteamManager")
	if not steam_manager:
		_refresh_steam_availability()
		return
	var ready_callback := Callable(self, "_on_steam_ready_changed")
	if not steam_manager.is_connected("steam_ready_changed", ready_callback):
		steam_manager.connect("steam_ready_changed", ready_callback)
	var status_callback := Callable(self, "_on_steam_status_changed")
	if not steam_manager.is_connected("status_changed", status_callback):
		steam_manager.connect("status_changed", status_callback)
	var identity_callback := Callable(self, "_on_steam_identity_changed")
	if not steam_manager.is_connected("identity_changed", identity_callback):
		steam_manager.connect("identity_changed", identity_callback)
	_refresh_steam_availability()


func _on_steam_ready_changed(_is_ready: bool) -> void:
	_refresh_steam_availability()
	if _multiplayer_steam_panel and _multiplayer_steam_panel.visible:
		_refresh_steam_lobbies()


func _on_steam_status_changed(message: String, is_error: bool) -> void:
	_refresh_steam_availability()
	if _multiplayer_steam_panel and _multiplayer_steam_panel.visible:
		_on_network_status_changed(message, is_error)


func _on_steam_identity_changed(_steam_id: int, _persona_name: String) -> void:
	_refresh_steam_availability()


func _on_network_status_changed(message: String, is_error: bool) -> void:
	if not _multiplayer_status_label:
		return
	_multiplayer_status_label.text = _localize_runtime_text(message, "Network status updated.")
	_multiplayer_status_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.42, 0.34) if is_error else Color(0.52, 0.86, 1.0)
	)
	if is_error and _multiplayer_code_input:
		_on_invite_code_changed(_multiplayer_code_input.text)
	if _multiplayer_steam_panel and _multiplayer_steam_panel.visible:
		_refresh_steam_availability()


func _on_network_lobby_changed(players: Dictionary) -> void:
	if not _multiplayer_players_label:
		return
	var names: Array[String] = []
	for player_id_variant in players.keys():
		var entry_variant: Variant = players[player_id_variant]
		if entry_variant is Dictionary:
			var entry := entry_variant as Dictionary
			var connection_mark := "" if bool(entry.get("connected", true)) else tr(" (reconnecting)")
			names.append("%s • %s%s" % [
				tr(str(entry.get("name", "Komutan"))),
				tr(str(entry.get("deck_name", "İsimsiz Deste"))),
				connection_mark,
			])
	var network_manager := get_node_or_null("/root/NetworkManager")
	var ruleset_name := str(network_manager.get_room_ruleset_name()) if network_manager else "Kuşatma"
	if network_manager and network_manager.has_method("get_room_settings"):
		_refresh_multiplayer_settings_summary(network_manager.get_room_settings())
	_multiplayer_players_label.text = tr("%s • %d/2 ready%s") % [
		tr(ruleset_name),
		players.size(),
		" • " + ", ".join(names) if not names.is_empty() else "",
	]


func _on_network_match_starting(player_id: int) -> void:
	if _multiplayer_join_button:
		_multiplayer_join_button.disabled = true
	if _multiplayer_host_create_button:
		_multiplayer_host_create_button.disabled = true
	if _steam_host_button:
		_steam_host_button.disabled = true
	var network_manager := get_node_or_null("/root/NetworkManager")
	var ruleset_name := str(network_manager.get_room_ruleset_name()) if network_manager else "Kuşatma"
	_on_network_status_changed(
		tr("Opponent found. %s match is starting as Player %d…") % [tr(ruleset_name), player_id],
		false,
	)


func _on_network_connection_closed(message: String) -> void:
	if _multiplayer_overlay and not _multiplayer_overlay.visible:
		_reveal_control(_multiplayer_overlay, 0.18)
	if "Steam" in message:
		_show_steam_multiplayer_mode()
	else:
		_show_multiplayer_mode(false)
	_on_network_status_changed(message, true)


func _on_network_room_hosted(invite_code: String) -> void:
	_multiplayer_host_invite_input.text = invite_code
	_multiplayer_host_create_button.disabled = true
	_multiplayer_copy_invite_button.disabled = invite_code.is_empty()
	_multiplayer_leave_room_button.visible = true
	_set_multiplayer_settings_locked(true)
	var network_manager := get_node_or_null("/root/NetworkManager")
	var ruleset_name := str(network_manager.get_room_ruleset_name()) if network_manager else "Kuşatma"
	_on_network_status_changed(
		tr("%s room is ready. Share the invite code with your opponent.") % tr(ruleset_name),
		false,
	)


func _on_network_steam_room_hosted(lobby_id: int) -> void:
	_show_steam_multiplayer_mode()
	_set_steam_settings_locked(true)
	_steam_host_button.disabled = true
	_steam_refresh_button.disabled = true
	_steam_invite_button.disabled = false
	_steam_leave_button.visible = true
	_on_network_status_changed(
		"Steam P2P lobisi hazır (%d). Arkadaş listesinden davet gönderebilirsin." % lobby_id,
		false
	)


func _on_network_steam_lobbies_changed(lobbies: Array[Dictionary]) -> void:
	_render_steam_lobbies(lobbies)
	_refresh_steam_availability()


func _on_network_reconnect_available(invite_code: String, player_name: String, seconds_remaining: int) -> void:
	if invite_code.begins_with("STEAM:"):
		_show_steam_multiplayer_mode()
		_steam_reconnect_button.visible = true
		_steam_reconnect_button.disabled = false
		_steam_reconnect_button.text = tr("RECONNECT (%d sec)") % seconds_remaining
	else:
		_show_multiplayer_mode(false)
		_multiplayer_code_input.text = invite_code
		_multiplayer_name_input.text = player_name
	_multiplayer_reconnect_button.visible = true
	_multiplayer_reconnect_button.disabled = false
	_multiplayer_reconnect_button.text = tr("RECONNECT (%d sec)") % seconds_remaining


func _localize_runtime_text(value: String, fallback_key: String) -> String:
	if value.is_empty():
		return value
	var localized := tr(value)
	if TranslationServer.get_locale().get_slice("_", 0).to_lower() == "tr":
		return localized
	if localized != value or not _contains_turkish_characters(value):
		return localized
	return tr(fallback_key)


func _contains_turkish_characters(value: String) -> bool:
	for character in ["ç", "ğ", "ı", "ö", "ş", "ü", "Ç", "Ğ", "İ", "Ö", "Ş", "Ü"]:
		if character in value:
			return true
	return false


func _start_game(difficulty: int = -1) -> void:
	if _transitioning:
		return
	if difficulty in [MatchSetup.AIDifficulty.EASY, MatchSetup.AIDifficulty.MEDIUM, MatchSetup.AIDifficulty.HARD]:
		_set_selected_difficulty(difficulty)
	var configured_name := _configured_game_name()
	if configured_name.is_empty():
		if _game_setup_name_feedback:
			_game_setup_name_feedback.text = "Oyunu başlatmak için bir ad gir."
			_game_setup_name_feedback.add_theme_color_override("font_color", Color(0.96, 0.42, 0.34))
		if _game_setup_game_name_input:
			_game_setup_game_name_input.grab_focus()
		return
	MatchSetup.configure_ai(_selected_difficulty)
	MatchSetup.set_ruleset(_selected_ruleset)
	MatchSetup.set_match_name(configured_name)
	MatchSetup.set_turn_duration_seconds(float(_selected_turn_duration_seconds))
	MatchSetup.set_auto_attack_allowed(_selected_auto_attack_allowed)
	MatchSetup.set_card_pool_mode(_selected_card_pool_mode)
	var deck_manager := get_node_or_null("/root/DeckManager")
	if MatchSetup.uses_all_cards():
		MatchSetup.set_player_deck(1, [], "Tüm Kartlar")
		MatchSetup.set_player_deck(2, [], "Tüm Kartlar")
	elif deck_manager:
		var active_deck: Dictionary = deck_manager.get_active_deck()
		MatchSetup.set_player_deck(1, active_deck.get("cards", []), str(active_deck.get("name", "")))
		var ai_deck_names := ["Muhafız Hattı", "Rünik Kontrol", "Fırtına Hücumu"]
		MatchSetup.set_player_deck(
			2,
			deck_manager.get_ai_deck_cards(_selected_difficulty),
			ai_deck_names[clampi(_selected_difficulty, 0, 2)]
		)
	if _difficulty_overlay:
		_difficulty_overlay.visible = false
	_transitioning = true
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_fade_overlay, "color", Color(0.006, 0.007, 0.01, 1.0), 0.34)
	await tween.finished
	var error := SceneTransition.transition_to(GAME_SCENE)
	if error != OK:
		push_error("Oyun yükleme ekranı açılamadı: %s" % error_string(error))
		_transitioning = false
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		create_tween().tween_property(_fade_overlay, "color", Color(0.006, 0.007, 0.01, 0.0), 0.25)


func _show_settings() -> void:
	_settings_tabs.current_tab = 0
	_reveal_control(_settings_overlay, 0.18)
	_fullscreen_toggle.grab_focus()


func _hide_settings() -> void:
	if not _settings_overlay.visible:
		return
	_settings_overlay.visible = false
	_focus_start_button()


func _show_gallery() -> void:
	_set_gallery_filter(_active_filter)
	_reveal_control(_gallery_overlay, 0.18)
	_focus_active_gallery_filter()


func _hide_gallery() -> void:
	_hide_card_detail()
	_gallery_overlay.visible = false
	_clear_gallery_grid()
	_focus_start_button()


func _show_soundtrack() -> void:
	if _soundtrack_track_buttons.is_empty():
		_refresh_soundtrack_list()
	if _menu_music_player:
		_update_soundtrack_track(
			_menu_music_player.current_track_index,
			_menu_music_player.get_current_track_data()
		)
		_on_music_playback_state_changed(_menu_music_player.is_playback_active())
	_reveal_control(_soundtrack_overlay, 0.18)
	var focus_index := 0
	if _menu_music_player:
		focus_index = maxi(_menu_music_player.current_track_index, 0)
	if focus_index < _soundtrack_track_buttons.size():
		_soundtrack_track_buttons[focus_index].grab_focus()


func _hide_soundtrack() -> void:
	if _soundtrack_overlay == null or not _soundtrack_overlay.visible:
		return
	_soundtrack_overlay.visible = false
	_soundtrack_seek_dragging = false
	_focus_start_button()


func _set_gallery_filter(type_key: String) -> void:
	if not TYPE_INFO.has(type_key):
		return
	_active_filter = type_key
	if _filter_buttons.has(type_key):
		_filter_buttons[type_key].set_pressed_no_signal(true)
	_refresh_rarity_filter_options()
	if _active_rarity_filter != "all" and _count_cards_with_rarity(_active_rarity_filter, _active_filter) == 0:
		_active_rarity_filter = "all"
		_rarity_filter_buttons["all"].set_pressed_no_signal(true)
	_refresh_gallery_cards()


func _set_gallery_rarity_filter(rarity_key: String) -> void:
	if not RARITY_INFO.has(rarity_key):
		return
	if rarity_key != "all" and _count_cards_with_rarity(rarity_key, _active_filter) == 0:
		return
	_active_rarity_filter = rarity_key
	if _rarity_filter_buttons.has(rarity_key):
		_rarity_filter_buttons[rarity_key].set_pressed_no_signal(true)
	_refresh_gallery_cards()


func _refresh_gallery_cards() -> void:
	_clear_gallery_grid()

	var card_rows: Array = []
	var requested_types: Array = TYPE_ORDER if _active_filter == "all" else [_active_filter]
	for card_type in requested_types:
		for card_data in CardDatabase.get_cards_for_type(card_type):
			if not _is_gallery_card(card_data):
				continue
			if _active_rarity_filter != "all" and str(card_data.get("rarity", "COMMON")).to_upper() != _active_rarity_filter:
				continue
			card_rows.append({"type": card_type, "data": card_data})
	card_rows.sort_custom(_sort_gallery_rows)

	for row in card_rows:
		_add_gallery_card(str(row["type"]), row["data"])

	_gallery_title_label.text = tr("KARTLAR  /  %s") % _gallery_filter_label().to_upper()
	_gallery_count_label.text = tr("%d CARDS") % card_rows.size()


func _gallery_filter_label() -> String:
	var type_label := tr(str(TYPE_INFO[_active_filter]["label"]))
	if _active_rarity_filter == "all":
		return type_label
	return "%s  •  %s" % [type_label, tr(str(RARITY_INFO[_active_rarity_filter]["label"]))]


func _is_gallery_card(card_data: Dictionary) -> bool:
	if bool(card_data.get("is_hq", false)):
		return false
	var role := str(card_data.get("role", "")).to_lower()
	if role == "hq" or role == "headquarters":
		return false
	var card_id := str(card_data.get("id", "")).to_lower()
	return not card_id.ends_with("_merkez") and not card_id.contains("merkez")


func _sort_gallery_rows(left: Dictionary, right: Dictionary) -> bool:
	var left_type_index := TYPE_ORDER.find(str(left["type"]))
	var right_type_index := TYPE_ORDER.find(str(right["type"]))
	if left_type_index != right_type_index:
		return left_type_index < right_type_index
	var left_data: Dictionary = left["data"]
	var right_data: Dictionary = right["data"]
	return str(left_data.get("name", "")).naturalnocasecmp_to(str(right_data.get("name", ""))) < 0


func _add_gallery_card(card_type: String, card_data: Dictionary) -> void:
	var accent: Color = TYPE_INFO[card_type]["accent"]
	var cell := PanelContainer.new()
	cell.name = "GalleryCell_%s_%s" % [card_type, str(card_data.get("id", "card"))]
	cell.custom_minimum_size = CARD_CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_stylebox_override("panel", _gallery_cell_style(accent, false))
	_gallery_grid.add_child(cell)

	var stage := Control.new()
	stage.name = "CardStage"
	stage.custom_minimum_size = CARD_CELL_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(stage)

	var card := _instantiate_card(card_type, card_data, CARD_GALLERY_SCALE)
	if card == null:
		return
	card.name = "GalleryCard_%s_%s" % [card_type, str(card_data.get("id", "card"))]
	card.position = Vector2((CARD_CELL_SIZE.x - 200.0) * 0.5, (CARD_CELL_SIZE.y - 280.0) * 0.5)
	stage.add_child(card)
	card.scale = CARD_GALLERY_SCALE

	var click_area := Button.new()
	click_area.name = "InspectButton"
	click_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_area.flat = true
	click_area.text = ""
	click_area.tooltip_text = tr("Inspect %s") % tr(str(card_data.get("name", "This card")))
	click_area.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus"]:
		click_area.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	click_area.mouse_entered.connect(_on_gallery_card_hover.bind(cell, card, accent, true))
	click_area.mouse_exited.connect(_on_gallery_card_hover.bind(cell, card, accent, false))
	click_area.focus_entered.connect(_on_gallery_card_hover.bind(cell, card, accent, true))
	click_area.focus_exited.connect(_on_gallery_card_hover.bind(cell, card, accent, false))
	click_area.pressed.connect(_show_card_detail.bind(card_type, card_data))
	stage.add_child(click_area)


func _instantiate_card(card_type: String, card_data: Dictionary, card_scale: Vector2) -> BaseCard:
	var rarity := str(card_data.get("rarity", "COMMON")).to_lower()
	if rarity not in ["common", "rare", "epic", "legendary"]:
		rarity = "common"
	var scene_key := str(CARD_SCENE_KEYS.get(card_type, ""))
	var scene_path := "res://scenes/card_templates/%s_%s.tscn" % [scene_key, rarity]
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("Galeri kart sahnesi bulunamadı: %s" % scene_path)
		return null
	var card := packed_scene.instantiate() as BaseCard
	if card == null:
		push_error("Galeri kartı oluşturulamadı: %s" % scene_path)
		return null
	card.card_id = str(card_data.get("id", ""))
	card.is_draggable = false
	card.normal_scale = card_scale
	card.hover_scale = Vector2.ONE
	card.scale = card_scale
	return card


func _on_gallery_card_hover(cell: PanelContainer, card: BaseCard, accent: Color, hovered: bool) -> void:
	if not is_instance_valid(cell) or not is_instance_valid(card):
		return
	cell.add_theme_stylebox_override("panel", _gallery_cell_style(accent, hovered))
	card.z_index = 2 if hovered else 0
	card.normal_scale = CARD_GALLERY_SCALE * (1.055 if hovered else 1.0)


func _gallery_cell_style(accent: Color, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.10 if hovered else 0.035)
	style.border_color = Color(accent, 0.78 if hovered else 0.18)
	style.set_border_width_all(2 if hovered else 1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(accent, 0.13 if hovered else 0.0)
	style.shadow_size = 12 if hovered else 0
	return style


func _show_card_detail(card_type: String, card_data: Dictionary) -> void:
	for child in _detail_card_stage.get_children():
		_detail_card_stage.remove_child(child)
		child.queue_free()

	var card := _instantiate_card(card_type, card_data, Vector2(1.28, 1.28))
	if card != null:
		card.name = "DetailCard"
		card.position = Vector2(65.0, 87.0)
		_detail_card_stage.add_child(card)
		card.scale = Vector2(1.28, 1.28)

	var info: Dictionary = TYPE_INFO[card_type]
	var rarity_key := str(card_data.get("rarity", "COMMON")).to_upper()
	_detail_type_label.text = tr(str(info["singular"])).to_upper()
	_detail_type_label.add_theme_color_override("font_color", info["accent"])
	_detail_name_label.text = tr(str(card_data.get("name", "İsimsiz Kart")))
	var rarity_name := tr(str(RARITY_NAMES.get(rarity_key, rarity_key.capitalize())))
	_detail_meta_label.text = (
		tr("%s  •  PERMANENT PASSIVE") % rarity_name
		if card_type == "effects"
		else tr("%s  •  %s ENERGY") % [
			rarity_name,
			str(card_data.get("energy_cost", 0)),
		]
	)
	_detail_description_label.text = tr(str(card_data.get("description", "Açıklama bulunmuyor.")))
	_detail_stats_label.text = _format_card_stats(card_type, card_data)
	_detail_effect_label.text = _format_card_effect(card_data)
	_reveal_control(_detail_overlay, 0.15)
	_detail_close_button.grab_focus()


func _hide_card_detail() -> void:
	if _detail_overlay == null or not _detail_overlay.visible:
		return
	_detail_overlay.visible = false
	for child in _detail_card_stage.get_children():
		_detail_card_stage.remove_child(child)
		child.queue_free()
	if _gallery_overlay.visible:
		_focus_active_gallery_filter()


func _focus_active_gallery_filter() -> void:
	if _active_rarity_filter != "all" and _rarity_filter_buttons.has(_active_rarity_filter):
		_rarity_filter_buttons[_active_rarity_filter].grab_focus()
	elif _filter_buttons.has(_active_filter):
		_filter_buttons[_active_filter].grab_focus()


func _format_card_stats(card_type: String, card_data: Dictionary) -> String:
	match card_type:
		"heroes":
			return "%s  %s\n%s  %s\n%s  %s" % [
				tr("ATTACK"),
				str(card_data.get("attack", 0)),
				tr("ARMOR"),
				str(card_data.get("armor", 0)),
				tr("HEALTH"),
				str(card_data.get("health", 0)),
			]
		"settlements":
			return "%s  %s\n%s  %s" % [
				tr("ATTACK"),
				str(card_data.get("attack", 0)),
				tr("HEALTH"),
				str(card_data.get("health", 0)),
			]
		"special_powers":
			return "%s  %s\n%s  %s" % [
				tr("EFFECT TYPE"),
				tr(str(card_data.get("power_type", "Büyü"))),
				tr("EFFECT POWER"),
				str(card_data.get("intensity", 0)),
			]
		"upgrades":
			return "%s  %s\n%s  %+d   %s  %+d   %s  %+d" % [
				tr("TARGET"),
				tr(str(card_data.get("allowed_targets", "Any"))),
				tr("ATTACK"),
				int(card_data.get("bonus_attack", 0)),
				tr("ARMOR"),
				int(card_data.get("bonus_armor", 0)),
				tr("HEALTH"),
				int(card_data.get("bonus_health", 0)),
			]
		"effects":
			return tr("PERMANENT PASSIVE") + "\n" + tr("NO ENERGY OR COMBAT VALUE")
	return ""


func _format_card_effect(card_data: Dictionary) -> String:
	var details: Array[String] = []
	var tags: Variant = card_data.get("tags", card_data.get("granted_tags", []))
	if tags is Array and not tags.is_empty():
		var tag_names: Array[String] = []
		for tag in tags:
			tag_names.append(tr(str(tag).replace("_", " ").capitalize()))
		details.append(tr("Traits: %s") % ", ".join(tag_names))
	var effect_id := str(card_data.get("effect_id", ""))
	if not effect_id.is_empty():
		details.append(tr("Effect record: %s") % effect_id.replace("_", " ").capitalize())
	return "\n".join(details)


func _clear_gallery_grid() -> void:
	if _gallery_grid == null:
		return
	for child in _gallery_grid.get_children():
		_gallery_grid.remove_child(child)
		child.queue_free()


func _show_quit_confirmation() -> void:
	_reveal_control(_quit_overlay, 0.16)
	var cancel_button := _quit_overlay.find_child("QuitCancelButton", true, false) as Button
	if cancel_button:
		cancel_button.grab_focus()


func _hide_quit_confirmation() -> void:
	_quit_overlay.visible = false
	_focus_start_button()


func _quit_game() -> void:
	get_tree().quit()


func _on_volume_changed(value: float) -> void:
	if _volume_value_label:
		_volume_value_label.text = "%d%%" % int(round(value))
	if not _settings_are_loading:
		_settings_manager.set_master_volume(value)


func _on_music_volume_changed(value: float) -> void:
	if _music_volume_value_label:
		_music_volume_value_label.text = "%d%%" % int(round(value))
	_sync_music_playback_with_volume(value)
	if not _settings_are_loading:
		_settings_manager.set_music_volume(value)


func _sync_music_playback_with_volume(value: float) -> void:
	if _menu_music_player:
		_menu_music_player.set_playback_allowed(value > 0.001)


func _on_effects_volume_changed(value: float) -> void:
	if _effects_volume_value_label:
		_effects_volume_value_label.text = "%d%%" % int(round(value))
	if not _settings_are_loading:
		_settings_manager.set_effects_volume(value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	_sync_toggle_text(_fullscreen_toggle, enabled)
	if _resolution_option:
		_resolution_option.disabled = enabled
	if not _settings_are_loading:
		_settings_manager.set_fullscreen(enabled)


func _on_resolution_selected(_index: int) -> void:
	if not _fullscreen_toggle.button_pressed:
		_apply_selected_resolution()


func _on_vsync_toggled(enabled: bool) -> void:
	_sync_toggle_text(_vsync_toggle, enabled)
	if not _settings_are_loading:
		_settings_manager.set_vsync(enabled)


func _on_fps_limit_selected(_index: int) -> void:
	if not _settings_are_loading:
		_settings_manager.set_max_fps(_fps_limit_option.get_selected_id())


func _on_default_difficulty_selected(_index: int) -> void:
	if not _settings_are_loading:
		_settings_manager.set_default_difficulty(_default_difficulty_option.get_selected_id())


func _on_tutorial_toggled(enabled: bool) -> void:
	_sync_toggle_text(_tutorial_toggle, enabled)
	if _tutorial_status_label:
		_tutorial_status_label.text = ""
	if not _settings_are_loading:
		_settings_manager.set_tutorial_enabled(enabled)


func _on_menu_animations_toggled(enabled: bool) -> void:
	_sync_toggle_text(_menu_animation_toggle, enabled)
	if not _settings_are_loading:
		_settings_manager.set_menu_animations(enabled)


func _on_language_selected(locale: String) -> void:
	if _settings_are_loading or not _settings_manager:
		return
	if str(_settings_manager.language) == locale:
		_refresh_language_buttons()
		return
	_settings_manager.set_language(locale)
	_refresh_language_buttons()
	call_deferred("_reload_after_language_change")


func _reload_after_language_change() -> void:
	await get_tree().process_frame
	get_tree().reload_current_scene()


func _sync_toggle_text(toggle: CheckButton, enabled: bool) -> void:
	if toggle:
		toggle.text = "Açık" if enabled else "Kapalı"


func _apply_bus_volume(bus_name: StringName, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var normalized := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(normalized, 0.001)))


func _apply_selected_resolution() -> void:
	if _fullscreen_toggle.button_pressed:
		return
	_settings_manager.set_resolution(_selected_resolution())
	_resolution_option.select(_resolution_index_for(_settings_manager.resolution))


func _selected_resolution() -> Vector2i:
	if _resolution_option == null or _resolution_option.selected < 0:
		return WINDOW_RESOLUTIONS[0]
	return WINDOW_RESOLUTIONS[clampi(_resolution_option.selected, 0, WINDOW_RESOLUTIONS.size() - 1)]


func _resolution_index_for(size_value: Vector2i) -> int:
	for index in range(WINDOW_RESOLUTIONS.size()):
		if WINDOW_RESOLUTIONS[index] == size_value:
			return index
	return 0


func _select_option_by_id(option: OptionButton, item_id: int) -> void:
	for index in range(option.item_count):
		if option.get_item_id(index) == item_id:
			option.select(index)
			return


func _reset_tutorial_progress() -> void:
	var config := ConfigFile.new()
	config.load(ONBOARDING_PATH)
	config.set_value("onboarding", "first_match_tutorial_completed", false)
	var save_error := config.save(ONBOARDING_PATH)
	if save_error != OK:
		if _tutorial_status_label:
			_tutorial_status_label.text = "Rehber durumu kaydedilemedi."
			_tutorial_status_label.add_theme_color_override("font_color", Color(0.88, 0.36, 0.28))
		return
	_tutorial_toggle.set_pressed_no_signal(true)
	_sync_toggle_text(_tutorial_toggle, true)
	_settings_manager.set_tutorial_enabled(true)
	if _tutorial_status_label:
		_tutorial_status_label.text = "Rehber bir sonraki maçta gösterilecek."
		_tutorial_status_label.add_theme_color_override("font_color", Color(0.56, 0.72, 0.52))


func _load_settings() -> void:
	_settings_are_loading = true
	_volume_slider.value = _settings_manager.master_volume
	_music_volume_slider.value = _settings_manager.music_volume
	_effects_volume_slider.value = _settings_manager.effects_volume
	_fullscreen_toggle.button_pressed = _settings_manager.fullscreen
	_resolution_option.select(_resolution_index_for(_settings_manager.resolution))
	_resolution_option.disabled = _settings_manager.fullscreen
	_vsync_toggle.button_pressed = _settings_manager.vsync
	_select_option_by_id(_fps_limit_option, _settings_manager.max_fps)
	_select_option_by_id(_default_difficulty_option, _settings_manager.default_difficulty)
	_tutorial_toggle.button_pressed = _settings_manager.tutorial_enabled
	_menu_animation_toggle.button_pressed = _settings_manager.menu_animations
	_refresh_language_buttons()
	_volume_value_label.text = "%d%%" % int(round(_volume_slider.value))
	_music_volume_value_label.text = "%d%%" % int(round(_music_volume_slider.value))
	_effects_volume_value_label.text = "%d%%" % int(round(_effects_volume_slider.value))
	_sync_toggle_text(_fullscreen_toggle, _settings_manager.fullscreen)
	_sync_toggle_text(_vsync_toggle, _settings_manager.vsync)
	_sync_toggle_text(_tutorial_toggle, _settings_manager.tutorial_enabled)
	_sync_toggle_text(_menu_animation_toggle, _settings_manager.menu_animations)
	_refresh_resolution_availability()
	_sync_music_playback_with_volume(float(_settings_manager.music_volume))
	_settings_are_loading = false


func _save_settings() -> void:
	if _settings_are_loading:
		return
	_settings_manager.save_settings()


func _reset_settings_to_defaults() -> void:
	var previous_language := str(_settings_manager.language)
	_settings_manager.reset_to_defaults()
	_load_settings()
	if previous_language != str(_settings_manager.language):
		call_deferred("_reload_after_language_change")
	if _tutorial_status_label:
		_tutorial_status_label.text = "Varsayılan ayarlar uygulandı."
		_tutorial_status_label.add_theme_color_override("font_color", Color(0.56, 0.72, 0.52))


func _refresh_resolution_availability() -> void:
	if not _resolution_option:
		return
	for index in range(_resolution_option.item_count):
		var resolution_value: Vector2i = WINDOW_RESOLUTIONS[index]
		_resolution_option.set_item_disabled(index, not _settings_manager.is_resolution_supported(resolution_value))


func _refresh_collection_brief() -> void:
	var total := 0
	for card_type in TYPE_ORDER:
		total += _count_cards_for_type(card_type)
	for type_key in ["all"] + TYPE_ORDER:
		if not _filter_buttons.has(type_key):
			continue
		var count := total if type_key == "all" else _count_cards_for_type(type_key)
		var type_info: Dictionary = TYPE_INFO[type_key]
		_filter_buttons[type_key].text = _format_filter_button_text(
			str(type_info["icon"]),
			str(type_info["label"]),
			count
		)

	_refresh_rarity_filter_options()


func _refresh_rarity_filter_options() -> void:
	var source_card_count := _count_cards_for_type(_active_filter)
	for rarity_key in ["all"] + RARITY_ORDER:
		if not _rarity_filter_buttons.has(rarity_key):
			continue
		var rarity_count := source_card_count if rarity_key == "all" else _count_cards_with_rarity(rarity_key, _active_filter)
		var rarity_info: Dictionary = RARITY_INFO[rarity_key]
		var rarity_button := _rarity_filter_buttons[rarity_key] as Button
		rarity_button.text = _format_filter_button_text(
			str(rarity_info["icon"]),
			str(rarity_info["label"]),
			rarity_count
		)
		rarity_button.visible = rarity_key == "all" or rarity_count > 0


func _count_cards_for_type(type_key: String) -> int:
	if type_key == "all":
		var total := 0
		for card_type in TYPE_ORDER:
			total += _count_cards_for_type(card_type)
		return total
	var count := 0
	for card_data in CardDatabase.get_cards_for_type(type_key):
		if _is_gallery_card(card_data):
			count += 1
	return count


func _count_cards_with_rarity(rarity_key: String, type_key: String = "all") -> int:
	var count := 0
	var requested_types: Array = TYPE_ORDER if type_key == "all" else [type_key]
	for card_type in requested_types:
		for card_data in CardDatabase.get_cards_for_type(card_type):
			if _is_gallery_card(card_data) and str(card_data.get("rarity", "COMMON")).to_upper() == rarity_key:
				count += 1
	return count


func _on_menu_button_hover(button: Button, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	var target_modulate := Color(1.05, 1.02, 0.94, 1.0) if hovered else Color.WHITE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target_modulate, 0.12)


func _animate_entry() -> void:
	if not _menu_animations_enabled():
		_fade_overlay.color.a = 0.0
		_main_shell.modulate.a = 1.0
		return
	_main_shell.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_fade_overlay, "color", Color(0.006, 0.007, 0.01, 0.0), 0.48)
	tween.tween_property(_main_shell, "modulate:a", 1.0, 0.34).set_delay(0.10)


func _reveal_control(control: Control, duration: float) -> void:
	control.visible = true
	if not _menu_animations_enabled():
		control.modulate.a = 1.0
		return
	control.modulate.a = 0.0
	create_tween().tween_property(control, "modulate:a", 1.0, duration)


func _menu_animations_enabled() -> bool:
	return _menu_animation_toggle == null or _menu_animation_toggle.button_pressed


func _focus_start_button() -> void:
	if _main_shell == null:
		return
	var start_button := _main_shell.find_child("StartButton", true, false) as Button
	if start_button and start_button.is_visible_in_tree():
		start_button.grab_focus()


func _on_viewport_size_changed() -> void:
	if _main_shell == null:
		return
	var viewport_size := get_viewport_rect().size
	var panel_width := minf(410.0, viewport_size.x - 48.0)
	var panel_height := minf(620.0, viewport_size.y - 36.0)
	var left_margin := 56.0 if viewport_size.x >= 900.0 else 24.0
	_main_shell.anchor_left = 0.0
	_main_shell.anchor_top = 0.5
	_main_shell.anchor_right = 0.0
	_main_shell.anchor_bottom = 0.5
	_main_shell.offset_left = left_margin
	_main_shell.offset_right = left_margin + panel_width
	_main_shell.offset_top = -panel_height * 0.5
	_main_shell.offset_bottom = panel_height * 0.5
	if _gallery_grid:
		var usable_width := maxf(420.0, viewport_size.x - 110.0)
		_gallery_grid.columns = clampi(int(floor(usable_width / (CARD_CELL_SIZE.x + 15.0))), 2, 5)
	if _settings_panel:
		_settings_panel.custom_minimum_size = Vector2(
			minf(880.0, viewport_size.x - 48.0),
			minf(610.0, viewport_size.y - 42.0)
		)
	if _soundtrack_panel:
		_soundtrack_panel.custom_minimum_size = Vector2(
			minf(1020.0, viewport_size.x - 48.0),
			minf(610.0, viewport_size.y - 42.0)
		)
	if _difficulty_panel:
		_difficulty_panel.custom_minimum_size = Vector2(
			minf(980.0, viewport_size.x - 42.0),
			minf(650.0, viewport_size.y - 36.0)
		)
	if _multiplayer_panel:
		_multiplayer_panel.custom_minimum_size = Vector2(
			minf(980.0, viewport_size.x - 42.0),
			minf(684.0, viewport_size.y - 24.0)
		)
	if _detail_panel:
		_detail_panel.custom_minimum_size = Vector2(
			minf(900.0, viewport_size.x - 54.0),
			minf(570.0, viewport_size.y - 44.0)
		)
	if _quit_panel:
		_quit_panel.custom_minimum_size.x = minf(510.0, viewport_size.x - 48.0)
	_refresh_resolution_availability()
