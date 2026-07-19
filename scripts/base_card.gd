class_name BaseCard extends Control

const TOP_ALIGNED_CARD_ART_SCRIPT := preload("res://scripts/top_aligned_card_art.gd")
const CARD_BACK_TEXTURE := preload("res://images/cards/card_back_fantasy.png")
const UI := preload("res://scripts/dark_fantasy_ui.gd")
const CARD_CONTENT_Z_INDEX := CardSlot.CONTENT_Z_INDEX
const TRANSIENT_Z_INDEX_META := "transient_z_index"

## Emitted whenever a visible runtime value changes so inspectors can stay in sync.
signal preview_state_changed
signal combat_state_changed(card: BaseCard, state: CombatState)
signal status_changed(card: BaseCard, status_id: String, amount: int)
signal skill_changed(card: BaseCard, skill: UpgradeCard)
signal traits_changed(card: BaseCard)
signal experience_changed(card: BaseCard, current_experience: int, gained: int)
signal level_changed(card: BaseCard, level: int, branch_id: String)
signal movement_state_changed(card: BaseCard, has_moved: bool)

const GROUP_NAME := "cards"

## Rarity classifications
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum CombatState { READY, EXHAUSTED }

@export_group("Card Data")
@export var card_id: String = "":
	set(val):
		card_id = val
		if is_inside_tree():
			_load_card_data_from_database()

@export var card_name: String = "Kart İsmi":
	set(val):
		card_name = val
		_update_ui()

@export_multiline var card_description: String = "Kart açıklaması buraya gelecek.":
	set(val):
		card_description = val
		_update_ui()

@export var energy_cost: int = 1:
	set(val):
		energy_cost = max(0, val)
		_update_ui()

@export var rarity: Rarity = Rarity.COMMON:
	set(val):
		rarity = val
		_update_visuals()
		_update_ui()

@export var owner_id: int = 1
@export var is_draggable: bool = true
@export var effect_id: String = ""
@export var effect_params: Dictionary = {}
@export var traits: Array[String] = []
@export var trait_values: Dictionary = {}

## Mutable state owned by card traits. Unlike static trait_values, these flags
## are serialized into match snapshots so once-per-turn and once-per-round
## abilities remain deterministic across reconnects and save/load.
var trait_runtime: Dictionary = {}

@export_group("Card Textures")
@export var card_art: Texture2D:
	set(val):
		card_art = val
		_update_ui()

@export var card_template: Texture2D:
	set(val):
		card_template = val
		_update_visuals()

@export_group("Animations")
@export var hover_scale: Vector2 = Vector2(1.48, 1.48)
@export var normal_scale: Vector2 = Vector2(1.0, 1.0)
@export var in_slot_scale: Vector2 = Vector2(0.30, 0.30)
@export var drag_visual_scale: Vector2 = Vector2(0.42, 0.42)
@export var drag_cursor_offset: Vector2 = Vector2(14.0, 22.0)
@export var drag_start_distance: float = 10.0
@export var drag_speed: float = 26.0
@export var snap_speed: float = 20.0
@export var return_speed: float = 17.0
@export var tilt_amount: float = 0.08
@export var max_tilt: float = 0.25 # limit in radians (approx 14 degrees)
@export var tilt_speed: float = 8.0

# Drag and Drop variables
var is_dragging: bool = false
var current_slot: CardSlot = null
# Inspector clones are detached from their source slot, but a clone of a
# public battlefield card must not be mistaken for a private opponent hand card.
var is_public_preview := false
var combat_state: CombatState = CombatState.EXHAUSTED
var status_effects: Dictionary = {
	"stunned": 0,
	"poison": 0,
	"poison_turns": 0,
	"protected": 0,
}
var attached_skill: UpgradeCard = null
var attached_skill_name: String = ""
var attached_skill_card_id: String = ""
var attached_skill_modifiers: Dictionary = {}
var attached_skill_added_traits: Array[String] = []
var level_paths: Dictionary = {}
var experience := 0
var card_level := 1
var selected_branch_id := ""
var selected_branch_name := ""
var experience_gained_this_turn := 0
var combat_damage_experience_awarded_this_turn := false
var base_effect_experience_awarded_this_turn := false
var ready_on_kill_used_this_turn := false
var has_moved_this_turn := false
var _guard_available := true

var _original_parent: Node = null
var _original_index: int = -1
var _original_global_position: Vector2
var _drag_offset: Vector2
var _last_position: Vector2
var _is_returning: bool = false
var _is_snapping: bool = false
var _target_global_position: Vector2
var _is_hovered: bool = false
var _active_hovered_slot: CardSlot = null
var _was_in_slot_before_drag: bool = false
var _pending_slot: CardSlot = null
var _pointer_press_pending := false
var _pointer_press_global_position := Vector2.ZERO

# Child UI nodes
var _frame_panel: Panel = null
var _art_texture: TextureRect = null
var _name_lbl: Label = null
var _desc_lbl: Label = null
var _gold_panel: Panel = null
var _gold_lbl: Label = null
var _card_back_panel: Panel = null
var _template_background: TextureRect = null
var _type_lbl: Label = null
var _rarity_lbl: Label = null
var _art_placeholder_lbl: Label = null
var _runtime_state_rail: Panel = null
var _combat_state_badge: Panel = null
var _combat_state_label: Label = null
var _progression_badge: Panel = null
var _progression_label: Label = null
var _effect_state_badge: Panel = null
var _effect_state_label: Label = null
var _interaction_glow: Panel = null
var _interaction_glow_style: StyleBoxFlat = null
var _interaction_glow_tween: Tween = null
var _feedback_tween: Tween = null
var last_feedback_kind := ""
var feedback_animation_count := 0

func _ready() -> void:
	add_to_group(GROUP_NAME)
	# Define default dimensions for the card if not already configured
	if size == Vector2.ZERO:
		size = Vector2(200, 280)
		
	# Center pivot offset for smooth rotate/scale
	pivot_offset = size / 2.0
	item_rect_changed.connect(func(): pivot_offset = size / 2.0)
	
	# Enable mouse input handling
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Instantiate layout controls if not present in scene tree
	_create_ui_nodes_if_missing()
	_create_progression_badge()
	_create_combat_state_badge()
	_create_effect_state_badge()
	_create_interaction_glow()

	_load_card_data_from_database()
	
	# Connect hover signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Initialize visuals
	_update_ui()
	_update_visuals()
	
	# Auto-link and center if pre-placed inside a CardSlot
	if get_parent() is CardSlot:
		current_slot = get_parent()
		current_slot.accept_card(self)
		position = (current_slot.size - size) / 2.0
	
	_refresh_mouse_filter()
	_refresh_progression_visual()
	_refresh_combat_state_visual()
	_refresh_effect_state_visual()

