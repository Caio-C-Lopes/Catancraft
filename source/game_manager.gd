extends Node2D

signal dice_rolled(player: Player, dice1: int, dice2: int)

enum GamePhase { PREPARATION, PLAYING }

var game_phase: GamePhase = GamePhase.PREPARATION
var _bot_trade_popup: Control = null
var _bot_trade_bot_id: int = -1
var preparation_order: Array[int] = []
var preparation_step: int = 0
var preparation_done: bool = false

var players: Array[Player] = []

var current_player_index: int = 0
var has_rolled_dice: bool = false
var auto_roll_time: float = 5.0
var turn_time: float = 60.0
var preparation_turn_time: float = 60.0
var is_setup_phase = true
@onready var player_hud = $Control/PlayerHUD
@onready var dice_log = $Control/DiceLog
@onready var bank_panel = $Control/BankPanel
@export var dice_textures: Array[Texture2D]
var _bot_huds: Array = []
var _bot_controller: Node = null

var _pending_trade_give: Array = []
var _pending_trade_recv: Array = []

# ── Baralho de cartas de desenvolvimento ──────────────────────────────────────
# Mapeamento: CardType int → quantidades conforme o Catan (25 cartas total)
# KNIGHT=0, ROAD_BUILDING=1, YEAR_OF_PLENTY=2, MONOPOLY=3,
# CHAPEL=4, UNIVERSITY=5, PALACE=6, LIBRARY=7, MARKET=8
const DEV_CARD_COUNTS := {
	0: 14,  # Cavaleiro
	1: 2,  # Construção de estradas
	2: 2,  # Ano da abundância
	3: 2,  # Monopólio
	4: 1,  # Capela
	5: 1,  # Universidade
	6: 1,  # Palácio
	7: 1,  # Biblioteca
	8: 1,  # Mercado
}

var _dev_deck: Array[int] = []  # cartas embaralhadas

# Referência ao painel de cartas do humano (DevCardPanel)
@onready var _dev_card_panel = $Control/PlayerHUD/DevCardPanel  # ajuste o caminho se necessário

# ── Largest Army / Longest Road ───────────────────────────────────────────────
var largest_army_owner: int = -1  # índice do jogador com maior exército
var longest_road_owner: int = -1  # índice do jogador com maior estrada

# ── Estado de carta em uso ────────────────────────────────────────────────────
var _pending_road_building_roads: int = 0  # quantas estradas gratuitas restam
var _road_mode_active: bool = false  # true quando o jogador está no modo de construir estrada
var _settlement_mode_active: bool = false  # true quando o jogador está no modo de construir aldeia
var _city_mode_active: bool = false  # true quando o jogador está no modo de construir cidade

# ── Monopoly/YoP aguardando input ─────────────────────────────────────────────
var _waiting_monopoly: bool = false
var _waiting_yop: bool = false
var _yop_cards_left: int = 0

# ── Controle da estrada na fase de preparação ────────────────────────────────
var _prep_settlement_pos: Vector2 = Vector2.ZERO
var _waiting_prep_road: bool = false

# ── Controle do Ladrão ────────────────────────────────────────────────────────
var waiting_discard: bool = false
var waiting_robber_placement: bool = false
var waiting_robber_steal: bool = false

var robber_discard_time: float = 20.0
var robber_move_time: float = 10.0

@onready var robber_panel = $Control/PlayerHUD/RobberPanel  # Ajuste o caminho pro seu nó


func resource_type_to_string(type: int) -> String:
	match type:
		0:
			return "wood"
		1:
			return "sheep"
		2:
			return "wheat"
		3:
			return "brick"
		4:
			return "ore"
		_:
			return ""


func _ready():
	_bot_controller = preload("res://source/bot_controller.gd").new()
	_bot_controller.name = "BotController"
	add_child(_bot_controller)

	player_hud.dice_clicked.connect(roll_dice)
	randomize()
	await get_tree().process_frame
	_setup_players()
	_build_preparation_order()
	_build_dev_deck()
	start_preparation_phase()
	_bot_controller.setup(self)
	player_hud.end_turn_pressed.connect(_on_button_pressed)
	player_hud.build_house_pressed.connect(_on_build_house_pressed)
	player_hud.build_road_pressed.connect(_on_build_road_pressed)
	player_hud.build_city_pressed.connect(_on_build_city_pressed)
	# Conecta sinais do tabuleiro (caso não estejam conectados no Inspector)
	var board = find_child("Board")
	if board:
		if not board.selected_vertice.is_connected(_on_selected_vertice):
			board.selected_vertice.connect(_on_selected_vertice)
		if not board.selected_edge.is_connected(_on_selected_edge):
			board.selected_edge.connect(_on_selected_edge)
	# Conecta o sinal do painel de cartas (apenas humano)
	if _dev_card_panel and _dev_card_panel.has_signal("card_played"):
		_dev_card_panel.card_played.connect(_on_human_card_played)

	# Popula as texturas de recursos no DiceLog para que os sprites apareçam
	# nas entradas de troca, produção e preparação.
	_setup_dice_log_resource_textures()

	# Aguarda até o _trade_panel existir antes de conectar bank_trade_requested
	_connect_trade_panel_deferred.call_deferred()


func _setup_dice_log_resource_textures() -> void:
	var textures: Dictionary = {
		"wood": load("res://card_assets/resources/WOOD.png"),
		"brick": load("res://card_assets/resources/BRICK.png"),
		"wheat": load("res://card_assets/resources/WHEAT.png"),
		"sheep": load("res://card_assets/resources/SHEEP.png"),
		"ore": load("res://card_assets/resources/STONE.png"),
	}
	dice_log.setup_resource_textures(textures)


func _connect_trade_panel_deferred() -> void:
	# Aguarda até o _trade_panel existir de fato (pode levar mais de 2 frames
	# se o PlayerHUD usar call_deferred para criá-lo).
	var max_attempts := 10
	for _i in range(max_attempts):
		await get_tree().process_frame
		if player_hud._trade_panel != null:
			break
	_connect_trade_panel()


# ── Baralho ────────────────────────────────────────────────────────────────────

# ── Troca com o banco ─────────────────────────────────────────────────────────


func _connect_trade_panel() -> void:
	var tp = player_hud._trade_panel
	if tp == null:
		push_error(
			"game_manager: trade_panel não existe após aguardar — verifique PlayerHUD._build_trade_panel()."
		)
		return
	if not tp.is_connected("bank_trade_requested", _on_bank_trade_requested):
		tp.bank_trade_requested.connect(_on_bank_trade_requested)
	if not tp.is_connected("player_trade_requested", _on_player_trade_requested):
		tp.player_trade_requested.connect(_on_player_trade_requested)
	if not tp.is_connected("trade_partner_chosen", _on_trade_partner_chosen):
		tp.trade_partner_chosen.connect(_on_trade_partner_chosen)


func _on_player_trade_requested(give_res: Array, recv_res: Array) -> void:
	if current_player_index != 0 or not has_rolled_dice:
		print("Troca bloqueada: role os dados primeiro ou aguarde seu turno.")
		return

	var human := players[0]
	var give_counts := _count_resources(give_res)
	for res in give_counts:
		if human.resources.get(res, 0) < give_counts[res]:
			print("Humano não tem recursos suficientes para a oferta.")
			if player_hud._trade_panel != null:
				player_hud._trade_panel.show_trade_result([])
			return

	var accepted_by: Array = []
	for i in range(1, players.size()):
		if _bot_controller.accepts_trade(i, give_res, recv_res):
			accepted_by.append(players[i])

	if accepted_by.is_empty():
		if player_hud._trade_panel != null:
			player_hud._trade_panel.show_trade_result([])
		return

	if accepted_by.size() == 1:
		# Só um bot aceitou — executa direto
		var bot_id := players.find(accepted_by[0])
		_execute_player_trade(0, bot_id, give_res, recv_res)
		if player_hud._trade_panel != null:
			player_hud._trade_panel.show_trade_result([accepted_by[0]])
	else:
		# Vários aceitaram — guarda estado e pede ao humano escolher
		_pending_trade_give = give_res.duplicate()
		_pending_trade_recv = recv_res.duplicate()
		if player_hud._trade_panel != null:
			player_hud._trade_panel.show_trade_offers(accepted_by, give_res, recv_res)


