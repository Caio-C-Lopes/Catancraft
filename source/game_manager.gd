extends Node2D

signal dice_rolled(player: Player, dice1: int, dice2: int)

enum GamePhase { PREPARATION, PLAYING }

var game_phase: GamePhase = GamePhase.PREPARATION

var preparation_order: Array[int] = []
var preparation_step: int = 0
var preparation_done: bool = false

var players: Array[Player] = []

var current_player_index: int = 0
var has_rolled_dice: bool = false
var auto_roll_time: float = 5.0
var turn_time: float = 60.0
var preparation_turn_time: float = 60.0
var waiting_robber_move: bool = false

@onready var player_hud = $Control/PlayerHUD
@onready var dice_log = $Control/DiceLog
@onready var bank_panel = $Control/BankPanel
@export var dice_textures: Array[Texture2D]

var _bot_huds: Array = []


func _ready():
	player_hud.dice_clicked.connect(roll_dice)
	randomize()
	await get_tree().process_frame
	_setup_players()
	_build_preparation_order()
	start_preparation_phase()
	player_hud.end_turn_pressed.connect(_on_button_pressed)
	player_hud.build_house_pressed.connect(func():
		if game_phase == GamePhase.PLAYING:
			_show_highlights_for_current(false)
	)

func _setup_players():
	var p_color  = GameConfig.player_color
	var p_icon   = load("res://icons_assets/%s.png" % GameConfig.player_icon_name) as Texture2D

	var all_color_names = ["blue", "green", "red", "purple"]
	var bot_color_names_available: Array = []
	for cn in all_color_names:
		if cn != GameConfig.player_color_name:
			bot_color_names_available.append(cn)

	var bot_color_map = {
		"red":    Color(0.85, 0.25, 0.25),
		"blue":   Color(0.22, 0.54, 0.87),
		"green":  Color(0.27, 0.65, 0.27),
		"purple": Color(0.55, 0.27, 0.80),
	}

	players = [Player.new("Jogador 1", p_color, p_icon)]

	for i in range(GameConfig.bot_count):
		var icon_name: String = "creeper"
		if i < GameConfig.bot_icon_names.size():
			icon_name = GameConfig.bot_icon_names[i]
		var bot_icon = load("res://icons_assets/%s.png" % icon_name) as Texture2D
		var cn: String = bot_color_names_available[i % bot_color_names_available.size()]
		players.append(Player.new("Bot " + str(i + 1), bot_color_map[cn], bot_icon))

	dice_log.setup_players(players)
	dice_log.setup_dice_textures(dice_textures)
	_create_bot_huds()

	# Aplica a cor escolhida no lobby nos ícones de peças do HUD
	player_hud.apply_player_color(GameConfig.player_color_name)


func _create_bot_huds():
	var control = $Control
	var all_color_names = ["blue", "green", "red", "purple"]
	var available: Array = []
	for cn in all_color_names:
		if cn != GameConfig.player_color_name:
			available.append(cn)

	for i in range(1, players.size()):
		var hud = preload("res://bot_hud.tscn").instantiate()
		hud.bot_index = i
		control.add_child(hud)
		var cn: String = available[(i - 1) % available.size()]
		hud.setup(players[i], cn)
		_bot_huds.append(hud)


func _refresh_bot_huds():
	for i in range(_bot_huds.size()):
		_bot_huds[i].refresh()


var _first_player_index: int = 0

func _build_preparation_order():
	var n = players.size()
	preparation_order.clear()

	# Sorteia aleatoriamente quem começa (equivalente ao "jogador mais velho" do Catan)
	_first_player_index = randi() % n
	print("Jogador sorteado para começar: %s (índice %d)" % [players[_first_player_index].player_name, _first_player_index])

	# Ida: começa no sorteado e percorre em ordem crescente de índice circular
	for i in range(n):
		preparation_order.append((_first_player_index + i) % n)

	# Volta: ordem inversa (último da ida volta primeiro)
	for i in range(n - 1, -1, -1):
		preparation_order.append((_first_player_index + i) % n)


func start_preparation_phase():
	game_phase = GamePhase.PREPARATION
	preparation_step = 0
	preparation_done = false

	# Dados desabilitados durante toda a preparação
	player_hud.set_dice_enabled(false)
	player_hud.stop_timer()

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

	player_hud.setup_preparation_turn(player)

	if is_human:
		_show_highlights_for_current(true)
		player_hud.start_timer(preparation_turn_time, _on_preparation_timeout)
	else:
		_hide_highlights()
		player_hud.stop_timer()
		await get_tree().create_timer(1.0).timeout
		_bot_place_settlement()


func _on_preparation_vertice_selected(pos: Vector2):
	_hide_highlights()
	player_hud.stop_timer()

	if _try_place_settlement(pos, current_player_index, true):
		preparation_step += 1
		_preparation_next_player()
	else:
		_show_highlights_for_current(true)
		player_hud.start_timer(preparation_turn_time, _on_preparation_timeout)


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
	# O primeiro turno começa com o mesmo jogador que abriu a preparação
	current_player_index = _first_player_index
	_hide_highlights()
	print("=== Preparação concluída! O jogo começa com %s. ===" % players[current_player_index].player_name)
	start_turn()


