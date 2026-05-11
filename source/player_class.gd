class_name Player
extends Resource

@export var player_name: String
@export var player_color: Color
@export var ponits: int = 0

var roads_remaining: int = 15
var settlements_remaining: int = 5
var cities_remaining: int = 4

var resources := {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}


func _init(name: String, color: Color):
	player_name = name
	player_color = color


func add_resource(resource: String, amount: int):
	if resources.has(resource):
		resources[resource] += amount


func remove_resource(resource: String, amount: int):
	if resources.has(resource):
		resources[resource] -= amount


func can_afford(cost: Dictionary):
	for i in cost:
		if resources[i] < cost[i]:
			return false
	return true
