class_name DarkFantasyUI extends RefCounted

## Shared visual language for every menu, HUD and modal surface.
## Keep component colors and materials here; docs/UI_KIT.md documents usage.

const DISPLAY_FONT := preload("res://fonts/Cinzel-Variable.ttf")
const BODY_FONT := preload("res://fonts/AlegreyaSans-Regular.ttf")
const BODY_MEDIUM_FONT := preload("res://fonts/AlegreyaSans-Medium.ttf")
const BODY_BOLD_FONT := preload("res://fonts/AlegreyaSans-Bold.ttf")
const BUTTON_TEXTURE := preload("res://images/ui/kit/button_forged.png")
const PANEL_TEXTURE := preload("res://images/ui/kit/panel_forged.png")

const VOID := Color(0.027, 0.029, 0.033)
const OBSIDIAN := Color(0.045, 0.043, 0.043)
const IRON := Color(0.095, 0.091, 0.088)
const BRASS_DARK := Color(0.43, 0.31, 0.16)
const BRASS := Color(0.72, 0.52, 0.24)
const BRASS_BRIGHT := Color(0.93, 0.75, 0.39)
const PARCHMENT := Color(0.92, 0.87, 0.76)
const TEXT_MUTED := Color(0.66, 0.63, 0.58)
const BLOOD := Color(0.68, 0.22, 0.19)
const FROST := Color(0.31, 0.58, 0.78)
const MOSS := Color(0.33, 0.58, 0.38)
const TEAM_EMBER := Color(0.86, 0.27, 0.16)
const TEAM_FROST := Color(0.22, 0.58, 0.92)
const TEAM_PLAYER := TEAM_FROST
const TEAM_OPPONENT := TEAM_EMBER

## Unified card-type & rarity palette (single source of truth across cards, HUD,
## Deck Builder, Gallery and Modals).
const CARD_TYPE_HERO := Color(0.82, 0.34, 0.24)
const CARD_TYPE_SETTLEMENT := Color(0.82, 0.58, 0.26)
const CARD_TYPE_UPGRADE := Color(0.22, 0.72, 0.68)
const CARD_TYPE_SPELL := Color(0.66, 0.38, 0.90)
const CARD_TYPE_EFFECT := Color(0.93, 0.75, 0.39)

const RARITY_COMMON := Color(0.68, 0.70, 0.72)
const RARITY_RARE := Color(0.28, 0.68, 0.98)
const RARITY_EPIC := Color(0.78, 0.38, 0.92)
const RARITY_LEGENDARY := Color(0.98, 0.70, 0.22)

const MODAL_DIM_ALPHA := 0.85

enum ButtonState { NORMAL, HOVER, PRESSED, DISABLED, FOCUS }


static func get_card_type_color(card_type: String) -> Color:
	match card_type.strip_edges().to_lower():
		"heroes", "hero":
			return CARD_TYPE_HERO
		"settlements", "settlement":
			return CARD_TYPE_SETTLEMENT
		"upgrades", "upgrade", "skill":
			return CARD_TYPE_UPGRADE
		"special_powers", "special_power", "spell":
			return CARD_TYPE_SPELL
		"effects", "effect":
			return CARD_TYPE_EFFECT
		_:
			return BRASS


static func get_card_type_label(card_type: String) -> String:
	match card_type.strip_edges().to_lower():
		"heroes", "hero":
			return "Kahraman"
		"settlements", "settlement":
			return "Yapı"
		"upgrades", "upgrade", "skill":
			return "Beceri"
		"special_powers", "special_power", "spell":
			return "Büyü"
		"effects", "effect":
			return "Etki"
		_:
			return "Kart"


static func get_rarity_color(rarity: String) -> Color:
	match rarity.strip_edges().to_upper():
		"COMMON":
			return RARITY_COMMON
		"RARE":
			return RARITY_RARE
		"EPIC":
			return RARITY_EPIC
		"LEGENDARY":
			return RARITY_LEGENDARY
		_:
			return RARITY_COMMON


static func get_rarity_label(rarity: String) -> String:
	match rarity.strip_edges().to_upper():
		"COMMON":
			return "Yaygın"
		"RARE":
			return "Nadir"
		"EPIC":
			return "Destansı"
		"LEGENDARY":
			return "Efsanevi"
		_:
			return "Yaygın"


