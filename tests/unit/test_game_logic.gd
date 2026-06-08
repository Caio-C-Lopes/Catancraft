extends GutTest


class ResourceMapper:
	func map(type: int) -> String:
		match type:
			0:
				return "wood"
			1:
				return "sheep"
			2:
				return "wheat"
			3:
				return "brick"
			4:
				return "ore"
			_:
				return ""


func test_resource_type_0_is_wood():
	var m = ResourceMapper.new()
	assert_eq(m.map(0), "wood")


func test_resource_type_1_is_sheep():
	var m = ResourceMapper.new()
	assert_eq(m.map(1), "sheep")


func test_resource_type_2_is_wheat():
	var m = ResourceMapper.new()
	assert_eq(m.map(2), "wheat")


func test_resource_type_3_is_brick():
	var m = ResourceMapper.new()
	assert_eq(m.map(3), "brick")


func test_resource_type_4_is_ore():
	var m = ResourceMapper.new()
	assert_eq(m.map(4), "ore")


func test_resource_type_unknown_is_empty():
	var m = ResourceMapper.new()
	assert_eq(m.map(99), "")


func _count_resources(arr: Array) -> Dictionary:
	var counts := {}
	for r in arr:
		counts[r] = counts.get(r, 0) + 1
	return counts


func test_count_resources_empty():
	assert_eq(_count_resources([]), {})


func test_count_resources_single_item():
	assert_eq(_count_resources(["wood"]), {"wood": 1})


func test_count_resources_multiple_same():
	var result = _count_resources(["ore", "ore", "ore"])
	assert_eq(result["ore"], 3)


func test_count_resources_mixed():
	var result = _count_resources(["wood", "ore", "wood"])
	assert_eq(result["wood"], 2)
	assert_eq(result["ore"], 1)


func _execute_trade(player_a: Player, player_b: Player, a_gives: Array, b_gives: Array) -> void:
	var a_counts = _count_resources(a_gives)
	for res in a_counts:
		player_a.remove_resource(res, a_counts[res])
		player_b.add_resource(res, a_counts[res])
	var b_counts = _count_resources(b_gives)
	for res in b_counts:
		player_b.remove_resource(res, b_counts[res])
		player_a.add_resource(res, b_counts[res])


func test_execute_trade_transfers_resources_correctly():
	var p1 = Player.new("A", Color.WHITE)
	var p2 = Player.new("B", Color.RED)
	p1.add_resource("wood", 3)
	p2.add_resource("ore", 2)

	_execute_trade(p1, p2, ["wood", "wood"], ["ore"])

	assert_eq(p1.resources["wood"], 1)
	assert_eq(p1.resources["ore"], 1)
	assert_eq(p2.resources["wood"], 2)
	assert_eq(p2.resources["ore"], 1)


func test_execute_trade_with_empty_b_gives():
	var p1 = Player.new("A", Color.WHITE)
	var p2 = Player.new("B", Color.RED)
	p1.add_resource("sheep", 2)

	_execute_trade(p1, p2, ["sheep"], [])

	assert_eq(p1.resources["sheep"], 1)
	assert_eq(p2.resources["sheep"], 1)


func _execute_monopoly(players: Array, stealer_id: int, resource: String) -> void:
	for i in range(players.size()):
		if i == stealer_id:
			continue
		var amount: int = players[i].resources.get(resource, 0)
		if amount > 0:
			players[i].remove_resource(resource, amount)
			players[stealer_id].add_resource(resource, amount)


func test_monopoly_steals_from_all_others():
	var p0 = Player.new("Human", Color.WHITE)
	var p1 = Player.new("Bot1", Color.BLUE)
	var p2 = Player.new("Bot2", Color.RED)
	p1.add_resource("wheat", 3)
	p2.add_resource("wheat", 2)
	p0.add_resource("wheat", 1)

	_execute_monopoly([p0, p1, p2], 0, "wheat")

	assert_eq(p0.resources["wheat"], 1 + 3 + 2)
	assert_eq(p1.resources["wheat"], 0)
	assert_eq(p2.resources["wheat"], 0)


func test_monopoly_no_effect_when_others_have_none():
	var p0 = Player.new("Human", Color.WHITE)
	var p1 = Player.new("Bot1", Color.BLUE)

	_execute_monopoly([p0, p1], 0, "ore")

	assert_eq(p0.resources["ore"], 0)


const DEV_CARD_COUNTS := {0: 14, 1: 2, 2: 2, 3: 2, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1}


func _build_dev_deck() -> Array:
	var deck: Array[int] = []
	for card_type in DEV_CARD_COUNTS:
		for _i in range(DEV_CARD_COUNTS[card_type]):
			deck.append(card_type)
	return deck


func test_dev_deck_has_25_cards():
	var deck = _build_dev_deck()
	assert_eq(deck.size(), 25)


func test_dev_deck_has_14_knights():
	var deck = _build_dev_deck()
	var count = deck.filter(func(c): return c == 0).size()
	assert_eq(count, 14)


func test_dev_deck_has_5_vp_cards():
	var deck = _build_dev_deck()
	var vp_count = deck.filter(func(c): return c in [4, 5, 6, 7, 8]).size()
	assert_eq(vp_count, 5)


func test_dev_deck_has_correct_action_cards():
	var deck = _build_dev_deck()
	assert_eq(deck.filter(func(c): return c == 1).size(), 2)
	assert_eq(deck.filter(func(c): return c == 2).size(), 2)
	assert_eq(deck.filter(func(c): return c == 3).size(), 2)


func _build_preparation_order(n: int, first: int) -> Array:
	var order: Array = []
	for i in range(n):
		order.append((first + i) % n)
	for i in range(n - 1, -1, -1):
		order.append((first + i) % n)
	return order


func test_preparation_order_length_for_4_players():
	var order = _build_preparation_order(4, 0)
	assert_eq(order.size(), 4 * 2)


func test_preparation_order_has_forward_and_reverse():
	var order = _build_preparation_order(3, 0)
	assert_eq(order, [0, 1, 2, 2, 1, 0])


func test_preparation_order_wraps_from_non_zero_start():
	var order = _build_preparation_order(3, 2)
	assert_eq(order[0], 2)
	assert_eq(order[1], 0)
	assert_eq(order[2], 1)
