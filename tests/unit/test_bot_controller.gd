extends GutTest

# ── Unit Tests: BotController ─────────────────────────────────────────────────
# Tests all pure-logic functions of the BotController that do not require
# a scene tree: resource selection, monopoly picking, trade acceptance,
# vertex scoring helpers, and bank trade helpers.

var BotController = preload("res://source/bot_controller.gd")


class MockGM extends Node:
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


# ── Setup / Teardown ──────────────────────────────────────────────────────────

var controller: Node
var mock_gm: MockGM
var bot: MockPlayer


func before_each():
	controller = BotController.new()
	mock_gm = MockGM.new()
	bot = MockPlayer.new()
	mock_gm.players = [null, bot]
	controller.setup(mock_gm)
	add_child_autofree(controller)
	add_child_autofree(mock_gm)


# ── setup() ───────────────────────────────────────────────────────────────────

func test_setup_stores_game_manager():
	assert_eq(controller.gm, mock_gm)


# ── choose_resource() ─────────────────────────────────────────────────────────

func test_choose_resource_returns_resource_with_zero():
	bot.resources = {"ore": 2, "wheat": 3, "sheep": 1, "wood": 0, "brick": 5}
	assert_eq(controller.choose_resource(1), "wood")


func test_choose_resource_returns_minimum_when_tied():
	bot.resources = {"ore": 0, "wheat": 3, "sheep": 1, "wood": 0, "brick": 5}
	# Both ore and wood are 0; ore comes first in res_order
	var result = controller.choose_resource(1)
	assert_true(result == "ore" or result == "wood")


func test_choose_resource_returns_lowest_when_all_nonzero():
	bot.resources = {"ore": 5, "wheat": 4, "sheep": 3, "wood": 2, "brick": 1}
	# brick is lowest but res_order is ore/wheat/sheep/wood/brick
	# The loop picks the first minimum found in order — brick = 1 is lowest
	assert_eq(controller.choose_resource(1), "brick")


# ── best_monopoly_resource() ──────────────────────────────────────────────────

func test_best_monopoly_returns_resource_others_have_most():
	var player0 = MockPlayer.new()
	player0.resources = {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}
	var player2 = MockPlayer.new()
	player2.resources = {"wood": 5, "brick": 1, "wheat": 0, "sheep": 0, "ore": 0}
	mock_gm.players = [player0, bot, player2]
	bot.resources = {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}
	assert_eq(controller.best_monopoly_resource(1), "wood")


func test_best_monopoly_ignores_self():
	# bot has huge ore, but we measure what others have
	bot.resources = {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 99}
	var player0 = MockPlayer.new()
	player0.resources = {"wood": 0, "brick": 0, "wheat": 3, "sheep": 0, "ore": 0}
	mock_gm.players = [player0, bot]
	assert_eq(controller.best_monopoly_resource(1), "wheat")


# ── accepts_trade() ───────────────────────────────────────────────────────────

func test_accepts_trade_false_when_bot_lacks_required_resource():
	bot.resources = {"wood": 0, "brick": 5, "wheat": 5, "sheep": 5, "ore": 5}
	# Human gives wood, wants brick — bot must give wood but has none
	assert_false(controller.accepts_trade(1, ["brick"], ["wood"]))


func test_accepts_trade_true_when_receiving_scarce_resource():
	bot.resources = {"wood": 0, "brick": 5, "wheat": 5, "sheep": 5, "ore": 5}
	# Human gives wood (bot has 0 → score +3), bot gives brick (has 5, keeps 4 → no penalty)
	assert_true(controller.accepts_trade(1, ["wood"], ["brick"]))


func test_accepts_trade_false_when_giving_away_last_unit():
	bot.resources = {"wood": 5, "brick": 1, "wheat": 5, "sheep": 5, "ore": 5}
	# Bot gives its only brick (remaining = 0 → -2), receives wood it already has lots of (+1)
	# score = +1 - 2 = -1 → REFUSE
	assert_false(controller.accepts_trade(1, ["wood"], ["brick"]))


# ── _count_resources() helper ─────────────────────────────────────────────────

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


# ── _can_reach_goal_with_trade() ──────────────────────────────────────────────

func test_can_reach_goal_with_trade_true_when_possible():
	bot.resources = {"wood": 0, "brick": 0, "wheat": 4, "sheep": 0, "ore": 0}
	var surplus = ["wheat"]
	var goal = {"wood": 1}
	# Trading 4 wheat → 1 wood satisfies the goal
	assert_true(controller._can_reach_goal_with_trade(bot, goal, surplus))


func test_can_reach_goal_with_trade_false_when_trade_doesnt_help():
	bot.resources = {"wood": 0, "brick": 4, "wheat": 0, "sheep": 0, "ore": 0}
	# Goal needs wheat AND wood, but trading brick only gives 1 resource at a time
	var surplus = ["brick"]
	var goal = {"wood": 1, "wheat": 1}
	assert_false(controller._can_reach_goal_with_trade(bot, goal, surplus))


# ── _most_needed_for_goal() ───────────────────────────────────────────────────

func test_most_needed_returns_resource_with_largest_deficit():
	bot.resources = {"ore": 2, "wheat": 0}
	var goal = {"ore": 3, "wheat": 2}
	# ore deficit = 1, wheat deficit = 2 → wheat is most needed
	var result = controller._most_needed_for_goal(bot, goal)
	assert_eq(result, "wheat")


func test_most_needed_returns_empty_when_already_affordable():
	bot.resources = {"ore": 5, "wheat": 5}
	var goal = {"ore": 3, "wheat": 2}
	# No deficit at all
	var result = controller._most_needed_for_goal(bot, goal)
	assert_eq(result, "")


# ── _least_needed_surplus() ───────────────────────────────────────────────────

func test_least_needed_surplus_prefers_non_goal_resources():
	bot.resources = {"ore": 5, "wheat": 8, "wood": 4}
	var goal = {"ore": 3}
	var surplus = ["ore", "wheat"]
	# wheat is not in goal, so it's preferred
	var result = controller._least_needed_surplus(bot, goal, surplus)
	assert_eq(result, "wheat")


func test_least_needed_surplus_falls_back_to_goal_resource_if_only_option():
	bot.resources = {"ore": 6, "wheat": 2}
	var goal = {"ore": 3}
	var surplus = ["ore"]
	# ore is in goal but is the only surplus — fallback
	var result = controller._least_needed_surplus(bot, goal, surplus)
	assert_eq(result, "ore")
