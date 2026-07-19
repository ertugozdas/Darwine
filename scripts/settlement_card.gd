class_name SettlementCard extends BaseCard

@export_group("Settlement Stats")
@export var health: int = 8:
	set(val):
		health = max(0, val)
		if not _health_initialized:
			max_health = health
		_update_ui()
		preview_state_changed.emit()

@export var attack: int = 0:
	set(val):
		attack = max(0, val)
		_update_ui()
		_update_badge_visibilities()
		preview_state_changed.emit()

var max_health: int = 8
var _health_initialized := false

# Settlement UI Nodes
var _stats_container: HBoxContainer = null
var _attack_panel: Panel = null
var _attack_lbl: Label = null
var _health_panel: Panel = null
var _health_lbl: Label = null

func _get_card_type_key() -> String:
	return "settlements"

func _get_card_type_display_name() -> String:
	return "Yerleşim"

func _apply_card_data(card_data: Dictionary) -> void:
	super._apply_card_data(card_data)
	health = _get_int_from_card_data(card_data, "health", health)
	attack = _get_int_from_card_data(card_data, "attack", attack)
	max_health = health
	_health_initialized = true

func get_attack_value() -> int:
	return attack

func get_current_health() -> int:
	return health

func get_max_health() -> int:
	_ensure_health_initialized()
	return max_health

func take_combat_damage(damage: int) -> Dictionary:
	_ensure_health_initialized()
	var normalized_damage: int = max(0, damage)
	var health_damage: int = min(health, normalized_damage)
	health -= health_damage
	return {
		"success": true,
		"damage": normalized_damage,
		"armor_damage": 0,
		"health_damage": health_damage,
		"remaining_armor": 0,
		"remaining_health": health,
		"destroyed": health <= 0,
	}

func heal_combat_damage(amount: int) -> int:
	_ensure_health_initialized()
	var previous_health := health
	health = min(max_health, health + max(0, amount))
	return health - previous_health

func increase_max_health(amount: int) -> void:
	_ensure_health_initialized()
	var normalized_amount: int = max(0, amount)
	max_health += normalized_amount
	health += normalized_amount

func _ensure_health_initialized() -> void:
	if _health_initialized:
		return
	max_health = max(0, health)
	_health_initialized = true

func _create_ui_nodes_if_missing() -> void:
	# Build base card structure
	super._create_ui_nodes_if_missing()
	
	# Shrink description box to fit bottom stats
	if _desc_lbl:
		_desc_lbl.anchor_bottom = 0.80
		
	_stats_container = get_node_or_null("CardFrame/StatsContainer") as HBoxContainer
	_attack_panel = _get_existing_stat_badge("AttackBadge")
	_attack_lbl = _get_existing_stat_label("AttackBadge", "AttackLabel")
	_health_panel = _get_existing_stat_badge("HealthBadge")
	_health_lbl = _get_existing_stat_label("HealthBadge", "HealthLabel")

	if not (_attack_panel and _attack_lbl and _health_panel and _health_lbl):
		# Create HBoxContainer for centering stats
		_stats_container = HBoxContainer.new()
		_stats_container.name = "StatsContainer"
		_stats_container.mouse_filter = Control.MOUSE_FILTER_PASS
		_stats_container.alignment = BoxContainer.ALIGNMENT_CENTER
		_stats_container.anchor_left = 0.06
		_stats_container.anchor_top = 0.82
		_stats_container.anchor_right = 0.94
		_stats_container.anchor_bottom = 0.94
		_stats_container.add_theme_constant_override("separation", 6)
		_frame_panel.add_child(_stats_container)
		
		# 1. Attack Badge (⚔️)
		_attack_panel = Panel.new()
		_attack_panel.name = "AttackBadge"
		_attack_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		_attack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var atk_style = StyleBoxFlat.new()
		atk_style.bg_color = Color(0.65, 0.15, 0.15)
		atk_style.border_width_left = 1
		atk_style.border_width_top = 1
		atk_style.border_width_right = 1
		atk_style.border_width_bottom = 1
		atk_style.border_color = Color(0.85, 0.3, 0.3)
		atk_style.corner_radius_top_left = 6
		atk_style.corner_radius_top_right = 6
		atk_style.corner_radius_bottom_left = 6
		atk_style.corner_radius_bottom_right = 6
		_attack_panel.add_theme_stylebox_override("panel", atk_style)
		_stats_container.add_child(_attack_panel)
		
		_attack_lbl = Label.new()
		_attack_lbl.name = "AttackLabel"
		_attack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_attack_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_attack_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_attack_lbl.add_theme_font_size_override("font_size", 10)
		_attack_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		_attack_lbl.add_theme_constant_override("shadow_outline_size", 1)
		_attack_panel.add_child(_attack_lbl)
		
		# 2. Health Badge (❤️)
		_health_panel = Panel.new()
		_health_panel.name = "HealthBadge"
		_health_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		_health_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var hp_style = StyleBoxFlat.new()
		hp_style.bg_color = Color(0.15, 0.5, 0.2)
		hp_style.border_width_left = 1
		hp_style.border_width_top = 1
		hp_style.border_width_right = 1
		hp_style.border_width_bottom = 1
		hp_style.border_color = Color(0.3, 0.75, 0.35)
		hp_style.corner_radius_top_left = 6
		hp_style.corner_radius_top_right = 6
		hp_style.corner_radius_bottom_left = 6
		hp_style.corner_radius_bottom_right = 6
		_health_panel.add_theme_stylebox_override("panel", hp_style)
		_stats_container.add_child(_health_panel)
		
		_health_lbl = Label.new()
		_health_lbl.name = "HealthLabel"
		_health_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_health_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_health_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_health_lbl.add_theme_font_size_override("font_size", 10)
		_health_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		_health_lbl.add_theme_constant_override("shadow_outline_size", 1)
		_health_panel.add_child(_health_lbl)
		
	_style_stat_badge(_attack_panel, _attack_lbl)
	_style_stat_badge(_health_panel, _health_lbl)

	# Adjust initial badge visibilities
	_update_badge_visibilities()
	_apply_settlement_template_layout()

