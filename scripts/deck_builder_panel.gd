class_name DeckBuilderPanel extends Control

signal closed

const UI := preload("res://scripts/dark_fantasy_ui.gd")
const TYPE_ORDER := ["heroes", "settlements", "special_powers", "upgrades"]
const TYPE_LABELS := {
	"all": "Tüm Kartlar",
	"heroes": "Kahraman",
	"settlements": "Yapı",
	"special_powers": "Büyü",
	"upgrades": "Beceri",
}
const TYPE_COLORS := {
	"heroes": Color(0.31, 0.57, 0.88),
	"settlements": Color(0.68, 0.43, 0.24),
	"special_powers": Color(0.62, 0.36, 0.88),
	"upgrades": Color(0.20, 0.68, 0.70),
}

var _deck_manager: Node
var _selected_deck_id := ""
var _working_cards: Array = []
var _working_name := ""
var _dirty := false

var _shell: PanelContainer
var _deck_list: VBoxContainer
var _collection_list: VBoxContainer
var _current_list: VBoxContainer
var _name_input: LineEdit
var _search_input: LineEdit
var _type_filter: OptionButton
var _stats_label: Label
var _status_label: Label
var _save_button: Button
var _activate_button: Button
var _delete_button: Button


func _ready() -> void:
	name = "DeckBuilderOverlay"
	z_index = 600
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_deck_manager = get_node_or_null("/root/DeckManager")
	_build_interface()
	if _deck_manager:
		var callback := Callable(self, "_on_repository_changed")
		if not _deck_manager.is_connected("decks_changed", callback):
			_deck_manager.connect("decks_changed", callback)


func open_panel(deck_id: String = "") -> void:
	if not _deck_manager:
		_set_status("Deste yöneticisi yüklenemedi.", true)
		visible = true
		return
	_refresh_deck_list()
	var target_id := deck_id
	if target_id.is_empty():
		target_id = str(_deck_manager.get_active_deck_id())
	_load_deck(target_id)
	visible = true
	modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	if _search_input:
		_search_input.grab_focus()


func close_panel() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func get_working_cards() -> Array:
	return _working_cards.duplicate(true)


func get_selected_deck_id() -> String:
	return _selected_deck_id


func _build_interface() -> void:
	var dim := ColorRect.new()
	dim.name = "DeckBuilderDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.005, 0.008, 0.93)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_shell = PanelContainer.new()
	_shell.name = "DeckBuilderPanel"
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shell.offset_left = 24.0
	_shell.offset_top = 20.0
	_shell.offset_right = -24.0
	_shell.offset_bottom = -20.0
	_shell.add_theme_stylebox_override("panel", UI.panel_style(UI.BRASS, 24.0, 1.0))
	add_child(_shell)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	_shell.add_child(root_box)
	root_box.add_child(_build_header())

	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", UI.line_style(Color(UI.BRASS, 0.50), 1))
	root_box.add_child(rule)

	var body := HBoxContainer.new()
	body.name = "DeckBuilderColumns"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root_box.add_child(body)
	body.add_child(_build_saved_decks_column())
	body.add_child(_build_collection_column())
	body.add_child(_build_current_deck_column())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "DeckBuilderHeader"
	header.add_theme_constant_override("separation", 14)
	var header_balance := Control.new()
	header_balance.name = "DeckBuilderHeaderBalance"
	# Balance the status copy and close button so the page heading matches other overlays.
	header_balance.custom_minimum_size.x = 368.0
	header.add_child(header_balance)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	header.add_child(copy)
	var eyebrow := Label.new()
	eyebrow.text = "KOMUTANLIK ARŞİVİ"
	eyebrow.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", UI.BRASS)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(eyebrow)
	var title := Label.new()
	title.name = "DeckBuilderTitle"
	title.text = "DESTE ATÖLYESİ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	UI.style_title(title, UI.PARCHMENT)
	copy.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "30 kart seç • Bir karttan en fazla 2 kopya kullan • Etkin desteni savaşa taşı"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", UI.TEXT_MUTED)
	copy.add_child(subtitle)

	_status_label = Label.new()
	_status_label.name = "DeckBuilderStatus"
	_status_label.custom_minimum_size = Vector2(310.0, 46.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", UI.TEXT_MUTED)
	header.add_child(_status_label)

	var close_button := Button.new()
	close_button.name = "DeckBuilderCloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(44.0, 44.0)
	close_button.add_theme_font_size_override("font_size", 24)
	UI.style_button(close_button, UI.BRASS, false, true)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)
	return header


