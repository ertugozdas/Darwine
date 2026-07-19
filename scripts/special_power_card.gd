class_name SpecialPowerCard extends BaseCard

@export_group("Special Power Details")
## The type or category of this power (e.g., "Hasar", "İyileştirme", "Dondurma")
@export var power_type: String = "Büyü":
	set(val):
		power_type = val
		_update_ui()

## The numerical strength of the spell (e.g. 5 damage, 2 turns stun)
@export var intensity: int = 3:
	set(val):
		intensity = val
		_update_ui()

var _power_type_lbl: Label = null
var _intensity_lbl: Label = null

func _get_card_type_key() -> String:
	return "special_powers"

func _get_card_type_display_name() -> String:
	return "Büyü"

func _apply_card_data(card_data: Dictionary) -> void:
	super._apply_card_data(card_data)
	power_type = _get_string_from_card_data(card_data, "power_type", power_type)
	intensity = _get_int_from_card_data(card_data, "intensity", intensity)

func _create_ui_nodes_if_missing() -> void:
	super._create_ui_nodes_if_missing()
	_power_type_lbl = get_node_or_null("CardFrame/PowerTypeLabel") as Label
	_intensity_lbl = get_node_or_null("CardFrame/IntensityLabel") as Label
	if _desc_lbl and (_power_type_lbl or _intensity_lbl):
		_desc_lbl.anchor_bottom = 0.80
	_style_readable_label(_power_type_lbl)
	_style_readable_label(_intensity_lbl)
	_apply_special_power_template_layout()

func _apply_special_power_template_layout() -> void:
	_set_template_value_badge(
		_gold_panel, _gold_lbl, Rect2(10.0, 10.0, 34.0, 34.0),
		Rect2(11.0, 0.0, 19.0, 34.0), 15
	)
	_set_template_control_rect(_art_texture, Rect2(17.0, 21.0, 166.0, 128.0))
	_set_template_label_rect(_power_type_lbl, Rect2(40.0, 154.0, 74.0, 18.0), 9)
	_set_template_label_rect(_intensity_lbl, Rect2(143.0, 154.0, 36.0, 18.0), 10)
	_set_template_label_rect(_name_lbl, Rect2(20.0, 175.0, 160.0, 23.0), 15)
	_set_template_label_rect(_desc_lbl, Rect2(21.0, 209.0, 158.0, 53.0), 10)
	if _power_type_lbl:
		_power_type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_power_type_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _intensity_lbl:
		_intensity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_intensity_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _update_ui() -> void:
	super._update_ui()
	if _power_type_lbl:
		_power_type_lbl.text = tr(power_type)
	if _intensity_lbl:
		_intensity_lbl.text = str(intensity)

func _update_visuals() -> void:
	if card_template or _has_template_background():
		super._update_visuals()
	else:
		if not is_inside_tree():
			return
			
		var border_color = Color(0.64, 0.21, 0.93) # Cosmic/Magic Violet
		match rarity:
			Rarity.COMMON:
				border_color = Color(0.5, 0.5, 0.6)
			Rarity.RARE:
				border_color = Color(0.12, 0.56, 1.0) # Magic Blue
			Rarity.EPIC:
				border_color = Color(0.75, 0.15, 0.95) # Radiant Purple
			Rarity.LEGENDARY:
				border_color = Color(1.0, 0.84, 0.0) # Celestial Gold
				
		var style_flat = StyleBoxFlat.new()
		style_flat.bg_color = Color(0.08, 0.05, 0.12) # Deep mystical abyss purple background
		style_flat.border_width_left = 4
		style_flat.border_width_top = 4
		style_flat.border_width_right = 4
		style_flat.border_width_bottom = 4
		style_flat.border_color = border_color
		style_flat.corner_radius_top_left = 12
		style_flat.corner_radius_top_right = 12
		style_flat.corner_radius_bottom_left = 12
		style_flat.corner_radius_bottom_right = 12
		style_flat.shadow_color = Color(0.3, 0.1, 0.4, 0.25) # Soft magical shadow glow
		style_flat.shadow_size = 8
		style_flat.shadow_offset = Vector2(0, 4)
		_frame_panel.add_theme_stylebox_override("panel", style_flat)
