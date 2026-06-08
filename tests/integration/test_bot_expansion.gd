extends GutTest

# ── Integration Tests: Bot Expansion Algorithm ────────────────────────────────
# Tests score_vertex() and road_lookahead_score() from BotController.
#
# IMPORTANT: bot_controller.gd accesses the BoardState *autoload* (global
# singleton), not any locally instantiated node. All setup/teardown must
# operate on the global BoardState directly.

var BotController = preload("res://source/bot_controller.gd")


class MockGM extends Node:
	var players = []


class MockPlayer:
	var resources = {}
	var player_name: String = "Bot"
	var settlements_remaining: int = 5
	var cities_remaining: int = 4
	var roads_remaining: int = 15
	var points: int = 0

	func can_afford(cost: Dictionary) -> bool:
		for r in cost:
			if resources.get(r, 0) < cost[r]:
				return false
		return true


var controller: Node
var mock_gm: MockGM
var bot: MockPlayer


func before_each():
	# Clear the global singleton before every test
	BoardState.reset_state()

	controller = BotController.new()
	mock_gm = MockGM.new()
	bot = MockPlayer.new()
	mock_gm.players = [null, bot]
	controller.setup(mock_gm)
	add_child_autofree(controller)
	add_child_autofree(mock_gm)


func after_each():
	# Always clean up global state so tests are isolated
	BoardState.reset_state()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_hex(dice_number: int, resource_type: int) -> Node2D:
	var hex = Node2D.new()
	hex.set_meta("dice_number", dice_number)
	hex.set_meta("resource_type", resource_type)
	add_child_autofree(hex)
	return hex


# ── score_vertex ──────────────────────────────────────────────────────────────

func test_score_vertex_empty_links_scores_below_useful_vertex():
	# A vertex with no hex links gets the formula's floor value.
	# We verify a vertex with a good hex (6) always scores higher.
	var hex_6 = _make_hex(6, 0)
	BoardState.register_vertices(Vector2(0, 0))  # empty
	BoardState.register_vertices(Vector2(1, 1))
	BoardState.vertices[Vector2(1, 1)]["links"] = [hex_6]

	var score_empty = controller.score_vertex(Vector2(0, 0))
	var score_useful = controller.score_vertex(Vector2(1, 1))
	assert_true(score_useful > score_empty, "Vertex with hex should score higher than empty vertex")


func test_score_vertex_higher_for_better_numbers():
	var hex_6 = _make_hex(6, 0)  # wood, prob 5
	var hex_8 = _make_hex(8, 1)  # sheep, prob 5
	var hex_2 = _make_hex(2, 2)  # wheat, prob 1

	BoardState.register_vertices(Vector2(10, 10))
	BoardState.vertices[Vector2(10, 10)]["links"] = [hex_6, hex_8]

	BoardState.register_vertices(Vector2(20, 20))
	BoardState.vertices[Vector2(20, 20)]["links"] = [hex_2]

	var score_hot  = controller.score_vertex(Vector2(10, 10))
	var score_cold = controller.score_vertex(Vector2(20, 20))

	assert_true(score_hot > score_cold, "6/8 vertex should score higher than 2 vertex")


func test_score_vertex_diversity_bonus_for_different_resources():
	var hex_a = _make_hex(5, 0)  # wood
	var hex_b = _make_hex(6, 1)  # sheep — different resource

	BoardState.register_vertices(Vector2(30, 30))
	BoardState.vertices[Vector2(30, 30)]["links"] = [hex_a, hex_b]

	var hex_same1 = _make_hex(5, 0)  # wood
	var hex_same2 = _make_hex(6, 0)  # wood — same resource type
	BoardState.register_vertices(Vector2(40, 40))
	BoardState.vertices[Vector2(40, 40)]["links"] = [hex_same1, hex_same2]

	var score_diverse = controller.score_vertex(Vector2(30, 30))
	var score_mono    = controller.score_vertex(Vector2(40, 40))

	assert_true(score_diverse > score_mono, "Diverse resources should score higher")


func test_score_vertex_skips_desert_hex():
	var hex_desert = _make_hex(0, 5)  # dice_number == 0 → desert
	var hex_normal = _make_hex(6, 0)

	BoardState.register_vertices(Vector2(50, 50))
	BoardState.vertices[Vector2(50, 50)]["links"] = [hex_desert]

	BoardState.register_vertices(Vector2(60, 60))
	BoardState.vertices[Vector2(60, 60)]["links"] = [hex_normal]

	var score_desert = controller.score_vertex(Vector2(50, 50))
	var score_normal = controller.score_vertex(Vector2(60, 60))

	assert_true(score_normal > score_desert, "Desert vertex should score lower than real hex")


func test_score_vertex_coverage_bonus_for_3_different_resources():
	var hex_a = _make_hex(5, 0)  # wood
	var hex_b = _make_hex(6, 1)  # sheep
	var hex_c = _make_hex(9, 2)  # wheat

	BoardState.register_vertices(Vector2(70, 70))
	BoardState.vertices[Vector2(70, 70)]["links"] = [hex_a, hex_b, hex_c]

	var hex_x = _make_hex(5, 0)  # wood
	var hex_y = _make_hex(6, 1)  # sheep (only 2 different resources)
	BoardState.register_vertices(Vector2(80, 80))
	BoardState.vertices[Vector2(80, 80)]["links"] = [hex_x, hex_y]

	var score_3res = controller.score_vertex(Vector2(70, 70))
	var score_2res = controller.score_vertex(Vector2(80, 80))

	assert_true(score_3res > score_2res, "3-resource vertex gets coverage bonus")


# ── road_lookahead_score ──────────────────────────────────────────────────────

func test_road_lookahead_returns_zero_for_invalid_edge():
	var score = controller.road_lookahead_score(Vector2(999, 999), 1, 3)
	assert_eq(score, 0.0)


func test_road_lookahead_returns_zero_at_depth_zero():
	BoardState.register_edges(Vector2(0, 0), Vector2(100, 0))
	var score = controller.road_lookahead_score(Vector2(50, 0), 1, 0)
	assert_eq(score, 0.0)


func test_road_lookahead_scores_higher_toward_good_vertex():
	# Edge pointing toward a hot vertex (hex 6)
	var hex_6 = _make_hex(6, 0)
	BoardState.register_vertices(Vector2(100, 0))
	BoardState.vertices[Vector2(100, 0)]["links"] = [hex_6]
	BoardState.register_edges(Vector2(0, 0), Vector2(100, 0))
	var edge_good = Vector2(50, 0)

	# Edge pointing toward a cold vertex (hex 2)
	var hex_2 = _make_hex(2, 0)
	BoardState.register_vertices(Vector2(100, 200))
	BoardState.vertices[Vector2(100, 200)]["links"] = [hex_2]
	BoardState.register_edges(Vector2(0, 200), Vector2(100, 200))
	var edge_bad = Vector2(50, 200)

	var score_good = controller.road_lookahead_score(edge_good, 1, 1)
	var score_bad  = controller.road_lookahead_score(edge_bad,  1, 1)

	assert_true(score_good > score_bad, "Edge toward hot vertex should score higher")