func _build_saved_decks_column() -> Control:
	var panel := _column_panel("KAYITLI DESTELER", 218.0)
	var content := panel.get_child(0) as VBoxContainer
	var scroll := ScrollContainer.new()
	scroll.name = "SavedDeckScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_deck_list = VBoxContainer.new()
	_deck_list.name = "SavedDeckList"
	_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_deck_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	content.add_child(actions)
	var new_button := _small_button("NewDeckButton", "+ YENİ", UI.MOSS)
	new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_button.pressed.connect(_create_deck)
	actions.add_child(new_button)
	var duplicate_button := _small_button("DuplicateDeckButton", "KOPYALA", UI.FROST)
	duplicate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duplicate_button.pressed.connect(_duplicate_deck)
	actions.add_child(duplicate_button)

	_delete_button = _small_button("DeleteDeckButton", "DESTEYİ SİL", UI.BLOOD, true)
	_delete_button.pressed.connect(_delete_deck)
	content.add_child(_delete_button)
	return panel


func _build_collection_column() -> Control:
	var panel := _column_panel("KART HAVUZU", 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := panel.get_child(0) as VBoxContainer

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	content.add_child(filters)
	_search_input = LineEdit.new()
	_search_input.name = "DeckCardSearch"
	_search_input.placeholder_text = "Kart ara…"
	_search_input.clear_button_enabled = true
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.custom_minimum_size.y = 40.0
	_search_input.add_theme_font_override("font", UI.BODY_FONT)
	_search_input.add_theme_stylebox_override("normal", UI.inset_style(Color(0.018, 0.019, 0.022, 0.96), UI.BRASS))
	_search_input.add_theme_stylebox_override("focus", UI.inset_style(Color(0.026, 0.028, 0.032, 1.0), UI.BRASS_BRIGHT))
	_search_input.text_changed.connect(func(_value: String): _refresh_collection())
	filters.add_child(_search_input)
	_type_filter = OptionButton.new()
	_type_filter.name = "DeckTypeFilter"
	_type_filter.custom_minimum_size = Vector2(142.0, 40.0)
	for type_key in ["all"] + TYPE_ORDER:
		_type_filter.add_item(tr(TYPE_LABELS[type_key]))
		_type_filter.set_item_metadata(_type_filter.item_count - 1, type_key)
	_type_filter.item_selected.connect(func(_index: int): _refresh_collection())
	filters.add_child(_type_filter)

	var scroll := ScrollContainer.new()
	scroll.name = "DeckCollectionScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_collection_list = VBoxContainer.new()
	_collection_list.name = "DeckCollectionList"
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_collection_list)
	return panel


func _build_current_deck_column() -> Control:
	var panel := _column_panel("SEÇİLİ DESTE", 348.0)
	var content := panel.get_child(0) as VBoxContainer
	_name_input = LineEdit.new()
	_name_input.name = "DeckNameInput"
	_name_input.max_length = 32
	_name_input.custom_minimum_size.y = 42.0
	_name_input.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_name_input.add_theme_stylebox_override("normal", UI.inset_style(Color(0.018, 0.019, 0.022, 0.96), UI.BRASS))
	_name_input.add_theme_stylebox_override("focus", UI.inset_style(Color(0.026, 0.028, 0.032, 1.0), UI.BRASS_BRIGHT))
	_name_input.text_changed.connect(_on_name_changed)
	content.add_child(_name_input)

	_stats_label = Label.new()
	_stats_label.name = "DeckStatsLabel"
	_stats_label.custom_minimum_size.y = 38.0
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_stats_label.add_theme_font_size_override("font_size", 12)
	content.add_child(_stats_label)

	var scroll := ScrollContainer.new()
	scroll.name = "CurrentDeckScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_current_list = VBoxContainer.new()
	_current_list.name = "CurrentDeckList"
	_current_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_current_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_current_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	_save_button = _small_button("SaveDeckButton", "KAYDET", UI.BRASS)
	_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_button.pressed.connect(_save_deck)
	actions.add_child(_save_button)
	_activate_button = _small_button("ActivateDeckButton", "ETKİNLEŞTİR", UI.MOSS)
	_activate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_activate_button.pressed.connect(_activate_deck)
	actions.add_child(_activate_button)
	return panel


