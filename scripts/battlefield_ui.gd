class_name BattlefieldUI extends Control

signal lane_state_changed(defender_id: int, lane_id: int, is_open: bool)
signal dominion_preview_changed(lane_results: Array)

const PAUSE_MENU_SCRIPT := preload("res://scripts/battlefield_pause_menu.gd")
const SAVE_SLOTS_PANEL_SCRIPT := preload("res://scripts/save_slots_panel.gd")
const ARENA_OVERLAY_SCRIPT := preload("res://scripts/battlefield_arena_overlay.gd")
const CARD_STAT_ICON_SCRIPT := preload("res://scripts/card_stat_icon.gd")
const SCENARIO_BRIEFING_PANEL_SCRIPT := preload("res://scripts/scenario_briefing_panel.gd")
const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")
const SCENARIO_OBJECTIVE_RESOLVER := preload("res://scripts/scenario_objective_resolver.gd")
const SCENARIO_MATCH_CONFIGURATOR := preload("res://scripts/scenario_match_configurator.gd")
const MATCH_ANALYSIS := preload("res://scripts/match_analysis.gd")
const MATCH_ANALYSIS_PANEL_SCRIPT := preload("res://scripts/match_analysis_panel.gd")
const ARENA_BACKDROP_TEXTURE := preload("res://images/environments/battlefield_factions_arena_blue_player.png")
const CARD_BACK_TEXTURE := preload("res://images/cards/card_back_fantasy.png")
const UI := preload("res://scripts/dark_fantasy_ui.gd")

@onready var turn_label = $HUD/TurnLabel
@onready var p1_energy_label = $HUD/P1EnergyLabel
@onready var p2_energy_label = $HUD/P2EnergyLabel
@onready var end_turn_button = $HUD/EndTurnButton
@onready var top_hud: TopHud = $TopHud
@onready var game_over_panel = $GameOverPanel
@onready var winner_label = $GameOverPanel/WinnerLabel

# HQ card nodes to sync health
@onready var p1_hq = $Player1Zone/HQSlot/P1_HQ
@onready var p2_hq = $Player2Zone/HQSlot/P2_HQ

@onready var game_manager = $GameManager
@onready var hud = $HUD
@onready var divider = $Divider
@onready var player1_zone = $Player1Zone
@onready var player2_zone = $Player2Zone
@onready var p1_hand = $Player1Zone/P1Hand
@onready var p2_hand = $Player2Zone/P2Hand
@onready var p1_grid = $Player1Zone/Grid
@onready var p2_grid = $Player2Zone/Grid
@onready var p1_hq_slot = $Player1Zone/HQSlot
@onready var p2_hq_slot = $Player2Zone/HQSlot

const HAND_CARD_BASE_SIZE := Vector2(200.0, 280.0)
const HAND_CARD_MIN_SCALE := 0.28
const HAND_CARD_MAX_SCALE := 0.64
const HAND_CARD_HOVER_TARGET_SCALE := 0.82
const HAND_CARD_OVERLAP_RATIO := 1.02
const HAND_DOCK_MIN_HEIGHT := 164.0
const HAND_DOCK_MAX_HEIGHT := 202.0
const HAND_DOCK_Z_INDEX := 100
const DRAW_ANIMATION_Z_INDEX := HAND_DOCK_Z_INDEX + 20
const OPPONENT_HAND_MIN_WIDTH := 220.0
const OPPONENT_HAND_MAX_WIDTH := 260.0
const DECK_PANEL_SIZE := Vector2(92.0, 128.0)
const DECK_HQ_HORIZONTAL_GAP := 184.0
const FIELD_NAME_BADGE_SIZE := Vector2(150.0, 42.0)
const FIELD_NAME_HQ_GAP := 10.0
const EFFECT_FIELD_MOUNT_SIZE := Vector2(96.0, 134.0)
const EFFECT_HQ_HORIZONTAL_GAP := 164.0
const TOP_HUD_SOURCE_SIZE := Vector2(720.0, 112.0)
const TOP_HUD_MIN_WIDTH := 620.0
const TOP_HUD_MAX_WIDTH := 790.0
const CARD_PREVIEW_DELAY := 0.12
const CARD_PREVIEW_SCALE := 1.08
const EFFECT_OFFER_CARD_SCALE := Vector2(0.84, 0.84)
const EFFECT_PANEL_CARD_SCALE := Vector2(0.48, 0.48)
const TOAST_PANEL_SIZE := Vector2(500.0, 68.0)
const TOAST_DURATION := 2.8
const CARD_DISSOLVE_SHADER := preload("res://shaders/card_dissolve.gdshader")
const CARD_ACTION_PANEL_SIZE := Vector2(520.0, 388.0)
const PHASE_BANNER_SIZE := Vector2(390.0, 52.0)
const PREFERENCES_PATH := "user://settings.cfg"
const ONBOARDING_SETTINGS_PATH := "user://darwine_settings.cfg"
const SETTINGS_SECTION := "onboarding"
const TUTORIAL_COMPLETED_KEY := "first_match_tutorial_completed"
const NETWORK_CARD_ID_META := "network_card_id"
const INITIAL_HAND_DRAW_COUNT := GameRules.STARTING_HAND_SIZE
const INITIAL_DRAW_DELAY := 0.045
const BOARD_SLOT_SIZE := Vector2(96.0, 134.0)
const BOARD_SLOT_GAP := Vector2(42.0, 12.0)
const BOARD_GRID_COLUMNS := 3
const BOARD_GRID_ROWS := 3
const BOARD_CARD_BASE_SCALE := 0.46
const BOARD_HQ_GAP := 18.0
const BOARD_CENTER_GAP := 96.0
const BOARD_WORLD_PADDING := Vector2(40.0, 70.0)
const BOARD_MIN_ZOOM := 0.32
const BOARD_MAX_ZOOM := 1.60
const BOARD_DEFAULT_FOCUS_ZOOM := 0.56
const BOARD_ZOOM_STEP := 1.12
const BOARD_HORIZONTAL_OVERSCROLL_MIN := 190.0
const BOARD_HORIZONTAL_OVERSCROLL_VIEW_RATIO := 0.34
const BOARD_HORIZONTAL_NUDGE_SCREEN_DISTANCE := 170.0
const COMBAT_AFTERMATH_SECONDS := 0.36
const BOARD_IMPACT_SHAKE_SECONDS := 0.23
const AUTO_ATTACK_MAX_ATTACKS := 18
const AUTO_ATTACK_NETWORK_TIMEOUT_MSEC := 10000
const BOARD_GRID_BASE_SIZE := Vector2(
	(BOARD_SLOT_SIZE.x * float(BOARD_GRID_COLUMNS)) + (BOARD_SLOT_GAP.x * float(BOARD_GRID_COLUMNS - 1)),
	(BOARD_SLOT_SIZE.y * float(BOARD_GRID_ROWS)) + (BOARD_SLOT_GAP.y * float(BOARD_GRID_ROWS - 1))
)

const CARD_TEMPLATE_SCENES := {
	"heroes": {
		"COMMON": preload("res://scenes/card_templates/hero_common.tscn"),
		"RARE": preload("res://scenes/card_templates/hero_rare.tscn"),
		"EPIC": preload("res://scenes/card_templates/hero_epic.tscn"),
		"LEGENDARY": preload("res://scenes/card_templates/hero_legendary.tscn"),
	},
	"settlements": {
		"COMMON": preload("res://scenes/card_templates/settlement_common.tscn"),
		"RARE": preload("res://scenes/card_templates/settlement_rare.tscn"),
		"EPIC": preload("res://scenes/card_templates/settlement_epic.tscn"),
		"LEGENDARY": preload("res://scenes/card_templates/settlement_legendary.tscn"),
	},
	"special_powers": {
		"COMMON": preload("res://scenes/card_templates/special_power_common.tscn"),
		"RARE": preload("res://scenes/card_templates/special_power_rare.tscn"),
		"EPIC": preload("res://scenes/card_templates/special_power_epic.tscn"),
		"LEGENDARY": preload("res://scenes/card_templates/special_power_legendary.tscn"),
	},
	"upgrades": {
		"COMMON": preload("res://scenes/card_templates/upgrade_common.tscn"),
		"RARE": preload("res://scenes/card_templates/upgrade_rare.tscn"),
		"EPIC": preload("res://scenes/card_templates/upgrade_epic.tscn"),
		"LEGENDARY": preload("res://scenes/card_templates/upgrade_legendary.tscn"),
	},
	"effects": {
		"COMMON": preload("res://scenes/card_templates/effect_common.tscn"),
		"RARE": preload("res://scenes/card_templates/effect_rare.tscn"),
		"EPIC": preload("res://scenes/card_templates/effect_epic.tscn"),
		"LEGENDARY": preload("res://scenes/card_templates/effect_legendary.tscn"),
	},
}

var _hand_card_scale := 0.40
var _opponent_hand_card_scale := 0.28
var _player_decks: Dictionary = {
	1: [],
	2: [],
}
var _deck_panels: Dictionary = {}
var _deck_labels: Dictionary = {}
var _is_dealing_initial_hands := false
var _is_draw_animation_running := false
var _pending_effect_draws: Array[Dictionary] = []
var _effect_draw_queue_running := false
var _is_confirming_selection := false
var _phase_selected_cards: Array[BaseCard] = []
var _discard_required := 0
var _phase_label: Label = null
var _preparation_token_button: Button = null
var _tactical_supply_button: Button = null
var _auto_attack_panel: Panel = null
var _auto_attack_checkbox: CheckBox = null
var _auto_attack_enabled := false
var _auto_attack_running := false
var _auto_attack_sequence_generation := 0
var _auto_attack_hovered := false
var _pause_menu: BattlefieldPauseMenu = null
var _save_slots_panel: SaveSlotsPanel = null
var _arena_overlay: BattlefieldArenaOverlay = null
var _arena_texture: TextureRect = null
var _phase_banner_panel: Panel = null
var _phase_banner_label: Label = null
var _phase_banner_tween: Tween = null
var _feedback_clip: Control = null
var _feedback_layer: BattlefieldFeedbackLayer = null
var _feedback_audio: FeedbackAudio = null
var _feedback_attack_source_ref: WeakRef = null
var _feedback_attack_target_ref: WeakRef = null
var _transient_feedback_anchors: Array[Dictionary] = []
var _tutorial_overlay: FirstMatchTutorial = null
var _rules_reference_panel: RulesReferencePanel = null
var floating_feedback_count := 0
var death_feedback_count := 0
var _selected_attacker: BaseCard = null
var _legal_combat_target: CardSlot = null
var _selected_deployment_card: BaseCard = null
var _legal_deployment_targets: Array[CardSlot] = []
var _selected_effect_card: BaseCard = null
var _legal_effect_targets: Array[CardSlot] = []
var _selected_hand_tactic_card: SpecialPowerCard = null
var _legal_hand_tactic_targets: Array[BaseCard] = []
var _is_hand_tactic_resolving := false
var _selected_action_card: BaseCard = null
var _selected_mover: BaseCard = null
var _legal_movement_targets: Array[CardSlot] = []
var _visible_action_branches: Array[Dictionary] = []
var _card_action_panel: Panel = null
var _card_action_title: Label = null
var _card_action_details: Label = null
var _move_action_button: Button = null
var _upgrade_action_button: Button = null
var _branch_action_buttons: Array[Button] = []
var _cancel_action_button: Button = null
var _preview_source_card: BaseCard = null
var _preview_card: BaseCard = null
var _preview_displayed_source_card: BaseCard = null
var _preview_hover_token := 0
var _toast_panel: Panel = null
var _toast_label: Label = null
var _toast_kicker_label: Label = null
var _toast_emblem_label: Label = null
var _toast_accent_bar: Panel = null
var _toast_style: StyleBoxFlat = null
var _toast_tween: Tween = null
var _p1_hq_health_label: Label = null
var _p2_hq_health_label: Label = null
var _match_flow_bar: Panel = null
var _flow_own_hq_label: Label = null
var _flow_enemy_hq_label: Label = null
var _flow_turn_pill: Label = null
var _flow_phase_labels: Dictionary = {}
var _flow_dominion_label: Label = null
var _battle_log_toggle: Button = null
var _battle_log_panel: PanelContainer = null
var _battle_log_list: VBoxContainer = null
var _battle_log_entries: Array[Dictionary] = []
var _battle_log_expanded := false
var _recent_feedback_stamps: Dictionary = {}
var _ai_spotlight_layer: Control = null
var _end_turn_pulse_tween: Tween = null
var _game_over_restart_button: Button = null
var _game_over_main_menu_button: Button = null
var _game_over_subtitle_label: Label = null
var _game_over_reward_label: Label = null
var _game_over_stat_values: Dictionary = {}
var _game_over_stat_titles: Dictionary = {}
var _game_over_eyebrow_label: Label = null
var _game_over_analysis_panel: Variant = null
var _hud_background: Panel = null
var _battlefield_static_hud: Control = null
var _battlefield_world_objects: Control = null
var _hand_dock: Control = null
var _hand_dock_backdrop: Panel = null
var _opponent_hand_backdrop: Panel = null
var _preview_panel: Panel = null
var _preview_mount: Control = null
var _preview_hint_label: Label = null
var _preview_title_label: Label = null
var _preview_details_panel: Panel = null
var _preview_details_header: Label = null
var _preview_details_label: RichTextLabel = null
var _zone_labels: Dictionary = {}
var _zone_styles: Dictionary = {}
var _deck_rngs: Dictionary = {}
var _ai_controller: AIController = null
var _match_telemetry: MatchTelemetry = null
var _combat_sequence_active := false
var _combat_sequence_attacker: BaseCard = null
var _combat_sequence_target: BaseCard = null
var _board_navigation_panel: Panel = null
var _board_navigation_toggle_button: Button = null
var _board_navigation_content: VBoxContainer = null
var _board_navigation_expanded := false
var _board_zoom_label: Label = null
var _board_view_rect := Rect2()
var _board_world_size := Vector2.ZERO
var _p1_zone_world_rect := Rect2()
var _p2_zone_world_rect := Rect2()
var _lane_board_world_rect := Rect2()
var _platform_world_rect := Rect2()
var _board_divider_world_y := 0.0
var _board_zoom := 1.0
var _board_fit_zoom := 1.0
var _board_camera_center := Vector2.ZERO
var _board_impact_offset := Vector2.ZERO
var _board_impact_tween: Tween = null
var impact_shake_count := 0
var last_impact_shake_kind := ""
var _board_camera_initialized := false
var _board_view_was_adjusted := false
var _is_board_panning := false
var _board_pan_button := MOUSE_BUTTON_NONE
var _last_board_pointer_position := Vector2.ZERO
var _board_pan_tween: Tween = null
var _next_network_card_serial := 1
var _applied_network_revision := -1
var _network_winner_id := 0
var _network_match_summary: Dictionary = {}
var _profile_match_recorded := false
var _effect_selection_overlay: Control = null
var _effect_selection_panel: PanelContainer = null
var _effect_selection_title: Label = null
var _effect_selection_status: Label = null
var _effect_offer_row: HBoxContainer = null
var _effect_handoff: VBoxContainer = null
var _effect_handoff_label: Label = null
var _effect_handoff_button: Button = null
var _effect_offer_cards: Array[EffectCard] = []
var _effect_offer_stages: Dictionary = {}
var _effect_confirm_button: Button = null
var _selected_effect_offer_id := ""
var _effect_panel: Control = null
var _effect_panel_own_mount: Control = null
var _effect_panel_enemy_mount: Control = null
var _effect_panel_own_label: Label = null
var _effect_panel_enemy_label: Label = null
var _effect_panel_state_label: Label = null
var _effect_panel_own_card: EffectCard = null
var _effect_panel_rendered_card_id := ""
var _field_resource_badges: Dictionary = {}
var _field_energy_labels: Dictionary = {}
var _field_health_labels: Dictionary = {}
var _field_name_badges: Dictionary = {}
var _field_name_labels: Dictionary = {}
var _field_name_styles: Dictionary = {}
var _field_timer_badge: PanelContainer = null
var _field_timer_icon: Control = null
var _field_timer_label: Label = null
var _field_timer_style: StyleBoxFlat = null
var _field_own_energy_badge: PanelContainer = null
var _field_own_energy_icon: Control = null
var _field_own_energy_label: Label = null
var _field_own_energy_style: StyleBoxFlat = null
var _field_own_health_badge: PanelContainer = null
var _field_own_health_icon: Control = null
var _field_own_health_label: Label = null
var _field_own_health_style: StyleBoxFlat = null
var _field_round_badge: PanelContainer = null
var _field_round_label: Label = null
var _field_round_style: StyleBoxFlat = null
var _field_dominion_scores: Dictionary = {1: 0, 2: 0}
var _field_dominion_target := GameRules.DOMINION_SCORE_TARGET
var _active_match_repository := ActiveMatchRepository.new()
var _resume_snapshot: Dictionary = {}
var _graveyards: Dictionary = {1: [], 2: []}
var _autosave_pending := false
var _restoring_active_match := false
var _active_match_completed := false
var _scenario_briefing_panel: Variant = null
var _scenario_objectives_button: Button = null
var _scenario_refresh_timer: Timer = null
var _scenario_definition: Dictionary = {}
var _scenario_evaluation: Dictionary = {}

func _ready() -> void:
	theme = UI.create_theme()
	if MatchSetup.match_seed == 0:
		MatchSetup.configure_local()
	if _can_persist_active_match():
		if MatchSetup.save_slot_id.is_empty():
			MatchSetup.set_save_slot(MatchSetup.DEFAULT_SAVE_SLOT_ID, MatchSetup.match_name)
		_active_match_repository.configure_slot(MatchSetup.save_slot_id, MatchSetup.save_slot_name)
	_hide_legacy_turn_gold_labels()
	if top_hud:
		top_hud.visible = false
	_create_responsive_chrome()
	_style_end_turn_button()
	_create_phase_ui_nodes()
	_create_effect_selection_overlay()
	_create_feedback_systems()
	_create_phase_banner()
	_create_help_overlays()
	_create_pause_menu()
	_create_save_slots_panel()
	_create_card_action_panel()
	_create_deck_ui_nodes()
	_create_toast_ui_nodes()
	_create_match_flow_chrome()
	_style_game_over_panel()
	_create_scenario_interface()
	_connect_slot_signals()
	_assign_static_network_ids()
	if not MatchSetup.is_multiplayer_client() and MatchSetup.has_resume_snapshot():
		_resume_snapshot = MatchSetup.take_resume_snapshot()
	if not MatchSetup.is_multiplayer_client() and _resume_snapshot.is_empty():
		_prepare_player_decks()
	_clear_starting_hand_cards()
	_is_dealing_initial_hands = _resume_snapshot.is_empty()

	# Connect to GameManager signals
	if game_manager:
		game_manager.turn_changed.connect(_on_turn_changed)
		game_manager.turn_time_changed.connect(_on_turn_time_changed)
		game_manager.turn_time_expired.connect(_on_turn_time_expired)
		game_manager.phase_changed.connect(_on_phase_changed)
		game_manager.energy_changed.connect(_on_energy_changed)
		game_manager.turn_draw_requested.connect(_on_turn_draw_requested)
		game_manager.effect_draw_requested.connect(_on_effect_draw_requested)
		game_manager.mulligan_completed.connect(_on_mulligan_completed)
		game_manager.effect_selection_started.connect(_on_effect_selection_started)
		game_manager.effect_selection_player_changed.connect(_on_effect_selection_player_changed)
		game_manager.effect_card_selected.connect(_on_effect_card_selected)
		game_manager.effect_selection_completed.connect(_on_effect_selection_completed)
		game_manager.effect_trigger_state_changed.connect(_on_effect_trigger_state_changed)
		game_manager.preparation_token_changed.connect(_on_preparation_token_changed)
		game_manager.card_played.connect(_on_card_played)
		game_manager.attack_declared.connect(_on_attack_declared)
		game_manager.effect_resolved.connect(_on_effect_resolved)
		game_manager.card_destroyed.connect(_on_card_destroyed)
		game_manager.experience_changed.connect(_on_experience_changed)
		game_manager.card_leveled_up.connect(_on_card_leveled_up)
		game_manager.card_moved.connect(_on_card_moved)
		game_manager.round_completed.connect(_on_round_completed)
		game_manager.dominion_score_changed.connect(_on_dominion_score_changed)
		game_manager.dominion_round_resolved.connect(_on_dominion_round_resolved)
		game_manager.game_over.connect(_on_game_over)
		game_manager.hq_health_changed.connect(_on_hq_health_changed)
		if top_hud:
			top_hud.set_perspective_player(MatchSetup.human_player_id)
			top_hud.set_ruleset(MatchSetup.ruleset)
		
		# Set initial state
		_on_turn_changed(game_manager.active_player_id)
		for player_id in GameRules.PLAYER_IDS:
			_on_energy_changed(
				player_id,
				int(game_manager.player_current_energy[player_id]),
				int(game_manager.player_max_energy[player_id]),
				int(game_manager.player_temporary_energy[player_id])
			)
		_on_phase_changed(game_manager.current_phase)
		for player_id in GameRules.PLAYER_IDS:
			_on_hq_health_changed(
				player_id,
				int(game_manager.player_hq_health.get(player_id, GameRules.HEADQUARTERS_HEALTH)),
				GameRules.HEADQUARTERS_HEALTH
			)
			_on_dominion_score_changed(
				player_id,
				int(game_manager.player_dominion_score.get(player_id, 0)),
				GameRules.DOMINION_SCORE_TARGET
			)
		_initialize_match_services()
		_connect_active_match_autosave()
		
	# Setup button connection
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	_preparation_token_button.pressed.connect(_on_preparation_token_pressed)
	if _tactical_supply_button:
		_tactical_supply_button.pressed.connect(_on_tactical_supply_pressed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Hide game over panel by default
	game_over_panel.visible = false
	_apply_responsive_layout()
	_refresh_lane_visuals()
	_update_hq_labels()
	_update_deck_ui()
	if MatchSetup.is_multiplayer_client():
		var network_manager := _get_network_manager()
		if network_manager:
			network_manager.notify_battlefield_ready(self)
	elif not _resume_snapshot.is_empty():
		call_deferred("_restore_active_match_on_ready")
	else:
		call_deferred("_deal_initial_hands")
	_connect_network_session_signals()


func _restore_active_match_on_ready() -> void:
	var snapshot := _resume_snapshot.duplicate(true)
	_resume_snapshot.clear()
	var result := restore_active_match_snapshot(snapshot)
	if not MatchSetup.is_multiplayer_server():
		return
	var network_manager := _get_network_manager()
	if not network_manager:
		return
	if bool(result.get("success", false)):
		network_manager.notify_battlefield_ready(self)
	else:
		push_error("Otoriter çevrimiçi maç snapshot'ı savaş alanına uygulanamadı: %s" % str(result.get("error", "bilinmeyen hata")))
		network_manager.call("_reset_server_lobby_after_abandon")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _scenario_briefing_panel and _scenario_briefing_panel.is_open():
			return
		if (_tutorial_overlay and _tutorial_overlay.is_open()) or (_rules_reference_panel and _rules_reference_panel.is_open()):
			return
		if game_over_panel and game_over_panel.visible:
			return
		if cancel_active_interaction(true):
			get_viewport().set_input_as_handled()
			return
		_open_pause_menu()
		get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or _is_text_entry_focused():
		return
	match key_event.keycode:
		KEY_SPACE:
			if _has_active_interaction_selection() or not end_turn_button or end_turn_button.disabled:
				return
			_on_end_turn_pressed()
			get_viewport().set_input_as_handled()
		KEY_F:
			if (
				get_tree().paused
				or (game_over_panel and game_over_panel.visible)
				or (_scenario_briefing_panel and _scenario_briefing_panel.is_open())
				or (_tutorial_overlay and _tutorial_overlay.is_open())
				or (_rules_reference_panel and _rules_reference_panel.is_open())
				or (_pause_menu and _pause_menu.visible)
			):
				return
			_fit_board_view()
			get_viewport().set_input_as_handled()

func _is_text_entry_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox

func _input(event: InputEvent) -> void:
	if _board_view_rect.size.x <= 0.0 or _board_view_rect.size.y <= 0.0:
		return
	if game_over_panel and game_over_panel.visible:
		_is_board_panning = false
		_board_pan_button = MOUSE_BUTTON_NONE
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			if cancel_active_interaction(true):
				get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			var can_start_pan := (
				mouse_event.button_index == MOUSE_BUTTON_MIDDLE
				or _can_start_left_board_pan(mouse_event.position)
			)
			if mouse_event.pressed and can_start_pan and _board_view_rect.has_point(mouse_event.position):
				_cancel_board_pan_tween()
				_is_board_panning = true
				_board_pan_button = mouse_event.button_index
				_last_board_pointer_position = mouse_event.position
				get_viewport().set_input_as_handled()
			elif not mouse_event.pressed and _is_board_panning and mouse_event.button_index == _board_pan_button:
				_is_board_panning = false
				_board_pan_button = MOUSE_BUTTON_NONE
				get_viewport().set_input_as_handled()
			return

		if mouse_event.pressed and _board_view_rect.has_point(mouse_event.position):
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if mouse_event.shift_pressed:
					_nudge_board_horizontal(-1.0)
				else:
					_zoom_board_at(mouse_event.position, _board_zoom * BOARD_ZOOM_STEP)
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if mouse_event.shift_pressed:
					_nudge_board_horizontal(1.0)
				else:
					_zoom_board_at(mouse_event.position, _board_zoom / BOARD_ZOOM_STEP)
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				_nudge_board_horizontal(-1.0)
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				_nudge_board_horizontal(1.0)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_board_panning:
		var motion := event as InputEventMouseMotion
		var pointer_delta := motion.position - _last_board_pointer_position
		_last_board_pointer_position = motion.position
		_board_camera_center -= pointer_delta / maxf(_board_zoom, 0.001)
		_board_view_was_adjusted = true
		_clamp_board_camera()
		_apply_board_camera_transform()
		get_viewport().set_input_as_handled()

func _can_start_left_board_pan(screen_position: Vector2) -> bool:
	if not _board_view_rect.has_point(screen_position):
		return false
	if get_tree() and get_tree().paused:
		return false
	if (
		(_scenario_briefing_panel and _scenario_briefing_panel.is_open())
		or (_tutorial_overlay and _tutorial_overlay.is_open())
		or (_rules_reference_panel and _rules_reference_panel.is_open())
	):
		return false
	if _pause_menu and _pause_menu.is_open():
		return false

	# _input runs before Control._gui_input. Querying the hovered leaf lets an
	# empty terrain press start panning without stealing clicks from cards,
	# slots, buttons, or the inspector.
	var hovered_control := get_viewport().gui_get_hovered_control()
	if not hovered_control or not hovered_control.get_global_rect().has_point(screen_position):
		return true
	return hovered_control == divider

func _exit_tree() -> void:
	if not _active_match_completed:
		_save_active_match("çıkış", false)
	if get_tree() and get_tree().paused:
		get_tree().paused = false

func _initialize_match_services() -> void:
	if not game_manager:
		return
	if MatchSetup.is_ai_match():
		_ai_controller = AIController.new()
		_ai_controller.name = "AIController"
		add_child(_ai_controller)
		_ai_controller.setup(self, game_manager)
		_ai_controller.thinking_changed.connect(_on_ai_thinking_changed)
	_match_telemetry = MatchTelemetry.new()
	_match_telemetry.name = "MatchTelemetry"
	add_child(_match_telemetry)
	var should_write := (
		MatchSetup.is_ai_match()
		and MatchSetup.telemetry_to_disk
		and DisplayServer.get_name() != "headless"
	)
	_match_telemetry.setup(game_manager, _ai_controller, should_write)


func _create_scenario_interface() -> void:
	if not MatchSetup.is_scenario_match():
		return
	var catalog_result := SCENARIO_CATALOG.load_catalog()
	if not bool(catalog_result.get("success", false)):
		push_warning("Komutan Seferi hedefleri yüklenemedi: %s" % str(catalog_result.get("error", "katalog hatası")))
		return
	_scenario_definition = SCENARIO_CATALOG.get_scenario(MatchSetup.get_scenario_id())
	if _scenario_definition.is_empty():
		push_warning("Etkin Komutan Seferi senaryosu katalogda bulunamadı: %s" % MatchSetup.get_scenario_id())
		return
	_scenario_briefing_panel = SCENARIO_BRIEFING_PANEL_SCRIPT.new()
	add_child(_scenario_briefing_panel)

	_scenario_objectives_button = Button.new()
	_scenario_objectives_button.name = "ScenarioObjectivesButton"
	_scenario_objectives_button.text = tr("CAMPAIGN OBJECTIVES 0/0")
	_scenario_objectives_button.add_theme_font_size_override("font_size", 12)
	UI.style_button(_scenario_objectives_button, UI.FROST, false, true, true)
	_scenario_objectives_button.pressed.connect(_show_scenario_briefing)
	hud.add_child(_scenario_objectives_button)

	_scenario_refresh_timer = Timer.new()
	_scenario_refresh_timer.name = "ScenarioObjectiveRefreshTimer"
	_scenario_refresh_timer.wait_time = 0.5
	_scenario_refresh_timer.one_shot = false
	_scenario_refresh_timer.autostart = true
	_scenario_refresh_timer.timeout.connect(_refresh_scenario_objectives)
	add_child(_scenario_refresh_timer)
	_refresh_scenario_objectives()


func _show_scenario_briefing() -> void:
	if (
		not _scenario_briefing_panel
		or _scenario_definition.is_empty()
		or (game_over_panel and game_over_panel.visible)
	):
		return
	var summary := _get_current_match_summary(0)
	_scenario_briefing_panel.open_panel(
		_scenario_definition,
		MatchSetup.get_scenario_context(),
		summary,
		MatchSetup.human_player_id
	)


func _maybe_show_scenario_briefing() -> void:
	if DisplayServer.get_name() == "headless" or not MatchSetup.is_scenario_match():
		return
	_show_scenario_briefing()


func _refresh_scenario_objectives() -> void:
	if not _scenario_briefing_panel or _scenario_definition.is_empty():
		return
	var winner_id := _network_winner_id if _network_winner_id in GameRules.PLAYER_IDS else 0
	var summary := _get_current_match_summary(winner_id)
	_scenario_evaluation = SCENARIO_OBJECTIVE_RESOLVER.evaluate(
		MatchSetup.get_scenario_context(),
		summary,
		MatchSetup.human_player_id
	)
	_scenario_briefing_panel.update_match_state(summary, MatchSetup.human_player_id)
	if _scenario_objectives_button:
		_scenario_objectives_button.text = tr("CAMPAIGN OBJECTIVES %d/%d") % [
			int(_scenario_evaluation.get("completed_required_count", 0)),
			int(_scenario_evaluation.get("required_count", 0)),
		]


func _on_ai_thinking_changed(_player_id: int, _is_thinking: bool) -> void:
	_refresh_phase_ui()

func _create_responsive_chrome() -> void:
	_create_arena_backdrop()
	_create_battlefield_static_hud()
	_create_battlefield_world_objects()

	_hud_background = Panel.new()
	_hud_background.name = "SidebarBackground"
	_hud_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_background.add_theme_stylebox_override("panel", _build_sidebar_style())
	hud.add_child(_hud_background)
	hud.move_child(_hud_background, 0)

	_create_zone_chrome(player1_zone, 1, _get_team_accent(1))
	_create_zone_chrome(player2_zone, 2, _get_team_accent(2))
	_create_battlefield_status_ui()
	_create_hand_dock()
	_create_effect_card_panel()
	_create_card_preview_panel()
	_create_board_navigation()


func _create_battlefield_static_hud() -> void:
	_battlefield_static_hud = Control.new()
	_battlefield_static_hud.name = "BattlefieldStaticHUD"
	_battlefield_static_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battlefield_static_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battlefield_static_hud.clip_contents = false
	add_child(_battlefield_static_hud)


func _create_battlefield_world_objects() -> void:
	_battlefield_world_objects = Control.new()
	_battlefield_world_objects.name = "BattlefieldWorldObjects"
	_battlefield_world_objects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battlefield_world_objects.clip_contents = false
	add_child(_battlefield_world_objects)


func _create_effect_selection_overlay() -> void:
	_effect_selection_overlay = Control.new()
	_effect_selection_overlay.name = "EffectSelectionOverlay"
	_effect_selection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effect_selection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_effect_selection_overlay.z_index = 900
	add_child(_effect_selection_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.006, 0.010, 0.96)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_effect_selection_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effect_selection_overlay.add_child(center)
	_effect_selection_panel = PanelContainer.new()
	_effect_selection_panel.name = "EffectSelectionPanel"
	_effect_selection_panel.custom_minimum_size = Vector2(1040.0, 650.0)
	_effect_selection_panel.add_theme_stylebox_override("panel", UI.panel_style(UI.BRASS_BRIGHT, 14.0, 1.0))
	center.add_child(_effect_selection_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	_effect_selection_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var kicker := Label.new()
	kicker.text = "MAÇ BAŞLANGICI  •  GİZLİ SEÇİM"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_title(kicker, UI.BRASS_BRIGHT)
	kicker.add_theme_font_size_override("font_size", 13)
	content.add_child(kicker)
	_effect_selection_title = Label.new()
	_effect_selection_title.name = "EffectSelectionTitle"
	_effect_selection_title.text = "ETKİ KARTINI SEÇ"
	_effect_selection_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_title(_effect_selection_title, UI.PARCHMENT)
	_effect_selection_title.add_theme_font_size_override("font_size", 30)
	content.add_child(_effect_selection_title)
	_effect_selection_status = Label.new()
	_effect_selection_status.name = "EffectSelectionStatus"
	_effect_selection_status.text = "Üç tekliften biri maç boyunca etkin kalacak."
	_effect_selection_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_selection_status.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
	_effect_selection_status.add_theme_font_size_override("font_size", 14)
	_effect_selection_status.add_theme_color_override("font_color", UI.TEXT_MUTED)
	content.add_child(_effect_selection_status)

	_effect_offer_row = HBoxContainer.new()
	_effect_offer_row.name = "EffectOfferRow"
	_effect_offer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_effect_offer_row.add_theme_constant_override("separation", 18)
	_effect_offer_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_effect_offer_row)
	_effect_confirm_button = Button.new()
	_effect_confirm_button.name = "ConfirmEffectChoiceButton"
	_effect_confirm_button.text = "ÖNCE BİR KART SEÇ"
	_effect_confirm_button.custom_minimum_size = Vector2(340.0, 54.0)
	_effect_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_effect_confirm_button.disabled = true
	UI.style_button(_effect_confirm_button, UI.BRASS_BRIGHT, false, false, true)
	_effect_confirm_button.pressed.connect(_confirm_effect_offer_selection)
	content.add_child(_effect_confirm_button)

	_effect_handoff = VBoxContainer.new()
	_effect_handoff.name = "EffectHandoff"
	_effect_handoff.alignment = BoxContainer.ALIGNMENT_CENTER
	_effect_handoff.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_effect_handoff.add_theme_constant_override("separation", 22)
	content.add_child(_effect_handoff)
	_effect_handoff_label = Label.new()
	_effect_handoff_label.name = "EffectHandoffLabel"
	_effect_handoff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_handoff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_effect_handoff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_handoff_label.custom_minimum_size = Vector2(700.0, 160.0)
	UI.style_title(_effect_handoff_label, UI.PARCHMENT)
	_effect_handoff_label.add_theme_font_size_override("font_size", 24)
	_effect_handoff.add_child(_effect_handoff_label)
	_effect_handoff_button = Button.new()
	_effect_handoff_button.name = "RevealEffectOffersButton"
	_effect_handoff_button.text = "TEKLİFLERİ GÖSTER"
	_effect_handoff_button.custom_minimum_size = Vector2(360.0, 60.0)
	UI.style_button(_effect_handoff_button, UI.BRASS_BRIGHT, false, false, true)
	_effect_handoff_button.pressed.connect(_reveal_effect_offers)
	_effect_handoff.add_child(_effect_handoff_button)
	_effect_selection_overlay.visible = false


func _create_effect_card_panel() -> void:
	# This is a transparent world-space holder, not a screen-space UI panel.
	# Its two children read as physical cards placed beside the Headquarters.
	_effect_panel = Control.new()
	_effect_panel.name = "EffectCardFieldObjects"
	_effect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_panel.z_index = 4
	_battlefield_world_objects.add_child(_effect_panel)

	var title := Label.new()
	title.name = "EffectPanelTitle"
	title.visible = false
	_effect_panel.add_child(title)

	_effect_panel_own_mount = Control.new()
	_effect_panel_own_mount.name = "OwnEffectMount"
	_effect_panel_own_mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_panel.add_child(_effect_panel_own_mount)
	_effect_panel_enemy_mount = Control.new()
	_effect_panel_enemy_mount.name = "EnemyEffectMount"
	_effect_panel_enemy_mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_panel.add_child(_effect_panel_enemy_mount)

	_effect_panel_own_label = Label.new()
	_effect_panel_own_label.name = "OwnEffectLabel"
	_effect_panel_own_label.text = "SENİN ETKİN"
	_effect_panel_own_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_panel_own_label.clip_text = true
	_effect_panel_own_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_effect_panel_own_label.add_theme_font_size_override("font_size", 9)
	_effect_panel_own_label.add_theme_color_override("font_color", UI.TEAM_PLAYER)
	_effect_panel_own_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_effect_panel_own_label.add_theme_constant_override("outline_size", 3)
	_effect_panel.add_child(_effect_panel_own_label)
	_effect_panel_enemy_label = Label.new()
	_effect_panel_enemy_label.name = "EnemyEffectLabel"
	_effect_panel_enemy_label.text = "RAKİP  •  GİZLİ"
	_effect_panel_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_panel_enemy_label.clip_text = true
	_effect_panel_enemy_label.add_theme_font_size_override("font_size", 9)
	_effect_panel_enemy_label.add_theme_color_override("font_color", UI.TEXT_MUTED)
	_effect_panel_enemy_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_effect_panel_enemy_label.add_theme_constant_override("outline_size", 3)
	_effect_panel.add_child(_effect_panel_enemy_label)
	_effect_panel_state_label = Label.new()
	_effect_panel_state_label.name = "OwnEffectState"
	_effect_panel_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_panel_state_label.add_theme_font_size_override("font_size", 8)
	_effect_panel_state_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.92))
	_effect_panel_state_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_effect_panel_state_label.add_theme_constant_override("outline_size", 3)
	_effect_panel.add_child(_effect_panel_state_label)

	var enemy_back := TextureRect.new()
	enemy_back.name = "NeutralEffectBack"
	enemy_back.texture = CARD_BACK_TEXTURE
	enemy_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_back.stretch_mode = TextureRect.STRETCH_SCALE
	enemy_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	enemy_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_panel_enemy_mount.add_child(enemy_back)


func _instantiate_effect_card(card_id: String, owner_id: int, card_scale: Vector2) -> EffectCard:
	var card_data := CardDatabase.get_card(EffectCardCatalog.CARD_TYPE, card_id)
	if card_data.is_empty():
		return null
	var rarity_key := str(card_data.get("rarity", "COMMON")).to_upper()
	var scene: Variant = (CARD_TEMPLATE_SCENES.get("effects", {}) as Dictionary).get(rarity_key)
	if not scene is PackedScene:
		return null
	var card := (scene as PackedScene).instantiate() as EffectCard
	if not card:
		return null
	card.card_id = card_id
	card.owner_id = owner_id
	card.is_draggable = false
	card.is_public_preview = true
	card.normal_scale = card_scale
	card.hover_scale = Vector2.ONE
	card.scale = card_scale
	return card

func _create_hand_dock() -> void:
	_hand_dock = Control.new()
	_hand_dock.name = "HandDock"
	_hand_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_dock.z_index = HAND_DOCK_Z_INDEX
	add_child(_hand_dock)
	move_child(_hand_dock, hud.get_index())

	_hand_dock_backdrop = Panel.new()
	_hand_dock_backdrop.name = "HandFanBackdrop"
	_hand_dock_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_dock_backdrop.add_theme_stylebox_override("panel", _build_hand_dock_style())
	_hand_dock.add_child(_hand_dock_backdrop)

	_opponent_hand_backdrop = Panel.new()
	_opponent_hand_backdrop.name = "OpponentHandBackdrop"
	_opponent_hand_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opponent_hand_backdrop.add_theme_stylebox_override("panel", _build_opponent_hand_style())
	_hand_dock.add_child(_opponent_hand_backdrop)

	# Both hands remain in this layer for game-state ownership, but only the local
	# hand is rendered. The opponent's hand has no top-of-playfield card rail.
	p1_hand.reparent(_hand_dock, false)
	p2_hand.reparent(_hand_dock, false)

func _build_hand_dock_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.013, 0.016, 0.94)
	style.border_color = Color(UI.BRASS, 0.64)
	style.border_width_left = 1
	style.border_width_top = 2
	style.border_width_right = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.76)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0.0, -5.0)
	return style

func _build_opponent_hand_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.019, 0.022, 0.72)
	style.border_color = Color(UI.BRASS_DARK, 0.44)
	style.set_border_width_all(1)
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
	return style

func _create_board_navigation() -> void:
	_board_navigation_panel = Panel.new()
	_board_navigation_panel.name = "BoardNavigation"
	_board_navigation_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_board_navigation_panel.z_index = 180
	_board_navigation_panel.add_theme_stylebox_override(
		"panel",
		UI.inset_style(Color(0.018, 0.019, 0.021, 0.96), UI.BRASS, 7)
	)
	add_child(_board_navigation_panel)

	_board_navigation_toggle_button = Button.new()
	_board_navigation_toggle_button.name = "CameraPanelToggle"
	_board_navigation_toggle_button.anchor_right = 1.0
	_board_navigation_toggle_button.offset_left = 5.0
	_board_navigation_toggle_button.offset_top = 5.0
	_board_navigation_toggle_button.offset_right = -5.0
	_board_navigation_toggle_button.offset_bottom = 35.0
	_board_navigation_toggle_button.add_theme_font_size_override("font_size", 9)
	UI.style_button(_board_navigation_toggle_button, UI.BRASS_BRIGHT, false, true)
	_offset_button_text_y(_board_navigation_toggle_button, 2.0)
	_board_navigation_toggle_button.pressed.connect(_on_board_navigation_toggle_pressed)
	_board_navigation_panel.add_child(_board_navigation_toggle_button)

	_board_navigation_content = VBoxContainer.new()
	_board_navigation_content.name = "CameraSettings"
	_board_navigation_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_navigation_content.offset_left = 8.0
	_board_navigation_content.offset_top = 42.0
	_board_navigation_content.offset_right = -8.0
	_board_navigation_content.offset_bottom = -7.0
	var controls := _board_navigation_content
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 5)
	_board_navigation_panel.add_child(controls)

	var interaction_hint := Label.new()
	interaction_hint.text = "BOŞ ALANDA SÜRÜKLE"
	interaction_hint.tooltip_text = "Boş alanda sol sürükle: taşı • Shift + tekerlek: sağ/sol • Tekerlek: yakınlaş/uzaklaş"
	interaction_hint.custom_minimum_size = Vector2(0.0, 18.0)
	interaction_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_hint.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
	interaction_hint.add_theme_font_size_override("font_size", 8)
	interaction_hint.add_theme_color_override("font_color", UI.TEXT_MUTED)
	interaction_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(interaction_hint)

	for region_spec in [
		{"name": "OpponentFocus", "label": "RAKİP", "region": -1, "tip": "Rakip bölgesine odaklan"},
		{"name": "FrontFocus", "label": "CEPHE", "region": 0, "tip": "Ön hatların birleştiği cepheye odaklan"},
		{"name": "BaseFocus", "label": "ÜS", "region": 1, "tip": "Kendi bölgene odaklan"},
	]:
		var focus_button := Button.new()
		focus_button.name = str(region_spec["name"])
		focus_button.text = str(region_spec["label"])
		focus_button.custom_minimum_size = Vector2(0.0, 27.0)
		focus_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus_button.tooltip_text = str(region_spec["tip"])
		focus_button.add_theme_font_size_override("font_size", 9)
		UI.style_button(focus_button, UI.BRASS_DARK, false, true)
		focus_button.pressed.connect(_focus_board_region.bind(int(region_spec["region"])))
		controls.add_child(focus_button)

	var pan_row := HBoxContainer.new()
	pan_row.name = "HorizontalPanControls"
	pan_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pan_row.add_theme_constant_override("separation", 4)
	controls.add_child(pan_row)
	for pan_spec in [
		{"name": "PanLeft", "label": "← SOL", "direction": -1.0},
		{"name": "PanRight", "label": "SAĞ →", "direction": 1.0},
	]:
		var pan_button := Button.new()
		pan_button.name = str(pan_spec["name"])
		pan_button.text = str(pan_spec["label"])
		pan_button.custom_minimum_size = Vector2(45.0, 25.0)
		pan_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pan_button.tooltip_text = "Savaş alanını yatay kaydır"
		pan_button.add_theme_font_size_override("font_size", 8)
		UI.style_button(pan_button, UI.FROST.darkened(0.45), false, true)
		pan_button.pressed.connect(_nudge_board_horizontal.bind(float(pan_spec["direction"])))
		pan_row.add_child(pan_button)

	var zoom_row := HBoxContainer.new()
	zoom_row.name = "ZoomControls"
	zoom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	zoom_row.add_theme_constant_override("separation", 4)
	controls.add_child(zoom_row)

	var zoom_out := Button.new()
	zoom_out.name = "ZoomOut"
	zoom_out.text = "−"
	zoom_out.custom_minimum_size = Vector2(27.0, 27.0)
	zoom_out.tooltip_text = "Uzaklaş"
	UI.style_button(zoom_out, UI.BRASS, false, true)
	zoom_out.pressed.connect(_on_board_zoom_out_pressed)
	zoom_row.add_child(zoom_out)

	_board_zoom_label = Label.new()
	_board_zoom_label.name = "ZoomValue"
	_board_zoom_label.custom_minimum_size = Vector2(36.0, 27.0)
	_board_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_zoom_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_board_zoom_label.add_theme_font_size_override("font_size", 11)
	_board_zoom_label.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	_board_zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_row.add_child(_board_zoom_label)

	var zoom_in := Button.new()
	zoom_in.name = "ZoomIn"
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(27.0, 27.0)
	zoom_in.tooltip_text = "Yakınlaş"
	UI.style_button(zoom_in, UI.BRASS, false, true)
	zoom_in.pressed.connect(_on_board_zoom_in_pressed)
	zoom_row.add_child(zoom_in)

	var reset_view := Button.new()
	reset_view.name = "ResetView"
	reset_view.text = "SIĞDIR"
	reset_view.custom_minimum_size = Vector2(0.0, 28.0)
	reset_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_view.tooltip_text = "Savaş alanının tamamını görünür alana sığdır"
	reset_view.add_theme_font_size_override("font_size", 10)
	UI.style_button(reset_view, UI.BRASS_BRIGHT, false, true)
	reset_view.pressed.connect(_fit_board_view)
	controls.add_child(reset_view)
	_sync_board_navigation_state()


func _offset_button_text_y(button: Button, offset: float) -> void:
	if not button or is_zero_approx(offset):
		return
	for state_name in [&"normal", &"hover", &"pressed", &"disabled"]:
		var source_style := button.get_theme_stylebox(state_name)
		if not source_style:
			continue
		var shifted_style := source_style.duplicate(true) as StyleBox
		shifted_style.content_margin_top += offset
		shifted_style.content_margin_bottom = maxf(0.0, shifted_style.content_margin_bottom - offset)
		button.add_theme_stylebox_override(state_name, shifted_style)


func _on_board_navigation_toggle_pressed() -> void:
	_board_navigation_expanded = not _board_navigation_expanded
	_sync_board_navigation_state()
	_apply_responsive_layout()


func _sync_board_navigation_state() -> void:
	if _board_navigation_content:
		_board_navigation_content.visible = _board_navigation_expanded
	if _board_navigation_toggle_button:
		_board_navigation_toggle_button.text = "KAMERA  ▾" if _board_navigation_expanded else "KAMERA  ▸"
		_board_navigation_toggle_button.tooltip_text = (
			"Kamera ayarlarını kapat"
			if _board_navigation_expanded
			else "Kamera ayarlarını aç"
		)

func _create_arena_backdrop() -> void:
	var background := get_node_or_null("Background") as Panel
	if not background:
		return

	_arena_texture = TextureRect.new()
	_arena_texture.name = "ArenaCastleBackdrop"
	_arena_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arena_texture.texture = ARENA_BACKDROP_TEXTURE
	_arena_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arena_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_arena_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_arena_texture.modulate = Color(0.88, 0.87, 0.84, 1.0)
	_arena_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arena_texture)
	move_child(_arena_texture, background.get_index())

	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(0.010, 0.012, 0.015, 0.24)
	background.add_theme_stylebox_override("panel", wash)

	_arena_overlay = ARENA_OVERLAY_SCRIPT.new() as BattlefieldArenaOverlay
	_arena_overlay.name = "ArenaMapOverlay"
	_arena_overlay.set_perspective_player(_get_battlefield_perspective_player_id())
	add_child(_arena_overlay)
	move_child(_arena_overlay, background.get_index() + 1)

	divider.color = Color(UI.BRASS_DARK, 0.18)

func _create_zone_chrome(zone: Control, player_id: int, accent: Color) -> void:
	if not zone:
		return

	var panel = Panel.new()
	panel.name = "ZoneBackground"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = _build_zone_style(accent)
	panel.add_theme_stylebox_override("panel", style)
	zone.add_child(panel)
	zone.move_child(panel, 0)
	_zone_styles[player_id] = style

	var label = Label.new()
	label.name = "ZoneLabel"
	label.position = Vector2(12.0, 7.0)
	label.size = Vector2(220.0, 22.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_constant_override("line_spacing", -1)
	label.add_theme_color_override("font_color", accent.lightened(0.18))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	UI.style_title(label, accent.lightened(0.18))
	zone.add_child(label)
	_zone_labels[player_id] = label
	label.visible = false


func _create_battlefield_status_ui() -> void:
	for player_id in GameRules.PLAYER_IDS:
		var hq_slot: CardSlot = p1_hq_slot if player_id == 1 else p2_hq_slot
		var energy_badge := _create_hq_resource_badge(
			hq_slot,
			"P%dFieldEnergyBadge" % player_id,
			CARD_STAT_ICON_SCRIPT.IconType.LIGHTNING,
			UI.BRASS_BRIGHT
		)
		var health_badge := _create_hq_resource_badge(
			hq_slot,
			"P%dFieldHealthBadge" % player_id,
			CARD_STAT_ICON_SCRIPT.IconType.HEART,
			Color(1.0, 0.36, 0.34)
		)
		_field_resource_badges[player_id] = {
			"energy": energy_badge.get("panel"),
			"energy_style": energy_badge.get("style"),
			"health": health_badge.get("panel"),
			"health_style": health_badge.get("style"),
		}
		_field_energy_labels[player_id] = energy_badge.get("label")
		_field_health_labels[player_id] = health_badge.get("label")
		var team_accent := _get_team_accent(player_id)
		var name_badge := PanelContainer.new()
		name_badge.name = "P%dFieldNameBadge" % player_id
		name_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_badge.z_index = 4
		var name_style := _build_field_badge_style(team_accent, 0.90)
		name_style.content_margin_left = 10.0
		name_style.content_margin_right = 10.0
		name_badge.add_theme_stylebox_override("panel", name_style)
		_battlefield_world_objects.add_child(name_badge)
		var name_label := Label.new()
		name_label.name = "PlayerName"
		name_label.text = tr("OYUNCU %d") % player_id
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_override("font", UI.DISPLAY_FONT)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", team_accent.lightened(0.24))
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 3)
		name_badge.add_child(name_label)
		_field_name_badges[player_id] = name_badge
		_field_name_labels[player_id] = name_label
		_field_name_styles[player_id] = name_style

	_field_timer_badge = PanelContainer.new()
	_field_timer_badge.name = "FieldTurnTimer"
	_field_timer_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_timer_badge.z_index = 126
	_field_timer_style = _build_field_badge_style(TopHud.TURN_TIME_SAFE_COLOR, 0.96)
	_field_timer_badge.add_theme_stylebox_override("panel", _field_timer_style)
	_battlefield_static_hud.add_child(_field_timer_badge)
	var timer_content := HBoxContainer.new()
	timer_content.name = "TimerContent"
	timer_content.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_content.add_theme_constant_override("separation", 3)
	timer_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_timer_badge.add_child(timer_content)
	_field_timer_icon = CARD_STAT_ICON_SCRIPT.new() as Control
	_field_timer_icon.name = "HourglassIcon"
	_field_timer_icon.custom_minimum_size = Vector2(31.0, 31.0)
	_field_timer_icon.set("icon_type", CARD_STAT_ICON_SCRIPT.IconType.HOURGLASS)
	timer_content.add_child(_field_timer_icon)
	_field_timer_label = Label.new()
	_field_timer_label.name = "TurnSeconds"
	_field_timer_label.text = "%02d" % int(ceil(GameRules.TURN_DURATION_SECONDS))
	_field_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_field_timer_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_field_timer_label.add_theme_font_size_override("font_size", 20)
	_field_timer_label.add_theme_color_override("font_color", TopHud.TURN_TIME_SAFE_COLOR.lightened(0.20))
	_field_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_field_timer_label.add_theme_constant_override("outline_size", 3)
	timer_content.add_child(_field_timer_label)

	var own_energy_badge := _create_hq_resource_badge(
		_battlefield_static_hud,
		"FieldOwnEnergy",
		CARD_STAT_ICON_SCRIPT.IconType.LIGHTNING,
		UI.BRASS_BRIGHT
	)
	_field_own_energy_badge = own_energy_badge.get("panel") as PanelContainer
	_field_own_energy_icon = own_energy_badge.get("icon") as Control
	_field_own_energy_label = own_energy_badge.get("label") as Label
	_field_own_energy_style = own_energy_badge.get("style") as StyleBoxFlat
	if _field_own_energy_badge:
		_field_own_energy_badge.z_index = 126

	var own_health_badge := _create_hq_resource_badge(
		_battlefield_static_hud,
		"FieldOwnHealth",
		CARD_STAT_ICON_SCRIPT.IconType.HEART,
		Color(1.0, 0.36, 0.34)
	)
	_field_own_health_badge = own_health_badge.get("panel") as PanelContainer
	_field_own_health_icon = own_health_badge.get("icon") as Control
	_field_own_health_label = own_health_badge.get("label") as Label
	_field_own_health_style = own_health_badge.get("style") as StyleBoxFlat
	if _field_own_health_badge:
		_field_own_health_badge.z_index = 126

	_field_round_badge = PanelContainer.new()
	_field_round_badge.name = "FieldRoundBadge"
	_field_round_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_round_badge.z_index = 126
	_field_round_style = _build_field_badge_style(UI.BRASS_BRIGHT, 0.92)
	_field_round_badge.add_theme_stylebox_override("panel", _field_round_style)
	_battlefield_static_hud.add_child(_field_round_badge)
	_field_round_label = Label.new()
	_field_round_label.name = "FieldRoundLabel"
	_field_round_label.text = "TUR 01"
	_field_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_field_round_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_field_round_label.add_theme_font_size_override("font_size", 14)
	_field_round_label.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	_field_round_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_field_round_label.add_theme_constant_override("outline_size", 3)
	_field_round_badge.add_child(_field_round_label)


func _create_hq_resource_badge(
	parent: Control,
	node_name: String,
	icon_type: int,
	accent: Color
) -> Dictionary:
	if not parent:
		return {}
	var badge := PanelContainer.new()
	badge.name = node_name
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = CardSlot.CONTENT_Z_INDEX
	var style := _build_field_badge_style(accent, 0.94)
	badge.add_theme_stylebox_override("panel", style)
	parent.add_child(badge)
	var content := HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 1)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(content)
	var icon := CARD_STAT_ICON_SCRIPT.new() as Control
	icon.name = "ResourceIcon"
	icon.custom_minimum_size = Vector2(23.0, 23.0)
	icon.set("icon_type", icon_type)
	content.add_child(icon)
	var value := Label.new()
	value.name = "Value"
	value.text = "0"
	value.custom_minimum_size.x = 28.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_override("font", UI.DISPLAY_FONT)
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", accent.lightened(0.18))
	value.add_theme_color_override("font_outline_color", Color.BLACK)
	value.add_theme_constant_override("outline_size", 3)
	content.add_child(value)
	return {"panel": badge, "label": value, "icon": icon, "style": style}


func _build_field_badge_style(accent: Color, opacity: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.022, 0.024, 0.028, opacity)
	style.border_color = Color(accent, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 7.0
	style.content_margin_top = 4.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 4.0
	style.shadow_color = Color(accent, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2.ZERO
	style.anti_aliasing = true
	return style

func _create_card_preview_panel() -> void:
	_preview_panel = Panel.new()
	_preview_panel.name = "CardPreviewPanel"
	_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_panel.add_theme_stylebox_override("panel", _build_preview_style())
	hud.add_child(_preview_panel)
	# The inspector is deliberately titleless: the card itself owns the whole
	# surface and there is no redundant "Kart Önizleme" chrome above it.
	_preview_title_label = null

	_preview_mount = Control.new()
	_preview_mount.name = "PreviewMount"
	_preview_mount.anchor_right = 1.0
	_preview_mount.anchor_bottom = 1.0
	_preview_mount.offset_left = 8.0
	_preview_mount.offset_top = 8.0
	_preview_mount.offset_right = -8.0
	_preview_mount.offset_bottom = -8.0
	_preview_mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_mount.clip_contents = true
	_preview_panel.add_child(_preview_mount)

	_preview_hint_label = Label.new()
	_preview_hint_label.name = "Hint"
	_preview_hint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_hint_label.offset_left = 16.0
	_preview_hint_label.offset_right = -16.0
	_preview_hint_label.text = "%s\n%s" % [
		tr("HOVER OVER A CARD ON THE BOARD"),
		tr("VIEW ITS DETAILS HERE"),
	]
	_preview_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_hint_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_preview_hint_label.add_theme_font_size_override("font_size", 11)
	_preview_hint_label.add_theme_color_override("font_color", Color(UI.BRASS, 0.76))
	_preview_hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
	_preview_hint_label.add_theme_constant_override("outline_size", 2)
	_preview_mount.add_child(_preview_hint_label)

	_preview_details_panel = Panel.new()
	_preview_details_panel.name = "PreviewDetails"
	_preview_details_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_details_panel.clip_contents = true
	_preview_details_panel.visible = false
	_preview_details_panel.add_theme_stylebox_override(
		"panel",
		_build_preview_details_style()
	)
	_preview_panel.add_child(_preview_details_panel)

	var preview_details_inset := Panel.new()
	preview_details_inset.name = "InnerPlate"
	preview_details_inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_details_inset.offset_left = 9.0
	preview_details_inset.offset_top = 9.0
	preview_details_inset.offset_right = -9.0
	preview_details_inset.offset_bottom = -9.0
	preview_details_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_details_inset.add_theme_stylebox_override(
		"panel",
		UI.inset_style(Color(0.018, 0.019, 0.022, 0.96), UI.BRASS_DARK, 4)
	)
	_preview_details_panel.add_child(preview_details_inset)

	_preview_details_header = Label.new()
	_preview_details_header.name = "Header"
	_preview_details_header.anchor_left = 0.0
	_preview_details_header.anchor_top = 0.0
	_preview_details_header.anchor_right = 1.0
	_preview_details_header.anchor_bottom = 0.0
	_preview_details_header.offset_left = 12.0
	_preview_details_header.offset_top = 11.0
	_preview_details_header.offset_right = -12.0
	_preview_details_header.offset_bottom = 29.0
	_preview_details_header.text = "SAHA DURUMU"
	_preview_details_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_details_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_details_header.add_theme_font_override("font", UI.DISPLAY_FONT)
	_preview_details_header.add_theme_font_size_override("font_size", 10)
	_preview_details_header.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	_preview_details_header.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_preview_details_header.add_theme_constant_override("outline_size", 2)
	_preview_details_panel.add_child(_preview_details_header)

	var preview_details_divider := ColorRect.new()
	preview_details_divider.name = "HeaderDivider"
	preview_details_divider.anchor_left = 0.0
	preview_details_divider.anchor_top = 0.0
	preview_details_divider.anchor_right = 1.0
	preview_details_divider.anchor_bottom = 0.0
	preview_details_divider.offset_left = 19.0
	preview_details_divider.offset_top = 33.0
	preview_details_divider.offset_right = -19.0
	preview_details_divider.offset_bottom = 34.0
	preview_details_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_details_divider.color = Color(UI.BRASS, 0.56)
	_preview_details_panel.add_child(preview_details_divider)

	_preview_details_label = RichTextLabel.new()
	_preview_details_label.name = "Details"
	_preview_details_label.bbcode_enabled = true
	_preview_details_label.scroll_active = true
	_preview_details_label.fit_content = false
	_preview_details_label.anchor_left = 0.0
	_preview_details_label.anchor_top = 0.0
	_preview_details_label.anchor_right = 1.0
	_preview_details_label.anchor_bottom = 1.0
	_preview_details_label.offset_left = 15.0
	_preview_details_label.offset_top = 37.0
	_preview_details_label.offset_right = -13.0
	_preview_details_label.offset_bottom = -11.0
	_preview_details_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_preview_details_label.add_theme_font_override("normal_font", UI.BODY_MEDIUM_FONT)
	_preview_details_label.add_theme_font_override("bold_font", UI.BODY_BOLD_FONT)
	_preview_details_label.add_theme_color_override("default_color", UI.PARCHMENT)
	_preview_details_panel.add_child(_preview_details_label)

func _build_sidebar_style() -> StyleBoxTexture:
	return UI.panel_style(UI.BRASS_DARK, 8.0, 0.99)

func _style_game_over_panel() -> void:
	if not game_over_panel:
		return
	game_over_panel.z_index = 1000
	game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim_style := StyleBoxFlat.new()
	dim_style.bg_color = Color(0.006, 0.007, 0.009, 0.91)
	game_over_panel.add_theme_stylebox_override("panel", dim_style)

	var modal := PanelContainer.new()
	modal.name = "GameOverModal"
	modal.anchor_left = 0.5
	modal.anchor_top = 0.5
	modal.anchor_right = 0.5
	modal.anchor_bottom = 0.5
	modal.offset_left = -500.0
	modal.offset_top = -345.0
	modal.offset_right = 500.0
	modal.offset_bottom = 345.0
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_theme_stylebox_override("panel", UI.panel_style(UI.BRASS_BRIGHT, 30.0, 1.0))
	game_over_panel.add_child(modal)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 9)
	modal.add_child(content)

	_game_over_eyebrow_label = Label.new()
	_game_over_eyebrow_label.name = "Eyebrow"
	_game_over_eyebrow_label.text = "KUŞATMA SONA ERDİ"
	_game_over_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_eyebrow_label.add_theme_font_size_override("font_size", 12)
	UI.style_title(_game_over_eyebrow_label, UI.TEXT_MUTED)
	content.add_child(_game_over_eyebrow_label)

	winner_label.reparent(content, false)
	winner_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	winner_label.custom_minimum_size = Vector2(650.0, 70.0)
	winner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 28)
	UI.style_title(winner_label, UI.BRASS_BRIGHT)

	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", UI.line_style(Color(UI.BRASS, 0.58), 1))
	content.add_child(rule)

	var stats_grid := GridContainer.new()
	stats_grid.name = "GameOverStatsGrid"
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 8)
	stats_grid.add_theme_constant_override("v_separation", 7)
	content.add_child(stats_grid)
	for definition in [
		["duration", "SÜRE"],
		["rounds", "RAUND"],
		["cards_played", "KART OYNANDI"],
		["hq_damage", "HQ HASARI"],
		["cards_destroyed", "RAKİP KARTI YIKILDI"],
		["mvp", "ÖNE ÇIKAN KART"],
	]:
		stats_grid.add_child(_build_game_over_stat(str(definition[0]), str(definition[1])))

	_game_over_analysis_panel = MATCH_ANALYSIS_PANEL_SCRIPT.new()
	content.add_child(_game_over_analysis_panel)

	_game_over_reward_label = Label.new()
	_game_over_reward_label.name = "GameOverReward"
	_game_over_reward_label.text = "Maç kaydı hazırlanıyor…"
	_game_over_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over_reward_label.custom_minimum_size.y = 34.0
	_game_over_reward_label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_game_over_reward_label.add_theme_font_size_override("font_size", 13)
	_game_over_reward_label.add_theme_color_override("font_color", Color(0.52, 0.84, 0.94))
	content.add_child(_game_over_reward_label)

	_game_over_subtitle_label = Label.new()
	_game_over_subtitle_label.name = "GameOverSubtitle"
	_game_over_subtitle_label.text = "Aynı düzenle yeniden savaş veya ana menüye dön."
	_game_over_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over_subtitle_label.add_theme_font_size_override("font_size", 15)
	_game_over_subtitle_label.add_theme_color_override("font_color", UI.TEXT_MUTED)
	content.add_child(_game_over_subtitle_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	content.add_child(actions)

	_game_over_restart_button = Button.new()
	_game_over_restart_button.name = "RestartButton"
	_game_over_restart_button.text = "YENİDEN OYNA"
	_game_over_restart_button.custom_minimum_size = Vector2(205.0, 54.0)
	_game_over_restart_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_restart_button.add_theme_font_size_override("font_size", 15)
	UI.style_button(_game_over_restart_button, UI.BRASS_BRIGHT, false, false, true)
	_game_over_restart_button.pressed.connect(_on_restart_match_pressed)
	actions.add_child(_game_over_restart_button)

	_game_over_main_menu_button = Button.new()
	_game_over_main_menu_button.name = "MainMenuButton"
	_game_over_main_menu_button.text = "ANA MENÜ"
	_game_over_main_menu_button.custom_minimum_size = Vector2(205.0, 54.0)
	_game_over_main_menu_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_main_menu_button.add_theme_font_size_override("font_size", 15)
	UI.style_button(_game_over_main_menu_button, UI.BRASS, false, false, false)
	_game_over_main_menu_button.pressed.connect(_on_game_over_main_menu_pressed)
	actions.add_child(_game_over_main_menu_button)


func _build_game_over_stat(key: String, title_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(215.0, 54.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		UI.inset_style(Color(0.012, 0.015, 0.020, 0.96), UI.BRASS_DARK, 5)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var title := Label.new()
	_game_over_stat_titles[key] = title
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", UI.TEXT_MUTED)
	row.add_child(title)
	var value := Label.new()
	value.name = "GameOverStat%s" % key.to_pascal_case()
	value.text = "—"
	value.custom_minimum_size.x = 108.0 if key == "mvp" else 78.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	value.add_theme_font_size_override("font_size", 13 if key == "mvp" else 14)
	value.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	row.add_child(value)
	_game_over_stat_values[key] = value
	return panel

func _build_zone_style(accent: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.018 + accent.r * 0.026, 0.020 + accent.g * 0.020, 0.024 + accent.b * 0.024, 0.105)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent, 0.44)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(accent, 0.12)
	style.shadow_size = 10
	return style

func _build_preview_style() -> StyleBoxTexture:
	return UI.panel_style(UI.BRASS_BRIGHT, 9.0, 1.0)

func _build_preview_details_style() -> StyleBoxTexture:
	return UI.panel_style(UI.BRASS_BRIGHT, 9.0, 1.0)

func _style_end_turn_button() -> void:
	end_turn_button.add_theme_font_size_override("font_size", 15)
	end_turn_button.tooltip_text = tr("SPACE: advance or confirm the current phase")
	UI.style_button(end_turn_button, UI.BRASS_BRIGHT, false, false, true)

func _create_phase_ui_nodes() -> void:
	_phase_label = Label.new()
	_phase_label.name = "PhaseLabel"
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_label.add_theme_font_size_override("font_size", 14)
	_phase_label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.56))
	_phase_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_phase_label.add_theme_constant_override("outline_size", 3)
	UI.style_title(_phase_label, UI.BRASS_BRIGHT)
	hud.add_child(_phase_label)

	_preparation_token_button = Button.new()
	_preparation_token_button.name = "PreparationTokenButton"
	_preparation_token_button.text = tr("HAZIRLIK JETONU  +%d") % GameRules.PREPARATION_TOKEN_ENERGY
	_preparation_token_button.visible = false
	_preparation_token_button.add_theme_font_size_override("font_size", 12)
	UI.style_button(_preparation_token_button, UI.FROST, false, true)
	hud.add_child(_preparation_token_button)

	_tactical_supply_button = Button.new()
	_tactical_supply_button.name = "TacticalSupplyButton"
	_tactical_supply_button.text = tr("İKMAL ÇEKİŞİ  (%dE → +1 KART)") % GameRules.TACTICAL_SUPPLY_ENERGY_COST
	_tactical_supply_button.tooltip_text = tr("Hazırlık fazında turda 1 kez %d Enerji harcayarak 1 kart çek.") % GameRules.TACTICAL_SUPPLY_ENERGY_COST
	_tactical_supply_button.visible = false
	_tactical_supply_button.add_theme_font_size_override("font_size", 12)
	UI.style_button(_tactical_supply_button, UI.BRASS, false, true)
	hud.add_child(_tactical_supply_button)

	_auto_attack_panel = Panel.new()
	_auto_attack_panel.name = "AutoAttackPanel"
	_auto_attack_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	hud.add_child(_auto_attack_panel)

	_auto_attack_checkbox = CheckBox.new()
	_auto_attack_checkbox.name = "AutoAttackCheckBox"
	_auto_attack_checkbox.text = "OTOMATİK SALDIRI"
	_auto_attack_checkbox.tooltip_text = (
		"Çatışmada Sol, Orta ve Sağ koridorlardaki bütün Hazır saldırganları sırayla kullanır."
	)
	_auto_attack_checkbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_auto_attack_checkbox.offset_left = 10.0
	_auto_attack_checkbox.offset_top = 3.0
	_auto_attack_checkbox.offset_right = -8.0
	_auto_attack_checkbox.offset_bottom = -3.0
	_auto_attack_checkbox.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	_auto_attack_checkbox.add_theme_font_size_override("font_size", 12)
	_auto_attack_checkbox.add_theme_color_override("font_color", UI.PARCHMENT)
	_auto_attack_checkbox.add_theme_color_override("font_hover_color", Color.WHITE)
	_auto_attack_checkbox.add_theme_color_override("font_pressed_color", UI.BRASS_BRIGHT)
	_auto_attack_checkbox.add_theme_color_override("font_disabled_color", Color(UI.TEXT_MUTED, 0.52))
	# The forged parent panel is the only background for this control. Without
	# explicit empty states CheckBox falls back to Button's opaque hover texture.
	for state_name in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		_auto_attack_checkbox.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	_auto_attack_checkbox.mouse_entered.connect(_on_auto_attack_hover_changed.bind(true))
	_auto_attack_checkbox.mouse_exited.connect(_on_auto_attack_hover_changed.bind(false))
	_auto_attack_checkbox.toggled.connect(_on_auto_attack_toggled)
	_auto_attack_panel.add_child(_auto_attack_checkbox)
	_auto_attack_panel.visible = MatchSetup.auto_attack_allowed
	_auto_attack_checkbox.disabled = not MatchSetup.auto_attack_allowed
	if not MatchSetup.auto_attack_allowed:
		_auto_attack_checkbox.set_pressed_no_signal(false)
		_auto_attack_enabled = false
	_refresh_auto_attack_panel_visual()

func _create_feedback_systems() -> void:
	_feedback_clip = Control.new()
	_feedback_clip.name = "BattlefieldFeedbackViewport"
	_feedback_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_clip.clip_contents = true
	# The last slot band ends one level below this surface. Root-level UI starts
	# above it, so every battlefield effect is visible on cards but never on HUD.
	_feedback_clip.z_index = get_tree().get_nodes_in_group(CardSlot.GROUP_NAME).size() * CardSlot.Z_INDEX_STRIDE
	add_child(_feedback_clip)
	move_child(_feedback_clip, 0)

	_feedback_layer = BattlefieldFeedbackLayer.new()
	_feedback_layer.name = "BattlefieldFeedbackLayer"
	_feedback_clip.add_child(_feedback_layer)

	_feedback_audio = FeedbackAudio.new()
	_feedback_audio.name = "FeedbackAudio"
	add_child(_feedback_audio)
	_feedback_audio.bind_button_feedback(self)

func _create_phase_banner() -> void:
	_phase_banner_panel = Panel.new()
	_phase_banner_panel.name = "PhaseBanner"
	_phase_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Board slots occupy compact Z bands; keep phase chrome above every resting
	# card while allowing transient drag cards to remain on top.
	_phase_banner_panel.z_index = (
		get_tree().get_nodes_in_group(CardSlot.GROUP_NAME).size() * CardSlot.Z_INDEX_STRIDE
	) + 1
	_phase_banner_panel.visible = false
	_phase_banner_panel.add_theme_stylebox_override(
		"panel",
		UI.button_style(UI.ButtonState.NORMAL, UI.BRASS_BRIGHT, 0.0, true, true)
	)
	add_child(_phase_banner_panel)

	_phase_banner_label = Label.new()
	_phase_banner_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_phase_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_banner_label.add_theme_font_size_override("font_size", 20)
	_phase_banner_label.add_theme_color_override("font_color", Color(1.0, 0.89, 0.58))
	_phase_banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_phase_banner_label.add_theme_constant_override("outline_size", 3)
	UI.style_title(_phase_banner_label, UI.BRASS_BRIGHT)
	_phase_banner_panel.add_child(_phase_banner_label)

func _create_help_overlays() -> void:
	_rules_reference_panel = RulesReferencePanel.new()
	_rules_reference_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_rules_reference_panel)
	_rules_reference_panel.reference_closed.connect(_on_reference_closed)

	_tutorial_overlay = FirstMatchTutorial.new()
	add_child(_tutorial_overlay)
	_tutorial_overlay.tutorial_closed.connect(_on_tutorial_closed)

func _create_pause_menu() -> void:
	_pause_menu = PAUSE_MENU_SCRIPT.new() as BattlefieldPauseMenu
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(_resume_from_pause)
	_pause_menu.save_requested.connect(_open_save_slots_from_pause.bind(true))
	_pause_menu.load_requested.connect(_open_save_slots_from_pause.bind(false))
	_pause_menu.rules_requested.connect(_open_rules_from_pause)
	_pause_menu.leave_match_requested.connect(_leave_match_from_pause)
	_pause_menu.set_save_available(_can_persist_active_match())


func _create_save_slots_panel() -> void:
	_save_slots_panel = SAVE_SLOTS_PANEL_SCRIPT.new() as SaveSlotsPanel
	add_child(_save_slots_panel)
	_save_slots_panel.save_requested.connect(_save_named_slot)
	_save_slots_panel.load_requested.connect(_load_named_slot)
	_save_slots_panel.delete_requested.connect(_delete_named_slot)


func _open_save_slots_from_pause(start_with_name_field: bool) -> void:
	if not _save_slots_panel or not _can_persist_active_match():
		return
	_save_slots_panel.open_panel(
		_active_match_repository.list_slots(),
		_active_match_repository.get_current_slot_id(),
		_active_match_repository.get_current_slot_name() if not _active_match_repository.get_current_slot_name().is_empty() else MatchSetup.match_name,
		true,
		start_with_name_field
	)


func _save_named_slot(slot_name: String, slot_id: String) -> void:
	var result := _active_match_repository.save_snapshot_to_slot(
		build_active_match_snapshot("elle_kayıt"),
		slot_name,
		slot_id
	)
	if not bool(result.get("success", false)):
		_save_slots_panel.set_status(str(result.get("error", tr("Oyun kaydedilemedi."))), true)
		return
	MatchSetup.set_save_slot(str(result.get("slot_id", "")), str(result.get("slot_name", slot_name)))
	_save_slots_panel.set_slots(_active_match_repository.list_slots(), MatchSetup.save_slot_id)
	_save_slots_panel.set_status(tr("%s slotuna güvenli biçimde kaydedildi.") % MatchSetup.save_slot_name)


func _load_named_slot(slot_id: String) -> void:
	var status := _active_match_repository.inspect_slot(slot_id)
	var loaded: Dictionary
	if str(status.get("state", "")) == "valid":
		loaded = _active_match_repository.load_slot(slot_id)
	elif bool(status.get("has_backup", false)):
		_active_match_repository.configure_slot(slot_id, str(status.get("slot_name", tr("Kayıt"))))
		loaded = _active_match_repository.recover_backup()
		if bool(loaded.get("success", false)):
			loaded["slot_id"] = _active_match_repository.get_current_slot_id()
			loaded["slot_name"] = _active_match_repository.get_current_slot_name()
	else:
		_save_slots_panel.set_status(str(status.get("error", tr("Kayıt yüklenemedi."))), true)
		return
	if not bool(loaded.get("success", false)):
		_save_slots_panel.set_status(str(loaded.get("error", tr("Kayıt yüklenemedi."))), true)
		return
	var snapshot := loaded.get("snapshot", {}) as Dictionary
	if not MatchSetup.configure_from_snapshot(
		snapshot,
		str(loaded.get("slot_id", slot_id)),
		str(loaded.get("slot_name", status.get("slot_name", tr("Kayıt"))))
	):
		_save_slots_panel.set_status(tr("Kayıt savaş alanına hazırlanamadı."), true)
		return
	_active_match_completed = true
	get_tree().paused = false
	var change_error := get_tree().change_scene_to_file("res://battlefield.tscn")
	if change_error != OK:
		_active_match_completed = false
		_save_slots_panel.set_status(tr("Kayıt yüklenemedi: %s") % error_string(change_error), true)


func _delete_named_slot(slot_id: String) -> void:
	var deleted_current := slot_id == _active_match_repository.get_current_slot_id()
	if not _active_match_repository.delete_slot(slot_id):
		_save_slots_panel.set_status(tr("Kayıt slotu silinemedi."), true)
		return
	if deleted_current:
		MatchSetup.set_save_slot(MatchSetup.DEFAULT_SAVE_SLOT_ID, MatchSetup.match_name)
		_active_match_repository.configure_slot(MatchSetup.save_slot_id, MatchSetup.save_slot_name)
	_save_slots_panel.set_slots(_active_match_repository.list_slots(), _active_match_repository.get_current_slot_id())
	_save_slots_panel.set_status(tr("Kayıt slotu silindi."))


func _manual_save_active_match() -> void:
	_save_active_match("elle_kayıt", true)

func _open_pause_menu() -> void:
	if not _pause_menu or (game_over_panel and game_over_panel.visible):
		return
	_clear_effect_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_clear_combat_selection()
	_pause_menu.open_menu()
	get_tree().paused = true
	_save_active_match("duraklatma", false)

func _resume_from_pause() -> void:
	get_tree().paused = false
	if _pause_menu:
		_pause_menu.close_menu()
	_refresh_phase_ui()

func _open_rules_from_pause() -> void:
	if not _rules_reference_panel:
		return
	_rules_reference_panel.open_reference()

func _leave_match_from_pause() -> void:
	_save_active_match("çıkış", false)
	get_tree().paused = false
	if _pause_menu:
		_pause_menu.close_menu()
	if MatchSetup.is_multiplayer_player():
		var network_manager := _get_network_manager()
		if network_manager:
			network_manager.leave_network(true)
		return
	var change_error := get_tree().change_scene_to_file("res://main_menu.tscn")
	if change_error != OK:
		push_error("Ana menüye dönülemedi: %s" % error_string(change_error))

func _create_card_action_panel() -> void:
	_card_action_panel = Panel.new()
	_card_action_panel.name = "CardActionPanel"
	_card_action_panel.set_anchors_preset(Control.PRESET_CENTER)
	_card_action_panel.offset_left = -CARD_ACTION_PANEL_SIZE.x * 0.5
	_card_action_panel.offset_top = -CARD_ACTION_PANEL_SIZE.y * 0.5
	_card_action_panel.offset_right = CARD_ACTION_PANEL_SIZE.x * 0.5
	_card_action_panel.offset_bottom = CARD_ACTION_PANEL_SIZE.y * 0.5
	_card_action_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_action_panel.z_index = 270
	_card_action_panel.add_theme_stylebox_override("panel", UI.panel_style(UI.FROST, 8.0, 0.99))
	add_child(_card_action_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 20.0
	content.offset_top = 16.0
	content.offset_right = -20.0
	content.offset_bottom = -16.0
	content.add_theme_constant_override("separation", 8)
	_card_action_panel.add_child(content)

	_card_action_title = Label.new()
	_card_action_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_action_title.add_theme_font_size_override("font_size", 20)
	UI.style_title(_card_action_title, UI.BRASS_BRIGHT)
	content.add_child(_card_action_title)

	_card_action_details = Label.new()
	_card_action_details.custom_minimum_size = Vector2(0.0, 58.0)
	_card_action_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_action_details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_action_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_action_details.add_theme_font_size_override("font_size", 13)
	_card_action_details.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	content.add_child(_card_action_details)

	_move_action_button = Button.new()
	_move_action_button.name = "MoveActionButton"
	_move_action_button.text = "HAREKET ET  •  1 ENERJİ"
	_style_card_action_button(_move_action_button, Color(0.08, 0.25, 0.36), Color(0.28, 0.76, 1.0))
	content.add_child(_move_action_button)

	_upgrade_action_button = Button.new()
	_upgrade_action_button.name = "UpgradeActionButton"
	_style_card_action_button(_upgrade_action_button, Color(0.28, 0.18, 0.06), Color(0.95, 0.68, 0.22))
	content.add_child(_upgrade_action_button)

	for button_index in range(2):
		var branch_button := Button.new()
		branch_button.name = "Branch%dButton" % (button_index + 1)
		branch_button.custom_minimum_size = Vector2(0.0, 54.0)
		branch_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_card_action_button(branch_button, Color(0.16, 0.10, 0.28), Color(0.70, 0.48, 1.0))
		content.add_child(branch_button)
		_branch_action_buttons.append(branch_button)

	_cancel_action_button = Button.new()
	_cancel_action_button.name = "CancelActionButton"
	_cancel_action_button.text = "VAZGEÇ"
	_style_card_action_button(_cancel_action_button, Color(0.16, 0.08, 0.08), Color(0.88, 0.32, 0.28))
	content.add_child(_cancel_action_button)

	_move_action_button.pressed.connect(_on_move_action_pressed)
	_upgrade_action_button.pressed.connect(_on_upgrade_action_pressed)
	_branch_action_buttons[0].pressed.connect(_on_branch_action_pressed.bind(0))
	_branch_action_buttons[1].pressed.connect(_on_branch_action_pressed.bind(1))
	_cancel_action_button.pressed.connect(_clear_card_action_selection)
	_card_action_panel.visible = false

func _style_card_action_button(button: Button, _background: Color, border: Color) -> void:
	button.custom_minimum_size.y = max(38.0, button.custom_minimum_size.y)
	button.add_theme_font_size_override("font_size", 13)
	UI.style_button(button, border, button.name == "CancelActionButton", true)

func _process(_delta: float) -> void:
	_update_hq_labels()
	_refresh_hand_card_layouts()
	_refresh_active_attack_feedback()
	_refresh_transient_feedback_positions()

func _update_hq_labels() -> void:
	if not game_manager:
		return

	var p1_health: int = p1_hq.health if p1_hq and is_instance_valid(p1_hq) else 0
	var p2_health: int = p2_hq.health if p2_hq and is_instance_valid(p2_hq) else 0
	game_manager.set_hq_health(1, p1_health)
	game_manager.set_hq_health(2, p2_health)
	if top_hud:
		top_hud.set_hq_health(1, p1_health, GameRules.HEADQUARTERS_HEALTH)
		top_hud.set_hq_health(2, p2_health, GameRules.HEADQUARTERS_HEALTH)
	_refresh_match_flow_chrome()

func _on_hq_health_changed(player_id: int, current_health: int, maximum_health: int) -> void:
	var hq_card: SettlementCard = p1_hq as SettlementCard
	if player_id == 2:
		hq_card = p2_hq as SettlementCard
	if hq_card and is_instance_valid(hq_card):
		hq_card.health = current_health
	if top_hud:
		top_hud.set_hq_health(player_id, current_health, maximum_health)
	var field_label := _field_health_labels.get(player_id) as Label
	if field_label:
		field_label.text = str(current_health)
		field_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.38, 0.34) if current_health <= maximum_health * 0.3 else Color(1.0, 0.68, 0.56)
		)
	_refresh_perspective_resource_ui()

func _on_turn_changed(active_player_id: int) -> void:
	_clear_deployment_selection()
	_clear_effect_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	turn_label.text = (
		tr("SIRA: %s") % tr(MatchSetup.get_ai_label(active_player_id).to_upper())
		if MatchSetup.is_ai_player(active_player_id)
		else tr("SIRA: OYUNCU %d") % active_player_id
	)
	if active_player_id == 1:
		turn_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2)) # Green for Player 1
	else:
		turn_label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0)) # Blue for Player 2

	if top_hud and game_manager:
		top_hud.set_turn_state(active_player_id, game_manager.round_count)
	if _field_round_label and game_manager:
		_field_round_label.text = tr("TURN %02d") % game_manager.round_count
	if _arena_overlay:
		_arena_overlay.set_turn_state(active_player_id, 1.0, true)
	_refresh_zone_state(active_player_id)
	_hide_card_preview()
	_refresh_phase_ui()
	_update_deck_ui()
	_refresh_hand_visibility()
	_refresh_perspective_resource_ui()
	_apply_responsive_layout()
	_refresh_open_lane_paths()
	_refresh_effect_card_panel()


func _on_turn_time_changed(
	active_player_id: int,
	remaining_seconds: float,
	total_seconds: float,
	is_running: bool
) -> void:
	if top_hud:
		top_hud.set_turn_time(active_player_id, remaining_seconds, total_seconds, is_running)
	_refresh_field_turn_timer(active_player_id, remaining_seconds, total_seconds, is_running)


func _on_turn_time_expired(player_id: int) -> void:
	if (
		not game_manager
		or not game_manager.is_game_active
		or player_id != game_manager.active_player_id
	):
		return

	show_toast(
		"%d saniye doldu; tur devredildi." % int(round(game_manager.turn_duration_seconds)),
		Color(0.95, 0.38, 0.24)
	)
	_clear_phase_selection()
	_clear_deployment_selection()
	_clear_effect_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_clear_combat_selection()
	if game_manager.current_phase == GameManager.TurnPhase.MULLIGAN:
		_confirm_mulligan_selection()
		return

	_complete_timed_out_turn(player_id)


func _complete_timed_out_turn(player_id: int) -> void:
	if not game_manager or player_id != game_manager.active_player_id:
		return
	if game_manager.current_phase == GameManager.TurnPhase.PREPARATION:
		game_manager.advance_phase(player_id)
	if game_manager.current_phase == GameManager.TurnPhase.COMBAT:
		game_manager.advance_phase(player_id)
	if game_manager.current_phase != GameManager.TurnPhase.END:
		return

	var required_discards := get_required_discard_count(player_id)
	var cards_to_discard: Array[BaseCard] = []
	for card in get_hand_cards(player_id):
		if cards_to_discard.size() >= required_discards:
			break
		cards_to_discard.append(card)
	resolve_end_phase_for_player(player_id, cards_to_discard)

func _refresh_zone_state(active_player_id: int) -> void:
	for player_id in [1, 2]:
		var label = _zone_labels.get(player_id) as Label
		var style = _zone_styles.get(player_id) as StyleBoxFlat
		var is_active = player_id == active_player_id
		var team_accent := _get_team_accent(player_id)
		var front_name := tr("GÜNEY CEPHESİ") if _is_player_on_south(player_id) else tr("KUZEY CEPHESİ")
		if label:
			var identity := _get_field_player_name(player_id)
			var identity_lines := [front_name, identity]
			if MatchSetup.is_dominion():
				identity_lines.append("◆  %d / %d" % [
					int(_field_dominion_scores.get(player_id, 0)),
					_field_dominion_target,
				])
			label.text = "\n".join(identity_lines)
			label.modulate.a = 1.0 if is_active else 0.74
			label.add_theme_color_override(
				"font_color",
				team_accent.lightened(0.34) if is_active else team_accent.lightened(0.08)
			)
			if style:
				style.bg_color.a = 0.17 if is_active else 0.09
				style.border_color = Color(team_accent, 0.72 if is_active else 0.34)
				style.shadow_color = Color(team_accent, 0.20 if is_active else 0.08)
		var field_name_label := _field_name_labels.get(player_id) as Label
		if field_name_label:
			field_name_label.text = _get_field_player_name(player_id)
			field_name_label.add_theme_color_override(
				"font_color",
				team_accent.lightened(0.38) if is_active else team_accent.lightened(0.16)
			)
		var field_name_style := _field_name_styles.get(player_id) as StyleBoxFlat
		if field_name_style:
			field_name_style.border_color = Color(team_accent, 0.92 if is_active else 0.54)
			field_name_style.shadow_color = Color(team_accent, 0.36 if is_active else 0.14)
			field_name_style.bg_color.a = 0.96 if is_active else 0.84

func _on_energy_changed(player_id: int, current_energy: int, maximum_energy: int, temporary_energy: int) -> void:
	var available_energy := current_energy + temporary_energy
	var energy_text := "%d/%d" % [available_energy, maximum_energy]
	if temporary_energy > 0:
		energy_text += tr(" (+%d temporary)") % temporary_energy

	if player_id == 1:
		p1_energy_label.text = tr("P1 Energy: %s") % energy_text
	else:
		p2_energy_label.text = tr("P2 Energy: %s") % energy_text

	if top_hud:
		top_hud.set_player_energy(player_id, current_energy, maximum_energy, temporary_energy)
	var field_label := _field_energy_labels.get(player_id) as Label
	if field_label:
		field_label.text = str(available_energy)
		field_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.44, 0.30) if available_energy <= 0 else UI.BRASS_BRIGHT
		)
	_refresh_perspective_resource_ui()


func _refresh_perspective_resource_ui() -> void:
	if not game_manager:
		return
	var perspective_player_id := _get_hand_perspective_player_id()
	if perspective_player_id not in GameRules.PLAYER_IDS:
		return

	for player_id in GameRules.PLAYER_IDS:
		var entry_variant: Variant = _field_resource_badges.get(player_id, {})
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var is_perspective := player_id == perspective_player_id
		var energy_badge := entry.get("energy") as Control
		var health_badge := entry.get("health") as Control
		var energy_label := _field_energy_labels.get(player_id) as Label
		if energy_badge:
			energy_badge.visible = is_perspective
		if health_badge:
			health_badge.visible = true
		if energy_label:
			if is_perspective:
				var current := int(game_manager.player_current_energy.get(player_id, 0))
				var temporary := int(game_manager.player_temporary_energy.get(player_id, 0))
				var available := current + temporary
				energy_label.text = str(available)
				energy_label.add_theme_color_override(
					"font_color",
					Color(1.0, 0.44, 0.30) if available <= 0 else UI.BRASS_BRIGHT
				)
			else:
				# Do not leave the opponent's energy readable in hidden UI state.
				energy_label.text = ""

	var current_energy := int(game_manager.player_current_energy.get(perspective_player_id, 0))
	var temporary_energy := int(game_manager.player_temporary_energy.get(perspective_player_id, 0))
	var available_energy := current_energy + temporary_energy
	var energy_color := Color(1.0, 0.44, 0.30) if available_energy <= 0 else UI.BRASS_BRIGHT
	if _field_own_energy_badge:
		_field_own_energy_badge.visible = true
	if _field_own_energy_label:
		_field_own_energy_label.text = str(available_energy)
		_field_own_energy_label.add_theme_color_override("font_color", energy_color.lightened(0.18))
	if _field_own_energy_icon:
		_field_own_energy_icon.set("accent_override", energy_color)
	if _field_own_energy_style:
		_field_own_energy_style.border_color = Color(energy_color, 0.88)
		_field_own_energy_style.shadow_color = Color(energy_color, 0.30)
		_field_own_energy_style.bg_color = Color(energy_color.darkened(0.84), 0.94)

	var maximum_health := GameRules.HEADQUARTERS_HEALTH
	var current_health := int(game_manager.player_hq_health.get(perspective_player_id, maximum_health))
	var health_color := (
		Color(1.0, 0.30, 0.28)
		if current_health <= maximum_health * 0.3
		else Color(1.0, 0.48, 0.42)
	)
	if _field_own_health_badge:
		_field_own_health_badge.visible = true
	if _field_own_health_label:
		_field_own_health_label.text = str(current_health)
		_field_own_health_label.add_theme_color_override("font_color", health_color.lightened(0.16))
	if _field_own_health_icon:
		_field_own_health_icon.set("accent_override", health_color)
	if _field_own_health_style:
		_field_own_health_style.border_color = Color(health_color, 0.88)
		_field_own_health_style.shadow_color = Color(health_color, 0.30)
		_field_own_health_style.bg_color = Color(health_color.darkened(0.84), 0.94)


func _get_field_player_name(player_id: int) -> String:
	if MatchSetup.is_multiplayer_match():
		var network_manager := _get_network_manager()
		if network_manager and network_manager.has_method("get_lobby_players"):
			var players: Dictionary = network_manager.get_lobby_players()
			var entry_variant: Variant = players.get(player_id, players.get(str(player_id), {}))
			if entry_variant is Dictionary:
				var network_name := str((entry_variant as Dictionary).get("name", "")).strip_edges()
				if not network_name.is_empty():
					return network_name.to_upper()
	if MatchSetup.is_ai_player(player_id):
		return tr(MatchSetup.get_ai_label(player_id).to_upper())
	return tr("OYUNCU %d") % player_id


func _refresh_field_turn_timer(
	active_player_id: int,
	remaining_seconds: float,
	total_seconds: float,
	is_running: bool
) -> void:
	var normalized_total := maxf(total_seconds, 0.001)
	var ratio := clampf(remaining_seconds / normalized_total, 0.0, 1.0)
	var timer_color := _get_field_turn_timer_color(ratio)
	if _field_timer_label:
		_field_timer_label.text = "%02d" % int(ceil(maxf(0.0, remaining_seconds)))
		_field_timer_label.add_theme_color_override("font_color", timer_color.lightened(0.18))
	if _field_timer_icon:
		_field_timer_icon.set("accent_override", timer_color)
		_field_timer_icon.modulate.a = 1.0 if is_running else 0.56
	if _field_timer_style:
		_field_timer_style.border_color = Color(timer_color, 0.92)
		_field_timer_style.shadow_color = Color(timer_color, 0.34)
		_field_timer_style.bg_color = Color(timer_color.darkened(0.82), 0.92)
	if _field_timer_badge:
		_field_timer_badge.modulate.a = 1.0 if is_running else 0.58
		_field_timer_badge.queue_redraw()
	if _arena_overlay:
		_arena_overlay.set_turn_state(active_player_id, ratio, is_running)


func _get_field_turn_timer_color(ratio: float) -> Color:
	if ratio > (2.0 / 3.0):
		return TopHud.TURN_TIME_SAFE_COLOR
	if ratio > (1.0 / 3.0):
		return TopHud.TURN_TIME_WARNING_COLOR
	return TopHud.TURN_TIME_DANGER_COLOR

func sync_player_energy(player_id: int) -> void:
	if not game_manager or not game_manager.player_current_energy.has(player_id):
		return

	_on_energy_changed(
		player_id,
		int(game_manager.player_current_energy[player_id]),
		int(game_manager.player_max_energy[player_id]),
		int(game_manager.player_temporary_energy[player_id])
	)

func _on_phase_changed(phase: GameManager.TurnPhase) -> void:
	if phase != GameManager.TurnPhase.COMBAT:
		_auto_attack_sequence_generation += 1
	_clear_phase_selection()
	_clear_deployment_selection()
	_clear_hand_tactic_selection()
	_clear_effect_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_clear_combat_selection()
	_discard_required = 0
	_refresh_phase_ui()
	if top_hud and game_manager:
		top_hud.set_phase(game_manager.get_phase_display_name())
	_show_phase_banner()
	if _feedback_audio:
		_feedback_audio.play_event("phase")
	_refresh_open_lane_paths()
	_refresh_effect_card_panel()
	if phase == GameManager.TurnPhase.EFFECT_SELECTION:
		_refresh_effect_selection_from_state(false)

	if game_manager and game_manager.current_phase == GameManager.TurnPhase.END:
		call_deferred("_prepare_end_phase")
	elif game_manager and game_manager.current_phase == GameManager.TurnPhase.COMBAT:
		call_deferred("_try_start_auto_attack")

func _on_preparation_token_changed(_player_id: int, _is_available: bool) -> void:
	_refresh_phase_ui()


func _on_effect_selection_started() -> void:
	_refresh_effect_selection_from_state(true)
	_refresh_effect_card_panel()


func _on_effect_selection_player_changed(player_id: int) -> void:
	if MatchSetup.is_multiplayer_match():
		_refresh_effect_selection_from_state(false)
		return
	if MatchSetup.is_ai_player(player_id):
		_effect_selection_overlay.visible = false
		return
	_show_effect_handoff(player_id)


func _on_effect_card_selected(player_id: int, card_id: String, was_automatic: bool) -> void:
	_refresh_effect_card_panel()
	var perspective := _get_effect_perspective_player_id()
	if player_id != perspective:
		return
	if was_automatic and not MatchSetup.fast_mode:
		var card_data := CardDatabase.get_card(EffectCardCatalog.CARD_TYPE, card_id)
		show_toast(
			tr("Time expired; %s was selected automatically.") % tr(str(card_data.get("name", "an Effect Card"))),
			Color(0.95, 0.58, 0.24),
			"ETKİ KARTI"
		)
	_refresh_effect_selection_from_state(false)


func _on_effect_selection_completed() -> void:
	_clear_effect_offer_cards()
	_effect_selection_overlay.visible = false
	_refresh_effect_card_panel()


func _on_effect_trigger_state_changed(player_id: int, _state: Dictionary) -> void:
	if player_id == _get_effect_perspective_player_id():
		_refresh_effect_card_panel()


func _show_effect_handoff(player_id: int) -> void:
	if not _effect_selection_overlay or player_id not in GameRules.PLAYER_IDS:
		return
	_clear_effect_offer_cards()
	_effect_selection_overlay.visible = true
	_effect_offer_row.visible = false
	if _effect_confirm_button:
		_effect_confirm_button.visible = false
	_effect_handoff.visible = true
	_effect_handoff_button.visible = true
	_effect_selection_title.text = tr("PLAYER %d  •  SECRET CHOICE") % player_id
	_effect_selection_status.text = "Diğer oyuncu ekrandan uzaklaşınca tekliflerini aç."
	_effect_handoff_label.text = "%s\n%s" % [
		tr("Player %d's turn") % player_id,
		tr("Effect Card offers will be shown only to you."),
	]
	_effect_handoff_button.text = tr("PLAYER %d READY") % player_id
	_effect_handoff_button.grab_focus()


func _reveal_effect_offers() -> void:
	if not game_manager or game_manager.current_phase != GameManager.TurnPhase.EFFECT_SELECTION:
		return
	_populate_effect_offer(game_manager.active_player_id)


func _refresh_effect_selection_from_state(require_handoff: bool = false) -> void:
	if not game_manager or game_manager.current_phase != GameManager.TurnPhase.EFFECT_SELECTION:
		if _effect_selection_overlay:
			_effect_selection_overlay.visible = false
		return
	if MatchSetup.human_player_id == 0 and MatchSetup.is_multiplayer_server():
		_effect_selection_overlay.visible = false
		return
	var player_id := _get_effect_perspective_player_id()
	if player_id not in GameRules.PLAYER_IDS or MatchSetup.is_ai_player(player_id):
		_effect_selection_overlay.visible = false
		return
	if game_manager.has_effect_selection(player_id):
		_clear_effect_offer_cards()
		_effect_selection_overlay.visible = true
		_effect_handoff.visible = true
		_effect_offer_row.visible = false
		if _effect_confirm_button:
			_effect_confirm_button.visible = false
		_effect_selection_title.text = "ETKİ KARTIN HAZIR"
		_effect_selection_status.text = "Seçimin gizli tutuluyor. Rakibin seçimi bekleniyor."
		_effect_handoff_label.text = "%s\n%s" % [
			tr("Your choice was saved."),
			tr("The opponent's Effect Card will remain hidden throughout the match."),
		]
		_effect_handoff_button.visible = false
		return
	_effect_handoff_button.visible = true
	if not MatchSetup.is_multiplayer_match() and require_handoff:
		_show_effect_handoff(player_id)
	else:
		_populate_effect_offer(player_id)


func _populate_effect_offer(player_id: int) -> void:
	_clear_effect_offer_cards()
	var offer: Array[String] = game_manager.get_effect_offer(player_id)
	if offer.size() != EffectCardCatalog.OFFER_SIZE:
		_effect_selection_overlay.visible = false
		return
	_effect_selection_overlay.visible = true
	_effect_handoff.visible = false
	_effect_offer_row.visible = true
	if _effect_confirm_button:
		_effect_confirm_button.visible = true
		_effect_confirm_button.disabled = true
		_effect_confirm_button.text = "ÖNCE BİR KART SEÇ"
	_effect_selection_title.text = tr("PLAYER %d  •  CHOOSE AN EFFECT CARD") % player_id
	_effect_selection_status.text = "Kartı incele, seçmek için üzerine tıkla ve alttaki düğmeyle onayla."
	for card_id in offer:
		var cell := VBoxContainer.new()
		cell.name = "EffectOffer_%s" % card_id
		cell.custom_minimum_size = Vector2(250.0, 314.0)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		_effect_offer_row.add_child(cell)
		var stage := Button.new()
		stage.name = "EffectOfferCardButton_%s" % card_id
		stage.text = ""
		stage.custom_minimum_size = Vector2(224.0, 286.0)
		stage.focus_mode = Control.FOCUS_ALL
		stage.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cell.add_child(stage)
		var card := _instantiate_effect_card(card_id, player_id, EFFECT_OFFER_CARD_SCALE)
		if not card:
			continue
		var accent := _effect_rarity_color(card.rarity)
		_style_effect_offer_stage(stage, accent, false)
		stage.pressed.connect(_on_effect_offer_pressed.bind(card_id))
		stage.mouse_entered.connect(_on_effect_offer_hover_changed.bind(card_id, true))
		stage.mouse_exited.connect(_on_effect_offer_hover_changed.bind(card_id, false))
		card.position = Vector2(12.0, 14.0)
		stage.add_child(card)
		card.scale = EFFECT_OFFER_CARD_SCALE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_effect_offer_cards.append(card)
		_effect_offer_stages[card_id] = {
			"stage": stage,
			"card": card,
			"accent": accent,
			"hovered": false,
		}
	if _effect_offer_row.get_child_count() > 0:
		var first_cell := _effect_offer_row.get_child(0)
		var first_button := first_cell.get_child(0) as Button
		if first_button:
			first_button.grab_focus()
	call_deferred("_layout_effect_offer_cards")


func _on_effect_offer_pressed(card_id: String) -> void:
	_select_effect_offer(card_id)


func _select_effect_offer(card_id: String) -> void:
	if not _effect_offer_stages.has(card_id):
		return
	_selected_effect_offer_id = card_id
	for offer_id_variant in _effect_offer_stages:
		var offer_id := str(offer_id_variant)
		_refresh_effect_offer_stage(offer_id)
	var card_data := CardDatabase.get_card(EffectCardCatalog.CARD_TYPE, card_id)
	_effect_selection_status.text = "%s seçildi. Kararı tamamlamak için SEÇ düğmesine bas." % tr(str(card_data.get("name", "Etki Kartı")))
	if _effect_confirm_button:
		_effect_confirm_button.disabled = false
		_effect_confirm_button.text = "SEÇ"
		_effect_confirm_button.grab_focus()


func _confirm_effect_offer_selection() -> void:
	var card_id := _selected_effect_offer_id
	if card_id.is_empty() or not _effect_offer_stages.has(card_id):
		return
	var player_id := _get_effect_perspective_player_id()
	if MatchSetup.is_multiplayer_player():
		if _request_network_action("effect_choice", {"card_id": card_id}):
			_effect_selection_status.text = "Seçim sunucu tarafından doğrulanıyor…"
			if _effect_confirm_button:
				_effect_confirm_button.disabled = true
			for entry_variant in _effect_offer_stages.values():
				var entry := entry_variant as Dictionary
				var stage := entry.get("stage") as Button
				if stage:
					stage.disabled = true
		return
	resolve_effect_card_choice_for_player(player_id, card_id, false)


func _on_effect_offer_hover_changed(card_id: String, hovered: bool) -> void:
	if not _effect_offer_stages.has(card_id):
		return
	var entry := _effect_offer_stages[card_id] as Dictionary
	entry["hovered"] = hovered
	_effect_offer_stages[card_id] = entry
	_refresh_effect_offer_stage(card_id)


func _refresh_effect_offer_stage(card_id: String) -> void:
	var entry_variant: Variant = _effect_offer_stages.get(card_id, {})
	if not entry_variant is Dictionary:
		return
	var entry := entry_variant as Dictionary
	var stage := entry.get("stage") as Button
	var card := entry.get("card") as EffectCard
	var accent: Color = entry.get("accent", UI.BRASS)
	var is_selected := card_id == _selected_effect_offer_id
	var is_hovered := bool(entry.get("hovered", false))
	_style_effect_offer_stage(stage, accent, is_selected)
	if card and is_instance_valid(card):
		var emphasis := 1.055 if is_hovered else 1.025 if is_selected else 1.0
		card.normal_scale = EFFECT_OFFER_CARD_SCALE * emphasis
		card.set_selection_visual(is_selected, accent)
		_layout_effect_offer_card(card, stage)


func _style_effect_offer_stage(stage: Button, accent: Color, selected: bool) -> void:
	if not stage:
		return
	var normal := _effect_offer_stage_style(accent, 0.12 if selected else 0.045, 3 if selected else 1)
	var hover := _effect_offer_stage_style(accent.lightened(0.14), 0.12, 2)
	var pressed := _effect_offer_stage_style(accent.lightened(0.22), 0.16, 3)
	stage.add_theme_stylebox_override("normal", normal)
	stage.add_theme_stylebox_override("hover", hover)
	stage.add_theme_stylebox_override("pressed", pressed)
	stage.add_theme_stylebox_override("focus", _effect_offer_stage_style(accent.lightened(0.26), 0.08, 2))
	stage.add_theme_stylebox_override("disabled", normal)


func _effect_offer_stage_style(accent: Color, fill_alpha: float, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.darkened(0.76), fill_alpha)
	style.border_color = Color(accent, 0.92 if border_width > 1 else 0.48)
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(accent, 0.24 if border_width > 1 else 0.08)
	style.shadow_size = 12 if border_width > 1 else 4
	style.shadow_offset = Vector2.ZERO
	style.anti_aliasing = true
	return style


func _layout_effect_offer_cards() -> void:
	for entry_variant in _effect_offer_stages.values():
		var entry := entry_variant as Dictionary
		_layout_effect_offer_card(entry.get("card") as EffectCard, entry.get("stage") as Control)


func _layout_effect_offer_card(card: EffectCard, stage: Control) -> void:
	if not card or not stage or not is_instance_valid(card):
		return
	var scaled_size := HAND_CARD_BASE_SIZE * card.normal_scale
	var visual_top_left := (stage.size - scaled_size) * 0.5
	var pivot := HAND_CARD_BASE_SIZE * 0.5
	card.position = visual_top_left - (pivot * (Vector2.ONE - card.normal_scale))


func resolve_effect_card_choice_for_player(player_id: int, card_id: String, was_automatic: bool = false) -> bool:
	if not game_manager or card_id.is_empty():
		return false
	return game_manager.submit_effect_selection(player_id, card_id, was_automatic)


func _clear_effect_offer_cards() -> void:
	_selected_effect_offer_id = ""
	_effect_offer_stages.clear()
	_effect_offer_cards.clear()
	if _effect_confirm_button:
		_effect_confirm_button.disabled = true
		_effect_confirm_button.text = "ÖNCE BİR KART SEÇ"
	if not _effect_offer_row:
		return
	for child in _effect_offer_row.get_children():
		_effect_offer_row.remove_child(child)
		child.queue_free()


func _effect_rarity_color(rarity: BaseCard.Rarity) -> Color:
	match rarity:
		BaseCard.Rarity.RARE: return Color(0.24, 0.64, 0.96)
		BaseCard.Rarity.EPIC: return Color(0.82, 0.38, 0.88)
		BaseCard.Rarity.LEGENDARY: return Color(1.0, 0.66, 0.18)
		_: return Color(0.68, 0.72, 0.76)


func _get_effect_perspective_player_id() -> int:
	if MatchSetup.is_multiplayer_match() or MatchSetup.is_ai_match():
		return MatchSetup.human_player_id
	return game_manager.active_player_id if game_manager else 1


func _refresh_effect_card_panel() -> void:
	if not _effect_panel or not game_manager:
		return
	var player_id := _get_effect_perspective_player_id()
	if player_id not in GameRules.PLAYER_IDS:
		_effect_panel.visible = false
		return
	_effect_panel.visible = true
	var selected_id: String = game_manager.get_selected_effect_card(player_id)
	if selected_id != _effect_panel_rendered_card_id:
		if _effect_panel_own_card and is_instance_valid(_effect_panel_own_card):
			if _preview_source_card == _effect_panel_own_card:
				_preview_source_card = null
				_preview_hover_token += 1
			if _preview_displayed_source_card == _effect_panel_own_card:
				_hide_card_preview()
			_effect_panel_own_mount.remove_child(_effect_panel_own_card)
			_effect_panel_own_card.queue_free()
		_effect_panel_own_card = null
		_effect_panel_rendered_card_id = selected_id
	if selected_id.is_empty():
		_effect_panel_own_label.text = "SENİN ETKİN  •  BEKLENİYOR"
		_effect_panel_state_label.text = "Seçim tamamlanmadı"
	else:
		if not _effect_panel_own_card:
			_effect_panel_own_card = _instantiate_effect_card(selected_id, player_id, EFFECT_PANEL_CARD_SCALE)
			if _effect_panel_own_card:
				_effect_panel_own_card.position = Vector2.ZERO
				_effect_panel_own_mount.add_child(_effect_panel_own_card)
				_effect_panel_own_card.mouse_filter = Control.MOUSE_FILTER_STOP
				_register_preview_card(_effect_panel_own_card)
				_layout_effect_panel_own_card()
		var data := CardDatabase.get_card(EffectCardCatalog.CARD_TYPE, selected_id)
		_effect_panel_own_label.text = str(data.get("name", "SENİN ETKİN")).to_upper()
		var state: Dictionary = game_manager.get_effect_trigger_state(player_id)
		var last_trigger := str(state.get("last_trigger_id", ""))
		_effect_panel_state_label.text = (
			"AKTİF  •  BU TUR HAZIR"
			if last_trigger.is_empty()
			else "AKTİF  •  BU TUR TETİKLENDİ"
		)
	_effect_panel_enemy_label.text = "RAKİP  •  GİZLİ"
	_layout_effect_panel_contents()


func _layout_effect_panel_own_card() -> void:
	if not _effect_panel_own_card or not is_instance_valid(_effect_panel_own_card) or not _effect_panel_own_mount:
		return
	var available := _effect_panel_own_mount.size
	var fitted_scale := minf(available.x / 200.0, available.y / 280.0)
	if fitted_scale <= 0.0:
		fitted_scale = EFFECT_PANEL_CARD_SCALE.x
	_effect_panel_own_card.pivot_offset = Vector2.ZERO
	_effect_panel_own_card.position = Vector2.ZERO
	_effect_panel_own_card.normal_scale = Vector2.ONE * fitted_scale
	_effect_panel_own_card.scale = Vector2.ONE * fitted_scale

func _on_mulligan_completed() -> void:
	if not game_manager or MatchSetup.is_multiplayer_client():
		return
	var second_player_id: int = game_manager.get_opponent_id(game_manager.first_player_id)
	var hq_slot := get_hq_slot(second_player_id)
	var hq_card: BaseCard = null
	if hq_slot and hq_slot.is_occupied:
		hq_card = hq_slot.occupied_card as BaseCard
	if not hq_card:
		return
	hq_card.apply_status(
		EffectResolver.STATUS_PROTECTED,
		GameRules.SECOND_PLAYER_HQ_PROTECTION
	)
	if not MatchSetup.fast_mode:
		show_toast(
			tr("Player %d's Headquarters will block %d of the first damage.") % [
				second_player_id,
				GameRules.SECOND_PLAYER_HQ_PROTECTION,
			],
			Color(0.35, 0.82, 1.0),
			"AÇILIŞ KALKANI"
		)
	_refresh_lane_visuals()

func _on_preparation_token_pressed() -> void:
	if not game_manager:
		return
	if MatchSetup.is_multiplayer_player():
		_request_network_action("preparation_token")
		return
	if game_manager.use_preparation_token(game_manager.active_player_id):
		show_toast("Hazırlık jetonu kullanıldı: +1 geçici Enerji.", Color(0.30, 0.72, 1.0))
	_refresh_phase_ui()


func _on_tactical_supply_pressed() -> void:
	if not game_manager or is_card_interaction_locked():
		return
	var active_id: int = int(game_manager.active_player_id)
	if MatchSetup.is_multiplayer_player():
		_request_network_action("tactical_supply")
		return
	var active_hand = _get_hand_for_player(active_id)
	var hand_count: int = _get_hand_card_count(active_hand) if active_hand else 0
	var result: Dictionary = game_manager.use_tactical_supply(active_id, hand_count)
	if bool(result.get("success", false)):
		show_toast(
			tr("İkmal Çekişi: %d Enerji karşılığında 1 kart çekildi.") % GameRules.TACTICAL_SUPPLY_ENERGY_COST,
			UI.BRASS_BRIGHT,
			tr("İKMAL ÇEKİŞİ")
		)
	else:
		show_toast(str(result.get("error", tr("İkmal çekişi yapılamadı."))), UI.BLOOD)
	_refresh_phase_ui()


func _on_auto_attack_toggled(enabled: bool) -> void:
	_auto_attack_enabled = enabled
	_auto_attack_sequence_generation += 1
	_clear_effect_selection()
	_clear_hand_tactic_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_clear_combat_selection()
	_refresh_phase_ui()
	_refresh_auto_attack_panel_visual()
	if enabled:
		call_deferred("_try_start_auto_attack")

func _on_auto_attack_hover_changed(hovered: bool) -> void:
	_auto_attack_hovered = hovered
	_refresh_auto_attack_panel_visual()

func _refresh_auto_attack_panel_visual() -> void:
	if not _auto_attack_panel:
		return
	var state := UI.ButtonState.NORMAL
	if _auto_attack_checkbox and _auto_attack_checkbox.disabled:
		state = UI.ButtonState.DISABLED
	elif _auto_attack_hovered:
		state = UI.ButtonState.HOVER
	elif _auto_attack_checkbox and _auto_attack_checkbox.button_pressed:
		state = UI.ButtonState.PRESSED
	var accent: Color = UI.TEAM_PLAYER if _auto_attack_enabled else UI.BRASS
	_auto_attack_panel.add_theme_stylebox_override(
		"panel",
		UI.button_style(state, accent, 10.0, true, _auto_attack_enabled)
	)


func _try_start_auto_attack() -> void:
	if not _can_start_auto_attack():
		return
	_auto_attack_running = true
	var run_generation := _auto_attack_sequence_generation
	_clear_combat_selection()
	_refresh_phase_ui()
	var attacks_resolved: int = await _run_auto_attack_sequence(run_generation)
	var was_retriggered := run_generation != _auto_attack_sequence_generation
	_auto_attack_running = false
	_refresh_lane_visuals()
	_update_hq_labels()
	_refresh_phase_ui()
	if attacks_resolved > 0 and not MatchSetup.fast_mode and not MatchSetup.is_multiplayer_client():
		show_toast(
			tr("%d automatic attacks completed.") % attacks_resolved,
			Color(0.38, 0.90, 0.62),
			"KORİDOR HÜCUMU"
		)
	if was_retriggered and _auto_attack_enabled:
		call_deferred("_try_start_auto_attack")


func _can_start_auto_attack() -> bool:
	if (
		not _auto_attack_enabled
		or _auto_attack_running
		or not game_manager
		or not game_manager.is_game_active
		or not game_manager.is_match_started
		or game_manager.current_phase != GameManager.TurnPhase.COMBAT
	):
		return false
	if not _is_auto_attack_player_locally_controlled(game_manager.active_player_id):
		return false
	return not (
		_is_dealing_initial_hands
		or _is_draw_animation_running
		or _effect_draw_queue_running
		or _is_confirming_selection
		or _is_hand_tactic_resolving
		or (get_tree() != null and get_tree().paused)
		or (_pause_menu != null and _pause_menu.is_open())
		or (_tutorial_overlay != null and _tutorial_overlay.is_open())
		or (_rules_reference_panel != null and _rules_reference_panel.is_open())
	)


func _is_auto_attack_player_locally_controlled(player_id: int) -> bool:
	if MatchSetup.is_ai_player(player_id):
		return false
	if MatchSetup.is_multiplayer_match():
		return player_id == MatchSetup.human_player_id
	return player_id in GameRules.PLAYER_IDS


func _run_auto_attack_sequence(run_generation: int) -> int:
	var attacks_resolved := 0
	while attacks_resolved < AUTO_ATTACK_MAX_ATTACKS:
		if not _should_continue_auto_attack(run_generation):
			break
		var attack_slots := _get_auto_attack_slots(game_manager.active_player_id)
		if attack_slots.is_empty():
			break
		var attacks_this_pass := 0
		for slot in attack_slots:
			if not _should_continue_auto_attack(run_generation):
				break
			if not slot or not is_instance_valid(slot) or not slot.is_occupied:
				continue
			var attacker := slot.occupied_card as BaseCard
			if not attacker or not CombatResolver.can_select_attacker(game_manager, attacker):
				continue
			var target_slot := CombatResolver.get_legal_target_slot(self, game_manager, attacker)
			if not target_slot:
				continue
			var result: Dictionary = await _resolve_auto_attack(attacker, target_slot)
			if not bool(result.get("success", false)):
				continue
			attacks_resolved += 1
			attacks_this_pass += 1
			if attacks_resolved >= AUTO_ATTACK_MAX_ATTACKS or not game_manager.is_game_active:
				break
		if attacks_this_pass == 0:
			break
	return attacks_resolved


func _should_continue_auto_attack(run_generation: int) -> bool:
	return (
		_auto_attack_enabled
		and run_generation == _auto_attack_sequence_generation
		and game_manager != null
		and game_manager.is_game_active
		and game_manager.current_phase == GameManager.TurnPhase.COMBAT
		and _is_auto_attack_player_locally_controlled(game_manager.active_player_id)
	)


func _get_auto_attack_slots(player_id: int) -> Array[CardSlot]:
	var attack_slots: Array[CardSlot] = []
	for lane_id in [CardSlot.Lane.LEFT, CardSlot.Lane.CENTER, CardSlot.Lane.RIGHT]:
		for slot in get_lane_slots(player_id, lane_id):
			if not slot.is_occupied or not slot.occupied_card is BaseCard:
				continue
			var attacker := slot.occupied_card as BaseCard
			if (
				CombatResolver.can_select_attacker(game_manager, attacker)
				and CombatResolver.get_legal_target_slot(self, game_manager, attacker) != null
			):
				attack_slots.append(slot)
	return attack_slots


func _resolve_auto_attack(attacker: BaseCard, target_slot: CardSlot) -> Dictionary:
	if not MatchSetup.is_multiplayer_client():
		return await resolve_attack_with_feedback(attacker, target_slot)

	var network_manager := _get_network_manager()
	if not network_manager:
		return {"success": false, "error": "Ağ yöneticisi bulunamadı."}
	var previous_revision := _applied_network_revision
	var accepted := _request_network_action("attack", {
		"card_id": _get_card_network_id(attacker),
		"slot_id": _get_slot_network_id(target_slot),
	})
	if not accepted:
		return {"success": false, "error": "Saldırı sunucuya gönderilemedi."}

	var deadline := Time.get_ticks_msec() + AUTO_ATTACK_NETWORK_TIMEOUT_MSEC
	while network_manager.is_action_pending() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	while _applied_network_revision <= previous_revision and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return {
		"success": _applied_network_revision > previous_revision,
		"error": "Sunucu saldırı sonucunu zamanında göndermedi.",
	}

func _has_active_interaction_selection() -> bool:
	return (
		_get_active_drag_card() != null
		or (_selected_deployment_card != null and is_instance_valid(_selected_deployment_card))
		or (_selected_effect_card != null and is_instance_valid(_selected_effect_card))
		or (_selected_hand_tactic_card != null and is_instance_valid(_selected_hand_tactic_card))
		or (_selected_mover != null and is_instance_valid(_selected_mover))
		or (_selected_action_card != null and is_instance_valid(_selected_action_card))
		or (_selected_attacker != null and is_instance_valid(_selected_attacker))
	)

func _get_active_drag_card() -> BaseCard:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group(BaseCard.GROUP_NAME):
		var card := node as BaseCard
		if card and card.is_dragging:
			return card
	return null

func cancel_active_interaction(show_feedback: bool = false) -> bool:
	var drag_card := _get_active_drag_card()
	var has_phase_selection := not _phase_selected_cards.is_empty()
	if not drag_card and not has_phase_selection and not _has_active_interaction_selection():
		return false
	if drag_card:
		drag_card.cancel_dragging()
	_clear_phase_selection()
	_clear_deployment_selection()
	_clear_effect_selection()
	_clear_hand_tactic_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_clear_combat_selection()
	if show_feedback and not MatchSetup.fast_mode:
		show_toast(
			tr("Action selection cancelled."),
			Color(0.42, 0.76, 1.0),
			tr("SELECTION CANCELLED")
		)
	return true

func _on_end_turn_pressed() -> void:
	if not game_manager or is_card_interaction_locked():
		return
	_clear_deployment_selection()
	_clear_effect_selection()
	_clear_hand_tactic_selection()
	_clear_movement_selection()
	_clear_card_action_selection()

	match game_manager.current_phase:
		GameManager.TurnPhase.MULLIGAN:
			_confirm_mulligan_selection()
		GameManager.TurnPhase.PREPARATION, GameManager.TurnPhase.COMBAT:
			if MatchSetup.is_multiplayer_player():
				_request_network_action("advance_phase")
			else:
				game_manager.advance_phase(game_manager.active_player_id)
		GameManager.TurnPhase.END:
			_confirm_discard_selection()

func _refresh_phase_ui() -> void:
	if not game_manager or not end_turn_button:
		return

	if _phase_label:
		_phase_label.text = _get_phase_guidance()
		if _selected_deployment_card:
			_phase_label.text = _with_selection_cancel_hint(
				tr("%s • CHOOSE A DEPLOYMENT SLOT") % tr(_selected_deployment_card.card_name).to_upper()
			)
		elif _selected_hand_tactic_card:
			_phase_label.text = _with_selection_cancel_hint(
				tr("%s • SELECT A HAND CARD TO REPLACE") % tr(_selected_hand_tactic_card.card_name).to_upper()
			)
		elif _selected_effect_card:
			_phase_label.text = _with_selection_cancel_hint(
				tr("%s • SELECT A HIGHLIGHTED TARGET") % tr(_selected_effect_card.card_name).to_upper()
			)
		elif _selected_mover:
			_phase_label.text = _with_selection_cancel_hint(
				tr("MOVE %s • SELECT A TARGET") % tr(_selected_mover.card_name).to_upper()
			)
		elif _selected_attacker:
			_phase_label.text = _with_selection_cancel_hint(
				tr("%s • SELECT THE RED STRIKE TARGET") % tr(_selected_attacker.card_name).to_upper()
			)
		_phase_label.visible = not _phase_label.text.is_empty()

	if _auto_attack_checkbox:
		var auto_attack_available: bool = (
			MatchSetup.auto_attack_allowed
			and game_manager.is_game_active
			and _is_auto_attack_player_locally_controlled(game_manager.active_player_id)
		)
		if _auto_attack_panel:
			_auto_attack_panel.visible = MatchSetup.auto_attack_allowed
		_auto_attack_checkbox.disabled = not auto_attack_available
		_auto_attack_checkbox.text = (
			"OTOMATİK SALDIRI  •  ÇALIŞIYOR"
			if _auto_attack_running
			else "OTOMATİK SALDIRI"
		)
		if _auto_attack_panel:
			_auto_attack_panel.modulate.a = 1.0 if auto_attack_available else 0.56
		_refresh_auto_attack_panel_visual()

	end_turn_button.disabled = is_card_interaction_locked()
	end_turn_button.add_theme_font_size_override("font_size", 15)
	match game_manager.current_phase:
		GameManager.TurnPhase.EFFECT_SELECTION:
			end_turn_button.text = "ETKİ KARTI SEÇ"
			end_turn_button.disabled = true
		GameManager.TurnPhase.MULLIGAN:
			if _phase_selected_cards.is_empty():
				end_turn_button.text = "BAŞLANGIÇ ELİNİ ONAYLA"
				end_turn_button.add_theme_font_size_override("font_size", 11)
			else:
				end_turn_button.text = tr("%d KARTI DEĞİŞTİR") % _phase_selected_cards.size()
		GameManager.TurnPhase.PREPARATION:
			end_turn_button.text = "ÇATIŞMAYA GEÇ"
		GameManager.TurnPhase.COMBAT:
			end_turn_button.text = "TURU BİTİR"
		GameManager.TurnPhase.END:
			if _discard_required > 0:
				end_turn_button.text = tr("KART AT (%d/%d)") % [_phase_selected_cards.size(), _discard_required]
				end_turn_button.disabled = _phase_selected_cards.size() != _discard_required
			else:
				end_turn_button.text = "TUR SONU"
				end_turn_button.disabled = true

	if _preparation_token_button:
		_preparation_token_button.visible = (
			game_manager.current_phase == GameManager.TurnPhase.PREPARATION
			and game_manager.has_preparation_token(game_manager.active_player_id)
		)
		_preparation_token_button.disabled = is_card_interaction_locked()
	if _tactical_supply_button:
		var active_id: int = int(game_manager.active_player_id)
		var active_hand = _get_hand_for_player(active_id)
		var hand_count: int = _get_hand_card_count(active_hand) if active_hand else 0
		var deck_count: int = get_deck_card_count(active_id)
		var can_show_supply: bool = (
			bool(game_manager.is_game_active)
			and bool(game_manager.is_match_started)
			and game_manager.current_phase == GameManager.TurnPhase.PREPARATION
			and not MatchSetup.is_ai_player(active_id)
			and not bool(game_manager.has_player_turn_flag(active_id, "tactical_supply"))
			and deck_count > 0
		)
		_tactical_supply_button.visible = can_show_supply
		_tactical_supply_button.disabled = (
			is_card_interaction_locked()
			or not bool(game_manager.can_use_tactical_supply(active_id, hand_count))
		)
	_layout_sidebar_action_controls()
	_refresh_card_playability_highlights()
	_refresh_match_flow_chrome()
	_refresh_end_turn_pulse()
	if not _deck_panels.is_empty():
		_configure_deck_frames(get_viewport_rect().size)


func _refresh_card_playability_highlights() -> void:
	if not game_manager:
		return
	var active_id: int = int(game_manager.active_player_id)
	var is_prep: bool = (
		bool(game_manager.is_game_active)
		and bool(game_manager.is_match_started)
		and game_manager.current_phase == GameManager.TurnPhase.PREPARATION
		and not MatchSetup.is_ai_player(active_id)
		and not is_card_interaction_locked()
	)
	var is_combat: bool = (
		bool(game_manager.is_game_active)
		and bool(game_manager.is_match_started)
		and game_manager.current_phase == GameManager.TurnPhase.COMBAT
		and not MatchSetup.is_ai_player(active_id)
		and not is_card_interaction_locked()
	)
	for player_id in GameRules.PLAYER_IDS:
		var hand_cards := get_hand_cards(player_id)
		var show_hand_hints: bool = is_prep and player_id == active_id
		for card in hand_cards:
			if not card or not is_instance_valid(card) or card.is_queued_for_deletion():
				continue
			var playable := false
			if show_hand_hints:
				playable = _is_hand_card_currently_playable(card)
			card.set_hand_playable(playable, show_hand_hints)
		var board_cards := get_board_cards(player_id)
		for board_card in board_cards:
			if not board_card or not is_instance_valid(board_card) or board_card.is_queued_for_deletion():
				continue
			var ready_attack := false
			if is_combat and player_id == active_id:
				ready_attack = CombatResolver.get_attacker_error(game_manager, board_card).is_empty()
			board_card.set_board_ready_highlight(ready_attack)


func _is_hand_card_currently_playable(card: BaseCard) -> bool:
	if not game_manager or not card:
		return false
	var player_id: int = card.owner_id
	if card is HeroCard or card is SettlementCard:
		var action_type := "hero" if card is HeroCard else "settlement"
		var cost := EffectResolver.get_effect_action_cost(game_manager, card, action_type, card.energy_cost)
		if not game_manager.has_enough_energy(player_id, cost):
			return false
		for slot in get_board_slots(player_id):
			if slot and slot.can_accept_card(card):
				return true
		return false
	if card is SpecialPowerCard and is_hand_tactic_card(card):
		var tactic_cost := EffectResolver.get_effect_action_cost(game_manager, card, "special_power", card.energy_cost)
		if not game_manager.has_enough_energy(player_id, tactic_cost):
			return false
		if get_deck_card_count(player_id) <= 0:
			return false
		if card.effect_id == "redraw_card":
			return get_hand_cards(player_id).size() > 1
		return true
	if card is UpgradeCard or card is SpecialPowerCard:
		return not EffectResolver.get_legal_target_slots(game_manager, card).is_empty()
	return false

func _with_selection_cancel_hint(guidance: String) -> String:
	return "%s • ESC: %s" % [guidance, tr("VAZGEÇ")]

func _get_phase_guidance() -> String:
	if not game_manager:
		return ""
	if _auto_attack_running:
		return tr("OTOMATİK SALDIRI • KORİDORLAR ÇÖZÜLÜYOR")
	if MatchSetup.is_ai_player(game_manager.active_player_id):
		return tr("%s HAMLESİNİ PLANLIYOR…") % tr(MatchSetup.get_ai_label(game_manager.active_player_id).to_upper())
	match game_manager.current_phase:
		GameManager.TurnPhase.EFFECT_SELECTION:
			return tr("ETKİ KARTI SEÇİMİ • SEÇİMLER GİZLİDİR")
		GameManager.TurnPhase.MULLIGAN:
			return tr("BAŞLANGIÇ ELİNİ DÜZENLE • DEĞİŞTİRMEK İSTEDİĞİN KARTLARI SEÇ")
		GameManager.TurnPhase.PREPARATION:
			return tr("CLICK OR DRAG A CARD • SPACE: ADVANCE PHASE")
		GameManager.TurnPhase.COMBAT:
			return tr("OTOMATİK SALDIRI AÇIK") if _auto_attack_enabled else tr("HAZIR SALDIRGANI SEÇ")
		GameManager.TurnPhase.END:
			return tr("TUR SONU ÇÖZÜLÜYOR")
		_:
			return ""

func request_hand_card_deployment_selection(card: BaseCard) -> void:
	if not card or not is_instance_valid(card) or not game_manager:
		return
	if is_card_interaction_locked() or card.current_slot != null:
		return
	if not (card is HeroCard or card is SettlementCard):
		return
	if card == _selected_deployment_card:
		_clear_deployment_selection()
		return
	if card.owner_id != game_manager.active_player_id or not game_manager.can_play_card(card.owner_id):
		show_toast("Kartlar yalnızca kendi Hazırlık aşamanda yerleştirilebilir.", Color(0.95, 0.38, 0.24))
		return
	if card.get_parent() != _get_hand_for_player(card.owner_id):
		return
	var action_type := "hero" if card is HeroCard else "settlement"
	var resolved_cost := EffectResolver.get_effect_action_cost(game_manager, card, action_type, card.energy_cost)
	if game_manager.get_available_energy(card.owner_id) < resolved_cost:
		show_toast("Kartı oynayacak Enerji yok.", Color(0.95, 0.38, 0.24))
		return
	var legal_targets: Array[CardSlot] = []
	for slot in get_board_slots(card.owner_id):
		if slot.can_accept_card(card):
			legal_targets.append(slot)
	if legal_targets.is_empty():
		show_toast("Bu kart için boş ve geçerli bir yerleştirme yuvası yok.", Color(0.95, 0.38, 0.24))
		return

	_clear_effect_selection()
	_clear_hand_tactic_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_clear_combat_selection()
	_clear_deployment_selection()
	_selected_deployment_card = card
	_legal_deployment_targets = legal_targets
	card.set_meta("deployment_selected", true)
	card.modulate = Color.WHITE
	card.set_selection_visual(true, UI.FROST.lightened(0.18))
	_refresh_deployment_highlights()
	_refresh_phase_ui()
	show_toast(
		tr("Select a highlighted deployment slot for %s.") % tr(card.card_name),
		Color(0.30, 0.72, 1.0),
		tr("DEPLOY CARD")
	)

func request_deployment_target_selection(slot: CardSlot) -> Dictionary:
	if not _selected_deployment_card or not is_instance_valid(_selected_deployment_card):
		_clear_deployment_selection()
		return {"success": false, "error": "Yerleştirilecek kart seçili değil."}
	var card := _selected_deployment_card
	if not slot or slot not in _legal_deployment_targets or not slot.can_accept_card(card):
		show_toast("Kartı yerleştirmek için mavi bir yuva seç.", Color(0.95, 0.52, 0.24))
		return {"success": false, "error": "Yerleştirme yuvası geçersiz."}

	if MatchSetup.is_multiplayer_player():
		var accepted := request_network_card_drop(card, slot)
		if accepted:
			_clear_deployment_selection()
		else:
			show_toast("Sunucu önceki hamleyi çözüyor.", Color(0.95, 0.52, 0.24))
		return {"success": accepted, "pending": accepted}

	var start_global_position := card.global_position
	var start_rotation := card.rotation
	var result := play_hand_card_to_slot(card, slot)
	if not bool(result.get("success", false)):
		show_toast(str(result.get("error", "Kart yerleştirilemedi.")), Color(0.95, 0.38, 0.24))
		_legal_deployment_targets.clear()
		for candidate in get_board_slots(card.owner_id):
			if candidate.can_accept_card(card):
				_legal_deployment_targets.append(candidate)
		_refresh_deployment_highlights()
		return result

	_clear_deployment_selection()
	_refresh_lane_visuals()
	_apply_responsive_layout()
	card.animate_deployment_from(start_global_position, start_rotation)
	show_toast(
		tr("%s deployed.") % tr(card.card_name),
		Color(0.38, 0.90, 0.72),
		tr("DEPLOYED")
	)
	return result

func _refresh_deployment_highlights() -> void:
	_prepare_target_context(null)
	for slot in _legal_deployment_targets:
		if slot and is_instance_valid(slot):
			slot.set_combat_highlight(CardSlot.CombatHighlight.MOVE_TARGET, "YERLEŞTİR")

func _clear_deployment_selection() -> void:
	if _selected_deployment_card and is_instance_valid(_selected_deployment_card):
		_selected_deployment_card.set_meta("deployment_selected", false)
		_selected_deployment_card.modulate = Color.WHITE
		_selected_deployment_card.set_selection_visual(false)
	_selected_deployment_card = null
	_legal_deployment_targets.clear()
	if not is_inside_tree():
		return
	if _selected_effect_card:
		_refresh_effect_highlights()
	elif _selected_mover:
		_refresh_movement_highlights()
	elif _selected_attacker:
		_refresh_combat_highlights()
	else:
		_clear_slot_target_highlights()
	_refresh_phase_ui()

func request_hand_card_selection(card: BaseCard) -> void:
	if not card or not is_instance_valid(card) or not game_manager:
		return
	if is_card_interaction_locked() or card.current_slot != null:
		return
	if card.owner_id != game_manager.active_player_id:
		return

	match game_manager.current_phase:
		GameManager.TurnPhase.MULLIGAN:
			_toggle_phase_selected_card(card)
		GameManager.TurnPhase.END:
			if _discard_required <= 0:
				return
			if card not in _phase_selected_cards and _phase_selected_cards.size() >= _discard_required:
				show_toast(tr("You must select exactly %d cards.") % _discard_required, Color(0.95, 0.38, 0.24))
				return
			_toggle_phase_selected_card(card)

func _toggle_phase_selected_card(card: BaseCard) -> void:
	if card in _phase_selected_cards:
		_phase_selected_cards.erase(card)
		_set_phase_card_selected(card, false)
	else:
		_phase_selected_cards.append(card)
		_set_phase_card_selected(card, true)
	_refresh_phase_ui()

func _set_phase_card_selected(card: BaseCard, selected: bool) -> void:
	if not card or not is_instance_valid(card):
		return
	card.set_meta("phase_selected", selected)
	card.modulate = Color.WHITE
	card.set_selection_visual(selected, UI.BRASS_BRIGHT)

func _clear_phase_selection() -> void:
	for card in _phase_selected_cards:
		_set_phase_card_selected(card, false)
	_phase_selected_cards.clear()

func _confirm_mulligan_selection() -> void:
	if not game_manager or game_manager.current_phase != GameManager.TurnPhase.MULLIGAN:
		return
	var player_id: int = game_manager.active_player_id
	var selected_cards: Array[BaseCard] = []
	for card in _phase_selected_cards:
		if card and is_instance_valid(card):
			selected_cards.append(card)
	if MatchSetup.is_multiplayer_player():
		var card_ids: Array[String] = []
		for card in selected_cards:
			card_ids.append(_get_card_network_id(card))
		_clear_phase_selection()
		_request_network_action("mulligan", {"card_ids": card_ids})
		return
	_phase_selected_cards.clear()
	await resolve_mulligan_for_player(player_id, selected_cards)

func resolve_mulligan_for_player(player_id: int, selected_cards: Array[BaseCard]) -> bool:
	if (
		not game_manager
		or game_manager.current_phase != GameManager.TurnPhase.MULLIGAN
		or game_manager.active_player_id != player_id
		or _is_confirming_selection
	):
		return false
	var hand := _get_hand_for_player(player_id)
	for card in selected_cards:
		if not card or not is_instance_valid(card) or card.owner_id != player_id or card.get_parent() != hand:
			return false

	_is_confirming_selection = true
	_refresh_phase_ui()
	var returned_refs: Array = []

	for card in selected_cards:
		var card_ref: Dictionary = card.get_meta("deck_ref", {})
		if not card_ref.is_empty():
			returned_refs.append(card_ref.duplicate(true))
		var parent: Node = card.get_parent()
		if parent:
			parent.remove_child(card)
		card.queue_free()

	# Replacement cards are drawn before returned cards re-enter the deck, so a
	# mulligan cannot immediately hand the exact same physical copy back.
	for _index in range(returned_refs.size()):
		await _draw_card_to_hand(player_id, false)

	var deck: Array = _player_decks.get(player_id, [])
	deck.append_array(returned_refs)
	var rng := _deck_rngs.get(player_id) as RandomNumberGenerator
	if not rng:
		rng = MatchSetup.create_rng(10 + player_id)
		_deck_rngs[player_id] = rng
	CardDatabase.shuffle_with_rng(deck, rng)
	_player_decks[player_id] = deck
	_is_confirming_selection = false
	_update_deck_ui()
	var confirmed: bool = game_manager.confirm_mulligan(player_id)
	_refresh_phase_ui()
	return confirmed

func _prepare_end_phase() -> void:
	if not game_manager or game_manager.current_phase != GameManager.TurnPhase.END:
		return
	if MatchSetup.is_ai_player(game_manager.active_player_id):
		return
	var active_player_id: int = int(game_manager.active_player_id)
	var hand: Control = _get_hand_for_player(active_player_id)
	_discard_required = max(0, _get_hand_card_count(hand) - GameRules.MAX_HAND_SIZE)
	if _discard_required == 0:
		if not MatchSetup.is_multiplayer_client():
			# Dedicated servers and hosted rooms resolve the authoritative no-discard
			# transition immediately. Remote clients only render the resulting state.
			game_manager.complete_end_phase(active_player_id)
		return
	if MatchSetup.is_multiplayer_player() and active_player_id != MatchSetup.human_player_id:
		# The host still owns the authoritative opponent hand, but must never be
		# offered controls for it. The remote owner will submit the discard action.
		_discard_required = 0
		_refresh_phase_ui()
		return

	show_toast(
		tr("Hand limit %d: select %d cards to discard.") % [GameRules.MAX_HAND_SIZE, _discard_required],
		Color(0.95, 0.52, 0.24)
	)
	_refresh_phase_ui()

func _confirm_discard_selection() -> void:
	if not game_manager or game_manager.current_phase != GameManager.TurnPhase.END:
		return
	if _discard_required <= 0 or _phase_selected_cards.size() != _discard_required:
		return

	var player_id: int = game_manager.active_player_id
	var selected_cards: Array[BaseCard] = []
	for card in _phase_selected_cards:
		if card and is_instance_valid(card):
			selected_cards.append(card)
	if MatchSetup.is_multiplayer_player():
		var card_ids: Array[String] = []
		for card in selected_cards:
			card_ids.append(_get_card_network_id(card))
		_clear_phase_selection()
		_request_network_action("discard", {"card_ids": card_ids})
		return
	_phase_selected_cards.clear()
	resolve_end_phase_for_player(player_id, selected_cards)

func get_required_discard_count(player_id: int) -> int:
	return max(0, _get_hand_card_count(_get_hand_for_player(player_id)) - GameRules.MAX_HAND_SIZE)

func resolve_ai_end_phase(player_id: int, selected_cards: Array[BaseCard]) -> bool:
	return resolve_end_phase_for_player(player_id, selected_cards)

func resolve_end_phase_for_player(player_id: int, selected_cards: Array[BaseCard]) -> bool:
	if (
		not game_manager
		or not game_manager.is_game_active
		or game_manager.current_phase != GameManager.TurnPhase.END
		or game_manager.active_player_id != player_id
	):
		return false
	var required := get_required_discard_count(player_id)
	if selected_cards.size() != required:
		return false
	var hand := _get_hand_for_player(player_id)
	var unique_cards: Array[BaseCard] = []
	for card in selected_cards:
		if (
			not card
			or not is_instance_valid(card)
			or card.get_parent() != hand
			or card in unique_cards
		):
			return false
		unique_cards.append(card)
	for card in unique_cards:
		_record_graveyard_card(card, "discard")
		var parent: Node = card.get_parent()
		if parent:
			parent.remove_child(card)
		card.queue_free()

	_discard_required = 0
	return game_manager.complete_end_phase(player_id)

func is_card_interaction_locked() -> bool:
	var network_manager := _get_network_manager()
	var multiplayer_player_locked: bool = (
		MatchSetup.is_multiplayer_player()
		and (
			game_manager == null
			or MatchSetup.human_player_id not in GameRules.PLAYER_IDS
			or game_manager.active_player_id != MatchSetup.human_player_id
			or (network_manager != null and network_manager.is_action_pending())
		)
	)
	var reconnect_locked: bool = network_manager != null and bool(network_manager.is_match_waiting_for_reconnect())
	return (
		(game_manager != null and game_manager.current_phase == GameManager.TurnPhase.EFFECT_SELECTION)
		or
		_is_dealing_initial_hands
		or _is_draw_animation_running
		or _effect_draw_queue_running
		or _is_confirming_selection
		or _is_hand_tactic_resolving
		or _auto_attack_running
		or _combat_sequence_active
		or (get_tree() != null and get_tree().paused)
		or (_pause_menu != null and _pause_menu.is_open())
		or (game_manager != null and MatchSetup.is_ai_player(game_manager.active_player_id))
		or multiplayer_player_locked
		or reconnect_locked
		or (_tutorial_overlay != null and _tutorial_overlay.is_open())
		or (_rules_reference_panel != null and _rules_reference_panel.is_open())
		or (game_manager != null and not game_manager.is_game_active)
	)

func _on_game_over(winner_id: int) -> void:
	_active_match_completed = true
	if _scenario_refresh_timer:
		_scenario_refresh_timer.stop()
	if _scenario_briefing_panel and _scenario_briefing_panel.is_open():
		_scenario_briefing_panel.close_panel()
	if _can_persist_active_match():
		_active_match_repository.delete_all()
	_network_winner_id = winner_id
	_auto_attack_sequence_generation += 1
	if get_tree().paused:
		get_tree().paused = false
	if _pause_menu:
		_pause_menu.close_menu()
	_clear_phase_selection()
	_clear_deployment_selection()
	_clear_hand_tactic_selection()
	_clear_effect_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_clear_combat_selection()
	if _tutorial_overlay and _tutorial_overlay.is_open():
		_tutorial_overlay.visible = false
	if _rules_reference_panel and _rules_reference_panel.is_open():
		_rules_reference_panel.visible = false
	if _feedback_layer:
		_feedback_layer.set_open_paths([])
		_feedback_layer.stop_all_feedback()
	if _board_impact_tween and _board_impact_tween.is_valid():
		_board_impact_tween.kill()
	_board_impact_tween = null
	_set_board_impact_offset(Vector2.ZERO)
	_feedback_attack_source_ref = null
	_feedback_attack_target_ref = null
	_clear_transient_feedback()
	if _feedback_audio:
		_feedback_audio.play_event("victory")
	var match_summary := _get_current_match_summary(winner_id)
	if MatchSetup.is_scenario_match():
		_scenario_evaluation = SCENARIO_OBJECTIVE_RESOLVER.evaluate(
			MatchSetup.get_scenario_context(),
			match_summary,
			MatchSetup.human_player_id
		)
	_update_game_over_summary(match_summary, MatchSetup.human_player_id)
	if _game_over_eyebrow_label:
		_game_over_eyebrow_label.text = (
			tr("CAMPAIGN ENDED")
			if MatchSetup.is_scenario_match()
			else "HAKİMİYET SONA ERDİ" if MatchSetup.is_dominion()
			else "KUŞATMA SONA ERDİ"
		)
	game_over_panel.visible = true
	if _game_over_restart_button:
		_game_over_restart_button.visible = MatchSetup.human_player_id in GameRules.PLAYER_IDS
		_game_over_restart_button.disabled = false
		_game_over_restart_button.text = (
			tr("REPLAY SCENARIO")
			if MatchSetup.is_scenario_match()
			else "RÖVANŞ İSTE" if MatchSetup.is_multiplayer_match()
			else "YENİDEN OYNA"
		)
	if _game_over_subtitle_label:
		var base_subtitle := (
			tr("Both commanders must approve a rematch.")
			if MatchSetup.is_multiplayer_match()
			else tr("Aynı düzenle yeniden savaş veya ana menüye dön.")
		)
		var reason_text := tr("Dominion objective completed.") if game_manager and game_manager.win_reason == "dominion" else tr("Enemy Headquarters fell.")
		_game_over_subtitle_label.text = "%s  %s" % [reason_text, base_subtitle]
	end_turn_button.disabled = true
	if _preparation_token_button:
		_preparation_token_button.disabled = true
		_preparation_token_button.visible = false
	if _tactical_supply_button:
		_tactical_supply_button.disabled = true
		_tactical_supply_button.visible = false
	if _auto_attack_checkbox:
		_auto_attack_checkbox.disabled = true
	if _auto_attack_panel:
		_auto_attack_panel.modulate.a = 0.56
	var human_player_id := MatchSetup.human_player_id
	if winner_id not in GameRules.PLAYER_IDS:
		winner_label.text = tr("DRAW")
	elif human_player_id in GameRules.PLAYER_IDS and winner_id == human_player_id:
		winner_label.text = "%s\n%s" % [tr("VICTORY"), tr("YOU")]
	else:
		var winner_name := tr("OYUNCU %d") % winner_id
		if MatchSetup.is_ai_player(winner_id):
			winner_name = tr(MatchSetup.get_ai_label(winner_id).to_upper())
		winner_label.text = "%s\n%s" % [tr("DEFEAT"), winner_name]
	if _game_over_restart_button:
		_game_over_restart_button.grab_focus()
	if game_manager and not game_manager.is_game_active:
		call_deferred("_finalize_profile_match", winner_id)


func _get_current_match_summary(winner_id: int) -> Dictionary:
	var summary := {}
	if MatchSetup.is_multiplayer_client() and not _network_match_summary.is_empty():
		summary = _network_match_summary.duplicate(true)
	elif _match_telemetry:
		summary = _match_telemetry.get_summary()
	if summary.is_empty():
		summary = {
			"match_id": "%d-%d" % [MatchSetup.match_seed, Time.get_ticks_usec()],
			"match_name": MatchSetup.match_name,
			"seed": MatchSetup.match_seed,
			"ruleset": int(MatchSetup.ruleset),
			"ruleset_name": MatchSetup.get_ruleset_name(),
			"turn_duration_seconds": MatchSetup.turn_duration_seconds,
			"round_count": game_manager.round_count if game_manager else 0,
			"duration_seconds": 0.0,
			"players": {},
		}
	summary["winner_id"] = winner_id
	summary["ruleset"] = int(MatchSetup.ruleset)
	summary["ruleset_name"] = MatchSetup.get_ruleset_name()
	summary["scenario_context"] = MatchSetup.get_scenario_context()
	summary["scenario_id"] = MatchSetup.get_scenario_id()
	if game_manager:
		summary["round_count"] = game_manager.round_count
		summary["win_reason"] = game_manager.win_reason
		summary["dominion_scores"] = game_manager.player_dominion_score.duplicate(true)
		summary["last_dominion_lane_results"] = game_manager.last_dominion_lane_results.duplicate(true)
		var players_variant: Variant = summary.get("players", {})
		var players: Dictionary = players_variant as Dictionary if players_variant is Dictionary else {}
		for player_id in GameRules.PLAYER_IDS:
			var metrics_variant: Variant = _dictionary_player_value(players, player_id, {})
			var metrics: Dictionary = (metrics_variant as Dictionary).duplicate(true) if metrics_variant is Dictionary else {}
			var dominion_score := int(_dictionary_player_value(game_manager.player_dominion_score, player_id, 0))
			metrics["dominion_score"] = dominion_score
			metrics["dominion_points"] = int(metrics.get("dominion_points", dominion_score))
			metrics["dominion_lane_wins"] = int(metrics.get("dominion_lane_wins", dominion_score))
			players[player_id] = metrics
		summary["players"] = players
	return summary


func _update_game_over_summary(summary: Dictionary, perspective_player_id: int) -> void:
	var metrics := _summary_player_metrics(summary, perspective_player_id)
	var analysis: Dictionary = MATCH_ANALYSIS.analyze(summary, perspective_player_id)
	summary["match_analysis"] = analysis.duplicate(true)
	if _game_over_analysis_panel:
		_game_over_analysis_panel.set_analysis(analysis)
	_set_game_over_stat("duration", _format_match_duration(float(summary.get("duration_seconds", 0.0))))
	_set_game_over_stat("rounds", int(summary.get("round_count", 0)))
	_set_game_over_stat("cards_played", int(metrics.get("cards_played", 0)))
	if MatchSetup.is_dominion() and game_manager:
		_set_game_over_stat_title("hq_damage", "HAKİMİYET")
		_set_game_over_stat(
			"hq_damage",
			"%d / %d" % [
				int(game_manager.player_dominion_score.get(perspective_player_id, 0)),
				GameRules.DOMINION_SCORE_TARGET,
			]
		)
	else:
		_set_game_over_stat_title("hq_damage", "HQ HASARI")
		_set_game_over_stat("hq_damage", int(metrics.get("hq_damage", 0)))
	_set_game_over_stat("cards_destroyed", int(metrics.get("cards_destroyed", 0)))
	_set_game_over_stat("mvp", tr(str(metrics.get("mvp_card_name", "—"))))
	if _game_over_reward_label:
		_game_over_reward_label.text = tr("Preparing match summary for the profile…")


func _finalize_profile_match(winner_id: int) -> void:
	if (
		_profile_match_recorded
		or not game_manager
		or game_manager.is_game_active
		or MatchSetup.human_player_id not in GameRules.PLAYER_IDS
		or DisplayServer.get_name() == "headless"
	):
		return
	var profile_manager := get_node_or_null("/root/ProfileManager")
	if not profile_manager:
		if _game_over_reward_label:
			_game_over_reward_label.text = tr("Profile storage is unavailable; the match summary is preserved.")
		return
	_profile_match_recorded = true
	var summary := _get_current_match_summary(winner_id)
	_update_game_over_summary(summary, MatchSetup.human_player_id)
	var mode := "Yerel"
	if MatchSetup.is_scenario_match():
		mode = "Komutan Seferi"
	elif MatchSetup.is_multiplayer_match():
		mode = "Çevrimiçi"
	elif MatchSetup.is_ai_match():
		mode = "Yapay Zekâ"
	var deck_name := MatchSetup.get_player_deck_name(MatchSetup.human_player_id)
	if deck_name.is_empty():
		var deck_manager := get_node_or_null("/root/DeckManager")
		if deck_manager:
			deck_name = str(deck_manager.get_active_deck().get("name", ""))
	var result: Dictionary = profile_manager.record_match(
		summary,
		MatchSetup.human_player_id,
		mode,
		deck_name
	)
	var scenario_result := _record_scenario_profile_progress(profile_manager, summary)
	if not _game_over_reward_label:
		return
	var reward_parts: Array[String] = []
	if bool(result.get("recorded", false)):
		reward_parts.append("+%d XP" % int(result.get("xp_gained", 0)))
		reward_parts.append(tr("+%d Seals") % int(result.get("seals_gained", 0)))
		if int(result.get("level_after", 1)) > int(result.get("level_before", 1)):
			reward_parts.append(tr("Level %d") % int(result.get("level_after", 1)))
		var achievements := result.get("new_achievements", []) as Array
		if not achievements.is_empty():
			reward_parts.append(tr("Achievement: %s") % tr(str(achievements[0])))
		var missions := result.get("completed_missions", []) as Array
		if not missions.is_empty():
			reward_parts.append(tr("Mission: %s") % tr(str(missions[0])))
	if MatchSetup.is_scenario_match():
		var evaluation_variant: Variant = scenario_result.get("evaluation", _scenario_evaluation)
		var evaluation: Dictionary = evaluation_variant as Dictionary if evaluation_variant is Dictionary else {}
		var completed_count := int(evaluation.get("completed_required_count", 0))
		var required_count := int(evaluation.get("required_count", 0))
		if bool(evaluation.get("completed", false)):
			if bool(scenario_result.get("completed_now", false)):
				reward_parts.append(tr("SCENARIO COMPLETE"))
				var campaign_seals := int(scenario_result.get("seals_gained", 0))
				if campaign_seals > 0:
					reward_parts.append(tr("Campaign reward: +%d Seals") % campaign_seals)
			else:
				reward_parts.append(tr("Scenario objectives complete"))
		else:
			reward_parts.append(tr("Scenario objectives: %d/%d") % [completed_count, required_count])
		if not str(scenario_result.get("error", "")).is_empty():
			reward_parts.append(tr("Campaign progress could not be saved"))
	if reward_parts.is_empty():
		reward_parts.append(tr("The match was already recorded in the profile."))
	_game_over_reward_label.text = "  •  ".join(reward_parts)


func _record_scenario_profile_progress(profile_manager: Node, summary: Dictionary) -> Dictionary:
	if not MatchSetup.is_scenario_match():
		return {}
	if not profile_manager.has_method("record_scenario_result"):
		return {"recorded": false, "error": "Profil deposu kampanya ilerlemesini desteklemiyor."}
	var scenario := _scenario_definition
	if scenario.is_empty():
		var load_result := SCENARIO_CATALOG.load_catalog()
		if not bool(load_result.get("success", false)):
			return {"recorded": false, "error": str(load_result.get("error", "Senaryo kataloğu yüklenemedi."))}
		scenario = SCENARIO_CATALOG.get_scenario(MatchSetup.get_scenario_id())
	if scenario.is_empty():
		return {"recorded": false, "error": "Etkin senaryo katalogda bulunamadı."}
	var context := MatchSetup.get_scenario_context()
	_scenario_evaluation = SCENARIO_OBJECTIVE_RESOLVER.evaluate(
		context,
		summary,
		MatchSetup.human_player_id
	)
	var match_id := str(summary.get("match_id", MatchSetup.match_id))
	var result: Dictionary = profile_manager.record_scenario_result(
		str(context.get("campaign_id", "")),
		scenario,
		_scenario_evaluation,
		match_id
	)
	result["evaluation"] = _scenario_evaluation.duplicate(true)
	return result


func _summary_player_metrics(summary: Dictionary, player_id: int) -> Dictionary:
	var players_variant: Variant = summary.get("players", {})
	if not players_variant is Dictionary:
		return {}
	var players := players_variant as Dictionary
	if players.has(player_id) and players[player_id] is Dictionary:
		return (players[player_id] as Dictionary).duplicate(true)
	if players.has(str(player_id)) and players[str(player_id)] is Dictionary:
		return (players[str(player_id)] as Dictionary).duplicate(true)
	return {}


func _set_game_over_stat(key: String, value: Variant) -> void:
	if _game_over_stat_values.has(key):
		(_game_over_stat_values[key] as Label).text = str(value)


func _set_game_over_stat_title(key: String, value: String) -> void:
	if _game_over_stat_titles.has(key):
		(_game_over_stat_titles[key] as Label).text = value


func _format_match_duration(seconds: float) -> String:
	var total := maxi(0, int(round(seconds)))
	return "%02d:%02d" % [total / 60, total % 60]

func _on_restart_match_pressed() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if MatchSetup.is_multiplayer_match():
		var network_manager := _get_network_manager()
		if network_manager and network_manager.request_rematch():
			_game_over_restart_button.disabled = true
			_game_over_restart_button.text = tr("WAITING FOR OPPONENT")
			if _game_over_subtitle_label:
				_game_over_subtitle_label.text = tr("Rematch request sent; waiting for the opponent's approval.")
		return
	if MatchSetup.is_scenario_match():
		var replay_result := SCENARIO_MATCH_CONFIGURATOR.configure(
			MatchSetup.get_scenario_id(),
			get_node_or_null("/root/DeckManager")
		)
		if not bool(replay_result.get("success", false)):
			if _game_over_reward_label:
				_game_over_reward_label.text = tr("Scenario could not be restarted: %s") % str(replay_result.get("error", ""))
			return
	get_tree().reload_current_scene()

func _on_game_over_main_menu_pressed() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if MatchSetup.is_multiplayer_match():
		var network_manager := _get_network_manager()
		if network_manager:
			network_manager.leave_network(true)
			return
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _connect_network_session_signals() -> void:
	if not MatchSetup.is_multiplayer_match():
		return
	var network_manager := _get_network_manager()
	if not network_manager:
		return
	var rematch_callback := Callable(self, "_on_network_rematch_status_changed")
	if not network_manager.is_connected("rematch_status_changed", rematch_callback):
		network_manager.connect("rematch_status_changed", rematch_callback)
	var connection_callback := Callable(self, "_on_network_opponent_connection_changed")
	if not network_manager.is_connected("opponent_connection_changed", connection_callback):
		network_manager.connect("opponent_connection_changed", connection_callback)
	var pending_callback := Callable(self, "_on_network_action_pending_changed")
	if not network_manager.is_connected("action_pending_changed", pending_callback):
		network_manager.connect("action_pending_changed", pending_callback)


func _on_network_rematch_status_changed(votes: int, required_votes: int, message: String) -> void:
	if _game_over_subtitle_label:
		_game_over_subtitle_label.text = _localize_display_text(message, "Rematch status updated.")
	if _game_over_restart_button:
		_game_over_restart_button.text = tr("REMATCH %d/%d") % [votes, required_votes]


func _on_network_opponent_connection_changed(_player_id: int, connected: bool, seconds_remaining: int) -> void:
	show_toast(
		tr("Opponent reconnected.") if connected else tr("Opponent disconnected; waiting %d seconds.") % seconds_remaining,
		Color(0.38, 0.90, 0.62) if connected else Color(0.95, 0.58, 0.24),
		"BAĞLANTI"
	)
	_refresh_phase_ui()


func _on_network_action_pending_changed(_is_pending: bool) -> void:
	_refresh_phase_ui()

func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	if _effect_selection_panel:
		_effect_selection_panel.custom_minimum_size = Vector2(
			minf(1040.0, maxf(760.0, viewport_size.x - 36.0)),
			minf(650.0, maxf(560.0, viewport_size.y - 28.0))
		)
		_layout_effect_offer_cards()

	var outer_pad = clamp(viewport_size.x * 0.012, 8.0, 18.0)
	var hud_width = clamp(viewport_size.x * 0.23, 260.0, 330.0)
	var hud_gap = clamp(viewport_size.x * 0.008, 8.0, 12.0)
	var right_reserved = hud_width + hud_gap + outer_pad
	var zone_width = max(480.0, viewport_size.x - outer_pad - right_reserved)

	# The sidebar stays fixed while the arena below behaves like a camera view.
	hud.anchor_left = 1.0
	hud.anchor_top = 0.0
	hud.anchor_right = 1.0
	hud.anchor_bottom = 1.0
	hud.offset_left = -hud_width
	hud.offset_top = 0.0
	hud.offset_right = 0.0
	hud.offset_bottom = 0.0
	hud.z_index = 200
	_configure_top_hud(viewport_size, outer_pad, zone_width)

	var top_reserved = _get_top_playfield_reserved_height(viewport_size)
	var hand_dock_height = clamp(
		viewport_size.y * 0.245,
		HAND_DOCK_MIN_HEIGHT,
		HAND_DOCK_MAX_HEIGHT
	)
	var hand_dock_top = viewport_size.y - hand_dock_height
	_board_view_rect = Rect2(
		Vector2(outer_pad, top_reserved + 4.0),
		Vector2(zone_width, maxf(120.0, hand_dock_top - top_reserved - 12.0))
	)
	if _feedback_clip:
		_set_control_rect(_feedback_clip, _board_view_rect)

	if _hand_dock:
		_hand_dock.anchor_left = 0.0
		_hand_dock.anchor_top = 0.0
		_hand_dock.anchor_right = 0.0
		_hand_dock.anchor_bottom = 0.0
		_hand_dock.offset_left = outer_pad
		_hand_dock.offset_top = 0.0
		_hand_dock.offset_right = outer_pad + zone_width
		_hand_dock.offset_bottom = viewport_size.y
	if _hand_dock_backdrop:
		_hand_dock_backdrop.anchor_left = 0.0
		_hand_dock_backdrop.anchor_top = 0.0
		_hand_dock_backdrop.anchor_right = 0.0
		_hand_dock_backdrop.anchor_bottom = 0.0
		_hand_dock_backdrop.offset_left = 0.0
		_hand_dock_backdrop.offset_top = hand_dock_top
		_hand_dock_backdrop.offset_right = zone_width
		_hand_dock_backdrop.offset_bottom = viewport_size.y

	_refresh_hand_visibility()
	var local_hand_player_id := _get_hand_perspective_player_id()
	var opponent_hand_player_id := 2 if local_hand_player_id == 1 else 1
	var local_hand := _get_hand_for_player(local_hand_player_id)
	var opponent_hand := _get_hand_for_player(opponent_hand_player_id)
	# The physical deck now lives beside the Headquarters in board space, so the
	# entire lower dock can be used to show the local hand at a readable size.
	var local_hand_left := 12.0
	var local_hand_width := maxf(180.0, zone_width - (local_hand_left * 2.0))
	var local_hand_top = hand_dock_top - 18.0
	var local_hand_height = hand_dock_height + 18.0
	if local_hand:
		_configure_hand_frame(
			local_hand,
			local_hand_left,
			local_hand_top,
			Vector2(local_hand_width, local_hand_height)
		)

	var opponent_hand_width = clamp(
		zone_width * 0.26,
		OPPONENT_HAND_MIN_WIDTH,
		minf(OPPONENT_HAND_MAX_WIDTH, zone_width - 32.0)
	)
	var opponent_hand_height = clamp(viewport_size.y * 0.12, 78.0, 98.0)
	var opponent_hand_left = 16.0
	var opponent_hand_top = top_reserved + 5.0
	if opponent_hand:
		_configure_hand_frame(
			opponent_hand,
			opponent_hand_left,
			opponent_hand_top,
			Vector2(opponent_hand_width, opponent_hand_height)
		)
	if _opponent_hand_backdrop:
		_opponent_hand_backdrop.anchor_left = 0.0
		_opponent_hand_backdrop.anchor_top = 0.0
		_opponent_hand_backdrop.anchor_right = 0.0
		_opponent_hand_backdrop.anchor_bottom = 0.0
		_opponent_hand_backdrop.offset_left = opponent_hand_left - 8.0
		_opponent_hand_backdrop.offset_top = opponent_hand_top - 4.0
		_opponent_hand_backdrop.offset_right = opponent_hand_left + opponent_hand_width + 8.0
		_opponent_hand_backdrop.offset_bottom = opponent_hand_top + opponent_hand_height + 4.0

	var local_card_count := maxi(1, _get_hand_card_count(local_hand)) if local_hand else 1
	var local_span_at_unit_scale = HAND_CARD_BASE_SIZE.x * (
		1.0 + (float(local_card_count - 1) * HAND_CARD_OVERLAP_RATIO)
	)
	var max_hand_scale_by_width = max(1.0, local_hand_width - 28.0) / local_span_at_unit_scale
	var max_hand_scale_by_height = max(1.0, local_hand_height - 14.0) / HAND_CARD_BASE_SIZE.y
	_hand_card_scale = clamp(
		min(max_hand_scale_by_width, max_hand_scale_by_height),
		HAND_CARD_MIN_SCALE,
		HAND_CARD_MAX_SCALE
	)
	var opponent_card_count := maxi(1, _get_hand_card_count(opponent_hand)) if opponent_hand else 1
	var opponent_span_at_unit_scale = HAND_CARD_BASE_SIZE.x * (
		1.0 + (float(opponent_card_count - 1) * HAND_CARD_OVERLAP_RATIO)
	)
	var max_opponent_scale_by_width = max(1.0, opponent_hand_width - 20.0) / opponent_span_at_unit_scale
	var max_opponent_scale_by_height = max(1.0, opponent_hand_height - 16.0) / HAND_CARD_BASE_SIZE.y
	_opponent_hand_card_scale = clamp(min(max_opponent_scale_by_width, max_opponent_scale_by_height), 0.22, 0.31)

	_configure_board_world_geometry()
	_board_fit_zoom = clamp(
		min(
			_board_view_rect.size.x / maxf(_board_world_size.x, 1.0),
			_board_view_rect.size.y / maxf(_board_world_size.y, 1.0)
		) * 0.96,
		BOARD_MIN_ZOOM,
		BOARD_MAX_ZOOM
	)
	if not _board_camera_initialized:
		_board_camera_center = _get_default_board_camera_center()
		_board_zoom = _get_default_board_zoom()
		_board_camera_initialized = true
	elif not _board_view_was_adjusted:
		_board_camera_center = _get_default_board_camera_center()
		_board_zoom = _get_default_board_zoom()
	_clamp_board_camera()
	_layout_battlefield_world_objects()
	_configure_deck_frames(viewport_size)
	_apply_board_camera_transform()
	_layout_battlefield_status_ui()
	_position_toast_panel(viewport_size)
	_refresh_hand_card_layouts()
	_layout_phase_banner(viewport_size)
	_refresh_open_lane_paths()
	_layout_board_navigation(hand_dock_top, outer_pad, zone_width)

func _configure_board_world_geometry() -> void:
	var side_extent := BOARD_SLOT_SIZE.x + BOARD_HQ_GAP
	var hq_extent := BOARD_SLOT_SIZE.y + BOARD_HQ_GAP
	var grid_left := BOARD_WORLD_PADDING.x + side_extent
	var north_top := BOARD_WORLD_PADDING.y
	var zone_height := BOARD_GRID_BASE_SIZE.y + hq_extent
	var south_top := north_top + zone_height + BOARD_CENTER_GAP
	var zone_width := BOARD_GRID_BASE_SIZE.x
	var south_player_id := _get_battlefield_perspective_player_id()
	var north_rect := Rect2(Vector2(grid_left, north_top), Vector2(zone_width, zone_height))
	var south_rect := Rect2(Vector2(grid_left, south_top), Vector2(zone_width, zone_height))

	_board_world_size = Vector2(
		BOARD_GRID_BASE_SIZE.x + (side_extent * 2.0) + (BOARD_WORLD_PADDING.x * 2.0),
		(zone_height * 2.0) + BOARD_CENTER_GAP + (BOARD_WORLD_PADDING.y * 2.0)
	)
	_p1_zone_world_rect = south_rect if south_player_id == 1 else north_rect
	_p2_zone_world_rect = south_rect if south_player_id == 2 else north_rect
	_lane_board_world_rect = Rect2(
		Vector2(grid_left, north_top + hq_extent),
		Vector2(BOARD_GRID_BASE_SIZE.x, (south_top + BOARD_GRID_BASE_SIZE.y) - (north_top + hq_extent))
	)
	_platform_world_rect = Rect2(
		Vector2(BOARD_WORLD_PADDING.x, north_top),
		Vector2(
			_board_world_size.x - (BOARD_WORLD_PADDING.x * 2.0),
			(south_top + zone_height) - north_top
		)
	)
	_board_divider_world_y = north_top + zone_height + (BOARD_CENTER_GAP * 0.5)

	_configure_board_zone(player2_zone, _p2_zone_world_rect.size)
	_configure_board_zone(player1_zone, _p1_zone_world_rect.size)

	var hq_left := (BOARD_GRID_BASE_SIZE.x - BOARD_SLOT_SIZE.x) * 0.5
	for player_id in GameRules.PLAYER_IDS:
		var is_south := player_id == south_player_id
		var grid: Control = p1_grid if player_id == 1 else p2_grid
		var hq_slot: CardSlot = p1_hq_slot if player_id == 1 else p2_hq_slot
		var grid_top := 0.0 if is_south else hq_extent
		var hq_top := BOARD_GRID_BASE_SIZE.y + BOARD_HQ_GAP if is_south else 0.0
		_set_control_rect(grid, Rect2(Vector2(0.0, grid_top), BOARD_GRID_BASE_SIZE))
		_layout_board_slots(
			grid,
			is_south,
			BOARD_SLOT_SIZE,
			BOARD_SLOT_GAP,
			BOARD_GRID_BASE_SIZE,
			1.0
		)
		_place_board_slot(hq_slot, Vector2(hq_left, hq_top), BOARD_SLOT_SIZE, 1.0)

		var label := _zone_labels.get(player_id) as Label
		if label:
			label.position = Vector2(-112.0, hq_top + ((BOARD_SLOT_SIZE.y - 64.0) * 0.5))
			label.size = Vector2(164.0, 64.0)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_layout_hq_resource_badges()


func _layout_hq_resource_badges() -> void:
	var badge_size := Vector2(70.0, 36.0)
	for player_id in GameRules.PLAYER_IDS:
		var entry_variant: Variant = _field_resource_badges.get(player_id, {})
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var energy_badge := entry.get("energy") as Control
		var health_badge := entry.get("health") as Control
		var center_y := (BOARD_SLOT_SIZE.y - badge_size.y) * 0.5
		if energy_badge:
			_set_control_rect(
				energy_badge,
				Rect2(Vector2(-badge_size.x - 8.0, center_y), badge_size)
			)
		if health_badge:
			_set_control_rect(
				health_badge,
				Rect2(Vector2(BOARD_SLOT_SIZE.x + 8.0, center_y), badge_size)
			)

func _configure_board_zone(zone: Control, world_size: Vector2) -> void:
	if not zone:
		return
	zone.anchor_left = 0.0
	zone.anchor_top = 0.0
	zone.anchor_right = 0.0
	zone.anchor_bottom = 0.0
	zone.offset_left = 0.0
	zone.offset_top = 0.0
	zone.offset_right = world_size.x
	zone.offset_bottom = world_size.y
	zone.pivot_offset = Vector2.ZERO
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _set_control_rect(control: Control, control_rect: Rect2) -> void:
	if not control:
		return
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = control_rect.position.x
	control.offset_top = control_rect.position.y
	control.offset_right = control_rect.end.x
	control.offset_bottom = control_rect.end.y

func _get_default_board_zoom() -> float:
	return clampf(
		maxf(_board_fit_zoom, BOARD_DEFAULT_FOCUS_ZOOM),
		BOARD_MIN_ZOOM,
		BOARD_MAX_ZOOM
	)

func _get_default_board_camera_center() -> Vector2:
	var perspective_player_id := _get_hand_perspective_player_id()
	var perspective_zone := _p1_zone_world_rect if perspective_player_id == 1 else _p2_zone_world_rect
	return Vector2(
		_board_world_size.x * 0.5,
		lerpf(_board_divider_world_y, perspective_zone.get_center().y, 0.65)
	)


func _get_hq_world_rect(player_id: int) -> Rect2:
	var zone_rect := _get_player_zone_world_rect(player_id)
	var hq_left := (BOARD_GRID_BASE_SIZE.x - BOARD_SLOT_SIZE.x) * 0.5
	var hq_top := BOARD_GRID_BASE_SIZE.y + BOARD_HQ_GAP if _is_player_on_south(player_id) else 0.0
	return Rect2(zone_rect.position + Vector2(hq_left, hq_top), BOARD_SLOT_SIZE)


func _get_field_name_world_rect(player_id: int) -> Rect2:
	var hq_rect := _get_hq_world_rect(player_id)
	var badge_top := (
		hq_rect.end.y + FIELD_NAME_HQ_GAP
		if _is_player_on_south(player_id)
		else hq_rect.position.y - FIELD_NAME_HQ_GAP - FIELD_NAME_BADGE_SIZE.y
	)
	return Rect2(
		Vector2(
			hq_rect.get_center().x - (FIELD_NAME_BADGE_SIZE.x * 0.5),
			badge_top
		),
		FIELD_NAME_BADGE_SIZE
	)


func _get_team_standard_world_center(player_id: int) -> Vector2:
	var hq_rect := _get_hq_world_rect(player_id)
	var deck_rect := Rect2(
		Vector2(
			hq_rect.position.x - DECK_HQ_HORIZONTAL_GAP - DECK_PANEL_SIZE.x,
			hq_rect.get_center().y - (DECK_PANEL_SIZE.y * 0.5)
		),
		DECK_PANEL_SIZE
	)
	var zone_rect := _get_player_zone_world_rect(player_id)
	var grid_top := zone_rect.position.y + (0.0 if _is_player_on_south(player_id) else BOARD_SLOT_SIZE.y + BOARD_HQ_GAP)
	var grid_rect := Rect2(Vector2(zone_rect.position.x, grid_top), BOARD_GRID_BASE_SIZE)
	return Vector2(
		deck_rect.get_center().x,
		grid_rect.get_center().y
	)


func _get_effect_mount_world_rect(player_id: int) -> Rect2:
	var hq_rect := _get_hq_world_rect(player_id)
	return Rect2(
		Vector2(
			hq_rect.end.x + EFFECT_HQ_HORIZONTAL_GAP,
			hq_rect.get_center().y - (EFFECT_FIELD_MOUNT_SIZE.y * 0.5)
		),
		EFFECT_FIELD_MOUNT_SIZE
	)

func _board_world_to_screen(world_point: Vector2) -> Vector2:
	return _board_view_rect.get_center() + ((world_point - _board_camera_center) * _board_zoom) + _board_impact_offset

func _board_world_rect_to_screen(world_rect: Rect2) -> Rect2:
	return Rect2(
		_board_world_to_screen(world_rect.position),
		world_rect.size * _board_zoom
	)

func _apply_board_camera_transform() -> void:
	if not _board_camera_initialized or _board_world_size == Vector2.ZERO:
		return

	if _battlefield_world_objects:
		_battlefield_world_objects.position = _board_world_to_screen(Vector2.ZERO)
		_battlefield_world_objects.scale = Vector2.ONE * _board_zoom

	player2_zone.position = _board_world_to_screen(_p2_zone_world_rect.position)
	player2_zone.scale = Vector2.ONE * _board_zoom
	player1_zone.position = _board_world_to_screen(_p1_zone_world_rect.position)
	player1_zone.scale = Vector2.ONE * _board_zoom

	var platform_screen_rect := _board_world_rect_to_screen(_platform_world_rect)
	var lane_screen_rect := _board_world_rect_to_screen(_lane_board_world_rect)
	var p1_zone_screen_rect := _board_world_rect_to_screen(_p1_zone_world_rect)
	var p2_zone_screen_rect := _board_world_rect_to_screen(_p2_zone_world_rect)
	var divider_y := _board_world_to_screen(Vector2(0.0, _board_divider_world_y)).y
	divider.anchor_left = 0.0
	divider.anchor_top = 0.0
	divider.anchor_right = 0.0
	divider.anchor_bottom = 0.0
	divider.offset_left = platform_screen_rect.position.x
	divider.offset_top = divider_y - 1.0
	divider.offset_right = platform_screen_rect.end.x
	divider.offset_bottom = divider_y + 1.0

	if _arena_overlay:
		var standard_centers := {
			1: _board_world_to_screen(_get_team_standard_world_center(1)),
			2: _board_world_to_screen(_get_team_standard_world_center(2)),
		}
		_arena_overlay.configure(
			_board_view_rect.end.x,
			_board_view_rect.position.y,
			divider_y,
			lane_screen_rect,
			platform_screen_rect,
			_board_view_rect,
			p1_zone_screen_rect,
			p2_zone_screen_rect,
			standard_centers
		)
	_update_board_zoom_label()
	_refresh_open_lane_paths()
	_refresh_active_attack_feedback()
	_refresh_transient_feedback_positions()

func _set_board_impact_offset(value: Vector2) -> void:
	_board_impact_offset = value
	_apply_board_camera_transform()

func _play_board_impact_shake(kind: String, power: float = 1.0) -> bool:
	if MatchSetup.fast_mode or not is_inside_tree() or not _board_camera_initialized:
		return false
	var normalized := kind.strip_edges().to_lower()
	var strength := 3.0
	match normalized:
		BattlefieldFeedbackLayer.IMPACT_CRITICAL:
			strength = 10.0
		BattlefieldFeedbackLayer.IMPACT_ARMOR_BREAK:
			strength = 6.2
		BattlefieldFeedbackLayer.IMPACT_BLOCKED:
			strength = 4.2
		_:
			strength = 3.0
	strength *= clampf(0.78 + power * 0.055, 0.82, 1.42)
	impact_shake_count += 1
	last_impact_shake_kind = normalized
	if _board_impact_tween and _board_impact_tween.is_valid():
		_board_impact_tween.kill()
	_set_board_impact_offset(Vector2.ZERO)
	var direction := -1.0 if impact_shake_count % 2 == 0 else 1.0
	var offsets := [
		Vector2(strength * direction, -strength * 0.38),
		Vector2(-strength * 0.72 * direction, strength * 0.24),
		Vector2(strength * 0.38 * direction, -strength * 0.12),
	]
	var segment_seconds := BOARD_IMPACT_SHAKE_SECONDS / 4.0
	var from_offset := Vector2.ZERO
	_board_impact_tween = create_tween().bind_node(self).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for target_offset in offsets:
		_board_impact_tween.tween_method(
			Callable(self, "_set_board_impact_offset"),
			from_offset,
			target_offset,
			segment_seconds
		)
		from_offset = target_offset
	_board_impact_tween.tween_method(
		Callable(self, "_set_board_impact_offset"),
		from_offset,
		Vector2.ZERO,
		segment_seconds
	)
	return true


func _layout_battlefield_world_objects() -> void:
	if not _battlefield_world_objects or _board_world_size == Vector2.ZERO:
		return
	_configure_board_zone(_battlefield_world_objects, _board_world_size)
	for player_id in GameRules.PLAYER_IDS:
		var name_badge := _field_name_badges.get(player_id) as Control
		if not name_badge:
			continue
		if name_badge.get_parent() != _battlefield_world_objects:
			name_badge.reparent(_battlefield_world_objects, false)
		_set_control_rect(name_badge, _get_field_name_world_rect(player_id))
	if _effect_panel:
		if _effect_panel.get_parent() != _battlefield_world_objects:
			_effect_panel.reparent(_battlefield_world_objects, false)
		_set_control_rect(_effect_panel, Rect2(Vector2.ZERO, _board_world_size))
		_layout_effect_panel_contents()


func _layout_battlefield_status_ui() -> void:
	if _board_view_rect.size.x <= 0.0 or _board_view_rect.size.y <= 0.0:
		return
	var timer_size := Vector2(82.0, 54.0)
	var timer_left := _board_view_rect.position.x + 18.0
	var timer_top := clampf(
		_board_view_rect.get_center().y - timer_size.y * 0.5 - 54.0,
		_board_view_rect.position.y + 12.0,
		_board_view_rect.end.y - timer_size.y - 12.0
	)
	if _field_timer_badge:
		_set_control_rect(_field_timer_badge, Rect2(Vector2(timer_left, timer_top), timer_size))
	var resource_size := Vector2(timer_size.x, 44.0)
	var resource_gap := 8.0
	var energy_top := timer_top + timer_size.y + resource_gap
	if _field_own_energy_badge:
		_set_control_rect(
			_field_own_energy_badge,
			Rect2(Vector2(timer_left, energy_top), resource_size)
		)
	if _field_own_health_badge:
		_set_control_rect(
			_field_own_health_badge,
			Rect2(Vector2(timer_left, energy_top + resource_size.y + resource_gap), resource_size)
		)
	if _field_round_badge:
		var round_size := Vector2(104.0, 42.0)
		_set_control_rect(
			_field_round_badge,
			Rect2(
				Vector2(_board_view_rect.end.x - round_size.x - 12.0, _board_view_rect.position.y + 12.0),
				round_size
			)
		)


func _layout_effect_panel_contents() -> void:
	if not _effect_panel or not _effect_panel_own_mount or not _effect_panel_enemy_mount:
		return
	if _board_world_size == Vector2.ZERO:
		return
	var perspective_player_id := _get_effect_perspective_player_id()
	if perspective_player_id not in GameRules.PLAYER_IDS:
		perspective_player_id = 1
	var opponent_player_id := 2 if perspective_player_id == 1 else 1
	var own_rect := _get_effect_mount_world_rect(perspective_player_id)
	var enemy_rect := _get_effect_mount_world_rect(opponent_player_id)
	_set_control_rect(_effect_panel_own_mount, own_rect)
	_set_control_rect(_effect_panel_enemy_mount, enemy_rect)
	_effect_panel_own_mount.clip_contents = true
	_effect_panel_enemy_mount.clip_contents = true
	var enemy_back := _effect_panel_enemy_mount.get_node_or_null("NeutralEffectBack") as TextureRect
	if enemy_back:
		enemy_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var own_name_top := own_rect.position.y - 18.0 if _is_player_on_south(perspective_player_id) else own_rect.end.y + 2.0
	var own_state_top := own_rect.end.y + 2.0 if _is_player_on_south(perspective_player_id) else own_rect.position.y - 18.0
	var enemy_label_top := enemy_rect.end.y + 2.0 if not _is_player_on_south(opponent_player_id) else enemy_rect.position.y - 18.0
	_set_control_rect(
		_effect_panel_own_label,
		Rect2(Vector2(own_rect.position.x, own_name_top), Vector2(own_rect.size.x, 16.0))
	)
	_set_control_rect(
		_effect_panel_enemy_label,
		Rect2(Vector2(enemy_rect.position.x, enemy_label_top), Vector2(enemy_rect.size.x, 16.0))
	)
	_set_control_rect(
		_effect_panel_state_label,
		Rect2(Vector2(own_rect.position.x - 8.0, own_state_top), Vector2(own_rect.size.x + 16.0, 16.0))
	)
	var title := _effect_panel.get_node_or_null("EffectPanelTitle") as Label
	if title:
		title.visible = false
	_layout_effect_panel_own_card()

func _clamp_board_camera() -> void:
	if _board_world_size == Vector2.ZERO or _board_view_rect.size == Vector2.ZERO:
		return
	var half_visible_world := _board_view_rect.size / (maxf(_board_zoom, 0.001) * 2.0)
	var overscroll := Vector2(
		maxf(BOARD_HORIZONTAL_OVERSCROLL_MIN, half_visible_world.x * BOARD_HORIZONTAL_OVERSCROLL_VIEW_RATIO),
		minf(72.0, _board_world_size.y * 0.08)
	)
	for axis in [Vector2.AXIS_X, Vector2.AXIS_Y]:
		var world_extent := _board_world_size[axis]
		var visible_extent := half_visible_world[axis] * 2.0
		if world_extent <= visible_extent:
			var centered_axis := world_extent * 0.5
			_board_camera_center[axis] = clampf(
				_board_camera_center[axis],
				centered_axis - overscroll[axis],
				centered_axis + overscroll[axis]
			)
			continue
		var minimum_center := half_visible_world[axis] - overscroll[axis]
		var maximum_center := world_extent - half_visible_world[axis] + overscroll[axis]
		_board_camera_center[axis] = clampf(
			_board_camera_center[axis],
			minimum_center,
			maximum_center
		)

func _zoom_board_at(screen_point: Vector2, requested_zoom: float) -> void:
	_cancel_board_pan_tween()
	var next_zoom := clampf(requested_zoom, BOARD_MIN_ZOOM, BOARD_MAX_ZOOM)
	if is_equal_approx(next_zoom, _board_zoom):
		return
	var world_under_pointer := _board_camera_center + (
		(screen_point - _board_view_rect.get_center()) / maxf(_board_zoom, 0.001)
	)
	_board_zoom = next_zoom
	_board_camera_center = world_under_pointer - (
		(screen_point - _board_view_rect.get_center()) / _board_zoom
	)
	_board_view_was_adjusted = true
	_clamp_board_camera()
	_apply_board_camera_transform()

func _on_board_zoom_out_pressed() -> void:
	_zoom_board_at(_board_view_rect.get_center(), _board_zoom / BOARD_ZOOM_STEP)

func _on_board_zoom_in_pressed() -> void:
	_zoom_board_at(_board_view_rect.get_center(), _board_zoom * BOARD_ZOOM_STEP)

func _nudge_board_horizontal(direction: float) -> void:
	if is_zero_approx(direction) or _board_view_rect.size == Vector2.ZERO:
		return
	_cancel_board_pan_tween()
	var start_center := _board_camera_center
	var requested_center := start_center + Vector2(
		(signf(direction) * BOARD_HORIZONTAL_NUDGE_SCREEN_DISTANCE) / maxf(_board_zoom, 0.001),
		0.0
	)
	_board_camera_center = requested_center
	_clamp_board_camera()
	var target_center := _board_camera_center
	_board_camera_center = start_center
	_board_view_was_adjusted = true
	_board_pan_tween = create_tween().bind_node(self).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_board_pan_tween.tween_method(_set_board_camera_center, start_center, target_center, 0.28)

func _set_board_camera_center(value: Vector2) -> void:
	_board_camera_center = value
	_clamp_board_camera()
	_apply_board_camera_transform()

func _cancel_board_pan_tween() -> void:
	if _board_pan_tween and _board_pan_tween.is_valid():
		_board_pan_tween.kill()
	_board_pan_tween = null

func _focus_board_region(region: int) -> void:
	_cancel_board_pan_tween()
	var target_y := _board_divider_world_y
	var south_player_id := _get_battlefield_perspective_player_id()
	var north_player_id: int = int(game_manager.get_opponent_id(south_player_id)) if game_manager else (2 if south_player_id == 1 else 1)
	if region < 0:
		target_y = _get_player_zone_world_rect(north_player_id).get_center().y
	elif region > 0:
		target_y = _get_player_zone_world_rect(south_player_id).get_center().y
	_board_camera_center = Vector2(_board_world_size.x * 0.5, target_y)
	_board_zoom = clampf(
		maxf(_get_default_board_zoom(), 0.76),
		BOARD_MIN_ZOOM,
		BOARD_MAX_ZOOM
	)
	_board_view_was_adjusted = true
	_clamp_board_camera()
	_apply_board_camera_transform()

func _reset_board_view() -> void:
	_cancel_board_pan_tween()
	_board_camera_center = _get_default_board_camera_center()
	_board_zoom = _get_default_board_zoom()
	_board_view_was_adjusted = false
	_clamp_board_camera()
	_apply_board_camera_transform()

func _fit_board_view() -> void:
	_cancel_board_pan_tween()
	_board_camera_center = _board_world_size * 0.5
	_board_zoom = _board_fit_zoom
	_board_view_was_adjusted = true
	_clamp_board_camera()
	_apply_board_camera_transform()

func _update_board_zoom_label() -> void:
	if _board_zoom_label:
		_board_zoom_label.text = "%d%%" % int(round(_board_zoom * 100.0))

func _layout_board_navigation(hand_dock_top: float, outer_pad: float, zone_width: float) -> void:
	if not _board_navigation_panel:
		return
	var panel_width := minf(124.0, maxf(112.0, zone_width * 0.14))
	var panel_height := 274.0 if _board_navigation_expanded else 42.0
	var nav_left := outer_pad + 12.0
	if _board_navigation_expanded and _field_own_health_badge and _field_own_health_badge.visible:
		var badge_rect := _field_own_health_badge.get_global_rect()
		if hand_dock_top - panel_height - 12.0 < badge_rect.end.y + 8.0:
			nav_left = maxf(nav_left, badge_rect.end.x + 12.0)
	_board_navigation_panel.anchor_left = 0.0
	_board_navigation_panel.anchor_top = 0.0
	_board_navigation_panel.anchor_right = 0.0
	_board_navigation_panel.anchor_bottom = 0.0
	_board_navigation_panel.offset_left = nav_left
	_board_navigation_panel.offset_top = hand_dock_top - panel_height - 12.0
	_board_navigation_panel.offset_right = nav_left + panel_width
	_board_navigation_panel.offset_bottom = hand_dock_top - 12.0

func _hide_legacy_turn_gold_labels() -> void:
	for label in [turn_label, p1_energy_label, p2_energy_label, $HUD/P1HQLabel, $HUD/P2HQLabel]:
		if label:
			label.visible = false

func _create_hq_health_labels() -> void:
	_p1_hq_health_label = _create_hq_health_label(p1_hq_slot, "P1HQHealthLabel")
	_p2_hq_health_label = _create_hq_health_label(p2_hq_slot, "P2HQHealthLabel")

func _create_hq_health_label(parent: Control, label_name: String) -> Label:
	if not parent:
		return null

	var existing = parent.get_node_or_null(label_name) as Label
	if existing:
		return existing

	var label = Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = CardSlot.CONTENT_Z_INDEX
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 0.0
	label.offset_left = -16.0
	label.offset_top = 5.0
	label.offset_right = 16.0
	label.offset_bottom = 29.0
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _update_hq_health_label(label: Label, health: int) -> void:
	if not label:
		return

	label.text = "%d / %d" % [health, GameRules.HEADQUARTERS_HEALTH]

func _configure_top_hud(viewport_size: Vector2, outer_pad: float, zone_width: float) -> void:
	if not top_hud:
		return
	# Runtime values still flow through TopHud for backwards-compatible tests and
	# saved scenes, but the duplicated strip is no longer part of the visible UI.
	top_hud.visible = false
	top_hud.anchor_left = 0.0
	top_hud.anchor_top = 0.0
	top_hud.anchor_right = 0.0
	top_hud.anchor_bottom = 0.0
	top_hud.offset_left = 0.0
	top_hud.offset_top = 0.0
	top_hud.offset_right = 0.0
	top_hud.offset_bottom = 0.0
	top_hud.z_index = 150
	top_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _get_top_playfield_reserved_height(_viewport_size: Vector2) -> float:
	return 0.0

func _configure_hand_frame(hand: Control, left: float, top: float, content_size: Vector2) -> void:
	hand.anchor_left = 0.0
	hand.anchor_top = 0.0
	hand.anchor_right = 0.0
	hand.anchor_bottom = 0.0
	hand.offset_left = left
	hand.offset_top = top
	hand.offset_right = left + content_size.x
	hand.offset_bottom = top + content_size.y
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand.z_index = 1

func _layout_board_slots(
	grid: Control,
	is_south: bool,
	slot_size: Vector2,
	slot_gap: Vector2,
	grid_size: Vector2,
	layout_scale: float
) -> void:
	if not grid:
		return

	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := _get_board_slot_rows(is_south)
	var active_slot_names := {}
	for row_spec in rows:
		var slot_names: Array = row_spec.get("names", [])
		var row_index := int(row_spec.get("row", 0))
		var row_width = (slot_size.x * float(slot_names.size())) + (slot_gap.x * float(max(0, slot_names.size() - 1)))
		var row_left = (grid_size.x - row_width) * 0.5
		var row_top = float(row_index) * (slot_size.y + slot_gap.y)
		for slot_index in range(slot_names.size()):
			var slot_name := str(slot_names[slot_index])
			var slot = grid.get_node_or_null(slot_name) as CardSlot
			if not slot:
				continue

			var slot_left = row_left + (float(slot_index) * (slot_size.x + slot_gap.x))
			_place_board_slot(slot, Vector2(slot_left, row_top), slot_size, layout_scale)
			active_slot_names[slot.name] = true

	for child in grid.get_children():
		var slot = child as CardSlot
		if not slot:
			continue

		var is_active := active_slot_names.has(slot.name)
		slot.visible = is_active
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE

func _get_board_slot_rows(is_south: bool) -> Array:
	if not is_south:
		return [
			{"names": ["Slot_S1", "Slot_S2", "Slot_S3"], "row": 0},
			{"names": ["Slot_B1", "Slot_B2", "Slot_B3"], "row": 1},
			{"names": ["Slot_F1", "Slot_F2", "Slot_F3"], "row": 2},
		]

	return [
		{"names": ["Slot_F1", "Slot_F2", "Slot_F3"], "row": 0},
		{"names": ["Slot_B1", "Slot_B2", "Slot_B3"], "row": 1},
		{"names": ["Slot_S1", "Slot_S2", "Slot_S3"], "row": 2},
	]

func get_lane_slots(player_id: int, lane_id: int) -> Array[CardSlot]:
	var lane_slots: Array[CardSlot] = []
	for node in get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if not slot:
			continue
		if slot.owner_id != player_id or int(slot.lane_id) != lane_id:
			continue
		if slot.position_type == CardSlot.PositionType.HQ:
			continue
		lane_slots.append(slot)

	lane_slots.sort_custom(func(a: CardSlot, b: CardSlot): return int(a.position_type) < int(b.position_type))
	return lane_slots

func get_hq_slot(player_id: int) -> CardSlot:
	if player_id == 1:
		return p1_hq_slot as CardSlot
	return p2_hq_slot as CardSlot

func get_hand_cards(player_id: int) -> Array[BaseCard]:
	var cards: Array[BaseCard] = []
	var hand := _get_hand_for_player(player_id)
	if not hand:
		return cards
	for child in hand.get_children():
		var card := child as BaseCard
		if card and not card.is_queued_for_deletion() and card.owner_id == player_id:
			cards.append(card)
	return cards

func get_deck_card_count(player_id: int) -> int:
	return (_player_decks.get(player_id, []) as Array).size()

func get_board_slots(player_id: int = 0) -> Array[CardSlot]:
	var slots: Array[CardSlot] = []
	for node in get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if not slot or slot.position_type == CardSlot.PositionType.HQ:
			continue
		if player_id != 0 and slot.owner_id != player_id:
			continue
		if slot.is_visible_in_tree():
			slots.append(slot)
	slots.sort_custom(func(a: CardSlot, b: CardSlot):
		if a.owner_id != b.owner_id:
			return a.owner_id < b.owner_id
		if a.lane_id != b.lane_id:
			return int(a.lane_id) < int(b.lane_id)
		return int(a.position_type) < int(b.position_type)
	)
	return slots

func get_board_cards(player_id: int = 0) -> Array[BaseCard]:
	var cards: Array[BaseCard] = []
	for slot in get_board_slots(player_id):
		if slot.is_occupied and slot.occupied_card is BaseCard:
			var card := slot.occupied_card as BaseCard
			if not card.is_queued_for_deletion():
				cards.append(card)
	return cards

func play_hand_card_to_slot(card: BaseCard, slot: CardSlot) -> Dictionary:
	if not game_manager or not card or not slot:
		return {"success": false, "error": "Kart veya hedef yuva eksik."}
	if not (card is HeroCard or card is SettlementCard):
		return {"success": false, "error": "Bu kart doğrudan savaş alanına yerleştirilemez."}
	if card.owner_id != game_manager.active_player_id or not game_manager.can_play_card(card.owner_id):
		return {"success": false, "error": "Kart aktif oyuncunun Hazırlık aşamasında değil."}
	if card.current_slot or card.get_parent() != _get_hand_for_player(card.owner_id):
		return {"success": false, "error": "Kart aktif oyuncunun elinde değil."}
	if not slot.can_accept_card(card):
		return {"success": false, "error": "Hedef yuva bu kartı kabul etmiyor."}
	var action_type := "hero" if card is HeroCard else "settlement"
	var resolved_cost := EffectResolver.get_effect_action_cost(game_manager, card, action_type, card.energy_cost)
	if not game_manager.spend_energy(card.owner_id, resolved_cost):
		return {"success": false, "error": "Kartı oynayacak Enerji yok."}

	card.current_slot = slot
	card.reparent(slot, false)
	slot.accept_card(card)
	card.position = (slot.size - card.size) * 0.5
	card.rotation = 0.0
	card.modulate = Color.WHITE
	card.on_played_to_board()
	# AI cards enter the board without going through BaseCard's drag/snap path.
	# Refreshing here switches them to PASS so both the card and its parent slot
	# can drive hover/click inspection just like player-placed field cards.
	card._refresh_mouse_filter()
	card.set_meta("telemetry_energy_spent", resolved_cost)
	game_manager.card_played.emit(card, null)
	var board_effect := EffectResolver.resolve_after_board_card_played(game_manager, card)
	var energy_effect := EffectResolver.resolve_energy_action(game_manager, card, action_type, resolved_cost)
	sync_player_energy(card.owner_id)
	var result := {
		"success": true,
		"card": card,
		"target_slot": slot,
		"energy_spent": resolved_cost,
	}
	if bool(board_effect.get("triggered", false)):
		result["effect_card_bonus"] = board_effect
	if bool(energy_effect.get("triggered", false)):
		result["energy_effect"] = energy_effect
	return result


func request_network_card_drop(card: BaseCard, slot: CardSlot) -> bool:
	if not MatchSetup.is_multiplayer_player() or not card or not slot:
		return false
	var action := "targeted_card" if card is UpgradeCard else "play_card"
	return _request_network_action(action, {
		"card_id": _get_card_network_id(card),
		"slot_id": _get_slot_network_id(slot),
	})

func refresh_after_ai_action() -> void:
	if not game_manager:
		return
	sync_player_energy(game_manager.active_player_id)
	_refresh_lane_visuals()
	_update_hq_labels()
	_update_deck_ui()
	_refresh_phase_ui()
	if not MatchSetup.fast_mode:
		_apply_responsive_layout()

func is_ai_resolution_busy() -> bool:
	return (
		_is_dealing_initial_hands
		or _is_draw_animation_running
		or _effect_draw_queue_running
		or _is_confirming_selection
		or _auto_attack_running
		or _combat_sequence_active
	)

func get_match_telemetry() -> MatchTelemetry:
	return _match_telemetry

func get_ai_controller() -> AIController:
	return _ai_controller

func is_lane_open(defender_id: int, lane_id: int) -> bool:
	var lane_slots := get_lane_slots(defender_id, lane_id)
	if lane_slots.size() != 3:
		return false
	for slot in lane_slots:
		if slot.is_occupied:
			return false
	return true


func get_dominion_preview() -> Dictionary:
	return DominionResolver.calculate_board(self, game_manager.round_count if game_manager else 0)


func _on_round_completed(round_number: int) -> void:
	if not game_manager or not MatchSetup.is_dominion() or MatchSetup.is_multiplayer_client():
		return
	var result := DominionResolver.calculate_board(self, round_number)
	game_manager.apply_dominion_round_result(result)
	dominion_preview_changed.emit((result.get("lane_results", []) as Array).duplicate(true))


func _on_dominion_score_changed(player_id: int, current_score: int, target_score: int) -> void:
	_field_dominion_scores[player_id] = maxi(0, current_score)
	_field_dominion_target = maxi(1, target_score)
	if top_hud:
		top_hud.set_dominion_score(player_id, current_score, target_score)
	_refresh_match_flow_chrome()
	if game_manager:
		_refresh_zone_state(game_manager.active_player_id)


func _on_dominion_round_resolved(
	_round_number: int,
	lane_results: Array,
	points_awarded: Dictionary,
	scores: Dictionary
) -> void:
	_apply_dominion_lane_preview(lane_results)
	if MatchSetup.fast_mode:
		return
	var own_id := MatchSetup.human_player_id if MatchSetup.human_player_id in GameRules.PLAYER_IDS else 1
	var own_points := int(points_awarded.get(own_id, points_awarded.get(str(own_id), 0)))
	var opponent_id: int = game_manager.get_opponent_id(own_id) if game_manager else 2
	var enemy_points := int(points_awarded.get(opponent_id, points_awarded.get(str(opponent_id), 0)))
	if _feedback_audio:
		var highest_score := maxi(
			int(scores.get(1, scores.get("1", 0))),
			int(scores.get(2, scores.get("2", 0)))
		)
		_feedback_audio.play_event(
			"dominion_match_point"
			if highest_score >= GameRules.DOMINION_SCORE_TARGET - 1
			else "dominion_score"
		)
	show_toast(
		tr("This round: You +%d • Opponent +%d Dominion.") % [own_points, enemy_points],
		Color(0.95, 0.72, 0.28),
		"HAKİMİYET PUANLANDI"
	)


func _apply_dominion_lane_preview(lane_results: Array) -> void:
	var by_lane := {}
	for lane_variant in lane_results:
		if lane_variant is Dictionary:
			var lane_result := lane_variant as Dictionary
			by_lane[int(lane_result.get("lane_id", CardSlot.Lane.NONE))] = lane_result
	for player_id in GameRules.PLAYER_IDS:
		for lane_id in DominionResolver.LANES:
			var result := by_lane.get(lane_id, {}) as Dictionary
			var control := result.get("control", {}) as Dictionary
			for slot in get_lane_slots(player_id, lane_id):
				slot.set_dominion_control(
					MatchSetup.is_dominion(),
					int(result.get("owner_id", 0)),
					int(control.get(1, control.get("1", 0))),
					int(control.get(2, control.get("2", 0)))
				)

func _connect_slot_signals() -> void:
	var draw_order := 0
	for node in get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if not slot:
			continue

		slot.set_draw_order(draw_order)
		draw_order += 1

		if not slot.occupancy_changed.is_connected(_on_slot_occupancy_changed):
			slot.occupancy_changed.connect(_on_slot_occupancy_changed)

		var entered_callback := _on_board_slot_mouse_entered.bind(slot)
		if not slot.mouse_entered.is_connected(entered_callback):
			slot.mouse_entered.connect(entered_callback)

		var exited_callback := _on_board_slot_mouse_exited.bind(slot)
		if not slot.mouse_exited.is_connected(exited_callback):
			slot.mouse_exited.connect(exited_callback)

		var input_callback := _on_board_slot_gui_input.bind(slot)
		if not slot.gui_input.is_connected(input_callback):
			slot.gui_input.connect(input_callback)

		if slot.occupied_card is BaseCard:
			_register_preview_card(slot.occupied_card as BaseCard)

func _on_slot_occupancy_changed(slot: CardSlot) -> void:
	if slot and slot.occupied_card is BaseCard:
		var occupied_card := slot.occupied_card as BaseCard
		_register_preview_card(occupied_card)
		occupied_card._refresh_mouse_filter()
	if _selected_attacker and (not is_instance_valid(_selected_attacker) or not _selected_attacker.current_slot):
		_clear_combat_selection()
	if _selected_deployment_card and is_instance_valid(_selected_deployment_card):
		if _selected_deployment_card.current_slot:
			_clear_deployment_selection()
		else:
			_legal_deployment_targets.clear()
			for candidate in get_board_slots(_selected_deployment_card.owner_id):
				if candidate.can_accept_card(_selected_deployment_card):
					_legal_deployment_targets.append(candidate)
			if _legal_deployment_targets.is_empty():
				_clear_deployment_selection()
			else:
				_refresh_deployment_highlights()
	if _selected_effect_card and is_instance_valid(_selected_effect_card):
		_legal_effect_targets = EffectResolver.get_legal_target_slots(game_manager, _selected_effect_card)
		if _legal_effect_targets.is_empty():
			_clear_effect_selection()
		else:
			_refresh_effect_highlights()
	if _selected_mover and is_instance_valid(_selected_mover):
		_legal_movement_targets = MovementResolver.get_legal_destination_slots(game_manager, _selected_mover)
		if _legal_movement_targets.is_empty():
			_clear_movement_selection()
		else:
			_refresh_movement_highlights()
	if _selected_action_card and (
		not is_instance_valid(_selected_action_card)
		or not _selected_action_card.current_slot
	):
		_clear_card_action_selection()
	_refresh_lane_visuals()

func _on_board_slot_gui_input(event: InputEvent, slot: CardSlot) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_preview_occupied_slot(slot)
			if _selected_deployment_card:
				request_deployment_target_selection(slot)
			elif _selected_effect_card:
				request_effect_target_selection(slot)
			elif _selected_mover:
				request_movement_target_selection(slot)
			elif game_manager and game_manager.current_phase == GameManager.TurnPhase.PREPARATION:
				request_card_action_selection(slot)
			else:
				request_combat_slot_selection(slot)

func _preview_occupied_slot(slot: CardSlot) -> void:
	if not slot or not slot.is_occupied or not slot.occupied_card is BaseCard:
		return
	var card := slot.occupied_card as BaseCard
	if _can_preview_card(card):
		_show_card_preview(card)

func request_card_action_selection(slot: CardSlot) -> void:
	if not game_manager or not game_manager.is_game_active:
		return
	if game_manager.current_phase != GameManager.TurnPhase.PREPARATION:
		return
	if not slot or not slot.is_occupied or not slot.occupied_card is BaseCard:
		show_toast("Eylem için kendi Kahraman veya Yapını seç.", Color(0.95, 0.52, 0.24))
		return
	var card := slot.occupied_card as BaseCard
	if card.owner_id != game_manager.active_player_id or card.is_headquarters():
		show_toast("Yalnızca aktif oyuncunun Kahraman veya Yapısı seçilebilir.", Color(0.95, 0.38, 0.24))
		return
	if not (card is HeroCard or card is SettlementCard):
		return

	_clear_deployment_selection()
	_clear_effect_selection()
	_clear_hand_tactic_selection()
	_clear_combat_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_selected_action_card = card
	card.set_meta("action_selected", true)
	card.modulate = Color.WHITE
	card.set_selection_visual(true, UI.FROST.lightened(0.18))
	_refresh_card_action_panel()

func _refresh_card_action_panel(show_branches: bool = false) -> void:
	if not _card_action_panel:
		return
	if not _selected_action_card or not is_instance_valid(_selected_action_card):
		_clear_card_action_selection()
		return
	var card := _selected_action_card
	_card_action_panel.visible = true
	_card_action_panel.move_to_front()
	_card_action_title.text = tr(card.card_name).to_upper()
	var next_requirement := card.get_next_level_experience()
	var branch_text := tr("No branch selected") if card.selected_branch_name.is_empty() else tr(card.selected_branch_name)
	_card_action_details.text = tr("Level %d  •  Experience %d/%d  •  %s") % [
		card.card_level,
		card.experience,
		next_requirement,
		branch_text,
	]

	_move_action_button.visible = not show_branches and card is HeroCard
	_upgrade_action_button.visible = not show_branches
	for branch_button in _branch_action_buttons:
		branch_button.visible = show_branches

	if not show_branches:
		var movement_error := MovementResolver.get_movement_start_error(game_manager, card)
		if movement_error.is_empty() and MovementResolver.get_legal_destination_slots(game_manager, card).is_empty():
			movement_error = "Hareket edilebilecek boş komşu yuva yok."
		_move_action_button.disabled = not movement_error.is_empty()
		_move_action_button.tooltip_text = _localize_display_text(movement_error, "This action is unavailable.")

		var upgrade_error := ProgressionResolver.get_upgrade_start_error(game_manager, card)
		_upgrade_action_button.disabled = not upgrade_error.is_empty()
		_upgrade_action_button.tooltip_text = _localize_display_text(upgrade_error, "This action is unavailable.")
		var next_level: int = mini(GameRules.MAX_CARD_LEVEL, card.card_level + 1)
		var level_cost: int = ProgressionResolver.get_level_energy_cost(next_level)
		if card.card_level == 2 and not card.selected_branch_name.is_empty():
			_upgrade_action_button.text = tr("LEVEL 3  •  %s  •  %d ENERGY") % [tr(card.selected_branch_name).to_upper(), level_cost]
		else:
			_upgrade_action_button.text = tr("LEVEL %d  •  CHOOSE BRANCH  •  %d ENERGY") % [next_level, level_cost]

func _on_move_action_pressed() -> void:
	if not _selected_action_card or not is_instance_valid(_selected_action_card):
		_clear_card_action_selection()
		return
	var card := _selected_action_card
	var movement_error := MovementResolver.get_movement_start_error(game_manager, card)
	if not movement_error.is_empty():
		show_toast(movement_error, Color(0.95, 0.38, 0.24))
		return
	var targets := MovementResolver.get_legal_destination_slots(game_manager, card)
	if targets.is_empty():
		show_toast("Hareket edilebilecek boş komşu yuva yok.", Color(0.95, 0.38, 0.24))
		return

	card.set_meta("action_selected", false)
	card.set_selection_visual(false)
	_selected_action_card = null
	_card_action_panel.visible = false
	_selected_mover = card
	card.set_selection_visual(true, UI.FROST.lightened(0.18))
	_legal_movement_targets = targets
	_refresh_movement_highlights()
	_refresh_phase_ui()
	show_toast(tr("Select a highlighted movement slot for %s.") % tr(card.card_name), Color(0.30, 0.72, 1.0))

func request_movement_target_selection(slot: CardSlot) -> void:
	if not _selected_mover or not is_instance_valid(_selected_mover):
		_clear_movement_selection()
		return
	var mover := _selected_mover
	if MatchSetup.is_multiplayer_player():
		_request_network_action("move", {
			"card_id": _get_card_network_id(mover),
			"slot_id": _get_slot_network_id(slot),
		})
		_clear_movement_selection()
		return
	var result := MovementResolver.resolve_move(game_manager, mover, slot)
	if not bool(result.get("success", false)):
		show_toast(str(result.get("error", "Hareket hedefi geçersiz.")), Color(0.95, 0.38, 0.24))
		_legal_movement_targets = MovementResolver.get_legal_destination_slots(game_manager, mover)
		_refresh_movement_highlights()
		return

	show_toast(tr("%s moved and became Exhausted.") % tr(mover.card_name), Color(0.38, 0.82, 1.0))
	_clear_movement_selection()
	sync_player_energy(game_manager.active_player_id)
	_refresh_lane_visuals()
	_apply_responsive_layout()

func _on_upgrade_action_pressed() -> void:
	if not _selected_action_card or not is_instance_valid(_selected_action_card):
		_clear_card_action_selection()
		return
	var upgrade_error := ProgressionResolver.get_upgrade_start_error(game_manager, _selected_action_card)
	if not upgrade_error.is_empty():
		show_toast(upgrade_error, Color(0.95, 0.38, 0.24))
		return
	if _selected_action_card.card_level == 1:
		_visible_action_branches = ProgressionResolver.get_available_branches(_selected_action_card)
		if _visible_action_branches.size() != 2:
			show_toast("Bu kart için tam iki yükseltme dalı gerekli.", Color(0.95, 0.38, 0.24))
			return
		for branch_index in range(2):
			var branch := _visible_action_branches[branch_index]
			var level_definition_variant: Variant = branch.get("level_2", {})
			var level_definition := level_definition_variant as Dictionary
			_branch_action_buttons[branch_index].text = "%s\n%s" % [
				tr(str(branch.get("name", "Branch"))).to_upper(),
				tr(str(level_definition.get("description", ""))),
			]
		_refresh_card_action_panel(true)
		return
	_perform_card_upgrade(_selected_action_card.selected_branch_id)

func _on_branch_action_pressed(branch_index: int) -> void:
	if branch_index < 0 or branch_index >= _visible_action_branches.size():
		return
	_perform_card_upgrade(str(_visible_action_branches[branch_index].get("id", "")))

func _perform_card_upgrade(branch_id: String) -> void:
	if not _selected_action_card or not is_instance_valid(_selected_action_card):
		_clear_card_action_selection()
		return
	var card := _selected_action_card
	if MatchSetup.is_multiplayer_player():
		_request_network_action("upgrade", {
			"card_id": _get_card_network_id(card),
			"branch_id": branch_id,
		})
		_clear_card_action_selection()
		return
	var result := ProgressionResolver.resolve_upgrade(game_manager, card, branch_id)
	if not bool(result.get("success", false)):
		show_toast(str(result.get("error", "Yükseltme geçersiz.")), Color(0.95, 0.38, 0.24))
		_refresh_card_action_panel(card.card_level == 1 and not _visible_action_branches.is_empty())
		return
	show_toast(
		tr("%s reached Level %d: %s.") % [tr(card.card_name), card.card_level, tr(card.selected_branch_name)],
		Color(0.95, 0.72, 0.28)
	)
	_clear_card_action_selection()
	sync_player_energy(game_manager.active_player_id)
	if _preview_displayed_source_card == card:
		_copy_current_card_state_to_preview(card, _preview_card)

func _refresh_movement_highlights() -> void:
	_prepare_target_context(_selected_mover.current_slot if _selected_mover and is_instance_valid(_selected_mover) else null)
	if _selected_mover and is_instance_valid(_selected_mover) and _selected_mover.current_slot:
		_selected_mover.current_slot.set_combat_highlight(CardSlot.CombatHighlight.ATTACKER, "SEÇİLİ")
	for target_slot in _legal_movement_targets:
		if target_slot and is_instance_valid(target_slot):
			target_slot.set_combat_highlight(CardSlot.CombatHighlight.MOVE_TARGET, "GİT")

func _clear_movement_selection() -> void:
	if _selected_mover and is_instance_valid(_selected_mover):
		_selected_mover.set_selection_visual(false)
	_selected_mover = null
	_legal_movement_targets.clear()
	if _selected_deployment_card:
		_refresh_deployment_highlights()
	elif _selected_effect_card:
		_refresh_effect_highlights()
	elif _selected_attacker:
		_refresh_combat_highlights()
	else:
		_clear_slot_target_highlights()
	_refresh_phase_ui()

func _clear_card_action_selection() -> void:
	if _selected_action_card and is_instance_valid(_selected_action_card):
		_selected_action_card.set_meta("action_selected", false)
		_selected_action_card.modulate = Color.WHITE
		_selected_action_card.set_selection_visual(false)
	_selected_action_card = null
	_visible_action_branches.clear()
	if _card_action_panel:
		_card_action_panel.visible = false
	_refresh_phase_ui()

func is_hand_tactic_card(card: BaseCard) -> bool:
	return card is SpecialPowerCard and card.effect_id in ["redraw_card", "draw_cards"]

func is_hand_tactic_targeting() -> bool:
	return _selected_hand_tactic_card != null and is_instance_valid(_selected_hand_tactic_card)

func _request_hand_tactic_selection(card: SpecialPowerCard) -> void:
	if not card or not is_instance_valid(card):
		return
	if card == _selected_hand_tactic_card:
		_clear_hand_tactic_selection()
		return
	var start_error := EffectResolver.get_card_start_error(game_manager, card)
	if not start_error.is_empty():
		show_toast(start_error, Color(0.95, 0.38, 0.24))
		return
	var deck: Array = _player_decks.get(card.owner_id, [])
	if deck.is_empty():
		show_toast("Bu taktik için destende en az bir kart olmalı.", Color(0.95, 0.38, 0.24))
		return
	_clear_deployment_selection()
	_clear_effect_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_clear_combat_selection()
	_clear_hand_tactic_selection()

	if card.effect_id == "draw_cards":
		if MatchSetup.is_multiplayer_player():
			_request_network_action("hand_tactic", {"card_id": _get_card_network_id(card)})
			return
		var draw_result: Dictionary = await resolve_hand_tactic(card)
		_show_hand_tactic_result(draw_result)
		return

	_selected_hand_tactic_card = card
	_legal_hand_tactic_targets.clear()
	for hand_card in get_hand_cards(card.owner_id):
		if hand_card != card:
			_legal_hand_tactic_targets.append(hand_card)
	if _legal_hand_tactic_targets.is_empty():
		_selected_hand_tactic_card = null
		show_toast("Değiştirmek için elinde başka bir kart olmalı.", Color(0.95, 0.38, 0.24))
		return
	card.set_selection_visual(true, UI.FROST.lightened(0.20))
	for target in _legal_hand_tactic_targets:
		target.set_selection_visual(true, Color(0.35, 0.94, 0.67))
	_refresh_phase_ui()
	show_toast("Değiştirilecek kartı elinden seç.", Color(0.35, 0.82, 1.0), "TAKTİK DEĞİŞİM")

func request_hand_tactic_target_selection(target: BaseCard) -> void:
	if not is_hand_tactic_targeting():
		return
	if target == _selected_hand_tactic_card:
		_clear_hand_tactic_selection()
		return
	if target not in _legal_hand_tactic_targets:
		show_toast("Yalnızca vurgulanan el kartlarından birini seçebilirsin.", Color(0.95, 0.38, 0.24))
		return
	var tactic := _selected_hand_tactic_card
	if MatchSetup.is_multiplayer_player():
		_request_network_action("hand_tactic", {
			"card_id": _get_card_network_id(tactic),
			"target_card_id": _get_card_network_id(target),
		})
		_clear_hand_tactic_selection()
		return
	var result: Dictionary = await resolve_hand_tactic(tactic, target)
	_show_hand_tactic_result(result)

func resolve_hand_tactic(tactic: SpecialPowerCard, hand_target: BaseCard = null) -> Dictionary:
	if _is_hand_tactic_resolving:
		return {"success": false, "error": "Önceki taktik hâlâ çözülüyor."}
	if not is_hand_tactic_card(tactic):
		return {"success": false, "error": "Bu kart bir el taktiği değil."}
	var start_error := EffectResolver.get_card_start_error(game_manager, tactic)
	if not start_error.is_empty():
		return {"success": false, "error": start_error}
	var hand := _get_hand_for_player(tactic.owner_id)
	if not hand or tactic.get_parent() != hand:
		return {"success": false, "error": "Taktik kartı aktif oyuncunun elinde değil."}
	var deck: Array = _player_decks.get(tactic.owner_id, [])
	if deck.is_empty():
		return {"success": false, "error": "Bu taktik için destede kart yok."}
	if tactic.effect_id == "redraw_card":
		if (
			not hand_target
			or not is_instance_valid(hand_target)
			or hand_target == tactic
			or hand_target.owner_id != tactic.owner_id
			or hand_target.get_parent() != hand
		):
			return {"success": false, "error": "Değiştirilecek el kartı geçersiz."}
		var target_deck_ref: Dictionary = hand_target.get_meta("deck_ref", {})
		if target_deck_ref.is_empty():
			return {"success": false, "error": "Seçilen kartın deste kaydı bulunamadı."}
	var resolved_cost := EffectResolver.get_effect_action_cost(
		game_manager,
		tactic,
		"special_power",
		tactic.energy_cost
	)
	if not game_manager.spend_energy(tactic.owner_id, resolved_cost):
		return {"success": false, "error": "Taktiği oynayacak Enerji yok."}

	_is_hand_tactic_resolving = true
	_clear_hand_tactic_selection()
	var tactic_owner := tactic.owner_id
	var tactic_name := tactic.card_name
	var effect_id := tactic.effect_id
	var expected_draws := maxi(1, int(tactic.effect_params.get("cards", tactic.intensity)))
	var signal_result := {
		"success": true,
		"effect": effect_id,
		"cards_requested": expected_draws,
	}
	tactic.set_meta("telemetry_energy_spent", resolved_cost)
	game_manager.card_played.emit(tactic, hand_target)
	game_manager.effect_resolved.emit(effect_id, tactic, hand_target, signal_result)
	EffectResolver.resolve_special_power_echo(game_manager, tactic)
	_remove_hand_card(tactic)
	var energy_effect := EffectResolver.resolve_energy_action(game_manager, tactic, "special_power", resolved_cost)

	var cards_drawn := 0
	if effect_id == "redraw_card":
		var returned_card_ref: Dictionary = hand_target.get_meta("deck_ref", {}).duplicate(true)
		_remove_hand_card(hand_target)
		if await _draw_card_to_hand(tactic_owner, true):
			cards_drawn = 1
		var updated_deck: Array = _player_decks.get(tactic_owner, [])
		updated_deck.append(returned_card_ref)
		_player_decks[tactic_owner] = updated_deck
	else:
		for _draw_index in range(expected_draws):
			if await _draw_card_to_hand(tactic_owner, true, 0.08):
				cards_drawn += 1
			else:
				_apply_fatigue_damage(tactic_owner)
				if not game_manager.is_game_active:
					break

	_is_hand_tactic_resolving = false
	sync_player_energy(tactic_owner)
	_update_deck_ui()
	_apply_responsive_layout()
	_refresh_phase_ui()
	var result := {
		"success": true,
		"effect": effect_id,
		"card_name": tactic_name,
		"cards_drawn": cards_drawn,
		"message": (
			tr("Card replaced; a new one was drawn.")
			if effect_id == "redraw_card"
			else tr("%d new cards drawn.") % cards_drawn
		),
	}
	if bool(energy_effect.get("triggered", false)):
		result["energy_effect"] = energy_effect
	return result

func _remove_hand_card(card: BaseCard) -> void:
	if not card or not is_instance_valid(card):
		return
	_record_graveyard_card(card, "played")
	var parent := card.get_parent()
	if parent:
		parent.remove_child(card)
	card.queue_free()


func _record_graveyard_card(card: BaseCard, reason: String) -> void:
	if not card or not is_instance_valid(card) or card.owner_id not in GameRules.PLAYER_IDS:
		return
	if bool(card.get_meta("graveyard_recorded", false)):
		return
	card.set_meta("graveyard_recorded", true)
	var entry := _serialize_network_card(card)
	entry["zone_reason"] = reason
	entry["entered_turn"] = game_manager.turn_count if game_manager else 0
	var graveyard_variant: Variant = _graveyards.get(card.owner_id, [])
	var graveyard: Array = (graveyard_variant as Array).duplicate(true) if graveyard_variant is Array else []
	graveyard.append(entry)
	_graveyards[card.owner_id] = graveyard

func _show_hand_tactic_result(result: Dictionary) -> void:
	if bool(result.get("success", false)):
		show_toast(str(result.get("message", "Taktik çözüldü.")), Color(0.35, 0.90, 0.72), "TAKTİK ÇÖZÜLDÜ")
	else:
		show_toast(str(result.get("error", "Taktik çözülemedi.")), Color(0.95, 0.38, 0.24))

func _clear_hand_tactic_selection() -> void:
	if _selected_hand_tactic_card and is_instance_valid(_selected_hand_tactic_card):
		_selected_hand_tactic_card.set_selection_visual(false)
	for target in _legal_hand_tactic_targets:
		if target and is_instance_valid(target):
			target.set_selection_visual(false)
	_selected_hand_tactic_card = null
	_legal_hand_tactic_targets.clear()
	_refresh_phase_ui()

func request_effect_card_selection(card: BaseCard) -> void:
	if not card or not is_instance_valid(card) or not game_manager:
		return
	if is_card_interaction_locked():
		return
	if card is SpecialPowerCard and is_hand_tactic_card(card):
		await _request_hand_tactic_selection(card as SpecialPowerCard)
		return
	if card == _selected_effect_card:
		_clear_effect_selection()
		return
	_clear_deployment_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_clear_hand_tactic_selection()

	var start_error := EffectResolver.get_card_start_error(game_manager, card)
	if not start_error.is_empty():
		show_toast(start_error, Color(0.95, 0.38, 0.24))
		return
	var legal_targets := EffectResolver.get_legal_target_slots(game_manager, card)
	if legal_targets.is_empty():
		show_toast("Bu kartın şu anda yasal hedefi yok.", Color(0.95, 0.38, 0.24))
		return

	_clear_effect_selection()
	_clear_combat_selection()
	_selected_effect_card = card
	_legal_effect_targets = legal_targets
	card.set_meta("effect_selected", true)
	card.modulate = Color.WHITE
	card.set_selection_visual(true, UI.FROST.lightened(0.18))
	_refresh_effect_highlights()
	_refresh_phase_ui()
	show_toast(tr("Select a highlighted target for %s.") % tr(card.card_name), Color(0.30, 0.72, 1.0))

func request_effect_target_selection(slot: CardSlot) -> void:
	if not _selected_effect_card or not is_instance_valid(_selected_effect_card):
		_clear_effect_selection()
		return
	var played_card := _selected_effect_card
	if MatchSetup.is_multiplayer_player():
		_request_network_action("targeted_card", {
			"card_id": _get_card_network_id(played_card),
			"slot_id": _get_slot_network_id(slot),
		})
		_clear_effect_selection()
		return
	var result := EffectResolver.resolve_targeted_card(game_manager, played_card, slot)
	if not bool(result.get("success", false)):
		show_toast(str(result.get("error", "Etki hedefi geçersiz.")), Color(0.95, 0.38, 0.24))
		_legal_effect_targets = EffectResolver.get_legal_target_slots(game_manager, _selected_effect_card)
		_refresh_effect_highlights()
		return

	var message := str(result.get("message", tr("%s resolved.") % tr(played_card.card_name)))
	show_toast(message, Color(0.38, 0.90, 0.72))
	_clear_effect_selection()
	sync_player_energy(game_manager.active_player_id)
	_refresh_lane_visuals()
	_update_hq_labels()
	_apply_responsive_layout()

func _refresh_effect_highlights() -> void:
	_prepare_target_context(null)
	for slot in _legal_effect_targets:
		if slot and is_instance_valid(slot):
			var is_friendly := _selected_effect_card and slot.owner_id == _selected_effect_card.owner_id
			var highlight := CardSlot.CombatHighlight.SUPPORT_TARGET if is_friendly else CardSlot.CombatHighlight.TARGET
			slot.set_combat_highlight(highlight, _get_effect_target_hint(_selected_effect_card, is_friendly))

func _clear_effect_selection() -> void:
	if _selected_effect_card and is_instance_valid(_selected_effect_card):
		_selected_effect_card.set_meta("effect_selected", false)
		_selected_effect_card.modulate = Color.WHITE
		_selected_effect_card.set_selection_visual(false)
	_selected_effect_card = null
	_legal_effect_targets.clear()
	if _selected_deployment_card:
		_refresh_deployment_highlights()
	elif _selected_mover:
		_refresh_movement_highlights()
	elif _selected_attacker:
		_refresh_combat_highlights()
	else:
		_clear_slot_target_highlights()
	_refresh_phase_ui()

func request_combat_slot_selection(slot: CardSlot) -> void:
	if not game_manager or not game_manager.is_game_active:
		return
	if game_manager.current_phase != GameManager.TurnPhase.COMBAT:
		return
	if not slot or not slot.is_occupied or not slot.occupied_card is BaseCard:
		show_toast("Savaş için dolu bir kart yuvası seç.", Color(0.95, 0.52, 0.24))
		return

	var clicked_card := slot.occupied_card as BaseCard
	if clicked_card.owner_id == game_manager.active_player_id:
		if clicked_card == _selected_attacker:
			_clear_combat_selection()
			return
		var attacker_error := CombatResolver.get_attacker_error(game_manager, clicked_card)
		if not attacker_error.is_empty():
			show_toast(attacker_error, Color(0.95, 0.38, 0.24))
			return
		_select_combat_attacker(clicked_card)
		return

	if not _selected_attacker:
		show_toast("Önce Hazır bir saldırgan seç.", Color(0.95, 0.52, 0.24))
		return

	var attacker := _selected_attacker
	if MatchSetup.is_multiplayer_player():
		_request_network_action("attack", {
			"card_id": _get_card_network_id(attacker),
			"slot_id": _get_slot_network_id(slot),
		})
		_clear_combat_selection()
		return
	var result: Dictionary = await resolve_attack_with_feedback(attacker, slot)
	if not bool(result.get("success", false)):
		show_toast(str(result.get("error", "Saldırı geçersiz.")), Color(0.95, 0.38, 0.24))
		_refresh_combat_highlights()
		return

	var target_name := tr(str(result.get("target_name", "Target")))
	var message := tr("%s took %d damage.") % [target_name, int(result.get("damage", 0))]
	if bool(result.get("destroyed", false)) and not bool(result.get("target_was_hq", false)):
		message = tr("%s was destroyed.") % target_name
	elif int(result.get("armor_damage", 0)) > 0:
		message += tr(" %d Armor broken.") % int(result.get("armor_damage", 0))
	show_toast(message, Color(0.38, 0.90, 0.52))
	_clear_combat_selection()
	_refresh_lane_visuals()
	_update_hq_labels()

func resolve_attack_with_feedback(attacker: BaseCard, target_slot: CardSlot) -> Dictionary:
	if _combat_sequence_active:
		return {"success": false, "error": "Önceki saldırı hâlâ çözülüyor."}
	var attacker_error := CombatResolver.get_attacker_error(game_manager, attacker)
	if not attacker_error.is_empty():
		return {"success": false, "error": attacker_error}
	var legal_target := CombatResolver.get_legal_target_slot(self, game_manager, attacker)
	if not legal_target or target_slot != legal_target:
		return {"success": false, "error": "Koridordaki hedef sırası atlanamaz."}
	if not target_slot.is_occupied or not target_slot.occupied_card is BaseCard:
		return {"success": false, "error": "Hedef artık geçerli değil."}
	if MatchSetup.fast_mode:
		return CombatResolver.resolve_attack(self, game_manager, attacker, target_slot)

	var target := target_slot.occupied_card as BaseCard
	_combat_sequence_active = true
	_combat_sequence_attacker = attacker
	_combat_sequence_target = target
	attacker.set_selection_visual(true, UI.BRASS_BRIGHT)
	target.set_selection_visual(true, Color(1.0, 0.30, 0.20))
	if attacker.current_slot:
		attacker.current_slot.set_combat_highlight(CardSlot.CombatHighlight.ATTACKER, "SALDIRAN")
	target_slot.set_combat_highlight(CardSlot.CombatHighlight.TARGET, "VURULACAK")
	if _feedback_layer:
		var trace_color := _get_team_accent(attacker.owner_id)
		_play_attack_feedback(attacker, target, trace_color)
	attacker.play_attack_lunge(_get_card_feedback_center(target))
	target.play_feedback_animation("brace")
	show_toast(
		"%s  →  %s" % [tr(attacker.card_name).to_upper(), tr(target.card_name).to_upper()],
		UI.BRASS_BRIGHT,
		"SALDIRI HAZIRLANIYOR"
	)
	await get_tree().create_timer(
		BattlefieldFeedbackLayer.ATTACK_TELEGRAPH_SECONDS + BattlefieldFeedbackLayer.ATTACK_HOLD_SECONDS
	).timeout

	var result := CombatResolver.resolve_attack(self, game_manager, attacker, target_slot)
	await get_tree().create_timer(BattlefieldFeedbackLayer.ATTACK_IMPACT_SECONDS + COMBAT_AFTERMATH_SECONDS).timeout
	if attacker and is_instance_valid(attacker):
		attacker.set_selection_visual(false)
	if target and is_instance_valid(target):
		target.set_selection_visual(false)
	_combat_sequence_attacker = null
	_combat_sequence_target = null
	_combat_sequence_active = false
	return result

func _select_combat_attacker(attacker: BaseCard) -> void:
	_clear_combat_selection()
	_selected_attacker = attacker
	_legal_combat_target = CombatResolver.get_legal_target_slot(self, game_manager, attacker)
	if not _legal_combat_target:
		show_toast("Bu kartın yasal hedefi yok.", Color(0.95, 0.38, 0.24))
		_selected_attacker = null
		return
	attacker.set_selection_visual(true, UI.BRASS_BRIGHT)
	_refresh_combat_highlights()
	_refresh_phase_ui()
	show_toast(
		tr("Select the red STRIKE target for %s.") % tr(attacker.card_name),
		Color(1.0, 0.45, 0.28),
		"SALDIRI HEDEFİ"
	)

func _refresh_combat_highlights() -> void:
	_prepare_target_context(_selected_attacker.current_slot if _selected_attacker and is_instance_valid(_selected_attacker) else null)
	if _selected_attacker and is_instance_valid(_selected_attacker) and _selected_attacker.current_slot:
		_selected_attacker.current_slot.set_combat_highlight(CardSlot.CombatHighlight.ATTACKER, "SALDIRAN")
	if _legal_combat_target and is_instance_valid(_legal_combat_target):
		var target_hint := "VUR"
		if _selected_attacker and is_instance_valid(_selected_attacker):
			var preview := CombatResolver.preview_attack(self, game_manager, _selected_attacker, _legal_combat_target)
			if not preview.is_empty():
				target_hint = str(preview.get("summary_label", "VUR"))
		_legal_combat_target.set_combat_highlight(CardSlot.CombatHighlight.TARGET, target_hint)

func _clear_combat_selection() -> void:
	if _selected_attacker and is_instance_valid(_selected_attacker) and _selected_attacker != _combat_sequence_attacker:
		_selected_attacker.set_selection_visual(false)
	_selected_attacker = null
	_legal_combat_target = null
	if not is_inside_tree():
		return
	if _selected_deployment_card:
		_refresh_deployment_highlights()
		return
	if _selected_effect_card:
		_refresh_effect_highlights()
		return
	if _selected_mover:
		_refresh_movement_highlights()
		return
	_clear_slot_target_highlights()
	_refresh_phase_ui()

func _clear_slot_target_highlights() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if slot:
			slot.set_combat_highlight(CardSlot.CombatHighlight.NONE)

func _prepare_target_context(source_slot: CardSlot) -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if not slot:
			continue
		if source_slot and slot == source_slot:
			slot.set_combat_highlight(CardSlot.CombatHighlight.ATTACKER, "SEÇİLİ")
		elif slot.is_occupied:
			slot.set_combat_highlight(CardSlot.CombatHighlight.INELIGIBLE)
		else:
			slot.set_combat_highlight(CardSlot.CombatHighlight.NONE)

func _get_effect_target_hint(card: BaseCard, is_friendly: bool) -> String:
	if card is UpgradeCard:
		return "BECERİ VER"
	if not card is SpecialPowerCard:
		return "HEDEF"
	match card.effect_id:
		"heal_target", "repair_structure":
			return "İYİLEŞTİR"
		"protect_target":
			return "KORU"
		"damage_target", "damage_lane", "poison_target":
			return "VUR"
		"banish_target":
			return "SAHADAN SİL"
		"stun_target":
			return "SERSEMLET"
		"push_adjacent_lane":
			return "SAVUR"
		"blood_price":
			return "BEDEL ÖDE"
		"detach_skill":
			return "RÜNÜ KIR"
		"revive_last_hero":
			return "GERİ DÖNDÜR"
		_:
			return "DESTEKLE" if is_friendly else "ETKİLE"

func begin_drag_target_preview(card: BaseCard) -> void:
	if not card or not is_instance_valid(card):
		return
	_clear_deployment_selection()
	_prepare_target_context(null)
	if card is UpgradeCard:
		for slot in EffectResolver.get_legal_target_slots(game_manager, card):
			slot.set_combat_highlight(CardSlot.CombatHighlight.SUPPORT_TARGET, "BECERİ VER")
		return
	for slot in get_board_slots(card.owner_id):
		if slot.can_accept_card(card):
			slot.set_combat_highlight(CardSlot.CombatHighlight.MOVE_TARGET, "YERLEŞTİR")

func end_drag_target_preview(_card: BaseCard) -> void:
	_clear_slot_target_highlights()

func _on_board_slot_mouse_entered(slot: CardSlot) -> void:
	if slot and slot.occupied_card is BaseCard:
		_begin_card_preview(slot.occupied_card as BaseCard)

func _on_board_slot_mouse_exited(slot: CardSlot) -> void:
	if not _preview_source_card:
		return
	if not slot or not slot.is_occupied or _preview_source_card == slot.occupied_card:
		_end_card_preview(_preview_source_card)

func _refresh_lane_visuals() -> void:
	for player_id in [1, 2]:
		for lane_id in [CardSlot.Lane.LEFT, CardSlot.Lane.CENTER, CardSlot.Lane.RIGHT]:
			var lane_open := is_lane_open(player_id, lane_id)
			for slot in get_lane_slots(player_id, lane_id):
				slot.set_lane_open(lane_open)
			lane_state_changed.emit(player_id, lane_id, lane_open)
	_refresh_open_lane_paths()
	if MatchSetup.is_dominion():
		var preview := get_dominion_preview()
		var lane_results := (preview.get("lane_results", []) as Array).duplicate(true)
		_apply_dominion_lane_preview(lane_results)
		dominion_preview_changed.emit(lane_results)
	else:
		_apply_dominion_lane_preview([])

func _refresh_open_lane_paths() -> void:
	if not _feedback_layer or not game_manager:
		return
	if (
		not game_manager.is_game_active
		or not game_manager.is_match_started
		or game_manager.current_phase not in [
			GameManager.TurnPhase.PREPARATION,
			GameManager.TurnPhase.COMBAT,
		]
	):
		_feedback_layer.set_open_paths([])
		return

	var paths: Array[Dictionary] = []
	var attacker_id: int = game_manager.active_player_id
	var defender_id: int = game_manager.get_opponent_id(attacker_id)
	var hq_slot := get_hq_slot(defender_id)
	if not hq_slot:
		_feedback_layer.set_open_paths([])
		return
	var route_color := Color(1.0, 0.42, 0.28, 0.48) if attacker_id == 1 else Color(0.34, 0.68, 1.0, 0.48)
	for lane_id in [CardSlot.Lane.LEFT, CardSlot.Lane.CENTER, CardSlot.Lane.RIGHT]:
		if not is_lane_open(defender_id, lane_id):
			continue
		var source_slot: CardSlot = null
		for candidate in get_lane_slots(attacker_id, lane_id):
			if candidate.position_type == CardSlot.PositionType.FRONT:
				source_slot = candidate
				break
		if not source_slot:
			continue
		paths.append({
			"from": _to_feedback_point(source_slot.get_global_rect().get_center()),
			"to": _to_feedback_point(hq_slot.get_global_rect().get_center()),
			"color": route_color,
		})
	_feedback_layer.set_open_paths(paths)

func _to_feedback_point(global_point: Vector2) -> Vector2:
	if not _feedback_layer:
		return global_point
	return _feedback_layer.get_global_transform().affine_inverse() * global_point

func _play_attack_feedback(attacker: BaseCard, target: BaseCard, color: Color) -> void:
	if not _feedback_layer or not attacker or not target:
		return
	_feedback_attack_source_ref = weakref(attacker)
	_feedback_attack_target_ref = weakref(target)
	_feedback_layer.play_attack_path(
		_to_feedback_point(_get_card_feedback_center(attacker)),
		_to_feedback_point(_get_card_feedback_center(target)),
		color
	)

func _refresh_active_attack_feedback() -> void:
	if not _feedback_layer:
		return
	if not _feedback_layer.has_active_attack_path():
		_feedback_attack_source_ref = null
		_feedback_attack_target_ref = null
		return
	var attacker := _get_valid_feedback_card(_feedback_attack_source_ref)
	var target := _get_valid_feedback_card(_feedback_attack_target_ref)
	if not attacker or not target:
		return
	_feedback_layer.update_attack_path(
		_to_feedback_point(_get_card_feedback_center(attacker)),
		_to_feedback_point(_get_card_feedback_center(target))
	)

func _get_valid_feedback_card(reference: WeakRef) -> BaseCard:
	if not reference:
		return null
	var value: Variant = reference.get_ref()
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as BaseCard

func _on_attack_declared(attacker: BaseCard, target: BaseCard) -> void:
	if not attacker or not target:
		return
	var is_pretelegraphed := (
		_combat_sequence_active
		and attacker == _combat_sequence_attacker
		and target == _combat_sequence_target
	)
	if _feedback_layer and is_pretelegraphed:
		_feedback_layer.trigger_attack_impact()
	elif _feedback_layer:
		var trace_color := _get_team_accent(attacker.owner_id)
		_play_attack_feedback(attacker, target, trace_color)
	if not is_pretelegraphed:
		attacker.play_feedback_animation("attack")
	if _feedback_audio:
		_feedback_audio.play_event("attack")

func _on_card_played(card: BaseCard, _target: BaseCard) -> void:
	if card is SpecialPowerCard:
		_record_graveyard_card(card, "played")
	if card:
		var actor_tag := "O%d" % card.owner_id
		var type_tag := UI.get_card_type_label(card._get_card_type_key())
		_append_battle_log(
			"%s: %s (%s)" % [actor_tag, tr(card.card_name), tr(type_tag)],
			UI.get_card_type_color(card._get_card_type_key()),
			card._get_card_type_key(),
			card.card_id
		)
	if card and not MatchSetup.fast_mode and (card is HeroCard or card is SettlementCard):
		card.play_feedback_animation("deploy")
	if _feedback_audio:
		if card is UpgradeCard or card is SpecialPowerCard:
			_feedback_audio.play_event("ability")
		elif card is HeroCard or card is SettlementCard:
			_feedback_audio.play_event("deploy")

func _on_effect_resolved(
	effect_id: String,
	source: BaseCard,
	target: BaseCard,
	result: Dictionary
) -> void:
	if not bool(result.get("success", false)):
		return
	var normalized := effect_id.strip_edges().to_lower()
	match normalized:
		"damage":
			var actual_damage := int(result.get("armor_damage", 0)) + int(result.get("health_damage", 0))
			var blocked := int(result.get("blocked_damage", 0))
			var feedback_kind := _get_damage_feedback_kind(target, result)
			_play_board_impact_shake(feedback_kind, float(actual_damage + blocked))
			var active_feedback_source := _get_valid_feedback_card(_feedback_attack_source_ref)
			if (
				_feedback_layer
				and _feedback_layer.has_active_attack_path()
				and source
				and active_feedback_source == source
			):
				_feedback_layer.enhance_attack_impact(
					feedback_kind,
					clampf(0.82 + float(actual_damage + blocked) * 0.10, 0.82, 1.58)
				)
			if target:
				if is_instance_valid(target) and not target.is_queued_for_deletion():
					var card_animation_kind := (
						"damage"
						if feedback_kind == BattlefieldFeedbackLayer.IMPACT_HIT
						else feedback_kind
					)
					target.play_feedback_animation(card_animation_kind, actual_damage + blocked)
				var damage_text := "-%d" % actual_damage if actual_damage > 0 else "ENGELLENDİ"
				var feedback_color := Color(1.0, 0.34, 0.26)
				var emphasized := false
				match feedback_kind:
					BattlefieldFeedbackLayer.IMPACT_CRITICAL:
						damage_text = "KRİTİK  %s" % damage_text
						feedback_color = Color(1.0, 0.78, 0.22)
						emphasized = true
					BattlefieldFeedbackLayer.IMPACT_BLOCKED:
						damage_text = "SAVUNMA  •  %d ENGEL" % blocked
						if actual_damage > 0:
							damage_text += "  •  -%d" % actual_damage
						feedback_color = Color(0.42, 0.86, 1.0)
					BattlefieldFeedbackLayer.IMPACT_ARMOR_BREAK:
						damage_text = "ZIRH ÇATLADI  •  -%d" % actual_damage
						feedback_color = Color(0.78, 0.90, 1.0)
				if blocked > 0 and feedback_kind != BattlefieldFeedbackLayer.IMPACT_BLOCKED:
					damage_text += "  •  %d ENGEL" % blocked
				_spawn_floating_feedback(damage_text, target, feedback_color, emphasized)
				if bool(result.get("guard_redirected", false)):
					_spawn_floating_feedback(tr("MUHAFIZ KARŞILADI"), target, Color(0.42, 0.88, 1.0))
					if _feedback_layer and source and is_instance_valid(source):
						var original_target := result.get("original_target") as BaseCard
						var struct_pt := _to_feedback_point(_get_card_feedback_center(original_target if original_target else target))
						_feedback_layer.play_guard_intercept(
							_to_feedback_point(_get_card_feedback_center(source)),
							struct_pt,
							_to_feedback_point(_get_card_feedback_center(target))
						)
				var mod_tags: Array[String] = []
				var siege_b := int(result.get("siege_bonus", 0))
				if siege_b > 0:
					mod_tags.append(tr("KUŞATMA +%d") % siege_b)
				var banner_b := int(result.get("war_banner_bonus", 0))
				if banner_b > 0:
					mod_tags.append(tr("SANCAK +%d") % banner_b)
				var lb_b := int(result.get("last_breath_bonus", 0))
				if lb_b > 0:
					mod_tags.append(tr("SON NEFES +%d") % lb_b)
				var bulwark_r := int(result.get("bulwark_reduction", 0))
				if bulwark_r > 0:
					mod_tags.append(tr("SİPER -%d") % bulwark_r)
				var eclipse_r := int(result.get("eclipse_reduction", 0))
				if eclipse_r > 0:
					mod_tags.append(tr("TUTULMA -%d") % eclipse_r)
				var pierce_d := int(result.get("piercing_health_damage", 0))
				if pierce_d > 0:
					mod_tags.append(tr("DELİCİ %d") % pierce_d)
				if not mod_tags.is_empty():
					_spawn_floating_feedback(" • ".join(mod_tags), target, UI.BRASS_BRIGHT)
				var src_name := tr(source.card_name) if source and is_instance_valid(source) else tr("Etki")
				var tgt_name := tr(target.card_name) if is_instance_valid(target) else tr("Hedef")
				_append_battle_log(
					"%s → %s (-%d%s)" % [src_name, tgt_name, actual_damage, (" " + tr("YOK")) if bool(result.get("destroyed", false)) else ""],
					UI.BLOOD.lightened(0.28),
					source._get_card_type_key() if source and is_instance_valid(source) else "",
					source.card_id if source and is_instance_valid(source) else ""
				)
				if _feedback_layer and source and is_instance_valid(source) and source is SpecialPowerCard:
					_feedback_layer.play_spell_beam(
						_to_feedback_point(_get_card_feedback_center(source)),
						_to_feedback_point(_get_card_feedback_center(target)),
						Color(1.0, 0.36, 0.24, 1.0)
					)
			if _feedback_audio and not bool(result.get("destroyed", false)):
				match feedback_kind:
					BattlefieldFeedbackLayer.IMPACT_CRITICAL:
						_feedback_audio.play_event("critical")
					BattlefieldFeedbackLayer.IMPACT_BLOCKED:
						_feedback_audio.play_event("block")
					BattlefieldFeedbackLayer.IMPACT_ARMOR_BREAK:
						_feedback_audio.play_event("armor_break")
					_:
						_feedback_audio.play_event("damage")
			_refresh_lane_visuals()
		"heal":
			var healed := int(result.get("healed", 0))
			if healed > 0 and target and is_instance_valid(target):
				target.play_feedback_animation("heal", healed)
				_spawn_floating_feedback("+%d CAN" % healed, target, Color(0.38, 1.0, 0.58))
				if _feedback_layer:
					_feedback_layer.play_secondary_burst(_to_feedback_point(_get_card_feedback_center(target)), Color(0.36, 0.94, 0.54))
				if _feedback_audio:
					_feedback_audio.play_event("heal")
		"stunned", "poison", "protected":
			if target and is_instance_valid(target):
				var status_entry_variant: Variant = CardKeywordGlossary.STATUS_DEFINITIONS.get(normalized, {})
				var status_entry := status_entry_variant as Dictionary
				var status_name := str(status_entry.get("name", normalized.to_upper())).to_upper()
				var status_amount := target.get_status_amount(normalized)
				target.play_feedback_animation("heal" if normalized == "protected" else "damage", status_amount)
				var status_color := Color(0.42, 0.86, 1.0)
				if normalized == "poison":
					status_color = Color(0.50, 0.92, 0.36)
				elif normalized == "stunned":
					status_color = Color(0.56, 0.82, 1.0)
				_spawn_floating_feedback(
					"%s %d" % [status_name, status_amount],
					target,
					status_color
				)
				if _feedback_layer:
					_feedback_layer.play_secondary_burst(
						_to_feedback_point(_get_card_feedback_center(target)),
						status_color,
						"shield" if normalized == "protected" else "ring"
					)
				if _feedback_audio:
					_feedback_audio.play_event("heal" if normalized == "protected" else "damage")
		"cleave", "retaliate", "stormstep", "spore_drift", "afterburn", "petrify", "armor_siphon", "devourer", "soulbond", "starlight_ward", "steadfast", "hive_mind":
			if target and is_instance_valid(target):
				var trait_label := CardKeywordGlossary.get_keyword_name(normalized).to_upper()
				if trait_label.is_empty():
					trait_label = normalized.to_upper()
				_spawn_floating_feedback(trait_label, target, UI.BRASS_BRIGHT)
				if _feedback_layer:
					_feedback_layer.play_secondary_burst(_to_feedback_point(_get_card_feedback_center(target)), UI.BRASS_BRIGHT)
		"banish_target":
			if target and is_instance_valid(target):
				_spawn_floating_feedback("SÜRGÜN", target, Color(0.76, 0.44, 1.0), true)
				if _feedback_layer:
					_feedback_layer.play_secondary_burst(_to_feedback_point(_get_card_feedback_center(target)), Color(0.76, 0.44, 1.0))
		"attach_skill":
			if target and is_instance_valid(target):
				target.play_feedback_animation("upgrade")
				_spawn_floating_feedback("BECERİ BAĞLANDI", target, Color(0.84, 0.65, 1.0))
		"push_adjacent_lane":
			if target and is_instance_valid(target):
				target.play_feedback_animation("move")
				_spawn_floating_feedback("SAVRULDU", target, Color(0.44, 0.88, 1.0))
				if _feedback_audio:
					_feedback_audio.play_event("move")
			_refresh_lane_visuals()
		"energy_income", "building_discount":
			var source_variant: Variant = result.get("source", null)
			var source_card := source_variant as BaseCard
			var energy_gained := int(result.get("energy_gained", 0))
			if source_card and energy_gained > 0:
				_spawn_floating_feedback("+%d ENERJİ" % energy_gained, source_card, Color(1.0, 0.82, 0.32))
		"spell_echo":
			var echo_source := result.get("source") as BaseCard
			var echoed_energy := int(result.get("energy_gained", 0))
			if echo_source and is_instance_valid(echo_source):
				_spawn_floating_feedback("YANKI  +%d ENERJİ" % echoed_energy, echo_source, Color(0.68, 0.52, 1.0))
		"lane_ready":
			if target and is_instance_valid(target):
				target.play_feedback_animation("move")
				_spawn_floating_feedback("HAZIR KALDI", target, Color(0.42, 0.92, 1.0))
		"retaliate":
			if target and is_instance_valid(target):
				_spawn_floating_feedback(
					"MİSİLLEME  -%d" % int(result.get("health_damage", 0) + result.get("armor_damage", 0)),
					target,
					Color(1.0, 0.50, 0.28),
					true
				)
		"last_will":
			if source and is_instance_valid(source):
				_spawn_floating_feedback("SON VASİYET  +1 KART", source, Color(0.88, 0.72, 1.0))
		"blood_price":
			if target and is_instance_valid(target) and not target.is_queued_for_deletion():
				_spawn_floating_feedback("KAN BEDELİ", target, Color(0.95, 0.22, 0.30), true)
		"detach_skill":
			if target and is_instance_valid(target) and not target.is_queued_for_deletion():
				target.play_feedback_animation("damage")
				_spawn_floating_feedback("RÜN KIRILDI", target, Color(0.72, 0.46, 1.0), true)
		"revive_last_hero":
			var revived := result.get("revived_card") as HeroCard
			if revived and is_instance_valid(revived):
				revived.play_feedback_animation("heal", 1)
				_spawn_floating_feedback("KÜLLERDEN DÖNDÜ", revived, Color(1.0, 0.68, 0.30), true)
		"cloak_revealed":
			if target and is_instance_valid(target):
				_spawn_floating_feedback("ÖRTÜ KALKTI", target, Color(0.62, 0.58, 0.88))
		_:
			pass

func _get_damage_feedback_kind(target: BaseCard, result: Dictionary) -> String:
	var blocked := int(result.get("blocked_damage", 0))
	var armor_damage := int(result.get("armor_damage", 0))
	var health_damage := int(result.get("health_damage", 0))
	var destroyed := bool(result.get("destroyed", false))
	var maximum_health := 1
	if target and is_instance_valid(target):
		maximum_health = maxi(1, target.get_max_health())
	var critical_threshold := maxi(4, int(ceil(float(maximum_health) * 0.45)))
	if destroyed or health_damage >= critical_threshold:
		return BattlefieldFeedbackLayer.IMPACT_CRITICAL
	if blocked > 0:
		return BattlefieldFeedbackLayer.IMPACT_BLOCKED
	if armor_damage > 0:
		return BattlefieldFeedbackLayer.IMPACT_ARMOR_BREAK
	return BattlefieldFeedbackLayer.IMPACT_HIT

func _on_card_destroyed(card: BaseCard, _source: BaseCard) -> void:
	_record_graveyard_card(card, "destroyed")
	if not card or not is_instance_valid(card):
		return
	_spawn_death_ghost(card)
	if _feedback_audio:
		_feedback_audio.play_event("destroy")

func _on_experience_changed(
	card: BaseCard,
	_current_experience: int,
	gained: int,
	_reason: String
) -> void:
	if not card or not is_instance_valid(card) or gained <= 0:
		return
	_spawn_floating_feedback("+%d TP" % gained, card, Color(0.42, 0.78, 1.0))
	if _feedback_audio:
		_feedback_audio.play_event("experience")
	# A combat hit can award Tecrübe synchronously. Delay its card pulse so it
	# does not kill the attack animation that has just started.
	var timer := get_tree().create_timer(0.34)
	timer.timeout.connect(_play_deferred_card_feedback.bind(weakref(card), "experience", gained))

func _play_deferred_card_feedback(card_ref: WeakRef, kind: String, amount: int) -> void:
	if not card_ref:
		return
	var card_variant: Variant = card_ref.get_ref()
	if typeof(card_variant) != TYPE_OBJECT or not is_instance_valid(card_variant):
		return
	var card := card_variant as BaseCard
	if card and not card.is_queued_for_deletion():
		card.play_feedback_animation(kind, amount)

func _on_card_leveled_up(card: BaseCard, level: int, _branch_id: String) -> void:
	if not card or not is_instance_valid(card):
		return
	card.play_feedback_animation("upgrade", level)
	_spawn_floating_feedback("SEVİYE %d" % level, card, Color(1.0, 0.78, 0.28))
	if _feedback_audio:
		_feedback_audio.play_event("upgrade")

func _on_card_moved(card: BaseCard, _from_slot: CardSlot, _to_slot: CardSlot) -> void:
	if not card or not is_instance_valid(card):
		return
	card.play_feedback_animation("move")
	_spawn_floating_feedback("HAREKET", card, Color(0.42, 0.88, 1.0))
	if _feedback_audio:
		_feedback_audio.play_event("move")
	_refresh_lane_visuals()

func _get_card_feedback_center(card: BaseCard) -> Vector2:
	if card and is_instance_valid(card):
		if card.current_slot and is_instance_valid(card.current_slot):
			return card.current_slot.get_global_rect().get_center()
		return card.get_global_rect().get_center()
	return get_viewport_rect().size * 0.5

func _get_feedback_tracking_control(card: BaseCard) -> Control:
	if not card or not is_instance_valid(card):
		return null
	if card.current_slot and is_instance_valid(card.current_slot):
		return card.current_slot
	var parent := card.get_parent()
	if parent is CardSlot:
		return parent as CardSlot
	return card

func _register_transient_feedback_anchor(node: Control, card: BaseCard, track_rect: bool) -> void:
	var tracking_control := _get_feedback_tracking_control(card)
	if not node or not tracking_control:
		return
	_transient_feedback_anchors.append({
		"node_ref": weakref(node),
		"source_ref": weakref(tracking_control),
		"track_rect": track_rect,
	})
	_refresh_transient_feedback_positions()

func _refresh_transient_feedback_positions() -> void:
	if _transient_feedback_anchors.is_empty() or not _feedback_layer:
		return
	var live_anchors: Array[Dictionary] = []
	for entry in _transient_feedback_anchors:
		var node_ref := entry.get("node_ref") as WeakRef
		var source_ref := entry.get("source_ref") as WeakRef
		if not node_ref or not source_ref:
			continue
		var node_value: Variant = node_ref.get_ref()
		if typeof(node_value) != TYPE_OBJECT or not is_instance_valid(node_value):
			continue
		var node := node_value as Control
		if not node:
			continue
		live_anchors.append(entry)
		var source_value: Variant = source_ref.get_ref()
		if typeof(source_value) != TYPE_OBJECT or not is_instance_valid(source_value):
			continue
		var source := source_value as Control
		if not source:
			continue
		var source_rect := source.get_global_rect()
		if bool(entry.get("track_rect", false)):
			var local_start := _to_feedback_point(source_rect.position)
			var local_end := _to_feedback_point(source_rect.end)
			node.position = local_start
			node.size = (local_end - local_start).abs()
			node.pivot_offset = node.size * 0.5
		else:
			node.position = _to_feedback_point(source_rect.get_center())
	_transient_feedback_anchors = live_anchors

func _clear_transient_feedback() -> void:
	for entry in _transient_feedback_anchors:
		var node_ref := entry.get("node_ref") as WeakRef
		if not node_ref:
			continue
		var node_value: Variant = node_ref.get_ref()
		if typeof(node_value) == TYPE_OBJECT and is_instance_valid(node_value):
			(node_value as Node).queue_free()
	_transient_feedback_anchors.clear()

func _spawn_floating_feedback(
	message: String,
	card: BaseCard,
	color: Color,
	emphasized: bool = false
) -> void:
	if message.is_empty() or not _feedback_clip:
		return
	var anchor := Control.new()
	anchor.name = "FloatingFeedbackAnchor"
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.position = _to_feedback_point(_get_card_feedback_center(card))
	_feedback_clip.add_child(anchor)

	# Vertical stagger prevents simultaneous popups (e.g. damage + modifier + XP)
	# on the same card from overlapping each other.
	var card_key := card.get_instance_id() if card and is_instance_valid(card) else 0
	var now_ms := Time.get_ticks_msec()
	var stack_index := 0
	if _recent_feedback_stamps.has(card_key):
		var entry := _recent_feedback_stamps[card_key] as Dictionary
		if now_ms - int(entry.get("time", 0)) < 680:
			stack_index = (int(entry.get("count", 0)) + 1) % 4
	_recent_feedback_stamps[card_key] = {"time": now_ms, "count": stack_index}

	var label := Label.new()
	label.name = "FloatingFeedback"
	label.text = message
	label.size = Vector2(230.0, 34.0) if emphasized else Vector2(200.0, 28.0)
	label.position = Vector2(-label.size.x * 0.5, -label.size.y * 0.5 - float(stack_index) * 24.0)
	label.pivot_offset = label.size * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI.BODY_BOLD_FONT)
	label.add_theme_font_size_override("font_size", 18 if emphasized else 14)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	anchor.add_child(label)
	_register_transient_feedback_anchor(anchor, card, false)
	floating_feedback_count += 1
	label.scale = Vector2(0.70, 0.70)
	var target_y := label.position.y - 38.0
	var tween := create_tween().bind_node(anchor).set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", target_y, 0.78)
	tween.tween_property(label, "scale", Vector2(1.16, 1.16) if emphasized else Vector2(1.04, 1.04), 0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_delay(0.16)
	tween.tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.38)
	tween.chain().tween_callback(anchor.queue_free)

func _spawn_death_ghost(card: BaseCard) -> void:
	if not _feedback_clip:
		return
	var source_rect := card.get_global_rect()
	if card.current_slot and is_instance_valid(card.current_slot):
		source_rect = card.current_slot.get_global_rect()
	var ghost := Panel.new()
	ghost.name = "DeathFeedback"
	var local_start := _to_feedback_point(source_rect.position)
	var local_end := _to_feedback_point(source_rect.end)
	ghost.position = local_start
	ghost.size = (local_end - local_start).abs()
	ghost.pivot_offset = ghost.size * 0.5
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.04, 0.03, 0.92)
	style.border_color = Color(1.0, 0.42, 0.18, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	ghost.add_theme_stylebox_override("panel", style)
	_feedback_clip.add_child(ghost)
	_register_transient_feedback_anchor(ghost, card, true)

	# Preserve the dying card's illustration inside the burn-dissolve shader!
	if card.card_art:
		var art_ghost := TextureRect.new()
		art_ghost.texture = card.card_art
		art_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_ghost.offset_left = 3.0
		art_ghost.offset_top = 3.0
		art_ghost.offset_right = -3.0
		art_ghost.offset_bottom = -3.0
		art_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = CARD_DISSOLVE_SHADER
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("edge_color", Color(1.0, 0.45, 0.14, 1.0))
		art_ghost.material = mat
		ghost.add_child(art_ghost)
		var dissolve_tw := create_tween().bind_node(art_ghost)
		dissolve_tw.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.52)

	# Glowing ember CPUParticles2D burst
	if not MatchSetup.fast_mode:
		var particles := CPUParticles2D.new()
		particles.position = ghost.size * 0.5
		particles.one_shot = true
		particles.explosiveness = 0.85
		particles.amount = 18
		particles.lifetime = 0.55
		particles.direction = Vector2(0.0, -1.0)
		particles.spread = 150.0
		particles.initial_velocity_min = 28.0
		particles.initial_velocity_max = 86.0
		particles.gravity = Vector2(0.0, -35.0)
		particles.scale_amount_min = 2.0
		particles.scale_amount_max = 4.5
		particles.color = Color(1.0, 0.58, 0.18, 0.95)
		particles.emitting = true
		ghost.add_child(particles)

	death_feedback_count += 1
	var tween := create_tween().bind_node(ghost).set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "scale", Vector2(1.12, 1.12), 0.50)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.42).set_delay(0.14)
	tween.chain().tween_callback(ghost.queue_free)

func _place_board_slot(slot: CardSlot, local_position: Vector2, slot_size: Vector2, layout_scale: float) -> void:
	slot.anchor_left = 0.0
	slot.anchor_top = 0.0
	slot.anchor_right = 0.0
	slot.anchor_bottom = 0.0
	slot.offset_left = local_position.x
	slot.offset_top = local_position.y
	slot.offset_right = local_position.x + slot_size.x
	slot.offset_bottom = local_position.y + slot_size.y
	slot.custom_minimum_size = slot_size
	slot.size = slot_size
	slot.set_card_visual_scale(Vector2.ONE * (BOARD_CARD_BASE_SCALE * layout_scale))
	slot.visible = true
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

func _configure_deck_frames(viewport_size: Vector2) -> void:
	# Decks are physical battlefield props. Their local world positions stay
	# fixed beside the Headquarters while the shared camera moves the whole layer.
	var deck_parent := _battlefield_world_objects if _battlefield_world_objects else self
	_ensure_deck_parent(1, deck_parent)
	_ensure_deck_parent(2, deck_parent)
	for player_id in GameRules.PLAYER_IDS:
		var hq_rect := _get_hq_world_rect(player_id)
		var deck_position := Vector2(
			hq_rect.position.x - DECK_HQ_HORIZONTAL_GAP - DECK_PANEL_SIZE.x,
			hq_rect.get_center().y - (DECK_PANEL_SIZE.y * 0.5)
		)
		_configure_deck_frame(_deck_panels.get(player_id), deck_position, DECK_PANEL_SIZE)
		var deck_panel := _deck_panels.get(player_id) as Control
		if deck_panel:
			deck_panel.pivot_offset = Vector2.ZERO
			deck_panel.scale = Vector2.ONE
			deck_panel.visible = true

	var side_pad = clamp(hud.size.x * 0.055, 14.0, 20.0)
	var action_width = max(170.0, hud.size.x - (side_pad * 2.0))
	var action_left = (hud.size.x - action_width) * 0.5
	if _scenario_objectives_button:
		_scenario_objectives_button.anchor_left = 0.0
		_scenario_objectives_button.anchor_top = 0.0
		_scenario_objectives_button.anchor_right = 0.0
		_scenario_objectives_button.anchor_bottom = 0.0
		_scenario_objectives_button.offset_left = action_left
		_scenario_objectives_button.offset_top = 12.0
		_scenario_objectives_button.offset_right = action_left + action_width
		_scenario_objectives_button.offset_bottom = 56.0
		_scenario_objectives_button.z_index = 10

	var button_height = 52.0
	var button_top = viewport_size.y - button_height - 16.0
	end_turn_button.anchor_left = 0.0
	end_turn_button.anchor_top = 0.0
	end_turn_button.anchor_right = 0.0
	end_turn_button.anchor_bottom = 0.0
	end_turn_button.offset_left = action_left
	end_turn_button.offset_top = button_top
	end_turn_button.offset_right = action_left + action_width
	end_turn_button.offset_bottom = button_top + button_height

	_layout_sidebar_action_controls()

func _layout_sidebar_action_controls() -> void:
	if not hud or not end_turn_button:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var side_pad: float = 16.0
	var action_width: float = maxf(160.0, float(hud.size.x) - (side_pad * 2.0))
	var action_left: float = (float(hud.size.x) - action_width) * 0.5
	var cursor_top: float = float(end_turn_button.offset_top)

	var auto_attack_height := 40.0
	if _auto_attack_panel:
		if _auto_attack_panel.visible:
			cursor_top -= auto_attack_height + 8.0
		_auto_attack_panel.anchor_left = 0.0
		_auto_attack_panel.anchor_top = 0.0
		_auto_attack_panel.anchor_right = 0.0
		_auto_attack_panel.anchor_bottom = 0.0
		_auto_attack_panel.offset_left = action_left
		_auto_attack_panel.offset_top = cursor_top
		_auto_attack_panel.offset_right = action_left + action_width
		_auto_attack_panel.offset_bottom = cursor_top + auto_attack_height

	var supply_height := 40.0
	if _tactical_supply_button:
		if _tactical_supply_button.visible:
			cursor_top -= supply_height + 8.0
		_tactical_supply_button.anchor_left = 0.0
		_tactical_supply_button.anchor_top = 0.0
		_tactical_supply_button.anchor_right = 0.0
		_tactical_supply_button.anchor_bottom = 0.0
		_tactical_supply_button.offset_left = action_left
		_tactical_supply_button.offset_top = cursor_top
		_tactical_supply_button.offset_right = action_left + action_width
		_tactical_supply_button.offset_bottom = cursor_top + supply_height

	var token_height := 40.0
	if _preparation_token_button:
		if _preparation_token_button.visible:
			cursor_top -= token_height + 8.0
		_preparation_token_button.anchor_left = 0.0
		_preparation_token_button.anchor_top = 0.0
		_preparation_token_button.anchor_right = 0.0
		_preparation_token_button.anchor_bottom = 0.0
		_preparation_token_button.offset_left = action_left
		_preparation_token_button.offset_top = cursor_top
		_preparation_token_button.offset_right = action_left + action_width
		_preparation_token_button.offset_bottom = cursor_top + token_height

	var phase_height := 48.0
	if _phase_label:
		if _phase_label.visible:
			cursor_top -= phase_height + 6.0
		_phase_label.anchor_left = 0.0
		_phase_label.anchor_top = 0.0
		_phase_label.anchor_right = 0.0
		_phase_label.anchor_bottom = 0.0
		_phase_label.offset_left = action_left
		_phase_label.offset_top = cursor_top
		_phase_label.offset_right = action_left + action_width
		_phase_label.offset_bottom = cursor_top + phase_height

	if _preview_panel:
		var preview_top := 66.0 if _scenario_objectives_button else 12.0
		var preview_bottom := maxf(preview_top + 180.0, cursor_top - 10.0)
		_preview_panel.anchor_left = 0.0
		_preview_panel.anchor_top = 0.0
		_preview_panel.anchor_right = 0.0
		_preview_panel.anchor_bottom = 0.0
		_preview_panel.offset_left = side_pad
		_preview_panel.offset_top = preview_top
		_preview_panel.offset_right = hud.size.x - side_pad
		_preview_panel.offset_bottom = preview_bottom
		_layout_preview_surface()

func _ensure_deck_parent(player_id: int, expected_parent: Control) -> void:
	var deck_panel = _deck_panels.get(player_id) as Control
	if not deck_panel or not expected_parent:
		return

	if deck_panel.get_parent() != expected_parent:
		deck_panel.reparent(expected_parent, false)

func _configure_deck_frame(deck_panel: Control, local_position: Vector2, panel_size: Vector2) -> void:
	if not deck_panel:
		return

	deck_panel.anchor_left = 0.0
	deck_panel.anchor_top = 0.0
	deck_panel.anchor_right = 0.0
	deck_panel.anchor_bottom = 0.0
	deck_panel.offset_left = local_position.x
	deck_panel.offset_top = local_position.y
	deck_panel.offset_right = local_position.x + panel_size.x
	deck_panel.offset_bottom = local_position.y + panel_size.y
	deck_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_panel.z_index = 2

func _layout_phase_banner(viewport_size: Vector2) -> void:
	_layout_match_flow_chrome(viewport_size)
	if not _phase_banner_panel:
		return
	var sidebar_width: float = hud.size.x if hud else 0.0
	var playfield_right: float = viewport_size.x - sidebar_width
	var banner_width := minf(PHASE_BANNER_SIZE.x, maxf(280.0, playfield_right - 32.0))
	var banner_left := maxf(12.0, (playfield_right - banner_width) * 0.5)
	var banner_top := _get_top_playfield_reserved_height(viewport_size) + 46.0
	_phase_banner_panel.anchor_left = 0.0
	_phase_banner_panel.anchor_top = 0.0
	_phase_banner_panel.anchor_right = 0.0
	_phase_banner_panel.anchor_bottom = 0.0
	_phase_banner_panel.offset_left = banner_left
	_phase_banner_panel.offset_top = banner_top
	_phase_banner_panel.offset_right = banner_left + banner_width
	_phase_banner_panel.offset_bottom = banner_top + PHASE_BANNER_SIZE.y

func _show_phase_banner() -> void:
	if not _phase_banner_panel or not _phase_banner_label or not game_manager:
		return
	if MatchSetup.fast_mode:
		return
	_layout_phase_banner(get_viewport_rect().size)
	var actor_name := (
		tr(MatchSetup.get_ai_label(game_manager.active_player_id).to_upper())
		if MatchSetup.is_ai_player(game_manager.active_player_id)
		else tr("OYUNCU %d") % game_manager.active_player_id
	)
	_phase_banner_label.text = "%s  •  %s" % [
		tr(game_manager.get_phase_display_name()),
		actor_name,
	]
	_phase_banner_panel.visible = true
	_phase_banner_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _phase_banner_tween and _phase_banner_tween.is_valid():
		_phase_banner_tween.kill()
	_phase_banner_tween = create_tween().bind_node(_phase_banner_panel)
	_phase_banner_tween.tween_property(_phase_banner_panel, "modulate:a", 1.0, 0.12)
	_phase_banner_tween.tween_interval(0.72)
	_phase_banner_tween.tween_property(_phase_banner_panel, "modulate:a", 0.0, 0.22)
	_phase_banner_tween.tween_callback(_hide_phase_banner)

func _hide_phase_banner() -> void:
	if _phase_banner_panel:
		_phase_banner_panel.visible = false

func _on_reference_closed() -> void:
	if get_tree().paused and _pause_menu:
		_pause_menu.show_home()
		return
	_refresh_phase_ui()

func force_show_tutorial(step_index: int = 0) -> void:
	if not _tutorial_overlay:
		return
	_tutorial_overlay.open_tutorial(step_index)
	_refresh_phase_ui()

func _maybe_show_first_match_tutorial() -> void:
	if MatchSetup.is_scenario_match() or not _tutorial_overlay or DisplayServer.get_name() == "headless":
		return
	if not _is_first_match_tutorial_enabled():
		return
	if _has_completed_first_match_tutorial():
		return
	force_show_tutorial()

func _is_first_match_tutorial_enabled() -> bool:
	var config := ConfigFile.new()
	if config.load(PREFERENCES_PATH) != OK:
		return true
	return bool(config.get_value("gameplay", "tutorial_enabled", true))

func _has_completed_first_match_tutorial() -> bool:
	var config := ConfigFile.new()
	if config.load(ONBOARDING_SETTINGS_PATH) != OK:
		return false
	return bool(config.get_value(SETTINGS_SECTION, TUTORIAL_COMPLETED_KEY, false))

func _on_tutorial_closed(_skipped: bool) -> void:
	_save_first_match_tutorial_completion()
	_refresh_phase_ui()

func _save_first_match_tutorial_completion() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var config := ConfigFile.new()
	config.load(ONBOARDING_SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, TUTORIAL_COMPLETED_KEY, true)
	var save_error := config.save(ONBOARDING_SETTINGS_PATH)
	if save_error != OK:
		push_warning("Öğretici durumu kaydedilemedi: %s" % error_string(save_error))

func show_toast(
	message: String,
	accent_color: Color = Color(0.95, 0.72, 0.26),
	kicker_text: String = ""
) -> void:
	if message.is_empty():
		return

	if not _toast_panel or not is_instance_valid(_toast_panel):
		_create_toast_ui_nodes()

	_toast_label.text = _localize_display_text(message, "This action could not be completed.")
	_toast_kicker_label.text = _localize_display_text(
		kicker_text if not kicker_text.is_empty() else _get_toast_kicker(accent_color),
		"Battle update",
	)
	_toast_kicker_label.add_theme_color_override("font_color", accent_color.lightened(0.12))
	_toast_emblem_label.add_theme_color_override("font_color", accent_color)
	_toast_style.border_color = Color(accent_color, 0.72)
	_toast_panel.add_theme_stylebox_override("panel", _toast_style)
	var accent_style := StyleBoxFlat.new()
	accent_style.bg_color = accent_color
	accent_style.corner_radius_top_left = 2
	accent_style.corner_radius_bottom_left = 2
	_toast_accent_bar.add_theme_stylebox_override("panel", accent_style)
	_toast_panel.visible = true
	_toast_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_position_toast_panel(get_viewport_rect().size)
	_toast_panel.pivot_offset = _toast_panel.size * 0.5
	_toast_panel.scale = Vector2(0.96, 0.96)
	if _feedback_audio and accent_color.r >= 0.80 and accent_color.g <= 0.58:
		_feedback_audio.play_event("invalid")

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.16)
	_toast_tween.parallel().tween_property(_toast_panel, "scale", Vector2.ONE, 0.20)
	_toast_tween.tween_interval(TOAST_DURATION)
	_toast_tween.set_ease(Tween.EASE_IN)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.22)
	_toast_tween.parallel().tween_property(_toast_panel, "scale", Vector2(0.985, 0.985), 0.22)
	_toast_tween.tween_callback(_hide_toast_panel)

func _get_toast_kicker(accent_color: Color) -> String:
	if accent_color.r >= 0.80 and accent_color.g <= 0.58:
		return "HAMLE GEÇERSİZ"
	if accent_color.g >= 0.76 and accent_color.r <= 0.55:
		return "HAMLE ÇÖZÜLDÜ"
	if accent_color.b >= 0.72 and accent_color.r <= 0.55:
		return "TAKTİK BİLGİSİ"
	return "SAVAŞ GÜNLÜĞÜ"


func _localize_display_text(value: String, fallback_key: String) -> String:
	if value.is_empty():
		return value
	var localized := tr(value)
	if TranslationServer.get_locale().get_slice("_", 0).to_lower() == "tr":
		return localized
	if localized != value or not _contains_turkish_characters(value):
		return localized
	return tr(fallback_key)


func _contains_turkish_characters(value: String) -> bool:
	for character in ["ç", "ğ", "ı", "ö", "ş", "ü", "Ç", "Ğ", "İ", "Ö", "Ş", "Ü"]:
		if character in value:
			return true
	return false

func _create_toast_ui_nodes() -> void:
	if _toast_panel and is_instance_valid(_toast_panel):
		return

	_toast_panel = Panel.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_toast_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_toast_panel.z_index = 260
	_toast_style = _build_toast_style(Color(0.95, 0.72, 0.26))
	_toast_panel.add_theme_stylebox_override("panel", _toast_style)
	add_child(_toast_panel)

	_toast_accent_bar = Panel.new()
	_toast_accent_bar.name = "AccentBar"
	_toast_accent_bar.anchor_left = 0.0
	_toast_accent_bar.anchor_top = 0.0
	_toast_accent_bar.anchor_right = 0.0
	_toast_accent_bar.anchor_bottom = 1.0
	_toast_accent_bar.offset_right = 5.0
	_toast_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_accent_bar)

	_toast_emblem_label = Label.new()
	_toast_emblem_label.name = "Emblem"
	_toast_emblem_label.position = Vector2(15.0, 12.0)
	_toast_emblem_label.size = Vector2(32.0, 44.0)
	_toast_emblem_label.text = "◆"
	_toast_emblem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_emblem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_emblem_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_toast_emblem_label.add_theme_font_size_override("font_size", 18)
	_toast_emblem_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast_emblem_label.add_theme_constant_override("outline_size", 3)
	_toast_emblem_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_emblem_label)

	_toast_kicker_label = Label.new()
	_toast_kicker_label.name = "KickerLabel"
	_toast_kicker_label.anchor_left = 0.0
	_toast_kicker_label.anchor_top = 0.0
	_toast_kicker_label.anchor_right = 1.0
	_toast_kicker_label.anchor_bottom = 0.0
	_toast_kicker_label.offset_left = 58.0
	_toast_kicker_label.offset_top = 8.0
	_toast_kicker_label.offset_right = -18.0
	_toast_kicker_label.offset_bottom = 25.0
	_toast_kicker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_kicker_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_toast_kicker_label.add_theme_font_size_override("font_size", 10)
	_toast_kicker_label.add_theme_constant_override("letter_spacing", 1)
	_toast_kicker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_kicker_label)

	_toast_label = Label.new()
	_toast_label.name = "ToastLabel"
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_label.offset_left = 58.0
	_toast_label.offset_top = 24.0
	_toast_label.offset_right = -18.0
	_toast_label.offset_bottom = -7.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	_toast_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_toast_label.add_theme_constant_override("outline_size", 2)
	_toast_panel.add_child(_toast_label)
	_position_toast_panel(get_viewport_rect().size)

func _create_match_flow_chrome() -> void:
	# 1. Slim top-center Match Flow Strip (HQ Healths + Turn Owner + 3-Step Phase Stepper + Dominion)
	_match_flow_bar = Panel.new()
	_match_flow_bar.name = "MatchFlowBar"
	_match_flow_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_match_flow_bar.z_index = 230
	var bar_style := UI.inset_style(Color(0.045, 0.042, 0.044, 0.92), UI.BRASS, 5)
	bar_style.border_color = Color(UI.BRASS, 0.62)
	bar_style.content_margin_left = 10.0
	bar_style.content_margin_right = 10.0
	bar_style.content_margin_top = 3.0
	bar_style.content_margin_bottom = 3.0
	_match_flow_bar.add_theme_stylebox_override("panel", bar_style)
	add_child(_match_flow_bar)

	var bar_row := HBoxContainer.new()
	bar_row.name = "FlowRow"
	bar_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_row.offset_left = 10.0
	bar_row.offset_right = -10.0
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_row.add_theme_constant_override("separation", 10)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_match_flow_bar.add_child(bar_row)

	_flow_own_hq_label = Label.new()
	_flow_own_hq_label.name = "FlowOwnHQ"
	_flow_own_hq_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_flow_own_hq_label.add_theme_font_size_override("font_size", 11)
	_flow_own_hq_label.add_theme_color_override("font_color", UI.TEAM_PLAYER.lightened(0.30))
	_flow_own_hq_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(_flow_own_hq_label)

	var sep_l := Label.new()
	sep_l.text = "|"
	sep_l.add_theme_color_override("font_color", Color(UI.BRASS, 0.45))
	sep_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(sep_l)

	_flow_turn_pill = Label.new()
	_flow_turn_pill.name = "FlowTurnPill"
	_flow_turn_pill.add_theme_font_override("font", UI.DISPLAY_FONT)
	_flow_turn_pill.add_theme_font_size_override("font_size", 11)
	_flow_turn_pill.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	_flow_turn_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(_flow_turn_pill)

	var phase_specs := [
		[GameManager.TurnPhase.PREPARATION, "HAZIRLIK"],
		[GameManager.TurnPhase.COMBAT, "ÇATIŞMA"],
		[GameManager.TurnPhase.END, "TUR SONU"],
	]
	_flow_phase_labels.clear()
	for idx in range(phase_specs.size()):
		if idx > 0:
			var arrow := Label.new()
			arrow.text = "›"
			arrow.add_theme_font_size_override("font_size", 12)
			arrow.add_theme_color_override("font_color", Color(UI.TEXT_MUTED, 0.55))
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar_row.add_child(arrow)
		var step_lbl := Label.new()
		step_lbl.text = tr(str(phase_specs[idx][1]))
		step_lbl.add_theme_font_override("font", UI.DISPLAY_FONT)
		step_lbl.add_theme_font_size_override("font_size", 10)
		step_lbl.add_theme_color_override("font_color", Color(UI.TEXT_MUTED, 0.65))
		step_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_row.add_child(step_lbl)
		_flow_phase_labels[int(phase_specs[idx][0])] = step_lbl

	_flow_dominion_label = Label.new()
	_flow_dominion_label.name = "FlowDominion"
	_flow_dominion_label.visible = false
	_flow_dominion_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_flow_dominion_label.add_theme_font_size_override("font_size", 11)
	_flow_dominion_label.add_theme_color_override("font_color", UI.BRASS_BRIGHT)
	_flow_dominion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(_flow_dominion_label)

	var sep_r := Label.new()
	sep_r.text = "|"
	sep_r.add_theme_color_override("font_color", Color(UI.BRASS, 0.45))
	sep_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(sep_r)

	_flow_enemy_hq_label = Label.new()
	_flow_enemy_hq_label.name = "FlowEnemyHQ"
	_flow_enemy_hq_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_flow_enemy_hq_label.add_theme_font_size_override("font_size", 11)
	_flow_enemy_hq_label.add_theme_color_override("font_color", UI.TEAM_OPPONENT.lightened(0.28))
	_flow_enemy_hq_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(_flow_enemy_hq_label)

	# 2. Collapsible Live Battle Log ("SAVAŞ GÜNLÜĞÜ")
	_battle_log_toggle = Button.new()
	_battle_log_toggle.name = "BattleLogToggle"
	_battle_log_toggle.text = tr("GÜNLÜK")
	_battle_log_toggle.tooltip_text = tr("Son hamleleri ve hasar dökümünü aç/kapat")
	_battle_log_toggle.z_index = 235
	_battle_log_toggle.add_theme_font_size_override("font_size", 11)
	UI.style_button(_battle_log_toggle, UI.BRASS, false, true)
	_battle_log_toggle.pressed.connect(func():
		_battle_log_expanded = not _battle_log_expanded
		if _battle_log_panel:
			_battle_log_panel.visible = _battle_log_expanded
		_battle_log_toggle.text = tr("GÜNLÜK ▾") if _battle_log_expanded else tr("GÜNLÜK")
	)
	add_child(_battle_log_toggle)

	_battle_log_panel = PanelContainer.new()
	_battle_log_panel.name = "BattleLogPanel"
	_battle_log_panel.visible = false
	_battle_log_panel.z_index = 234
	_battle_log_panel.add_theme_stylebox_override("panel", UI.inset_style(Color(0.04, 0.038, 0.040, 0.94), UI.BRASS, 5))
	add_child(_battle_log_panel)

	var log_scroll := ScrollContainer.new()
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_log_panel.add_child(log_scroll)

	_battle_log_list = VBoxContainer.new()
	_battle_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_log_list.add_theme_constant_override("separation", 4)
	log_scroll.add_child(_battle_log_list)

	# 3. AI Card Spotlight Overlay Layer
	_ai_spotlight_layer = Control.new()
	_ai_spotlight_layer.name = "AISpotlightLayer"
	_ai_spotlight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ai_spotlight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ai_spotlight_layer.z_index = 250
	add_child(_ai_spotlight_layer)

	_layout_match_flow_chrome(get_viewport_rect().size)
	_refresh_match_flow_chrome()


func _layout_match_flow_chrome(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var sidebar_width: float = float(hud.size.x) if hud else 0.0
	var playfield_width: float = maxf(320.0, viewport_size.x - sidebar_width)
	if _match_flow_bar:
		var bar_w: float = clampf(playfield_width * 0.64, 420.0, 620.0)
		var bar_x: float = maxf(104.0, (playfield_width - bar_w) * 0.5)
		_match_flow_bar.anchor_left = 0.0
		_match_flow_bar.anchor_top = 0.0
		_match_flow_bar.anchor_right = 0.0
		_match_flow_bar.anchor_bottom = 0.0
		_match_flow_bar.offset_left = bar_x
		_match_flow_bar.offset_top = 8.0
		_match_flow_bar.offset_right = bar_x + bar_w
		_match_flow_bar.offset_bottom = 40.0
	if _battle_log_toggle:
		_battle_log_toggle.anchor_left = 0.0
		_battle_log_toggle.anchor_top = 0.0
		_battle_log_toggle.anchor_right = 0.0
		_battle_log_toggle.anchor_bottom = 0.0
		_battle_log_toggle.offset_left = 14.0
		_battle_log_toggle.offset_top = 8.0
		_battle_log_toggle.offset_right = 98.0
		_battle_log_toggle.offset_bottom = 38.0
	if _battle_log_panel:
		_battle_log_panel.anchor_left = 0.0
		_battle_log_panel.anchor_top = 0.0
		_battle_log_panel.anchor_right = 0.0
		_battle_log_panel.anchor_bottom = 0.0
		_battle_log_panel.offset_left = 14.0
		_battle_log_panel.offset_top = 44.0
		_battle_log_panel.offset_right = 272.0
		_battle_log_panel.offset_bottom = 228.0


func _refresh_match_flow_chrome() -> void:
	if not _match_flow_bar or not game_manager:
		return
	var own_id: int = _get_hand_perspective_player_id()
	var enemy_id: int = 2 if own_id == 1 else 1
	var own_hp: int = int(game_manager.player_hq_health.get(own_id, GameRules.HEADQUARTERS_HEALTH))
	var enemy_hp: int = int(game_manager.player_hq_health.get(enemy_id, GameRules.HEADQUARTERS_HEALTH))
	if _flow_own_hq_label:
		_flow_own_hq_label.text = "%s %d" % [tr("MERKEZ"), own_hp]
	if _flow_enemy_hq_label:
		_flow_enemy_hq_label.text = "%s %d" % [tr("RAKİP"), enemy_hp]
	if _flow_turn_pill:
		var is_own_turn: bool = int(game_manager.active_player_id) == own_id
		_flow_turn_pill.text = tr("SIRA SENDE") if is_own_turn else tr("RAKİP SIRASI")
		_flow_turn_pill.add_theme_color_override(
			"font_color",
			UI.TEAM_PLAYER.lightened(0.34) if is_own_turn else UI.TEAM_OPPONENT.lightened(0.32)
		)
	var current_phase_id: int = int(game_manager.current_phase)
	for phase_key in _flow_phase_labels.keys():
		var lbl := _flow_phase_labels[phase_key] as Label
		if not lbl:
			continue
		var is_active: bool = int(phase_key) == current_phase_id
		lbl.add_theme_color_override("font_color", UI.BRASS_BRIGHT if is_active else Color(UI.TEXT_MUTED, 0.50))
		lbl.add_theme_font_size_override("font_size", 11 if is_active else 10)
	if _flow_dominion_label:
		var is_dom := MatchSetup.is_dominion()
		_flow_dominion_label.visible = is_dom
		if is_dom:
			var own_score: int = int(game_manager.dominion_scores.get(own_id, 0))
			var enemy_score: int = int(game_manager.dominion_scores.get(enemy_id, 0))
			_flow_dominion_label.text = tr("HAK %d-%d") % [own_score, enemy_score]


func _append_battle_log(summary: String, accent: Color = UI.PARCHMENT, card_type: String = "", card_id: String = "") -> void:
	if summary.strip_edges().is_empty():
		return
	_battle_log_entries.push_front({
		"text": summary,
		"color": accent,
		"card_type": card_type,
		"card_id": card_id,
		"turn": int(game_manager.round_count) if game_manager else 1,
	})
	if _battle_log_entries.size() > 14:
		_battle_log_entries.resize(14)
	if not _battle_log_list:
		return
	for child in _battle_log_list.get_children():
		child.queue_free()
	for entry in _battle_log_entries:
		var row_btn := Button.new()
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.flat = true
		row_btn.text = "R%d • %s" % [int(entry.get("turn", 1)), str(entry.get("text", ""))]
		row_btn.clip_text = true
		row_btn.custom_minimum_size = Vector2(0.0, 22.0)
		row_btn.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
		row_btn.add_theme_font_size_override("font_size", 11)
		row_btn.add_theme_color_override("font_color", entry.get("color", UI.PARCHMENT))
		row_btn.add_theme_color_override("font_hover_color", Color.WHITE)
		var entry_type := str(entry.get("card_type", ""))
		var entry_id := str(entry.get("card_id", ""))
		if not entry_type.is_empty() and not entry_id.is_empty():
			row_btn.pressed.connect(func():
				var temp_card := _instantiate_card_from_ref({"card_type": entry_type, "card_id": entry_id}, 1)
				if temp_card:
					_show_card_preview(temp_card)
					temp_card.queue_free()
			)
		_battle_log_list.add_child(row_btn)


func _refresh_end_turn_pulse() -> void:
	if not end_turn_button or not game_manager:
		return
	var should_pulse := false
	var active_id: int = int(game_manager.active_player_id)
	if (
		bool(game_manager.is_game_active)
		and bool(game_manager.is_match_started)
		and not MatchSetup.is_ai_player(active_id)
		and not end_turn_button.disabled
		and not MatchSetup.fast_mode
	):
		if game_manager.current_phase == GameManager.TurnPhase.COMBAT:
			var has_ready_attacker := false
			for b_card in get_board_cards(active_id):
				if CombatResolver.get_attacker_error(game_manager, b_card).is_empty():
					has_ready_attacker = true
					break
			should_pulse = not has_ready_attacker
		elif game_manager.current_phase == GameManager.TurnPhase.PREPARATION:
			var has_any_play := false
			for h_card in get_hand_cards(active_id):
				if _is_hand_card_currently_playable(h_card):
					has_any_play = true
					break
			if not has_any_play:
				for b_card in get_board_cards(active_id):
					if ProgressionResolver.get_upgrade_start_error(game_manager, b_card).is_empty():
						has_any_play = true
						break
			should_pulse = not has_any_play
	if should_pulse:
		if not _end_turn_pulse_tween or not _end_turn_pulse_tween.is_valid():
			_end_turn_pulse_tween = create_tween().bind_node(end_turn_button).set_loops()
			_end_turn_pulse_tween.tween_property(end_turn_button, "modulate", Color(1.18, 1.12, 0.92, 1.0), 0.55)
			_end_turn_pulse_tween.tween_property(end_turn_button, "modulate", Color.WHITE, 0.55)
	else:
		if _end_turn_pulse_tween and _end_turn_pulse_tween.is_valid():
			_end_turn_pulse_tween.kill()
		_end_turn_pulse_tween = null
		end_turn_button.modulate = Color.WHITE


func animate_ai_card_deploy(card: BaseCard, player_id: int) -> void:
	if not card or not is_instance_valid(card) or MatchSetup.fast_mode:
		return
	var hand = _get_hand_for_player(player_id)
	var origin_center := hand.get_global_rect().get_center() if hand else Vector2(get_viewport_rect().size.x * 0.4, 40.0)
	card.animate_move_from(origin_center)


func show_ai_card_spotlight(card: BaseCard, target_slot: CardSlot) -> void:
	if not card or not is_instance_valid(card) or not _ai_spotlight_layer or MatchSetup.fast_mode:
		return
	var card_type := card._get_card_type_key()
	var preview := _instantiate_card_from_ref({"card_type": card_type, "card_id": card.card_id}, card.owner_id)
	if not preview:
		return
	var container := PanelContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_stylebox_override("panel", UI.inset_style(Color(0.04, 0.035, 0.04, 0.95), UI.TEAM_OPPONENT, 6))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	container.add_child(vbox)
	var caption := Label.new()
	caption.text = tr("RAKİP OYNADI: %s") % tr(card.card_name).to_upper()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", UI.DISPLAY_FONT)
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", UI.TEAM_OPPONENT.lightened(0.32))
	vbox.add_child(caption)
	var mount := Control.new()
	mount.custom_minimum_size = Vector2(150.0, 210.0)
	mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(mount)
	preview.is_public_preview = true
	preview.is_draggable = false
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.scale = Vector2(0.75, 0.75)
	preview.position = Vector2(-25.0, -35.0)
	mount.add_child(preview)
	_ai_spotlight_layer.add_child(container)
	var playfield_w: float = get_viewport_rect().size.x - (float(hud.size.x) if hud else 0.0)
	container.position = Vector2(maxf(20.0, playfield_w * 0.5 - 92.0), 66.0)
	container.modulate.a = 0.0
	if _feedback_layer and target_slot and is_instance_valid(target_slot):
		_feedback_layer.play_spell_beam(
			_to_feedback_point(container.position + Vector2(92.0, 120.0)),
			_to_feedback_point(target_slot.get_global_rect().get_center()),
			UI.get_card_type_color(card_type),
			4.5,
			0.68
		)
	var tw := create_tween().bind_node(container)
	tw.tween_property(container, "modulate:a", 1.0, 0.14)
	tw.tween_interval(0.52)
	tw.tween_property(container, "modulate:a", 0.0, 0.16)
	await tw.finished
	if is_instance_valid(container):
		container.queue_free()


func _build_toast_style(accent_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.032, 0.029, 0.985)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent_color, 0.72)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0.0, 6.0)
	style.content_margin_left = 6.0
	style.anti_aliasing = true
	return style

func _position_toast_panel(viewport_size: Vector2) -> void:
	if not _toast_panel:
		return

	var arena_left := _board_view_rect.position.x if _board_view_rect.size.x > 0.0 else 0.0
	var arena_width := _board_view_rect.size.x if _board_view_rect.size.x > 0.0 else viewport_size.x
	var toast_width = min(TOAST_PANEL_SIZE.x, max(220.0, arena_width - 32.0))
	var toast_height = TOAST_PANEL_SIZE.y
	var toast_top = 48.0
	if top_hud and top_hud.visible:
		toast_top = max(toast_top, top_hud.position.y + top_hud.size.y + 8.0)
	_toast_panel.anchor_left = 0.0
	_toast_panel.anchor_top = 0.0
	_toast_panel.anchor_right = 0.0
	_toast_panel.anchor_bottom = 0.0
	_toast_panel.offset_left = arena_left + ((arena_width - toast_width) * 0.5)
	_toast_panel.offset_top = toast_top
	_toast_panel.offset_right = _toast_panel.offset_left + toast_width
	_toast_panel.offset_bottom = _toast_panel.offset_top + toast_height

func _hide_toast_panel() -> void:
	if _toast_panel and is_instance_valid(_toast_panel):
		_toast_panel.visible = false

func _get_hand_card_count(hand: Control) -> int:
	if not hand:
		return 0

	var count := 0
	for child in hand.get_children():
		if child is BaseCard:
			count += 1

	return count

func _register_preview_card(card: BaseCard) -> void:
	if not card:
		return

	var entered_callback := _begin_card_preview.bind(card)
	if not card.mouse_entered.is_connected(entered_callback):
		card.mouse_entered.connect(entered_callback)

	var exited_callback := _end_card_preview.bind(card)
	if not card.mouse_exited.is_connected(exited_callback):
		card.mouse_exited.connect(exited_callback)

	var input_callback := _on_preview_card_gui_input.bind(card)
	if not card.gui_input.is_connected(input_callback):
		card.gui_input.connect(input_callback)

	var state_callback := _on_preview_source_state_changed.bind(card)
	if not card.preview_state_changed.is_connected(state_callback):
		card.preview_state_changed.connect(state_callback)

func _begin_card_preview(card: BaseCard) -> void:
	if not _can_preview_card(card):
		return

	_preview_source_card = card
	_preview_hover_token += 1
	var hover_token = _preview_hover_token
	await get_tree().create_timer(CARD_PREVIEW_DELAY).timeout
	if hover_token == _preview_hover_token and _preview_source_card == card and _can_preview_card(card):
		_show_card_preview(card)

func _end_card_preview(card: BaseCard) -> void:
	if _preview_source_card == card:
		_preview_source_card = null
	_preview_hover_token += 1
	# Keep the latest inspected card visible so its text remains readable.

func _on_preview_card_gui_input(event: InputEvent, card: BaseCard) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _preview_source_card == card:
			_preview_source_card = null
		_preview_hover_token += 1
		_hide_card_preview()

func _can_preview_card(card: BaseCard) -> bool:
	if not card or not is_instance_valid(card):
		return false

	if card.is_dragging:
		return false
	if card.is_public_preview:
		return true

	# Every face-up battlefield card is public information. In network matches a
	# hand stays tied to the local player instead of changing with the active turn.
	if card.current_slot == null:
		var visible_hand_owner: int = (
			MatchSetup.human_player_id
			if MatchSetup.is_multiplayer_player()
			else (game_manager.active_player_id if game_manager else 0)
		)
		if visible_hand_owner != card.owner_id:
			return false

	return true

func _show_card_preview(source_card: BaseCard) -> void:
	_hide_card_preview()

	var card_type = source_card._get_card_type_key()
	if card_type.is_empty():
		return

	var preview = _instantiate_card_from_ref({
		"card_type": card_type,
		"card_id": source_card.card_id,
	}, source_card.owner_id)
	if not preview:
		return

	_preview_card = preview
	preview.is_public_preview = true
	preview.is_draggable = false
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.0)
	preview.z_index = 80
	if _preview_mount:
		_preview_mount.add_child(preview)
	else:
		add_child(preview)
	_preview_displayed_source_card = source_card
	_apply_preview_card_accent(source_card)
	_copy_current_card_state_to_preview(source_card, preview)
	_update_preview_title(source_card)
	_update_preview_details(source_card)
	_layout_preview_surface()
	if preview.has_method("_refresh_mouse_filter"):
		preview._refresh_mouse_filter()
	if _preview_hint_label:
		_preview_hint_label.visible = false

	var tween = create_tween()
	tween.tween_property(preview, "modulate:a", 1.0, 0.12)

func _apply_preview_card_accent(card: BaseCard) -> void:
	if not card:
		return
	var accent := UI.BRASS
	match card.rarity:
		BaseCard.Rarity.RARE:
			accent = UI.FROST
		BaseCard.Rarity.EPIC:
			accent = Color(0.56, 0.40, 0.72)
		BaseCard.Rarity.LEGENDARY:
			accent = UI.BRASS_BRIGHT
		_:
			accent = UI.BRASS
	if _preview_panel:
		_preview_panel.add_theme_stylebox_override("panel", UI.panel_style(accent, 9.0, 1.0))
	if _preview_details_header:
		_preview_details_header.add_theme_color_override("font_color", accent.lightened(0.16))

func _copy_current_card_state_to_preview(source_card: BaseCard, preview: BaseCard) -> void:
	if not source_card or not preview:
		return
	if not is_instance_valid(source_card) or not is_instance_valid(preview):
		return

	# The preview scene is selected from the database, then overwritten with
	# the live card state so applied upgrades and damage are represented.
	preview.card_name = source_card.card_name
	preview.card_description = source_card.card_description
	preview.energy_cost = source_card.energy_cost
	preview.rarity = source_card.rarity
	preview.card_art = source_card.card_art
	preview.effect_id = source_card.effect_id
	preview.effect_params = source_card.effect_params.duplicate(true)
	preview.traits.assign(source_card.traits)
	preview.trait_values = source_card.trait_values.duplicate(true)
	preview.trait_runtime = source_card.trait_runtime.duplicate(true)
	preview.status_effects = source_card.status_effects.duplicate(true)
	preview.attached_skill_name = source_card.attached_skill_name
	preview.level_paths = source_card.level_paths.duplicate(true)
	preview.experience = source_card.experience
	preview.card_level = source_card.card_level
	preview.selected_branch_id = source_card.selected_branch_id
	preview.selected_branch_name = source_card.selected_branch_name
	preview.experience_gained_this_turn = source_card.experience_gained_this_turn
	preview.has_moved_this_turn = source_card.has_moved_this_turn
	preview.combat_state = source_card.combat_state

	if source_card is HeroCard and preview is HeroCard:
		var source_hero := source_card as HeroCard
		var preview_hero := preview as HeroCard
		preview_hero.attack = source_hero.attack
		preview_hero.armor = source_hero.armor
		preview_hero.max_armor = source_hero.max_armor
		preview_hero._armor_initialized = true
		preview_hero.health = source_hero.health
		preview_hero.max_health = source_hero.max_health
	elif source_card is SettlementCard and preview is SettlementCard:
		var source_settlement := source_card as SettlementCard
		var preview_settlement := preview as SettlementCard
		preview_settlement.attack = source_settlement.attack
		preview_settlement.health = source_settlement.health
		preview_settlement.max_health = source_settlement.max_health
	elif source_card is UpgradeCard and preview is UpgradeCard:
		var source_upgrade := source_card as UpgradeCard
		var preview_upgrade := preview as UpgradeCard
		preview_upgrade.bonus_attack = source_upgrade.bonus_attack
		preview_upgrade.bonus_armor = source_upgrade.bonus_armor
		preview_upgrade.bonus_health = source_upgrade.bonus_health
		preview_upgrade.allowed_targets = source_upgrade.allowed_targets
		preview_upgrade.granted_traits.assign(source_upgrade.granted_traits)
		preview_upgrade.granted_status = source_upgrade.granted_status
		preview_upgrade.status_amount = source_upgrade.status_amount
		preview_upgrade.status_duration = source_upgrade.status_duration
	elif source_card is SpecialPowerCard and preview is SpecialPowerCard:
		var source_power := source_card as SpecialPowerCard
		var preview_power := preview as SpecialPowerCard
		preview_power.power_type = source_power.power_type
		preview_power.intensity = source_power.intensity
	preview._refresh_combat_state_visual()
	preview._refresh_effect_state_visual()

func _on_preview_source_state_changed(source_card: BaseCard) -> void:
	if _preview_displayed_source_card != source_card:
		return
	if not _preview_card or not is_instance_valid(_preview_card):
		return

	_copy_current_card_state_to_preview(source_card, _preview_card)
	_update_preview_title(source_card)
	_update_preview_details(source_card)

func _update_preview_title(source_card: BaseCard) -> void:
	# Kept as a hook for callers; the titleless inspector gives the card the
	# maximum possible reading area.
	pass

func _layout_preview_card() -> void:
	if not _preview_card or not is_instance_valid(_preview_card) or not _preview_mount:
		return

	var available_size = _preview_mount.size - Vector2(14.0, 10.0)
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return

	var preview_scale = clamp(
		min(available_size.x / HAND_CARD_BASE_SIZE.x, available_size.y / HAND_CARD_BASE_SIZE.y),
		0.58,
		CARD_PREVIEW_SCALE
	)
	var scaled_size = HAND_CARD_BASE_SIZE * preview_scale
	var visual_top_left = ( _preview_mount.size - scaled_size) * 0.5
	var pivot = HAND_CARD_BASE_SIZE * 0.5
	_preview_card.normal_scale = Vector2(preview_scale, preview_scale)
	_preview_card.scale = Vector2(preview_scale, preview_scale)
	_preview_card.position = visual_top_left - (pivot * (Vector2.ONE - _preview_card.scale))

func _layout_preview_surface() -> void:
	if not _preview_panel or not _preview_mount:
		return

	var has_preview := _preview_card != null and is_instance_valid(_preview_card)
	if _preview_details_panel:
		_preview_details_panel.visible = has_preview
	if has_preview and _preview_details_panel:
		var details_height := clampf(_preview_panel.size.y * 0.30, 112.0, 136.0)
		_preview_details_panel.anchor_left = 0.0
		_preview_details_panel.anchor_top = 0.0
		_preview_details_panel.anchor_right = 1.0
		_preview_details_panel.anchor_bottom = 0.0
		_preview_details_panel.offset_left = 8.0
		_preview_details_panel.offset_top = _preview_panel.size.y - details_height - 8.0
		_preview_details_panel.offset_right = -8.0
		_preview_details_panel.offset_bottom = _preview_panel.size.y - 8.0
		_preview_mount.offset_left = 8.0
		_preview_mount.offset_top = 8.0
		_preview_mount.offset_right = -8.0
		_preview_mount.offset_bottom = -(details_height + 16.0)
	else:
		_preview_mount.offset_left = 8.0
		_preview_mount.offset_top = 8.0
		_preview_mount.offset_right = -8.0
		_preview_mount.offset_bottom = -8.0

	_layout_preview_card()

func _update_preview_details(source_card: BaseCard) -> void:
	if not _preview_details_label or not source_card:
		return

	var card_type_key := source_card._get_card_type_key()
	var type_label := tr("MERKEZ") if source_card.is_headquarters() else tr(UI.get_card_type_label(card_type_key)).to_upper()
	var rarity_label := tr(UI.get_rarity_label(source_card._get_rarity_enum_key())).to_upper()
	var owner_tag := ""
	if source_card.owner_id in [1, 2]:
		owner_tag = tr("DOST") if source_card._is_friendly_to_local_viewer() else tr("RAKİP")
	if _preview_details_header:
		var header_parts: Array[String] = [type_label, rarity_label]
		if not owner_tag.is_empty():
			header_parts.append(owner_tag)
		_preview_details_header.text = "  •  ".join(header_parts)
		if source_card.owner_id in [1, 2] and not source_card._is_friendly_to_local_viewer():
			_preview_details_header.add_theme_color_override("font_color", UI.TEAM_OPPONENT.lightened(0.24))
		else:
			_preview_details_header.add_theme_color_override("font_color", UI.get_card_type_color(card_type_key).lightened(0.24))

	var lines: Array[String] = []
	var is_board_unit := (
		source_card.current_slot != null
		and not source_card.is_headquarters()
		and (source_card is HeroCard or source_card is SettlementCard)
	)
	if is_board_unit:
		var level_text := tr("LEVEL %d") % source_card.card_level
		if not source_card.selected_branch_name.is_empty():
			level_text += " • %s" % tr(source_card.selected_branch_name)
		var next_xp := source_card.get_next_level_experience()
		var experience_text := tr("TP %d/%d") % [source_card.experience, next_xp] if source_card.card_level < GameRules.MAX_CARD_LEVEL else tr("AZAMİ")
		var combat_text := tr("READY") if source_card.is_ready_for_combat() else tr("TÜKENDİ")
		var combat_color := "#7ee088" if source_card.is_ready_for_combat() else "#ef7868"
		lines.append("[b][color=#f2c45c]%s[/color][/b] [color=#c8bca4](%s)[/color]  •  [b][color=%s]%s[/color][/b]" % [
			level_text, experience_text, combat_color, combat_text
		])

	var desc := tr(source_card.card_description).strip_edges()
	if not desc.is_empty():
		lines.append("[color=#f4ead5]%s[/color]" % desc)

	if not source_card.attached_skill_name.is_empty():
		lines.append("[b][color=#5ad8d0]%s:[/color][/b] [color=#e8f6f5]%s[/color]" % [
			tr("BAĞLI BECERİ"), tr(source_card.attached_skill_name)
		])

	var trait_names: Array[String] = []
	for trait_id in source_card.traits:
		var display_name := CardKeywordGlossary.get_keyword_name(trait_id)
		trait_names.append(display_name if not display_name.is_empty() else trait_id.capitalize())
	if not trait_names.is_empty():
		lines.append("[color=#e5c88a][b]%s:[/b] %s[/color]" % [tr("NİTELİK"), " · ".join(trait_names)])

	var status_names: Array[String] = []
	for status_id in ["stunned", "poison", "protected"]:
		var status_amount := source_card.get_status_amount(status_id)
		if status_amount <= 0:
			continue
		var status_entry := CardKeywordGlossary.STATUS_DEFINITIONS.get(status_id, {}) as Dictionary
		var status_name := tr(str(status_entry.get("name", "")))
		status_names.append("%s %d" % [status_name if not status_name.is_empty() else status_id.capitalize(), status_amount])
	if not status_names.is_empty():
		lines.append("[color=#9dd6ff][b]%s:[/b] %s[/color]" % [tr("DURUM"), " · ".join(status_names)])

	_preview_details_label.text = "[font_size=12]%s[/font_size]" % "\n".join(lines)

func _hide_card_preview() -> void:
	if _preview_card and is_instance_valid(_preview_card):
		_preview_card.queue_free()
	_preview_card = null
	_preview_displayed_source_card = null
	if _preview_details_panel:
		_preview_details_panel.visible = false
	_layout_preview_surface()
	if _preview_hint_label:
		_preview_hint_label.visible = true
	if _preview_panel:
		_preview_panel.add_theme_stylebox_override("panel", _build_preview_style())
	if _preview_details_header:
		_preview_details_header.add_theme_color_override("font_color", UI.BRASS_BRIGHT)

func _refresh_hand_card_layouts() -> void:
	_layout_hand_cards(p1_hand)
	_layout_hand_cards(p2_hand)

func _get_locally_visible_hand_player_id() -> int:
	if MatchSetup.is_multiplayer_player():
		return MatchSetup.human_player_id if MatchSetup.human_player_id in GameRules.PLAYER_IDS else 0
	if MatchSetup.is_ai_match():
		return MatchSetup.human_player_id if MatchSetup.human_player_id in GameRules.PLAYER_IDS else 0
	if game_manager:
		return game_manager.active_player_id
	return MatchSetup.human_player_id if MatchSetup.human_player_id in GameRules.PLAYER_IDS else 1

func _get_hand_perspective_player_id() -> int:
	var player_id := _get_locally_visible_hand_player_id()
	return player_id if player_id in GameRules.PLAYER_IDS else 1


func _get_battlefield_perspective_player_id() -> int:
	if (
		(MatchSetup.is_multiplayer_player() or MatchSetup.is_ai_match())
		and MatchSetup.human_player_id in GameRules.PLAYER_IDS
	):
		return MatchSetup.human_player_id
	return 1


func _is_player_on_south(player_id: int) -> bool:
	return player_id == _get_battlefield_perspective_player_id()


func _get_player_zone_world_rect(player_id: int) -> Rect2:
	return _p1_zone_world_rect if player_id == 1 else _p2_zone_world_rect


func _get_team_accent(player_id: int) -> Color:
	return UI.TEAM_PLAYER if _is_player_on_south(player_id) else UI.TEAM_OPPONENT

func _refresh_hand_visibility() -> void:
	var visible_player_id := _get_hand_perspective_player_id()
	if p1_hand:
		p1_hand.visible = visible_player_id == 1
	if p2_hand:
		p2_hand.visible = visible_player_id == 2
	if _hand_dock_backdrop:
		_hand_dock_backdrop.visible = visible_player_id in GameRules.PLAYER_IDS
	if _opponent_hand_backdrop:
		_opponent_hand_backdrop.visible = false

func _layout_hand_cards(hand: Control) -> void:
	if not hand:
		return
	var cards: Array[Control] = []
	for child in hand.get_children():
		var card = child as Control
		if card:
			cards.append(card)
	if cards.is_empty():
		return

	for card_index in range(cards.size()):
		var card := cards[card_index]
		var placement := _get_hand_card_placement(hand, card_index, cards.size())
		var card_scale := Vector2.ONE * float(placement.get("scale", _hand_card_scale))
		var hand_rotation := float(placement.get("rotation", 0.0))
		var pivot := card.pivot_offset if card.pivot_offset != Vector2.ZERO else HAND_CARD_BASE_SIZE * 0.5
		var visual_top_left := placement.get("visual_top_left", Vector2.ZERO) as Vector2
		card.position = visual_top_left - (pivot * (Vector2.ONE - card_scale))
		card.rotation = hand_rotation
		card.set_meta("hand_rotation", hand_rotation)
		var card_z_index := (card_index + 1) * CardSlot.Z_INDEX_STRIDE
		card.set_meta("hand_z_index", card_z_index)
		card.z_index = card_z_index
		if card is BaseCard:
			var base_card := card as BaseCard
			base_card.normal_scale = card_scale
			var hover_multiplier = clamp(
				HAND_CARD_HOVER_TARGET_SCALE / max(card_scale.x, 0.01),
				1.30,
				1.90
			)
			base_card.hover_scale = Vector2(hover_multiplier, hover_multiplier)

func _calculate_hand_card_position(card: Control, visible_index: int) -> Vector2:
	var hand := _get_hand_for_player((card as BaseCard).owner_id) if card is BaseCard else card.get_parent() as Control
	if not hand:
		return Vector2.ZERO
	var projected_count := maxi(visible_index + 1, _get_hand_card_count(hand))
	if card.get_parent() != hand:
		projected_count = maxi(projected_count, _get_hand_card_count(hand) + 1)
	var placement := _get_hand_card_placement(hand, visible_index, projected_count)
	var card_scale := Vector2.ONE * float(placement.get("scale", _hand_card_scale))
	var visual_top_left := placement.get("visual_top_left", Vector2.ZERO) as Vector2
	var pivot := card.pivot_offset if card.pivot_offset != Vector2.ZERO else HAND_CARD_BASE_SIZE * 0.5
	return visual_top_left - (pivot * (Vector2.ONE - card_scale))

func _get_hand_card_placement(hand: Control, card_index: int, card_count: int) -> Dictionary:
	var owner_id := 1 if hand == p1_hand else 2
	var is_local_hand := owner_id == _get_hand_perspective_player_id()
	var card_scale := _hand_card_scale if is_local_hand else _opponent_hand_card_scale
	var visual_card_size := HAND_CARD_BASE_SIZE * card_scale

	var fan_gap := visual_card_size.x * HAND_CARD_OVERLAP_RATIO
	var fan_width := visual_card_size.x + (fan_gap * float(maxi(0, card_count - 1)))
	var center_index := float(card_count - 1) * 0.5
	var normalized_offset := (float(card_index) - center_index) / maxf(1.0, center_index)
	var fan_top := (
		maxf(10.0, hand.size.y - visual_card_size.y - 18.0)
		if is_local_hand
		else maxf(8.0, (hand.size.y - visual_card_size.y) * 0.5)
	)
	return {
		"scale": card_scale,
		"rotation": normalized_offset * (0.018 if is_local_hand else 0.045),
		"visual_top_left": Vector2(
			(hand.size.x - fan_width) * 0.5 + (float(card_index) * fan_gap),
			fan_top + (absf(normalized_offset) * (3.0 if is_local_hand else 4.0))
		),
	}

func _hand_card_scale_for_player(player_id: int) -> float:
	return _hand_card_scale if player_id == _get_hand_perspective_player_id() else _opponent_hand_card_scale

func _create_deck_ui_nodes() -> void:
	var deck_parent := _battlefield_world_objects if _battlefield_world_objects else self
	_deck_panels[1] = _create_deck_panel(1, deck_parent)
	_deck_panels[2] = _create_deck_panel(2, deck_parent)

func _create_deck_panel(player_id: int, parent: Control) -> Panel:
	var deck_panel := parent.get_node_or_null("P%dDeck" % player_id) as Panel
	if not deck_panel:
		deck_panel = Panel.new()
		deck_panel.name = "P%dDeck" % player_id
		parent.add_child(deck_panel)

	deck_panel.custom_minimum_size = DECK_PANEL_SIZE
	deck_panel.size = DECK_PANEL_SIZE
	deck_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_panel.add_theme_stylebox_override("panel", _build_deck_style(player_id))

	var icon := deck_panel.get_node_or_null("DeckBackIcon") as TextureRect
	if not icon:
		icon = TextureRect.new()
		icon.name = "DeckBackIcon"
		deck_panel.add_child(icon)
	icon.texture = CARD_BACK_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 7.0
	icon.offset_top = 7.0
	icon.offset_right = -7.0
	icon.offset_bottom = -7.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(0.88, 0.82, 0.68, 0.94)

	var label := deck_panel.get_node_or_null("DeckLabel") as Label
	if not label:
		label = Label.new()
		label.name = "DeckLabel"
		deck_panel.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 7.0
	label.offset_top = 86.0
	label.offset_right = -7.0
	label.offset_bottom = -7.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_font_override("font", UI.DISPLAY_FONT)
	label.add_theme_color_override("font_color", UI.PARCHMENT)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	label.clip_text = true
	_deck_labels[player_id] = label

	return deck_panel

func _build_deck_style(_player_id: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.021, 0.018, 0.98)
	style.set_border_width_all(2)
	style.border_color = Color(UI.BRASS_BRIGHT, 0.78)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
	style.shadow_size = 12
	style.shadow_offset = Vector2(5.0, -3.0)
	return style

func _prepare_player_decks() -> void:
	CardDatabase.load_all(true)
	var composition_rng := MatchSetup.create_rng(10)
	var fixed_composition := CardDatabase.build_fixed_deck_with_rng(composition_rng)
	var all_cards_composition := CardDatabase.get_playable_card_refs()
	_deck_rngs[1] = MatchSetup.create_rng(11)
	_deck_rngs[2] = MatchSetup.create_rng(12)
	for player_id in GameRules.PLAYER_IDS:
		var configured_deck := MatchSetup.get_player_deck(player_id)
		var resolved_deck := (
			all_cards_composition
			if MatchSetup.uses_all_cards()
			else configured_deck if _is_valid_configured_deck(configured_deck) else fixed_composition
		)
		_player_decks[player_id] = resolved_deck.duplicate(true)
		CardDatabase.shuffle_with_rng(_player_decks[player_id], _deck_rngs[player_id])


func _is_valid_configured_deck(cards: Array) -> bool:
	if cards.size() != GameRules.DECK_SIZE:
		return false
	var playable := {}
	for card_ref_variant in CardDatabase.get_playable_card_refs():
		if card_ref_variant is Dictionary:
			var card_ref := card_ref_variant as Dictionary
			playable["%s/%s" % [card_ref.get("card_type", ""), card_ref.get("card_id", "")]] = true
	var copies := {}
	for card_variant in cards:
		if not card_variant is Dictionary:
			return false
		var card := card_variant as Dictionary
		var key := "%s/%s" % [card.get("card_type", ""), card.get("card_id", "")]
		if not playable.has(key):
			return false
		copies[key] = int(copies.get(key, 0)) + 1
		if int(copies[key]) > GameRules.MAX_CARD_COPIES:
			return false
	return true

func _clear_starting_hand_cards() -> void:
	for hand in [p1_hand, p2_hand]:
		for child in hand.get_children():
			if child is BaseCard:
				hand.remove_child(child)
				child.queue_free()

func _deal_initial_hands() -> void:
	await get_tree().process_frame
	_apply_responsive_layout()
	var draw_delay := 0.0 if MatchSetup.fast_mode else INITIAL_DRAW_DELAY
	for _index in range(INITIAL_HAND_DRAW_COUNT):
		await _draw_card_to_hand(2, false, draw_delay)
		await _draw_card_to_hand(1, false, draw_delay)

	_is_dealing_initial_hands = false
	if game_manager:
		game_manager.begin_effect_selection(MatchSetup.get_first_player_id())
		# Existing headless rule/UI suites start at Mulligan. Resolve only local
		# presentation choices deterministically there; dedicated ENet servers
		# remain authoritative and wait for real player requests/timeouts.
		if DisplayServer.get_name() == "headless" and not MatchSetup.is_multiplayer_match():
			while game_manager.current_phase == GameManager.TurnPhase.EFFECT_SELECTION:
				var selecting_player: int = game_manager.active_player_id
				var offer: Array[String] = game_manager.get_effect_offer(selecting_player)
				var forced_choice := MatchSetup.get_forced_effect_card(selecting_player)
				var choice: String = (
					forced_choice
					if forced_choice in offer
					else EffectCardCatalog.choose_for_ai(offer, MatchSetup.get_player_deck(selecting_player))
					if MatchSetup.is_ai_player(selecting_player)
					else offer[0] if not offer.is_empty() else ""
				)
				if choice.is_empty() or not game_manager.submit_effect_selection(selecting_player, choice, true):
					break
	_update_deck_ui()
	_refresh_phase_ui()
	call_deferred("_maybe_show_first_match_tutorial")
	call_deferred("_maybe_show_scenario_briefing")
	if MatchSetup.is_multiplayer_server():
		var network_manager := _get_network_manager()
		if network_manager:
			network_manager.notify_battlefield_ready(self)

func _on_turn_draw_requested(player_id: int, card_count: int) -> void:
	var total_draw_count: int = get_turn_start_draw_count(player_id, card_count)
	var base_request: int = maxi(0, card_count)
	var drawn_total: int = 0
	var fatigue_applied: bool = false
	for draw_index in range(total_draw_count):
		var drew_card := await _draw_card_to_hand(player_id, false)
		if drew_card:
			drawn_total += 1
		else:
			# Catch-up hand refill must never multiply Fatigue damage on an
			# empty deck: apply at most one Fatigue tick per turn start.
			if not fatigue_applied and draw_index < base_request:
				fatigue_applied = true
				_apply_fatigue_damage(player_id)
			break
	var catch_up_drawn: int = maxi(0, drawn_total - base_request)
	if catch_up_drawn > 0 and game_manager and game_manager.is_game_active and not MatchSetup.fast_mode:
		show_toast(
			tr("Your hand was filled to %d cards: %d reinforcement cards drawn.") % [
				GameRules.MINIMUM_TURN_START_HAND,
				catch_up_drawn,
			],
			Color(0.35, 0.82, 1.0),
			"TAKVİYE ÇEKİŞİ"
		)
	_refresh_phase_ui()

func _on_effect_draw_requested(player_id: int, card_count: int, source: BaseCard) -> void:
	var normalized_count := maxi(0, card_count)
	if normalized_count == 0 or player_id not in GameRules.PLAYER_IDS:
		return
	_pending_effect_draws.append({
		"player_id": player_id,
		"card_count": normalized_count,
		"source_name": source.card_name if source and is_instance_valid(source) else "Kart etkisi",
	})
	if _effect_draw_queue_running:
		return
	_effect_draw_queue_running = true
	call_deferred("_process_effect_draw_queue")

func _process_effect_draw_queue() -> void:
	while not _pending_effect_draws.is_empty() and game_manager:
		var request := _pending_effect_draws.pop_front() as Dictionary
		var player_id := int(request.get("player_id", 0))
		var requested_count := int(request.get("card_count", 0))
		var drawn_count := 0
		for _draw_index in range(requested_count):
			if await _draw_card_to_hand(player_id, true, 0.08):
				drawn_count += 1
			else:
				_apply_fatigue_damage(player_id)
				if not game_manager.is_game_active:
					break
		game_manager.effect_draw_completed.emit(player_id, requested_count, drawn_count)
		if drawn_count > 0 and not MatchSetup.fast_mode and not MatchSetup.is_multiplayer_client():
			show_toast(
				tr("%s: %d cards drawn.") % [tr(str(request.get("source_name", "Card effect"))), drawn_count],
				Color(0.72, 0.56, 1.0),
				"ETKİ ÇEKİŞİ"
			)
	_effect_draw_queue_running = false
	_update_deck_ui()
	_refresh_phase_ui()

func get_turn_start_draw_count(player_id: int, requested_count: int) -> int:
	var normalized_request: int = maxi(0, requested_count)
	# Tests, replays and special modes deliberately use zero to suppress the
	# whole draw step; catch-up must respect that explicit override.
	if normalized_request == 0:
		return 0
	var hand := _get_hand_for_player(player_id)
	var current_count: int = _get_hand_card_count(hand) if hand else 0
	var catch_up: int = maxi(0, GameRules.MINIMUM_TURN_START_HAND - (current_count + normalized_request))
	return normalized_request + catch_up

func _apply_fatigue_damage(player_id: int) -> void:
	if not game_manager:
		return
	var result: Dictionary = game_manager.resolve_failed_draw(player_id)
	if not bool(result.get("success", false)):
		return
	var hq := (p1_hq if player_id == 1 else p2_hq) as SettlementCard
	var dmg: int = int(result.get("damage", 0))
	if hq:
		hq.health = int(result.get("remaining_health", 0))
		if not MatchSetup.fast_mode:
			hq.play_feedback_animation("damage")
			_spawn_floating_feedback(tr("-%d YORGUNLUK") % dmg, hq, UI.BLOOD)
	if not MatchSetup.fast_mode:
		_play_board_impact_shake("damage", 1.1)
		show_toast(
			tr("Deck empty: Player %d's Headquarters took %d Fatigue Damage.") % [
				player_id,
				dmg,
			],
			UI.BLOOD,
			tr("YORGUNLUK")
		)
	_update_hq_labels()

func _draw_card_to_hand(player_id: int, _count_as_manual_draw: bool, post_delay: float = 0.0) -> bool:
	var deck: Array = _player_decks.get(player_id, [])
	if deck.is_empty():
		_update_deck_ui()
		return false

	var hand = _get_hand_for_player(player_id)
	if not hand:
		return false

	var card_ref = deck.pop_front()
	_player_decks[player_id] = deck
	var card = _instantiate_card_from_ref(card_ref, player_id)
	if not card:
		deck.push_front(card_ref)
		_player_decks[player_id] = deck
		return false

	card.set_meta("deck_ref", card_ref.duplicate(true))
	_register_preview_card(card)
	if _feedback_audio:
		_feedback_audio.play_event("draw")
	card.is_draggable = false
	var target_hand_scale := _hand_card_scale_for_player(player_id)
	card.normal_scale = Vector2(target_hand_scale, target_hand_scale)
	card.scale = Vector2(target_hand_scale, target_hand_scale) * 0.82
	card.rotation = -0.10 if player_id == 1 else 0.10
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if MatchSetup.fast_mode:
		hand.add_child(card)
		card.position = _calculate_hand_card_position(card, hand.get_child_count() - 1)
		card.scale = Vector2(target_hand_scale, target_hand_scale)
		card.rotation = 0.0
		card.modulate = Color.WHITE
		card.is_draggable = true
		if card.has_method("_refresh_mouse_filter"):
			card._refresh_mouse_filter()
		_update_deck_ui()
		return true
	card.set_meta(BaseCard.TRANSIENT_Z_INDEX_META, DRAW_ANIMATION_Z_INDEX)
	add_child(card)

	var target_index = hand.get_child_count()
	var target_local_position = _calculate_hand_card_position(card, target_index)
	var target_global_position = hand.global_position + target_local_position
	var start_global_position = _get_deck_draw_origin(player_id, card)
	card.global_position = start_global_position
	# The draw animation is temporarily parented to Battlefield. Its Z index
	# therefore needs to clear the root-level hand dock, not only the board's
	# per-slot bands, or the card slips behind the bottom bar while being dealt.
	card.z_index = DRAW_ANIMATION_Z_INDEX

	_is_draw_animation_running = true
	_update_deck_ui()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "global_position", target_global_position, 0.30)
	tween.tween_property(card, "scale", Vector2(target_hand_scale, target_hand_scale), 0.30)
	tween.tween_property(card, "rotation", 0.0, 0.24)
	tween.tween_property(card, "modulate:a", 1.0, 0.16)
	await tween.finished

	card.reparent(hand, true)
	card.remove_meta(BaseCard.TRANSIENT_Z_INDEX_META)
	card.position = target_local_position
	card.z_index = 0
	card.is_draggable = true
	if card.has_method("_refresh_mouse_filter"):
		card._refresh_mouse_filter()
	_apply_responsive_layout()
	_is_draw_animation_running = false
	_update_deck_ui()

	if post_delay > 0.0:
		await get_tree().create_timer(post_delay).timeout

	return true

func _instantiate_card_from_ref(card_ref: Dictionary, player_id: int) -> BaseCard:
	var card_type = str(card_ref.get("card_type", ""))
	var card_id = str(card_ref.get("card_id", ""))
	if card_type.is_empty() or card_id.is_empty():
		return null

	var card_data = CardDatabase.get_card(card_type, card_id)
	if card_data.is_empty():
		return null

	var rarity_key = str(card_data.get("rarity", "COMMON")).to_upper()
	var type_templates: Dictionary = CARD_TEMPLATE_SCENES.get(card_type, {})
	var template_scene = type_templates.get(rarity_key, type_templates.get("COMMON"))
	if not template_scene is PackedScene:
		push_error("Card template scene not found for %s/%s" % [card_type, rarity_key])
		return null

	var card = template_scene.instantiate() as BaseCard
	if not card:
		push_error("Card template does not inherit BaseCard: %s/%s" % [card_type, card_id])
		return null

	card.name = "P%d_%s" % [player_id, card_id]
	card.card_id = card_id
	card.owner_id = player_id
	card.set_meta(NETWORK_CARD_ID_META, _allocate_network_card_id(player_id))
	card.size = HAND_CARD_BASE_SIZE
	card.pivot_offset = HAND_CARD_BASE_SIZE * 0.5
	return card

func resurrect_hero_from_record(
	record: Dictionary,
	target_slot: CardSlot,
	owner_id: int
) -> HeroCard:
	if (
		record.is_empty()
		or not target_slot
		or not is_instance_valid(target_slot)
		or target_slot.is_occupied
		or target_slot.owner_id != owner_id
		or target_slot.position_type != CardSlot.PositionType.BACK
	):
		return null
	var card := _instantiate_card_from_ref({
		"card_type": "heroes",
		"card_id": str(record.get("card_id", "")),
	}, owner_id) as HeroCard
	if not card or not target_slot.can_accept_card(card):
		if card:
			card.queue_free()
		return null

	target_slot.add_child(card)
	card.current_slot = target_slot
	if not target_slot.is_occupied:
		target_slot.accept_card(card)
	card.position = (target_slot.size - card.size) * 0.5
	card.rotation = 0.0
	card.modulate = Color.WHITE
	card.reset_progression()
	card.health = 1
	card.set_combat_state(BaseCard.CombatState.EXHAUSTED)
	card.refresh_runtime_badges()
	card._refresh_mouse_filter()
	_register_preview_card(card)
	_refresh_lane_visuals()
	return card

func _get_deck_draw_origin(player_id: int, card: Control) -> Vector2:
	var deck_panel = _deck_panels.get(player_id) as Control
	if not deck_panel:
		return _get_hand_for_player(player_id).global_position

	var deck_rect = deck_panel.get_global_rect()
	return deck_rect.position + ((deck_rect.size - card.size) * 0.5)

func _get_hand_for_player(player_id: int) -> Control:
	return p1_hand if player_id == 1 else p2_hand

func _update_deck_ui() -> void:
	var perspective_player_id := _get_hand_perspective_player_id()
	for player_id in _deck_panels:
		var deck_panel = _deck_panels[player_id] as Control
		var label = _deck_labels.get(player_id) as Label
		if not deck_panel or not label:
			continue

		var deck: Array = _player_decks.get(player_id, [])
		label.text = "%s\n%s" % [
			tr("DESTEN") if player_id == perspective_player_id else tr("RAKİP"),
			tr("%d KART") % deck.size(),
		]
		deck_panel.modulate = Color.WHITE
		deck_panel.visible = true


func build_active_match_snapshot(last_save_reason: String = "otomatik") -> Dictionary:
	if not game_manager:
		return {}
	var hands := {}
	var deck_order := {}
	var deck_rng := {}
	for player_id in GameRules.PLAYER_IDS:
		var hand_rows: Array = []
		for card in get_hand_cards(player_id):
			hand_rows.append(_serialize_active_card(card))
		hands[player_id] = hand_rows
		deck_order[player_id] = (_player_decks.get(player_id, []) as Array).duplicate(true)
		var rng := _deck_rngs.get(player_id) as RandomNumberGenerator
		deck_rng[player_id] = (
			{"seed": str(rng.seed), "state": str(rng.state)}
			if rng else {}
		)

	var board_rows: Array = []
	for slot in get_board_slots():
		if not slot.is_occupied or not slot.occupied_card is BaseCard:
			continue
		var row := _serialize_active_card(slot.occupied_card as BaseCard)
		row["slot_id"] = _get_slot_network_id(slot)
		board_rows.append(row)
	var selected_ids: Array[String] = []
	for card in _phase_selected_cards:
		if card and is_instance_valid(card):
			selected_ids.append(_get_card_network_id(card))
	return {
		"match_id": MatchSetup.match_id,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0.0")),
		"seed": MatchSetup.match_seed,
		"match_mode": int(MatchSetup.match_mode),
		"match_name": MatchSetup.match_name,
		"ruleset": int(MatchSetup.ruleset),
		"card_pool_mode": int(MatchSetup.card_pool_mode),
		"turn_duration_seconds": MatchSetup.turn_duration_seconds,
		"auto_attack_allowed": MatchSetup.auto_attack_allowed,
		"human_player_id": MatchSetup.human_player_id,
		"ai_difficulties": MatchSetup.ai_difficulties.duplicate(true),
		"configured_player_decks": MatchSetup.player_decks.duplicate(true),
		"configured_player_deck_names": MatchSetup.player_deck_names.duplicate(true),
		"scenario_context": MatchSetup.get_scenario_context(),
		"last_save_reason": last_save_reason,
		"save_slot_id": MatchSetup.save_slot_id,
		"save_slot_name": MatchSetup.save_slot_name,
		"manager": game_manager.build_state_snapshot(),
		"zones": {
			"deck_order": deck_order,
			"hands": hands,
			"graveyards": _graveyards.duplicate(true),
			"board_cards": board_rows,
			"hq_cards": {
				1: _serialize_active_card(p1_hq as BaseCard),
				2: _serialize_active_card(p2_hq as BaseCard),
			},
			"phase_selected_card_ids": selected_ids,
			"discard_required": _discard_required,
			"next_network_card_serial": _next_network_card_serial,
		},
		"rng": {
			"deck": deck_rng,
			"ai": _ai_controller.get_rng_snapshot() if _ai_controller else {},
		},
		"effect_cards": {
			"offers": game_manager.effect_offers.duplicate(true),
			"selected": game_manager.selected_effect_cards.duplicate(true),
			"trigger_state": game_manager.effect_trigger_state.duplicate(true),
			"trigger_totals": game_manager.effect_trigger_totals.duplicate(true),
		},
		"telemetry_summary": _match_telemetry.get_summary() if _match_telemetry else {},
	}


func restore_active_match_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty() or not game_manager:
		return {"success": false, "error": "Yüklenecek aktif maç snapshot'ı yok."}
	_clear_deployment_selection()
	var identity_validation := _validate_active_snapshot_identities(snapshot)
	if not bool(identity_validation.get("success", false)):
		show_toast(str(identity_validation.get("error", "Aktif maç kaydı bozuk.")), Color(0.95, 0.38, 0.24), "KAYIT YÜKLENEMEDİ")
		return identity_validation
	_restoring_active_match = true
	CardDatabase.load_all()
	MatchSetup.match_id = str(snapshot.get("match_id", MatchSetup.match_id))
	MatchSetup.match_seed = int(snapshot.get("seed", MatchSetup.match_seed))
	MatchSetup.match_name = str(snapshot.get("match_name", MatchSetup.match_name))
	MatchSetup.set_ruleset(int(snapshot.get("ruleset", MatchSetup.ruleset)))
	MatchSetup.set_card_pool_mode(int(snapshot.get("card_pool_mode", MatchSetup.CardPoolMode.DECK)))
	if top_hud:
		top_hud.set_ruleset(MatchSetup.ruleset)
	MatchSetup.set_turn_duration_seconds(float(snapshot.get("turn_duration_seconds", MatchSetup.turn_duration_seconds)))
	MatchSetup.set_auto_attack_allowed(bool(snapshot.get("auto_attack_allowed", true)))
	var scenario_variant: Variant = snapshot.get("scenario_context", {})
	if scenario_variant is Dictionary:
		MatchSetup.set_scenario_context(scenario_variant as Dictionary)
	else:
		MatchSetup.clear_scenario_context()
	if _auto_attack_panel:
		_auto_attack_panel.visible = MatchSetup.auto_attack_allowed
	if _auto_attack_checkbox:
		_auto_attack_checkbox.disabled = not MatchSetup.auto_attack_allowed
		if not MatchSetup.auto_attack_allowed:
			_auto_attack_checkbox.set_pressed_no_signal(false)
			_auto_attack_enabled = false
	_clear_network_dynamic_cards()

	var manager_variant: Variant = snapshot.get("manager", {})
	if not manager_variant is Dictionary:
		_restoring_active_match = false
		return {"success": false, "error": "GameManager kayıt bölümü geçersiz."}
	var manager_result: Dictionary = game_manager.apply_state_snapshot(manager_variant as Dictionary)
	if not bool(manager_result.get("success", false)):
		_restoring_active_match = false
		return manager_result

	var zones_variant: Variant = snapshot.get("zones", {})
	var zones: Dictionary = zones_variant as Dictionary if zones_variant is Dictionary else {}
	var deck_order_variant: Variant = zones.get("deck_order", {})
	if deck_order_variant is Dictionary:
		for player_id in GameRules.PLAYER_IDS:
			var deck_variant: Variant = _dictionary_player_value(deck_order_variant as Dictionary, player_id, [])
			_player_decks[player_id] = (deck_variant as Array).duplicate(true) if deck_variant is Array else []

	_deck_rngs.clear()
	var rng_variant: Variant = snapshot.get("rng", {})
	var rng_data: Dictionary = rng_variant as Dictionary if rng_variant is Dictionary else {}
	var deck_rng_variant: Variant = rng_data.get("deck", {})
	for player_id in GameRules.PLAYER_IDS:
		var rng := RandomNumberGenerator.new()
		var player_rng_variant: Variant = (
			_dictionary_player_value(deck_rng_variant as Dictionary, player_id, {})
			if deck_rng_variant is Dictionary else {}
		)
		var player_rng: Dictionary = player_rng_variant as Dictionary if player_rng_variant is Dictionary else {}
		rng.seed = str(player_rng.get("seed", MatchSetup.match_seed + (player_id * 104729))).to_int()
		rng.state = str(player_rng.get("state", rng.state)).to_int()
		_deck_rngs[player_id] = rng

	var hands_variant: Variant = zones.get("hands", {})
	if hands_variant is Dictionary:
		for player_id in GameRules.PLAYER_IDS:
			var rows_variant: Variant = _dictionary_player_value(hands_variant as Dictionary, player_id, [])
			if not rows_variant is Array:
				continue
			var hand := _get_hand_for_player(player_id)
			for row_variant in rows_variant as Array:
				if row_variant is Dictionary:
					_restore_card_to_hand(row_variant as Dictionary, player_id, hand)

	var board_variant: Variant = zones.get("board_cards", [])
	if board_variant is Array:
		for row_variant in board_variant as Array:
			if not row_variant is Dictionary:
				continue
			var row := row_variant as Dictionary
			var slot := _find_slot_by_network_id(str(row.get("slot_id", "")))
			if not slot:
				continue
			var card := _instantiate_card_from_ref({
				"card_type": str(row.get("card_type", "")),
				"card_id": str(row.get("card_id", "")),
			}, int(row.get("owner_id", slot.owner_id)))
			if not card:
				continue
			card.set_meta(NETWORK_CARD_ID_META, str(row.get("network_id", "")))
			card.is_draggable = false
			slot.add_child(card)
			_apply_network_card_state(card, row)
			card.position = (slot.size - card.size) * 0.5
			_register_preview_card(card)

	var hq_variant: Variant = zones.get("hq_cards", {})
	if hq_variant is Dictionary:
		for player_id in GameRules.PLAYER_IDS:
			var hq_row_variant: Variant = _dictionary_player_value(hq_variant as Dictionary, player_id, {})
			var hq := (p1_hq if player_id == 1 else p2_hq) as BaseCard
			if hq and hq_row_variant is Dictionary:
				_apply_network_card_state(hq, hq_row_variant as Dictionary)

	var graveyard_variant: Variant = zones.get("graveyards", {})
	_graveyards = {1: [], 2: []}
	if graveyard_variant is Dictionary:
		for player_id in GameRules.PLAYER_IDS:
			var rows_variant: Variant = _dictionary_player_value(graveyard_variant as Dictionary, player_id, [])
			_graveyards[player_id] = (rows_variant as Array).duplicate(true) if rows_variant is Array else []
	_discard_required = maxi(0, int(zones.get("discard_required", 0)))
	_next_network_card_serial = maxi(1, int(zones.get("next_network_card_serial", 1)))

	var selected_ids_variant: Variant = zones.get("phase_selected_card_ids", [])
	if selected_ids_variant is Array:
		for network_id_variant in selected_ids_variant as Array:
			var selected_card := _find_card_by_network_id(str(network_id_variant))
			if selected_card:
				_phase_selected_cards.append(selected_card)
				_set_phase_card_selected(selected_card, true)
	if _ai_controller:
		var ai_rng_variant: Variant = rng_data.get("ai", {})
		if ai_rng_variant is Dictionary:
			_ai_controller.apply_rng_snapshot(ai_rng_variant as Dictionary)

	_is_dealing_initial_hands = false
	_is_draw_animation_running = false
	_is_confirming_selection = false
	_pending_effect_draws.clear()
	_effect_draw_queue_running = false
	_restoring_active_match = false
	_on_turn_changed(game_manager.active_player_id)
	_on_phase_changed(game_manager.current_phase)
	for player_id in GameRules.PLAYER_IDS:
		_on_energy_changed(
			player_id,
			int(game_manager.player_current_energy.get(player_id, 0)),
			int(game_manager.player_max_energy.get(player_id, GameRules.STARTING_ENERGY)),
			int(game_manager.player_temporary_energy.get(player_id, 0))
		)
		_on_hq_health_changed(
			player_id,
			int(game_manager.player_hq_health.get(player_id, GameRules.HEADQUARTERS_HEALTH)),
			GameRules.HEADQUARTERS_HEALTH
		)
		_on_dominion_score_changed(
			player_id,
			int(game_manager.player_dominion_score.get(player_id, 0)),
			GameRules.DOMINION_SCORE_TARGET
		)
	_on_turn_time_changed(
		game_manager.active_player_id,
		game_manager.turn_time_remaining_seconds,
		game_manager.turn_duration_seconds,
		bool(game_manager.get("_turn_timer_running"))
	)
	_refresh_effect_selection_from_state(false)
	_refresh_effect_card_panel()
	_refresh_hand_visibility()
	_refresh_hand_card_layouts()
	_refresh_lane_visuals()
	_update_deck_ui()
	_refresh_phase_ui()
	_apply_responsive_layout()
	return {"success": true}


func _serialize_active_card(card: BaseCard) -> Dictionary:
	var row := _serialize_network_card(card)
	var deck_ref_variant: Variant = card.get_meta("deck_ref", {}) if card else {}
	if deck_ref_variant is Dictionary:
		row["deck_ref"] = (deck_ref_variant as Dictionary).duplicate(true)
	return row


func _restore_card_to_hand(row: Dictionary, player_id: int, hand: Control) -> BaseCard:
	var card := _instantiate_card_from_ref({
		"card_type": str(row.get("card_type", "")),
		"card_id": str(row.get("card_id", "")),
	}, player_id)
	if not card:
		return null
	card.set_meta(NETWORK_CARD_ID_META, str(row.get("network_id", "")))
	var deck_ref_variant: Variant = row.get("deck_ref", {})
	card.set_meta("deck_ref", (
		(deck_ref_variant as Dictionary).duplicate(true)
		if deck_ref_variant is Dictionary
		else {"card_type": str(row.get("card_type", "")), "card_id": str(row.get("card_id", ""))}
	))
	hand.add_child(card)
	_apply_network_card_state(card, row)
	card.is_draggable = true
	card._refresh_mouse_filter()
	_register_preview_card(card)
	return card


func _validate_active_snapshot_identities(snapshot: Dictionary) -> Dictionary:
	var zones_variant: Variant = snapshot.get("zones", {})
	if not zones_variant is Dictionary:
		return {"success": false, "error": "Kayıt bölgeleri geçersiz."}
	var zones := zones_variant as Dictionary
	var seen := {}
	var physical_count := 0
	var owner_counts := {1: 0, 2: 0}
	var hands_variant: Variant = zones.get("hands", {})
	if not hands_variant is Dictionary:
		return {"success": false, "error": "Kayıt el bölgeleri geçersiz."}
	for player_id in GameRules.PLAYER_IDS:
		var rows_variant: Variant = _dictionary_player_value(hands_variant as Dictionary, player_id, null)
		if not rows_variant is Array:
			return {"success": false, "error": "Kayıt oyuncu eli geçersiz."}
		for row_variant in rows_variant as Array:
			if not row_variant is Dictionary or int((row_variant as Dictionary).get("owner_id", 0)) != player_id:
				return {"success": false, "error": "Kayıt el kartı sahipliği geçersiz."}
			var identity_result := _register_snapshot_identity(row_variant as Dictionary, seen)
			if not bool(identity_result.get("success", false)):
				return identity_result
			physical_count += 1
			owner_counts[player_id] = int(owner_counts[player_id]) + 1
	var board_variant: Variant = zones.get("board_cards", [])
	if not board_variant is Array:
		return {"success": false, "error": "Kayıt savaş alanı geçersiz."}
	for row_variant in board_variant as Array:
		if not row_variant is Dictionary:
			return {"success": false, "error": "Kayıt savaş alanı kartı geçersiz."}
		var row := row_variant as Dictionary
		var owner_id := int(row.get("owner_id", 0))
		if owner_id not in GameRules.PLAYER_IDS or str(row.get("slot_id", "")).is_empty():
			return {"success": false, "error": "Kayıt savaş alanı kartı sahipliği veya yuvası geçersiz."}
		var identity_result := _register_snapshot_identity(row, seen)
		if not bool(identity_result.get("success", false)):
			return identity_result
		physical_count += 1
		owner_counts[owner_id] = int(owner_counts[owner_id]) + 1

	var graveyards_variant: Variant = zones.get("graveyards", {})
	if not graveyards_variant is Dictionary:
		return {"success": false, "error": "Kayıt mezarlık bölgeleri geçersiz."}
	for player_id in GameRules.PLAYER_IDS:
		var graveyard_rows_variant: Variant = _dictionary_player_value(graveyards_variant as Dictionary, player_id, null)
		if not graveyard_rows_variant is Array:
			return {"success": false, "error": "Kayıt oyuncu mezarlığı geçersiz."}
		for row_variant in graveyard_rows_variant as Array:
			if not row_variant is Dictionary or int((row_variant as Dictionary).get("owner_id", 0)) != player_id:
				return {"success": false, "error": "Kayıt mezarlık kartı sahipliği geçersiz."}
			var identity_result := _register_snapshot_identity(row_variant as Dictionary, seen)
			if not bool(identity_result.get("success", false)):
				return identity_result
			physical_count += 1
			owner_counts[player_id] = int(owner_counts[player_id]) + 1

	if physical_count > GameRules.DECK_SIZE * GameRules.PLAYER_IDS.size():
		return {"success": false, "error": "Kayıtta fiziksel kart sayısı geçersiz."}
	for player_id in GameRules.PLAYER_IDS:
		if int(owner_counts[player_id]) > GameRules.DECK_SIZE:
			return {"success": false, "error": "Kayıtta oyuncu kart sayısı deste sınırını aşıyor."}
	return {"success": true}


func _register_snapshot_identity(row: Dictionary, seen: Dictionary) -> Dictionary:
	var network_id := str(row.get("network_id", ""))
	if network_id.is_empty() or seen.has(network_id):
		return {"success": false, "error": "Kayıtta yinelenen veya boş kart kimliği var."}
	if (
		str(row.get("card_id", "")).is_empty()
		or str(row.get("card_type", "")).is_empty()
		or int(row.get("owner_id", 0)) not in GameRules.PLAYER_IDS
	):
		return {"success": false, "error": "Kayıtta kart kimliği veya sahipliği geçersiz."}
	seen[network_id] = true
	return {"success": true}


func _connect_active_match_autosave() -> void:
	if not _can_persist_active_match() or not game_manager:
		return
	game_manager.turn_changed.connect(func(_player_id: int): _request_active_match_autosave("tur_geçişi"))
	game_manager.phase_changed.connect(func(_phase: GameManager.TurnPhase): _request_active_match_autosave("faz_geçişi"))
	game_manager.energy_changed.connect(func(_player_id: int, _current: int, _maximum: int, _temporary: int): _request_active_match_autosave("enerji_hamlesi"))
	game_manager.card_played.connect(func(_card: BaseCard, _target: BaseCard): _request_active_match_autosave("kart_hamlesi"))
	game_manager.card_moved.connect(func(_card: BaseCard, _from: CardSlot, _to: CardSlot): _request_active_match_autosave("hareket"))
	game_manager.effect_resolved.connect(func(_id: String, _source: BaseCard, _target: BaseCard, _result: Dictionary): _request_active_match_autosave("etki"))
	game_manager.card_destroyed.connect(func(_card: BaseCard, _source: BaseCard): _request_active_match_autosave("kart_yıkımı"))
	game_manager.card_leveled_up.connect(func(_card: BaseCard, _level: int, _branch: String): _request_active_match_autosave("geliştirme"))
	game_manager.effect_card_selected.connect(func(_player_id: int, _card_id: String, _automatic: bool): _request_active_match_autosave("etki_kartı_seçimi"))
	game_manager.mulligan_player_changed.connect(func(_player_id: int): _request_active_match_autosave("mulligan"))


func _request_active_match_autosave(reason: String) -> void:
	if (
		_autosave_pending
		or _restoring_active_match
		or _is_dealing_initial_hands
		or not _can_persist_active_match()
		or not game_manager
		or not game_manager.is_game_active
	):
		return
	_autosave_pending = true
	call_deferred("_perform_active_match_autosave", reason)


func _perform_active_match_autosave(reason: String) -> void:
	_autosave_pending = false
	_save_active_match(reason, false)


func _save_active_match(reason: String, show_feedback: bool) -> Dictionary:
	if (
		not _can_persist_active_match()
		or _restoring_active_match
		or _is_dealing_initial_hands
		or not game_manager
		or not game_manager.is_game_active
	):
		return {"success": false, "skipped": true}
	var result := _active_match_repository.save_snapshot(build_active_match_snapshot(reason))
	if show_feedback:
		show_toast(
			"Oyun güvenli biçimde kaydedildi." if bool(result.get("success", false)) else str(result.get("error", "Oyun kaydedilemedi.")),
			Color(0.38, 0.90, 0.62) if bool(result.get("success", false)) else Color(0.95, 0.38, 0.24),
			"OYUNU KAYDET"
		)
	return result


func _can_persist_active_match() -> bool:
	return MatchSetup.match_mode in [MatchSetup.MatchMode.LOCAL, MatchSetup.MatchMode.AI]


## Dedicated-server command boundary. Clients can only identify an intended
## action; every legality, ownership, phase and Energy check runs here.
func execute_network_action(player_id: int, action: String, payload: Dictionary) -> Dictionary:
	await get_tree().process_frame
	if not MatchSetup.is_multiplayer_server() or not game_manager:
		return {"success": false, "error": "Bu süreç authoritative sunucu değil."}
	if player_id not in GameRules.PLAYER_IDS or action.length() > 32:
		return {"success": false, "error": "Geçersiz oyuncu veya hamle."}
	if not game_manager.is_game_active:
		return {"success": false, "error": "Maç artık aktif değil."}

	match action:
		"effect_choice":
			if game_manager.current_phase != GameManager.TurnPhase.EFFECT_SELECTION:
				return {"success": false, "error": "Etki Kartı seçim aşaması kapalı."}
			var effect_card_id := str(payload.get("card_id", "")).strip_edges()
			var choice_success: bool = game_manager.submit_effect_selection(player_id, effect_card_id, false)
			return {
				"success": choice_success,
				"message": "Etki Kartı seçimin gizli olarak kaydedildi." if choice_success else "Etki Kartı seçimi geçersiz.",
			}
		"load", "snapshot", "restore", "set_stat", "set_stats":
			return {"success": false, "error": "İstemci otoriter maç durumu gönderemez."}
		"mulligan":
			var mulligan_cards := _resolve_network_card_list(payload.get("card_ids", []), player_id, true)
			if not bool(mulligan_cards.get("success", false)):
				return mulligan_cards
			var mulligan_success: bool = await resolve_mulligan_for_player(
				player_id,
				mulligan_cards.get("cards", []) as Array[BaseCard]
			)
			return {
				"success": mulligan_success,
				"message": "Başlangıç eli onaylandı." if mulligan_success else "Başlangıç eli onaylanamadı.",
			}
		"advance_phase":
			if game_manager.active_player_id != player_id:
				return {"success": false, "error": "Sıra sende değil."}
			var previous_phase: int = int(game_manager.current_phase)
			var advanced: bool = game_manager.advance_phase(player_id)
			return {
				"success": advanced,
				"message": "Aşama ilerletildi." if advanced else "Bu aşama ilerletilemedi.",
				"previous_phase": previous_phase,
			}
		"preparation_token":
			var token_used: bool = game_manager.use_preparation_token(player_id)
			return {
				"success": token_used,
				"message": "Hazırlık jetonu kullanıldı: +1 geçici Enerji." if token_used else "Hazırlık jetonu kullanılamadı.",
			}
		"tactical_supply":
			var hand_node = _get_hand_for_player(player_id)
			var hand_count: int = _get_hand_card_count(hand_node) if hand_node else 0
			var supply_result: Dictionary = game_manager.use_tactical_supply(player_id, hand_count)
			return {
				"success": bool(supply_result.get("success", false)),
				"message": "İkmal çekişi kullanıldı: +1 kart." if bool(supply_result.get("success", false)) else str(supply_result.get("error", "İkmal çekişi kullanılamadı.")),
			}
		"discard":
			var discard_cards := _resolve_network_card_list(payload.get("card_ids", []), player_id, true)
			if not bool(discard_cards.get("success", false)):
				return discard_cards
			var discard_success := resolve_end_phase_for_player(
				player_id,
				discard_cards.get("cards", []) as Array[BaseCard]
			)
			return {
				"success": discard_success,
				"message": "Tur sonu tamamlandı." if discard_success else "Atılacak kartlar geçersiz.",
			}
		"hand_tactic":
			if game_manager.active_player_id != player_id:
				return {"success": false, "error": "Sıra sende değil."}
			var tactic := _find_card_by_network_id(str(payload.get("card_id", ""))) as SpecialPowerCard
			if not tactic or tactic.owner_id != player_id or not is_hand_tactic_card(tactic):
				return {"success": false, "error": "El taktiği bulunamadı veya sana ait değil."}
			var hand_target: BaseCard = null
			if tactic.effect_id == "redraw_card":
				hand_target = _find_card_by_network_id(str(payload.get("target_card_id", "")))
				if not hand_target or hand_target.owner_id != player_id:
					return {"success": false, "error": "Değiştirilecek el kartı bulunamadı."}
			return await resolve_hand_tactic(tactic, hand_target)
		"play_card", "targeted_card", "move", "upgrade", "attack":
			if game_manager.active_player_id != player_id:
				return {"success": false, "error": "Sıra sende değil."}
			var card := _find_card_by_network_id(str(payload.get("card_id", "")))
			if not card or card.owner_id != player_id:
				return {"success": false, "error": "Kart bulunamadı veya sana ait değil."}
			if action == "upgrade":
				var upgrade_result := ProgressionResolver.resolve_upgrade(
					game_manager,
					card,
					str(payload.get("branch_id", ""))
				)
				if bool(upgrade_result.get("success", false)):
					upgrade_result["message"] = "%s yükseltildi." % card.card_name
				return upgrade_result
			var slot := _find_slot_by_network_id(str(payload.get("slot_id", "")))
			if not slot:
				return {"success": false, "error": "Hedef yuva bulunamadı."}
			if action == "play_card":
				var play_result := play_hand_card_to_slot(card, slot)
				if bool(play_result.get("success", false)):
					play_result["message"] = "%s savaş alanına yerleştirildi." % card.card_name
				return play_result
			if action == "targeted_card":
				var effect_result := EffectResolver.resolve_targeted_card(game_manager, card, slot)
				if bool(effect_result.get("success", false)) and not effect_result.has("message"):
					effect_result["message"] = "%s çözüldü." % card.card_name
				return effect_result
			if action == "move":
				var move_result := MovementResolver.resolve_move(game_manager, card, slot)
				if bool(move_result.get("success", false)):
					move_result["message"] = "%s hareket etti ve Tükendi." % card.card_name
				return move_result
			var attack_result: Dictionary = await resolve_attack_with_feedback(card, slot)
			if bool(attack_result.get("success", false)):
				attack_result["message"] = "%s saldırısını tamamladı." % card.card_name
			return attack_result
		_:
			return {"success": false, "error": "Desteklenmeyen ağ hamlesi."}


func build_network_snapshot(perspective_player_id: int) -> Dictionary:
	if perspective_player_id not in GameRules.PLAYER_IDS or not game_manager:
		return {}
	var hands := {}
	for player_id in GameRules.PLAYER_IDS:
		var cards: Array = []
		var hand_cards := get_hand_cards(player_id)
		if player_id == perspective_player_id:
			for card in hand_cards:
				cards.append(_serialize_network_card(card))
		else:
			for hidden_index in range(hand_cards.size()):
				cards.append({
					"hidden": true,
					"owner_id": player_id,
					"network_id": "hidden-%d-%d" % [player_id, hidden_index],
				})
		hands[player_id] = cards

	var board_cards: Array = []
	for slot in get_board_slots():
		if not slot.is_occupied or not slot.occupied_card is BaseCard:
			continue
		var serialized := _serialize_network_card(slot.occupied_card as BaseCard)
		serialized["slot_id"] = _get_slot_network_id(slot)
		board_cards.append(serialized)

	var hq_cards := {
		1: _serialize_network_card(p1_hq as BaseCard),
		2: _serialize_network_card(p2_hq as BaseCard),
	}
	var deck_counts := {}
	for player_id in GameRules.PLAYER_IDS:
		deck_counts[player_id] = (_player_decks.get(player_id, []) as Array).size()

	return {
		"ruleset": int(MatchSetup.ruleset),
		"perspective_player_id": perspective_player_id,
		"manager": {
			"active_player_id": game_manager.active_player_id,
			"first_player_id": game_manager.first_player_id,
			"turn_count": game_manager.turn_count,
			"round_count": game_manager.round_count,
			"current_phase": int(game_manager.current_phase),
			"is_game_active": game_manager.is_game_active,
			"is_match_started": game_manager.is_match_started,
			"winner_id": _network_winner_id,
			"turn_time_remaining": game_manager.turn_time_remaining_seconds,
			"turn_time_running": game_manager.get("_turn_timer_running"),
			"player_max_energy": game_manager.player_max_energy.duplicate(true),
			"player_current_energy": game_manager.player_current_energy.duplicate(true),
			"player_temporary_energy": game_manager.player_temporary_energy.duplicate(true),
			"player_personal_turns": game_manager.player_personal_turns.duplicate(true),
			"preparation_token_available": game_manager.preparation_token_available.duplicate(true),
			"player_failed_draws": game_manager.player_failed_draws.duplicate(true),
			"player_hq_health": game_manager.player_hq_health.duplicate(true),
			"player_dominion_score": game_manager.player_dominion_score.duplicate(true),
			"last_dominion_lane_results": game_manager.last_dominion_lane_results.duplicate(true),
			"win_reason": game_manager.win_reason,
			"player_turn_flags": game_manager.player_turn_flags.duplicate(true),
			"destroyed_hero_history": game_manager.destroyed_hero_history.duplicate(true),
			"effect_selection": game_manager.get_effect_selection_public_state(perspective_player_id),
			"own_effect_trigger_state": game_manager.get_effect_trigger_state(perspective_player_id),
		},
		"hands": hands,
		"board_cards": board_cards,
		"hq_cards": hq_cards,
		"deck_counts": deck_counts,
		"telemetry_summary": _match_telemetry.get_summary() if _match_telemetry else {},
	}


func apply_network_snapshot(snapshot: Dictionary) -> void:
	if not MatchSetup.is_multiplayer_client() or not game_manager:
		return
	var revision := int(snapshot.get("revision", -1))
	if revision <= _applied_network_revision:
		return
	_applied_network_revision = revision
	_clear_deployment_selection()
	MatchSetup.set_ruleset(int(snapshot.get("ruleset", MatchSetup.ruleset)))
	if top_hud:
		top_hud.set_ruleset(MatchSetup.ruleset)
	var telemetry_variant: Variant = snapshot.get("telemetry_summary", {})
	if telemetry_variant is Dictionary:
		_network_match_summary = (telemetry_variant as Dictionary).duplicate(true)

	_clear_network_dynamic_cards()
	var hands_variant: Variant = snapshot.get("hands", {})
	if hands_variant is Dictionary:
		var hands := hands_variant as Dictionary
		for player_id in GameRules.PLAYER_IDS:
			var entries_variant: Variant = _dictionary_player_value(hands, player_id, [])
			if not entries_variant is Array:
				continue
			var hand := _get_hand_for_player(player_id)
			for entry_variant in entries_variant as Array:
				if not entry_variant is Dictionary:
					continue
				var entry := entry_variant as Dictionary
				var card: BaseCard
				if bool(entry.get("hidden", false)):
					card = _instantiate_hidden_network_card(player_id)
				else:
					card = _instantiate_card_from_ref({
						"card_type": str(entry.get("card_type", "")),
						"card_id": str(entry.get("card_id", "")),
					}, player_id)
				if not card:
					continue
				card.set_meta(NETWORK_CARD_ID_META, str(entry.get("network_id", "")))
				hand.add_child(card)
				if not bool(entry.get("hidden", false)):
					card.set_meta("deck_ref", {
						"card_type": str(entry.get("card_type", "")),
						"card_id": str(entry.get("card_id", "")),
					})
					_apply_network_card_state(card, entry)
				card.is_draggable = player_id == MatchSetup.human_player_id and not bool(entry.get("hidden", false))
				_register_preview_card(card)

	var board_variant: Variant = snapshot.get("board_cards", [])
	if board_variant is Array:
		for entry_variant in board_variant as Array:
			if not entry_variant is Dictionary:
				continue
			var entry := entry_variant as Dictionary
			var slot := _find_slot_by_network_id(str(entry.get("slot_id", "")))
			if not slot:
				continue
			var owner_id := int(entry.get("owner_id", 0))
			var card := _instantiate_card_from_ref({
				"card_type": str(entry.get("card_type", "")),
				"card_id": str(entry.get("card_id", "")),
			}, owner_id)
			if not card:
				continue
			card.set_meta(NETWORK_CARD_ID_META, str(entry.get("network_id", "")))
			card.is_draggable = false
			slot.add_child(card)
			_apply_network_card_state(card, entry)
			card.position = (slot.size - card.size) * 0.5
			_register_preview_card(card)

	var hq_variant: Variant = snapshot.get("hq_cards", {})
	if hq_variant is Dictionary:
		var hq_cards := hq_variant as Dictionary
		for player_id in GameRules.PLAYER_IDS:
			var hq_entry_variant: Variant = _dictionary_player_value(hq_cards, player_id, {})
			var hq_card := (p1_hq if player_id == 1 else p2_hq) as BaseCard
			if hq_entry_variant is Dictionary and hq_card:
				_apply_network_card_state(hq_card, hq_entry_variant as Dictionary)

	var deck_counts_variant: Variant = snapshot.get("deck_counts", {})
	if deck_counts_variant is Dictionary:
		var deck_counts := deck_counts_variant as Dictionary
		for player_id in GameRules.PLAYER_IDS:
			var placeholder_deck: Array = []
			placeholder_deck.resize(maxi(0, int(_dictionary_player_value(deck_counts, player_id, 0))))
			_player_decks[player_id] = placeholder_deck

	var manager_variant: Variant = snapshot.get("manager", {})
	if manager_variant is Dictionary:
		_apply_network_manager_state(manager_variant as Dictionary)
	_is_dealing_initial_hands = false
	_is_draw_animation_running = false
	_pending_effect_draws.clear()
	_effect_draw_queue_running = false
	_is_confirming_selection = false
	_refresh_hand_visibility()
	_refresh_hand_card_layouts()
	_refresh_lane_visuals()
	_update_hq_labels()
	_update_deck_ui()
	_refresh_phase_ui()
	_apply_responsive_layout()


func _apply_network_manager_state(state_data: Dictionary) -> void:
	var was_active: bool = game_manager.is_game_active
	game_manager.active_player_id = int(state_data.get("active_player_id", 1))
	game_manager.first_player_id = int(state_data.get("first_player_id", 1))
	game_manager.turn_count = int(state_data.get("turn_count", 1))
	game_manager.round_count = int(state_data.get("round_count", 1))
	game_manager.current_phase = int(state_data.get("current_phase", GameManager.TurnPhase.MULLIGAN))
	game_manager.is_game_active = bool(state_data.get("is_game_active", true))
	game_manager.is_match_started = bool(state_data.get("is_match_started", false))
	game_manager.turn_time_remaining_seconds = float(state_data.get("turn_time_remaining", GameRules.TURN_DURATION_SECONDS))
	game_manager.set("_turn_timer_running", bool(state_data.get("turn_time_running", false)))
	game_manager.player_max_energy = (state_data.get("player_max_energy", {}) as Dictionary).duplicate(true)
	game_manager.player_current_energy = (state_data.get("player_current_energy", {}) as Dictionary).duplicate(true)
	game_manager.player_temporary_energy = (state_data.get("player_temporary_energy", {}) as Dictionary).duplicate(true)
	game_manager.player_personal_turns = (state_data.get("player_personal_turns", {}) as Dictionary).duplicate(true)
	game_manager.preparation_token_available = (state_data.get("preparation_token_available", {}) as Dictionary).duplicate(true)
	game_manager.player_failed_draws = (state_data.get("player_failed_draws", {}) as Dictionary).duplicate(true)
	game_manager.player_hq_health = (state_data.get("player_hq_health", {}) as Dictionary).duplicate(true)
	var dominion_scores_variant: Variant = state_data.get("player_dominion_score", {})
	if dominion_scores_variant is Dictionary:
		var dominion_scores := dominion_scores_variant as Dictionary
		game_manager.player_dominion_score = {
			1: int(_dictionary_player_value(dominion_scores, 1, 0)),
			2: int(_dictionary_player_value(dominion_scores, 2, 0)),
		}
	var dominion_lanes_variant: Variant = state_data.get("last_dominion_lane_results", [])
	game_manager.last_dominion_lane_results = (
		(dominion_lanes_variant as Array).duplicate(true)
		if dominion_lanes_variant is Array
		else []
	)
	game_manager.win_reason = str(state_data.get("win_reason", ""))
	game_manager.player_turn_flags = (state_data.get("player_turn_flags", {}) as Dictionary).duplicate(true)
	game_manager.destroyed_hero_history = (state_data.get("destroyed_hero_history", {}) as Dictionary).duplicate(true)
	var effect_selection_variant: Variant = state_data.get("effect_selection", {})
	if effect_selection_variant is Dictionary:
		var effect_selection := effect_selection_variant as Dictionary
		var perspective_id := MatchSetup.human_player_id
		game_manager.effect_offers = {
			perspective_id: (effect_selection.get("own_offer", []) as Array).duplicate(),
		}
		game_manager.selected_effect_cards.clear()
		var own_selected := str(effect_selection.get("own_selected_card", ""))
		if not own_selected.is_empty():
			game_manager.selected_effect_cards[perspective_id] = own_selected
		game_manager.set("_effect_selection_active", bool(effect_selection.get("active", false)))
	game_manager.effect_trigger_state = {
		MatchSetup.human_player_id: (state_data.get("own_effect_trigger_state", {}) as Dictionary).duplicate(true),
	}

	_on_turn_changed(game_manager.active_player_id)
	_on_phase_changed(game_manager.current_phase)
	for player_id in GameRules.PLAYER_IDS:
		_on_energy_changed(
			player_id,
			int(_dictionary_player_value(game_manager.player_current_energy, player_id, 0)),
			int(_dictionary_player_value(game_manager.player_max_energy, player_id, GameRules.STARTING_ENERGY)),
			int(_dictionary_player_value(game_manager.player_temporary_energy, player_id, 0))
		)
		_on_preparation_token_changed(
			player_id,
			bool(_dictionary_player_value(game_manager.preparation_token_available, player_id, false))
		)
		_on_hq_health_changed(
			player_id,
			int(_dictionary_player_value(game_manager.player_hq_health, player_id, GameRules.HEADQUARTERS_HEALTH)),
			GameRules.HEADQUARTERS_HEALTH
		)
		_on_dominion_score_changed(
			player_id,
			int(_dictionary_player_value(game_manager.player_dominion_score, player_id, 0)),
			GameRules.DOMINION_SCORE_TARGET
		)
	_on_turn_time_changed(
		game_manager.active_player_id,
		game_manager.turn_time_remaining_seconds,
		game_manager.turn_duration_seconds,
		bool(state_data.get("turn_time_running", false))
	)
	_refresh_effect_selection_from_state(false)
	_refresh_effect_card_panel()
	if was_active and not game_manager.is_game_active:
		var winner_id := int(state_data.get("winner_id", 0))
		if winner_id not in GameRules.PLAYER_IDS:
			winner_id = game_manager.get_opponent_id(game_manager.active_player_id)
		_on_game_over(winner_id)


func _serialize_network_card(card: BaseCard) -> Dictionary:
	if not card:
		return {}
	var serialized := {
		"hidden": false,
		"network_id": _get_card_network_id(card),
		"card_type": str(card.call("_get_card_type_key")),
		"card_id": card.card_id,
		"owner_id": card.owner_id,
		"combat_state": int(card.combat_state),
		"status_effects": card.status_effects.duplicate(true),
		"traits": card.traits.duplicate(),
		"trait_values": card.trait_values.duplicate(true),
		"trait_runtime": card.trait_runtime.duplicate(true),
		"effect_params": card.effect_params.duplicate(true),
		"attached_skill_name": card.attached_skill_name,
		"attached_skill_card_id": card.attached_skill_card_id,
		"attached_skill_modifiers": card.attached_skill_modifiers.duplicate(true),
		"attached_skill_added_traits": card.attached_skill_added_traits.duplicate(),
		"experience": card.experience,
		"card_level": card.card_level,
		"selected_branch_id": card.selected_branch_id,
		"selected_branch_name": card.selected_branch_name,
		"experience_gained_this_turn": card.experience_gained_this_turn,
		"combat_damage_experience_awarded_this_turn": card.combat_damage_experience_awarded_this_turn,
		"base_effect_experience_awarded_this_turn": card.base_effect_experience_awarded_this_turn,
		"ready_on_kill_used_this_turn": card.ready_on_kill_used_this_turn,
		"has_moved_this_turn": card.has_moved_this_turn,
		"guard_available": bool(card.get("_guard_available")),
	}
	if card is HeroCard:
		var hero := card as HeroCard
		serialized["attack"] = hero.attack
		serialized["armor"] = hero.armor
		serialized["max_armor"] = hero.max_armor
		serialized["health"] = hero.health
		serialized["max_health"] = hero.max_health
	elif card is SettlementCard:
		var settlement := card as SettlementCard
		serialized["attack"] = settlement.attack
		serialized["health"] = settlement.health
		serialized["max_health"] = settlement.max_health
	return serialized


func _apply_network_card_state(card: BaseCard, serialized: Dictionary) -> void:
	if not card:
		return
	card.set_meta(NETWORK_CARD_ID_META, str(serialized.get("network_id", "")))
	card.owner_id = int(serialized.get("owner_id", card.owner_id))
	card.combat_state = int(serialized.get("combat_state", BaseCard.CombatState.EXHAUSTED))
	card.status_effects = (serialized.get("status_effects", {}) as Dictionary).duplicate(true)
	card.traits.clear()
	var traits_variant: Variant = serialized.get("traits", [])
	if traits_variant is Array:
		for trait_variant in traits_variant as Array:
			card.traits.append(str(trait_variant))
	card.trait_values = (serialized.get("trait_values", {}) as Dictionary).duplicate(true)
	card.trait_runtime = (serialized.get("trait_runtime", {}) as Dictionary).duplicate(true)
	card.effect_params = (serialized.get("effect_params", {}) as Dictionary).duplicate(true)
	card.attached_skill = null
	card.attached_skill_name = str(serialized.get("attached_skill_name", ""))
	card.attached_skill_card_id = str(serialized.get("attached_skill_card_id", ""))
	card.attached_skill_modifiers = (serialized.get("attached_skill_modifiers", {}) as Dictionary).duplicate(true)
	card.attached_skill_added_traits.clear()
	var attached_traits_variant: Variant = serialized.get("attached_skill_added_traits", [])
	if attached_traits_variant is Array:
		for trait_variant in attached_traits_variant as Array:
			card.attached_skill_added_traits.append(str(trait_variant))
	card.experience = int(serialized.get("experience", 0))
	card.card_level = int(serialized.get("card_level", 1))
	card.selected_branch_id = str(serialized.get("selected_branch_id", ""))
	card.selected_branch_name = str(serialized.get("selected_branch_name", ""))
	card.experience_gained_this_turn = int(serialized.get("experience_gained_this_turn", 0))
	card.combat_damage_experience_awarded_this_turn = bool(serialized.get("combat_damage_experience_awarded_this_turn", false))
	card.base_effect_experience_awarded_this_turn = bool(serialized.get("base_effect_experience_awarded_this_turn", false))
	card.ready_on_kill_used_this_turn = bool(serialized.get("ready_on_kill_used_this_turn", false))
	card.has_moved_this_turn = bool(serialized.get("has_moved_this_turn", false))
	card.set("_guard_available", bool(serialized.get("guard_available", true)))
	if card is HeroCard:
		var hero := card as HeroCard
		hero.max_health = int(serialized.get("max_health", hero.max_health))
		hero.max_armor = int(serialized.get("max_armor", hero.max_armor))
		hero.attack = int(serialized.get("attack", hero.attack))
		hero.armor = int(serialized.get("armor", hero.armor))
		hero.health = int(serialized.get("health", hero.health))
	elif card is SettlementCard:
		var settlement := card as SettlementCard
		settlement.max_health = int(serialized.get("max_health", settlement.max_health))
		settlement.attack = int(serialized.get("attack", settlement.attack))
		settlement.health = int(serialized.get("health", settlement.health))
	card.refresh_runtime_badges()
	card.preview_state_changed.emit()


func _clear_network_dynamic_cards() -> void:
	_clear_phase_selection()
	_clear_effect_selection()
	_clear_movement_selection()
	_clear_card_action_selection()
	_clear_combat_selection()
	_hide_card_preview()
	for hand in [p1_hand, p2_hand]:
		for child in hand.get_children():
			if child is BaseCard:
				hand.remove_child(child)
				child.free()
	for slot in get_board_slots():
		if not slot.is_occupied or not slot.occupied_card is BaseCard:
			continue
		var card := slot.occupied_card as BaseCard
		slot.release_card()
		if is_instance_valid(card):
			if card.get_parent():
				card.get_parent().remove_child(card)
			card.free()


func _instantiate_hidden_network_card(player_id: int) -> BaseCard:
	var template := CARD_TEMPLATE_SCENES["heroes"]["COMMON"] as PackedScene
	var card := template.instantiate() as BaseCard
	if not card:
		return null
	card.name = "P%d_HiddenCard" % player_id
	card.card_id = ""
	card.owner_id = player_id
	card.is_draggable = false
	card.size = HAND_CARD_BASE_SIZE
	card.pivot_offset = HAND_CARD_BASE_SIZE * 0.5
	return card


func _resolve_network_card_list(raw_ids: Variant, player_id: int, require_hand: bool) -> Dictionary:
	if not raw_ids is Array or (raw_ids as Array).size() > GameRules.MAX_HAND_SIZE:
		return {"success": false, "error": "Kart listesi geçersiz."}
	var cards: Array[BaseCard] = []
	var seen := {}
	for raw_id in raw_ids as Array:
		var network_id := str(raw_id)
		if network_id.is_empty() or seen.has(network_id):
			return {"success": false, "error": "Kart listesinde tekrar veya boş kimlik var."}
		seen[network_id] = true
		var card := _find_card_by_network_id(network_id)
		if not card or card.owner_id != player_id:
			return {"success": false, "error": "Seçilen kart bulunamadı."}
		if require_hand and card.get_parent() != _get_hand_for_player(player_id):
			return {"success": false, "error": "Seçilen kart oyuncunun elinde değil."}
		cards.append(card)
	return {"success": true, "cards": cards}


func _assign_static_network_ids() -> void:
	if p1_hq is BaseCard:
		(p1_hq as BaseCard).set_meta(NETWORK_CARD_ID_META, "hq-1")
	if p2_hq is BaseCard:
		(p2_hq as BaseCard).set_meta(NETWORK_CARD_ID_META, "hq-2")


func _allocate_network_card_id(player_id: int) -> String:
	var network_id := "p%d-%06d" % [player_id, _next_network_card_serial]
	_next_network_card_serial += 1
	return network_id


func _get_card_network_id(card: BaseCard) -> String:
	if not card:
		return ""
	var network_id := str(card.get_meta(NETWORK_CARD_ID_META, ""))
	if network_id.is_empty() and not MatchSetup.is_multiplayer_client():
		network_id = _allocate_network_card_id(card.owner_id)
		card.set_meta(NETWORK_CARD_ID_META, network_id)
	return network_id


func _find_card_by_network_id(network_id: String) -> BaseCard:
	if network_id.is_empty():
		return null
	for node in get_tree().get_nodes_in_group(BaseCard.GROUP_NAME):
		var card := node as BaseCard
		if card and not card.is_queued_for_deletion() and _get_card_network_id(card) == network_id:
			return card
	return null


func _get_slot_network_id(slot: CardSlot) -> String:
	if not slot:
		return ""
	return "p%d-l%d-s%d" % [slot.owner_id, int(slot.lane_id), int(slot.position_type)]


func _find_slot_by_network_id(network_id: String) -> CardSlot:
	if network_id.is_empty():
		return null
	for node in get_tree().get_nodes_in_group(CardSlot.GROUP_NAME):
		var slot := node as CardSlot
		if slot and _get_slot_network_id(slot) == network_id:
			return slot
	return null


func _request_network_action(action: String, payload: Dictionary = {}) -> bool:
	var network_manager := _get_network_manager()
	if not network_manager:
		show_toast("Ağ yöneticisi bulunamadı.", Color(0.95, 0.38, 0.24))
		return false
	var accepted: bool = network_manager.request_action(action, payload)
	if not accepted:
		show_toast("Sunucu önceki hamleyi çözüyor.", Color(0.95, 0.52, 0.24))
	return accepted


func _get_network_manager() -> Node:
	return get_node_or_null("/root/NetworkManager")


func _dictionary_player_value(dictionary: Dictionary, player_id: int, fallback: Variant) -> Variant:
	if dictionary.has(player_id):
		return dictionary[player_id]
	var string_key := str(player_id)
	return dictionary.get(string_key, fallback)