static func create_theme() -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font = BODY_FONT
	ui_theme.default_font_size = 16

	ui_theme.set_font("font", "Label", BODY_FONT)
	ui_theme.set_font("font", "Button", DISPLAY_FONT)
	ui_theme.set_font("font", "CheckButton", BODY_MEDIUM_FONT)
	ui_theme.set_font("font", "CheckBox", BODY_MEDIUM_FONT)
	ui_theme.set_font("font", "OptionButton", BODY_MEDIUM_FONT)
	ui_theme.set_font("font", "LineEdit", BODY_FONT)
	ui_theme.set_font("font", "TabBar", DISPLAY_FONT)
	ui_theme.set_font("font", "TabContainer", DISPLAY_FONT)
	ui_theme.set_font("font", "PopupMenu", BODY_MEDIUM_FONT)
	ui_theme.set_font("normal_font", "RichTextLabel", BODY_FONT)
	ui_theme.set_font("bold_font", "RichTextLabel", BODY_BOLD_FONT)

	ui_theme.set_color("font_color", "Label", PARCHMENT)
	ui_theme.set_color("font_color", "Button", PARCHMENT)
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	ui_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	ui_theme.set_color("font_focus_color", "Button", BRASS_BRIGHT)
	ui_theme.set_color("font_disabled_color", "Button", Color(TEXT_MUTED, 0.56))
	ui_theme.set_color("font_color", "CheckButton", PARCHMENT)
	ui_theme.set_color("font_hover_color", "CheckButton", Color.WHITE)
	ui_theme.set_color("font_pressed_color", "CheckButton", BRASS_BRIGHT)
	ui_theme.set_color("font_color", "CheckBox", PARCHMENT)
	ui_theme.set_color("font_hover_color", "CheckBox", Color.WHITE)
	ui_theme.set_color("font_pressed_color", "CheckBox", BRASS_BRIGHT)
	ui_theme.set_color("default_color", "RichTextLabel", PARCHMENT)

	ui_theme.set_stylebox("normal", "Button", button_style(ButtonState.NORMAL))
	ui_theme.set_stylebox("hover", "Button", button_style(ButtonState.HOVER))
	ui_theme.set_stylebox("pressed", "Button", button_style(ButtonState.PRESSED))
	ui_theme.set_stylebox("disabled", "Button", button_style(ButtonState.DISABLED))
	ui_theme.set_stylebox("focus", "Button", button_style(ButtonState.FOCUS))

	ui_theme.set_stylebox("normal", "OptionButton", compact_button_style(ButtonState.NORMAL, BRASS))
	ui_theme.set_stylebox("hover", "OptionButton", compact_button_style(ButtonState.HOVER, BRASS))
	ui_theme.set_stylebox("pressed", "OptionButton", compact_button_style(ButtonState.PRESSED, BRASS))
	ui_theme.set_stylebox("disabled", "OptionButton", compact_button_style(ButtonState.DISABLED, BRASS))
	ui_theme.set_stylebox("focus", "OptionButton", focus_style(BRASS, true))
	ui_theme.set_color("font_color", "OptionButton", PARCHMENT)
	ui_theme.set_color("font_hover_color", "OptionButton", Color.WHITE)
	ui_theme.set_color("font_pressed_color", "OptionButton", BRASS_BRIGHT)

	# LineEdit
	var line_normal := inset_style(Color(0.055, 0.052, 0.050, 0.96), BRASS_DARK, 4)
	line_normal.border_color = Color(BRASS, 0.45)
	var line_focus := inset_style(Color(0.075, 0.068, 0.060, 0.98), BRASS_BRIGHT, 4)
	line_focus.border_color = Color(BRASS_BRIGHT, 0.88)
	line_focus.set_border_width_all(2)
	var line_readonly := inset_style(Color(0.04, 0.04, 0.042, 0.84), TEXT_MUTED, 4)
	ui_theme.set_stylebox("normal", "LineEdit", line_normal)
	ui_theme.set_stylebox("focus", "LineEdit", line_focus)
	ui_theme.set_stylebox("read_only", "LineEdit", line_readonly)
	ui_theme.set_color("font_color", "LineEdit", PARCHMENT)
	ui_theme.set_color("font_placeholder_color", "LineEdit", Color(TEXT_MUTED, 0.72))
	ui_theme.set_color("caret_color", "LineEdit", BRASS_BRIGHT)
	ui_theme.set_color("selection_color", "LineEdit", Color(BRASS, 0.36))

	# PopupMenu (OptionButton dropdowns)
	var popup_bg := StyleBoxFlat.new()
	popup_bg.bg_color = Color(0.065, 0.060, 0.058, 0.98)
	popup_bg.border_color = Color(BRASS, 0.68)
	popup_bg.set_border_width_all(1)
	popup_bg.set_corner_radius_all(4)
	popup_bg.content_margin_left = 6.0
	popup_bg.content_margin_right = 6.0
	popup_bg.content_margin_top = 6.0
	popup_bg.content_margin_bottom = 6.0
	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = Color(BRASS, 0.24)
	popup_hover.border_color = Color(BRASS_BRIGHT, 0.65)
	popup_hover.set_border_width_all(1)
	popup_hover.set_corner_radius_all(3)
	ui_theme.set_stylebox("panel", "PopupMenu", popup_bg)
	ui_theme.set_stylebox("hover", "PopupMenu", popup_hover)
	ui_theme.set_color("font_color", "PopupMenu", PARCHMENT)
	ui_theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	ui_theme.set_color("font_disabled_color", "PopupMenu", Color(TEXT_MUTED, 0.50))
	ui_theme.set_color("font_separator_color", "PopupMenu", BRASS)

	# TabContainer & TabBar
	var tab_panel := inset_style(Color(0.048, 0.045, 0.044, 0.94), BRASS, 4)
	tab_panel.border_color = Color(BRASS, 0.44)
	tab_panel.content_margin_left = 14.0
	tab_panel.content_margin_right = 14.0
	tab_panel.content_margin_top = 12.0
	tab_panel.content_margin_bottom = 12.0
	var tab_unselected := StyleBoxFlat.new()
	tab_unselected.bg_color = Color(0.075, 0.070, 0.066, 0.92)
	tab_unselected.border_color = Color(BRASS_DARK, 0.55)
	tab_unselected.set_border_width_all(1)
	tab_unselected.border_width_bottom = 0
	tab_unselected.corner_radius_top_left = 4
	tab_unselected.corner_radius_top_right = 4
	tab_unselected.content_margin_left = 16.0
	tab_unselected.content_margin_right = 16.0
	tab_unselected.content_margin_top = 8.0
	tab_unselected.content_margin_bottom = 8.0
	var tab_hovered := tab_unselected.duplicate() as StyleBoxFlat
	tab_hovered.bg_color = Color(0.125, 0.112, 0.095, 0.96)
	tab_hovered.border_color = Color(BRASS, 0.78)
	var tab_selected := tab_unselected.duplicate() as StyleBoxFlat
	tab_selected.bg_color = Color(0.145, 0.118, 0.082, 0.98)
	tab_selected.border_color = Color(BRASS_BRIGHT, 0.92)
	tab_selected.border_width_top = 2
	for tab_type in ["TabContainer", "TabBar"]:
		ui_theme.set_stylebox("tab_unselected", tab_type, tab_unselected)
		ui_theme.set_stylebox("tab_hovered", tab_type, tab_hovered)
		ui_theme.set_stylebox("tab_selected", tab_type, tab_selected)
		ui_theme.set_stylebox("tab_focus", tab_type, focus_style(BRASS, true))
		ui_theme.set_color("font_unselected_color", tab_type, TEXT_MUTED)
		ui_theme.set_color("font_hovered_color", tab_type, PARCHMENT)
		ui_theme.set_color("font_selected_color", tab_type, BRASS_BRIGHT)
	ui_theme.set_stylebox("panel", "TabContainer", tab_panel)

	# Scrollbars (forged slim iron + brass grabber)
	var scroll_track := StyleBoxFlat.new()
	scroll_track.bg_color = Color(0.055, 0.052, 0.050, 0.78)
	scroll_track.set_corner_radius_all(3)
	scroll_track.content_margin_left = 3.0
	scroll_track.content_margin_right = 3.0
	scroll_track.content_margin_top = 3.0
	scroll_track.content_margin_bottom = 3.0
	var scroll_grab := StyleBoxFlat.new()
	scroll_grab.bg_color = Color(BRASS_DARK, 0.85)
	scroll_grab.border_color = Color(BRASS, 0.65)
	scroll_grab.set_border_width_all(1)
	scroll_grab.set_corner_radius_all(3)
	var scroll_grab_hover := scroll_grab.duplicate() as StyleBoxFlat
	scroll_grab_hover.bg_color = Color(BRASS, 0.92)
	scroll_grab_hover.border_color = Color(BRASS_BRIGHT, 0.85)
	var scroll_grab_pressed := scroll_grab.duplicate() as StyleBoxFlat
	scroll_grab_pressed.bg_color = Color(BRASS_BRIGHT, 0.95)
	for bar_type in ["VScrollBar", "HScrollBar"]:
		ui_theme.set_stylebox("scroll", bar_type, scroll_track)
		ui_theme.set_stylebox("scroll_focus", bar_type, scroll_track)
		ui_theme.set_stylebox("grabber", bar_type, scroll_grab)
		ui_theme.set_stylebox("grabber_highlight", bar_type, scroll_grab_hover)
		ui_theme.set_stylebox("grabber_pressed", bar_type, scroll_grab_pressed)

	# ProgressBar & HSlider
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.055, 0.052, 0.94)
	bar_bg.border_color = Color(BRASS_DARK, 0.65)
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(BRASS, 0.88)
	bar_fill.set_corner_radius_all(2)
	ui_theme.set_stylebox("background", "ProgressBar", bar_bg)
	ui_theme.set_stylebox("fill", "ProgressBar", bar_fill)
	ui_theme.set_color("font_color", "ProgressBar", PARCHMENT)

	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color(0.08, 0.075, 0.07, 0.95)
	slider_track.border_color = Color(BRASS_DARK, 0.65)
	slider_track.set_border_width_all(1)
	slider_track.set_corner_radius_all(3)
	slider_track.content_margin_top = 4.0
	slider_track.content_margin_bottom = 4.0
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = Color(BRASS, 0.90)
	slider_fill.set_corner_radius_all(3)
	ui_theme.set_stylebox("slider", "HSlider", slider_track)
	ui_theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	ui_theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	ui_theme.set_stylebox("panel", "PopupPanel", panel_style(BRASS, 18.0, 0.96))
	ui_theme.set_stylebox("panel", "TooltipPanel", panel_style(BRASS, 14.0, 0.96))
	ui_theme.set_stylebox("separator", "HSeparator", line_style(Color(BRASS, 0.46), 1))
	return ui_theme


