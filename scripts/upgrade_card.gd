class_name UpgradeCard extends BaseCard

@export_group("Upgrade Modifiers")
@export var bonus_attack: int = 1:
	set(val):
		bonus_attack = val
		_update_ui()
		_update_badge_visibilities()

@export var bonus_armor: int = 0:
	set(val):
		bonus_armor = val
		_update_ui()
		_update_badge_visibilities()

@export var bonus_health: int = 0:
	set(val):
		bonus_health = val
		_update_ui()
		_update_badge_visibilities()

## Valid targets for this upgrade, e.g. "Hero", "Settlement", "Any".
@export var allowed_targets: String = "Any":
	set(val):
		allowed_targets = val
		_update_ui()

@export var granted_traits: Array[String] = []
@export var granted_status: String = ""
@export var status_amount: int = 0
@export var status_duration: int = 1

# UI Nodes
var _stats_container: HBoxContainer = null
var _attack_panel: Panel = null
var _attack_lbl: Label = null
var _armor_panel: Panel = null
var _armor_lbl: Label = null
var _health_panel: Panel = null
var _health_lbl: Label = null
var _allowed_targets_lbl: Label = null

func _get_card_type_key() -> String:
	return "upgrades"

func _get_card_type_display_name() -> String:
	return "Beceri"

func can_target_card(target_card: Control) -> bool:
	if not target_card or not target_card.has_method("_apply_upgrade"):
		return false
	if target_card is BaseCard and not (target_card as BaseCard).can_attach_skill():
		return false

	var normalized_targets := allowed_targets.strip_edges().to_lower()
	match normalized_targets:
		"any", "both", "her ikisi", "hero/settlement", "kahraman/yapı", "kahraman/yapi":
			return target_card is HeroCard or target_card is SettlementCard
		"hero", "kahraman":
			return target_card is HeroCard
		"settlement", "structure", "building", "yerleşim", "yerlesim", "yapı", "yapi":
			return target_card is SettlementCard
		_:
			return false

func _apply_card_data(card_data: Dictionary) -> void:
	super._apply_card_data(card_data)
	bonus_attack = _get_int_from_card_data(card_data, "bonus_attack", bonus_attack)
	bonus_armor = _get_int_from_card_data(card_data, "bonus_armor", bonus_armor)
	bonus_health = _get_int_from_card_data(card_data, "bonus_health", bonus_health)
	allowed_targets = _get_string_from_card_data(card_data, "allowed_targets", allowed_targets)
	granted_status = _get_string_from_card_data(card_data, "granted_status", granted_status).strip_edges().to_lower()
	status_amount = _get_int_from_card_data(card_data, "status_amount", status_amount)
	status_duration = max(1, _get_int_from_card_data(card_data, "status_duration", status_duration))
	granted_traits.clear()
	var raw_traits: Variant = card_data.get("granted_tags", [])
	if raw_traits is Array:
		for raw_trait in raw_traits:
			var normalized_trait := str(raw_trait).strip_edges().to_lower()
			if not normalized_trait.is_empty() and normalized_trait not in granted_traits:
				granted_traits.append(normalized_trait)

func _create_ui_nodes_if_missing() -> void:
	# Build base card structure
	super._create_ui_nodes_if_missing()
	
	# Shrink description box to fit bottom modifiers
	if _desc_lbl:
		_desc_lbl.anchor_bottom = 0.80
		
	_stats_container = get_node_or_null("CardFrame/StatsContainer") as HBoxContainer
	_attack_panel = _get_existing_stat_badge("AttackBadge")
	_attack_lbl = _get_existing_stat_label("AttackBadge", "AttackLabel")
	_armor_panel = _get_existing_stat_badge("ArmorBadge")
	_armor_lbl = _get_existing_stat_label("ArmorBadge", "ArmorLabel")
	_health_panel = _get_existing_stat_badge("HealthBadge")
	_health_lbl = _get_existing_stat_label("HealthBadge", "HealthLabel")

	if not (_attack_panel and _attack_lbl and _armor_panel and _armor_lbl and _health_panel and _health_lbl):
		# Create stats container
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
		
		# 1. Attack Bonus Badge
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
		
		# 2. Armor Bonus Badge
		_armor_panel = Panel.new()
		_armor_panel.name = "ArmorBadge"
		_armor_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		_armor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var arm_style = StyleBoxFlat.new()
		arm_style.bg_color = Color(0.35, 0.35, 0.4)
		arm_style.border_width_left = 1
		arm_style.border_width_top = 1
		arm_style.border_width_right = 1
		arm_style.border_width_bottom = 1
		arm_style.border_color = Color(0.6, 0.6, 0.65)
		arm_style.corner_radius_top_left = 6
		arm_style.corner_radius_top_right = 6
		arm_style.corner_radius_bottom_left = 6
		arm_style.corner_radius_bottom_right = 6
		_armor_panel.add_theme_stylebox_override("panel", arm_style)
		_stats_container.add_child(_armor_panel)
		
		_armor_lbl = Label.new()
		_armor_lbl.name = "ArmorLabel"
		_armor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_armor_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_armor_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_armor_lbl.add_theme_font_size_override("font_size", 10)
		_armor_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		_armor_lbl.add_theme_constant_override("shadow_outline_size", 1)
		_armor_panel.add_child(_armor_lbl)
		
		# 3. Health Bonus Badge
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
	_style_stat_badge(_armor_panel, _armor_lbl)
	_style_stat_badge(_health_panel, _health_lbl)

	# Adjust initial badge visibilities
	_update_badge_visibilities()
	_allowed_targets_lbl = get_node_or_null("CardFrame/AllowedTargetsLabel") as Label
	if _desc_lbl and _allowed_targets_lbl:
		_desc_lbl.anchor_bottom = 0.72
	_style_readable_label(_allowed_targets_lbl)
	_apply_upgrade_template_layout()

