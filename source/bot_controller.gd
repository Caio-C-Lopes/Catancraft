# bot_controller.gd
extends Node

# game manager
var gm: Node


func setup(game_manager: Node) -> void:
	gm = game_manager


func play_turn(player_id: int) -> void:
	await gm.get_tree().create_timer(1.0).timeout

	play_knight_if_available(player_id)
	await gm.get_tree().process_frame

	while gm.waiting_discard or gm.waiting_robber_placement or gm.waiting_robber_steal:
		await gm.get_tree().process_frame

	await gm.get_tree().create_timer(1.0).timeout
	gm.roll_dice()

	while gm.waiting_discard or gm.waiting_robber_placement or gm.waiting_robber_steal:
		await gm.get_tree().process_frame

	await gm.get_tree().create_timer(1.0).timeout

	try_bank_trade(player_id)
	await gm.get_tree().create_timer(0.4).timeout

	try_build_city(player_id)
	await gm.get_tree().create_timer(0.4).timeout

	try_build_settlement(player_id)
	await gm.get_tree().create_timer(0.4).timeout

	try_build_road(player_id)
	await gm.get_tree().create_timer(0.4).timeout

	try_buy_dev_card(player_id)
	await gm.get_tree().create_timer(0.5).timeout

	gm.end_turn()


const NUMBER_SCORE := {2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 8: 5, 9: 4, 10: 3, 11: 2, 12: 1}


func score_vertex(key: Vector2) -> float:
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


func place_settlement_prep() -> void:
	var player_id: int = gm.current_player_index as int
	var best_score: float = -1.0
	var best_candidates: Array = []

	for key in BoardState.vertices:
		if not gm.village_construction_check(key, player_id, true):
			continue
		var score := score_vertex(key)
		if score > best_score:
			best_score = score
			best_candidates = [key]
		elif score == best_score:
			best_candidates.append(key)

	if best_candidates.is_empty():
		print("Bot %s sem vértice válido na preparação." % gm.players[player_id].player_name)
	else:
		var best_key = best_candidates[randi() % best_candidates.size()]
		print(
			"%s escolheu vértice com score %.1f" % [gm.players[player_id].player_name, best_score]
		)
		if gm._try_place_settlement(best_key, player_id, true):
			place_preparation_road(player_id, best_key)

	gm.preparation_step += 1
	gm._preparation_next_player()


func place_preparation_road(player_id: int, settlement_key: Vector2) -> void:
	var best_edge_key: Variant = null
	var best_edge_score: float = -1.0
	var valid_edges: Array = []

	for ek in BoardState.edges:
		var edge = BoardState.edges[ek]
		if edge["owner"] != null:
			continue
		if edge["a_vertice"] == settlement_key or edge["b_vertice"] == settlement_key:
			valid_edges.append(ek)

	if valid_edges.is_empty():
		return

	for ek in valid_edges:
		var edge = BoardState.edges[ek]
		var target_vertex = (
			edge["b_vertice"] if edge["a_vertice"] == settlement_key else edge["a_vertice"]
		)
		var score := score_vertex(target_vertex)
		if score > best_edge_score:
			best_edge_score = score
			best_edge_key = ek

	if best_edge_key == null:
		best_edge_key = valid_edges[randi() % valid_edges.size()]

	BoardState.edges[best_edge_key]["owner"] = player_id
	gm.players[player_id].roads_remaining -= 1

	var board := gm.find_child("Board")
	if board and board.has_method("spawn_road_visual"):
		board.spawn_road_visual(best_edge_key, gm.players[player_id].player_color)

	print(
		(
			"Bot %s colocou estrada de preparação em %s (score destino %.1f)"
			% [gm.players[player_id].player_name, str(best_edge_key), best_edge_score]
		)
	)


