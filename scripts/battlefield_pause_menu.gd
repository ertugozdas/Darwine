class_name BattlefieldPauseMenu extends Control

signal resume_requested
signal save_requested
signal load_requested
signal rules_requested
signal leave_match_requested

const SETTINGS_PATH := "user://settings.cfg"
const UI := preload("res://scripts/dark_fantasy_ui.gd")
const SETTINGS_MANAGER_SCRIPT := preload("res://scripts/settings_manager.gd")
const GOLD := UI.BRASS
const GOLD_BRIGHT := UI.BRASS_BRIGHT
const CREAM := UI.PARCHMENT
const MUTED := UI.TEXT_MUTED
const DANGER := UI.BLOOD

var _panel: PanelContainer = null
var _home_view: VBoxContainer = null
var _settings_view: VBoxContainer = null
var _leave_view: VBoxContainer = null
var _continue_button: Button = null
var _save_button: Button = null
var _load_button: Button = null
var _volume_slider: HSlider = null
var _volume_value_label: Label = null
var _fullscreen_toggle: CheckButton = null
var _settings_are_loading := false
var _settings_manager: Variant = null


func _ready() -> void:
	_settings_manager = _resolve_settings_manager()
	name = "PauseMenu"
	theme = UI.create_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 950
	_build_ui()
	resized.connect(_layout_panel)
	visibility_changed.connect(_on_visibility_changed)
	visible = false


func _resolve_settings_manager() -> Variant:
	var existing := get_node_or_null("/root/SettingsManager")
	if existing:
		return existing
	var fallback := SETTINGS_MANAGER_SCRIPT.new()
	fallback.name = "SettingsManager"
	get_tree().root.add_child(fallback)
	return fallback


func open_menu() -> void:
	_show_home()
	visible = true
	_layout_panel()
	modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(self, "modulate:a", 1.0, 0.14)
	if _continue_button:
		_continue_button.grab_focus()


func close_menu() -> void:
	visible = false


func is_open() -> bool:
	return visible


func set_save_available(available: bool) -> void:
	if _save_button:
		_save_button.visible = available
		_save_button.disabled = not available
	if _load_button:
		_load_button.visible = available
		_load_button.disabled = not available


func show_home() -> void:
	_show_home()
	visible = true
	if _continue_button:
		_continue_button.grab_focus()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.006, 0.007, 0.009, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "PausePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	_panel.add_child(margin)

	var surface := Control.new()
	surface.name = "Surface"
	surface.custom_minimum_size = Vector2(420.0, 560.0)
	margin.add_child(surface)

	_home_view = VBoxContainer.new()
	_home_view.name = "PauseHome"
	_home_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home_view.add_theme_constant_override("separation", 10)
	surface.add_child(_home_view)
	_build_home_view()

	_settings_view = VBoxContainer.new()
	_settings_view.name = "SettingsView"
	_settings_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_view.add_theme_constant_override("separation", 15)
	surface.add_child(_settings_view)
	_build_settings_view()

	_leave_view = VBoxContainer.new()
	_leave_view.name = "LeaveView"
	_leave_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_leave_view.add_theme_constant_override("separation", 16)
	surface.add_child(_leave_view)
	_build_leave_view()


