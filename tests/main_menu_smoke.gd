extends SceneTree

const TYPE_ORDER := ["heroes", "settlements", "special_powers", "upgrades", "effects"]
const UI := preload("res://scripts/dark_fantasy_ui.gd")
const DIFFICULTY_EMBLEM_SCRIPT := preload("res://scripts/difficulty_emblem.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://main_menu.tscn") as PackedScene
	_expect(packed != null, "main_menu.tscn yüklenemedi")
	if packed == null:
		_finish()
		return

	var menu := packed.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame

	var start_button := menu.find_child("StartButton", true, false) as Button
	var game_title := menu.find_child("GameTitle", true, false) as Label
	var title_top_spacer := menu.find_child("TitleTopSpacer", true, false) as Control
	var application_name := str(ProjectSettings.get_setting("application/config/name", ""))
	var application_version := str(ProjectSettings.get_setting("application/config/version", ""))
	var release_stage := str(ProjectSettings.get_setting("application/config/release_stage", ""))
	_expect(start_button is Button, "Başla düğmesi bulunamadı")
	_expect(game_title != null and game_title.get_theme_font_size("font_size") >= 56, "Darwine başlığı UI_KIT aralığında (56-72) olmalı")
	_expect(title_top_spacer != null and title_top_spacer.custom_minimum_size.y == 8.0, "Darwine başlığı biraz aşağı alınmalı")
	_expect(application_name == "Darwine", "Oyun adı ana yapılandırmada tutulmalı")
	_expect(application_version == "0.7" and release_stage == "RC", "Sürüm bilgisi ana yapılandırmada tutulmalı")
	_expect(game_title != null and game_title.text == application_name.to_upper(), "Ana başlık oyun adını ana yapılandırmadan okumalı")
	_expect(menu.find_child("Eyebrow", true, false) == null, "Üç Koridorlu Kuşatma üst etiketi kaldırılmalı")
	_expect(menu.find_child("CollectionBrief", true, false) == null, "Sağdaki Kart Arşivi paneli kaldırılmalı")
	_expect(not _tree_contains_text(menu, "KART ARŞİVİ"), "Ana menüde Kart Arşivi metni kalmamalı")
	_expect(start_button != null and start_button.text == "SAVAŞA BAŞLA", "Başla düğmesi yeni tematik metni kullanmıyor")
	var online_button := menu.find_child("OnlineButton", true, false) as Button
	_expect(online_button is Button and online_button.text == "ÇEVRİMİÇİ OYNA", "Çevrimiçi Oyna düğmesi bulunamadı")
	_expect(menu.find_child("HowToButton", true, false) is Button, "Nasıl Oynanır düğmesi bulunamadı")
	_expect(menu.find_child("SettingsButton", true, false) is Button, "Ayarlar düğmesi bulunamadı")
	var gallery_menu_button := menu.find_child("GalleryButton", true, false) as Button
	_expect(gallery_menu_button is Button and gallery_menu_button.text == "KARTLAR", "Kartlar düğmesi bulunamadı veya eski galeri adını kullanıyor")
	var load_menu_button := menu.find_child("ContinueGameButton", true, false) as Button
	_expect(load_menu_button != null and load_menu_button.visible and load_menu_button.text == tr("YÜKLE"), "Ana menü slot seçimi için Yükle düğmesini göstermeli")
	var soundtrack_button := menu.find_child("SoundtrackButton", true, false) as Button
	_expect(soundtrack_button is Button, "Soundtrack düğmesi bulunamadı")
	_expect(
		soundtrack_button != null
		and soundtrack_button.get_theme_font_size("font_size") == 16
		and soundtrack_button.text == "SOUNDTRACK",
		"Soundtrack düğmesi yerelleştirilebilir anahtar ve tutarlı 16 punto kullanmalı"
	)
	var profile_button := menu.find_child("ProfileButton", true, false) as Button
	_expect(profile_button is Button and profile_button.text == "PROFİL", "Profil düğmesi doğru kısa başlığı göstermeli")
	_expect(menu.find_child("QuitButton", true, false) is Button, "Çıkış Yap düğmesi bulunamadı")
	var version_label := menu.find_child("VersionLabel", true, false) as Button
	var main_content := menu.find_child("MainContent", true, false) as VBoxContainer
	var menu_buttons := menu.find_child("MenuButtons", true, false) as VBoxContainer
	_expect(
		version_label != null
		and version_label.text == str(menu.call("_application_version_label"))
		and version_label.get_parent() == main_content
		and menu_buttons != null
		and version_label.get_index() > menu_buttons.get_index(),
		"Sürüm bilgisi ana menü düğmelerinin altındaki boşlukta görünmeli"
	)
	_expect(version_label != null and version_label.focus_mode == Control.FOCUS_ALL, "Sürüm notları klavyeyle açılabilmeli")
	var mini_music_player := menu.find_child("MiniMusicPlayer", true, false) as PanelContainer
	_expect(
		mini_music_player != null and mini_music_player.anchor_left == 1.0 and mini_music_player.anchor_top == 1.0,
		"Mini müzik çalar ana menünün sağ altına sabitlenmeli"
	)
	var mini_music_track_title := menu.find_child("MiniMusicTrackTitle", true, false) as Label
	var mini_music_now_playing := menu.find_child("MiniMusicNowPlaying", true, false) as Label
	var mini_music_track_copy := menu.find_child("MiniMusicTrackCopy", true, false) as VBoxContainer
	var mini_music_track_index := menu.find_child("MiniMusicTrackIndex", true, false) as Label
	var mini_music_controls_offset := menu.find_child("MiniMusicControlsOffset", true, false) as Control
	_expect(mini_music_track_title is Label, "Mini müzik çalar parça adını göstermeli")
	_expect(
		mini_music_track_title != null
		and mini_music_track_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and mini_music_track_title.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
		"Mini parça adı ortalanmalı ve taşınca kısaltılmalı"
	)
	_expect(
		mini_music_now_playing != null
		and mini_music_now_playing.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and mini_music_now_playing.get_parent() == mini_music_track_copy
		and mini_music_track_title.get_parent() == mini_music_track_copy
		and mini_music_now_playing.get_index() + 1 == mini_music_track_title.get_index()
		and _is_horizontally_centered(mini_music_now_playing, mini_music_player),
		"Mini müzik çalar Şimdi Çalıyor etiketi başlığın hemen üstünde ve ortalanmış olmalı"
	)
	_expect(
		mini_music_track_index != null
		and is_equal_approx(mini_music_track_index.offset_left, -68.0)
		and is_equal_approx(mini_music_track_index.offset_top, 3.0)
		and is_equal_approx(mini_music_track_index.offset_right, -10.0),
		"Mini parça sayacı dekoratif çıkıntı üzerine hafifçe sola ve aşağıya taşınmalı"
	)
	_expect(
		mini_music_controls_offset != null and is_equal_approx(mini_music_controls_offset.custom_minimum_size.y, 1.0),
		"Mini müzik çalar kontrolleri bir piksel aşağıda olmalı"
	)
	_expect(_is_horizontally_centered(mini_music_track_title, mini_music_player), "Mini parça adı ortalanmalı")
	var mini_previous_button := menu.find_child("MiniPreviousTrackButton", true, false) as Button
	_expect(mini_previous_button is Button, "Mini müzik çalar önceki düğmesini göstermeli")
	_expect(menu.find_child("MiniPlayPauseButton", true, false) is Button, "Mini müzik çalar oynat/duraklat düğmesini göstermeli")
	var mini_next_button := menu.find_child("MiniNextTrackButton", true, false) as Button
	_expect(mini_next_button is Button, "Mini müzik çalar sonraki düğmesini göstermeli")
	_expect(
		mini_previous_button != null
		and mini_previous_button.get_theme_font("font") == UI.BODY_BOLD_FONT
		and mini_next_button != null
		and mini_next_button.get_theme_font("font") == UI.BODY_BOLD_FONT,
		"Mini müzik çalar ileri ve geri düğmeleri kalın yazı tipini kullanmalı"
	)
	_expect(not _tree_contains_text(menu, "PROTOTİP"), "Ana menüde prototip etiketi kalmamalı")
	_expect(menu.find_child("MasterVolumeSlider", true, false) is HSlider, "Ana ses ayarı bulunamadı")
	_expect(menu.find_child("MusicVolumeSlider", true, false) is HSlider, "Müzik ses ayarı bulunamadı")
	_expect(menu.find_child("EffectsVolumeSlider", true, false) is HSlider, "Efekt ses ayarı bulunamadı")
	_expect(menu.find_child("FullscreenToggle", true, false) is CheckButton, "Tam ekran ayarı bulunamadı")
	_expect(menu.find_child("ResolutionOption", true, false) is OptionButton, "Çözünürlük ayarı bulunamadı")
	_expect(menu.find_child("VSyncToggle", true, false) is CheckButton, "VSync ayarı bulunamadı")
	_expect(menu.find_child("FpsLimitOption", true, false) is OptionButton, "FPS sınırı ayarı bulunamadı")
	_expect(menu.find_child("SettingsResetButton", true, false) is Button, "Varsayılan ayarlara dön düğmesi bulunamadı")
	_expect(menu.find_child("DefaultDifficultyOption", true, false) is OptionButton, "Varsayılan rakip ayarı bulunamadı")
	_expect(menu.find_child("TutorialToggle", true, false) is CheckButton, "İlk maç rehberi ayarı bulunamadı")
	_expect(menu.find_child("MenuAnimationsToggle", true, false) is CheckButton, "Menü geçişi ayarı bulunamadı")
	var settings_tabs := menu.find_child("SettingsTabs", true, false) as TabContainer
	_expect(settings_tabs != null and settings_tabs.get_tab_count() == 4, "Ayarlar dört sekmeli olmalı")
	for locale in ["En", "De", "Fr", "It", "Es", "Tr"]:
		_expect(menu.find_child("Language%sButton" % locale, true, false) is Button, "%s dil düğmesi bulunamadı" % locale)
		_expect(menu.find_child("Language%sFlag" % locale, true, false) is LanguageFlagIcon, "%s bayrağı bulunamadı" % locale)

	menu.call("_show_release_notes")
	await process_frame
	var release_notes := menu.find_child("ReleaseNotesOverlay", true, false) as ReleaseNotesPanel
	_expect(release_notes != null and release_notes.is_open(), "Sürüm notları açılmalı")
	_expect(release_notes != null and release_notes.get_release_count() == 7, "0.1-0.7 sürüm geçmişi bulunmalı")
	_expect(menu.find_child("Release0_7", true, false) is PanelContainer, "0.7 sürüm notu bulunamadı")
	_expect(menu.find_child("Release0_1", true, false) is PanelContainer, "0.1 geçmiş sürüm notu bulunamadı")
	menu.call("_hide_release_notes")

	var fade := menu.find_child("SceneFade", true, false) as ColorRect
	var main_panel := menu.find_child("MainMenuPanel", true, false) as Control
	if fade:
		fade.color.a = 0.0
	if main_panel:
		main_panel.modulate.a = 1.0
	await create_timer(0.65).timeout
	_capture("/tmp/tdm_main_menu.png")

	menu.call("_show_multiplayer")
	await create_timer(0.22).timeout
	var multiplayer_overlay := menu.find_child("MultiplayerOverlay", true, false) as Control
	var host_room_panel := menu.find_child("HostRoomPanel", true, false) as VBoxContainer
	var join_room_panel := menu.find_child("JoinRoomPanel", true, false) as VBoxContainer
	var host_address_input := menu.find_child("HostAddressInput", true, false) as LineEdit
	var host_port_input := menu.find_child("HostPortInput", true, false) as LineEdit
	var create_room_button := menu.find_child("CreateRoomButton", true, false) as Button
	var copy_invite_button := menu.find_child("CopyInviteButton", true, false) as Button
	var reconnect_button := menu.find_child("ReconnectButton", true, false) as Button
	var steam_mode_button := menu.find_child("SteamModeButton", true, false) as Button
	var steam_panel := menu.find_child("SteamP2PPanel", true, false) as VBoxContainer
	var steam_identity := menu.find_child("SteamIdentityStatus", true, false) as Label
	var steam_capabilities := menu.find_child("SteamCapabilitiesStatus", true, false) as Label
	var steam_host_button := menu.find_child("SteamCreateLobbyButton", true, false) as Button
	var steam_refresh_button := menu.find_child("SteamRefreshLobbiesButton", true, false) as Button
	var steam_invite_button := menu.find_child("SteamInviteFriendsButton", true, false) as Button
	var steam_friends_button := menu.find_child("SteamFriendsOverlayButton", true, false) as Button
	var steam_achievements_button := menu.find_child("SteamAchievementsButton", true, false) as Button
	var steam_lobby_list := menu.find_child("SteamLobbyList", true, false) as VBoxContainer
	var invite_code_input := menu.find_child("InviteCodeInput", true, false) as LineEdit
	var multiplayer_join_button := menu.find_child("MultiplayerJoinButton", true, false) as Button
	_expect(multiplayer_overlay != null and multiplayer_overlay.visible, "Çevrimiçi oyun penceresi açılmadı")
	_expect(host_room_panel != null and host_room_panel.visible, "Oda kurma modu varsayılan olarak açılmalı")
	_expect(join_room_panel != null and not join_room_panel.visible, "Kodla katıl modu başlangıçta gizli olmalı")
	_expect(host_address_input != null and not host_address_input.text.is_empty(), "Oda kurma adresi önerilmedi")
	_expect(host_port_input != null and host_port_input.text == "7777", "Oda kurma portu varsayılanı yanlış")
	_expect(create_room_button != null and create_room_button.text == "ODAYI OLUŞTUR", "Oda oluşturma düğmesi bulunamadı")
	_expect(copy_invite_button != null and copy_invite_button.disabled, "Davet kodu oluşmadan kopyalama kapalı olmalı")
	_expect(reconnect_button != null and not reconnect_button.visible, "Aktif oturum yokken yeniden bağlan düğmesi gizli olmalı")
	_expect(steam_mode_button != null and steam_mode_button.text == "STEAM P2P", "Steam P2P modu bulunamadı")
	_expect(steam_panel != null and not steam_panel.visible, "Steam P2P alanı varsayılan modda gizli olmalı")
	_capture("/tmp/tdm_multiplayer_host.png")
	menu.call("_show_multiplayer_mode", false)
	await process_frame
	_expect(host_room_panel != null and not host_room_panel.visible, "Kodla katıl modunda oda kurma alanı gizlenmedi")
	_expect(join_room_panel != null and join_room_panel.visible, "Kodla katıl alanı açılmadı")
	_expect(invite_code_input != null, "Davet kodu alanı bulunamadı")
	_expect(multiplayer_join_button != null and multiplayer_join_button.disabled, "Eksik davet koduyla katılım kapalı olmalı")
	if invite_code_input:
		menu.call("_on_invite_code_changed", "075G0W9A3SGH4D2PF2TG")
		await process_frame
		_expect(invite_code_input.text == "075G0-W9A3S-GH4D2-PF2TG", "Davet kodu okunabilir gruplara ayrılmadı")
		_expect(multiplayer_join_button != null and not multiplayer_join_button.disabled, "Tam davet koduyla katılım etkinleşmedi")
	await create_timer(0.12).timeout
	_capture("/tmp/tdm_multiplayer_join.png")
	menu.call("_show_steam_multiplayer_mode")
	await process_frame
	_expect(steam_panel != null and steam_panel.visible, "Steam P2P alanı açılamadı")
	_expect(host_room_panel != null and not host_room_panel.visible, "Steam modunda kodlu host alanı gizlenmeli")
	_expect(join_room_panel != null and not join_room_panel.visible, "Steam modunda kodla katıl alanı gizlenmeli")
	_expect(steam_identity != null and not steam_identity.text.is_empty(), "Steam kimlik/durum özeti gösterilmeli")
	_expect(steam_capabilities != null and "Shift+Tab" in steam_capabilities.text, "Shift+Tab durumu gösterilmeli")
	_expect(steam_host_button is Button, "Steam odası açma düğmesi bulunamadı")
	_expect(steam_refresh_button is Button, "Steam lobi yenileme düğmesi bulunamadı")
	_expect(steam_invite_button != null and steam_invite_button.disabled, "Lobi olmadan Steam arkadaş daveti kapalı olmalı")
	_expect(steam_friends_button is Button, "Steam arkadaş overlay düğmesi bulunamadı")
	_expect(steam_achievements_button is Button, "Steam başarım düğmesi bulunamadı")
	_expect(steam_lobby_list is VBoxContainer, "Steam lobi listesi bulunamadı")
	_expect(int(ProjectSettings.get_setting("steam/initialization/app_data/app_id", 0)) > 0, "Steam App ID proje ayarında tanımlanmalı")
	_capture("/tmp/tdm_multiplayer_steam.png")
	menu.call("_hide_multiplayer")
	_expect(multiplayer_overlay == null or not multiplayer_overlay.visible, "Davet koduyla katılım penceresi kapanmadı")

	menu.call("_show_profile")
	await create_timer(0.18).timeout
	var profile_overlay := menu.find_child("ProfileOverlay", true, false) as CommanderProfilePanel
	var profile_panel := menu.find_child("ProfilePanel", true, false) as Control
	var profile_heading := menu.find_child("ProfileHeading", true, false) as Label
	var profile_tabs := menu.find_child("ProfileTabs", true, false) as TabContainer
	_expect(profile_overlay != null and profile_overlay.is_open(), "Komutan Profili açılmadı")
	_expect(_is_horizontally_centered(profile_heading, profile_panel), "Profil başlığı pencerenin ortasında olmalı")
	_expect(profile_tabs != null and profile_tabs.get_tab_count() == 3, "Komutan Profili üç sekmeli olmalı")
	_expect(menu.find_child("AchievementList", true, false) is VBoxContainer, "Profil başarı listesi bulunamadı")
	_expect(menu.find_child("DailyMissionList", true, false) is VBoxContainer, "Profil günlük görevleri bulunamadı")
	_expect(menu.find_child("MatchHistoryList", true, false) is VBoxContainer, "Profil maç geçmişi bulunamadı")
	menu.call("_hide_profile")
	_expect(profile_overlay == null or not profile_overlay.is_open(), "Komutan Profili kapanmadı")

	menu.call("_show_how_to_play")
	await create_timer(0.12).timeout
	var how_to_overlay := menu.find_child("HowToOverlay", true, false) as HowToPlayPanel
	var how_to_panel := menu.find_child("HowToPanel", true, false) as Control
	var how_to_title := menu.find_child("HowToPageTitle", true, false) as Label
	_expect(how_to_overlay != null and how_to_overlay.is_open(), "Nasıl Oynanır sayfası açılmadı")
	_expect(how_to_overlay != null and how_to_overlay.get_page_count() == 8, "Nasıl Oynanır sayfası sekiz bölümlü olmalı")
	_expect(_tree_contains_text(how_to_overlay, tr("İKİ OYUN MODU")), "Nasıl Oynanır oyun modları bölümü görünmüyor")
	_expect(_tree_contains_text(how_to_overlay, tr("MERKEZİ YIK")), "Kuşatma modu zafer koşulunu açıklamıyor")
	_expect(_tree_contains_text(how_to_overlay, tr("12 PUANA ULAŞ")), "Hakimiyet modu zafer koşulunu açıklamıyor")
	_expect(_is_horizontally_centered(how_to_title, how_to_panel), "Nasıl Oynanır başlığı pencerenin ortasında olmalı")
	_capture("/tmp/tdm_how_to_modes.png")
	if how_to_overlay:
		how_to_overlay.open_panel(1)
		await process_frame
		_expect(_tree_contains_text(how_to_overlay, tr("SAVAŞ ALANI VE ZAFER")), "Nasıl Oynanır amaç bölümü görünmüyor")
		_capture("/tmp/tdm_how_to_goal.png")
		how_to_overlay.open_panel(2)
		await process_frame
		_expect(_tree_contains_text(how_to_overlay, tr("DESTE, KARTLAR VE ETKİ")), "Kart türleri ve Etki Kartı rehberi görünmüyor")
		_expect(
			_tree_contains_text(
				how_to_overlay,
				tr("ETKİ KARTI  •  Mulligan'dan önce üç tekliften birini seçersin. Eline girmez ve Enerji harcamaz; maç boyunca pasif kalır. Rakibin seçimi gizlidir.")
			),
			"Etki Kartı gizlilik rehberi görünmüyor"
		)
		_capture("/tmp/tdm_how_to_cards.png")
		how_to_overlay.open_panel(3)
		await process_frame
		_expect(_tree_contains_text(how_to_overlay, tr("BİR TUR NASIL İŞLER?")), "Tur akışı rehberi görünmüyor")
		_capture("/tmp/tdm_how_to_turn.png")
		how_to_overlay.open_panel(4)
		await process_frame
		_expect(how_to_overlay.get_current_page() == 4, "Nasıl Oynanır sayfaları arasında geçilemiyor")
		_expect(_tree_contains_text(how_to_overlay, tr("KART OYNAMA VE HEDEFLEME")), "Hedefleme rehberi görünmüyor")
		_capture("/tmp/tdm_how_to_targeting.png")
		how_to_overlay.open_panel(5)
		await process_frame
		_expect(_tree_contains_text(how_to_overlay, tr("ÇATIŞMA VE HAREKET")), "Çatışma rehberi görünmüyor")
		_capture("/tmp/tdm_how_to_combat.png")
		how_to_overlay.open_panel(6)
		await process_frame
		_expect(_tree_contains_text(how_to_overlay, tr("CAN ÇALMA")), "Yeni Can Çalma anahtarı rehberde açıklanmıyor")
		_capture("/tmp/tdm_how_to_mastery.png")
		how_to_overlay.open_panel(7)
		await process_frame
		_expect(_tree_contains_text(how_to_overlay, tr("KONTROLLER, KAYIT VE YARDIM")), "Kontrol ve kayıt rehberi görünmüyor")
		_expect(_tree_contains_text(how_to_overlay, tr("KAYIT SLOTU")), "Slot kaydet/yükle rehberi görünmüyor")
		_capture("/tmp/tdm_how_to_controls.png")
	menu.call("_hide_how_to_play")
	_expect(how_to_overlay == null or not how_to_overlay.is_open(), "Nasıl Oynanır sayfası kapanmadı")

	menu.call("_show_gallery")
	await create_timer(0.22).timeout
	var gallery_overlay := menu.find_child("GalleryOverlay", true, false) as Control
	var gallery_panel := menu.find_child("GalleryPanel", true, false) as Control
	var gallery_title := menu.find_child("GalleryTitle", true, false) as Label
	var grid := menu.find_child("CardGrid", true, false) as GridContainer
	_expect(gallery_overlay != null and gallery_overlay.visible, "Galeri açılmadı")
	_expect(grid != null, "Galeri kart ızgarası bulunamadı")
	_expect(_is_horizontally_centered(gallery_title, gallery_panel), "Galeri başlığı pencerenin ortasında olmalı")

	var total := 0
	for card_type in TYPE_ORDER:
		total += _count_gallery_cards_for_type(card_type)
	if grid:
		_expect(grid.get_child_count() == total, "Tümü filtresi %d yerine %d kart gösteriyor" % [total, grid.get_child_count()])
		_expect(
			grid.find_child("GalleryCard_settlements_p1_merkez", true, false) == null
			and grid.find_child("GalleryCard_settlements_p2_merkez", true, false) == null,
			"Merkez binaları Kart Galerisi'nde görünmemeli"
		)
	_capture("/tmp/tdm_gallery.png")

	for card_type in TYPE_ORDER:
		menu.call("_set_gallery_filter", card_type)
		await process_frame
		var expected_count := _count_gallery_cards_for_type(card_type)
		_expect(grid.get_child_count() == expected_count, "%s filtresi yanlış kart sayısı gösteriyor" % card_type)

	var rarity_filters := menu.find_child("RarityFilters", true, false) as HBoxContainer
	_expect(rarity_filters != null and rarity_filters.get_child_count() == 5, "Nadirlik filtreleri oluşturulmadı")
	for rarity_key in ["COMMON", "RARE", "EPIC", "LEGENDARY"]:
		var rarity_button := menu.find_child("%sRarityFilter" % rarity_key.capitalize(), true, false) as Button
		_expect(
			rarity_button != null and not rarity_button.tooltip_text.is_empty() and not rarity_button.text.begins_with(rarity_button.tooltip_text),
			"%s nadirlik filtresi renkli ikonlu etiket kullanmalı" % rarity_key
		)
		menu.call("_set_gallery_filter", "all")
		menu.call("_set_gallery_rarity_filter", rarity_key)
		await process_frame
		_expect(
			grid.get_child_count() == _count_cards_with_rarity(rarity_key),
			"%s nadirlik filtresi yanlış kart sayısı gösteriyor" % rarity_key
		)

	menu.call("_set_gallery_filter", "all")
	menu.call("_set_gallery_rarity_filter", "COMMON")
	menu.call("_set_gallery_filter", "heroes")
	await process_frame
	var all_rarity_button := menu.find_child("AllRarityFilter", true, false) as Button
	var common_rarity_button := menu.find_child("CommonRarityFilter", true, false) as Button
	_expect(
		all_rarity_button != null
		and all_rarity_button.button_pressed
		and all_rarity_button.text.ends_with(str(_count_gallery_cards_for_type("heroes"))),
		"Nadirlik tümü sayacı seçili kart türüne göre güncellenmiyor"
	)
	_expect(
		common_rarity_button != null and not common_rarity_button.visible and common_rarity_button.text.ends_with("0"),
		"Seçili türde olmayan nadirlik gizlenmeli"
	)
	_expect(grid.get_child_count() == _count_gallery_cards_for_type("heroes"), "Geçersiz nadirlik seçimi tür değişiminde temizlenmedi")

	menu.call("_set_gallery_rarity_filter", "RARE")
	await process_frame
	_expect(
		grid.get_child_count() == _count_cards_with_rarity("RARE", "heroes"),
		"Tür ve nadirlik filtreleri birlikte çalışmıyor"
	)
	menu.call("_set_gallery_rarity_filter", "all")

	menu.call("_set_gallery_filter", "heroes")
	await process_frame
	if grid and grid.get_child_count() > 0:
		var first_cell := grid.get_child(0)
		var inspect_button := first_cell.find_child("InspectButton", true, false) as Button
		_expect(inspect_button != null, "Kart inceleme düğmesi bulunamadı")
		if inspect_button:
			inspect_button.pressed.emit()
			await create_timer(0.20).timeout
			var detail_overlay := menu.find_child("CardDetailOverlay", true, false) as Control
			var detail_panel := menu.find_child("CardDetailPanel", true, false) as Control
			var detail_title := menu.find_child("CardDetailTitle", true, false) as Label
			_expect(detail_overlay != null and detail_overlay.visible, "Kart ayrıntısı açılmadı")
			_expect(menu.find_child("DetailCard", true, false) is BaseCard, "Ayrıntı kartı oluşturulmadı")
			_expect(_is_horizontally_centered(detail_title, detail_panel), "Kart ayrıntısı başlığı pencerenin ortasında olmalı")
			_capture("/tmp/tdm_card_detail.png")

	menu.call("_hide_card_detail")
	menu.call("_set_gallery_filter", "special_powers")
	await process_frame
	var banish_cell := grid.find_child("GalleryCell_special_powers_hiclik_fermani", true, false) if grid else null
	var banish_inspect := banish_cell.find_child("InspectButton", true, false) as Button if banish_cell else null
	_expect(banish_inspect != null, "Hiçlik Fermanı galeride incelenebilir olmalı")
	if banish_inspect:
		banish_inspect.pressed.emit()
		await create_timer(0.20).timeout
		var banish_detail := menu.find_child("DetailCard", true, false) as SpecialPowerCard
		_expect(banish_detail != null and banish_detail.card_id == "hiclik_fermani", "Hiçlik Fermanı ayrıntısı doğru kartı açmalı")
		_capture("/tmp/tdm_hiclik_fermani.png")
	menu.call("_hide_card_detail")
	menu.call("_hide_gallery")
	menu.call("_show_soundtrack")
	await create_timer(0.22).timeout
	var soundtrack_overlay := menu.find_child("SoundtrackOverlay", true, false) as Control
	var soundtrack_panel := menu.find_child("SoundtrackPanel", true, false) as Control
	var soundtrack_title := menu.find_child("SoundtrackTitle", true, false) as Label
	var soundtrack_list := menu.find_child("SoundtrackTrackList", true, false) as VBoxContainer
	var music_player := menu.find_child("MenuMusicPlayer", true, false) as MenuMusicPlayer
	menu.call("_sync_music_playback_with_volume", 70.0)
	_expect(soundtrack_overlay != null and soundtrack_overlay.visible, "Soundtrack sayfası açılmadı")
	_expect(_is_horizontally_centered(soundtrack_title, soundtrack_panel), "Soundtrack başlığı pencerenin ortasında olmalı")
	_expect(soundtrack_list != null and soundtrack_list.get_child_count() == 5, "Soundtrack sayfası beş parçayı göstermeli")
	_expect(menu.find_child("SoundtrackProgress", true, false) is HSlider, "Soundtrack sarma çubuğu bulunamadı")
	var first_track_number := menu.find_child("TrackNumber01", true, false) as Label
	_expect(
		first_track_number != null and first_track_number.vertical_alignment == VERTICAL_ALIGNMENT_CENTER,
		"Soundtrack numaraları kart içinde dikey ortalanmalı"
	)
	var previous_control := menu.find_child("PreviousTrackButton", true, false) as Button
	_expect(previous_control is Button, "Önceki parça düğmesi bulunamadı")
	_expect(menu.find_child("PlayPauseTrackButton", true, false) is Button, "Oynat/duraklat düğmesi bulunamadı")
	var next_control := menu.find_child("NextTrackButton", true, false) as Button
	_expect(next_control is Button, "Sonraki parça düğmesi bulunamadı")
	_expect(
		previous_control != null and previous_control.clip_text and next_control != null and next_control.clip_text,
		"Soundtrack yön düğmeleri metni çerçeve dışına taşırmamalı"
	)
	_expect(
		previous_control != null
		and previous_control.get_theme_font("font") == UI.BODY_BOLD_FONT
		and next_control != null
		and next_control.get_theme_font("font") == UI.BODY_BOLD_FONT,
		"Soundtrack ileri ve geri düğmeleri kalın yazı tipini kullanmalı"
	)
	_expect(_tree_contains_text(menu, "Iron Dawn"), "Iron Dawn soundtrack listesinde görünmeli")
	_expect(_tree_contains_text(menu, "Waiting in the Cold"), "Waiting in the Cold soundtrack listesinde görünmeli")
	_expect(_tree_contains_text(menu, "Whisper of the Ramparts"), "Whisper of the Ramparts soundtrack listesinde görünmeli")
	_expect(_tree_contains_text(menu, "Mud and Blood"), "Mud and Blood soundtrack listesinde görünmeli")
	_expect(_tree_contains_text(menu, "March of Courage"), "March of Courage soundtrack listesinde görünmeli")
	if soundtrack_list and music_player:
		var second_track_button := soundtrack_list.get_child(1) as Button
		second_track_button.pressed.emit()
		await process_frame
		_expect(music_player.current_track_index == 1, "Listeden seçilen soundtrack çalmalı")
		var next_track_button := menu.find_child("NextTrackButton", true, false) as Button
		next_track_button.pressed.emit()
		_expect(music_player.current_track_index == 2, "Soundtrack sayfası sonraki parçaya geçmeli")
		var previous_track_button := menu.find_child("PreviousTrackButton", true, false) as Button
		previous_track_button.pressed.emit()
		_expect(music_player.current_track_index == 1, "Soundtrack sayfası önceki parçaya dönmeli")
		var play_pause_button := menu.find_child("PlayPauseTrackButton", true, false) as Button
		play_pause_button.pressed.emit()
		_expect(music_player.stream_paused, "Soundtrack sayfası müziği duraklatabilmeli")
		await process_frame
		var mini_play_pause := menu.find_child("MiniPlayPauseButton", true, false) as Button
		_expect(mini_play_pause != null and mini_play_pause.text == "▶", "Duraklatılmış müzikte mini oynat düğmesi oynat simgesi göstermeli")
		play_pause_button.pressed.emit()
		_expect(not music_player.stream_paused, "Soundtrack sayfası müziği sürdürebilmeli")
		menu.call("_sync_music_playback_with_volume", 0.0)
		await process_frame
		_expect(not music_player.playing, "Müzik ayarı %0 olduğunda şarkı durmalı")
		_expect(mini_play_pause != null and mini_play_pause.disabled, "Mini oynat düğmesi müzik %0 iken devre dışı olmalı")
		mini_play_pause.pressed.emit()
		_expect(not music_player.playing, "Mini oynat düğmesi müzik %0 iken şarkıyı başlatmamalı")
		menu.call("_sync_music_playback_with_volume", 70.0)
		await process_frame
		_expect(music_player.is_playback_active(), "Müzik sesi yeniden açıldığında şarkı devam etmeli")
	await create_timer(0.10).timeout
	_capture("/tmp/tdm_soundtrack.png")
	menu.call("_hide_soundtrack")
	menu.call("_show_settings")
	await create_timer(0.22).timeout
	var settings_overlay := menu.find_child("SettingsOverlay", true, false) as Control
	var settings_panel := menu.find_child("SettingsPanel", true, false) as Control
	var settings_title := menu.find_child("SettingsTitle", true, false) as Label
	_expect(settings_overlay != null and settings_overlay.visible, "Ayarlar açılmadı")
	_expect(_is_horizontally_centered(settings_title, settings_panel), "Ayarlar başlığı pencerenin ortasında olmalı")
	_capture("/tmp/tdm_settings.png")
	if settings_tabs:
		settings_tabs.current_tab = 1
		await create_timer(0.05).timeout
		_capture("/tmp/tdm_settings_audio.png")
		settings_tabs.current_tab = 2
		await create_timer(0.05).timeout
		_capture("/tmp/tdm_settings_gameplay.png")

	menu.call("_hide_settings")
	menu.call("_show_quit_confirmation")
	await create_timer(0.20).timeout
	var quit_overlay := menu.find_child("QuitOverlay", true, false) as Control
	var quit_panel := menu.find_child("QuitPanel", true, false) as Control
	var quit_title := menu.find_child("QuitTitle", true, false) as Label
	var quit_eyebrow := menu.find_child("QuitEyebrow", true, false) as Label
	_expect(quit_overlay != null and quit_overlay.visible, "Çıkış penceresi açılmadı")
	_expect(_is_horizontally_centered(quit_title, quit_panel), "Çıkış başlığı pencerenin ortasında olmalı")
	_expect(
		quit_eyebrow != null and quit_eyebrow.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"Çıkış üst etiketi ortalanmalı"
	)
	_capture("/tmp/tdm_quit.png")
	menu.call("_hide_quit_confirmation")
	menu.call("_show_difficulty_selection")
	await create_timer(0.22).timeout
	var difficulty_overlay := menu.find_child("DifficultyOverlay", true, false) as Control
	var difficulty_panel := menu.find_child("DifficultyPanel", true, false) as Control
	var difficulty_title := menu.find_child("DifficultyTitle", true, false) as Label
	var difficulty_eyebrow := menu.find_child("DifficultyEyebrow", true, false) as Label
	_expect(difficulty_overlay != null and difficulty_overlay.visible, "Başla zorluk seçimini açmadı")
	_expect(_is_horizontally_centered(difficulty_title, difficulty_panel), "Zorluk başlığı pencerenin ortasında olmalı")
	_expect(menu.find_child("DifficultySubtitle", true, false) == null, "Zorluk başlığı altındaki açıklama kaldırılmalı")
	_expect(
		difficulty_eyebrow != null and difficulty_eyebrow.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"Oyun ayarları üst etiketi ortalanmalı"
	)
	_expect(menu.find_child("GameSetupForm", true, false) is VBoxContainer, "Oyun ayarları tek formda bulunmalı")
	for row_name in ["GameNameConfigRow", "CardPoolConfigRow", "TurnDurationConfigRow", "DifficultyConfigRow"]:
		var config_row := menu.find_child(row_name, true, false) as Control
		_expect(config_row != null and config_row.visible, "%s aynı formda görünmeli" % row_name)
	_expect(menu.find_child("GameSetupProgress", true, false) == null, "Aşama göstergesi kaldırılmalı")
	_expect(menu.find_child("GameSetupNextButton", true, false) == null, "İleri düğmesi kaldırılmalı")
	_expect(menu.find_child("GameSetupBackButton", true, false) == null, "Geri düğmesi kaldırılmalı")
	var configured_start_button := menu.find_child("StartConfiguredGameButton", true, false) as Button
	_expect(configured_start_button != null and configured_start_button.visible, "Oyunu Başlat formun altında görünmeli")
	_expect(menu.find_child("EasyDifficultyButton", true, false) is Button, "Kolay AI seçeneği bulunamadı")
	_expect(menu.find_child("MediumDifficultyButton", true, false) is Button, "Orta AI seçeneği bulunamadı")
	_expect(menu.find_child("HardDifficultyButton", true, false) is Button, "Zor AI seçeneği bulunamadı")
	var deck_pool_button := menu.find_child("DeckCardPoolButton", true, false) as Button
	var all_cards_pool_button := menu.find_child("AllCardsPoolButton", true, false) as Button
	var card_pool_description := menu.find_child("CardPoolModeDescription", true, false) as Label
	var active_deck_label := menu.find_child("DifficultyActiveDeck", true, false) as Label
	_expect(deck_pool_button != null and deck_pool_button.button_pressed, "Kart kaynağı varsayılan olarak etkin deste olmalı")
	_expect(all_cards_pool_button != null and not all_cards_pool_button.button_pressed, "Tüm Kartlar seçeneği başlangıçta kapalı olmalı")
	menu.call("_set_card_pool_mode", MatchSetup.CardPoolMode.ALL_CARDS)
	await create_timer(0.10).timeout
	# The headless renderer never emits frame_post_draw. Waiting for it here left
	# the smoke test open forever even though the menu itself was healthy. A
	# forced draw also avoids a missed one-shot signal on a static GUI frame.
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
	_expect(all_cards_pool_button != null and all_cards_pool_button.button_pressed, "Başlangıçta Tüm Kartlar seçilebilmeli")
	_expect(deck_pool_button != null and not deck_pool_button.button_pressed, "Tüm Kartlar seçilince etkin deste seçimi kapanmalı")
	var playable_card_count := CardDatabase.get_playable_card_refs().size()
	_expect(
		card_pool_description != null
		and card_pool_description.text == tr("Both sides start with all %d playable cards; each card order is shuffled separately.") % playable_card_count,
		"Tüm Kartlar modu eksiksiz havuzu açıklamalı"
	)
	_expect(
		active_deck_label != null
		and active_deck_label.text == tr("ALL CARDS  •  %d CARDS IN MATCH") % playable_card_count,
		"Seçilen kart kaynağı zorluk ekranında görünmeli"
	)
	for difficulty_name in ["Easy", "Medium", "Hard"]:
		var difficulty_emblem := menu.find_child("%sDifficultyEmblem" % difficulty_name, true, false)
		var difficulty_name_label := menu.find_child("%sDifficultyTitle" % difficulty_name, true, false) as Label
		var difficulty_description := menu.find_child("%sDifficultyDescription" % difficulty_name, true, false) as Label
		_expect(
			difficulty_emblem != null and difficulty_emblem.get_script() == DIFFICULTY_EMBLEM_SCRIPT,
			"%s zorluk amblemi bulunmalı" % difficulty_name
		)
		_expect(
			difficulty_name_label != null and difficulty_name_label.get_theme_font("font") == UI.BODY_BOLD_FONT,
			"%s zorluk adı kalın yazı tipini kullanmalı" % difficulty_name
		)
		_expect(
			difficulty_description != null and difficulty_description.get_theme_font_size("font_size") < difficulty_name_label.get_theme_font_size("font_size"),
			"%s zorluk açıklaması adından daha küçük olmalı" % difficulty_name
		)
	_expect(not _tree_contains_exact_text(difficulty_overlay, "01"), "Kolay seçeneğinde 01 numarası kalmamalı")
	_expect(not _tree_contains_exact_text(difficulty_overlay, "02"), "Orta seçeneğinde 02 numarası kalmamalı")
	_expect(not _tree_contains_exact_text(difficulty_overlay, "03"), "Zor seçeneğinde 03 numarası kalmamalı")
	_expect(
		not _tree_contains_text(difficulty_overlay, "Seçimin yalnızca yapay zekânın karar kalitesini"),
		"Zorluk seçim ekranının en altındaki ipucu kaldırılmalı"
	)
	_capture("/tmp/tdm_difficulty_all_cards.png")
	menu.call("_start_game", MatchSetup.AIDifficulty.MEDIUM)
	var transition_timeout := 3.5
	while current_scene != null and current_scene.name != "Battlefield" and transition_timeout > 0.0:
		await create_timer(0.05).timeout
		transition_timeout -= 0.05
	_expect(current_scene != null and current_scene.name == "Battlefield", "Başla düğmesi savaş sahnesine geçmedi")
	_expect(MatchSetup.uses_all_cards(), "Başlangıçtaki Tüm Kartlar seçimi maç yapılandırmasına aktarılmalı")
	_expect(MatchSetup.get_player_deck_name(1) == "Tüm Kartlar", "Tüm Kartlar modu maç geçmişine doğru adla aktarılmalı")
	_finish()


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(false)
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("Görsel yakalanamadı: %s" % path)
		return
	var save_error := image.save_png(path)
	_expect(save_error == OK, "Görsel kaydedilemedi: %s" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _is_horizontally_centered(control: Control, container: Control, tolerance := 1.5) -> bool:
	if control == null or container == null:
		return false
	return absf(control.get_global_rect().get_center().x - container.get_global_rect().get_center().x) <= tolerance


func _tree_contains_text(node: Node, needle: String) -> bool:
	if node is Label and needle in (node as Label).text:
		return true
	if node is Button and needle in (node as Button).text:
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false


func _tree_contains_exact_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text == expected:
		return true
	if node is Button and (node as Button).text == expected:
		return true
	for child in node.get_children():
		if _tree_contains_exact_text(child, expected):
			return true
	return false


func _count_cards_with_rarity(rarity_key: String, card_type: String = "") -> int:
	var count := 0
	var types := TYPE_ORDER if card_type.is_empty() else [card_type]
	for type_key in types:
		for card_data in CardDatabase.get_cards_for_type(type_key):
			if _is_gallery_card(card_data) and str(card_data.get("rarity", "COMMON")).to_upper() == rarity_key:
				count += 1
	return count


func _count_gallery_cards_for_type(card_type: String) -> int:
	var count := 0
	for card_data in CardDatabase.get_cards_for_type(card_type):
		if _is_gallery_card(card_data):
			count += 1
	return count


func _is_gallery_card(card_data: Dictionary) -> bool:
	if bool(card_data.get("is_hq", false)):
		return false
	var role := str(card_data.get("role", "")).to_lower()
	if role == "hq" or role == "headquarters":
		return false
	return not str(card_data.get("id", "")).to_lower().contains("merkez")


func _finish() -> void:
	if _failures.is_empty():
		print("MAIN_MENU_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("MAIN_MENU_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