func robber_movement(player_id: int) -> void:
	gm.waiting_robber_placement = true
	var board := gm.find_child("Board")
	var current_robber_pos := BoardState.robber_hex_pos
	var best_hex_pos := Vector2.ZERO
	var best_score: float = -1.0

	const PROB := {2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 8: 5, 9: 4, 10: 3, 11: 2, 12: 1}

	if board:
		for child in board.get_children():
			if not (child is Node2D and child.has_meta("resource_type")):
				continue
			var hex_pos := Vector2(round(child.position.x), round(child.position.y))
			if hex_pos == current_robber_pos:
				continue
			var dice_num = child.get_meta("dice_number") if child.has_meta("dice_number") else 0
			var prob: float = PROB.get(dice_num, 0)
			var score: float = 0.0
			for vert_key in BoardState.vertices:
				var vert = BoardState.vertices[vert_key]
				if vert["owner"] == null or vert["owner"] == player_id:
					continue
				if child in vert["links"]:
					var mult := 2.0 if vert["type"] == BoardState.BuildingType.CITY else 1.0
					score += prob * mult
			if score > best_score:
				best_score = score
				best_hex_pos = child.position

	# Fallback: qualquer hex diferente do atual
	if best_score <= 0.0 and board:
		for child in board.get_children():
			if not (child is Node2D and child.has_meta("resource_type")):
				continue
			var hex_pos := Vector2(round(child.position.x), round(child.position.y))
			if hex_pos != current_robber_pos:
				best_hex_pos = child.position
				break

	if best_hex_pos != Vector2.ZERO:
		var robber_node := gm.find_child("Robber", true, false)
		if robber_node:
			robber_node.moving_to(best_hex_pos, false)
		BoardState.update_robber_position(best_hex_pos)
		print("Bot moveu o ladrão para: ", best_hex_pos, " (score: %.1f)" % best_score)

	gm.waiting_robber_placement = false

	var victims = gm._get_robber_victims(best_hex_pos)
	if not victims.is_empty():
		var random_victim = victims[randi() % victims.size()]
		gm._execute_steal(player_id, random_victim)
	else:
		gm._resume_turn()


func play_knight_if_available(player_id: int) -> void:
	const KNIGHT := 0
	var cards: Array[int] = gm.players[player_id].dev_cards
	for i in range(cards.size()):
		if cards[i] != KNIGHT:
			continue
		if gm.players[player_id].dev_card_bought_this_turn and i == cards.size() - 1:
			continue
		gm.play_dev_card(player_id, i, KNIGHT)
		return


func try_buy_dev_card(player_id: int) -> void:
	if gm.deck_empty():
		return
	if gm.players[player_id].can_afford({"ore": 1, "wheat": 1, "sheep": 1}):
		gm.buy_dev_card(player_id)


func choose_resource(player_id: int) -> String:
	var res_order := ["ore", "wheat", "sheep", "wood", "brick"]
	var min_amount := 9999
	var chosen := "ore"
	for r in res_order:
		var amt: int = gm.players[player_id].resources.get(r, 0)
		if amt < min_amount:
			min_amount = amt
			chosen = r
	return chosen


func best_monopoly_resource(player_id: int) -> String:
	var totals := {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}
	for i in range(gm.players.size()):
		if i == player_id:
			continue
		for r in totals:
			totals[r] += gm.players[i].resources.get(r, 0)
	var best_res := "ore"
	var best_amt := -1
	for r in totals:
		if totals[r] > best_amt:
			best_amt = totals[r]
			best_res = r
	return best_res


func place_free_road(player_id: int) -> void:
	for edge_key in BoardState.edges:
		var edge: Dictionary = BoardState.edges[edge_key]
		if edge["owner"] != null:
			continue
		if gm.road_construction_check(edge_key, player_id):
			BoardState.edges[edge_key]["owner"] = player_id
			gm.players[player_id].roads_remaining -= 1
			var board := gm.find_child("Board")
			if board and board.has_method("spawn_road_visual"):
				board.spawn_road_visual(edge_key, gm.players[player_id].player_color)
			print(
				(
					"Bot %s colocou estrada gratuita em %s"
					% [gm.players[player_id].player_name, str(edge_key)]
				)
			)
			gm._check_longest_road(player_id)
			break


