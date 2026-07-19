extends Node

var _lane_slots: Dictionary = {}
var _hq_slots: Dictionary = {}

func create_lane_slot(player_id: int, lane_id: int, position_type: CardSlot.PositionType) -> CardSlot:
	var slot := CardSlot.new()
	slot.owner_id = player_id
	slot.lane_id = lane_id as CardSlot.Lane
	slot.position_type = position_type
	slot.name = "P%d_L%d_%d" % [player_id, lane_id, int(position_type)]
	add_child(slot)
	var key := _lane_key(player_id, lane_id)
	var slots: Array = _lane_slots.get(key, [])
	slots.append(slot)
	slots.sort_custom(func(a: CardSlot, b: CardSlot): return int(a.position_type) < int(b.position_type))
	_lane_slots[key] = slots
	return slot

func create_hq_slot(player_id: int) -> CardSlot:
	var slot := CardSlot.new()
	slot.owner_id = player_id
	slot.lane_id = CardSlot.Lane.NONE
	slot.position_type = CardSlot.PositionType.HQ
	slot.is_hq_slot = true
	slot.name = "P%d_HQ" % player_id
	add_child(slot)
	_hq_slots[player_id] = slot
	return slot

func get_lane_slots(player_id: int, lane_id: int) -> Array:
	return (_lane_slots.get(_lane_key(player_id, lane_id), []) as Array).duplicate()

func is_lane_open(player_id: int, lane_id: int) -> bool:
	var slots: Array = get_lane_slots(player_id, lane_id)
	if slots.size() != 3:
		return false
	for slot_variant in slots:
		var slot := slot_variant as CardSlot
		if slot and slot.is_occupied:
			return false
	return true

func get_hq_slot(player_id: int) -> CardSlot:
	return _hq_slots.get(player_id) as CardSlot

func resurrect_hero_from_record(
	record: Dictionary,
	target_slot: CardSlot,
	owner_id: int
) -> HeroCard:
	if (
		record.is_empty()
		or not target_slot
		or target_slot.is_occupied
		or target_slot.owner_id != owner_id
		or target_slot.position_type != CardSlot.PositionType.BACK
	):
		return null
	var hero := HeroCard.new()
	hero.owner_id = owner_id
	hero.card_id = str(record.get("card_id", ""))
	target_slot.add_child(hero)
	hero.reset_progression()
	hero.health = 1
	hero.set_combat_state(BaseCard.CombatState.EXHAUSTED)
	return hero

func _lane_key(player_id: int, lane_id: int) -> String:
	return "%d:%d" % [player_id, lane_id]