func start_turn():
	has_rolled_dice = false

	var player = players[current_player_index]
	var is_human = current_player_index == 0

	player_hud.setup_turn(player)
	player_hud.update_end_turn_button(is_human, false)

	print("Turno de: ", player.player_name)

	if not is_human:
		player_hud.set_dice_enabled(false)
		player_hud.stop_timer()
		play_bot_turn()
	else:
		# Humano: habilita dados e inicia timer para rolar
		player_hud.set_dice_enabled(true)
		player_hud.start_timer(auto_roll_time, _on_roll_timeout)


func play_bot_turn():
	await get_tree().create_timer(2.0).timeout
	roll_dice()
	await get_tree().create_timer(1.0).timeout
	end_turn()


func end_turn():
	_hide_highlights()
	player_hud.stop_timer()
	_refresh_bot_huds()
	current_player_index = (current_player_index + 1) % players.size()
	start_turn()


func _on_button_pressed():
	if current_player_index != 0:
		return
	if has_rolled_dice:
		end_turn()
	else:
		print("Você precisa rolar os dados primeiro!")


func _on_roll_timeout():
	# Só rola automaticamente se for humano e ainda não rolou
	if game_phase != GamePhase.PLAYING or current_player_index != 0 or has_rolled_dice:
		return
	print("Tempo esgotado! Rolando dados automaticamente.")
	roll_dice()


func _on_preparation_timeout():
	if game_phase != GamePhase.PREPARATION or current_player_index != 0:
		return
	print("Tempo de preparação esgotado! Colocando casa aleatoriamente.")
	_hide_highlights()

	# Coleta todos os vértices válidos e escolhe um aleatório
	var valid_keys: Array = []
	for key in BoardState.vertices:
		if village_construction_check(key, current_player_index, true):
			valid_keys.append(key)

	if valid_keys.is_empty():
		print("Nenhum vértice válido encontrado para colocação automática.")
		preparation_step += 1
		_preparation_next_player()
		return

	var chosen_key = valid_keys[randi() % valid_keys.size()]
	_try_place_settlement(chosen_key, current_player_index, true)
	preparation_step += 1
	_preparation_next_player()


func _on_turn_timeout():
	if game_phase != GamePhase.PLAYING or current_player_index != 0:
		return
	print("Tempo do turno esgotado! Passando turno automaticamente.")
	end_turn()


func roll_dice():
	# Guards: bloqueia na preparação e impede rolar duas vezes
	if game_phase == GamePhase.PREPARATION:
		return
	if has_rolled_dice:
		return

	has_rolled_dice = true
	player_hud.stop_timer()
	player_hud.set_dice_enabled(false)

	var dice1 = randi() % 6 + 1
	var dice2 = randi() % 6 + 1
	var total = dice1 + dice2
	var player = players[current_player_index]

	player_hud.show_dice_result(dice1, dice2)
	player_hud.update_end_turn_button(current_player_index == 0, true)

	print("%s rolou %d + %d = %d" % [player.player_name, dice1, dice2, total])

	dice_rolled.emit(player, dice1, dice2)
	dice_log.add_roll_entry(player, dice1, dice2)

	# Inicia timer do turno (60s) apenas para o humano
	if current_player_index == 0:
		player_hud.start_timer(turn_time, _on_turn_timeout)

	on_dice_rolled(total)


func on_dice_rolled(value: int):
	if value == 7:
		waiting_robber_move = true
		robber_movement()


func robber_movement():
	waiting_robber_move = true
	print("Clique em um hexágono para mover o ladrão.")
	var board = find_child("Board")
	if board:
		board.show_robber_options()



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

	# Atualiza HUD de peças
	if player_id == 0:
		player_hud.update_pieces(player)
	else:
		_refresh_bot_huds()

	print("%s construiu aldeia em %s (pontos: %d)" % [player.player_name, str(key), player.ponits])
	return true


func village_construction_check(pos: Vector2, player_id: int, preparation: bool) -> bool:
	var key = Vector2(round(pos.x), round(pos.y))

	if not BoardState.vertices.has(key):
		return false

	if BoardState.vertices[key]["owner"] != null:
		return false

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

	if (
		BoardState.vertices[a_v]["owner"] == player_id
		or BoardState.vertices[b_v]["owner"] == player_id
	):
		return true

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
				players[current_player_index].cities_remaining -= 1
				players[current_player_index].settlements_remaining += 1  # aldeia volta ao estoque
				players[current_player_index].ponits += 1
				player_hud.update_pieces(players[current_player_index])
				print("Cidade construída em ", key)


func _on_selected_edge(pos: Vector2):
	if game_phase != GamePhase.PLAYING or current_player_index != 0:
		return
	if road_construction_check(pos, current_player_index):
		var key = Vector2(round(pos.x), round(pos.y))
		BoardState.edges[key]["owner"] = current_player_index
		players[current_player_index].roads_remaining -= 1
		player_hud.update_pieces(players[current_player_index])
		print("Estrada construída em ", key)


func _show_highlights_for_current(is_preparation: bool):
	var board = find_child("Board")
	if board and board.has_method("show_settlement_highlights"):
		board.show_settlement_highlights(current_player_index, is_preparation, self)


func _hide_highlights():
	var board = find_child("Board")
	if board and board.has_method("hide_settlement_highlights"):
		board.hide_settlement_highlights()