func try_build_city(player_id: int) -> bool:
	var player = gm.players[player_id]
	var cost := {"ore": 3, "wheat": 2}
	var built := false

	while player.can_afford(cost) and player.cities_remaining > 0:
		var best_key: Variant = null
		var best_score: float = -1.0

		for vk in BoardState.vertices:
			var vert = BoardState.vertices[vk]
			if vert["owner"] != player_id or vert["type"] != BoardState.BuildingType.VILLAGE:
				continue
			var score := score_vertex(vk)
			if score > best_score:
				best_score = score
				best_key = vk

		if best_key == null:
			break

		if gm.city_construction_check(best_key, player_id):
			BoardState.vertices[best_key]["type"] = BoardState.BuildingType.CITY
			player.cities_remaining -= 1
			player.settlements_remaining += 1
			player.points += 1
			var board_node := gm.find_child("Board")
			if board_node and board_node.has_method("upgrade_settlement_to_city"):
				board_node.upgrade_settlement_to_city(best_key, player.player_color)
			print(
				(
					"Bot %s construiu cidade em %s (score %.1f, pontos: %d)"
					% [player.player_name, str(best_key), best_score, player.points]
				)
			)
			gm._refresh_resource_ui()
			gm._check_victory(player_id)
			built = true
		else:
			break

	return built


func try_build_settlement(player_id: int) -> bool:
	var player = gm.players[player_id]
	var cost := {"wood": 1, "brick": 1, "wheat": 1, "sheep": 1}
	var built := false

	while player.can_afford(cost) and player.settlements_remaining > 0:
		var best_key: Variant = null
		var best_score: float = -1.0

		for vk in BoardState.vertices:
			if not gm.village_construction_check(vk, player_id, false):
				continue
			var score := score_vertex(vk)
			if score > best_score:
				best_score = score
				best_key = vk

		if best_key == null:
			break

		if gm._try_place_settlement(best_key, player_id, false):
			print(
				(
					"Bot %s construiu aldeia em %s (score %.1f, pontos: %d)"
					% [player.player_name, str(best_key), best_score, player.points]
				)
			)
			built = true
		else:
			break

	return built


func try_build_road(player_id: int) -> bool:
	const MAX_ROAD_LOOKAHEAD := 3
	var player = gm.players[player_id]
	var cost := {"wood": 1, "brick": 1}
	var built := false

	while player.can_afford(cost) and player.roads_remaining > 0:
		var best_edge_key: Variant = null
		var best_score: float = -1.0

		for ek in BoardState.edges:
			var edge = BoardState.edges[ek]
			if edge["owner"] != null:
				continue
			if not gm.road_construction_check(ek, player_id):
				continue
			var score := road_lookahead_score(ek, player_id, MAX_ROAD_LOOKAHEAD)
			if score > best_score:
				best_score = score
				best_edge_key = ek

		if best_edge_key == null:
			break

		BoardState.edges[best_edge_key]["owner"] = player_id
		player.roads_remaining -= 1
		player.remove_resource("wood", 1)
		player.remove_resource("brick", 1)
		gm.bank_panel.return_resource("wood", 1)
		gm.bank_panel.return_resource("brick", 1)
		var board := gm.find_child("Board")
		if board and board.has_method("spawn_road_visual"):
			board.spawn_road_visual(best_edge_key, player.player_color)
		print(
			(
				"Bot %s construiu estrada em %s (score lookahead %.1f)"
				% [player.player_name, str(best_edge_key), best_score]
			)
		)
		gm._check_longest_road(player_id)
		gm._refresh_resource_ui()
		built = true

	return built


