class_name DarkFantasyUI extends RefCounted

## Shared visual language for every menu, HUD and modal surface.
## Keep component colors and materials here; UI_KIT.md documents usage.

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
const TEXT_MUTED := Color(0.64, 0.62, 0.58)
const BLOOD := Color(0.61, 0.20, 0.17)
const FROST := Color(0.31, 0.55, 0.70)
const MOSS := Color(0.31, 0.48, 0.33)
const TEAM_EMBER := Color(0.86, 0.27, 0.16)
const TEAM_FROST := Color(0.22, 0.58, 0.92)
const TEAM_PLAYER := TEAM_FROST
const TEAM_OPPONENT := TEAM_EMBER

enum ButtonState { NORMAL, HOVER, PRESSED, DISABLED, FOCUS }


static func create_theme() -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font = BODY_FONT
	ui_theme.default_font_size = 16

	ui_theme.set_font("font", "Label", BODY_FONT)
	ui_theme.set_font("font", "Button", DISPLAY_FONT)
	ui_theme.set_font("font", "CheckButton", BODY_MEDIUM_FONT)
	ui_theme.set_font("font", "OptionButton", BODY_MEDIUM_FONT)
	ui_theme.set_font("font", "TabBar", DISPLAY_FONT)
	ui_theme.set_font("normal_font", "RichTextLabel", BODY_FONT)
	ui_theme.set_font("bold_font", "RichTextLabel", BODY_BOLD_FONT)

	ui_theme.set_color("font_color", "Label", PARCHMENT)
	ui_theme.set_color("font_color", "Button", PARCHMENT)
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	ui_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	ui_theme.set_color("font_focus_color", "Button", BRASS_BRIGHT)
	ui_theme.set_color("font_disabled_color", "Button", Color(TEXT_MUTED, 0.52))
	ui_theme.set_color("font_color", "CheckButton", TEXT_MUTED)
	ui_theme.set_color("font_hover_color", "CheckButton", PARCHMENT)
	ui_theme.set_color("font_pressed_color", "CheckButton", BRASS_BRIGHT)
	ui_theme.set_color("default_color", "RichTextLabel", PARCHMENT)

	ui_theme.set_stylebox("normal", "Button", button_style(ButtonState.NORMAL))
	ui_theme.set_stylebox("hover", "Button", button_style(ButtonState.HOVER))
	ui_theme.set_stylebox("pressed", "Button", button_style(ButtonState.PRESSED))
	ui_theme.set_stylebox("disabled", "Button", button_style(ButtonState.DISABLED))
	ui_theme.set_stylebox("focus", "Button", button_style(ButtonState.FOCUS))

	ui_theme.set_stylebox("normal", "OptionButton", button_style(ButtonState.NORMAL, BRASS, 12.0, true))
	ui_theme.set_stylebox("hover", "OptionButton", button_style(ButtonState.HOVER, BRASS, 12.0, true))
	ui_theme.set_stylebox("pressed", "OptionButton", button_style(ButtonState.PRESSED, BRASS, 12.0, true))
	ui_theme.set_stylebox("focus", "OptionButton", button_style(ButtonState.FOCUS, BRASS, 12.0, true))

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
	button.add_theme_color_override("font_disabled_color", Color(TEXT_MUTED, 0.50))
	button.add_theme_stylebox_override("normal", button_style(ButtonState.NORMAL, effective_accent, padding, compact, primary))
	button.add_theme_stylebox_override("hover", button_style(ButtonState.HOVER, effective_accent, padding, compact, primary))
	button.add_theme_stylebox_override("pressed", button_style(ButtonState.PRESSED, effective_accent, padding, compact, primary))
	button.add_theme_stylebox_override("disabled", button_style(ButtonState.DISABLED, effective_accent, padding, compact, primary))
	button.add_theme_stylebox_override("focus", button_style(ButtonState.FOCUS, effective_accent, padding, compact, primary))


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


static func button_style(
	state: int,
	accent: Color = BRASS,
	horizontal_padding := 18.0,
	compact := false,
	primary := false
) -> StyleBox:
	if state == ButtonState.FOCUS:
		return focus_style(accent, compact)

	var style := StyleBoxTexture.new()
	style.texture = BUTTON_TEXTURE
	style.texture_margin_left = 34.0
	style.texture_margin_top = 25.0
	style.texture_margin_right = 34.0
	style.texture_margin_bottom = 25.0
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = 7.0 if compact else 10.0
	style.content_margin_bottom = 7.0 if compact else 10.0
	style.draw_center = true

	var neutral_tint := Color(0.82, 0.80, 0.76, 1.0)
	match state:
		ButtonState.HOVER:
			style.modulate_color = neutral_tint.lerp(accent.lightened(0.12), 0.34 if primary else 0.25)
		ButtonState.PRESSED:
			style.modulate_color = neutral_tint.lerp(accent, 0.28).darkened(0.22)
			style.content_margin_top += 2.0
			style.content_margin_bottom = maxf(4.0, style.content_margin_bottom - 2.0)
		ButtonState.DISABLED:
			style.modulate_color = Color(0.39, 0.39, 0.40, 0.72)
		_:
			style.modulate_color = neutral_tint.lerp(accent, 0.20 if primary else 0.09)
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
	style.set_corner_radius_all(radius)
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
