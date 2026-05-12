extends Node

enum BuildingType {NONE, VILLAGE, CITY}

var vertices: Dictionary = {}
var edges: Dictionary = {}

func register_vertices(pos: Vector2):
	var key = Vector2(round(pos.x), round(pos.y))
	if not vertices.has(key):
		vertices[key] = {
			"owner": null,
			"type": BuildingType.NONE,
			"links": []
		}

func register_edges(a: Vector2, b: Vector2):
	var center = (a + b) / 2.0
	var key = Vector2(round(center.x), round(center.y))
	
	if not edges.has(key):
		edges[key] = {
			"owner": null,
			"a_vertice": Vector2(round(a.x), round(a.y)),
			"b_vertice": Vector2(round(b.x), round(b.y))
		}