func road_lookahead_score(start_edge_key: Vector2, player_id: int, depth: int) -> float:
	if depth <= 0 or not BoardState.edges.has(start_edge_key):
		return 0.0

	var edge = BoardState.edges[start_edge_key]
	var verts := [edge["a_vertice"], edge["b_vertice"]]
	var best: float = 0.0

	for vk in verts:
		if BoardState.vertices.has(vk) and BoardState.vertices[vk]["owner"] == null:
			var s := score_vertex(vk)
			if s > best:
				best = s

		if depth > 1:
			for ek2 in BoardState.edges:
				if ek2 == start_edge_key:
					continue
				var e2 = BoardState.edges[ek2]
				if e2["owner"] != null and e2["owner"] != player_id:
					continue
				if e2["a_vertice"] != vk and e2["b_vertice"] != vk:
					continue
				var child_score := road_lookahead_score(ek2, player_id, depth - 1) * 0.85
				if child_score > best:
					best = child_score

	return best


func try_bank_trade(player_id: int) -> bool:
	var player = gm.players[player_id]
	var build_goals := [
		{"ore": 3, "wheat": 2},  # city
		{"wood": 1, "brick": 1, "wheat": 1, "sheep": 1},  # settlement
		{"wood": 1, "brick": 1},  # road
		{"ore": 1, "wheat": 1, "sheep": 1},  # dev card
	]
	var traded := false
	var made_trade := true

	while made_trade:
		made_trade = false
		var surplus: Array = []
		for r in player.resources:
			if player.resources[r] >= 4:
				surplus.append(r)
		if surplus.is_empty():
			break

		for goal in build_goals:
			if not _can_reach_goal_with_trade(player, goal, surplus):
				continue
			var need_res := _most_needed_for_goal(player, goal)
			if need_res == "":
				continue
			var give_res := _least_needed_surplus(player, goal, surplus)
			if give_res == "" or give_res == need_res:
				continue
			if gm.execute_bank_trade(player_id, give_res, need_res):
				print(
					(
						"Bot %s trocou com banco: 4x %s → 1x %s"
						% [player.player_name, give_res, need_res]
					)
				)
				made_trade = true
				traded = true
				break

	return traded


func _can_reach_goal_with_trade(player: Player, goal: Dictionary, surplus: Array) -> bool:
	for give_r in surplus:
		for need_r in goal:
			if player.resources.get(need_r, 0) >= goal[need_r]:
				continue
			if give_r == need_r:
				continue
			var sim := player.resources.duplicate()
			sim[give_r] = sim.get(give_r, 0) - 4
			sim[need_r] = sim.get(need_r, 0) + 1
			var ok := true
			for r in goal:
				if sim.get(r, 0) < goal[r]:
					ok = false
					break
			if ok:
				return true
	return false


func _most_needed_for_goal(player: Player, goal: Dictionary) -> String:
	var worst := ""
	var worst_deficit := 0
	for r in goal:
		var deficit: int = goal[r] - player.resources.get(r, 0)
		if deficit > worst_deficit:
			worst_deficit = deficit
			worst = r
	return worst


func _least_needed_surplus(player: Player, goal: Dictionary, surplus: Array) -> String:
	var best := ""
	var best_excess := -1
	for r in surplus:
		if r in goal:
			continue
		var excess: int = player.resources.get(r, 0)
		if excess > best_excess:
			best_excess = excess
			best = r
	if best == "":
		for r in surplus:
			var excess: int = player.resources.get(r, 0)
			if excess > best_excess:
				best_excess = excess
				best = r
	return best


## Decide se o bot aceita uma troca proposta pelo humano.
func accepts_trade(bot_id: int, give_res: Array, recv_res: Array) -> bool:
	var bot = gm.players[bot_id]

	# Bot precisa ter todos os recursos pedidos pelo humano
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

	print(
		(
			"%s avaliou troca: score=%d -> %s"
			% [bot.player_name, score, "ACEITA" if score >= 0 else "RECUSA"]
		)
	)
	return score >= 0


func _count_resources(res_array: Array) -> Dictionary:
	var counts := {}
	for r in res_array:
		counts[r] = counts.get(r, 0) + 1
	return counts
