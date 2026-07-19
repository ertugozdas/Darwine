class_name DominionResolver extends RefCounted

## Pure, deterministic Dominion control calculation. The battlefield supplies
## slot contents; GameManager owns scores and victory state.

const LANES: Array[int] = [
	CardSlot.Lane.LEFT,
	CardSlot.Lane.CENTER,
	CardSlot.Lane.RIGHT,
]


static func get_card_control_value(card: BaseCard) -> int:
	if not card or not is_instance_valid(card) or card.is_queued_for_deletion():
		return 0
	if card.is_headquarters() or card.get_current_health() <= 0:
		return 0
	if card is HeroCard:
		return GameRules.DOMINION_HERO_CONTROL
	if card is SettlementCard:
		return GameRules.DOMINION_STRUCTURE_CONTROL
	return 0


static func calculate_lane(battlefield: Node, lane_id: int) -> Dictionary:
	var control := {1: 0, 2: 0}
	if not battlefield or not battlefield.has_method("get_lane_slots"):
		return _lane_result(lane_id, control)
	for player_id in GameRules.PLAYER_IDS:
		var lane_slots_variant: Variant = battlefield.get_lane_slots(player_id, lane_id)
		if not lane_slots_variant is Array:
			continue
		for slot_variant in lane_slots_variant as Array:
			var slot := slot_variant as CardSlot
			if not slot or not slot.is_occupied or not slot.occupied_card is BaseCard:
				continue
			control[player_id] = int(control[player_id]) + get_card_control_value(slot.occupied_card as BaseCard)
	return _lane_result(lane_id, control)


static func calculate_board(battlefield: Node, round_number: int = 0) -> Dictionary:
	var lane_results: Array[Dictionary] = []
	var points_awarded := {1: 0, 2: 0}
	var total_control := {1: 0, 2: 0}
	for lane_id in LANES:
		var lane_result := calculate_lane(battlefield, lane_id)
		lane_results.append(lane_result)
		var control := lane_result.get("control", {}) as Dictionary
		for player_id in GameRules.PLAYER_IDS:
			total_control[player_id] = int(total_control[player_id]) + int(control.get(player_id, 0))
		var owner_id := int(lane_result.get("owner_id", 0))
		if owner_id in GameRules.PLAYER_IDS:
			points_awarded[owner_id] = int(points_awarded[owner_id]) + 1
	return {
		"round_number": round_number,
		"lane_results": lane_results,
		"points_awarded": points_awarded,
		"total_control": total_control,
	}


static func _lane_result(lane_id: int, control: Dictionary) -> Dictionary:
	var player_one := int(control.get(1, 0))
	var player_two := int(control.get(2, 0))
	var owner_id := 0
	if player_one != player_two:
		owner_id = 1 if player_one > player_two else 2
	return {
		"lane_id": lane_id,
		"lane_name": _lane_name(lane_id),
		"owner_id": owner_id,
		"control": {1: player_one, 2: player_two},
	}


static func _lane_name(lane_id: int) -> String:
	match lane_id:
		CardSlot.Lane.LEFT:
			return "SOL"
		CardSlot.Lane.CENTER:
			return "ORTA"
		CardSlot.Lane.RIGHT:
			return "SAĞ"
		_:
			return ""
