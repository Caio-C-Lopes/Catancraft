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
