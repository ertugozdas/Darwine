class_name SaveSlotsPanel extends Control

signal closed
signal save_requested(slot_name: String, slot_id: String)
signal load_requested(slot_id: String)
signal delete_requested(slot_id: String)

const UI := preload("res://scripts/dark_fantasy_ui.gd")
const GOLD := UI.BRASS
const GOLD_BRIGHT := UI.BRASS_BRIGHT
const CREAM := UI.PARCHMENT
const MUTED := UI.TEXT_MUTED
const DANGER := UI.BLOOD

var _panel: PanelContainer
var _eyebrow_label: Label
var _title_label: Label
var _name_section: VBoxContainer
var _slot_name_input: LineEdit
var _slot_list: VBoxContainer
var _empty_label: Label
var _status_label: Label
var _new_slot_button: Button
var _save_button: Button
var _load_button: Button
var _delete_button: Button
var _slot_buttons: Dictionary = {}
var _slots: Array[Dictionary] = []
var _selected_slot_id := ""
var _selected_slot_name := ""
var _suggested_name := "Yeni Kayıt"
var _allow_save := false
var _editing_selection := false


func _ready() -> void:
	theme = UI.create_theme()
	name = "SaveSlotsOverlay"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 980
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	resized.connect(_layout_panel)
	visible = false
	_layout_panel()


func open_panel(
	slots: Array[Dictionary],
	current_slot_id := "",
	suggested_name := "Yeni Kayıt",
	allow_save := false,
	start_with_name_field := false
) -> void:
	_allow_save = allow_save
	_suggested_name = _sanitize_display_name(suggested_name)
	if _suggested_name.is_empty():
		_suggested_name = tr("Yeni Kayıt")
	_name_section.visible = _allow_save
	_new_slot_button.visible = _allow_save
	_save_button.visible = _allow_save
	_eyebrow_label.text = tr("DARWINE  •  KAYIT ARŞİVİ")
	_title_label.text = tr("KAYDET  /  YÜKLE") if _allow_save else tr("KAYIT YÜKLE")
	_status_label.text = tr("Bir slot seç veya yeni bir kayıt adı oluştur.") if _allow_save else tr("Devam etmek istediğin savaş kaydını seç.")
	_status_label.add_theme_color_override("font_color", MUTED)
	set_slots(slots, current_slot_id)
	visible = true
	modulate.a = 1.0
	if _allow_save and start_with_name_field:
		_begin_new_slot()
	else:
		_focus_selected_or_first()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func set_slots(slots: Array[Dictionary], preferred_slot_id := "") -> void:
	_slots.clear()
	for slot_variant in slots:
		if slot_variant is Dictionary:
			_slots.append((slot_variant as Dictionary).duplicate(true))
	var requested_id := preferred_slot_id if not preferred_slot_id.is_empty() else _selected_slot_id
	_rebuild_slot_list()
	if not requested_id.is_empty() and _has_slot(requested_id):
		_select_slot(requested_id)
	elif not _slots.is_empty():
		_select_slot(str(_slots[0].get("slot_id", "")))
	else:
		_selected_slot_id = ""
		_selected_slot_name = ""
		_update_actions()


func set_status(message: String, is_error := false) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override(
		"font_color",
		Color(0.96, 0.48, 0.36) if is_error else Color(0.50, 0.86, 0.66)
	)


func get_slot_count() -> int:
	return _slots.size()


func get_selected_slot_id() -> String:
	return _selected_slot_id


