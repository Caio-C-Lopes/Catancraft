extends GutTest


class MockGM:
	var players: Array = []
	var current_player_index: int = 0
	var has_rolled_dice: bool = true

	func _count_resources(arr: Array) -> Dictionary:
		var counts := {}
		for r in arr:
			counts[r] = counts.get(r, 0) + 1
		return counts

	func execute_player_trade(a_id: int, b_id: int, a_gives: Array, b_gives: Array) -> void:
		var player_a = players[a_id]
		var player_b = players[b_id]
		var a_counts = _count_resources(a_gives)
		for res in a_counts:
			player_a.remove_resource(res, a_counts[res])
			player_b.add_resource(res, a_counts[res])
		var b_counts = _count_resources(b_gives)
		for res in b_counts:
			player_b.remove_resource(res, b_counts[res])
			player_a.add_resource(res, b_counts[res])

	func can_trade(human_id: int, give_res: Array) -> bool:
		var human = players[human_id]
		var give_counts = _count_resources(give_res)
		for res in give_counts:
			if human.resources.get(res, 0) < give_counts[res]:
				return false
		return true


var gm: MockGM
var human: Player
var bot: Player


func before_each():
	human = Player.new("Human", Color.WHITE)
	bot = Player.new("Bot", Color.BLUE)
	gm = MockGM.new()
	gm.players = [human, bot]


func test_trade_blocked_when_human_lacks_resource():
	human.add_resource("wood", 0)
	assert_false(gm.can_trade(0, ["wood"]))


func test_trade_allowed_when_human_has_exact_resources():
	human.add_resource("wood", 2)
	assert_true(gm.can_trade(0, ["wood", "wood"]))


func test_trade_blocked_when_human_has_less_than_required():
	human.add_resource("ore", 1)
	assert_false(gm.can_trade(0, ["ore", "ore"]))


func test_trade_transfers_wood_for_ore():
	human.add_resource("wood", 2)
	bot.add_resource("ore", 1)

	gm.execute_player_trade(0, 1, ["wood"], ["ore"])

	assert_eq(human.resources["wood"], 1)
	assert_eq(human.resources["ore"], 1)
	assert_eq(bot.resources["wood"], 1)
	assert_eq(bot.resources["ore"], 0)


func test_trade_multiple_resources_each_way():
	human.add_resource("wheat", 3)
	human.add_resource("sheep", 1)
	bot.add_resource("ore", 2)
	bot.add_resource("brick", 1)

	gm.execute_player_trade(0, 1, ["wheat", "wheat", "sheep"], ["ore", "ore", "brick"])

	assert_eq(human.resources["wheat"], 1)
	assert_eq(human.resources["sheep"], 0)
	assert_eq(human.resources["ore"], 2)
	assert_eq(human.resources["brick"], 1)
	assert_eq(bot.resources["wheat"], 2)
	assert_eq(bot.resources["sheep"], 1)
	assert_eq(bot.resources["ore"], 0)
	assert_eq(bot.resources["brick"], 0)


func test_trade_with_empty_b_gives_is_one_sided():
	human.add_resource("wood", 1)
	gm.execute_player_trade(0, 1, ["wood"], [])
	assert_eq(human.resources["wood"], 0)
	assert_eq(bot.resources["wood"], 1)


func test_trade_does_not_affect_other_resources():
	human.add_resource("wood", 1)
	human.add_resource("ore", 5)
	bot.add_resource("wheat", 1)
	bot.add_resource("brick", 5)

	gm.execute_player_trade(0, 1, ["wood"], ["wheat"])

	assert_eq(human.resources["ore"], 5, "Human ore should be untouched")
	assert_eq(bot.resources["brick"], 5, "Bot brick should be untouched")


func test_total_resources_are_conserved_after_trade():
	human.add_resource("wood", 3)
	human.add_resource("ore", 2)
	bot.add_resource("wheat", 4)
	bot.add_resource("sheep", 1)

	var total_wood_before = human.resources["wood"] + bot.resources.get("wood", 0)
	var total_ore_before = human.resources["ore"] + bot.resources.get("ore", 0)
	var total_wheat_before = human.resources.get("wheat", 0) + bot.resources["wheat"]

	gm.execute_player_trade(0, 1, ["wood", "wood"], ["wheat"])

	var total_wood_after = human.resources["wood"] + bot.resources["wood"]
	var total_ore_after = human.resources["ore"] + bot.resources.get("ore", 0)
	var total_wheat_after = human.resources["wheat"] + bot.resources["wheat"]

	assert_eq(total_wood_after, total_wood_before, "Wood total should be conserved")
	assert_eq(total_ore_after, total_ore_before, "Ore total should be conserved")
	assert_eq(total_wheat_after, total_wheat_before, "Wheat total should be conserved")
