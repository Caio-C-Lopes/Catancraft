extends Node2D

signal dice_rolled(player: Player, dice1: int, dice2: int)

enum GamePhase { PREPARATION, PLAYING }

var game_phase: GamePhase = GamePhase.PREPARATION

# Ordem de colocação na preparação: ida (0→N-1) + volta (N-1→0)
var preparation_order: Array[int] = []
var preparation_step: int = 0
var preparation_done: bool = false

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
	_build_preparation_order()
	await get_tree().process_frame
	start_preparation_phase()


func _setup_players():
	players = [
		Player.new("Jogador 1", Color(0.88, 0.37, 0.37)),
		Player.new("Bot 1", Color(0.37, 0.63, 0.88)),
		Player.new("Bot 2", Color(0.43, 0.78, 0.43)),
		Player.new("Bot 3", Color(0.88, 0.75, 0.31)),
	]
	dice_log.setup_players(players)
	dice_log.setup_dice_textures(dice_textures)


func _build_preparation_order():
	var n = players.size()
	preparation_order.clear()
	for i in range(n):
		preparation_order.append(i)
	for i in range(n - 1, -1, -1):
		preparation_order.append(i)


func start_preparation_phase():
	game_phase = GamePhase.PREPARATION
	preparation_step = 0
	preparation_done = false

	dice_button.disabled = true
	end_turn_button.disabled = true

	_preparation_next_player()


func _preparation_next_player():
	if preparation_step >= preparation_order.size():
		_finish_preparation()
		return

	current_player_index = preparation_order[preparation_step]
	var player = players[current_player_index]
	var is_human = current_player_index == 0

	print(
		(
			"[PREPARAÇÃO %d/%d] Vez de %s colocar uma casa."
			% [preparation_step + 1, preparation_order.size(), player.player_name]
		)
	)

	if is_human:
		_show_highlights_for_current(true)
	else:
		_hide_highlights()
		await get_tree().create_timer(1.0).timeout
		_bot_place_settlement()


# Humano clicou num vértice durante a preparação
func _on_preparation_vertice_selected(pos: Vector2):
	_hide_highlights()

	if _try_place_settlement(pos, current_player_index, true):
		preparation_step += 1
		_preparation_next_player()
	else:
		_show_highlights_for_current(true)


const NUMBER_SCORE = {2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 8: 5, 9: 4, 10: 3, 11: 2, 12: 1}


func _bot_place_settlement():
	var best_score: float = -1.0
	var best_candidates: Array = []

	for key in BoardState.vertices:
		if not village_construction_check(key, current_player_index, true):
			continue

		var score = _score_vertex(key)

		if score > best_score:
			best_score = score
			best_candidates = [key]
		elif score == best_score:
			best_candidates.append(key)

	if best_candidates.is_empty():
		print("Bot %s sem vértice válido." % players[current_player_index].player_name)
	else:
		var best_key = best_candidates[randi() % best_candidates.size()]
		print(
			(
				"%s escolheu vértice com score %.1f"
				% [players[current_player_index].player_name, best_score]
			)
		)
		_try_place_settlement(best_key, current_player_index, true)

	preparation_step += 1
	_preparation_next_player()


func _score_vertex(key: Vector2) -> float:
	var hex_links = BoardState.vertices[key]["links"]
	var total_prob: float = 0.0
	var resource_set: Array = []

	for hex in hex_links:
		if not is_instance_valid(hex):
			continue

		var number = hex.get_meta("dice_number") if hex.has_meta("dice_number") else 0
		var rtype = hex.get_meta("resource_type") if hex.has_meta("resource_type") else -1

		if number == 0:
			continue

		if NUMBER_SCORE.has(number):
			total_prob += NUMBER_SCORE[number]

		if rtype != -1 and rtype not in resource_set:
			resource_set.append(rtype)

	var diversity_bonus: float = (resource_set.size() - 1) * 2.0
	var coverage_bonus: float = 3.0 if resource_set.size() == 3 else 0.0

	return total_prob + diversity_bonus + coverage_bonus


func _finish_preparation():
	preparation_done = true
	game_phase = GamePhase.PLAYING
	current_player_index = 0
	_hide_highlights()
	print("=== Preparação concluída! O jogo começa. ===")
	start_turn()


func start_turn():
	has_rolled_dice = false
	var player = players[current_player_index]
	var is_human = current_player_index == 0

	print("Turno de: ", player.player_name)
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
	_hide_highlights()
	current_player_index = (current_player_index + 1) % players.size()
	start_turn()


func _on_button_pressed():
	if current_player_index != 0:
		return
	if has_rolled_dice:
		end_turn()
	else:
		print("Você precisa rolar os dados primeiro!")


func _on_roll_dice_button_pressed():
	if game_phase == GamePhase.PREPARATION:
		print("Não é possível rolar dados na fase de preparação!")
		return
	if current_player_index == 0 and not has_rolled_dice:
		roll_dice()
	else:
		print("Você já rolou os dados ou não é seu turno!")


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
	print("Clique em um hexágono para mover o ladrão.")
	var board = find_child("Board")
	if board:
		board.show_robber_options()


func resources_distribution(_value: int):
	pass  # TODO: implementar distribuição de recursos