func _on_trade_partner_chosen(chosen_bot: Player) -> void:
	if _pending_trade_give.is_empty() or _pending_trade_recv.is_empty():
		return

	var bot_id := players.find(chosen_bot)
	if bot_id == -1:
		return

	# Revalida — o estado pode ter mudado enquanto o humano escolhia
	var recv_counts := _count_resources(_pending_trade_recv)
	for res in recv_counts:
		if chosen_bot.resources.get(res, 0) < recv_counts[res]:
			print("%s não tem mais recursos suficientes." % chosen_bot.player_name)
			_pending_trade_give.clear()
			_pending_trade_recv.clear()
			return

	_execute_player_trade(0, bot_id, _pending_trade_give, _pending_trade_recv)
	_pending_trade_give.clear()
	_pending_trade_recv.clear()
	_refresh_resource_ui()


## Conta quantas de cada recurso há em um array de strings
func _count_resources(res_array: Array) -> Dictionary:
	var counts := {}
	for r in res_array:
		counts[r] = counts.get(r, 0) + 1
	return counts


## Transfere recursos entre dois jogadores
func _execute_player_trade(
	player_a_id: int, player_b_id: int, a_gives: Array, b_gives: Array
) -> void:
	var player_a := players[player_a_id]
	var player_b := players[player_b_id]

	# A dá para B
	var a_give_counts := _count_resources(a_gives)
	for res in a_give_counts:
		player_a.remove_resource(res, a_give_counts[res])
		player_b.add_resource(res, a_give_counts[res])

	# B dá para A
	var b_give_counts := _count_resources(b_gives)
	for res in b_give_counts:
		player_b.remove_resource(res, b_give_counts[res])
		player_a.add_resource(res, b_give_counts[res])

	print(
		(
			"%s trocou com %s: deu %s, recebeu %s"
			% [player_a.player_name, player_b.player_name, str(a_gives), str(b_gives)]
		)
	)

	# Log visual (reutiliza a entrada de troca do DiceLog)
	dice_log.add_trade_entry(player_a, a_gives, b_gives, player_b)

	_refresh_resource_ui()


func _on_bank_trade_requested(give_res: String, recv_res: String) -> void:
	execute_bank_trade(0, give_res, recv_res)


## Executa a troca 4:1 com o banco para o jogador indicado.
## Desconta 4 cartas de give_res, devolve ao banco, retira 1 de recv_res do banco.
func execute_bank_trade(player_id: int, give_res: String, recv_res: String) -> bool:
	var player := players[player_id]

	# Só pode trocar durante o turno do humano após rolar os dados
	if player_id == 0 and (current_player_index != 0 or not has_rolled_dice):
		print("Troca bloqueada: role os dados primeiro ou aguarde seu turno.")
		return false

	# Verificação de segurança: jogador tem as 4 cartas?
	if player.resources.get(give_res, 0) < 4:
		print("Recursos insuficientes para a troca com o banco.")
		return false

	# Banco tem o recurso pedido?
	if not bank_panel.take_resource(recv_res, 1):
		print("Banco sem '%s'." % recv_res)
		return false

	# Desconta do jogador e devolve ao banco
	player.remove_resource(give_res, 4)
	bank_panel.return_resource(give_res, 4)

	# Entrega recurso ao jogador
	player.add_resource(recv_res, 1)

	print("%s trocou 4x %s por 1x %s com o banco." % [player.player_name, give_res, recv_res])

	# Registra no log
	var give_list: Array = []
	for _i in range(4):
		give_list.append(give_res)
	dice_log.add_trade_entry(player, give_list, [recv_res], null)

	_refresh_resource_ui()
	return true