func _apply_upgrade_template_layout() -> void:
	_set_template_value_badge(
		_gold_panel, _gold_lbl, Rect2(10.0, 11.0, 34.0, 34.0),
		Rect2(11.0, 0.0, 19.0, 34.0), 15
	)
	_set_template_control_rect(_art_texture, Rect2(19.0, 28.0, 162.0, 122.0))
	_set_template_label_rect(_allowed_targets_lbl, Rect2(37.0, 154.0, 58.0, 22.0), 9)
	_set_template_value_badge(
		_attack_panel, _attack_lbl, Rect2(98.0, 154.0, 24.0, 22.0),
		Rect2(9.0, 0.0, 12.0, 22.0), 10
	)
	_set_template_value_badge(
		_armor_panel, _armor_lbl, Rect2(127.0, 154.0, 24.0, 22.0),
		Rect2(9.0, 0.0, 12.0, 22.0), 10
	)
	_set_template_value_badge(
		_health_panel, _health_lbl, Rect2(156.0, 154.0, 24.0, 22.0),
		Rect2(9.0, 0.0, 12.0, 22.0), 10
	)
	_set_template_label_rect(_name_lbl, Rect2(20.0, 181.0, 160.0, 22.0), 15)
	_set_template_label_rect(_desc_lbl, Rect2(21.0, 213.0, 158.0, 50.0), 10)
	if _allowed_targets_lbl:
		_allowed_targets_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_allowed_targets_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _stats_container:
		_stats_container.visible = false

func _update_badge_visibilities() -> void:
	if _attack_panel:
		_attack_panel.visible = true
	if _armor_panel:
		_armor_panel.visible = true
	if _health_panel:
		_health_panel.visible = true

func _update_ui() -> void:
	super._update_ui()
	
	if _attack_lbl:
		_attack_lbl.text = ("+%d" % bonus_attack) if bonus_attack > 0 else "—"
		_attack_lbl.add_theme_color_override(
			"font_color",
			Color(1.0, 0.88, 0.56) if bonus_attack > 0 else Color(0.55, 0.53, 0.50, 0.45)
		)
	if _armor_lbl:
		_armor_lbl.text = ("+%d" % bonus_armor) if bonus_armor > 0 else "—"
		_armor_lbl.add_theme_color_override(
			"font_color",
			Color(0.68, 0.90, 1.0) if bonus_armor > 0 else Color(0.55, 0.53, 0.50, 0.45)
		)
	if _health_lbl:
		_health_lbl.text = ("+%d" % bonus_health) if bonus_health > 0 else "—"
		_health_lbl.add_theme_color_override(
			"font_color",
			Color(0.66, 0.96, 0.72) if bonus_health > 0 else Color(0.55, 0.53, 0.50, 0.45)
		)
	if _allowed_targets_lbl:
		_allowed_targets_lbl.text = _get_allowed_targets_display_text()
		_allowed_targets_lbl.add_theme_color_override("font_color", UI.CARD_TYPE_UPGRADE.lightened(0.35))

func _get_allowed_targets_display_text() -> String:
	match allowed_targets.strip_edges().to_lower():
		"hero", "kahraman":
			return "Kahraman"
		"settlement", "structure", "building", "yerleşim", "yerlesim", "yapı", "yapi":
			return "Yapı"
		"any", "both", "her ikisi", "hero/settlement", "kahraman/yapı", "kahraman/yapi":
			return "Tümü"
		_:
			return allowed_targets

func _update_visuals() -> void:
	if card_template or _has_template_background():
		super._update_visuals()
	else:
		if not is_inside_tree():
			return
			
		var border_color = Color(0.2, 0.6, 0.6) # Mechanical/Teal Copper
		match rarity:
			Rarity.COMMON:
				border_color = Color(0.2, 0.6, 0.6)
			Rarity.RARE:
				border_color = Color(0.1, 0.7, 0.9)
			Rarity.EPIC:
				border_color = Color(0.85, 0.25, 0.6)
			Rarity.LEGENDARY:
				border_color = Color(0.95, 0.5, 0.15)
				
		var style_flat = StyleBoxFlat.new()
		style_flat.bg_color = Color(0.09, 0.13, 0.14) # Metallic teal gray background
		style_flat.border_width_left = 4
		style_flat.border_width_top = 4
		style_flat.border_width_right = 4
		style_flat.border_width_bottom = 4
		style_flat.border_color = border_color
		style_flat.corner_radius_top_left = 12
		style_flat.corner_radius_top_right = 12
		style_flat.corner_radius_bottom_left = 12
		style_flat.corner_radius_bottom_right = 12
		style_flat.shadow_color = Color(0, 0, 0, 0.3)
		style_flat.shadow_size = 6
		style_flat.shadow_offset = Vector2(0, 4)
		_frame_panel.add_theme_stylebox_override("panel", style_flat)
