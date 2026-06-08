extends GutTest

var BotController = preload("res://source/bot_controller.gd")


class MockGM:
	extends Node
	var players = []


class MockPlayer:
	var resources = {}
	var player_name: String = "MockBot"
	var settlements_remaining: int = 5
	var cities_remaining: int = 4
	var roads_remaining: int = 15
	var points: int = 0

	func can_afford(cost: Dictionary) -> bool:
		for r in cost:
			if resources.get(r, 0) < cost[r]:
				return false
		return true

	func remove_resource(type: String, amount: int) -> void:
		resources[type] = max(0, resources.get(type, 0) - amount)

	func add_resource(type: String, amount: int) -> void:
		resources[type] = resources.get(type, 0) + amount


var controller: Node
var mock_gm: MockGM
var bot: MockPlayer
var real_bot: Player


func before_each():
	controller = BotController.new()
	mock_gm = MockGM.new()
	bot = MockPlayer.new()
	real_bot = Player.new("TestBot", Color.BLUE)
	mock_gm.players = [null, bot]
	controller.setup(mock_gm)
	add_child_autofree(controller)
	add_child_autofree(mock_gm)


func test_setup_stores_game_manager():
	assert_eq(controller.gm, mock_gm)


func test_choose_resource_returns_resource_with_zero():
	bot.resources = {"ore": 2, "wheat": 3, "sheep": 1, "wood": 0, "brick": 5}
	assert_eq(controller.choose_resource(1), "wood")


func test_choose_resource_returns_minimum_when_tied():
	bot.resources = {"ore": 0, "wheat": 3, "sheep": 1, "wood": 0, "brick": 5}
	var result = controller.choose_resource(1)
	assert_true(result == "ore" or result == "wood")


func test_choose_resource_returns_lowest_when_all_nonzero():
	bot.resources = {"ore": 5, "wheat": 4, "sheep": 3, "wood": 2, "brick": 1}
	assert_eq(controller.choose_resource(1), "brick")


func test_best_monopoly_returns_resource_others_have_most():
	var player0 = MockPlayer.new()
	player0.resources = {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}
	var player2 = MockPlayer.new()
	player2.resources = {"wood": 5, "brick": 1, "wheat": 0, "sheep": 0, "ore": 0}
	mock_gm.players = [player0, bot, player2]
	bot.resources = {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}
	assert_eq(controller.best_monopoly_resource(1), "wood")


func test_best_monopoly_ignores_self():
	bot.resources = {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 99}
	var player0 = MockPlayer.new()
	player0.resources = {"wood": 0, "brick": 0, "wheat": 3, "sheep": 0, "ore": 0}
	mock_gm.players = [player0, bot]
	assert_eq(controller.best_monopoly_resource(1), "wheat")


func test_accepts_trade_false_when_bot_lacks_required_resource():
	bot.resources = {"wood": 0, "brick": 5, "wheat": 5, "sheep": 5, "ore": 5}
	assert_false(controller.accepts_trade(1, ["brick"], ["wood"]))


func test_accepts_trade_true_when_receiving_scarce_resource():
	bot.resources = {"wood": 0, "brick": 5, "wheat": 5, "sheep": 5, "ore": 5}
	assert_true(controller.accepts_trade(1, ["wood"], ["brick"]))


func test_accepts_trade_false_when_giving_away_last_unit():
	bot.resources = {"wood": 5, "brick": 1, "wheat": 5, "sheep": 5, "ore": 5}
	assert_false(controller.accepts_trade(1, ["wood"], ["brick"]))


func test_count_resources_empty_array():
	var result = controller._count_resources([])
	assert_eq(result, {})


func test_count_resources_single():
	var result = controller._count_resources(["wood"])
	assert_eq(result["wood"], 1)


func test_count_resources_duplicates():
	var result = controller._count_resources(["ore", "ore", "ore", "wood"])
	assert_eq(result["ore"], 3)
	assert_eq(result["wood"], 1)


func test_can_reach_goal_with_trade_true_when_possible():
	real_bot.add_resource("wheat", 4)
	var surplus = ["wheat"]
	var goal = {"wood": 1}
	assert_true(controller._can_reach_goal_with_trade(real_bot, goal, surplus))


func test_can_reach_goal_with_trade_false_when_trade_doesnt_help():
	real_bot.add_resource("brick", 4)
	var surplus = ["brick"]
	var goal = {"wood": 1, "wheat": 1}
	assert_false(controller._can_reach_goal_with_trade(real_bot, goal, surplus))


func test_most_needed_returns_resource_with_largest_deficit():
	real_bot.add_resource("ore", 2)
	var goal = {"ore": 3, "wheat": 2}
	var result = controller._most_needed_for_goal(real_bot, goal)
	assert_eq(result, "wheat")


func test_most_needed_returns_empty_when_already_affordable():
	real_bot.add_resource("ore", 5)
	real_bot.add_resource("wheat", 5)
	var goal = {"ore": 3, "wheat": 2}
	var result = controller._most_needed_for_goal(real_bot, goal)
	assert_eq(result, "")


func test_least_needed_surplus_prefers_non_goal_resources():
	real_bot.add_resource("ore", 5)
	real_bot.add_resource("wheat", 8)
	real_bot.add_resource("wood", 4)
	var goal = {"ore": 3}
	var surplus = ["ore", "wheat"]
	var result = controller._least_needed_surplus(real_bot, goal, surplus)
	assert_eq(result, "wheat")


func test_least_needed_surplus_falls_back_to_goal_resource_if_only_option():
	real_bot.add_resource("ore", 6)
	real_bot.add_resource("wheat", 2)
	var goal = {"ore": 3}
	var surplus = ["ore"]
	var result = controller._least_needed_surplus(real_bot, goal, surplus)
	assert_eq(result, "ore")