func _process(delta: float) -> void:
	# Fallback: if release event gets consumed by another Control, still finish drag.
	if is_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_dragging()
	
	# Determine face-down status (opponent hand card)
	var gm = GameManager.instance
	var face_down := _is_hand_face_down(gm)
	if face_down:
		_is_hovered = false
		z_index = _get_resting_z_index()
			
	if _frame_panel:
		_frame_panel.visible = not face_down
	if _card_back_panel:
		_card_back_panel.visible = face_down

	# Apply hover rise/down position offset to the visual frame and card back
	var target_y = 0.0
	if current_slot == null:
		if owner_id == 1:
			target_y = -35.0 if _is_hovered else 0.0
		else:
			target_y = 35.0 if _is_hovered else 0.0
			
	if _frame_panel:
		_frame_panel.position.y = lerp(_frame_panel.position.y, target_y, 12.0 * delta)
	if _card_back_panel:
		_card_back_panel.position.y = lerp(_card_back_panel.position.y, target_y, 12.0 * delta)

	# Smoothly scale based on hover/drag status and slot containment
	var base_scale = normal_scale
	if is_dragging:
		base_scale = drag_visual_scale * 1.06
	elif current_slot or _pending_slot or _is_snapping:
		base_scale = in_slot_scale
		
	var should_emphasize = _is_hovered and not (is_dragging or _pending_slot or _is_snapping)
	var target_scale = (base_scale * hover_scale) if should_emphasize else base_scale
	scale = scale.lerp(target_scale, 12.0 * delta)
	
	if is_dragging:
		# A short exponential follow keeps the card attached to the pointer while
		# removing the mechanical one-frame teleport of the old drag motion.
		var target_pos = get_global_mouse_position() + _drag_offset
		var drag_weight := 1.0 - exp(-drag_speed * maxf(delta, 0.0001))
		global_position = global_position.lerp(target_pos, drag_weight)
		
		# Apply smooth rotation based on dragging velocity (wind drag look)
		var velocity = (global_position - _last_position) / delta
		_last_position = global_position
		
		var target_tilt = clamp(velocity.x * tilt_amount * 0.01, -max_tilt, max_tilt)
		rotation = lerp(rotation, target_tilt, tilt_speed * delta)
		
		# Find slot currently under mouse cursor
		_scan_for_hovered_slots()
		
	elif _is_returning:
		# Animate back to original position
		var return_weight := 1.0 - exp(-return_speed * maxf(delta, 0.0001))
		global_position = global_position.lerp(_target_global_position, return_weight)
		rotation = lerp(rotation, 0.0, minf(1.0, tilt_speed * delta))
		
		if global_position.distance_to(_target_global_position) < 0.5:
			global_position = _target_global_position
			_is_returning = false
			
			var battlefield = get_node_or_null("/root/Battlefield")
			if not battlefield:
				top_level = false
				
			# Return to original child index within container
			if _original_parent and is_instance_valid(_original_parent) and get_parent() != _original_parent:
				_reparent_preserve_global(_original_parent)
				var target_index = clamp(_original_index, 0, _original_parent.get_child_count())
				_original_parent.move_child(self, target_index)
				
			# Re-occupy slot if returning back to a slot
			if _original_parent is CardSlot:
				current_slot = _original_parent
				current_slot.accept_card(self)
				rotation = 0.0
			else:
				rotation = float(get_meta("hand_rotation", 0.0))
			
			_refresh_mouse_filter()
			_refresh_progression_visual()
				
	elif _is_snapping:
		# Animate into target grid slot center
		var snap_weight := 1.0 - exp(-snap_speed * maxf(delta, 0.0001))
		global_position = global_position.lerp(_target_global_position, snap_weight)
		rotation = lerp(rotation, 0.0, minf(1.0, tilt_speed * delta))
		
		if global_position.distance_to(_target_global_position) < 0.5:
			global_position = _target_global_position
			rotation = 0.0
			_is_snapping = false
			
			var battlefield = get_node_or_null("/root/Battlefield")
			if not battlefield:
				top_level = false
				
			# Enforce exact local positioning within slot boundaries
			if _pending_slot and is_instance_valid(_pending_slot):
				current_slot = _pending_slot
				_pending_slot = null
				_reparent_preserve_global(current_slot)
				_place_in_slot_center(current_slot)
			elif current_slot:
				_place_in_slot_center(current_slot)
			
			_refresh_mouse_filter()
			_refresh_progression_visual()
			_refresh_combat_state_visual()

func _gui_input(event: InputEvent) -> void:
	# Ignore inputs if card is face down
	var gm = GameManager.instance
	var face_down := _is_hand_face_down(gm)
	if face_down:
		return

	# Mulligan and hand-limit discards use card clicks as selections rather than
	# drag attempts. BattlefieldUI owns the selection count and visual feedback.
	if gm and current_slot == null and gm.current_phase in [GameManager.TurnPhase.MULLIGAN, GameManager.TurnPhase.END]:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				var battlefield_ui := _get_battlefield_ui()
				if battlefield_ui and battlefield_ui.has_method("request_hand_card_selection"):
					battlefield_ui.request_hand_card_selection(self)
		return

	# Cards already committed to the battlefield are inspectable, but they are
	# not picked up again. Upgrade cards can still target them through the slot.
	if current_slot:
		return

	# Taktik Değişim targets another card in the active player's hand. Keep the
	# same direct card-click language as mulligan/discard instead of making the
	# player drag a card onto another overlapping hand card.
	if gm and gm.current_phase == GameManager.TurnPhase.PREPARATION:
		var tactic_battlefield := _get_battlefield_ui()
		if tactic_battlefield and tactic_battlefield.has_method("is_hand_tactic_targeting"):
			if tactic_battlefield.is_hand_tactic_targeting() and event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					tactic_battlefield.request_hand_tactic_target_selection(self)
					accept_event()
				return

	# Spells enter an explicit targeting mode. The card remains in hand until a
	# legal target is chosen, so an invalid target can never consume Energy.
	if self is SpecialPowerCard and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var battlefield_ui := _get_battlefield_ui()
			if battlefield_ui and battlefield_ui.has_method("request_effect_card_selection"):
				battlefield_ui.request_effect_card_selection(self)
			accept_event()
		return
		
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_pointer_interaction()
			else:
				_finish_pointer_interaction()
			accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _pointer_press_pending:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var distance := motion.position.distance_to(_pointer_press_global_position)
			if distance >= drag_start_distance:
				_pointer_press_pending = false
				_start_dragging()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			if is_dragging:
				_stop_dragging()
			elif _pointer_press_pending:
				_finish_pointer_interaction()

func _begin_pointer_interaction() -> void:
	if _is_returning or _is_snapping or not is_draggable:
		return
	_pointer_press_pending = true
	_pointer_press_global_position = get_viewport().get_mouse_position()

func _finish_pointer_interaction() -> void:
	if not _pointer_press_pending:
		return
	_pointer_press_pending = false
	var battlefield_ui := _get_battlefield_ui()
	if not battlefield_ui:
		return
	if self is UpgradeCard and battlefield_ui.has_method("request_effect_card_selection"):
		battlefield_ui.request_effect_card_selection(self)
	elif battlefield_ui.has_method("request_hand_card_deployment_selection"):
		battlefield_ui.request_hand_card_deployment_selection(self)

func _start_dragging() -> void:
	_pointer_press_pending = false
	if _is_returning or _is_snapping:
		return

	var battlefield_ui := _get_battlefield_ui()
	if battlefield_ui and battlefield_ui.has_method("is_card_interaction_locked"):
		if battlefield_ui.is_card_interaction_locked():
			return
		
	# Turn, phase and energy validation checks
	var gm = GameManager.instance
	if gm:
		if gm.active_player_id != owner_id:
			_show_game_toast("Sıra sende değil.")
			return
		if not gm.can_play_card(owner_id):
			_show_game_toast("Kartlar yalnızca Hazırlık aşamasında oynanabilir.")
			return
		var action_type := "hero" if self is HeroCard else "settlement"
		var resolved_cost := EffectResolver.get_effect_action_cost(gm, self, action_type, energy_cost)
		if not current_slot and not gm.has_enough_energy(owner_id, resolved_cost):
			_show_game_toast("Kartı oynayacak Enerji yok.")
			return
			
	if not is_draggable:
		return
		
	is_dragging = true
	set_selection_visual(true, UI.BRASS_BRIGHT)
	_pending_slot = null
	_original_parent = get_parent()
	_original_index = get_index()
	_original_global_position = global_position
	_was_in_slot_before_drag = (current_slot != null)
	
	# Release current slot association
	if current_slot:
		current_slot.release_card()
		current_slot = null
		_refresh_progression_visual()
		
	# Keep the card close to the cursor without covering the cursor itself.
	scale = drag_visual_scale
	_drag_offset = _get_drag_global_offset()
	global_position = get_global_mouse_position() + _drag_offset
	_last_position = global_position
	z_index = _get_drag_z_index()
	_refresh_mouse_filter()
	if battlefield_ui and battlefield_ui.has_method("begin_drag_target_preview"):
		battlefield_ui.begin_drag_target_preview(self)
	
	# Reparent to root Battlefield node to drag outside local containers
	var battlefield = get_node_or_null("/root/Battlefield")
	if battlefield:
		_reparent_preserve_global(battlefield)
	else:
		top_level = true
		
	rotation = 0.0

