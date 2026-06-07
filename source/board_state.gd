extends Node

enum BuildingType { NONE, VILLAGE, CITY }

var vertices: Dictionary = {}
var edges: Dictionary = {}
var robber_hex_pos: Vector2


func reset_state() -> void:
	vertices.clear()
	edges.clear()
	robber_hex_pos = Vector2.ZERO
	print("Estado do tabuleiro resetado com sucesso!")


func set_initial_robber_pos(pos: Vector2):
	robber_hex_pos = Vector2(round(pos.x), round(pos.y))


func update_robber_position(pos: Vector2):
	robber_hex_pos = Vector2(round(pos.x), round(pos.y))
	print("Estado do Tabuleiro: Ladrão agora está em ", robber_hex_pos)


func register_vertices(pos: Vector2):
	var key = Vector2(round(pos.x), round(pos.y))
	if not vertices.has(key):
		vertices[key] = {"owner": null, "type": BuildingType.NONE, "links": []}


func register_edges(a: Vector2, b: Vector2):
	var center = (a + b) / 2.0
	var key = Vector2(round(center.x), round(center.y))

	if not edges.has(key):
		edges[key] = {
			"owner": null,
			"a_vertice": Vector2(round(a.x), round(a.y)),
			"b_vertice": Vector2(round(b.x), round(b.y))
		}
