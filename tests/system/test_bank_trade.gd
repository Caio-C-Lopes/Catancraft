extends GutTest

# ── System Tests: Bank Trade ──────────────────────────────────────────────────
# Loads the full game scene and tests the 4:1 bank trade flow end-to-end:
# resource deduction from player, credit to bank, resource receipt from bank,
# and all guard conditions (insufficient resources, wrong phase, bank empty).

var game_scene: Node


func before_all():
	GameConfig.bot_count = 1
	GameConfig.player_color_name = "red"
	GameConfig.player_icon_name = "steve"
	GameConfig.bot_icon_names = ["creeper"]
	GameConfig.bot_color_names = ["blue"]


func before_each():
	game_scene = load("res://game.tscn").instantiate()
	add_child_autofree(game_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	# Put game into PLAYING phase with dice rolled so trades are allowed
	game_scene.game_phase = game_scene.GamePhase.PLAYING
	game_scene.current_player_index = 0
	game_scene.has_rolled_dice = true


func _gm() -> Node:
	return game_scene


func _human() -> Player:
	return game_scene.players[0]


# ── Happy path ────────────────────────────────────────────────────────────────

func test_bank_trade_deducts_4_give_resources_from_player():
	_human().add_resource("wood", 4)
	_gm().execute_bank_trade(0, "wood", "ore")
	assert_eq(_human().resources["wood"], 0)


func test_bank_trade_gives_1_recv_resource_to_player():
	_human().add_resource("wood", 4)
	_gm().execute_bank_trade(0, "wood", "ore")
	assert_eq(_human().resources["ore"], 1)


func test_bank_trade_returns_true_on_success():
	_human().add_resource("sheep", 4)
	var result = _gm().execute_bank_trade(0, "sheep", "wheat")
	assert_true(result)


func test_bank_trade_preserves_other_resources():
	_human().add_resource("brick", 4)
	_human().add_resource("ore", 3)
	_gm().execute_bank_trade(0, "brick", "wheat")
	assert_eq(_human().resources["ore"], 3, "Ore should be untouched")


# ── Guard conditions ──────────────────────────────────────────────────────────

func test_bank_trade_fails_when_player_has_fewer_than_4():
	_human().add_resource("wood", 3)
	var result = _gm().execute_bank_trade(0, "wood", "ore")
	assert_false(result)
	assert_eq(_human().resources["wood"], 3, "Wood should not be deducted on failure")


func test_bank_trade_fails_when_dice_not_rolled():
	game_scene.has_rolled_dice = false
	_human().add_resource("wheat", 4)
	var result = _gm().execute_bank_trade(0, "wheat", "ore")
	assert_false(result)
	assert_eq(_human().resources["wheat"], 4)


func test_bank_trade_fails_when_not_human_turn():
	game_scene.current_player_index = 1
	_human().add_resource("ore", 4)
	var result = _gm().execute_bank_trade(0, "ore", "wood")
	assert_false(result)


func test_bank_trade_bot_can_trade_without_phase_restriction():
	# Bots are not restricted by has_rolled_dice / current_player_index
	var bot = game_scene.players[1]
	bot.add_resource("brick", 4)
	var result = _gm().execute_bank_trade(1, "brick", "wheat")
	assert_true(result)
	assert_eq(bot.resources["brick"], 0)
	assert_eq(bot.resources["wheat"], 1)


# ── Resource conservation ────────────────────────────────────────────────────

func test_bank_trade_conserves_total_resources_in_system():
	_human().add_resource("sheep", 4)
	var bank = game_scene.bank_panel
	var sheep_before = bank.bank_amounts["sheep"]
	var ore_before = bank.bank_amounts["ore"]

	_gm().execute_bank_trade(0, "sheep", "ore")

	# Player gave 4 sheep → bank gets them back
	assert_eq(bank.bank_amounts["sheep"], sheep_before + 4)
	# Bank gave 1 ore to player
	assert_eq(bank.bank_amounts["ore"], ore_before - 1)


# ── Monopoly card logic ───────────────────────────────────────────────────────

func test_monopoly_steals_from_all_bots():
	var bot = game_scene.players[1]
	bot.add_resource("wheat", 5)
	_human().add_resource("wheat", 1)

	game_scene._execute_monopoly(0, "wheat")

	assert_eq(_human().resources["wheat"], 1 + 5)
	assert_eq(bot.resources["wheat"], 0)


func test_monopoly_no_effect_when_others_have_none():
	var before = _human().resources["ore"]
	game_scene._execute_monopoly(0, "ore")
	assert_eq(_human().resources["ore"], before)