func _build_dev_deck() -> void:
	_dev_deck.clear()
	for card_type in DEV_CARD_COUNTS:
		for _i in range(DEV_CARD_COUNTS[card_type]):
			_dev_deck.append(card_type)
	# Embaralha
	for i in range(_dev_deck.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp := _dev_deck[i]
		_dev_deck[i] = _dev_deck[j]
		_dev_deck[j] = tmp
	print("Baralho de cartas de desenvolvimento criado: %d cartas." % _dev_deck.size())


func deck_empty() -> bool:
	return _dev_deck.is_empty()


## Compra a carta do topo do baralho para o jogador.
## Retorna true em caso de sucesso.
func buy_dev_card(player_id: int) -> bool:
	# Só pode comprar após rolar os dados (apenas para o humano)
	if player_id == 0 and not has_rolled_dice:
		print("Role os dados antes de comprar uma carta de desenvolvimento!")
		return false

	var player := players[player_id]
	var cost := {"ore": 1, "wheat": 1, "sheep": 1}

	if deck_empty():
		print("Baralho de desenvolvimento vazio!")
		return false

	if not player.can_afford(cost):
		print("%s não tem recursos para comprar carta de desenvolvimento." % player.player_name)
		return false

	if player.dev_card_bought_this_turn:
		print("Só é permitido comprar uma carta de desenvolvimento por turno.")
		return false

	# Desconta recursos
	for r in cost:
		player.remove_resource(r, cost[r])
		bank_panel.return_resource(r, 1)  # devolve ao banco

	# Retira carta do topo
	var card_type: int = _dev_deck.pop_back()
	player.add_dev_card(card_type)

	print(
		(
			"%s comprou carta de desenvolvimento: %s (restam %d no baralho)"
			% [player.player_name, _card_type_name(card_type), _dev_deck.size()]
		)
	)

	# Atualiza HUD apenas para o humano
	if player_id == 0 and _dev_card_panel:
		_dev_card_panel.add_card(card_type)

	_refresh_resource_ui()
	_check_victory(player_id)
	return true


# ── Jogar carta de desenvolvimento ────────────────────────────────────────────


## Chamado pelo sinal do DevCardPanel quando o humano clica numa carta.
func _on_human_card_played(card_index: int, card_type: int) -> void:
	if current_player_index != 0:
		return
	play_dev_card(0, card_index, card_type)


## Lógica central para jogar uma carta — funciona para humano e bots.
func play_dev_card(player_id: int, card_index: int, card_type: int) -> bool:
	var player := players[player_id]

	if player.played_dev_card_this_turn:
		print("%s já jogou uma carta de desenvolvimento neste turno." % player.player_name)
		return false

	# Não pode jogar carta comprada no mesmo turno
	if player.dev_card_bought_this_turn and card_index == player.dev_cards.size() - 1:
		print("Não pode jogar uma carta comprada no mesmo turno.")
		return false

	# Cartas de ponto de vitória só reveladas para vencer
	const VP_CARDS := [4, 5, 6, 7, 8]
	if card_type in VP_CARDS:
		print("Cartas de ponto de vitória são reveladas automaticamente ao atingir 10 pontos.")
		return false

	player.remove_dev_card(card_index)
	player.played_dev_card_this_turn = true

	# Atualiza grid do humano
	if player_id == 0 and _dev_card_panel:
		_dev_card_panel.remove_card(card_index)

	match card_type:
		0:  # KNIGHT
			_apply_knight(player_id)
		1:  # ROAD_BUILDING
			_apply_road_building(player_id)
		2:  # YEAR_OF_PLENTY
			_apply_year_of_plenty(player_id)
		3:  # MONOPOLY
			_apply_monopoly(player_id)

	_refresh_resource_ui()
	return true


# ── Efeitos das cartas ─────────────────────────────────────────────────────────


## CAVALEIRO — move o ladrão (igual ao rolar 7, sem descartar cartas)
func _apply_knight(player_id: int) -> void:
	players[player_id].knights_played += 1
	print(
		(
			"%s jogou Cavaleiro (total jogado: %d)"
			% [players[player_id].player_name, players[player_id].knights_played]
		)
	)

	_prompt_robber_movement()
	_check_largest_army(player_id)


func _check_largest_army(player_id: int) -> void:
	var player := players[player_id]
	if player.knights_played < 3:
		return

	if largest_army_owner == -1:
		# Primeiro a ter 3 cavaleiros
		largest_army_owner = player_id
		player.points += 2
		print("%s obteve o Maior Exército de Cavalaria! (+2 PV)" % player.player_name)
		player_hud.update_vp_and_knights()
		_check_victory(player_id)
		return

	if player_id != largest_army_owner:
		var current_owner := players[largest_army_owner]
		if player.knights_played > current_owner.knights_played:
			# Transfere os 2 pontos
			current_owner.points -= 2
			player.points += 2
			largest_army_owner = player_id
			print(
				(
					"%s roubou o Maior Exército de Cavalaria de %s! (+2 PV / -2 PV)"
					% [player.player_name, current_owner.player_name]
				)
			)
			player_hud.update_vp_and_knights()
			_check_victory(player_id)


## CONSTRUÇÃO DE ESTRADAS — 2 estradas grátis
func _apply_road_building(player_id: int) -> void:
	print(
		"%s jogou Construção de Estradas — 2 estradas gratuitas!" % players[player_id].player_name
	)
	if player_id == 0:
		_pending_road_building_roads = 2
		_road_mode_active = true
		# Mostra highlights de estrada para o humano
		var board := find_child("Board")
		if board and board.has_method("show_road_highlights"):
			board.show_road_highlights(player_id, self)
	else:
		# Bot coloca 2 estradas válidas via bot_controller
		for _i in range(2):
			_bot_controller.place_free_road(player_id)


## ANO DA ABUNDÂNCIA — recebe 2 recursos à escolha do banco
func _apply_year_of_plenty(player_id: int) -> void:
	print("%s jogou Ano da Abundância!" % players[player_id].player_name)
	if player_id == 0:
		_waiting_yop = true
		_yop_cards_left = 2
		# Abre diálogo de seleção de recurso para o humano
		_open_resource_picker("year_of_plenty")
	else:
		# Bot pega os 2 recursos mais escassos
		for _i in range(2):
			var rarest: String = _bot_controller.choose_resource(player_id) as String
			if bank_panel.take_resource(rarest, 1):
				players[player_id].add_resource(rarest, 1)
		_refresh_resource_ui()


## MONOPÓLIO — rouba todos os recursos de um tipo de todos os outros jogadores
func _apply_monopoly(player_id: int) -> void:
	print("%s jogou Monopólio!" % players[player_id].player_name)
	if player_id == 0:
		_waiting_monopoly = true
		_open_resource_picker("monopoly")
	else:
		# Bot escolhe o recurso que mais oponentes têm
		var best_res: String = _bot_controller.best_monopoly_resource(player_id) as String
		_execute_monopoly(player_id, best_res)


func _execute_monopoly(player_id: int, resource: String) -> void:
	var total := 0
	for i in range(players.size()):
		if i == player_id:
			continue
		var amount: int = players[i].resources.get(resource, 0)
		if amount > 0:
			players[i].remove_resource(resource, amount)
			players[player_id].add_resource(resource, amount)
			total += amount
	print(
		(
			"%s usou Monopólio em '%s' e roubou %d cartas no total."
			% [players[player_id].player_name, resource, total]
		)
	)
	_refresh_resource_ui()


## ANO DA ABUNDÂNCIA — entrega recurso ao humano (chamado pelo diálogo de UI)
func year_of_plenty_pick(resource: String) -> void:
	if not _waiting_yop or current_player_index != 0:
		return
	if bank_panel.take_resource(resource, 1):
		players[0].add_resource(resource, 1)
		_yop_cards_left -= 1
		_refresh_resource_ui()
		if _yop_cards_left <= 0:
			_waiting_yop = false
		else:
			_open_resource_picker("year_of_plenty")  # pede o 2º recurso
	else:
		print("Banco sem '%s'." % resource)


## MONOPÓLIO — confirma escolha do humano (chamado pelo diálogo de UI)
func monopoly_pick(resource: String) -> void:
	if not _waiting_monopoly or current_player_index != 0:
		return
	_waiting_monopoly = false
	_execute_monopoly(0, resource)


# ── Diálogo de seleção de recurso (stub — conecte à sua UI real) ──────────────
## Abre um popup/dialog para o humano escolher um recurso.
## Implemente _open_resource_picker conforme sua cena.
## Ao confirmar, chame year_of_plenty_pick(res) ou monopoly_pick(res).
func _open_resource_picker(context: String) -> void:
	# STUB: emite um sinal ou abre um Control existente na cena.
	# Substitua pelo seu popup real.
	print("[UI] Abrir seletor de recurso para contexto: %s" % context)
	# Exemplo mínimo — auto-seleciona "ore" para não travar o jogo durante o desenvolvimento:
	# (remova este fallback quando sua UI de popup estiver pronta)
	if context == "monopoly":
		monopoly_pick("ore")
	elif context == "year_of_plenty":
		year_of_plenty_pick("ore")


# ── Maior Estrada Comercial ────────────────────────────────────────────────────


func _check_longest_road(player_id: int) -> void:
	var road_len := _calc_longest_road(player_id)
	if road_len < 5:
		return

	if longest_road_owner == -1:
		longest_road_owner = player_id
		players[player_id].points += 2
		print(
			(
				"%s obteve a Maior Estrada Comercial (%d)! (+2 PV)"
				% [players[player_id].player_name, road_len]
			)
		)
		player_hud.update_vp_and_knights()
		_check_victory(player_id)
		return

	if player_id != longest_road_owner:
		var current_len := _calc_longest_road(longest_road_owner)
		if road_len > current_len:
			players[longest_road_owner].points -= 2
			players[player_id].points += 2
			longest_road_owner = player_id
			print(
				(
					"%s roubou a Maior Estrada Comercial! (%d)"
					% [players[player_id].player_name, road_len]
				)
			)
			player_hud.update_vp_and_knights()
			_check_victory(player_id)


## Calcula o comprimento da maior estrada contínua (DFS simples).
func _calc_longest_road(player_id: int) -> int:
	var best := 0
	var visited := {}

	# Coleta todas as arestas do jogador
	var player_edges: Array = []
	for ek in BoardState.edges:
		if BoardState.edges[ek]["owner"] == player_id:
			player_edges.append(ek)

	for start_edge in player_edges:
		var length := _dfs_road(player_id, start_edge, visited)
		if length > best:
			best = length

	return best


func _dfs_road(player_id: int, edge_key: Vector2, visited: Dictionary) -> int:
	if visited.has(edge_key):
		return 0
	visited[edge_key] = true

	var edge: Dictionary = BoardState.edges[edge_key]
	var a: Vector2 = edge["a_vertice"]
	var b: Vector2 = edge["b_vertice"]
	var best_extension := 0

	for ek in BoardState.edges:
		if ek == edge_key or visited.has(ek):
			continue
		if BoardState.edges[ek]["owner"] != player_id:
			continue
		var ea: Vector2 = BoardState.edges[ek]["a_vertice"]
		var eb: Vector2 = BoardState.edges[ek]["b_vertice"]
		# Conecta se compartilha um vértice E esse vértice não é bloqueado por oponente
		var shared: Variant = null
		if ea == a or ea == b:
			shared = ea
		elif eb == a or eb == b:
			shared = eb
		if shared != null:
			# Verifica bloqueio por aldeia/cidade de oponente no vértice compartilhado
			var vert: Dictionary = BoardState.vertices.get(shared, {})
			var owner: Variant = vert.get("owner", null)
			if owner != null and owner != player_id:
				continue  # estrada interrompida
			var ext := _dfs_road(player_id, ek, visited)
			if ext > best_extension:
				best_extension = ext

	visited.erase(edge_key)
	return 1 + best_extension


## Faz o Bot escolher a estrada que aponta para o melhor vértice vizinho


func _setup_players():
	var p_color = GameConfig.player_color
	var p_icon = load("res://icons_assets/%s.png" % GameConfig.player_icon_name) as Texture2D

	players = [Player.new("Jogador 1", p_color, p_icon)]

	for i in range(GameConfig.bot_count):
		var icon_name: String = (
			GameConfig.bot_icon_names[i] if i < GameConfig.bot_icon_names.size() else "creeper"
		)
		var bot_icon = load("res://icons_assets/%s.png" % icon_name) as Texture2D
		var cn: String = (
			GameConfig.bot_color_names[i] if i < GameConfig.bot_color_names.size() else "blue"
		)
		var bot_color: Color = GameConfig.COLOR_MAP.get(cn, Color(0.22, 0.54, 0.87))
		players.append(Player.new("Bot " + str(i + 1), bot_color, bot_icon))

	dice_log.setup_players(players)
	dice_log.setup_dice_textures(dice_textures)
	(
		dice_log
		. setup_resource_textures(
			{
				"wood": player_hud.wood_icon,
				"brick": player_hud.brick_icon,
				"wheat": player_hud.wheat_icon,
				"sheep": player_hud.sheep_icon,
				"ore": player_hud.ore_icon,
			}
		)
	)
	player_hud.bind_human_player(players[0])
	_create_bot_huds()
	player_hud.apply_player_color(GameConfig.player_color_name)


func _create_bot_huds():
	var control = $Control

	for i in range(1, players.size()):
		var hud = preload("res://bot_hud.tscn").instantiate()
		hud.bot_index = i
		control.add_child(hud)
		var cn: String = (
			GameConfig.bot_color_names[i - 1]
			if (i - 1) < GameConfig.bot_color_names.size()
			else "blue"
		)
		hud.setup(players[i], cn)
		_bot_huds.append(hud)


func _refresh_bot_huds():
	for i in range(_bot_huds.size()):
		_bot_huds[i].refresh()


var _first_player_index: int = 0


func _build_preparation_order():
	var n = players.size()
	preparation_order.clear()

	_first_player_index = randi() % n
	print(
		(
			"Jogador sorteado para começar: %s (índice %d)"
			% [players[_first_player_index].player_name, _first_player_index]
		)
	)

	for i in range(n):
		preparation_order.append((_first_player_index + i) % n)

	for i in range(n - 1, -1, -1):
		preparation_order.append((_first_player_index + i) % n)


func start_preparation_phase():
	game_phase = GamePhase.PREPARATION
	preparation_step = 0
	preparation_done = false

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
		_bot_controller.place_settlement_prep()


func _on_preparation_vertice_selected(pos: Vector2):
	_hide_highlights()
	player_hud.stop_timer()

	if _try_place_settlement(pos, current_player_index, true):
		_prep_settlement_pos = Vector2(round(pos.x), round(pos.y))
		_waiting_prep_road = true

		_road_mode_active = true
		var board = find_child("Board")
		if board and board.has_method("show_road_highlights"):
			board.show_road_highlights(current_player_index, self)

		print("Aldeia colocada! Escolha uma estrada adjacente a ela para finalizar o turno.")
		player_hud.start_timer(preparation_turn_time, _on_preparation_timeout)
	else:
		_show_highlights_for_current(true)
		player_hud.start_timer(preparation_turn_time, _on_preparation_timeout)


func _is_edge_connected_to_vertex(edge_key: Vector2, vertex_key: Vector2) -> bool:
	if not BoardState.edges.has(edge_key):
		return false
	var edge = BoardState.edges[edge_key]
	return edge["a_vertice"] == vertex_key or edge["b_vertice"] == vertex_key


func _finish_preparation():
	preparation_done = true
	game_phase = GamePhase.PLAYING
	current_player_index = _first_player_index
	_hide_highlights()
	print(
		(
			"=== Preparação concluída! O jogo começa com %s. ==="
			% players[current_player_index].player_name
		)
	)
	start_turn()


func start_turn():
	has_rolled_dice = false

	var player = players[current_player_index]
	var is_human = current_player_index == 0

	# Reseta flags de turno
	player.reset_turn_flags()

	player_hud.setup_turn(player)
	player_hud.update_end_turn_button(is_human, false)

	# Atualiza interatividade das cartas de desenvolvimento do humano
	if _dev_card_panel:
		_dev_card_panel.set_playable(is_human)

	print("Turno de: ", player.player_name)

	if not is_human:
		player_hud.set_dice_enabled(false)
		player_hud.stop_timer()
		play_bot_turn()
	else:
		player_hud.set_dice_enabled(true)
		player_hud.start_timer(auto_roll_time, _on_roll_timeout)


func play_bot_turn():
	_bot_controller.play_turn(current_player_index)


func end_turn():
	_hide_highlights()
	_road_mode_active = false
	_settlement_mode_active = false
	_city_mode_active = false
	_pending_road_building_roads = 0
	player_hud.stop_timer()
	# Fecha o painel de troca se estiver aberto (fim de turno ou timeout)
	if player_hud._trade_panel != null and player_hud._trade_panel.visible:
		player_hud._trade_panel.close_trade()
	if _dev_card_panel:
		_dev_card_panel.set_playable(false)
	_refresh_bot_huds()
	current_player_index = (current_player_index + 1) % players.size()
	start_turn()


func _on_button_pressed():
	if current_player_index != 0:
		return
	if waiting_discard or waiting_robber_placement or waiting_robber_steal:
		print("Resolva o ladrão antes de terminar o turno!")
		return
	if _waiting_monopoly or _waiting_yop:
		print("Resolva a carta de desenvolvimento antes de terminar o turno!")
		return
	if has_rolled_dice:
		end_turn()
	else:
		print("Você precisa rolar os dados primeiro!")


func _on_roll_timeout():
	if game_phase != GamePhase.PLAYING or current_player_index != 0 or has_rolled_dice:
		return
	print("Tempo esgotado! Rolando dados automaticamente.")
	roll_dice()


func _on_preparation_timeout():
	if game_phase != GamePhase.PREPARATION or current_player_index != 0:
		return
	print("Tempo de preparação esgotado!")
	_hide_highlights()

	if _waiting_prep_road:
		# Força uma estrada adjacente qualquer se o tempo acabar na fase de estradas
		for ek in BoardState.edges:
			if (
				_is_edge_connected_to_vertex(ek, _prep_settlement_pos)
				and BoardState.edges[ek]["owner"] == null
			):
				BoardState.edges[ek]["owner"] = 0
				players[0].roads_remaining -= 1
				var board = find_child("Board")
				if board and board.has_method("spawn_road_visual"):
					board.spawn_road_visual(ek, players[0].player_color)
				break
		_waiting_prep_road = false
		_prep_settlement_pos = Vector2.ZERO
		_road_mode_active = false
		preparation_step += 1
		_preparation_next_player()
		return

	var valid_keys: Array = []
	for key in BoardState.vertices:
		if village_construction_check(key, current_player_index, true):
			valid_keys.append(key)

	if valid_keys.is_empty():
		preparation_step += 1
		_preparation_next_player()
		return

	var chosen_key = valid_keys[randi() % valid_keys.size()]
	if _try_place_settlement(chosen_key, current_player_index, true):
		_bot_controller.place_preparation_road(current_player_index, chosen_key)

	preparation_step += 1
	_preparation_next_player()


func _on_turn_timeout():
	if game_phase != GamePhase.PLAYING or current_player_index != 0:
		return
	print("Tempo do turno esgotado! Passando turno automaticamente.")
	end_turn()


func roll_dice():
	if game_phase == GamePhase.PREPARATION:
		return
	if has_rolled_dice:
		return

	has_rolled_dice = true
	player_hud.stop_timer()
	player_hud.set_dice_enabled(false)

	# Após rolar, o humano pode jogar cartas de desenvolvimento
	if current_player_index == 0 and _dev_card_panel:
		_dev_card_panel.set_playable(true)

	var dice1 = randi() % 6 + 1
	var dice2 = randi() % 6 + 1
	var total = dice1 + dice2
	var player = players[current_player_index]

	player_hud.show_dice_result(dice1, dice2)
	player_hud.update_end_turn_button(current_player_index == 0, true)

	print("%s rolou %d + %d = %d" % [player.player_name, dice1, dice2, total])

	dice_rolled.emit(player, dice1, dice2)
	dice_log.add_roll_entry(player, dice1, dice2)

	if current_player_index == 0:
		player_hud.start_timer(turn_time, _on_turn_timeout)

	on_dice_rolled(total)


func on_dice_rolled(value: int):
	if value == 7:
		print("LADRÃO ATIVADO!")
		player_hud.stop_timer()
		_start_robber_sequence()
	else:
		var resources_gained = produce_resources(value)
		dice_log.add_resources_entry(players, resources_gained)


func _start_robber_sequence():
	var someone_discarding = false

	# 1. Faz os bots descartarem automaticamente (sua função original)
	for i in range(1, players.size()):
		_discard_excess_cards(i)

	# 2. Avalia o humano
	var human_total = _get_player_total_cards(0)
	if human_total > 7:
		waiting_discard = true
		robber_panel.open_discard_mode(human_total / 2)  # Metade para baixo

		# Conecta o painel, se não estiver conectado
		if not robber_panel.discard_confirmed.is_connected(_on_human_discard_confirmed):
			robber_panel.discard_confirmed.connect(_on_human_discard_confirmed, CONNECT_ONE_SHOT)

		player_hud.start_timer(robber_discard_time, _on_robber_discard_timeout)
		print("[LADRÃO] Janela de descarte do humano: 20s")
	else:
		_prompt_robber_movement()


func _on_human_discard_confirmed(discarded: Array):
	waiting_discard = false
	player_hud.stop_timer()  # Cancela o timer de 20s

	for res in discarded:
		players[0].remove_resource(res, 1)
		bank_panel.return_resource(res, 1)

	_refresh_resource_ui()
	_prompt_robber_movement()


func _on_robber_discard_timeout():
	if not waiting_discard:
		return

	print("[TIMEOUT] Tempo esgotado! Descarte automático.")
	var player = players[0]
	var target_amount = _get_player_total_cards(0) / 2

	var hand_pool: Array[String] = []
	for res in player.resources:
		for i in range(player.resources[res]):
			hand_pool.append(res)

	hand_pool.shuffle()

	for i in range(min(target_amount, hand_pool.size())):
		var res = hand_pool[i]
		player.remove_resource(res, 1)
		bank_panel.return_resource(res, 1)

	robber_panel.hide()
	waiting_discard = false
	_refresh_resource_ui()
	_prompt_robber_movement()


func _prompt_robber_movement():
	if current_player_index == 0:
		waiting_robber_placement = true
		player_hud.start_timer(robber_move_time, _on_robber_move_timeout)
		robber_movement_human()  # Sua função que mostra as opções
	else:
		robber_movement_bot()  # Sua função original


func _on_human_robber_placed(pos: Vector2):
	waiting_robber_placement = false
	player_hud.stop_timer()

	# O board.gd já moveu o ladrão visualmente e atualizou o BoardState.
	# Busca vítimas válidas no hex escolhido.
	var victim_ids = _get_robber_victims(pos)

	if victim_ids.is_empty():
		print("Nenhuma vítima para roubar.")
		_resume_turn()
	elif victim_ids.size() == 1:
		print("Apenas uma vítima: roubando automaticamente.")
		_execute_steal(0, victim_ids[0])
	else:
		# Múltiplas vítimas: monta lista de Players e abre painel de escolha
		print("Múltiplas vítimas, abrindo painel de escolha.")
		waiting_robber_steal = true
		var victim_players: Array = []
		for vid in victim_ids:
			victim_players.append(players[vid])
		robber_panel.open_steal_mode(victim_players)
		if not robber_panel.is_connected("steal_target_chosen", _on_human_steal_target_chosen):
			robber_panel.steal_target_chosen.connect(_on_human_steal_target_chosen)


func _on_human_steal_target_chosen(target_player):
	waiting_robber_steal = false
	player_hud.stop_timer()
	var target_id = players.find(target_player)
	if target_id == -1:
		push_error("Vítima não encontrada na lista de jogadores!")
		_resume_turn()
		return
	_execute_steal(0, target_id)


func _on_robber_move_timeout():
	if not waiting_robber_placement and not waiting_robber_steal:
		return
	print("[TIMEOUT] Tempo de mover/roubar esgotado!")

	var target_hex_pos = BoardState.robber_hex_pos

	if waiting_robber_placement:
		var board = find_child("Board")
		if board and board.has_method("hide_robber_options"):
			board.hide_robber_options()

		# Pega qualquer hex diferente
		for child in board.get_children():
			if child is Node2D and child.has_meta("resource_type"):
				if child.position != target_hex_pos:
					target_hex_pos = child.position
					var robber_node = find_child("Robber", true, false)
					if robber_node:
						robber_node.moving_to(target_hex_pos, false)
					BoardState.update_robber_position(target_hex_pos)
					break

	waiting_robber_placement = false
	waiting_robber_steal = false
	robber_panel.hide()

	# Rouba aleatório
	var victims = _get_robber_victims(target_hex_pos)
	if not victims.is_empty():
		var random_victim = victims[randi() % victims.size()]
		_execute_steal(0, random_victim)
	else:
		_resume_turn()


# ─── FUNÇÕES AUXILIARES ───────────────────────────────────────────────────────
func _execute_steal(thief_id: int, victim_id: int):
	var victim = players[victim_id]
	var thief = players[thief_id]

	var stealable = []
	for res in victim.resources:
		for i in range(victim.resources[res]):
			stealable.append(res)

	if stealable.size() > 0:
		stealable.shuffle()
		var stolen_res = stealable[0]
		victim.remove_resource(stolen_res, 1)
		thief.add_resource(stolen_res, 1)
		print("Jogador %d roubou %s do Jogador %d" % [thief_id, stolen_res, victim_id])
		_refresh_resource_ui()

	_resume_turn()


func _resume_turn():
	# Só devolve o timer de 60s se for o turno do humano!
	if current_player_index == 0:
		player_hud.start_timer(turn_time, _on_turn_timeout)


func _get_player_total_cards(player_id: int) -> int:
	var total = 0
	for r in players[player_id].resources:
		total += players[player_id].resources[r]
	return total


func _get_robber_victims(hex_pos: Vector2) -> Array:
	# Busca jogadores no hex já excluindo quem está roubando
	var raw_victims = BoardState.get_players_on_hex(hex_pos, current_player_index)
	var valid_victims: Array = []

	# Só pode roubar de quem tem pelo menos 1 carta
	for victim_id in raw_victims:
		if _get_player_total_cards(victim_id) > 0:
			valid_victims.append(victim_id)

	return valid_victims


## Descarta metade das cartas se o jogador tiver mais de 7 (regra do ladrão)
func _discard_excess_cards(player_id: int) -> void:
	var player := players[player_id]
	var total := 0
	for r in player.resources:
		total += player.resources[r]
	if total <= 7:
		return

	var discard := total / 2  # arredonda para baixo
	print("%s deve descartar %d cartas (total: %d)" % [player.player_name, discard, total])

	if player_id != 0:
		# Bot descarta recursos menos úteis primeiro (ore > wheat > sheep > wood > brick)
		var priority := ["ore", "wheat", "sheep", "wood", "brick"]
		var remaining := discard
		for r in priority:
			if remaining <= 0:
				break
			var amt: int = min(player.resources.get(r, 0), remaining)
			if amt > 0:
				player.remove_resource(r, amt)
				bank_panel.return_resource(r, amt)
				remaining -= amt
	# Para o humano, idealmente abriria um popup de descarte.
	# Por ora o jogo continua sem forçar o descarte manual.
	_refresh_resource_ui()


func robber_movement_human():
	print("Humano: escolha onde colocar o ladrão.")
	var board = find_child("Board")
	if board:
		if not board.robber_placed.is_connected(_on_human_robber_placed):
			board.robber_placed.connect(_on_human_robber_placed, CONNECT_ONE_SHOT)
		board.show_robber_options()


func robber_movement_bot():
	_bot_controller.robber_movement(current_player_index)


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
			bank_panel.return_resource(resource, 1)

	BoardState.vertices[key]["owner"] = player_id
	BoardState.vertices[key]["type"] = BoardState.BuildingType.VILLAGE
	player.settlements_remaining -= 1
	player.points += 1

	var board = find_child("Board")
	if board:
		board.spawn_settlement_visual(key, player.player_color)
		if is_setup_phase and player.settlements_remaining == 3:
			give_initial_resources(pos, player_id)
	if player_id == 0:
		player_hud.update_pieces(players[0])
		player_hud.update_vp_and_knights()
	else:
		_refresh_bot_huds()
		player_hud.update_action_buttons(players[0])

	print("%s construiu aldeia em %s (pontos: %d)" % [player.player_name, str(key), player.points])
	_check_victory(player_id)
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

	# ─── TRAVA VISUAL DA FASE DE PREPARAÇÃO ───
	if game_phase == GamePhase.PREPARATION and _waiting_prep_road:
		# Se estivermos na preparação, só retorna TRUE se a estrada
		# tocar exatamente na aldeia que acabou de ser construída.
		return _is_edge_connected_to_vertex(edge_key, _prep_settlement_pos)
	# ──────────────────────────────────────────

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
			var shared_vertice = null

			if next_edge["a_vertice"] == a_v or next_edge["b_vertice"] == a_v:
				shared_vertice = a_v
			elif next_edge["a_vertice"] == b_v or next_edge["b_vertice"] == b_v:
				shared_vertice = b_v

			if shared_vertice != null:
				var vertice_owner = BoardState.vertices[shared_vertice]["owner"]

				if vertice_owner == null or vertice_owner == player_id:
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
			bank_panel.return_resource(resource, cost[resource])
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
		if not has_rolled_dice:
			print("Role os dados antes de construir!")
			return
		var key = Vector2(round(pos.x), round(pos.y))
		if not BoardState.vertices.has(key):
			return

		var vertice = BoardState.vertices[key]
		if vertice["owner"] == null and _settlement_mode_active:
			if _try_place_settlement(pos, current_player_index, false):
				# Sai do modo após construir
				_settlement_mode_active = false
				_hide_highlights()
				_refresh_resource_ui()
		elif (
			vertice["owner"] == current_player_index
			and vertice["type"] == BoardState.BuildingType.VILLAGE
			and _city_mode_active
		):
			if city_construction_check(pos, current_player_index):
				vertice["type"] = BoardState.BuildingType.CITY
				players[current_player_index].cities_remaining -= 1
				players[current_player_index].settlements_remaining += 1
				players[current_player_index].points += 1
				# Spawn visual: substitui aldeia por cidade
				var board_node := find_child("Board")
				if board_node and board_node.has_method("upgrade_settlement_to_city"):
					board_node.upgrade_settlement_to_city(
						key, players[current_player_index].player_color
					)
				# Sai do modo
				_city_mode_active = false
				_hide_highlights()
				_refresh_resource_ui()
				print("Cidade construída em ", key)
				_check_victory(current_player_index)


func give_initial_resources(vertex_pos: Vector2, player_id: int):
	var key = Vector2(round(vertex_pos.x), round(vertex_pos.y))

	if not BoardState.vertices.has(key):
		return

	var player = players[player_id]
	var hexes = BoardState.vertices[key]["links"]

	var resources_gained: Dictionary = {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}

	for hex in hexes:
		if not hex.has_meta("resource_type"):
			continue

		var type = hex.get_meta("resource_type")

		if type == 5:
			continue

		var resource_name = resource_type_to_string(type)

		print("INITIAL RESOURCE:", resource_name)

		if bank_panel.take_resource(resource_name, 1):
			player.add_resource(resource_name, 1)
			resources_gained[resource_name] += 1
		else:
			print("Banco sem", resource_name)

	_refresh_resource_ui()
	dice_log.add_preparation_resources_entry(player, resources_gained)


func _on_build_city_pressed():
	if game_phase != GamePhase.PLAYING or current_player_index != 0:
		return
	if not has_rolled_dice:
		print("Role os dados antes de construir cidades!")
		return

	var board := find_child("Board")
	if board == null:
		return

	if _city_mode_active:
		_reset_build_modes()
		return

	_reset_build_modes()

	# Verifica custo: 3 minerio + 2 trigo
	var cost = {"ore": 3, "wheat": 2}
	if not players[0].can_afford(cost):
		print("Recursos insuficientes para construir uma cidade (3 minério + 2 trigo).")
		return
	if players[0].cities_remaining <= 0:
		print("Sem peças de cidade disponíveis!")
		return

	# Verifica se o jogador tem pelo menos uma aldeia para promover
	var has_village = false
	for key in BoardState.vertices:
		var v = BoardState.vertices[key]
		if v["owner"] == 0 and v["type"] == BoardState.BuildingType.VILLAGE:
			has_village = true
			break
	if not has_village:
		print("Você não tem aldeias para promover a cidade!")
		return

	_city_mode_active = true
	board.show_city_highlights(current_player_index)
	print("Modo de construção de cidade ativado — clique numa aldeia sua.")


func _on_build_house_pressed():
	if game_phase != GamePhase.PLAYING or current_player_index != 0:
		return
	if not has_rolled_dice:
		print("Role os dados antes de construir aldeias!")
		return

	var board := find_child("Board")
	if board == null:
		return

	if _settlement_mode_active:
		_reset_build_modes()
		return

	_reset_build_modes()

	# Verifica custo: madeira + argila + lã + trigo
	var cost = {"wood": 1, "brick": 1, "sheep": 1, "wheat": 1}
	if not players[0].can_afford(cost):
		print(
			"Recursos insuficientes para construir uma aldeia (1 madeira + 1 argila + 1 lã + 1 trigo)."
		)
		return
	if players[0].settlements_remaining <= 0:
		print("Sem peças de aldeia disponíveis!")
		return

	_settlement_mode_active = true
	_show_highlights_for_current(false)
	print("Modo de construção de aldeia ativado — clique numa encruzilhada válida.")


func _on_build_road_pressed():
	if game_phase != GamePhase.PLAYING or current_player_index != 0:
		return
	if not has_rolled_dice and _pending_road_building_roads == 0:
		print("Role os dados antes de construir estradas!")
		return

	var board := find_child("Board")
	if board == null:
		return

	if _road_mode_active:
		_reset_build_modes()
		return

	_reset_build_modes()

	# Verifica se o jogador pode pagar (ou tem estradas gratuitas pela carta)
	if _pending_road_building_roads == 0:
		var cost = {"wood": 1, "brick": 1}
		if not players[0].can_afford(cost):
			print("Recursos insuficientes para construir uma estrada (1 madeira + 1 tijolo).")
			return
		if players[0].roads_remaining <= 0:
			print("Sem peças de estrada disponíveis!")
			return

	_road_mode_active = true
	board.show_road_highlights(current_player_index, self)
	print("Modo de construção de estrada ativado — clique numa posição válida.")


func _on_selected_edge(pos: Vector2):
	var key = Vector2(round(pos.x), round(pos.y))

	# ─── LÓGICA DE INTERCEPÇÃO PARA A PREPARAÇÃO ───
	if game_phase == GamePhase.PREPARATION:
		if not _waiting_prep_road or current_player_index != 0:
			return

		if _is_edge_connected_to_vertex(key, _prep_settlement_pos):
			BoardState.edges[key]["owner"] = current_player_index
			players[current_player_index].roads_remaining -= 1

			var board := find_child("Board")
			if board and board.has_method("spawn_road_visual"):
				board.spawn_road_visual(key, players[current_player_index].player_color)

			_waiting_prep_road = false
			_prep_settlement_pos = Vector2.ZERO
			_road_mode_active = false
			_hide_highlights()
			_refresh_resource_ui()

			# 🔧 CORREÇÃO: Para o timer imediatamente!
			player_hud.stop_timer()

			# Avança o turno apenas após colocar a casa E a estrada
			preparation_step += 1
			_preparation_next_player()
		else:
			print("Você precisa escolher uma estrada conectada à aldeia que acabou de criar!")
		return
	# ───────────────────────────────────────────────

	if game_phase != GamePhase.PLAYING or current_player_index != 0:
		return
	if not has_rolled_dice and _pending_road_building_roads == 0:
		print("Role os dados antes de construir estradas!")
		return
	if not _road_mode_active and _pending_road_building_roads == 0:
		return

	if road_construction_check(pos, current_player_index):
		BoardState.edges[key]["owner"] = current_player_index
		players[current_player_index].roads_remaining -= 1
		_check_longest_road(current_player_index)

		var board := find_child("Board")
		if board and board.has_method("spawn_road_visual"):
			board.spawn_road_visual(key, players[current_player_index].player_color)

		if _pending_road_building_roads > 0:
			_pending_road_building_roads -= 1
			if _pending_road_building_roads > 0:
				if board and board.has_method("show_road_highlights"):
					board.show_road_highlights(current_player_index, self)
			else:
				_road_mode_active = false
				if board and board.has_method("hide_road_highlights"):
					board.hide_road_highlights()
		else:
			players[current_player_index].remove_resource("wood", 1)
			players[current_player_index].remove_resource("brick", 1)
			bank_panel.return_resource("wood", 1)
			bank_panel.return_resource("brick", 1)
			_road_mode_active = false
			if board and board.has_method("hide_road_highlights"):
				board.hide_road_highlights()

		_refresh_resource_ui()
		print("Estrada construída em ", pos)


func _show_highlights_for_current(is_preparation: bool):
	var board = find_child("Board")
	if board and board.has_method("show_settlement_highlights"):
		board.show_settlement_highlights(current_player_index, is_preparation, self)


func _hide_highlights():
	var board = find_child("Board")
	if board:
		if board.has_method("hide_settlement_highlights"):
			board.hide_settlement_highlights()
		if board.has_method("hide_road_highlights"):
			board.hide_road_highlights()
		if board.has_method("hide_city_highlights"):
			board.hide_city_highlights()


func produce_resources(dice_value: int) -> Dictionary:
	print("Produzindo recursos para valor:", dice_value)

	var resources_gained: Dictionary = {}

	for vert_key in BoardState.vertices:
		var vert = BoardState.vertices[vert_key]

		if vert["owner"] == null:
			continue

		var player_id = vert["owner"]
		var player = players[player_id]

		var building_type = vert["type"]
		var amount = 0

		if building_type == BoardState.BuildingType.VILLAGE:
			amount = 1
		elif building_type == BoardState.BuildingType.CITY:
			amount = 2
		else:
			continue

		for hex in vert["links"]:
			if not is_instance_valid(hex):
				continue

			var number = hex.get_meta("dice_number") if hex.has_meta("dice_number") else 0

			if number != dice_value:
				continue

			var hex_pos = Vector2(round(hex.global_position.x), round(hex.global_position.y))
			if hex_pos == BoardState.robber_hex_pos:
				continue
			var resource_id = hex.get_meta("resource_type")
			var resource = resource_type_to_string(resource_id)

			if resource == "":
				continue

			var bank = get_node("Control/BankPanel")

			if bank.take_resource(resource, amount):
				player.add_resource(resource, amount)
				_refresh_resource_ui()
				if not resources_gained.has(player_id):
					resources_gained[player_id] = {
						"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0
					}
				resources_gained[player_id][resource] += amount
			else:
				print("Banco sem", resource)
				_refresh_resource_ui()

	return resources_gained


func _check_victory(player_id: int) -> void:
	if game_phase != GamePhase.PLAYING:
		return
	var player := players[player_id]
	if player.get_total_points() >= 10:
		print("=== %s VENCEU com %d pontos! ===" % [player.player_name, player.get_total_points()])
		_show_victory_screen()


func _show_victory_screen() -> void:
	# Pausa o jogo antes de exibir a tela
	get_tree().paused = true

	var victory_script = load("res://source/victory_screen.gd")
	if victory_script == null:
		push_error("victory_screen.gd não encontrado em res://source/")
		return

	var screen := CanvasLayer.new()
	screen.set_script(victory_script)
	screen.process_mode = Node.PROCESS_MODE_ALWAYS  # roda mesmo com o jogo pausado
	get_tree().root.add_child(screen)
	screen.show_victory(players, largest_army_owner, longest_road_owner)


func _refresh_resource_ui():
	player_hud.update_resources(players[0])
	player_hud.update_pieces(players[0])
	player_hud.update_vp_and_knights()
	_refresh_bot_huds()


# ── Helper de nome de carta (usado em logs) ────────────────────────────────────
func _card_type_name(card_type: int) -> String:
	match card_type:
		0:
			return "Cavaleiro"
		1:
			return "Construção de Estradas"
		2:
			return "Ano da Abundância"
		3:
			return "Monopólio"
		4:
			return "Capela"
		5:
			return "Universidade"
		6:
			return "Palácio"
		7:
			return "Biblioteca"
		8:
			return "Mercado"
	return "Desconhecida"


func _reset_build_modes() -> void:
	_road_mode_active = false
	_settlement_mode_active = false
	_city_mode_active = false

	_hide_highlights()


func _bot_get_surplus_resource(bot_id: int) -> String:
	var bot := players[bot_id]
	var best_res := ""
	var highest := 0

	for res in bot.resources:
		var amount: int = bot.resources[res]
		if amount >= 3 and amount > highest:
			highest = amount
			best_res = res

	return best_res


func _bot_get_needed_resource(bot_id: int) -> String:
	var bot := players[bot_id]
	var lowest := 999
	var needed := ""

	for res in bot.resources:
		var amount: int = bot.resources[res]
		if amount < lowest:
			lowest = amount
			needed = res

	return needed


func _human_accepts_bot_trade(give_res: String, recv_res: String) -> bool:
	var human := players[0]

	if human.resources.get(recv_res, 0) <= 0:
		return false

	if human.resources.get(give_res, 0) <= 1:
		return true

	if human.resources.get(recv_res, 0) >= 4 and human.resources.get(give_res, 0) <= 2:
		return true

	return false


func _bot_find_trade_partner(bot_id: int, give_res: String, recv_res: String) -> int:
	var best_score: float = -999.0
	var best_partner: int = -1

	for i in range(1, players.size()):
		if i == bot_id:
			continue

		var candidate: Player = players[i]

		var candidate_has: int = candidate.resources.get(recv_res, 0)
		if candidate_has <= 0:
			continue

		var score: float = 0.0

		var current: int = candidate.resources.get(give_res, 0)
		if current == 0:
			score += 3.0
		elif current <= 2:
			score += 2.0
		else:
			score += 1.0

		var remaining: int = candidate.resources.get(recv_res, 0) - 1
		if remaining == 0:
			score -= 2.0
		elif remaining == 1:
			score -= 1.0

		if score > best_score:
			best_score = score
			best_partner = i

	return best_partner


func _bot_try_trade(bot_id: int) -> void:
	# Só tenta trocar se não estiver em meio a outra ação
	if waiting_discard or waiting_robber_placement or waiting_robber_steal:
		return

	var give_res := _bot_get_surplus_resource(bot_id)
	var recv_res := _bot_get_needed_resource(bot_id)

	if give_res == "" or recv_res == "":
		return

	if give_res == recv_res:
		return

	var bot := players[bot_id]
	print("%s quer trocar %s por %s" % [bot.player_name, give_res, recv_res])

	# Verifica se o humano aceitaria
	if _human_accepts_bot_trade(give_res, recv_res):
		_show_bot_trade_offer(bot_id, give_res, recv_res)
		return

	# Depois tenta outros bots
	var trade_partner := _bot_find_trade_partner(bot_id, give_res, recv_res)
	if trade_partner != -1:
		_execute_player_trade(bot_id, trade_partner, [give_res], [recv_res])
		print("%s trocou com %s." % [bot.player_name, players[trade_partner].player_name])
		return

	# Depois tenta banco
	if bot.resources[give_res] >= 4:
		if execute_bank_trade(bot_id, give_res, recv_res):
			print("%s trocou com o banco." % bot.player_name)
		return


# ── POPUP DE TROCA DO BOT ────────────────────────────────────────────────────


func _show_bot_trade_offer(bot_id: int, give_res: String, recv_res: String):
	var bot := players[bot_id]

	# Se já existe um popup, fecha ele primeiro
	if _bot_trade_popup and is_instance_valid(_bot_trade_popup):
		_bot_trade_popup.queue_free()

	# Carrega a fonte Minecraft
	var minecraft_font = load("res://assets/fonts/1_Minecraft-Regular.otf")

	# Criar popup
	_bot_trade_popup = Control.new()
	_bot_trade_popup.name = "BotTradePopup"
	_bot_trade_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bot_trade_popup.z_index = 100  # Alto para ficar sobre tudo
	_bot_trade_popup.mouse_filter = Control.MOUSE_FILTER_STOP  # Bloqueia cliques atrás
	$Control.add_child(_bot_trade_popup)

	# Fundo semi-transparente
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bot_trade_popup.add_child(bg)

	# Painel central
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(450, 300)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.98)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.7, 0.4, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	_bot_trade_popup.add_child(panel)

	# Layout vertical
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 15)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	# Espacador superior
	vbox.add_child(Control.new())

	# Titulo
	var title = Label.new()
	title.name = "Title"
	title.text = "TRADE PROPOSAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	if minecraft_font:
		title.add_theme_font_override("font", minecraft_font)
	vbox.add_child(title)

	# Label da oferta com icones
	var offer_container = HBoxContainer.new()
	offer_container.name = "OfferContainer"
	offer_container.alignment = BoxContainer.ALIGNMENT_CENTER
	offer_container.add_theme_constant_override("separation", 20)
	vbox.add_child(offer_container)

	# O que o bot da
	var bot_gives = VBoxContainer.new()
	bot_gives.alignment = BoxContainer.ALIGNMENT_CENTER
	var bot_gives_label = Label.new()
	bot_gives_label.text = _translate_resource(recv_res)
	bot_gives_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
	bot_gives_label.add_theme_font_size_override("font_size", 16)
	if minecraft_font:
		bot_gives_label.add_theme_font_override("font", minecraft_font)
	bot_gives.add_child(bot_gives_label)

	var bot_gives_icon = TextureRect.new()
	bot_gives_icon.texture = _get_resource_texture(recv_res)
	bot_gives_icon.custom_minimum_size = Vector2(48, 48)
	bot_gives_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bot_gives_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bot_gives.add_child(bot_gives_icon)

	offer_container.add_child(bot_gives)

	# Seta
	var arrow = Label.new()
	arrow.text = "->"
	arrow.add_theme_font_size_override("font_size", 30)
	arrow.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if minecraft_font:
		arrow.add_theme_font_override("font", minecraft_font)
	offer_container.add_child(arrow)

	# O que o bot quer
	var bot_wants = VBoxContainer.new()
	bot_wants.alignment = BoxContainer.ALIGNMENT_CENTER
	var bot_wants_label = Label.new()
	bot_wants_label.text = _translate_resource(give_res)
	bot_wants_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6, 1))
	bot_wants_label.add_theme_font_size_override("font_size", 16)
	if minecraft_font:
		bot_wants_label.add_theme_font_override("font", minecraft_font)
	bot_wants.add_child(bot_wants_label)

	var bot_wants_icon = TextureRect.new()
	bot_wants_icon.texture = _get_resource_texture(give_res)
	bot_wants_icon.custom_minimum_size = Vector2(48, 48)
	bot_wants_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bot_wants_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bot_wants.add_child(bot_wants_icon)

	offer_container.add_child(bot_wants)

	# Linha divisoria
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 10)
	vbox.add_child(separator)

	# Nome do bot
	var bot_name_label = Label.new()
	bot_name_label.name = "BotName"
	bot_name_label.text = bot.player_name
	bot_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bot_name_label.add_theme_font_size_override("font_size", 16)
	bot_name_label.add_theme_color_override("font_color", bot.player_color)
	if minecraft_font:
		bot_name_label.add_theme_font_override("font", minecraft_font)
	vbox.add_child(bot_name_label)

	# Timer com contagem regressiva
	var timer_container = HBoxContainer.new()
	timer_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(timer_container)

	var timer_icon = Label.new()
	timer_icon.text = "TIME:"
	timer_icon.add_theme_font_size_override("font_size", 20)
	if minecraft_font:
		timer_icon.add_theme_font_override("font", minecraft_font)
	timer_container.add_child(timer_icon)

	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "20s"
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.add_theme_color_override("font_color", Color(1, 0.6, 0.3, 1))
	if minecraft_font:
		timer_label.add_theme_font_override("font", minecraft_font)
	timer_container.add_child(timer_label)

	# Botoes
	var hbox = HBoxContainer.new()
	hbox.name = "Buttons"
	hbox.add_theme_constant_override("separation", 30)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var accept_btn = Button.new()
	accept_btn.name = "AcceptButton"
	accept_btn.text = "ACCEPT"
	accept_btn.custom_minimum_size = Vector2(140, 50)
	accept_btn.add_theme_font_size_override("font_size", 16)
	accept_btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	if minecraft_font:
		accept_btn.add_theme_font_override("font", minecraft_font)

	# Estilo do botao Aceitar
	var accept_style = StyleBoxFlat.new()
	accept_style.bg_color = Color(0.3, 0.8, 0.3, 1)
	accept_style.border_width_left = 2
	accept_style.border_width_right = 2
	accept_style.border_width_top = 2
	accept_style.border_width_bottom = 2
	accept_style.border_color = Color(0, 0.5, 0, 1)
	accept_style.corner_radius_top_left = 6
	accept_style.corner_radius_top_right = 6
	accept_style.corner_radius_bottom_left = 6
	accept_style.corner_radius_bottom_right = 6
	accept_btn.add_theme_stylebox_override("normal", accept_style)

	var accept_hover = accept_style.duplicate()
	accept_hover.bg_color = Color(0.4, 0.9, 0.4, 1)
	accept_btn.add_theme_stylebox_override("hover", accept_hover)

	accept_btn.pressed.connect(_on_bot_trade_accept.bind(bot_id, give_res, recv_res))
	hbox.add_child(accept_btn)

	var refuse_btn = Button.new()
	refuse_btn.name = "RefuseButton"
	refuse_btn.text = "REFUSE"
	refuse_btn.custom_minimum_size = Vector2(140, 50)
	refuse_btn.add_theme_font_size_override("font_size", 16)
	refuse_btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	if minecraft_font:
		refuse_btn.add_theme_font_override("font", minecraft_font)

	# Estilo do botao Recusar
	var refuse_style = StyleBoxFlat.new()
	refuse_style.bg_color = Color(0.8, 0.3, 0.3, 1)
	refuse_style.border_width_left = 2
	refuse_style.border_width_right = 2
	refuse_style.border_width_top = 2
	refuse_style.border_width_bottom = 2
	refuse_style.border_color = Color(0.5, 0, 0, 1)
	refuse_style.corner_radius_top_left = 6
	refuse_style.corner_radius_top_right = 6
	refuse_style.corner_radius_bottom_left = 6
	refuse_style.corner_radius_bottom_right = 6
	refuse_btn.add_theme_stylebox_override("normal", refuse_style)

	var refuse_hover = refuse_style.duplicate()
	refuse_hover.bg_color = Color(0.9, 0.4, 0.4, 1)
	refuse_btn.add_theme_stylebox_override("hover", refuse_hover)

	refuse_btn.pressed.connect(_on_bot_trade_refuse.bind(bot_id))
	hbox.add_child(refuse_btn)

	# Espacador inferior
	vbox.add_child(Control.new())

	# Guardar referencias para o timer
	_bot_trade_bot_id = bot_id

	# Iniciar timer de 20s com atualizacao visual
	var time_left = 20.0
	var timer_update = func():
		while time_left > 0 and _bot_trade_popup and is_instance_valid(_bot_trade_popup):
			await get_tree().create_timer(0.1).timeout
			time_left -= 0.1
			if _bot_trade_popup and is_instance_valid(_bot_trade_popup):
				var timer_node = _bot_trade_popup.find_child("TimerLabel", true, false)
				if timer_node:
					timer_node.text = "%d.%ds" % [int(time_left), int(time_left * 10) % 10]
		if _bot_trade_popup and is_instance_valid(_bot_trade_popup):
			_on_bot_trade_timeout()

	timer_update.call()