static func style_button(
	button: Button,
	accent: Color = BRASS,
	destructive := false,
	compact := false,
	primary := false
) -> void:
	if not button:
		return
	var effective_accent := BLOOD if destructive else accent
	var padding := 10.0 if compact else 18.0
	button.add_theme_font_override("font", DISPLAY_FONT)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", BRASS_BRIGHT if not destructive else Color(1.0, 0.76, 0.68))
	button.add_theme_color_override("font_disabled_color", Color(TEXT_MUTED, 0.56))
	if compact:
		button.add_theme_stylebox_override("normal", compact_button_style(ButtonState.NORMAL, effective_accent, padding, primary))
		button.add_theme_stylebox_override("hover", compact_button_style(ButtonState.HOVER, effective_accent, padding, primary))
		button.add_theme_stylebox_override("pressed", compact_button_style(ButtonState.PRESSED, effective_accent, padding, primary))
		button.add_theme_stylebox_override("disabled", compact_button_style(ButtonState.DISABLED, effective_accent, padding, primary))
		button.add_theme_stylebox_override("focus", focus_style(effective_accent, true))
	else:
		button.add_theme_stylebox_override("normal", button_style(ButtonState.NORMAL, effective_accent, padding, false, primary))
		button.add_theme_stylebox_override("hover", button_style(ButtonState.HOVER, effective_accent, padding, false, primary))
		button.add_theme_stylebox_override("pressed", button_style(ButtonState.PRESSED, effective_accent, padding, false, primary))
		button.add_theme_stylebox_override("disabled", button_style(ButtonState.DISABLED, effective_accent, padding, false, primary))
		button.add_theme_stylebox_override("focus", button_style(ButtonState.FOCUS, effective_accent, padding, false, primary))


