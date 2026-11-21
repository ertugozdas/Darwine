class_name EffectCard extends BaseCard

var _persistent_badge: Label = null


func _get_card_type_key() -> String:
	return EffectCardCatalog.CARD_TYPE


func _get_card_type_display_name() -> String:
	return "ETKİ"


func _get_rarity_display_name() -> String:
	match rarity:
		Rarity.RARE: return "NADİR"
		Rarity.EPIC: return "DESTANSI"
		Rarity.LEGENDARY: return "EFSANEVİ"
		_: return "YAYGIN"


func _ready() -> void:
	energy_cost = 0
	is_draggable = false
	super._ready()
	_build_effect_template_surface()
	_refresh_mouse_filter()


func _build_effect_template_surface() -> void:
	if not _frame_panel:
		return
	if _gold_panel:
		_gold_panel.visible = false
	for badge_name in ["AttackBadge", "ArmorBadge", "HealthBadge", "StatsContainer"]:
		var badge := _frame_panel.get_node_or_null(badge_name)
		if badge:
			badge.visible = false
	if _runtime_state_rail:
		_runtime_state_rail.visible = false
	if _combat_state_badge:
		_combat_state_badge.visible = false
	if _progression_badge:
		_progression_badge.visible = false
	if _effect_state_badge:
		_effect_state_badge.visible = false

	if not _type_lbl:
		_type_lbl = Label.new()
		_type_lbl.name = "TypeLabel"
		_frame_panel.add_child(_type_lbl)
	if not _rarity_lbl:
		_rarity_lbl = Label.new()
		_rarity_lbl.name = "RarityLabel"
		_frame_panel.add_child(_rarity_lbl)
	for label in [_type_lbl, _rarity_lbl]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", UI.DISPLAY_FONT)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
	_type_lbl.text = tr("ETKİ")
	_type_lbl.position = Vector2(16.0, 10.0)
	_type_lbl.size = Vector2(82.0, 22.0)
	_rarity_lbl.text = tr(_get_rarity_display_name())
	_rarity_lbl.position = Vector2(100.0, 10.0)
	_rarity_lbl.size = Vector2(84.0, 22.0)
	_rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if _art_texture:
		_reset_anchors(_art_texture)
		_art_texture.position = Vector2(16.0, 38.0)
		_art_texture.size = Vector2(168.0, 118.0)
	if _name_lbl:
		_reset_anchors(_name_lbl)
		_name_lbl.position = Vector2(14.0, 162.0)
		_name_lbl.size = Vector2(172.0, 31.0)
		_name_lbl.add_theme_font_size_override("font_size", 15)
	if _desc_lbl:
		_reset_anchors(_desc_lbl)
		_desc_lbl.position = Vector2(16.0, 196.0)
		_desc_lbl.size = Vector2(168.0, 54.0)
		_desc_lbl.add_theme_font_size_override("font_size", 10)
		_desc_lbl.max_lines_visible = 4

	_persistent_badge = Label.new()
	_persistent_badge.name = "PersistentBadge"
	_persistent_badge.text = "KALICI  •  AKTİF"
	_persistent_badge.position = Vector2(28.0, 251.0)
	_persistent_badge.size = Vector2(144.0, 20.0)
	_persistent_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_persistent_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_persistent_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_persistent_badge.add_theme_font_override("font", UI.DISPLAY_FONT)
	_persistent_badge.add_theme_font_size_override("font_size", 10)
	_persistent_badge.add_theme_color_override("font_color", _rarity_accent())
	_frame_panel.add_child(_persistent_badge)
	_apply_effect_frame_style()
	_update_ui()


func _reset_anchors(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0


func _update_visuals() -> void:
	if not is_inside_tree() or not _frame_panel:
		return
	_apply_effect_frame_style()
	if _persistent_badge:
		_persistent_badge.add_theme_color_override("font_color", _rarity_accent())


func _apply_effect_frame_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.043, 0.046, 0.99)
	style.border_color = _rarity_accent()
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(_rarity_accent(), 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	_frame_panel.add_theme_stylebox_override("panel", style)


func _rarity_accent() -> Color:
	match rarity:
		Rarity.RARE: return UI.RARITY_RARE
		Rarity.EPIC: return UI.RARITY_EPIC
		Rarity.LEGENDARY: return UI.RARITY_LEGENDARY
		_: return UI.RARITY_COMMON
