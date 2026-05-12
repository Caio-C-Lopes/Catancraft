extends Node2D

var players = ["Jogador 1", "Bot 1", "Bot 2", "Bot 3"]
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
<<<<<<< Updated upstream


func village_construction_check(pos: Vector2, player_id: int, preparation: bool) -> bool:
	var key = Vector2(round(pos.x), round(pos.y))

	if BoardState.vertices[key]["owner"] != null:
		print("Este local está ocupado")
		return false

	for edge_key in BoardState.edges:
		var edge = BoardState.edges[edge_key]
		var neighbor = null

=======
	
func village_construction_check(pos: Vector2, player_id:int, preparation: bool) -> bool:
	var key = Vector2(round(pos.x), round(pos.y))
	
	if BoardState.vertices[key]["owner"] != null:
		print("Este local está ocupado")
		return false
	
	for edge_key in BoardState.edges:
		var edge = BoardState.edges[edge_key]
		var neighbor = null
		
>>>>>>> Stashed changes
		if edge["a_vertice"] == key:
			neighbor = edge["b_vertice"]
		elif edge["b_vertice"] == key:
			neighbor = edge["b_vertice"]
<<<<<<< Updated upstream

=======
		
>>>>>>> Stashed changes
		if neighbor != null:
			if BoardState.vertices[neighbor]["owner"] != null:
				print("Muito perto de outra aldeia/cidade")
				return false
<<<<<<< Updated upstream

	if not preparation:
		var flag = false

=======
				
	if not preparation:
		var flag = false
				
>>>>>>> Stashed changes
		for edge_key in BoardState.edges:
			var edge = BoardState.edges[edge_key]
			if edge["a_vertice"] == key or edge["b_vertice"] == key:
				if edge["owner"] == player_id:
					flag = true
					break
<<<<<<< Updated upstream

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
=======
		
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
	
	if BoardState.vertices[a_vertice]["owner"] == player_id or BoardState.vertices[b_vertice]["owner"] == player_id:
		return true
		
	for next_key in BoardState.edges:
		if next_key == edge_key:
			continue
			
		var next_edge = BoardState.edges[next_key]
		
		if next_edge["owner"] == player_id:
			if (next_edge["a_vertice"] == a_vertice or next_edge["a_vertice"] == b_vertice or 
				next_edge["b_vertice"] == a_vertice or next_edge["b_vertice"] == b_vertice):
>>>>>>> Stashed changes
				return true

	print("A estrada tem de estar conectada a uma construção sua!")
	return false
<<<<<<< Updated upstream


=======
	
>>>>>>> Stashed changes
func _on_selected_vertice(pos: Vector2):
	#do: The player needs to roll the dice firt
	var current_player = current_player_index
	var preparation = false
	var key = Vector2(round(pos.x), round(pos.y))
	var vertice = BoardState.vertices[key]
<<<<<<< Updated upstream

=======
	
>>>>>>> Stashed changes
	if vertice["owner"] == null:
		if village_construction_check(pos, current_player, preparation):
			vertice["owner"] = current_player
			vertice["type"] = BoardState.BuildingType.VILLAGE
<<<<<<< Updated upstream

			print("Aldeia construída no ponto ", key)

	if vertice["owner"] != null:
		if city_construction_check(pos, current_player):
			vertice["type"] = BoardState.BuildingType.CITY

			print("Cidade construida no ponto ", key)


func _on_selected_edge(pos: Vector2):
	#do: The player needs to roll the dice firt
	var current_player = current_player_index

=======
			
			print("Aldeia construída no ponto ", key)
			
	if vertice["owner"] != null:
		if city_construction_check(pos, current_player):
			vertice["type"] = BoardState.BuildingType.CITY 
			
			print("Cidade construida no ponto ", key)
	
func _on_selected_edge(pos: Vector2):
	#do: The player needs to roll the dice firt
	var current_player = current_player_index
	
>>>>>>> Stashed changes
	if road_construction_check(pos, current_player):
		var key = Vector2(round(pos.x), round(pos.y))
		BoardState.vertices[key]["owner"] = current_player
		print("Estrada construída no ponto ", key)
<<<<<<< Updated upstream


func city_construction_check(pos: Vector2, player_id: int) -> bool:
	var key = Vector2(round(pos.x), round(pos.y))
	var vertice = BoardState.vertices[key]

=======
		
func city_construction_check(pos: Vector2, player_id: int) -> bool:
	var key = Vector2(round(pos.x), round(pos.y))
	var vertice = BoardState.vertices[key]
	
>>>>>>> Stashed changes
	if vertice["owner"] == player_id and vertice["type"] == BoardState.BuildingType.VILLAGE:
		return true

	return false