func get_slot_name_input() -> LineEdit:
	return _slot_name_input


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "SaveSlotsDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.003, 0.004, 0.007, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "SaveSlotsPanel"
	_panel.add_theme_stylebox_override("panel", UI.panel_style(GOLD, 18.0, 1.0))
	add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_panel.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 48.0
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	var seal := Label.new()
	seal.custom_minimum_size.x = 46.0
	seal.text = "◆"
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_theme_font_size_override("font_size", 18)
	seal.add_theme_color_override("font_color", Color(GOLD, 0.76))
	header.add_child(seal)
	var header_copy := VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.add_theme_constant_override("separation", 1)
	header.add_child(header_copy)
	_eyebrow_label = _make_label("DARWINE  •  KAYIT ARŞİVİ", 10, GOLD_BRIGHT)
	_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_copy.add_child(_eyebrow_label)
	_title_label = _make_label("KAYIT YÜKLE", 27, CREAM, true)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_copy.add_child(_title_label)
	var close_button := _make_button("SaveSlotsCloseButton", "×", GOLD, true)
	close_button.custom_minimum_size = Vector2(46.0, 44.0)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)

	content.add_child(_make_rule(Color(GOLD, 0.48)))

	_name_section = VBoxContainer.new()
	_name_section.name = "SaveSlotNameSection"
	_name_section.add_theme_constant_override("separation", 5)
	content.add_child(_name_section)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	_name_section.add_child(name_row)
	var name_copy := VBoxContainer.new()
	name_copy.custom_minimum_size.x = 150.0
	name_row.add_child(name_copy)
	name_copy.add_child(_make_label("SLOT ADI", 13, GOLD_BRIGHT, true))
	name_copy.add_child(_make_label("Yeni ad yeni slot açar.", 11, MUTED))
	_slot_name_input = LineEdit.new()
	_slot_name_input.name = "SaveSlotNameInput"
	_slot_name_input.placeholder_text = "Örn. Kuzey Kapısı"
	_slot_name_input.max_length = 40
	_slot_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_name_input.custom_minimum_size.y = 46.0
	_slot_name_input.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
	_slot_name_input.add_theme_font_size_override("font_size", 16)
	_slot_name_input.add_theme_color_override("font_color", CREAM)
	_slot_name_input.add_theme_color_override("font_placeholder_color", Color(MUTED, 0.62))
	_slot_name_input.add_theme_stylebox_override("normal", UI.inset_style(Color(0.018, 0.020, 0.024, 0.98), GOLD, 4))
	_slot_name_input.add_theme_stylebox_override("focus", UI.focus_style(GOLD, true))
	_slot_name_input.text_changed.connect(_on_slot_name_changed)
	_slot_name_input.text_submitted.connect(func(_value: String): _on_save_pressed())
	name_row.add_child(_slot_name_input)
	_new_slot_button = _make_button("NewSaveSlotButton", "YENİ SLOT", Color(0.38, 0.58, 0.68), true)
	_new_slot_button.custom_minimum_size.x = 132.0
	_new_slot_button.pressed.connect(_begin_new_slot)
	name_row.add_child(_new_slot_button)

	var list_header := HBoxContainer.new()
	content.add_child(list_header)
	list_header.add_child(_make_label("KAYIT SLOTLARI", 12, GOLD_BRIGHT, true))
	var list_spacer := Control.new()
	list_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_header.add_child(list_spacer)
	var backup_note := _make_label("Her slot için 3 güvenli yedek", 11, MUTED)
	backup_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	list_header.add_child(backup_note)

	var scroll := ScrollContainer.new()
	scroll.name = "SaveSlotsScroll"
	scroll.custom_minimum_size.y = 170.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_slot_list = VBoxContainer.new()
	_slot_list.name = "SaveSlotList"
	_slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_slot_list)

	_status_label = _make_label("Bir slot seç.", 12, MUTED)
	_status_label.name = "SaveSlotsStatus"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.y = 22.0
	content.add_child(_status_label)
	content.add_child(_make_rule(Color(GOLD, 0.28)))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	_delete_button = _make_button("DeleteSaveSlotButton", "SİL", DANGER, true, true)
	_delete_button.pressed.connect(_on_delete_pressed)
	actions.add_child(_delete_button)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	var cancel_button := _make_button("CancelSaveSlotsButton", "VAZGEÇ", Color(0.46, 0.45, 0.42), true)
	cancel_button.pressed.connect(close_panel)
	actions.add_child(cancel_button)
	_save_button = _make_button("SaveToSlotButton", "KAYDET", Color(0.34, 0.68, 0.54), false)
	_save_button.pressed.connect(_on_save_pressed)
	actions.add_child(_save_button)
	_load_button = _make_button("LoadSaveSlotButton", "YÜKLE", Color(0.30, 0.58, 0.80), false)
	_load_button.pressed.connect(_on_load_pressed)
	actions.add_child(_load_button)


func _rebuild_slot_list() -> void:
	for child in _slot_list.get_children():
		_slot_list.remove_child(child)
		child.queue_free()
	_slot_buttons.clear()
	if _slots.is_empty():
		var empty_panel := PanelContainer.new()
		empty_panel.name = "EmptySaveSlots"
		empty_panel.custom_minimum_size.y = 145.0
		empty_panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.020, 0.022, 0.027, 0.92), Color(GOLD, 0.28), 4))
		_slot_list.add_child(empty_panel)
		_empty_label = _make_label(
			"%s\n%s" % [
				tr("Henüz kayıt slotu yok."),
				tr("Oyunu başlatıp ilk slotunu oluşturabilirsin."),
			],
			14,
			MUTED
		)
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_panel.add_child(_empty_label)
		return

	for slot in _slots:
		var slot_id := str(slot.get("slot_id", ""))
		if slot_id.is_empty():
			continue
		var button := Button.new()
		button.name = "SaveSlot_%s" % slot_id
		button.text = _format_slot_text(slot)
		button.tooltip_text = tr("Bu kayıt slotunu seç")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 66.0
		button.clip_text = true
		button.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_select_slot.bind(slot_id))
		_slot_list.add_child(button)
		_slot_buttons[slot_id] = button
		_style_slot_button(button, false, str(slot.get("state", "missing")))


func _select_slot(slot_id: String) -> void:
	var slot := _slot_by_id(slot_id)
	if slot.is_empty():
		return
	_selected_slot_id = slot_id
	_selected_slot_name = str(slot.get("slot_name", "Kayıt"))
	if _allow_save:
		_editing_selection = true
		_slot_name_input.text = _selected_slot_name
		_slot_name_input.caret_column = _slot_name_input.text.length()
		_editing_selection = false
	for button_id in _slot_buttons:
		var button := _slot_buttons[button_id] as Button
		var row := _slot_by_id(str(button_id))
		_style_slot_button(button, str(button_id) == _selected_slot_id, str(row.get("state", "missing")))
	_update_actions()