func _stop_dragging() -> void:
	if not is_dragging:
		return
	is_dragging = false
	set_selection_visual(false)
	var target_preview_battlefield := _get_battlefield_ui()
	if target_preview_battlefield and target_preview_battlefield.has_method("end_drag_target_preview"):
		target_preview_battlefield.end_drag_target_preview(self)
	
	var gm = GameManager.instance
	
	var slot = _get_slot_under_mouse()
	if _active_hovered_slot and _active_hovered_slot != slot:
		_active_hovered_slot.highlight(false)
	_active_hovered_slot = null
	
	if slot:
		slot.highlight(false)
		# Multiplayer clients never mutate gameplay state optimistically. They send
		# the intended drop to the dedicated server, return the local card to hand,
		# and wait for the authoritative snapshot.
		if MatchSetup.is_multiplayer_client():
			var network_battlefield := _get_battlefield_ui()
			if network_battlefield and network_battlefield.has_method("request_network_card_drop"):
				if not network_battlefield.request_network_card_drop(self, slot):
					_show_game_toast("Sunucu önceki hamleyi çözüyor.")
			_return_to_original_position()
			return
			
		# Beceri cards retain their drag interaction, but validation, Energy and
		# attachment all use the same central resolver as spells and passives.
		if self is UpgradeCard and slot.is_occupied:
			var effect_result := EffectResolver.resolve_targeted_card(gm, self, slot)
			if not bool(effect_result.get("success", false)):
				_show_game_toast(str(effect_result.get("error", "Beceri hedefi geçersiz.")))
				_return_to_original_position()
				return
			_sync_energy_display(gm, owner_id)
			_show_game_toast(str(effect_result.get("message", "Beceri bağlandı.")))
			return

		# Board deployments use the same authoritative cost/effect resolver as AI,
		# click-to-place, saves, and dedicated-server actions. Reparenting briefly
		# restores the hand invariant expected by that central boundary.
		var release_global_position := global_position
		var release_rotation := rotation
		if _original_parent and is_instance_valid(_original_parent) and get_parent() != _original_parent:
			_reparent_preserve_global(_original_parent)
		var battlefield_ui := _get_battlefield_ui()
		var play_result := {"success": false, "error": "Kart yerleştirme akışı bulunamadı."}
		if battlefield_ui and battlefield_ui.has_method("play_hand_card_to_slot"):
			play_result = battlefield_ui.play_hand_card_to_slot(self, slot)
		if not bool(play_result.get("success", false)):
			_show_game_toast(str(play_result.get("error", "Kart bu yuvaya yerleştirilemedi.")))
			_return_to_original_position()
			return
		animate_deployment_from(release_global_position, release_rotation)
	else:
		# Return to hand/original container
		# We don't reparent here to let the return animation play smoothly in Battlefield space
		_return_to_original_position()

func cancel_dragging() -> bool:
	if not is_dragging:
		return false
	is_dragging = false
	_pointer_press_pending = false
	set_selection_visual(false)
	if _active_hovered_slot and is_instance_valid(_active_hovered_slot):
		_active_hovered_slot.highlight(false)
	_active_hovered_slot = null
	var battlefield_ui := _get_battlefield_ui()
	if battlefield_ui and battlefield_ui.has_method("end_drag_target_preview"):
		battlefield_ui.end_drag_target_preview(self)
	_return_to_original_position()
	return true

func _scan_for_hovered_slots() -> void:
	var hovered_slot = _get_slot_under_mouse()
	
	if hovered_slot != _active_hovered_slot:
		if _active_hovered_slot:
			_active_hovered_slot.highlight(false)
		_active_hovered_slot = hovered_slot
		if _active_hovered_slot:
			_active_hovered_slot.highlight(true)

func _get_slot_under_mouse() -> CardSlot:
	var mouse_pos = get_global_mouse_position()
	var slots = get_tree().get_nodes_in_group(CardSlot.GROUP_NAME)
	var best_slot: CardSlot = null
	var best_distance_sq := INF
	
	for slot in slots:
		if slot is CardSlot and slot.can_accept_card(self):
			var rect = slot.get_global_rect()
			if rect.has_point(mouse_pos):
				var center = rect.position + (rect.size * 0.5)
				var distance_sq = mouse_pos.distance_squared_to(center)
				if distance_sq < best_distance_sq:
					best_distance_sq = distance_sq
					best_slot = slot
	
	return best_slot

func _get_slot_center_global(slot: CardSlot) -> Vector2:
	var rect = slot.get_global_rect()
	return rect.position + (rect.size * 0.5)

func _place_in_slot_center(slot: CardSlot) -> void:
	position = (slot.size - size) * 0.5

func animate_deployment_from(start_global_position: Vector2, start_rotation: float = 0.0) -> bool:
	if not current_slot or not is_instance_valid(current_slot):
		return false
	global_position = start_global_position
	rotation = start_rotation
	_target_global_position = _get_slot_center_global(current_slot) - (size * 0.5)
	_pending_slot = null
	_is_returning = false
	_is_snapping = true
	_refresh_mouse_filter()
	return true

func _reparent_preserve_global(new_parent: Node) -> void:
	reparent(new_parent, true)

func _get_drag_global_offset() -> Vector2:
	var pivot = pivot_offset
	if pivot == Vector2.ZERO:
		pivot = size * 0.5

	var visual_card_size = size * drag_visual_scale
	var visual_top_left_offset = Vector2(
		-(visual_card_size.x + drag_cursor_offset.x),
		drag_cursor_offset.y
	)
	return visual_top_left_offset - (pivot * (Vector2.ONE - drag_visual_scale))

func _get_drag_z_index() -> int:
	# While a card is reparented to Battlefield it no longer inherits the slot
	# band. Keep it above the fixed hand dock and inspector chrome as well, so a
	# card never disappears behind the new bottom-hand surface while dragging.
	var slot_count := get_tree().get_nodes_in_group(CardSlot.GROUP_NAME).size()
	return maxi(500, slot_count * CardSlot.Z_INDEX_STRIDE)

func _return_to_original_position() -> void:
	_target_global_position = _original_global_position
	_is_returning = true
	_refresh_mouse_filter()

func _spend_play_cost(gm: GameManager) -> bool:
	if not gm:
		return false

	var did_spend = gm.spend_energy(owner_id, energy_cost)
	if did_spend:
		_sync_energy_display(gm, owner_id)
	else:
		_show_game_toast("Kartı oynayacak Enerji yok veya hamle bu aşamada geçersiz.")

	return did_spend

func _sync_energy_display(_gm: GameManager, player_id: int) -> void:
	var battlefield = get_tree().current_scene
	if not battlefield or not battlefield.has_method("sync_player_energy"):
		battlefield = get_node_or_null("/root/Battlefield")

	if battlefield and battlefield.has_method("sync_player_energy"):
		battlefield.sync_player_energy(player_id)

func _show_game_toast(message: String) -> void:
	if message.is_empty():
		return

	var battlefield = get_tree().current_scene
	if not battlefield or not battlefield.has_method("show_toast"):
		battlefield = get_node_or_null("/root/Battlefield")

	if battlefield and battlefield.has_method("show_toast"):
		battlefield.show_toast(message, Color(0.95, 0.38, 0.24))

func on_played_to_board() -> void:
	has_moved_this_turn = false
	set_combat_state(CombatState.READY if has_trait("fast") else CombatState.EXHAUSTED)

func ready_for_turn() -> void:
	if not current_slot or is_headquarters():
		return
	_guard_available = true
	if consume_stunned_ready_skip():
		set_combat_state(CombatState.EXHAUSTED)
		return
	set_combat_state(CombatState.READY)

func set_combat_state(next_state: CombatState) -> void:
	if combat_state == next_state:
		_refresh_progression_visual()
		_refresh_combat_state_visual()
		_refresh_effect_state_visual()
		return
	combat_state = next_state
	_refresh_progression_visual()
	_refresh_combat_state_visual()
	_refresh_effect_state_visual()
	combat_state_changed.emit(self, combat_state)
	preview_state_changed.emit()

func is_ready_for_combat() -> bool:
	return combat_state == CombatState.READY

func get_attack_value() -> int:
	return 0

func get_current_health() -> int:
	return 0

func get_max_health() -> int:
	return 0

func take_combat_damage(_damage: int) -> Dictionary:
	return {"success": false, "error": "Bu kart hasar alamaz."}

func heal_combat_damage(_amount: int) -> int:
	return 0

func has_trait(trait_id: String) -> bool:
	var normalized_trait := trait_id.strip_edges().to_lower()
	for value in traits:
		if value.strip_edges().to_lower() == normalized_trait:
			return true
	return false

func add_trait(trait_id: String) -> bool:
	var normalized_trait := trait_id.strip_edges().to_lower()
	if normalized_trait.is_empty() or has_trait(normalized_trait):
		return false
	traits.append(normalized_trait)
	traits_changed.emit(self)
	preview_state_changed.emit()
	return true

func remove_trait(trait_id: String) -> bool:
	var normalized_trait := trait_id.strip_edges().to_lower()
	for index in range(traits.size() - 1, -1, -1):
		if traits[index].strip_edges().to_lower() != normalized_trait:
			continue
		traits.remove_at(index)
		traits_changed.emit(self)
		preview_state_changed.emit()
		return true
	return false

func get_trait_value(key: String, fallback: int = 0) -> int:
	var value: Variant = trait_values.get(key, fallback)
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback

func apply_status(status_id: String, amount: int, duration: int = 1) -> bool:
	var normalized_status := status_id.strip_edges().to_lower()
	var normalized_amount: int = max(0, amount)
	var normalized_duration: int = max(1, duration)
	match normalized_status:
		"stunned":
			status_effects["stunned"] = max(
				int(status_effects.get("stunned", 0)),
				max(normalized_amount, normalized_duration)
			)
		"poison":
			status_effects["poison"] = max(int(status_effects.get("poison", 0)), normalized_amount)
			status_effects["poison_turns"] = max(
				int(status_effects.get("poison_turns", 0)),
				normalized_duration
			)
		"protected":
			status_effects["protected"] = int(status_effects.get("protected", 0)) + normalized_amount
		_:
			return false

	_refresh_effect_state_visual()
	status_changed.emit(self, normalized_status, get_status_amount(normalized_status))
	preview_state_changed.emit()
	return true