func _try_place_settlement(pos: Vector2, player_id: int, is_preparation: bool) -> bool:
	var key = Vector2(round(pos.x), round(pos.y))

	if not BoardState.vertices.has(key):
		return false

	if not village_construction_check(key, player_id, is_preparation):
		return false

	var player = players[player_id]

	if not is_preparation:
		var cost = {"wood": 1, "brick": 1, "wheat": 1, "sheep": 1}
		if not player.can_afford(cost):
			print("%s não tem recursos suficientes!" % player.player_name)
			return false
		for resource in cost:
			player.remove_resource(resource, cost[resource])

	BoardState.vertices[key]["owner"] = player_id
	BoardState.vertices[key]["type"] = BoardState.BuildingType.VILLAGE
	player.settlements_remaining -= 1
	player.ponits += 1

	var board = find_child("Board")
	if board:
		board.spawn_settlement_visual(key, player.player_color)

	print("%s construiu aldeia em %s (pontos: %d)" % [player.player_name, str(key), player.ponits])
	return true


func village_construction_check(pos: Vector2, player_id: int, preparation: bool) -> bool:
	var key = Vector2(round(pos.x), round(pos.y))

	if not BoardState.vertices.has(key):
		return false

	# Vértice ocupado?
	if BoardState.vertices[key]["owner"] != null:
		return false

	# Regra da distância — nenhum vizinho pode ter construção
	for edge_key in BoardState.edges:
		var edge = BoardState.edges[edge_key]
		var neighbor: Variant = null

		if edge["a_vertice"] == key:
			neighbor = edge["b_vertice"]
		elif edge["b_vertice"] == key:
			neighbor = edge["a_vertice"]

		if neighbor != null:
			if BoardState.vertices.has(neighbor) and BoardState.vertices[neighbor]["owner"] != null:
				return false

	if not preparation:
		var has_road = false
		for edge_key in BoardState.edges:
			var edge = BoardState.edges[edge_key]
			if edge["a_vertice"] == key or edge["b_vertice"] == key:
				if edge["owner"] == player_id:
					has_road = true
					break
		if not has_road:
			return false

	return true


func road_construction_check(pos: Vector2, player_id: int) -> bool:
	var edge_key = Vector2(round(pos.x), round(pos.y))

	if not BoardState.edges.has(edge_key):
		return false

	if BoardState.edges[edge_key]["owner"] != null:
		print("Esta via já tem dono.")
		return false

	var a_v = BoardState.edges[edge_key]["a_vertice"]
	var b_v = BoardState.edges[edge_key]["b_vertice"]

	# Conectada a uma construção própria?
	if (
		BoardState.vertices[a_v]["owner"] == player_id
		or BoardState.vertices[b_v]["owner"] == player_id
	):
		return true

	# Conectada a outra estrada própria?
	for next_key in BoardState.edges:
		if next_key == edge_key:
			continue
		var next_edge = BoardState.edges[next_key]
		if next_edge["owner"] == player_id:
			if (
				next_edge["a_vertice"] == a_v
				or next_edge["a_vertice"] == b_v
				or next_edge["b_vertice"] == a_v
				or next_edge["b_vertice"] == b_v
			):
				return true

	print("A estrada tem de estar conectada a uma construção sua!")
	return false


func city_construction_check(pos: Vector2, player_id: int) -> bool:
	var key = Vector2(round(pos.x), round(pos.y))
	var vertice = BoardState.vertices[key]

	if vertice["owner"] == player_id and vertice["type"] == BoardState.BuildingType.VILLAGE:
		var cost = {"ore": 3, "wheat": 2}
		if not players[player_id].can_afford(cost):
			print("Recursos insuficientes para cidade.")
			return false
		for resource in cost:
			players[player_id].remove_resource(resource, cost[resource])
		return true

	return false


func _on_selected_vertice(pos: Vector2):
	if game_phase == GamePhase.PREPARATION:
		if current_player_index != 0:
			return
		_on_preparation_vertice_selected(pos)

	elif game_phase == GamePhase.PLAYING:
		if current_player_index != 0:
			return
		var key = Vector2(round(pos.x), round(pos.y))
		if not BoardState.vertices.has(key):
			return

		var vertice = BoardState.vertices[key]
		if vertice["owner"] == null:
			if _try_place_settlement(pos, current_player_index, false):
				_show_highlights_for_current(false)
		elif (
			vertice["owner"] == current_player_index
			and vertice["type"] == BoardState.BuildingType.VILLAGE
		):
			if city_construction_check(pos, current_player_index):
				vertice["type"] = BoardState.BuildingType.CITY
				players[current_player_index].ponits += 1
				print("Cidade construída em ", key)


func _on_selected_edge(pos: Vector2):
	if game_phase != GamePhase.PLAYING or current_player_index != 0:
		return
	if road_construction_check(pos, current_player_index):
		var key = Vector2(round(pos.x), round(pos.y))
		BoardState.edges[key]["owner"] = current_player_index
		print("Estrada construída em ", key)


func _show_highlights_for_current(is_preparation: bool):
	var board = find_child("Board")
	if board and board.has_method("show_settlement_highlights"):
		board.show_settlement_highlights(current_player_index, is_preparation, self)


func _hide_highlights():
	var board = find_child("Board")
	if board and board.has_method("hide_settlement_highlights"):
		board.hide_settlement_highlights()
