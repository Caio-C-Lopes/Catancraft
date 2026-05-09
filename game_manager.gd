extends Node2D

var players = ["Jogador", "Bot 1", "Bot 2", "Bot 3"]
var current_player_index = 0
var has_rolled_dice = false

@onready var end_turn_button = $Control/EndTurnButton
@onready var dice_button = $Control/RollDiceButton


func _ready():
	randomize()
	start_turn()


func _on_button_pressed():
	if current_player_index == 0:
		if has_rolled_dice:
			print("Jogador passou o turno")
			end_turn()
		else:
			print("Você precisa rolar os dados primeiro!")
	else:
		print("Não é seu turno!")


func _on_roll_dice_button_pressed():
	if current_player_index == 0 and not has_rolled_dice:
		roll_dice()
		has_rolled_dice = true
	else:
		print("Você já rolou os dados ou não é seu turno!")


func start_turn():
	has_rolled_dice = false

	var player = players[current_player_index]
	print("Turno de: ", player)

	if current_player_index == 0:
		end_turn_button.disabled = false
		dice_button.disabled = false
	else:
		end_turn_button.disabled = true
		dice_button.disabled = true
		play_bot_turn()


func play_bot_turn():
	print("Bot jogando...")

	await get_tree().create_timer(2.0).timeout

	roll_dice()

	await get_tree().create_timer(1.0).timeout

	print("Bot jogou!")
	end_turn()


func end_turn():
	current_player_index += 1

	if current_player_index >= players.size():
		current_player_index = 0

	start_turn()


func roll_dice():
	var dice1 = randi() % 6 + 1
	var dice2 = randi() % 6 + 1
	var total = dice1 + dice2
	
	print("Dados:", dice1, "+", dice2, "=", total)