func get_status_amount(status_id: String) -> int:
	return int(status_effects.get(status_id.strip_edges().to_lower(), 0))

func consume_stunned_ready_skip() -> bool:
	var remaining := get_status_amount("stunned")
	if remaining <= 0:
		return false
	status_effects["stunned"] = remaining - 1
	_refresh_effect_state_visual()
	status_changed.emit(self, "stunned", remaining - 1)
	preview_state_changed.emit()
	return true

func consume_poison_tick() -> int:
	var damage := get_status_amount("poison")
	var turns := int(status_effects.get("poison_turns", 0))
	if damage <= 0 or turns <= 0:
		return 0
	turns -= 1
	status_effects["poison_turns"] = turns
	if turns <= 0:
		status_effects["poison"] = 0
	_refresh_effect_state_visual()
	status_changed.emit(self, "poison", int(status_effects.get("poison", 0)))
	preview_state_changed.emit()
	return damage

func absorb_protected_damage(incoming_damage: int) -> Dictionary:
	var normalized_damage: int = max(0, incoming_damage)
	var protection := get_status_amount("protected")
	if protection <= 0 or normalized_damage <= 0:
		return {"blocked": 0, "remaining": normalized_damage}
	var blocked: int = min(protection, normalized_damage)
	# Korumalı is consumed by the next damage instance, even when some of the
	# shield amount would remain.
	status_effects["protected"] = 0
	_refresh_effect_state_visual()
	status_changed.emit(self, "protected", 0)
	preview_state_changed.emit()
	return {"blocked": blocked, "remaining": normalized_damage - blocked}

func is_guard_available() -> bool:
	return has_trait("guard") and _guard_available and get_current_health() > 0

func consume_guard() -> void:
	_guard_available = false
	preview_state_changed.emit()

func can_attach_skill() -> bool:
	return (
		attached_skill_name.is_empty()
		and (attached_skill == null or not is_instance_valid(attached_skill))
	)

func attach_skill(skill: UpgradeCard) -> bool:
	if not skill or not is_instance_valid(skill) or not can_attach_skill():
		return false
	if skill.owner_id != owner_id or is_headquarters():
		return false

	attached_skill = skill
	attached_skill_name = skill.card_name
	attached_skill_card_id = skill.card_id
	attached_skill_modifiers = {
		"bonus_attack": skill.bonus_attack,
		"bonus_armor": skill.bonus_armor,
		"bonus_health": skill.bonus_health,
	}
	attached_skill_added_traits.clear()
	skill.is_dragging = false
	skill.current_slot = null
	skill.is_draggable = false
	skill.visible = false
	if skill.get_parent():
		skill.reparent(self, false)
	else:
		add_child(skill)
	skill.process_mode = Node.PROCESS_MODE_DISABLED
	_refresh_effect_state_visual()
	skill_changed.emit(self, skill)
	preview_state_changed.emit()
	return true

func add_attached_skill_trait(trait_id: String) -> bool:
	var normalized_trait := trait_id.strip_edges().to_lower()
	if not add_trait(normalized_trait):
		return false
	if normalized_trait not in attached_skill_added_traits:
		attached_skill_added_traits.append(normalized_trait)
	return true

func clear_attached_skill() -> UpgradeCard:
	var previous_skill := attached_skill
	attached_skill = null
	attached_skill_name = ""
	attached_skill_card_id = ""
	attached_skill_modifiers.clear()
	attached_skill_added_traits.clear()
	_refresh_effect_state_visual()
	skill_changed.emit(self, null)
	preview_state_changed.emit()
	return previous_skill

func gain_experience(amount: int) -> int:
	if amount <= 0 or card_level >= GameRules.MAX_CARD_LEVEL:
		return 0
	var turn_cap := get_experience_turn_cap()
	if turn_cap <= 0:
		return 0
	var remaining_turn_gain: int = max(0, turn_cap - experience_gained_this_turn)
	var maximum_experience := int(GameRules.LEVEL_EXPERIENCE_REQUIREMENTS.get(GameRules.MAX_CARD_LEVEL, 6))
	var remaining_total: int = max(0, maximum_experience - experience)
	var gained: int = min(amount, min(remaining_turn_gain, remaining_total))
	if gained <= 0:
		return 0
	experience += gained
	experience_gained_this_turn += gained
	_refresh_effect_state_visual()
	experience_changed.emit(self, experience, gained)
	preview_state_changed.emit()
	return gained

func get_experience_turn_cap() -> int:
	if self is HeroCard:
		return GameRules.HERO_EXPERIENCE_PER_TURN
	if self is SettlementCard and not is_headquarters():
		return GameRules.STRUCTURE_EXPERIENCE_PER_TURN
	return 0

func get_next_level_experience() -> int:
	if card_level >= GameRules.MAX_CARD_LEVEL:
		return experience
	return int(GameRules.LEVEL_EXPERIENCE_REQUIREMENTS.get(card_level + 1, experience))

func reset_owner_turn_tracking() -> void:
	experience_gained_this_turn = 0
	combat_damage_experience_awarded_this_turn = false
	base_effect_experience_awarded_this_turn = false
	ready_on_kill_used_this_turn = false
	has_moved_this_turn = false
	_guard_available = true
	if has_trait("bulwark"):
		trait_runtime["bulwark_available"] = true
	if has_trait("time_thief"):
		trait_runtime["time_theft_used"] = false
	movement_state_changed.emit(self, false)
	preview_state_changed.emit()

func mark_moved_this_turn() -> void:
	has_moved_this_turn = true
	movement_state_changed.emit(self, true)
	preview_state_changed.emit()

func set_progression_level(next_level: int) -> void:
	card_level = clampi(next_level, 1, GameRules.MAX_CARD_LEVEL)
	_refresh_progression_visual()
	_refresh_effect_state_visual()
	level_changed.emit(self, card_level, selected_branch_id)
	preview_state_changed.emit()

func reset_progression() -> void:
	experience = 0
	card_level = 1
	selected_branch_id = ""
	selected_branch_name = ""
	experience_gained_this_turn = 0
	combat_damage_experience_awarded_this_turn = false
	base_effect_experience_awarded_this_turn = false
	ready_on_kill_used_this_turn = false
	has_moved_this_turn = false
	_reset_trait_runtime()
	_refresh_progression_visual()
	_refresh_effect_state_visual()

func _reset_trait_runtime() -> void:
	trait_runtime.clear()
	if has_trait("bulwark"):
		trait_runtime["bulwark_available"] = true
	if has_trait("time_thief"):
		trait_runtime["time_theft_used"] = false

func refresh_runtime_badges() -> void:
	_refresh_progression_visual()
	_refresh_effect_state_visual()
	_refresh_combat_state_visual()

