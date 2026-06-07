extends Node

var player_color_name: String = "red"
var player_icon_name: String = "steve"
var bot_count: int = 3
var bot_icon_names: Array[String] = ["creeper", "zombie", "pig"]
var bot_color_names: Array[String] = ["blue", "green", "purple"]

var player_color: Color:
	get:
		return COLOR_MAP.get(player_color_name, Color.RED)

const COLOR_MAP: Dictionary = {
	"red": Color(0.85, 0.25, 0.25),
	"blue": Color(0.22, 0.54, 0.87),
	"green": Color(0.27, 0.65, 0.27),
	"purple": Color(0.55, 0.27, 0.80),
}
