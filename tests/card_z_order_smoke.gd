extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_battlefield := load("res://battlefield.tscn") as PackedScene
	_expect(packed_battlefield != null, "battlefield.tscn yüklenemedi")
	if not packed_battlefield:
		_finish()
		return

	var battlefield := packed_battlefield.instantiate() as BattlefieldUI
	root.add_child(battlefield)
	await process_frame
	var saw_animated_draw_card := false
	while battlefield._is_dealing_initial_hands:
		for child in battlefield.get_children():
			var animated_card := child as BaseCard
			if not animated_card:
				continue
			saw_animated_draw_card = true
			_expect(
				animated_card.z_index > battlefield._hand_dock.z_index,
				"%s dağıtılırken alt barın arkasında kalıyor" % animated_card.name
			)
		await process_frame
	_expect(saw_animated_draw_card, "Dağıtım Z sırasını doğrulayacak animasyon kartı görülmedi")

	var slots := get_nodes_in_group(CardSlot.GROUP_NAME)
	_expect(not slots.is_empty(), "Kart slotları bulunamadı")
	for draw_order in range(slots.size()):
		var slot := slots[draw_order] as CardSlot
		_expect(slot != null, "Geçersiz kart slotu bulundu")
		if not slot:
			continue
		_expect(
			slot.z_index == draw_order * CardSlot.Z_INDEX_STRIDE,
			"%s slotunun Z bandı sıralı değil" % slot.name
		)
		_expect(
			_max_relative_z(slot) <= CardSlot.CONTENT_Z_INDEX,
			"%s slotunun içeriği kendi Z bandını aşıyor" % slot.name
		)

	var hand := battlefield._get_hand_for_player(1)
	var cards: Array[BaseCard] = []
	for child in hand.get_children():
		if child is BaseCard:
			cards.append(child as BaseCard)
	_expect(cards.size() > 1, "El Z sıralamasını doğrulayacak yeterli kart yok")
	for card_index in range(cards.size()):
		var card := cards[card_index]
		var expected_z := (card_index + 1) * CardSlot.Z_INDEX_STRIDE
		_expect(card.z_index == expected_z, "%s el kartının Z indeksi yanlış" % card.name)
		_expect(
			_max_relative_z(card) <= CardSlot.CONTENT_Z_INDEX,
			"%s kart içeriği kendi Z bandını aşıyor" % card.name
		)
		if card_index + 1 < cards.size():
			var next_card := cards[card_index + 1]
			_expect(
				card.z_index + _max_relative_z(card) < next_card.z_index,
				"%s kartının ikonları sonraki kartın üstüne taşabilir" % card.name
			)

	battlefield.queue_free()
	await process_frame
	_finish()

func _max_relative_z(root_node: Node) -> int:
	return _max_relative_z_recursive(root_node, 0)

func _max_relative_z_recursive(node: Node, inherited_z: int) -> int:
	var max_z := inherited_z
	for child in node.get_children():
		var child_z := inherited_z
		if child is CanvasItem:
			var canvas_item := child as CanvasItem
			child_z = inherited_z + canvas_item.z_index if canvas_item.z_as_relative else canvas_item.z_index
		max_z = maxi(max_z, child_z)
		max_z = maxi(max_z, _max_relative_z_recursive(child, child_z))
	return max_z

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("CARD_Z_ORDER_SMOKE_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("CARD_Z_ORDER_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
