extends GutTest

# ── System Tests: Construction Rules ─────────────────────────────────────────
# Loads the full game scene and tests the construction validation functions
# (village_construction_check, road_construction_check, city_construction_check)
# using real BoardState data populated by the scene.
#
# These tests verify the game enforces Catan's building rules correctly from
# end to end: no building on occupied vertex, no road without connection, etc.

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


func _gm() -> Node:
	return game_scene


func _first_free_vertex() -> Variant:
	for key in BoardState.vertices:
		if BoardState.vertices[key]["owner"] == null:
			return key
	return null


func _first_free_edge() -> Variant:
	for key in BoardState.edges:
		if BoardState.edges[key]["owner"] == null:
			return key
	return null


# ── village_construction_check ────────────────────────────────────────────────


func test_village_check_true_for_free_vertex_in_preparation():
	var vertex = _first_free_vertex()
	if vertex == null:
		pass  # skip if board not populated yet
		return
	assert_true(
		_gm().village_construction_check(vertex, 0, true),
		"Should be able to place in preparation on any free, non-adjacent vertex"
	)


func test_village_check_false_for_occupied_vertex():
	var vertex = _first_free_vertex()
	if vertex == null:
		return
	# Manually occupy the vertex
	BoardState.vertices[vertex]["owner"] = 0
	assert_false(
		_gm().village_construction_check(vertex, 1, true), "Cannot build on an occupied vertex"
	)
	BoardState.vertices[vertex]["owner"] = null  # cleanup


func test_village_check_false_for_adjacent_occupied_vertex():
	# Find an edge, occupy one endpoint, check the other fails
	var edge_key = _first_free_edge()
	if edge_key == null:
		return
	var edge = BoardState.edges[edge_key]
	var vertex_a = edge["a_vertice"]
	var vertex_b = edge["b_vertice"]

	BoardState.vertices[vertex_a]["owner"] = 0
	assert_false(
		_gm().village_construction_check(vertex_b, 1, true),
		"Cannot build adjacent to an existing settlement"
	)
	BoardState.vertices[vertex_a]["owner"] = null  # cleanup


func test_village_check_false_without_road_outside_preparation():
	var vertex = _first_free_vertex()
	if vertex == null:
		return
	# No roads owned by player 0 at all → should fail outside preparation
	assert_false(
		_gm().village_construction_check(vertex, 0, false),
		"Cannot build settlement without a connecting road outside preparation"
	)


# ── road_construction_check ───────────────────────────────────────────────────


func test_road_check_false_for_nonexistent_edge():
	assert_false(
		_gm().road_construction_check(Vector2(99999, 99999), 0), "Nonexistent edge should fail"
	)


func test_road_check_false_for_occupied_edge():
	var edge_key = _first_free_edge()
	if edge_key == null:
		return
	# Also set a vertex so it's connectable, then occupy the edge
	var edge = BoardState.edges[edge_key]
	BoardState.vertices[edge["a_vertice"]]["owner"] = 0
	BoardState.edges[edge_key]["owner"] = 1  # owned by someone else

	assert_false(
		_gm().road_construction_check(edge_key, 0), "Cannot build on an already-owned edge"
	)
	BoardState.edges[edge_key]["owner"] = null
	BoardState.vertices[edge["a_vertice"]]["owner"] = null


func test_road_check_true_when_player_owns_adjacent_vertex():
	var edge_key = _first_free_edge()
	if edge_key == null:
		return

	# Put game into PLAYING phase so preparation rules don't interfere
	game_scene.game_phase = game_scene.GamePhase.PLAYING

	var edge = BoardState.edges[edge_key]
	BoardState.vertices[edge["a_vertice"]]["owner"] = 0
	assert_true(
		_gm().road_construction_check(edge_key, 0),
		"Should be able to build road connected to own vertex"
	)
	BoardState.vertices[edge["a_vertice"]]["owner"] = null


# ── city_construction_check ───────────────────────────────────────────────────


func test_city_check_false_when_vertex_not_owned_by_player():
	var vertex = _first_free_vertex()
	if vertex == null:
		return
	# Free vertex — not a village, not owned
	# city_construction_check doesn't guard against missing key, so ensure it exists
	assert_false(
		_gm().city_construction_check(vertex, 0), "Cannot upgrade vertex that is not your village"
	)


func test_city_check_false_when_player_cannot_afford():
	var vertex = _first_free_vertex()
	if vertex == null:
		return
	BoardState.vertices[vertex]["owner"] = 0
	BoardState.vertices[vertex]["type"] = BoardState.BuildingType.VILLAGE
	# Player 0 has no resources → cannot afford city (ore:3, wheat:2)
	assert_false(
		_gm().city_construction_check(vertex, 0), "Cannot build city without enough resources"
	)
	BoardState.vertices[vertex]["owner"] = null
	BoardState.vertices[vertex]["type"] = BoardState.BuildingType.NONE


func test_city_check_true_when_player_has_village_and_resources():
	var vertex = _first_free_vertex()
	if vertex == null:
		return
	var player = game_scene.players[0]
	player.add_resource("ore", 3)
	player.add_resource("wheat", 2)
	BoardState.vertices[vertex]["owner"] = 0
	BoardState.vertices[vertex]["type"] = BoardState.BuildingType.VILLAGE
	assert_true(
		_gm().city_construction_check(vertex, 0),
		"Should be able to upgrade village to city with enough resources"
	)
	# Cleanup state (city_construction_check deducts resources as a side effect)
	BoardState.vertices[vertex]["owner"] = null
	BoardState.vertices[vertex]["type"] = BoardState.BuildingType.NONE


# ── Victory condition ─────────────────────────────────────────────────────────


func test_victory_not_triggered_below_10_points():
	game_scene.game_phase = game_scene.GamePhase.PLAYING
	game_scene.players[0].points = 9
	# _check_victory should not pause or change scene at 9 points
	# We test indirectly: tree should not be paused after the call
	game_scene._check_victory(0)
	assert_false(get_tree().paused, "Game should not be over at 9 points")


func test_victory_triggered_at_10_points():
	game_scene.game_phase = game_scene.GamePhase.PLAYING
	game_scene.players[0].points = 10
	game_scene._check_victory(0)
	# The victory screen pauses the tree
	assert_true(get_tree().paused, "Game should be paused when a player reaches 10 points")
	# Cleanup: unpause so other tests aren't affected
	get_tree().paused = false


func test_victory_not_triggered_during_preparation():
	game_scene.game_phase = game_scene.GamePhase.PREPARATION
	game_scene.players[0].points = 99
	game_scene._check_victory(0)
	assert_false(get_tree().paused, "Victory should not trigger during preparation phase")
