extends GutTest

# ── System Tests: Game Startup ────────────────────────────────────────────────
# Loads the full game scene and verifies the initial game state from the
# perspective of an external observer: correct number of players, resources
# starting at zero, preparation phase active, correct piece counts.
#
# These tests are slow (full scene load) but test the real integration
# between GameConfig → GameManager → Players → BoardState.

var game_scene: Node


func before_all():
	# Configure a minimal, deterministic game: 1 human + 1 bot
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


func _gm() -> Node:
	return game_scene


# ── Players are created correctly ─────────────────────────────────────────────

func test_game_creates_correct_number_of_players():
	assert_eq(_gm().players.size(), 2, "Should have human + 1 bot")


func test_human_player_is_first():
	assert_eq(_gm().players[0].player_name, "Jogador 1")


func test_bot_player_exists():
	assert_eq(_gm().players[1].player_name, "Bot 1")


# ── Initial resource state ────────────────────────────────────────────────────

func test_all_players_start_with_zero_resources():
	for player in _gm().players:
		for res in ["wood", "brick", "wheat", "sheep", "ore"]:
			assert_eq(
				player.resources.get(res, 0), 0,
				"%s should start with 0 %s" % [player.player_name, res]
			)


func test_all_players_start_with_zero_points():
	for player in _gm().players:
		assert_eq(player.points, 0)


# ── Initial piece counts ──────────────────────────────────────────────────────

func test_all_players_start_with_15_roads():
	for player in _gm().players:
		assert_eq(player.roads_remaining, 15)


func test_all_players_start_with_5_settlements():
	for player in _gm().players:
		assert_eq(player.settlements_remaining, 5)


func test_all_players_start_with_4_cities():
	for player in _gm().players:
		assert_eq(player.cities_remaining, 4)


# ── Game phase ────────────────────────────────────────────────────────────────

func test_game_starts_in_preparation_phase():
	assert_eq(_gm().game_phase, _gm().GamePhase.PREPARATION)


func test_preparation_not_done_at_start():
	assert_false(_gm().preparation_done)


func test_first_player_index_is_valid():
	var idx = _gm().current_player_index
	assert_true(idx >= 0 and idx < _gm().players.size())


# ── Preparation order ─────────────────────────────────────────────────────────

func test_preparation_order_has_correct_length():
	# n players → 2n steps (forward + reverse)
	var expected = _gm().players.size() * 2
	assert_eq(_gm().preparation_order.size(), expected)


func test_preparation_order_contains_all_player_indices():
	var seen := {}
	for idx in _gm().preparation_order:
		seen[idx] = true
	for i in range(_gm().players.size()):
		assert_true(seen.has(i), "Player %d missing from preparation order" % i)


# ── Dev deck ─────────────────────────────────────────────────────────────────

func test_dev_deck_is_not_empty_at_start():
	assert_false(_gm().deck_empty())


func test_dev_deck_has_no_more_than_25_cards():
	# Access the internal deck — we verify the total matches the Catan standard
	var deck: Array = _gm()._dev_deck
	assert_eq(deck.size(), 25)


# ── BoardState is populated ───────────────────────────────────────────────────

func test_board_state_has_vertices():
	assert_false(BoardState.vertices.is_empty(), "BoardState should have vertices after scene loads")


func test_board_state_has_edges():
	assert_false(BoardState.edges.is_empty(), "BoardState should have edges after scene loads")


# ── BotController is initialized ─────────────────────────────────────────────

func test_bot_controller_is_child_of_game_manager():
	var bot_ctrl = _gm().find_child("BotController")
	assert_not_null(bot_ctrl)


func test_bot_controller_has_game_manager_reference():
	var bot_ctrl = _gm().find_child("BotController")
	assert_eq(bot_ctrl.gm, _gm())
