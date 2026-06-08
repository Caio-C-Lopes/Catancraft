extends GutTest
 
# Mocks
 
class MockPlayer:
	var player_name: String
	var resources: Dictionary
	var points: int = 0
 
	func _init(name: String, res: Dictionary):
		player_name = name
		resources = res
 
	func add_resource(type: String, amount: int):
		if not resources.has(type):
			resources[type] = 0
		resources[type] += amount
 
	func remove_resource(type: String, amount: int):
		if not resources.has(type):
			return
		resources[type] = max(0, resources[type] - amount)
 
	func can_afford(cost: Dictionary) -> bool:
		for r in cost:
			if not resources.has(r) or resources[r] < cost[r]:
				return false
		return true
 
 
# GameManager mínimo para testar as funções de troca isoladamente
class MockGM extends Node:
	var players: Array = []
 
	func _count_resources(res_array: Array) -> Dictionary:
		var counts := {}
		for r in res_array:
			counts[r] = counts.get(r, 0) + 1
		return counts
 
	func _bot_accepts_trade(bot_id: int, give_res: Array, recv_res: Array) -> bool:
		var bot = players[bot_id]
		var need_counts := _count_resources(recv_res)
		for res in need_counts:
			if bot.resources.get(res, 0) < need_counts[res]:
				return false
		var score := 0
		for res in give_res:
			var current: int = bot.resources.get(res, 0)
			if current == 0:
				score += 3
			elif current <= 2:
				score += 2
			else:
				score += 1
		var give_counts := _count_resources(recv_res)
		for res in give_counts:
			var current: int = bot.resources.get(res, 0)
			var giving: int = give_counts[res]
			var remaining: int = current - giving
			if remaining == 0:
				score -= 2
			elif remaining == 1:
				score -= 1
		return score >= 0
 
	func _execute_player_trade(
		player_a_id: int, player_b_id: int,
		a_gives: Array, b_gives: Array
	) -> void:
		var player_a = players[player_a_id]
		var player_b = players[player_b_id]
		var a_give_counts := _count_resources(a_gives)
		for res in a_give_counts:
			player_a.remove_resource(res, a_give_counts[res])
			player_b.add_resource(res, a_give_counts[res])
		var b_give_counts := _count_resources(b_gives)
		for res in b_give_counts:
			player_b.remove_resource(res, b_give_counts[res])
			player_a.add_resource(res, b_give_counts[res])
 
 
# Helpers
 
func _make_gm(human_res: Dictionary, bot_res: Dictionary) -> MockGM:
	var gm = MockGM.new()
	gm.players = [
		MockPlayer.new("Jogador 1", human_res),
		MockPlayer.new("Bot 1",     bot_res),
	]
	return gm

# Tests

func test_full_trade_flow_accepted():
	# Simula o fluxo completo: humano propõe → bot avalia → troca executada
	var gm = _make_gm(
		{"wood": 2, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0},
		{"wood": 0, "brick": 4, "wheat": 0, "sheep": 0, "ore": 0}
	)
	var give_res = ["wood"]
	var recv_res = ["brick"]
 
	# Bot avalia
	var accepted = gm._bot_accepts_trade(1, give_res, recv_res)
	assert_true(accepted, "Bot deve aceitar a troca")
 
	# Executa se aceitou
	if accepted:
		gm._execute_player_trade(0, 1, give_res, recv_res)
 
	assert_eq(gm.players[0].resources["wood"],  1, "Humano deve ter 1 wood após troca")
	assert_eq(gm.players[0].resources["brick"], 1, "Humano deve ter 1 brick após troca")
	assert_eq(gm.players[1].resources["wood"],  1, "Bot deve ter 1 wood após troca")
	assert_eq(gm.players[1].resources["brick"], 3, "Bot deve ter 3 brick após troca")
	gm.free()
 
 
func test_full_trade_flow_rejected():
	# Bot não tem o recurso pedido — troca não acontece
	var gm = _make_gm(
		{"wood": 2, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0},
		{"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}
	)
	var give_res = ["wood"]
	var recv_res = ["brick"]
 
	var accepted = gm._bot_accepts_trade(1, give_res, recv_res)
	assert_false(accepted, "Bot sem brick não deve aceitar")
 
	# Recursos devem permanecer intactos
	assert_eq(gm.players[0].resources["wood"],  2, "Recursos do humano não devem mudar")
	assert_eq(gm.players[1].resources["brick"], 0, "Recursos do bot não devem mudar")
	gm.free()
 
 
func test_full_trade_flow_multiple_bots_first_accepts():
	# Com 2 bots, apenas o primeiro aceita — só ele deve trocar
	var gm = MockGM.new()
	gm.players = [
		MockPlayer.new("Jogador 1", {"wood": 2, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}),
		MockPlayer.new("Bot 1",     {"wood": 0, "brick": 4, "wheat": 0, "sheep": 0, "ore": 0}),
		MockPlayer.new("Bot 2",     {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}),
	]
	var give_res = ["wood"]
	var recv_res = ["brick"]
 
	var accepted_by = []
	for i in range(1, gm.players.size()):
		if gm._bot_accepts_trade(i, give_res, recv_res):
			accepted_by.append(i)
 
	assert_eq(accepted_by.size(), 1,  "Apenas Bot 1 deve aceitar")
	assert_eq(accepted_by[0],    1,   "O bot que aceitou deve ser o índice 1")
 
	gm._execute_player_trade(0, accepted_by[0], give_res, recv_res)
 
	assert_eq(gm.players[0].resources["wood"],  1, "Humano deve ter 1 wood")
	assert_eq(gm.players[0].resources["brick"], 1, "Humano deve ter 1 brick")
	assert_eq(gm.players[2].resources["brick"], 0, "Bot 2 não deve ter sido afetado")
	gm.free()