static func style_title(label: Label, color: Color = PARCHMENT) -> void:
	if not label:
		return
	label.add_theme_font_override("font", DISPLAY_FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("outline_size", 3)


static func style_rich_text(label: RichTextLabel) -> void:
	if not label:
		return
	label.add_theme_font_override("normal_font", BODY_FONT)
	label.add_theme_font_override("bold_font", BODY_BOLD_FONT)
	label.add_theme_color_override("default_color", PARCHMENT)


static func compact_button_style(
	state: int,
	accent: Color = BRASS,
	horizontal_padding := 10.0,
	primary := false
) -> StyleBox:
	if state == ButtonState.FOCUS:
		return focus_style(accent, true)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	match state:
		ButtonState.HOVER:
			style.bg_color = Color(0.145, 0.132, 0.118, 0.98).lerp(accent, 0.18 if primary else 0.12)
			style.border_color = Color(accent.lightened(0.22), 0.92)
		ButtonState.PRESSED:
			style.bg_color = Color(0.068, 0.062, 0.058, 0.98).lerp(accent, 0.12)
			style.border_color = Color(accent, 0.82)
			style.content_margin_top = 6.0
			style.content_margin_bottom = 4.0
		ButtonState.DISABLED:
			style.bg_color = Color(0.065, 0.065, 0.068, 0.72)
			style.border_color = Color(0.28, 0.27, 0.26, 0.48)
		_:
			style.bg_color = Color(0.095, 0.088, 0.082, 0.96).lerp(accent, 0.14 if primary else 0.06)
			style.border_color = Color(accent, 0.72 if primary else 0.48)
	return style


static func button_style(
	state: int,
	accent: Color = BRASS,
	horizontal_padding := 18.0,
	compact := false,
	primary := false
) -> StyleBox:
	if compact:
		return compact_button_style(state, accent, horizontal_padding, primary)
	if state == ButtonState.FOCUS:
		return focus_style(accent, false)

	var style := StyleBoxTexture.new()
	style.texture = BUTTON_TEXTURE
	style.texture_margin_left = 26.0
	style.texture_margin_top = 16.0
	style.texture_margin_right = 26.0
	style.texture_margin_bottom = 16.0
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	style.draw_center = true

	var neutral_tint := Color(1.0, 0.98, 0.94, 1.0)
	match state:
		ButtonState.HOVER:
			style.modulate_color = neutral_tint.lerp(accent.lightened(0.16), 0.36 if primary else 0.26)
		ButtonState.PRESSED:
			style.modulate_color = neutral_tint.lerp(accent, 0.28).darkened(0.20)
			style.content_margin_top += 2.0
			style.content_margin_bottom = maxf(4.0, style.content_margin_bottom - 2.0)
		ButtonState.DISABLED:
			style.modulate_color = Color(0.42, 0.42, 0.44, 0.72)
		_:
			style.modulate_color = neutral_tint.lerp(accent, 0.22 if primary else 0.10)
	return style


static func panel_style(accent: Color = BRASS, padding := 24.0, opacity := 1.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PANEL_TEXTURE
	style.texture_margin_left = 32.0
	style.texture_margin_top = 32.0
	style.texture_margin_right = 32.0
	style.texture_margin_bottom = 32.0
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	style.modulate_color = Color(0.88, 0.86, 0.82, opacity).lerp(Color(accent, opacity), 0.10)
	style.draw_center = true
	return style


static func inset_style(background: Color = Color(0.03, 0.03, 0.035, 0.92), accent: Color = BRASS, radius := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(accent, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(clampi(radius, 2, 6))
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


static func focus_style(accent: Color = BRASS, compact := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(accent.lightened(0.20), 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3 if compact else 5)
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style


static func line_style(color_value: Color = Color(BRASS, 0.44), thickness := 1) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = color_value
	line.thickness = thickness
	return line