func _column_panel(title_text: String, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	if width > 0.0:
		panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.016, 0.017, 0.020, 0.96), UI.BRASS, 6))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	content.add_child(title)
	return panel


func _small_button(node_name: String, text_value: String, accent: Color, destructive := false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size.y = 40.0
	button.add_theme_font_size_override("font_size", 12)
	UI.style_button(button, accent, destructive, true)
	return button


func _refresh_deck_list() -> void:
	_clear(_deck_list)
	if not _deck_manager:
		return
	var active_id := str(_deck_manager.get_active_deck_id())
	for deck_variant in _deck_manager.get_decks():
		var deck := deck_variant as Dictionary
		var deck_id := str(deck.get("id", ""))
		var button := Button.new()
		button.name = "DeckChoice_%s" % deck_id
		var active_mark := "  ◆" if deck_id == active_id else ""
		button.text = "%s%s\n%s" % [
			tr(str(deck.get("name", "İsimsiz Deste"))), active_mark,
			tr(str(deck.get("archetype", "Özel"))).to_upper(),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 58.0
		button.toggle_mode = true
		button.button_pressed = deck_id == _selected_deck_id
		button.add_theme_font_size_override("font_size", 12)
		UI.style_button(button, UI.BRASS_BRIGHT if deck_id == active_id else UI.BRASS, false, true, deck_id == active_id)
		button.pressed.connect(_load_deck.bind(deck_id))
		_deck_list.add_child(button)


func _load_deck(deck_id: String) -> void:
	if not _deck_manager:
		return
	var deck: Dictionary = _deck_manager.get_deck(deck_id)
	if deck.is_empty():
		return
	_selected_deck_id = deck_id
	_working_cards = (deck.get("cards", []) as Array).duplicate(true)
	_working_name = str(deck.get("name", "İsimsiz Deste"))
	_dirty = false
	_name_input.set_text(_working_name)
	_delete_button.disabled = bool(deck.get("is_starter", false))
	_refresh_deck_list()
	_refresh_collection()
	_refresh_current_deck()
	_set_status(str(deck.get("description", "")), false)


func _refresh_collection() -> void:
	_clear(_collection_list)
	if not _collection_list:
		return
	var search := _search_input.text.strip_edges().to_lower() if _search_input else ""
	var selected_type := "all"
	if _type_filter and _type_filter.selected >= 0:
		selected_type = str(_type_filter.get_item_metadata(_type_filter.selected))
	var cards: Array[Dictionary] = []
	for type_key in TYPE_ORDER:
		if selected_type != "all" and selected_type != type_key:
			continue
		for data_variant in CardDatabase.get_cards_for_type(type_key):
			var data := data_variant as Dictionary
			var card_id := str(data.get("id", ""))
			var ref := {"card_type": type_key, "card_id": card_id}
			if not _is_playable_ref(ref):
				continue
			var searchable := "%s %s" % [str(data.get("name", "")), str(data.get("description", ""))]
			if not search.is_empty() and search not in searchable.to_lower():
				continue
			var row := data.duplicate(true)
			row["card_type"] = type_key
			cards.append(row)
	cards.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var cost_compare := int(left.get("energy_cost", 0)) - int(right.get("energy_cost", 0))
		return str(left.get("name", "")).naturalnocasecmp_to(str(right.get("name", ""))) < 0 if cost_compare == 0 else cost_compare < 0
	)
	for data in cards:
		_collection_list.add_child(_build_collection_row(data))


func _build_collection_row(data: Dictionary) -> Control:
	var card_type := str(data.get("card_type", ""))
	var card_id := str(data.get("id", ""))
	var ref := {"card_type": card_type, "card_id": card_id}
	var copies := _count_ref(_working_cards, ref)
	var panel := PanelContainer.new()
	panel.name = "DeckPool_%s_%s" % [card_type, card_id]
	panel.custom_minimum_size.y = 48.0
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.026, 0.027, 0.030, 0.94), TYPE_COLORS.get(card_type, UI.BRASS), 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var cost := Label.new()
	cost.text = str(data.get("energy_cost", 0))
	cost.custom_minimum_size.x = 24.0
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	cost.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	row.add_child(cost)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 0)
	row.add_child(copy)
	var name_label := Label.new()
	name_label.text = tr(str(data.get("name", "İsimsiz Kart")))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	name_label.add_theme_font_size_override("font_size", 13)
	copy.add_child(name_label)
	var type_label := Label.new()
	type_label.text = "%s • %s" % [tr(TYPE_LABELS.get(card_type, card_type)), tr(str(data.get("rarity", "COMMON")).capitalize())]
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", UI.TEXT_MUTED)
	copy.add_child(type_label)
	var count := Label.new()
	count.text = "%d/%d" % [copies, GameRules.MAX_CARD_COPIES]
	count.custom_minimum_size.x = 36.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	count.add_theme_color_override("font_color", UI.PARCHMENT if copies > 0 else UI.TEXT_MUTED)
	row.add_child(count)
	var add_button := _small_button("Add_%s_%s" % [card_type, card_id], "+", TYPE_COLORS.get(card_type, UI.BRASS))
	add_button.custom_minimum_size = Vector2(38.0, 34.0)
	add_button.disabled = copies >= GameRules.MAX_CARD_COPIES or _working_cards.size() >= GameRules.DECK_SIZE
	add_button.pressed.connect(_add_card.bind(ref))
	row.add_child(add_button)
	return panel