func _on_bot_trade_timeout():
	if _bot_trade_popup and is_instance_valid(_bot_trade_popup):
		_bot_trade_popup.queue_free()
		_bot_trade_popup = null

	print("[TIMEOUT] Tempo esgotado! Troca recusada automaticamente.")
	_bot_trade_bot_id = -1


func _on_bot_trade_accept(bot_id: int, give_res: String, recv_res: String):
	if _bot_trade_popup and is_instance_valid(_bot_trade_popup):
		_bot_trade_popup.queue_free()
		_bot_trade_popup = null

	# Verificar se o bot ainda tem os recursos
	var bot = players[bot_id]
	var human = players[0]

	# Bot precisa ter o que vai dar (recv_res = recurso que o bot DA)
	if bot.resources.get(recv_res, 0) < 1:
		print("%s nao tem mais %s para dar!" % [bot.player_name, _translate_resource(recv_res)])
		return

	# Humano precisa ter o que o bot quer (give_res = recurso que o bot QUER)
	if human.resources.get(give_res, 0) < 1:
		print("Voce nao tem mais %s para dar!" % _translate_resource(give_res))
		return

	_execute_player_trade(bot_id, 0, [recv_res], [give_res])  # Bot da recv_res, humano da give_res
	print("%s aceitou a troca de %s." % [human.player_name, bot.player_name])
	_refresh_resource_ui()
	_bot_trade_bot_id = -1


func _on_bot_trade_refuse(bot_id: int):
	if _bot_trade_popup and is_instance_valid(_bot_trade_popup):
		_bot_trade_popup.queue_free()
		_bot_trade_popup = null

	print("Humano recusou a troca de %s." % players[bot_id].player_name)
	_bot_trade_bot_id = -1


func _translate_resource(res: String) -> String:
	match res:
		"wood":
			return "Wood"
		"brick":
			return "Brick"
		"wheat":
			return "Wheat"
		"sheep":
			return "Sheep"
		"ore":
			return "Ore"
	return res


func _get_resource_texture(res: String) -> Texture2D:
	match res:
		"wood":
			return player_hud.wood_icon
		"brick":
			return player_hud.brick_icon
		"wheat":
			return player_hud.wheat_icon
		"sheep":
			return player_hud.sheep_icon
		"ore":
			return player_hud.ore_icon
	return null
