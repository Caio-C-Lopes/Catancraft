extends GutTest

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
	for _i in range(15):
		await get_tree().process_frame
	game_scene.game_phase = game_scene.GamePhase.PLAYING
	game_scene.current_player_index = 0
	game_scene.has_rolled_dice = true


func _gm() -> Node:
	return game_scene


func _human() -> Player:
	return game_scene.players[0]


func _give_cards(player: Player, card_types: Array) -> void:
	player.dev_cards.clear()
	player.dev_cards_in_hand = 0
	for t in card_types:
		player.dev_cards.append(t)
	player.dev_cards_in_hand = player.dev_cards.size()
	player.dev_card_bought_this_turn = false


func test_buy_dev_card_deducts_correct_resources():
	_human().add_resource("ore", 1)
	_human().add_resource("wheat", 1)
	_human().add_resource("sheep", 1)
	_gm().buy_dev_card(0)
	assert_eq(_human().resources["ore"], 0)
	assert_eq(_human().resources["wheat"], 0)
	assert_eq(_human().resources["sheep"], 0)


func test_buy_dev_card_adds_card_to_hand():
	_human().add_resource("ore", 1)
	_human().add_resource("wheat", 1)
	_human().add_resource("sheep", 1)
	_gm().buy_dev_card(0)
	assert_eq(_human().dev_cards.size(), 1)


func test_buy_dev_card_returns_true_on_success():
	_human().add_resource("ore", 1)
	_human().add_resource("wheat", 1)
	_human().add_resource("sheep", 1)
	assert_true(_gm().buy_dev_card(0))


func test_buy_dev_card_fails_without_resources():
	var result = _gm().buy_dev_card(0)
	assert_false(result)
	assert_eq(_human().dev_cards.size(), 0)


func test_buy_dev_card_fails_before_rolling_dice():
	game_scene.has_rolled_dice = false
	_human().add_resource("ore", 1)
	_human().add_resource("wheat", 1)
	_human().add_resource("sheep", 1)
	assert_false(_gm().buy_dev_card(0))


func test_cannot_buy_two_cards_in_same_turn():
	_human().add_resource("ore", 2)
	_human().add_resource("wheat", 2)
	_human().add_resource("sheep", 2)
	_gm().buy_dev_card(0)
	var result = _gm().buy_dev_card(0)
	assert_false(result, "Should not be able to buy a second dev card in the same turn")


func test_cannot_play_card_bought_same_turn():
	_human().add_resource("ore", 1)
	_human().add_resource("wheat", 1)
	_human().add_resource("sheep", 1)
	_gm().buy_dev_card(0)
	var card_type = _human().dev_cards[0]
	var result = _gm().play_dev_card(0, 0, card_type)
	assert_false(result, "Cannot play card bought this turn")


func test_cannot_play_two_cards_in_same_turn():
	_give_cards(_human(), [0, 0])

	_gm().play_dev_card(0, 0, 0)
	_human().played_dev_card_this_turn = true
	var result = _gm().play_dev_card(0, 0, 0)
	assert_false(result, "Cannot play a second card in the same turn")


func test_cannot_play_vp_card():
	_give_cards(_human(), [4])
	var result = _gm().play_dev_card(0, 0, 4)
	assert_false(result, "VP cards cannot be played manually")


func test_knight_increments_knights_played():
	_give_cards(_human(), [0])
	_gm().play_dev_card(0, 0, 0)
	assert_eq(_human().knights_played, 1)


func test_knight_removes_card_from_hand():
	_give_cards(_human(), [0])
	_gm().play_dev_card(0, 0, 0)
	assert_eq(_human().dev_cards.size(), 0)


func test_largest_army_awarded_at_3_knights():
	_human().knights_played = 2
	_give_cards(_human(), [0])
	_gm().play_dev_card(0, 0, 0)
	assert_eq(game_scene.largest_army_owner, 0, "Human should receive largest army at 3 knights")
	assert_eq(_human().points, 2, "Should receive +2 VP for largest army")


func test_largest_army_transfers_when_surpassed():
	game_scene.largest_army_owner = 0
	_human().knights_played = 3
	_human().points = 2

	var bot = game_scene.players[1]
	bot.knights_played = 3
	_give_cards(bot, [0])
	bot.dev_card_bought_this_turn = false

	_gm().play_dev_card(1, 0, 0)

	assert_eq(game_scene.largest_army_owner, 1, "Bot should steal largest army")
	assert_eq(_human().points, 0, "Human should lose the 2 VP")
	assert_eq(bot.points, 2, "Bot should gain the 2 VP")