## Keeps combat feedback on the visual frame so the card's drag/snap scale and
## position state machine remain authoritative.
func play_feedback_animation(kind: String, amount: int = 0) -> bool:
	if not _frame_panel or not is_instance_valid(_frame_panel) or is_queued_for_deletion():
		return false
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_reset_feedback_visual()
	var normalized := kind.strip_edges().to_lower()
	last_feedback_kind = normalized
	feedback_animation_count += 1
	_feedback_tween = create_tween().bind_node(self).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	match normalized:
		"deploy":
			_frame_panel.self_modulate = Color(0.52, 0.88, 1.0, 1.0)
			_feedback_tween.set_trans(Tween.TRANS_BACK)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(1.12, 1.12), 0.10)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", 0.025, 0.10)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(0.97, 0.97), 0.09)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", -0.018, 0.09)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2.ONE, 0.15)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", 0.0, 0.15)
		"attack":
			_frame_panel.self_modulate = Color(1.0, 0.74, 0.34, 1.0)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(1.10, 1.10), 0.20)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", -0.045, 0.20)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(0.96, 0.96), 0.10)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", 0.035, 0.10)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2.ONE, 0.18)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", 0.0, 0.18)
		"brace":
			_frame_panel.self_modulate = Color(0.88, 0.78, 0.60, 1.0)
			_feedback_tween.set_trans(Tween.TRANS_QUAD)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(0.94, 0.94), 0.18)
			_feedback_tween.tween_interval(0.76)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2.ONE, 0.18)
		"hit", "damage":
			var shake := clampf(3.0 + float(maxi(0, amount)) * 0.35, 3.0, 9.0)
			_frame_panel.self_modulate = Color(1.0, 0.34, 0.28, 1.0)
			_feedback_tween.set_trans(Tween.TRANS_SINE)
			_feedback_tween.tween_property(_frame_panel, "position:x", shake, 0.075)
			_feedback_tween.tween_property(_frame_panel, "position:x", -shake, 0.085)
			_feedback_tween.tween_property(_frame_panel, "position:x", shake * 0.45, 0.075)
			_feedback_tween.tween_property(_frame_panel, "position:x", 0.0, 0.085)
		"critical":
			var critical_shake := clampf(7.0 + float(maxi(0, amount)) * 0.42, 7.0, 13.0)
			_frame_panel.self_modulate = Color(1.0, 0.62, 0.16, 1.0)
			_feedback_tween.set_trans(Tween.TRANS_BACK)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(1.16, 1.16), 0.07)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", -0.065, 0.07)
			_feedback_tween.tween_property(_frame_panel, "position:x", critical_shake, 0.07)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", 0.055, 0.07)
			_feedback_tween.tween_property(_frame_panel, "position:x", -critical_shake * 0.72, 0.08)
			_feedback_tween.tween_property(_frame_panel, "position:x", 0.0, 0.09)
			_feedback_tween.parallel().tween_property(_frame_panel, "scale", Vector2.ONE, 0.12)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", 0.0, 0.12)
		"blocked":
			_frame_panel.self_modulate = Color(0.48, 0.84, 1.0, 1.0)
			_feedback_tween.set_trans(Tween.TRANS_BACK)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(0.90, 0.96), 0.08)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(1.055, 1.055), 0.12)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2.ONE, 0.14)
		"armor_break":
			var armor_shake := clampf(4.5 + float(maxi(0, amount)) * 0.28, 4.5, 9.5)
			_frame_panel.self_modulate = Color(0.72, 0.88, 1.0, 1.0)
			_feedback_tween.set_trans(Tween.TRANS_SINE)
			_feedback_tween.tween_property(_frame_panel, "rotation", -0.055, 0.06)
			_feedback_tween.parallel().tween_property(_frame_panel, "position:x", armor_shake, 0.06)
			_feedback_tween.tween_property(_frame_panel, "rotation", 0.048, 0.07)
			_feedback_tween.parallel().tween_property(_frame_panel, "position:x", -armor_shake, 0.07)
			_feedback_tween.tween_property(_frame_panel, "rotation", 0.0, 0.10)
			_feedback_tween.parallel().tween_property(_frame_panel, "position:x", 0.0, 0.10)
		"heal":
			_frame_panel.self_modulate = Color(0.48, 1.0, 0.65, 1.0)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(1.09, 1.09), 0.10)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2.ONE, 0.16)
		"upgrade":
			_frame_panel.self_modulate = Color(1.0, 0.82, 0.30, 1.0)
			_feedback_tween.set_trans(Tween.TRANS_BACK)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(1.14, 1.14), 0.15)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", 0.045, 0.15)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2.ONE, 0.20)
			_feedback_tween.parallel().tween_property(_frame_panel, "rotation", 0.0, 0.20)
		"experience":
			_frame_panel.self_modulate = Color(0.48, 0.78, 1.0, 1.0)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2(1.045, 1.045), 0.07)
			_feedback_tween.tween_property(_frame_panel, "scale", Vector2.ONE, 0.10)
		"move":
			_frame_panel.self_modulate = Color(0.42, 0.94, 1.0, 1.0)
			_feedback_tween.tween_property(_frame_panel, "rotation", 0.035, 0.07)
			_feedback_tween.tween_property(_frame_panel, "rotation", 0.0, 0.10)
		_:
			_feedback_tween.tween_interval(0.08)

	_feedback_tween.tween_property(_frame_panel, "self_modulate", Color.WHITE, 0.12)
	_feedback_tween.tween_callback(_reset_feedback_visual)
	return true

## Directional wind-up and lunge make the attacker readable before damage is
## resolved. Only the visual frame moves; slot ownership and drag coordinates
## remain untouched.
func play_attack_lunge(target_global_position: Vector2) -> bool:
	if not _frame_panel or not is_instance_valid(_frame_panel) or is_queued_for_deletion():
		return false
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_reset_feedback_visual()
	var source_center := get_global_rect().get_center()
	var direction := source_center.direction_to(target_global_position)
	if direction.length_squared() <= 0.001:
		direction = Vector2.UP
	var windup := -direction * 11.0
	var lunge := direction * 31.0
	var attack_tilt := clampf(direction.x * 0.075, -0.075, 0.075)
	last_feedback_kind = "attack"
	feedback_animation_count += 1
	_frame_panel.self_modulate = Color(1.0, 0.74, 0.34, 1.0)
	_feedback_tween = create_tween().bind_node(self).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	_feedback_tween.tween_property(_frame_panel, "position", windup, 0.24)
	_feedback_tween.parallel().tween_property(_frame_panel, "scale", Vector2(1.055, 1.055), 0.24)
	_feedback_tween.parallel().tween_property(_frame_panel, "rotation", -attack_tilt * 0.55, 0.24)
	_feedback_tween.tween_interval(0.14)
	_feedback_tween.tween_property(_frame_panel, "position", lunge, 0.54)
	_feedback_tween.parallel().tween_property(_frame_panel, "scale", Vector2(1.18, 1.18), 0.54)
	_feedback_tween.parallel().tween_property(_frame_panel, "rotation", attack_tilt, 0.54)
	_feedback_tween.tween_interval(0.20)
	_feedback_tween.tween_property(_frame_panel, "position", Vector2.ZERO, 0.24)
	_feedback_tween.parallel().tween_property(_frame_panel, "scale", Vector2.ONE, 0.24)
	_feedback_tween.parallel().tween_property(_frame_panel, "rotation", 0.0, 0.24)
	_feedback_tween.parallel().tween_property(_frame_panel, "self_modulate", Color.WHITE, 0.24)
	_feedback_tween.tween_callback(_reset_feedback_visual)
	return true

func _reset_feedback_visual() -> void:
	if not _frame_panel or not is_instance_valid(_frame_panel):
		return
	_frame_panel.position = Vector2.ZERO
	_frame_panel.rotation = 0.0
	_frame_panel.scale = Vector2.ONE
	_frame_panel.self_modulate = Color.WHITE

func is_headquarters() -> bool:
	return current_slot != null and current_slot.position_type == CardSlot.PositionType.HQ

func destroy_from_combat() -> void:
	reset_progression()
	if current_slot and is_instance_valid(current_slot):
		var previous_slot := current_slot
		current_slot = null
		if previous_slot.occupied_card == self:
			previous_slot.release_card()
	queue_free()

func _create_interaction_glow() -> void:
	if not _frame_panel or _interaction_glow:
		return
	_interaction_glow = Panel.new()
	_interaction_glow.name = "InteractionGlow"
	_interaction_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interaction_glow.offset_left = -5.0
	_interaction_glow.offset_top = -5.0
	_interaction_glow.offset_right = 5.0
	_interaction_glow.offset_bottom = 5.0
	_interaction_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_glow.z_index = CARD_CONTENT_Z_INDEX
	_interaction_glow.visible = false
	_interaction_glow_style = StyleBoxFlat.new()
	_interaction_glow_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_interaction_glow_style.border_color = UI.BRASS_BRIGHT
	_interaction_glow_style.set_border_width_all(4)
	_interaction_glow_style.set_corner_radius_all(12)
	_interaction_glow_style.shadow_color = Color(UI.BRASS_BRIGHT, 0.62)
	_interaction_glow_style.shadow_size = 13
	_interaction_glow_style.shadow_offset = Vector2.ZERO
	_interaction_glow.add_theme_stylebox_override("panel", _interaction_glow_style)
	_frame_panel.add_child(_interaction_glow)

func set_selection_visual(selected: bool, accent: Color = UI.BRASS_BRIGHT) -> void:
	if not _interaction_glow:
		return
	if _interaction_glow_tween and _interaction_glow_tween.is_valid():
		_interaction_glow_tween.kill()
	_interaction_glow.visible = selected
	if not selected:
		_interaction_glow.modulate.a = 0.0
		return
	if _interaction_glow_style:
		_interaction_glow_style.border_color = Color(accent.r, accent.g, accent.b, 0.98)
		_interaction_glow_style.shadow_color = Color(accent.r, accent.g, accent.b, 0.62)
	_interaction_glow.modulate.a = 0.56
	_interaction_glow_tween = create_tween().bind_node(_interaction_glow).set_loops()
	_interaction_glow_tween.tween_property(_interaction_glow, "modulate:a", 1.0, 0.42)
	_interaction_glow_tween.tween_property(_interaction_glow, "modulate:a", 0.48, 0.56)

