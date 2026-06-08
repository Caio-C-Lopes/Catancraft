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

func test_execute_trade_transfers_resources_correctly():
	var gm = _make_gm(
		{"wood": 2, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0},
		{"wood": 0, "brick": 3, "wheat": 0, "sheep": 0, "ore": 0}
	)
	gm._execute_player_trade(0, 1, ["wood"], ["brick"])
 
	assert_eq(gm.players[0].resources["wood"],  1, "Humano deve ter 1 wood após dar 1")
	assert_eq(gm.players[0].resources["brick"], 1, "Humano deve ter 1 brick após receber")
	assert_eq(gm.players[1].resources["wood"],  1, "Bot deve ter 1 wood após receber")
	assert_eq(gm.players[1].resources["brick"], 2, "Bot deve ter 2 brick após dar 1")
	gm.free()
 
 
func test_execute_trade_multiple_cards():
	var gm = _make_gm(
		{"wood": 3, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0},
		{"wood": 0, "brick": 0, "wheat": 2, "sheep": 2, "ore": 0}
	)
	gm._execute_player_trade(0, 1, ["wood", "wood"], ["wheat", "sheep"])
 
	assert_eq(gm.players[0].resources["wood"],  1, "Humano deve ter 1 wood restante")
	assert_eq(gm.players[0].resources["wheat"], 1, "Humano deve ter 1 wheat recebido")
	assert_eq(gm.players[0].resources["sheep"], 1, "Humano deve ter 1 sheep recebido")
	assert_eq(gm.players[1].resources["wood"],  2, "Bot deve ter 2 wood recebidos")
	assert_eq(gm.players[1].resources["wheat"], 1, "Bot deve ter 1 wheat restante")
	assert_eq(gm.players[1].resources["sheep"], 1, "Bot deve ter 1 sheep restante")
	gm.free()
 
 
func test_execute_trade_does_not_go_negative():
	# Garante que remove_resource não deixa recursos negativos
	var gm = _make_gm(
		{"wood": 1, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0},
		{"wood": 0, "brick": 1, "wheat": 0, "sheep": 0, "ore": 0}
	)
	gm._execute_player_trade(0, 1, ["wood"], ["brick"])
 
	assert_eq(gm.players[0].resources["wood"],  0, "Humano não deve ter wood negativo")
	assert_eq(gm.players[1].resources["brick"], 0, "Bot não deve ter brick negativo")
	gm.free()
 
 
func test_execute_trade_preserves_uninvolved_resources():
	# Recursos que não fazem parte da troca não devem ser alterados
	var gm = _make_gm(
		{"wood": 2, "brick": 5, "wheat": 3, "sheep": 1, "ore": 4},
		{"wood": 1, "brick": 2, "wheat": 4, "sheep": 3, "ore": 2}
	)
	gm._execute_player_trade(0, 1, ["wood"], ["wheat"])
 
	assert_eq(gm.players[0].resources["brick"], 5, "brick do humano não deve mudar")
	assert_eq(gm.players[0].resources["sheep"], 1, "sheep do humano não deve mudar")
	assert_eq(gm.players[0].resources["ore"],   4, "ore do humano não deve mudar")
	assert_eq(gm.players[1].resources["brick"], 2, "brick do bot não deve mudar")
	assert_eq(gm.players[1].resources["sheep"], 3, "sheep do bot não deve mudar")
	assert_eq(gm.players[1].resources["ore"],   2, "ore do bot não deve mudar")
	gm.free()