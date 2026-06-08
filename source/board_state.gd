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


func get_players_on_hex(hex_pos: Vector2, exclude_player: int = -1) -> Array:
	var victims_found: Array = []
	var target_pos = Vector2(round(hex_pos.x), round(hex_pos.y))

	for vert_key in vertices:
		var vert = vertices[vert_key]

		if vert["owner"] != null:
			if vert["owner"] == exclude_player:
				continue
			for hex_node in vert["links"]:
				if not is_instance_valid(hex_node):
					continue

				# Usa position (local) para bater com o pos emitido pelo board
				var h_pos = Vector2(round(hex_node.position.x), round(hex_node.position.y))

				# Se um dos hexágonos vizinhos for o hexágono alvo
				if h_pos == target_pos:
					# Adiciona o dono na lista de vítimas (se já não estiver lá)
					if not victims_found.has(vert["owner"]):
						victims_found.append(vert["owner"])
					break

	return victims_found