func _build_home_view() -> void:
	var eyebrow := _make_label("OYUN DURAKLATILDI", 12, GOLD_BRIGHT)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_view.add_child(eyebrow)

	var title := _make_label("KUŞATMA BEKLİYOR", 29, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	_home_view.add_child(title)

	var subtitle := _make_label("ESC", 11, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_view.add_child(subtitle)

	_home_view.add_child(_make_rule())

	_continue_button = _make_menu_button("ContinueButton", "DEVAM ET", GOLD)
	_continue_button.pressed.connect(func(): resume_requested.emit())
	_home_view.add_child(_continue_button)

	_save_button = _make_menu_button("SaveGameButton", "KAYDET", Color(0.34, 0.66, 0.56))
	_save_button.pressed.connect(func(): save_requested.emit())
	_home_view.add_child(_save_button)

	_load_button = _make_menu_button("LoadGameButton", "YÜKLE", Color(0.30, 0.58, 0.80))
	_load_button.pressed.connect(func(): load_requested.emit())
	_home_view.add_child(_load_button)

	var rules_button := _make_menu_button("RulesButton", "KURALLAR", Color(0.42, 0.57, 0.66))
	rules_button.pressed.connect(_on_rules_pressed)
	_home_view.add_child(rules_button)

	var settings_button := _make_menu_button("SettingsButton", "AYARLAR", Color(0.52, 0.50, 0.45))
	settings_button.pressed.connect(_show_settings)
	_home_view.add_child(settings_button)

	var leave_button := _make_menu_button("LeaveGameButton", "OYUNU TERK ET", DANGER, true)
	leave_button.pressed.connect(_show_leave_confirmation)
	_home_view.add_child(leave_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home_view.add_child(spacer)

	var hint := _make_label("Devam etmek için ESC", 11, Color(0.48, 0.47, 0.44))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_view.add_child(hint)


func _build_settings_view() -> void:
	var eyebrow := _make_label("DURAKLATMA MENÜSÜ", 12, GOLD_BRIGHT)
	_settings_view.add_child(eyebrow)
	_settings_view.add_child(_make_label("AYARLAR", 28, CREAM))
	_settings_view.add_child(_make_rule())

	var volume_row := HBoxContainer.new()
	_settings_view.add_child(volume_row)
	var volume_label := _make_label("Ana Ses", 16, CREAM)
	volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_row.add_child(volume_label)
	_volume_value_label = _make_label("80%", 14, GOLD_BRIGHT)
	_volume_value_label.name = "VolumeValue"
	volume_row.add_child(_volume_value_label)

	_volume_slider = HSlider.new()
	_volume_slider.name = "MasterVolumeSlider"
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.value = 80.0
	_volume_slider.custom_minimum_size.y = 38.0
	_volume_slider.value_changed.connect(_on_volume_changed)
	_style_slider(_volume_slider)
	_settings_view.add_child(_volume_slider)
	_settings_view.add_child(_make_label("Müzik ve efektlerin genel seviyesi.", 12, MUTED))

	_settings_view.add_child(_make_rule())

	var fullscreen_row := HBoxContainer.new()
	fullscreen_row.add_theme_constant_override("separation", 18)
	_settings_view.add_child(fullscreen_row)
	var fullscreen_copy := VBoxContainer.new()
	fullscreen_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen_row.add_child(fullscreen_copy)
	fullscreen_copy.add_child(_make_label("Tam Ekran", 16, CREAM))
	fullscreen_copy.add_child(_make_label("Oyunu masaüstünü kaplayacak şekilde gösterir.", 12, MUTED))

	_fullscreen_toggle = CheckButton.new()
	_fullscreen_toggle.name = "FullscreenToggle"
	_fullscreen_toggle.text = "Açık"
	_fullscreen_toggle.add_theme_font_size_override("font_size", 14)
	_fullscreen_toggle.add_theme_color_override("font_color", MUTED)
	_fullscreen_toggle.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	fullscreen_row.add_child(_fullscreen_toggle)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_view.add_child(spacer)

	var back_button := _make_menu_button("SettingsBackButton", "GERİ", GOLD)
	back_button.pressed.connect(_show_home)
	_settings_view.add_child(back_button)


func _build_leave_view() -> void:
	var eyebrow := _make_label("MAÇTAN AYRIL", 12, Color(0.92, 0.47, 0.38))
	_leave_view.add_child(eyebrow)
	_leave_view.add_child(_make_label("KUŞATMAYI TERK ET?", 28, CREAM))
	_leave_view.add_child(_make_rule())

	var copy := _make_label(
		"Mevcut maç sona erecek ve ana menüye döneceksin.",
		16,
		Color(0.78, 0.76, 0.71)
	)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size.y = 90.0
	copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_leave_view.add_child(copy)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_leave_view.add_child(spacer)

	var cancel_button := _make_menu_button("LeaveCancelButton", "VAZGEÇ", Color(0.48, 0.47, 0.44))
	cancel_button.pressed.connect(_show_home)
	_leave_view.add_child(cancel_button)

	var confirm_button := _make_menu_button("LeaveConfirmButton", "ANA MENÜYE DÖN", DANGER, true)
	confirm_button.pressed.connect(func(): leave_match_requested.emit())
	_leave_view.add_child(confirm_button)


func _show_home() -> void:
	_home_view.visible = true
	_settings_view.visible = false
	_leave_view.visible = false
	if visible and _continue_button:
		_continue_button.grab_focus()


func _show_settings() -> void:
	_load_settings()
	_home_view.visible = false
	_settings_view.visible = true
	_leave_view.visible = false
	if _volume_slider:
		_volume_slider.grab_focus()


func _show_leave_confirmation() -> void:
	_home_view.visible = false
	_settings_view.visible = false
	_leave_view.visible = true
	var cancel_button := _leave_view.get_node_or_null("LeaveCancelButton") as Button
	if cancel_button:
		cancel_button.grab_focus()


func _on_rules_pressed() -> void:
	visible = false
	rules_requested.emit()


func _on_visibility_changed() -> void:
	set_process_unhandled_input(visible)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if _settings_view.visible or _leave_view.visible:
		_show_home()
	else:
		resume_requested.emit()
	get_viewport().set_input_as_handled()


func _layout_panel() -> void:
	if not _panel:
		return
	var panel_size := Vector2(
		minf(520.0, maxf(320.0, size.x - 32.0)),
		minf(650.0, maxf(520.0, size.y - 32.0))
	)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -panel_size.x * 0.5
	_panel.offset_top = -panel_size.y * 0.5
	_panel.offset_right = panel_size.x * 0.5
	_panel.offset_bottom = panel_size.y * 0.5


func _load_settings() -> void:
	_settings_are_loading = true
	_volume_slider.value = _settings_manager.master_volume
	_fullscreen_toggle.button_pressed = _settings_manager.fullscreen
	_volume_value_label.text = "%d%%" % int(round(_volume_slider.value))
	_fullscreen_toggle.text = "Açık" if _settings_manager.fullscreen else "Kapalı"
	_settings_are_loading = false


func _on_volume_changed(value: float) -> void:
	if _volume_value_label:
		_volume_value_label.text = "%d%%" % int(round(value))
	if not _settings_are_loading:
		_settings_manager.set_master_volume(value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	if _fullscreen_toggle:
		_fullscreen_toggle.text = "Açık" if enabled else "Kapalı"
	if not _settings_are_loading:
		_settings_manager.set_fullscreen(enabled)


func _apply_master_volume(percent: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	var normalized := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(normalized, 0.001)))


func _save_settings() -> void:
	_settings_manager.save_settings()


func _make_panel_style() -> StyleBoxTexture:
	return UI.panel_style(GOLD, 12.0, 1.0)


func _make_rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1.0
	rule.color = Color(GOLD, 0.34)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size >= 20 or text_value == text_value.to_upper():
		UI.style_title(label, color)
	return label


func _make_menu_button(node_name: String, text_value: String, accent: Color, destructive := false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 54.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)
	UI.style_button(button, accent, destructive, false, node_name == "ContinueButton")
	return button


func _style_slider(slider: HSlider) -> void:
	var track := UI.inset_style(Color(0.018, 0.018, 0.018, 0.95), GOLD, 3)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var fill := UI.inset_style(Color(GOLD, 0.72), GOLD_BRIGHT, 3)
	fill.content_margin_top = 3.0
	fill.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", UI.inset_style(Color(GOLD_BRIGHT, 0.88), GOLD_BRIGHT, 3))
