class_name RulesReferencePanel extends Control

signal reference_closed

const UI := preload("res://scripts/dark_fantasy_ui.gd")

var _panel: Panel = null
var _reference_label: RichTextLabel = null
var _close_button: Button = null

func _ready() -> void:
	name = "RulesReferencePanel"
	theme = UI.create_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 850
	_create_ui()
	resized.connect(_layout_panel)
	visibility_changed.connect(_on_visibility_changed)
	visible = false

func open_reference() -> void:
	visible = true
	_layout_panel()
	_reference_label.text = CardKeywordGlossary.get_reference_text()
	_close_button.grab_focus()

func close_reference() -> void:
	if not visible:
		return
	visible = false
	reference_closed.emit()

func is_open() -> bool:
	return visible

func get_reference_text() -> String:
	return _reference_label.text if _reference_label else ""

func _create_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.006, 0.007, 0.009, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = Panel.new()
	_panel.name = "ReferencePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _build_panel_style())
	add_child(_panel)

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 28.0
	content.offset_top = 22.0
	content.offset_right = -28.0
	content.offset_bottom = -22.0
	content.add_theme_constant_override("separation", 12)
	_panel.add_child(content)

	var title := Label.new()
	title.text = "HIZLI KURAL REHBERİ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	UI.style_title(title, UI.BRASS_BRIGHT)
	content.add_child(title)

	_reference_label = RichTextLabel.new()
	_reference_label.name = "ReferenceText"
	_reference_label.bbcode_enabled = true
	_reference_label.scroll_active = true
	_reference_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reference_label.add_theme_font_size_override("normal_font_size", 15)
	_reference_label.add_theme_font_size_override("bold_font_size", 15)
	UI.style_rich_text(_reference_label)
	_reference_label.text = CardKeywordGlossary.get_reference_text()
	content.add_child(_reference_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "KAPAT"
	_close_button.custom_minimum_size = Vector2(0.0, 42.0)
	_close_button.add_theme_font_size_override("font_size", 14)
	UI.style_button(_close_button, UI.BRASS, false, true, true)
	_close_button.pressed.connect(close_reference)
	content.add_child(_close_button)

func _on_visibility_changed() -> void:
	set_process_unhandled_input(visible)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	close_reference()
	get_viewport().set_input_as_handled()

func _layout_panel() -> void:
	if not _panel:
		return
	var panel_size := Vector2(
		minf(660.0, maxf(320.0, size.x - 48.0)),
		minf(540.0, maxf(360.0, size.y - 48.0))
	)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -panel_size.x * 0.5
	_panel.offset_top = -panel_size.y * 0.5
	_panel.offset_right = panel_size.x * 0.5
	_panel.offset_bottom = panel_size.y * 0.5

func _build_panel_style() -> StyleBoxTexture:
	return UI.panel_style(UI.BRASS, 14.0, 1.0)
