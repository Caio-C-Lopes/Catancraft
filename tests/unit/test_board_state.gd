extends GutTest

var board_state: Node


func before_each():
	board_state = load("res://source/board_state.gd").new()
	add_child_autofree(board_state)


func test_register_vertex_creates_entry():
	board_state.register_vertices(Vector2(100, 200))
	assert_true(board_state.vertices.has(Vector2(100, 200)))


func test_register_vertex_default_state():
	board_state.register_vertices(Vector2(10, 20))
	var v = board_state.vertices[Vector2(10, 20)]
	assert_eq(v["owner"], null)
	assert_eq(v["type"], board_state.BuildingType.NONE)
	assert_eq(v["links"], [])


func test_register_vertex_rounds_position():
	board_state.register_vertices(Vector2(10.7, 20.3))
	assert_true(board_state.vertices.has(Vector2(11, 20)))


func test_register_vertex_twice_does_not_overwrite():
	board_state.register_vertices(Vector2(5, 5))
	board_state.vertices[Vector2(5, 5)]["owner"] = 0
	board_state.register_vertices(Vector2(5, 5))
	assert_eq(board_state.vertices[Vector2(5, 5)]["owner"], 0)


func test_register_edge_creates_entry():
	board_state.register_edges(Vector2(0, 0), Vector2(100, 0))
	var center = Vector2(50, 0)
	assert_true(board_state.edges.has(center))


func test_register_edge_correct_vertices():
	board_state.register_edges(Vector2(0, 0), Vector2(100, 0))
	var edge = board_state.edges[Vector2(50, 0)]
	assert_eq(edge["a_vertice"], Vector2(0, 0))
	assert_eq(edge["b_vertice"], Vector2(100, 0))


func test_register_edge_default_owner_null():
	board_state.register_edges(Vector2(0, 0), Vector2(100, 0))
	assert_eq(board_state.edges[Vector2(50, 0)]["owner"], null)


func test_register_edge_twice_does_not_overwrite():
	board_state.register_edges(Vector2(0, 0), Vector2(100, 0))
	board_state.edges[Vector2(50, 0)]["owner"] = 1
	board_state.register_edges(Vector2(0, 0), Vector2(100, 0))
	assert_eq(board_state.edges[Vector2(50, 0)]["owner"], 1)


func test_set_initial_robber_pos():
	board_state.set_initial_robber_pos(Vector2(150, 200))
	assert_eq(board_state.robber_hex_pos, Vector2(150, 200))


func test_update_robber_position():
	board_state.set_initial_robber_pos(Vector2(0, 0))
	board_state.update_robber_position(Vector2(300, 400))
	assert_eq(board_state.robber_hex_pos, Vector2(300, 400))


func test_update_robber_rounds_position():
	board_state.update_robber_position(Vector2(99.6, 200.1))
	assert_eq(board_state.robber_hex_pos, Vector2(100, 200))


func test_reset_clears_vertices():
	board_state.register_vertices(Vector2(10, 10))
	board_state.reset_state()
	assert_true(board_state.vertices.is_empty())


func test_reset_clears_edges():
	board_state.register_edges(Vector2(0, 0), Vector2(50, 0))
	board_state.reset_state()
	assert_true(board_state.edges.is_empty())


func test_reset_clears_robber_pos():
	board_state.update_robber_position(Vector2(100, 100))
	board_state.reset_state()
	assert_eq(board_state.robber_hex_pos, Vector2.ZERO)


func test_get_players_on_hex_returns_empty_when_no_buildings():
	board_state.register_vertices(Vector2(10, 10))
	var result = board_state.get_players_on_hex(Vector2(50, 50))
	assert_eq(result, [])


func test_get_players_on_hex_excludes_specified_player():
	board_state.register_vertices(Vector2(10, 10))
	var mock_hex = Node2D.new()
	mock_hex.position = Vector2(50, 50)
	board_state.vertices[Vector2(10, 10)]["owner"] = 0
	board_state.vertices[Vector2(10, 10)]["links"] = [mock_hex]

	var result = board_state.get_players_on_hex(Vector2(50, 50), 0)
	assert_eq(result, [])
	mock_hex.free()