func _begin_new_slot() -> void:
	if not _allow_save:
		return
	_selected_slot_id = ""
	_selected_slot_name = ""
	_editing_selection = true
	_slot_name_input.text = _suggested_name
	_editing_selection = false
	for button_id in _slot_buttons:
		var row := _slot_by_id(str(button_id))
		_style_slot_button(_slot_buttons[button_id] as Button, false, str(row.get("state", "missing")))
	_update_actions()
	_slot_name_input.grab_focus()
	_slot_name_input.select_all()


func _on_slot_name_changed(value: String) -> void:
	if _editing_selection:
		return
	if not _selected_slot_id.is_empty() and _sanitize_display_name(value) != _selected_slot_name:
		_selected_slot_id = ""
		for button_id in _slot_buttons:
			var row := _slot_by_id(str(button_id))
			_style_slot_button(_slot_buttons[button_id] as Button, false, str(row.get("state", "missing")))
	_update_actions()


func _on_save_pressed() -> void:
	if not _allow_save:
		return
	var slot_name := _sanitize_display_name(_slot_name_input.text)
	if slot_name.is_empty():
		set_status(tr("Kaydetmek için bir slot adı gir."), true)
		_slot_name_input.grab_focus()
		return
	save_requested.emit(slot_name, _selected_slot_id)


func _on_load_pressed() -> void:
	if _selected_slot_id.is_empty():
		set_status(tr("Yüklemek için bir kayıt slotu seç."), true)
		return
	load_requested.emit(_selected_slot_id)


func _on_delete_pressed() -> void:
	if _selected_slot_id.is_empty():
		return
	delete_requested.emit(_selected_slot_id)


func _update_actions() -> void:
	_load_button.disabled = _selected_slot_id.is_empty()
	_delete_button.disabled = _selected_slot_id.is_empty()
	_save_button.disabled = not _allow_save or _sanitize_display_name(_slot_name_input.text).is_empty()


func _focus_selected_or_first() -> void:
	if not _selected_slot_id.is_empty() and _slot_buttons.has(_selected_slot_id):
		(_slot_buttons[_selected_slot_id] as Button).grab_focus()
	elif not _slot_buttons.is_empty():
		(_slot_buttons.values()[0] as Button).grab_focus()
	else:
		_load_button.grab_focus()


func _format_slot_text(slot: Dictionary) -> String:
	var state := str(slot.get("state", "missing"))
	var slot_name := str(slot.get("slot_name", tr("İsimsiz Kayıt")))
	var state_mark := "  ⚠ %s" % tr("KURTARMA GEREKİYOR") if state != "valid" else ""
	var ruleset_name := tr("HAKİMİYET") if int(slot.get("ruleset", 0)) == MatchSetup.Ruleset.DOMINION else tr("KUŞATMA")
	var round_count := maxi(1, int(slot.get("round_count", 1)))
	var turn_count := maxi(1, int(slot.get("turn_count", 1)))
	var saved_at := str(slot.get("saved_at_utc", tr("Tarih bilinmiyor"))).replace("T", "  •  ")
	return "%s%s\n%s  •  %s %d  •  %s %d  •  %s" % [
		slot_name,
		state_mark,
		ruleset_name,
		tr("RAUND"),
		round_count,
		tr("TUR"),
		turn_count,
		saved_at,
	]


func _style_slot_button(button: Button, selected: bool, state: String) -> void:
	if not button:
		return
	var accent := Color(0.86, 0.40, 0.27) if state != "valid" else (GOLD_BRIGHT if selected else Color(0.46, 0.55, 0.62))
	UI.style_button(button, accent, false, true, selected)
	button.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
	button.add_theme_color_override("font_color", CREAM)


func _slot_by_id(slot_id: String) -> Dictionary:
	for slot in _slots:
		if str(slot.get("slot_id", "")) == slot_id:
			return slot
	return {}


func _has_slot(slot_id: String) -> bool:
	return not _slot_by_id(slot_id).is_empty()


func _sanitize_display_name(value: String) -> String:
	return value.replace("\n", " ").replace("\r", " ").strip_edges().left(40)


func _make_label(text_value: String, font_size: int, color: Color, title := false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if title:
		UI.style_title(label, color)
	return label


func _make_button(node_name: String, text_value: String, accent: Color, compact := false, destructive := false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(120.0, 46.0)
	button.add_theme_font_size_override("font_size", 14)
	UI.style_button(button, accent, destructive, compact, not compact)
	return button


func _make_rule(color_value: Color) -> HSeparator:
	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", UI.line_style(color_value, 1))
	return rule


func _layout_panel() -> void:
	if not _panel:
		return
	var panel_size := Vector2(
		minf(820.0, maxf(620.0, size.x - 40.0)),
		minf(590.0, maxf(520.0, size.y - 56.0))
	)
	_panel.position = (size - panel_size) * 0.5
	_panel.size = panel_size