func _apply_settlement_template_layout() -> void:
	_set_template_value_badge(
		_gold_panel, _gold_lbl, Rect2(10.0, 10.0, 34.0, 34.0),
		Rect2(11.0, 0.0, 19.0, 34.0), 15
	)
	_set_template_control_rect(_art_texture, Rect2(19.0, 18.0, 162.0, 129.0))
	_set_template_control_rect(_runtime_state_rail, Rect2(20.0, 125.0, 160.0, 20.0))
	_set_template_value_badge(
		_attack_panel, _attack_lbl, Rect2(23.0, 158.0, 64.0, 29.0),
		Rect2(32.0, 0.0, 26.0, 29.0), 15
	)
	_set_template_value_badge(
		_health_panel, _health_lbl, Rect2(113.0, 158.0, 64.0, 29.0),
		Rect2(32.0, 0.0, 26.0, 29.0), 15
	)
	_set_template_label_rect(_name_lbl, Rect2(20.0, 196.0, 160.0, 22.0), 15)
	_set_template_label_rect(_desc_lbl, Rect2(21.0, 225.0, 158.0, 39.0), 10)
	if _stats_container:
		_stats_container.visible = false

func _update_badge_visibilities() -> void:
	if _attack_panel:
		# A zero attack is still useful card information and keeps the left field
		# from looking unfinished.
		_attack_panel.visible = true
		_attack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _health_panel:
		_health_panel.visible = true
		_health_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _update_ui() -> void:
	super._update_ui()
	
	if _attack_lbl:
		_attack_lbl.text = str(attack)
	if _health_lbl:
		_health_lbl.text = str(health)

func _update_visuals() -> void:
	if card_template or _has_template_background():
		super._update_visuals()
	else:
		if not is_inside_tree():
			return
			
		var border_color = Color(0.55, 0.47, 0.38) # Rustic Stone/Brick Brown
		match rarity:
			Rarity.COMMON:
				border_color = Color(0.55, 0.47, 0.38)
			Rarity.RARE:
				border_color = Color(0.2, 0.5, 0.75)
			Rarity.EPIC:
				border_color = Color(0.65, 0.3, 0.8)
			Rarity.LEGENDARY:
				border_color = Color(0.9, 0.6, 0.1)
				
		var style_flat = StyleBoxFlat.new()
		style_flat.bg_color = Color(0.14, 0.11, 0.10) # Dark mud/earth background
		style_flat.border_width_left = 4
		style_flat.border_width_top = 4
		style_flat.border_width_right = 4
		style_flat.border_width_bottom = 4
		style_flat.border_color = border_color
		style_flat.corner_radius_top_left = 12
		style_flat.corner_radius_top_right = 12
		style_flat.corner_radius_bottom_left = 12
		style_flat.corner_radius_bottom_right = 12
		style_flat.shadow_color = Color(0, 0, 0, 0.35)
		style_flat.shadow_size = 6
		style_flat.shadow_offset = Vector2(0, 4)
		_frame_panel.add_theme_stylebox_override("panel", style_flat)

func _apply_upgrade(upgrade_card: UpgradeCard) -> void:
	EffectResolver.apply_skill_modifiers(self, upgrade_card)
