extends Node2D

signal dice_rolled(player: Player, dice1: int, dice2: int)

var players: Array[Player] = []
var current_player_index: int = 0
var has_rolled_dice: bool = false

@onready var end_turn_button = $Control/EndTurnButton
@onready var dice_button = $Control/RollDiceButton
@onready var dice_log = $Control/DiceLog
@export var dice_textures: Array[Texture2D]


func _ready():
	randomize()
	_setup_players()
	start_turn()


func _setup_players():
	players = [
		Player.new("Jogador 1", Color(0.88, 0.37, 0.37)),
		Player.new("Bot 1",     Color(0.37, 0.63, 0.88)),
		Player.new("Bot 2",     Color(0.43, 0.78, 0.43)),
		Player.new("Bot 3",     Color(0.88, 0.75, 0.31)),
	]

	dice_log.setup_players(players)
	dice_log.setup_dice_textures(dice_textures)


func _on_button_pressed():
	if current_player_index != 0:
		return
	if has_rolled_dice:
		end_turn()
	else:
		print("Você precisa rolar os dados primeiro!")


func _on_roll_dice_button_pressed():
	if current_player_index == 0 and not has_rolled_dice:
		roll_dice()
	else:
		print("Você já rolou os dados ou não é seu turno!")


func start_turn():
	has_rolled_dice = false
	var player = players[current_player_index]
	print("Turno de: ", player.player_name)

	var is_human = current_player_index == 0
	end_turn_button.disabled = not is_human
	dice_button.disabled = not is_human

	if not is_human:
		play_bot_turn()


func play_bot_turn():
	await get_tree().create_timer(2.0).timeout
	roll_dice()
	await get_tree().create_timer(1.0).timeout
	end_turn()


func end_turn():
	current_player_index = (current_player_index + 1) % players.size()
	start_turn()


func roll_dice():
	var dice1 = randi() % 6 + 1
	var dice2 = randi() % 6 + 1
	var total = dice1 + dice2
	var player = players[current_player_index]

	has_rolled_dice = true
	print("%s rolou %d + %d = %d" % [player.player_name, dice1, dice2, total])

	dice_rolled.emit(player, dice1, dice2)
	dice_log.add_roll_entry(player, dice1, dice2)
