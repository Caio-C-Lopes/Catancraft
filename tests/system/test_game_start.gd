extends GutTest

var game_scene: Node
var _original_scene: Node


func before_all():
	GameConfig.bot_count = 1
	GameConfig.player_color_name = "red"
	GameConfig.player_icon_name = "steve"
	GameConfig.bot_icon_names = ["creeper"]
	GameConfig.bot_color_names = ["blue"]


func before_each():
	_original_scene = get_tree().current_scene
	game_scene = load("res://game.tscn").instantiate()
	get_tree().current_scene = game_scene
	add_child_autofree(game_scene)
	for _i in range(15):
		await get_tree().process_frame


func _gm() -> Node:
	return game_scene


func test_game_creates_correct_number_of_players():
	assert_eq(_gm().players.size(), 2, "Should have human + 1 bot")


func test_human_player_is_first():
	assert_eq(_gm().players[0].player_name, "Jogador 1")


func test_bot_player_exists():
	assert_eq(_gm().players[1].player_name, "Bot 1")


func test_all_players_start_with_zero_resources():
	for player in _gm().players:
		for res in ["wood", "brick", "wheat", "sheep", "ore"]:
			assert_eq(
				player.resources.get(res, 0),
				0,
				"%s should start with 0 %s" % [player.player_name, res]
			)


func test_all_players_start_with_zero_points():
	for player in _gm().players:
		assert_eq(player.points, 0)


func test_all_players_start_with_15_roads():
	for player in _gm().players:
		assert_eq(player.roads_remaining, 15)


func test_all_players_start_with_5_settlements():
	for player in _gm().players:
		assert_eq(player.settlements_remaining, 5)


func test_all_players_start_with_4_cities():
	for player in _gm().players:
		assert_eq(player.cities_remaining, 4)


func test_game_starts_in_preparation_phase():
	assert_eq(_gm().game_phase, _gm().GamePhase.PREPARATION)


func test_preparation_not_done_at_start():
	assert_false(_gm().preparation_done)


func test_first_player_index_is_valid():
	var idx = _gm().current_player_index
	assert_true(idx >= 0 and idx < _gm().players.size())


func test_preparation_order_has_correct_length():
	var expected = _gm().players.size() * 2
	assert_eq(_gm().preparation_order.size(), expected)


func test_preparation_order_contains_all_player_indices():
	var seen := {}
	for idx in _gm().preparation_order:
		seen[idx] = true
	for i in range(_gm().players.size()):
		assert_true(seen.has(i), "Player %d missing from preparation order" % i)


func test_dev_deck_is_not_empty_at_start():
	assert_false(_gm().deck_empty())


func test_dev_deck_has_no_more_than_25_cards():
	var deck: Array = _gm()._dev_deck
	assert_eq(deck.size(), 25)


func test_board_state_has_vertices():
	assert_false(
		BoardState.vertices.is_empty(), "BoardState should have vertices after scene loads"
	)


func test_board_state_has_edges():
	assert_false(BoardState.edges.is_empty(), "BoardState should have edges after scene loads")


func test_bot_controller_is_child_of_game_manager():
	assert_not_null(game_scene._bot_controller)


func test_bot_controller_has_game_manager_reference():
	assert_eq(game_scene._bot_controller.gm, game_scene)


func after_each():
	if _original_scene:
		get_tree().current_scene = _original_scene
		_original_scene = null

