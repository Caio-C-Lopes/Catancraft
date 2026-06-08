extends GutTest

var player: Player


func before_each():
	player = Player.new("Test", Color.WHITE)


func test_initial_resources_are_zero():
	for res in ["wood", "brick", "wheat", "sheep", "ore"]:
		assert_eq(player.resources[res], 0, "Initial %s should be 0" % res)


func test_add_resource_increases_amount():
	player.add_resource("wood", 3)
	assert_eq(player.resources["wood"], 3)


func test_add_multiple_calls_accumulate():
	player.add_resource("ore", 2)
	player.add_resource("ore", 3)
	assert_eq(player.resources["ore"], 5)


func test_remove_resource_decreases_amount():
	player.add_resource("wheat", 5)
	player.remove_resource("wheat", 3)
	assert_eq(player.resources["wheat"], 2)


func test_remove_resource_does_not_go_below_zero():
	player.add_resource("sheep", 1)
	player.remove_resource("sheep", 999)
	assert_eq(player.resources["sheep"], 0)


func test_add_invalid_resource_is_ignored():
	player.add_resource("gold", 10)
	assert_false(player.resources.has("gold"))


func test_remove_invalid_resource_is_ignored():
	player.remove_resource("diamonds", 5)
	assert_false(player.resources.has("diamonds"), "Should not add diamonds to resources")


func test_can_afford_true_when_has_exact_resources():
	player.add_resource("wood", 1)
	player.add_resource("brick", 1)
	assert_true(player.can_afford({"wood": 1, "brick": 1}))


func test_can_afford_true_when_has_more_than_needed():
	player.add_resource("ore", 10)
	assert_true(player.can_afford({"ore": 3}))


func test_can_afford_false_when_missing_one_resource():
	player.add_resource("wood", 1)
	player.add_resource("brick", 1)
	player.add_resource("sheep", 1)
	assert_false(player.can_afford({"wood": 1, "brick": 1, "wheat": 1, "sheep": 1}))


func test_can_afford_false_when_has_none():
	assert_false(player.can_afford({"wood": 1}))


func test_can_afford_empty_cost_is_always_true():
	assert_true(player.can_afford({}))


func test_add_dev_card_increases_hand():
	player.add_dev_card(0)
	assert_eq(player.dev_cards_in_hand, 1)
	assert_eq(player.dev_cards.size(), 1)


func test_add_dev_card_sets_bought_this_turn():
	player.add_dev_card(1)
	assert_true(player.dev_card_bought_this_turn)


func test_remove_dev_card_decreases_hand():
	player.add_dev_card(0)
	player.remove_dev_card(0)
	assert_eq(player.dev_cards_in_hand, 0)
	assert_eq(player.dev_cards.size(), 0)


func test_remove_dev_card_invalid_index_does_nothing():
	player.add_dev_card(0)
	player.remove_dev_card(99)
	assert_eq(player.dev_cards.size(), 1)


func test_remove_dev_card_negative_index_does_nothing():
	player.add_dev_card(0)
	player.remove_dev_card(-1)
	assert_eq(player.dev_cards.size(), 1)


func test_count_victory_point_cards_zero_when_no_vp_cards():
	player.add_dev_card(0)
	assert_eq(player.count_victory_point_cards(), 0)


func test_count_victory_point_cards_counts_correctly():
	player.add_dev_card(4)
	player.add_dev_card(5)
	player.add_dev_card(0)
	assert_eq(player.count_victory_point_cards(), 2)


func test_get_total_points_includes_vp_cards():
	player.points = 5
	player.add_dev_card(4)
	player.add_dev_card(7)
	assert_eq(player.get_total_points(), 7)


func test_get_total_points_without_vp_cards():
	player.points = 3
	assert_eq(player.get_total_points(), 3)


func test_reset_turn_flags_clears_played_card():
	player.played_dev_card_this_turn = true
	player.reset_turn_flags()
	assert_false(player.played_dev_card_this_turn)


func test_reset_turn_flags_clears_bought_card():
	player.add_dev_card(0)
	player.reset_turn_flags()
	assert_false(player.dev_card_bought_this_turn)


func test_initial_roads_remaining():
	assert_eq(player.roads_remaining, 15)


func test_initial_settlements_remaining():
	assert_eq(player.settlements_remaining, 5)


func test_initial_cities_remaining():
	assert_eq(player.cities_remaining, 4)


func test_initial_points():
	assert_eq(player.points, 0)
