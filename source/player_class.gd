class_name Player
extends Resource

@export var player_name: String
@export var player_color: Color
@export var icon_texture: Texture2D
@export var ponits: int = 0

var roads_remaining: int = 15
var settlements_remaining: int = 5
var cities_remaining: int = 4

var dev_cards_in_hand: int = 0
var knights_played: int = 0


func _init(name: String, color: Color, icon: Texture2D = null):
	player_name = name
	player_color = color
	icon_texture = icon


var resources := {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}


func add_resource(type: String, amount: int):
	if not resources.has(type):
		return
	resources[type] += amount
	print("%s recebeu %d de %s (total: %d)" % [player_name, amount, type, resources[type]])


func remove_resource(type: String, amount: int):
	if not resources.has(type):
		return
	resources[type] = max(0, resources[type] - amount)


func can_afford(cost: Dictionary) -> bool:
	for r in cost:
		if not resources.has(r) or resources[r] < cost[r]:
			return false
	return true