func _create_effect_state_badge() -> void:
	if not _frame_panel or _effect_state_badge:
		return
	_effect_state_badge = Panel.new()
	_effect_state_badge.name = "EffectStateBadge"
	_effect_state_badge.anchor_left = 0.29
	_effect_state_badge.anchor_top = 0.018
	_effect_state_badge.anchor_right = 0.69
	_effect_state_badge.anchor_bottom = 0.092
	_effect_state_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_state_badge.z_index = 1 if _runtime_state_rail else CARD_CONTENT_Z_INDEX
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.05, 0.075, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.76, 0.58, 0.27, 0.92)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	_effect_state_badge.add_theme_stylebox_override("panel", style)
	var badge_parent: Control = _runtime_state_rail if _runtime_state_rail else _frame_panel
	badge_parent.add_child(_effect_state_badge)

	_effect_state_label = Label.new()
	_effect_state_label.name = "EffectStateLabel"
	_effect_state_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effect_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_effect_state_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_effect_state_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_effect_state_label.add_theme_font_size_override("font_size", 8)
	_effect_state_label.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	_effect_state_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_effect_state_label.add_theme_constant_override("outline_size", 2)
	_effect_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_state_badge.add_child(_effect_state_label)
	_layout_runtime_state_badges()

func _refresh_effect_state_visual() -> void:
	if not _effect_state_badge or not _effect_state_label:
		return
	var labels: Array[String] = []
	var tooltip_lines: Array[String] = []
	var stunned := get_status_amount("stunned")
	var poison := get_status_amount("poison")
	var protected_amount := get_status_amount("protected")
	if stunned > 0:
		labels.append("S%d" % stunned)
		tooltip_lines.append("Sersem %d" % stunned)
	if poison > 0:
		labels.append("Z%d" % poison)
		tooltip_lines.append("Zehir %d" % poison)
	if protected_amount > 0:
		labels.append("K%d" % protected_amount)
		tooltip_lines.append("Koruma %d" % protected_amount)
	if not attached_skill_name.is_empty():
		labels.append("BECERİ")
		tooltip_lines.append("Bağlı Beceri: %s" % attached_skill_name)
	_effect_state_label.text = " • ".join(labels)
	_effect_state_badge.tooltip_text = "\n".join(tooltip_lines)
	_effect_state_badge.visible = not labels.is_empty()
	_refresh_runtime_state_rail_visibility()

func _create_progression_badge() -> void:
	if not _frame_panel or _progression_badge:
		return

	_progression_badge = Panel.new()
	_progression_badge.name = "ProgressionBadge"
	_progression_badge.anchor_left = 0.02
	_progression_badge.anchor_top = 0.018
	_progression_badge.anchor_right = 0.28
	_progression_badge.anchor_bottom = 0.092
	_progression_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progression_badge.z_index = 1 if _runtime_state_rail else CARD_CONTENT_Z_INDEX
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.075, 0.022, 0.96)
	style.border_color = Color(0.96, 0.72, 0.25, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 2.0)
	_progression_badge.add_theme_stylebox_override("panel", style)
	var badge_parent: Control = _runtime_state_rail if _runtime_state_rail else _frame_panel
	badge_parent.add_child(_progression_badge)

	_progression_label = Label.new()
	_progression_label.name = "Label"
	_progression_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_progression_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progression_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progression_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progression_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_progression_label.add_theme_font_size_override("font_size", 8)
	_progression_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.68))
	_progression_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_progression_label.add_theme_constant_override("outline_size", 2)
	_progression_badge.add_child(_progression_label)
	_layout_runtime_state_badges()

func _refresh_progression_visual() -> void:
	if not _progression_badge or not _progression_label:
		return
	var show_progression := (
		(current_slot != null or _pending_slot != null)
		and not is_headquarters()
		and (self is HeroCard or self is SettlementCard)
	)
	_progression_badge.visible = show_progression
	if not show_progression:
		return
	_progression_label.text = "SV %d" % card_level
	_progression_badge.tooltip_text = "Seviye %d%s • Tecrübe %d/%d" % [
		card_level,
		" • %s" % selected_branch_name if not selected_branch_name.is_empty() else "",
		experience,
		get_next_level_experience(),
	]
	_refresh_runtime_state_rail_visibility()

func _create_combat_state_badge() -> void:
	if not _frame_panel or _combat_state_badge:
		return

	_combat_state_badge = Panel.new()
	_combat_state_badge.name = "CombatStateBadge"
	_combat_state_badge.anchor_left = 0.70
	_combat_state_badge.anchor_top = 0.018
	_combat_state_badge.anchor_right = 0.98
	_combat_state_badge.anchor_bottom = 0.092
	_combat_state_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_state_badge.z_index = 1 if _runtime_state_rail else CARD_CONTENT_Z_INDEX
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.08, 0.08, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.95, 0.36, 0.25, 0.95)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	_combat_state_badge.add_theme_stylebox_override("panel", style)
	var badge_parent: Control = _runtime_state_rail if _runtime_state_rail else _frame_panel
	badge_parent.add_child(_combat_state_badge)

	_combat_state_label = Label.new()
	_combat_state_label.name = "Label"
	_combat_state_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combat_state_label.text = "TÜKENDİ"
	_combat_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combat_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_state_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	_combat_state_label.add_theme_font_size_override("font_size", 8)
	_combat_state_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.78))
	_combat_state_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_combat_state_label.add_theme_constant_override("outline_size", 2)
	_combat_state_badge.add_child(_combat_state_label)
	_layout_runtime_state_badges()

func _refresh_combat_state_visual() -> void:
	var is_on_board := current_slot != null or _pending_slot != null
	var show_exhausted := is_on_board and not is_headquarters() and combat_state == CombatState.EXHAUSTED
	if _combat_state_badge:
		_combat_state_badge.visible = show_exhausted
	if _frame_panel:
		_frame_panel.modulate = Color.WHITE
	_refresh_runtime_state_rail_visibility()

func _layout_runtime_state_badges() -> void:
	if not _runtime_state_rail:
		return
	if _progression_badge:
		_set_template_control_rect(_progression_badge, Rect2(0.0, 0.0, 44.0, 20.0))
	if _effect_state_badge:
		_set_template_control_rect(_effect_state_badge, Rect2(46.0, 0.0, 50.0, 20.0))
	if _combat_state_badge:
		_set_template_control_rect(_combat_state_badge, Rect2(98.0, 0.0, 62.0, 20.0))

func _refresh_runtime_state_rail_visibility() -> void:
	if not _runtime_state_rail:
		return
	_runtime_state_rail.visible = bool(
		(_progression_badge and _progression_badge.visible)
		or (_effect_state_badge and _effect_state_badge.visible)
		or (_combat_state_badge and _combat_state_badge.visible)
	)

func _get_battlefield_ui() -> Node:
	var battlefield = get_tree().current_scene
	if not battlefield or not battlefield.has_method("show_toast"):
		battlefield = get_node_or_null("/root/Battlefield")
	return battlefield

func _get_card_type_key() -> String:
	return ""

func _get_card_type_display_name() -> String:
	return "Kart"

func _get_rarity_display_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "COMMON"
		Rarity.RARE:
			return "RARE"
		Rarity.EPIC:
			return "EPIC"
		Rarity.LEGENDARY:
			return "LEGENDARY"

	return "COMMON"

func _load_card_data_from_database() -> void:
	if card_id.is_empty():
		return

	var card_type = _get_card_type_key()
	if card_type.is_empty():
		push_error("Card type key is empty for card id: %s" % card_id)
		return

	var card_data = CardDatabase.get_card(card_type, card_id)
	if card_data.is_empty():
		return

	_apply_card_data(card_data)

func _apply_card_data(card_data: Dictionary) -> void:
	card_name = _get_string_from_card_data(card_data, "name", card_name)
	card_description = _get_string_from_card_data(card_data, "description", card_description)
	energy_cost = _get_int_from_card_data(
		card_data,
		"energy_cost",
		_get_int_from_card_data(card_data, "gold_cost", energy_cost)
	)
	rarity = _get_rarity_from_card_data(card_data.get("rarity", rarity), rarity)
	effect_id = _get_string_from_card_data(card_data, "effect_id", effect_id)

	var raw_effect_params: Variant = card_data.get("effect_params", {})
	effect_params = raw_effect_params.duplicate(true) if raw_effect_params is Dictionary else {}
	var raw_trait_values: Variant = card_data.get("trait_values", {})
	trait_values = raw_trait_values.duplicate(true) if raw_trait_values is Dictionary else {}
	var raw_level_paths: Variant = card_data.get("level_paths", {})
	level_paths = raw_level_paths.duplicate(true) if raw_level_paths is Dictionary else {}
	traits.clear()
	var raw_traits: Variant = card_data.get("tags", [])
	if raw_traits is Array:
		for raw_trait in raw_traits:
			var normalized_trait := str(raw_trait).strip_edges().to_lower()
			if not normalized_trait.is_empty() and normalized_trait not in traits:
				traits.append(normalized_trait)
	_reset_trait_runtime()

	var image_path = _get_string_from_card_data(card_data, "image_url", "")
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		var loaded_art = load(image_path)
		if loaded_art is Texture2D:
			card_art = loaded_art
	else:
		card_art = null