func _refresh_current_deck() -> void:
	_clear(_current_list)
	var grouped := {}
	for card_variant in _working_cards:
		if not card_variant is Dictionary:
			continue
		var card := card_variant as Dictionary
		var key := "%s/%s" % [card.get("card_type", ""), card.get("card_id", "")]
		grouped[key] = int(grouped.get(key, 0)) + 1
	var keys: Array[String] = []
	for key_variant in grouped.keys():
		keys.append(str(key_variant))
	keys.sort_custom(func(left: String, right: String) -> bool:
		var left_parts := left.split("/", false, 1)
		var right_parts := right.split("/", false, 1)
		var left_data := CardDatabase.get_card(left_parts[0], left_parts[1])
		var right_data := CardDatabase.get_card(right_parts[0], right_parts[1])
		var cost_delta := int(left_data.get("energy_cost", 0)) - int(right_data.get("energy_cost", 0))
		return str(left_data.get("name", "")).naturalnocasecmp_to(str(right_data.get("name", ""))) < 0 if cost_delta == 0 else cost_delta < 0
	)
	for key in keys:
		var parts := key.split("/", false, 1)
		if parts.size() != 2:
			continue
		var data := CardDatabase.get_card(parts[0], parts[1])
		_current_list.add_child(_build_current_row(parts[0], parts[1], data, int(grouped[key])))

	var stats: Dictionary = _deck_manager.get_deck_stats(_working_cards) if _deck_manager else {}
	var valid_count := _working_cards.size() == GameRules.DECK_SIZE
	_stats_label.text = tr("%d/%d CARDS  •  ⚔ %d  ⌂ %d  ✦ %d  ⚒ %d  •  Avg. %.1f Energy") % [
		int(stats.get("total", 0)), GameRules.DECK_SIZE,
		int(stats.get("heroes", 0)), int(stats.get("settlements", 0)),
		int(stats.get("special_powers", 0)), int(stats.get("upgrades", 0)),
		float(stats.get("average_energy", 0.0)),
	]
	_stats_label.add_theme_color_override("font_color", UI.MOSS.lightened(0.30) if valid_count else UI.BRASS_BRIGHT)
	_save_button.disabled = not valid_count or not _dirty
	_activate_button.disabled = not valid_count
	var active := _deck_manager and _selected_deck_id == str(_deck_manager.get_active_deck_id()) and not _dirty
	_activate_button.text = "ETKİN DESTE" if active else "ETKİNLEŞTİR"
	if _dirty:
		_set_status("Kaydedilmemiş deste değişiklikleri var.", false)


func _build_current_row(card_type: String, card_id: String, data: Dictionary, copies: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "CurrentDeck_%s_%s" % [card_type, card_id]
	panel.custom_minimum_size.y = 42.0
	panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.024, 0.025, 0.028, 0.94), TYPE_COLORS.get(card_type, UI.BRASS), 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	var cost := Label.new()
	cost.text = str(data.get("energy_cost", 0))
	cost.custom_minimum_size.x = 22.0
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	cost.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	row.add_child(cost)
	var name_label := Label.new()
	name_label.text = tr(str(data.get("name", card_id)))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	name_label.add_theme_font_size_override("font_size", 12)
	row.add_child(name_label)
	var count := Label.new()
	count.text = "×%d" % copies
	count.custom_minimum_size.x = 30.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	row.add_child(count)
	var remove_button := _small_button("Remove_%s_%s" % [card_type, card_id], "−", UI.BLOOD, true)
	remove_button.custom_minimum_size = Vector2(36.0, 32.0)
	remove_button.pressed.connect(_remove_card.bind({"card_type": card_type, "card_id": card_id}))
	row.add_child(remove_button)
	return panel


