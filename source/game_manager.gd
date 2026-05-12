extends Node2D

signal dice_rolled(player: Player, dice1: int, dice2: int)

var players: Array[Player] = []
var current_player_index: int = 0
var has_rolled_dice: bool = false
var waiting_robber_move: bool = false

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
		Player.new("Bot 1", Color(0.37, 0.63, 0.88)),
		Player.new("Bot 2", Color(0.43, 0.78, 0.43)),
		Player.new("Bot 3", Color(0.88, 0.75, 0.31)),
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
	on_dice_rolled(total)


func on_dice_rolled(value: int):
	if value == 7:
		waiting_robber_move = true
		robber_movement()
	else:
		resources_distribution(value)


func robber_movement():
	waiting_robber_move = true
	print("Clique em um hexágono para mover o ladrão e bloquear os recursos.")
	var board = find_child("Board")
	if board:
		board.show_robber_options()


func resources_distribution(value: int):
	print("TESTE")


func village_construction_check(pos: Vector2, player_id: int, preparation: bool) -> bool:
	var key = Vector2(round(pos.x), round(pos.y))

	if BoardState.vertices[key]["owner"] != null:
		print("Este local está ocupado")
		return false

	for edge_key in BoardState.edges:
		var edge = BoardState.edges[edge_key]
		var neighbor = null

		if edge["a_vertice"] == key:
			neighbor = edge["b_vertice"]
		elif edge["b_vertice"] == key:
			neighbor = edge["b_vertice"]

		if neighbor != null:
			if BoardState.vertices[neighbor]["owner"] != null:
				print("Muito perto de outra aldeia/cidade")
				return false

	if not preparation:
		var flag = false

		for edge_key in BoardState.edges:
			var edge = BoardState.edges[edge_key]
			if edge["a_vertice"] == key or edge["b_vertice"] == key:
				if edge["owner"] == player_id:
					flag = true
					break

		if not flag:
			print("Você não tem estrada para este vértice")
			return false

	return true


func road_construction_check(pos: Vector2, player_id: int) -> bool:
	var edge_key = Vector2(round(pos.x), round(pos.y))

	if BoardState.edges[edge_key]["owner"] != null:
		print("Esta via já tem dono")
		return false

	var a_vertice = BoardState.edges[edge_key]["a_vertice"]
	var b_vertice = BoardState.edges[edge_key]["b_vertice"]

	if (
		BoardState.vertices[a_vertice]["owner"] == player_id
		or BoardState.vertices[b_vertice]["owner"] == player_id
	):
		return true

	for next_key in BoardState.edges:
		if next_key == edge_key:
			continue

		var next_edge = BoardState.edges[next_key]

		if next_edge["owner"] == player_id:
			if (
				next_edge["a_vertice"] == a_vertice
				or next_edge["a_vertice"] == b_vertice
				or next_edge["b_vertice"] == a_vertice
				or next_edge["b_vertice"] == b_vertice
			):
				return true

	print("A estrada tem de estar conectada a uma construção sua!")
	return false


func _on_selected_vertice(pos: Vector2):
	#do: The player needs to roll the dice firt
	var current_player = current_player_index
	var preparation = false
	var key = Vector2(round(pos.x), round(pos.y))
	var vertice = BoardState.vertices[key]

	if vertice["owner"] == null:
		if village_construction_check(pos, current_player, preparation):
			vertice["owner"] = current_player
			vertice["type"] = BoardState.BuildingType.VILLAGE

			print("Aldeia construída no ponto ", key)

	if vertice["owner"] != null:
		if city_construction_check(pos, current_player):
			vertice["type"] = BoardState.BuildingType.CITY

			print("Cidade construida no ponto ", key)


func _on_selected_edge(pos: Vector2):
	#do: The player needs to roll the dice firt
	var current_player = current_player_index

	if road_construction_check(pos, current_player):
		var key = Vector2(round(pos.x), round(pos.y))
		BoardState.vertices[key]["owner"] = current_player
		print("Estrada construída no ponto ", key)


func city_construction_check(pos: Vector2, player_id: int) -> bool:
	var key = Vector2(round(pos.x), round(pos.y))
	var vertice = BoardState.vertices[key]

	if vertice["owner"] == player_id and vertice["type"] == BoardState.BuildingType.VILLAGE:
		return true

	return false