func _get_string_from_card_data(card_data: Dictionary, key: String, fallback: String) -> String:
	var value = card_data.get(key, fallback)
	if value == null:
		return fallback
	return str(value)

func _get_int_from_card_data(card_data: Dictionary, key: String, fallback: int) -> int:
	var value = card_data.get(key, fallback)
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			if value.is_valid_int():
				return value.to_int()

	return fallback

func _get_rarity_from_card_data(value: Variant, fallback: Rarity) -> Rarity:
	match typeof(value):
		TYPE_INT:
			var index = clampi(value, Rarity.COMMON, Rarity.LEGENDARY)
			return index as Rarity
		TYPE_FLOAT:
			var index = clampi(int(value), Rarity.COMMON, Rarity.LEGENDARY)
			return index as Rarity
		TYPE_STRING:
			match value.to_upper():
				"COMMON":
					return Rarity.COMMON
				"RARE":
					return Rarity.RARE
				"EPIC":
					return Rarity.EPIC
				"LEGENDARY":
					return Rarity.LEGENDARY

	return fallback

func _refresh_mouse_filter() -> void:
	if is_dragging:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif _is_snapping or _is_returning or _pending_slot:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif current_slot:
		# PASS keeps battlefield cards hoverable for the inspector while still
		# allowing their CardSlot parent to receive pointer events.
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif not is_draggable:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	
	if is_dragging or _is_snapping or _is_returning:
		z_index = _get_drag_z_index()
	elif current_slot or _pending_slot:
		z_index = 0
	else:
		z_index = _get_resting_z_index()

func _on_mouse_entered() -> void:
	var gm = GameManager.instance
	var face_down := _is_hand_face_down(gm)
	if face_down:
		return
		
	_is_hovered = true
	if not is_dragging and not _is_returning and not _is_snapping:
		z_index = 100 if current_slot == null else 0

func _get_resting_z_index() -> int:
	if has_meta(TRANSIENT_Z_INDEX_META):
		return int(get_meta(TRANSIENT_Z_INDEX_META, 0))
	return int(get_meta("hand_z_index", 0))

func _is_hand_face_down(gm: GameManager) -> bool:
	if is_public_preview:
		return false
	if not gm or current_slot != null or is_dragging:
		return false
	if MatchSetup.is_multiplayer_client():
		return owner_id != MatchSetup.human_player_id
	if MatchSetup.is_ai_match():
		return MatchSetup.is_ai_player(owner_id)
	return owner_id != gm.active_player_id

func _on_mouse_exited() -> void:
	_is_hovered = false
	if not is_dragging and not _is_returning and not _is_snapping:
		z_index = 0 if current_slot else _get_resting_z_index()

func _create_ui_nodes_if_missing() -> void:
	# 1. Base frame panel
	if has_node("CardFrame"):
		_frame_panel = get_node("CardFrame")
	else:
		_frame_panel = Panel.new()
		_frame_panel.name = "CardFrame"
		_frame_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_frame_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(_frame_panel)
		
	# 2. Art texture Rect
	if has_node("CardFrame/ArtRect"):
		_art_texture = get_node("CardFrame/ArtRect")
	else:
		_art_texture = TextureRect.new()
		_art_texture.name = "ArtRect"
		_art_texture.mouse_filter = Control.MOUSE_FILTER_PASS
		_art_texture.anchor_left = 0.08
		_art_texture.anchor_top = 0.08
		_art_texture.anchor_right = 0.92
		_art_texture.anchor_bottom = 0.55
		_frame_panel.add_child(_art_texture)
	_configure_card_art_rect()
		
	# 3. Name Label
	if has_node("CardFrame/NameLabel"):
		_name_lbl = get_node("CardFrame/NameLabel")
	else:
		_name_lbl = Label.new()
		_name_lbl.name = "NameLabel"
		_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_lbl.anchor_left = 0.08
		_name_lbl.anchor_top = 0.58
		_name_lbl.anchor_right = 0.92
		_name_lbl.anchor_bottom = 0.68
		_name_lbl.add_theme_font_size_override("font_size", 14)
		_name_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		_name_lbl.add_theme_constant_override("shadow_outline_size", 2)
		_frame_panel.add_child(_name_lbl)
		
	# 4. Description Label
	if has_node("CardFrame/DescLabel"):
		_desc_lbl = get_node("CardFrame/DescLabel")
	else:
		_desc_lbl = Label.new()
		_desc_lbl.name = "DescLabel"
		_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc_lbl.anchor_left = 0.08
		_desc_lbl.anchor_top = 0.70
		_desc_lbl.anchor_right = 0.92
		_desc_lbl.anchor_bottom = 0.92
		_desc_lbl.add_theme_font_size_override("font_size", 10)
		_desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		_frame_panel.add_child(_desc_lbl)
		
	# 5. Gold cost Badge and Label
	if has_node("CardFrame/GoldBadge"):
		_gold_panel = get_node("CardFrame/GoldBadge")
		_gold_lbl = get_node("CardFrame/GoldBadge/GoldLabel")
	else:
		_gold_panel = Panel.new()
		_gold_panel.name = "GoldBadge"
		_gold_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		_gold_panel.custom_minimum_size = Vector2(28, 28)
		_gold_panel.size = Vector2(28, 28)
		_gold_panel.position = Vector2(-6, -6)
		
		var gold_style = StyleBoxFlat.new()
		gold_style.bg_color = Color(0.85, 0.65, 0.15)
		gold_style.border_width_left = 2
		gold_style.border_width_top = 2
		gold_style.border_width_right = 2
		gold_style.border_width_bottom = 2
		gold_style.border_color = Color(1.0, 0.9, 0.5)
		gold_style.corner_radius_top_left = 14
		gold_style.corner_radius_top_right = 14
		gold_style.corner_radius_bottom_left = 14
		gold_style.corner_radius_bottom_right = 14
		_gold_panel.add_theme_stylebox_override("panel", gold_style)
		_frame_panel.add_child(_gold_panel)
		
		_gold_lbl = Label.new()
		_gold_lbl.name = "GoldLabel"
		_gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_gold_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_gold_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_gold_lbl.add_theme_font_size_override("font_size", 12)
		_gold_lbl.add_theme_color_override("font_color", Color.WHITE)
		_gold_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		_gold_lbl.add_theme_constant_override("shadow_outline_size", 2)
		_gold_panel.add_child(_gold_lbl)
		
	# 6. Card Back panel
	if has_node("CardBack"):
		_card_back_panel = get_node("CardBack")
	else:
		_card_back_panel = Panel.new()
		_card_back_panel.name = "CardBack"
		_card_back_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_card_back_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		_card_back_panel.clip_contents = true

		# A thin forged-metal rim protects the generated fantasy illustration.
		var back_style = StyleBoxFlat.new()
		back_style.bg_color = Color(0.032, 0.034, 0.04)
		back_style.border_width_left = 3
		back_style.border_width_top = 3
		back_style.border_width_right = 3
		back_style.border_width_bottom = 3
		back_style.border_color = Color(0.76, 0.55, 0.23)
		back_style.corner_radius_top_left = 10
		back_style.corner_radius_top_right = 10
		back_style.corner_radius_bottom_left = 10
		back_style.corner_radius_bottom_right = 10
		back_style.shadow_color = Color(0, 0, 0, 0.58)
		back_style.shadow_size = 8
		back_style.shadow_offset = Vector2(0, 5)
		_card_back_panel.add_theme_stylebox_override("panel", back_style)

		var back_art := TextureRect.new()
		back_art.name = "FantasyBackArt"
		back_art.anchor_right = 1.0
		back_art.anchor_bottom = 1.0
		back_art.offset_left = 4.0
		back_art.offset_top = 4.0
		back_art.offset_right = -4.0
		back_art.offset_bottom = -4.0
		back_art.texture = CARD_BACK_TEXTURE
		back_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back_art.stretch_mode = TextureRect.STRETCH_SCALE
		back_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		back_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_card_back_panel.add_child(back_art)

		add_child(_card_back_panel)

	_bind_optional_template_labels()
	_apply_base_text_styles()