func _add_card(card_ref: Dictionary) -> void:
	if _working_cards.size() >= GameRules.DECK_SIZE or _count_ref(_working_cards, card_ref) >= GameRules.MAX_CARD_COPIES:
		return
	_working_cards.append(card_ref.duplicate(true))
	_dirty = true
	_refresh_collection()
	_refresh_current_deck()


func _remove_card(card_ref: Dictionary) -> void:
	for index in range(_working_cards.size() - 1, -1, -1):
		var existing_variant: Variant = _working_cards[index]
		if existing_variant is Dictionary and _same_ref(existing_variant as Dictionary, card_ref):
			_working_cards.remove_at(index)
			_dirty = true
			break
	_refresh_collection()
	_refresh_current_deck()


func _on_name_changed(value: String) -> void:
	if value == _working_name:
		return
	_working_name = value
	_dirty = true
	_refresh_current_deck()


func _save_deck() -> void:
	if not _deck_manager:
		return
	var current := _deck_manager.get_deck(_selected_deck_id) as Dictionary
	var result: Dictionary
	if bool(current.get("is_starter", false)):
		result = _deck_manager.create_deck("%s Özel" % _working_name, _working_cards)
	else:
		result = _deck_manager.save_deck(_selected_deck_id, _working_name, _working_cards)
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", "Deste kaydedilemedi.")), true)
		return
	var saved := result.get("deck", {}) as Dictionary
	_load_deck(str(saved.get("id", _selected_deck_id)))
	_set_status("Deste kaydedildi.", false)


func _activate_deck() -> void:
	if _dirty:
		_save_deck()
	if not _deck_manager or _selected_deck_id.is_empty():
		return
	var result: Dictionary = _deck_manager.set_active_deck(_selected_deck_id)
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", "Deste etkinleştirilemedi.")), true)
		return
	_dirty = false
	_refresh_deck_list()
	_refresh_current_deck()
	_set_status("%s artık savaşlarda kullanılacak." % _working_name, false)


func _create_deck() -> void:
	if not _deck_manager:
		return
	var result: Dictionary = _deck_manager.create_deck("Yeni Deste", _deck_manager.get_active_deck_cards())
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", "Yeni deste oluşturulamadı.")), true)
		return
	_load_deck(str((result.get("deck", {}) as Dictionary).get("id", "")))
	_name_input.select_all()
	_name_input.grab_focus()


func _duplicate_deck() -> void:
	if not _deck_manager or _selected_deck_id.is_empty():
		return
	var result: Dictionary = _deck_manager.create_deck("%s Kopyası" % _working_name, _working_cards)
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", "Deste kopyalanamadı.")), true)
		return
	_load_deck(str((result.get("deck", {}) as Dictionary).get("id", "")))


func _delete_deck() -> void:
	if not _deck_manager or _selected_deck_id.is_empty():
		return
	var result: Dictionary = _deck_manager.delete_deck(_selected_deck_id)
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", "Deste silinemedi.")), true)
		return
	_load_deck(str(_deck_manager.get_active_deck_id()))
	_set_status("Özel deste silindi.", false)


func _on_repository_changed() -> void:
	if visible:
		_refresh_deck_list()


func _set_status(message: String, is_error: bool) -> void:
	if not _status_label:
		return
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.96, 0.38, 0.28) if is_error else UI.TEXT_MUTED)


func _count_ref(cards: Array, target: Dictionary) -> int:
	var count := 0
	for card_variant in cards:
		if card_variant is Dictionary and _same_ref(card_variant as Dictionary, target):
			count += 1
	return count


func _same_ref(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("card_type", "")) == str(right.get("card_type", "")) and str(left.get("card_id", "")) == str(right.get("card_id", ""))


func _is_playable_ref(card_ref: Dictionary) -> bool:
	var card_type := str(card_ref.get("card_type", ""))
	var card_id := str(card_ref.get("card_id", ""))
	for playable_variant in CardDatabase.get_playable_card_refs():
		if playable_variant is Dictionary and _same_ref(playable_variant as Dictionary, card_ref):
			return true
	return false


func _clear(container: Node) -> void:
	if not container:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
