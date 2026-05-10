extends Node2D

var players = ["Jogador 1", "Bot 1", "Bot 2", "Bot 3"] # Change just to run CI job
var current_player_index = 0

@onready var button = $Control/Button

func _ready():
	start_turn()


func _on_button_pressed():
	if current_player_index == 0:
		print("Jogador passou o turno")
		end_turn()
	else:
		print("Não é seu turno!")


func start_turn():
	var player = players[current_player_index]
	print("Turno de: ", player)

	if player == "Jogador":
		button.disabled = false
	else:
		button.disabled = true
		play_bot_turn()


func play_bot_turn():
	print("Bot jogando...")

	await get_tree().create_timer(3.0).timeout

	print("Bot jogou!")
	end_turn()


func end_turn():
	current_player_index += 1

	if current_player_index >= players.size():
		current_player_index = 0

	start_turn()