func _bind_optional_template_labels() -> void:
	_template_background = get_node_or_null("CardFrame/TemplateBackground") as TextureRect
	_type_lbl = get_node_or_null("CardFrame/TypeLabel") as Label
	_rarity_lbl = get_node_or_null("CardFrame/RarityLabel") as Label
	_art_placeholder_lbl = get_node_or_null("CardFrame/ArtPlaceholderLabel") as Label
	_runtime_state_rail = get_node_or_null("CardFrame/RuntimeStateRail") as Panel
	if _runtime_state_rail:
		_runtime_state_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Rail (2) + badge (1) stays inside the card's three-level content band.
		_runtime_state_rail.z_index = 2
		var rail_style := StyleBoxFlat.new()
		rail_style.bg_color = Color(0.018, 0.020, 0.026, 0.92)
		rail_style.border_color = Color(0.62, 0.47, 0.24, 0.94)
		rail_style.set_border_width_all(1)
		rail_style.set_corner_radius_all(4)
		rail_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
		rail_style.shadow_size = 3
		rail_style.shadow_offset = Vector2(0.0, 1.0)
		_runtime_state_rail.add_theme_stylebox_override("panel", rail_style)

	# The illustration sits behind the alpha-cut frame. Labels and stat wells are
	# lifted above it by the shared styling helpers below.
	if _art_texture:
		_art_texture.z_index = 0
		_art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _template_background:
		_template_background.z_index = 1
		_template_background.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _configure_card_art_rect() -> void:
	if not _art_texture:
		return

	# Attach the custom drawing behavior to the existing TextureRect so scene
	# paths and any external node connections remain stable.
	if _art_texture.get_script() != TOP_ALIGNED_CARD_ART_SCRIPT:
		var previous_texture := _art_texture.texture
		_art_texture.set_script(TOP_ALIGNED_CARD_ART_SCRIPT)
		_art_texture.set("source_texture", previous_texture)

	_art_texture.texture = null
	_art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_texture.clip_contents = true
	var obsolete_backdrop := _frame_panel.get_node_or_null("ArtBackdrop")
	if obsolete_backdrop:
		obsolete_backdrop.queue_free()

func _apply_base_text_styles() -> void:
	_style_empty_panel(_gold_panel)
	_style_readable_label(_type_lbl)
	_style_readable_label(_rarity_lbl)
	_style_readable_label(_art_placeholder_lbl)
	_style_readable_label(_name_lbl)
	_style_readable_label(_desc_lbl)
	_style_readable_label(_gold_lbl)
	# GoldLabel is already inside the foreground GoldBadge. Keep it in that
	# layer instead of adding a second relative Z offset.
	if _gold_lbl:
		_gold_lbl.z_index = 0
	_set_label_font_size(_type_lbl, 13)
	_set_label_font_size(_rarity_lbl, 12)
	_set_label_font_size(_art_placeholder_lbl, 14)
	_set_label_font_size(_name_lbl, 16)
	_set_label_font_size(_desc_lbl, 11)
	_set_label_font_size(_gold_lbl, 16)
	for title_label in [_type_lbl, _rarity_lbl, _name_lbl, _gold_lbl]:
		if title_label:
			title_label.add_theme_font_override("font", UI.DISPLAY_FONT)
	if _desc_lbl:
		_desc_lbl.add_theme_font_override("font", UI.BODY_MEDIUM_FONT)
		_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_desc_lbl.max_lines_visible = 4
		_desc_lbl.clip_text = true
		_desc_lbl.add_theme_constant_override("line_spacing", -1)
	if _name_lbl:
		_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_name_lbl.clip_text = true

func _style_readable_label(label: Label, outline_size: int = 2) -> void:
	if not label:
		return

	label.z_index = 2
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_constant_override("shadow_outline_size", max(1, outline_size - 1))

	if label.label_settings:
		label.label_settings.font_color = Color(0.98, 0.96, 0.90)
		label.label_settings.outline_color = Color(0.0, 0.0, 0.0, 1.0)
		label.label_settings.outline_size = outline_size

func _set_label_font_size(label: Label, font_size: int) -> void:
	if not label:
		return

	label.add_theme_font_size_override("font_size", font_size)
	if label.label_settings:
		label.label_settings.font_size = font_size

func _style_empty_panel(panel: Panel) -> void:
	if not panel:
		return

	panel.z_index = 2
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _style_stat_badge(panel: Panel, label: Label) -> void:
	_style_empty_panel(panel)
	_style_readable_label(label)
	# The panel owns the local foreground layer; its text must not add another
	# relative Z offset and escape this card's compact stack band.
	if label:
		label.z_index = 0
	_set_label_font_size(label, 14)

func _set_template_control_rect(control: Control, rect: Rect2) -> void:
	if not control:
		return

	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

func _set_template_label_rect(label: Label, rect: Rect2, font_size: int) -> void:
	if not label:
		return

	_set_template_control_rect(label, rect)
	_set_label_font_size(label, font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true

func _set_template_badge_rect(panel: Panel, label: Label, rect: Rect2, font_size: int = 14) -> void:
	if not panel:
		return

	panel.custom_minimum_size = rect.size
	_set_template_control_rect(panel, rect)
	if not label:
		return

	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	_set_label_font_size(label, font_size)

func _set_template_value_badge(
	panel: Panel,
	value_label: Label,
	rect: Rect2,
	value_rect: Rect2,
	value_font_size: int
) -> void:
	if not panel or not value_label:
		return

	panel.custom_minimum_size = rect.size
	_set_template_control_rect(panel, rect)
	_set_template_label_rect(value_label, value_rect, value_font_size)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_constant_override("line_spacing", -2)

	# Semantic icons are part of the shared frame PNGs. Remove legacy runtime
	# children defensively so a reused card can never draw a duplicate icon.
	for legacy_name in ["CaptionLabel", "CaptionIcon", "LightningIcon"]:
		var legacy := panel.get_node_or_null(legacy_name)
		if legacy:
			legacy.queue_free()

func _get_existing_stat_badge(badge_name: String) -> Panel:
	var direct_badge = get_node_or_null("CardFrame/" + badge_name) as Panel
	if direct_badge:
		return direct_badge

	return get_node_or_null("CardFrame/StatsContainer/" + badge_name) as Panel

func _get_existing_stat_label(badge_name: String, label_name: String) -> Label:
	var badge = _get_existing_stat_badge(badge_name)
	if not badge:
		return null

	return badge.get_node_or_null(label_name) as Label

func _update_ui() -> void:
	if not is_inside_tree():
		return
		
	if _type_lbl:
		_type_lbl.text = tr(_get_card_type_display_name())
	if _rarity_lbl:
		_rarity_lbl.text = tr(_get_rarity_display_name())
	if _name_lbl:
		_name_lbl.text = tr(card_name)
	if _desc_lbl:
		_desc_lbl.text = tr(card_description)
	if _gold_lbl:
		_gold_lbl.text = str(energy_cost)
	if _art_texture:
		if card_art:
			_art_texture.texture = null
			_art_texture.set("source_texture", card_art)
			_art_texture.visible = true
		else:
			_art_texture.texture = null
			_art_texture.set("source_texture", null)
			_art_texture.visible = false
	if _art_placeholder_lbl:
		_art_placeholder_lbl.visible = card_art == null and not _has_template_background()

func _update_visuals() -> void:
	if not is_inside_tree():
		return

	if _template_background:
		if card_template:
			_template_background.texture = card_template
		if _template_background.texture:
			_template_background.visible = true
			_template_background.self_modulate = _get_template_rarity_tint()
			_frame_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			return
		_template_background.visible = false
		
	if card_template:
		var style_tex = StyleBoxTexture.new()
		style_tex.texture = card_template
		_frame_panel.add_theme_stylebox_override("panel", style_tex)
	else:
		var border_color = Color(0.6, 0.6, 0.6)
		match rarity:
			Rarity.COMMON:
				border_color = Color(0.6, 0.6, 0.6)
			Rarity.RARE:
				border_color = Color(0.12, 0.44, 0.88)
			Rarity.EPIC:
				border_color = Color(0.64, 0.21, 0.93)
			Rarity.LEGENDARY:
				border_color = Color(0.98, 0.50, 0.04)
				
		var style_flat = StyleBoxFlat.new()
		style_flat.bg_color = Color(0.12, 0.12, 0.14)
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

func _get_template_rarity_tint() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.80, 0.80, 0.76, 1.0)
		Rarity.RARE:
			return Color(0.55, 0.76, 1.00, 1.0)
		Rarity.EPIC:
			return Color(0.78, 0.54, 1.00, 1.0)
		Rarity.LEGENDARY:
			return Color(1.00, 0.72, 0.32, 1.0)

	return Color.WHITE

func _has_template_background() -> bool:
	return _template_background != null and _template_background.texture != null and _template_background.visible
