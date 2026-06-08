extends GutTest

# ── Integration Tests: Board Generation ──────────────────────────────────────
# Moved from tests/test_board_generation.gd (was in root).
# Tests that the board shuffle algorithm always produces valid configurations:
# no adjacent 6/8 tiles and no resource type with more than one 6 or 8.

var Board = load("res://source/board.gd")


func test_board_never_has_adjacent_6_or_8():
	var board = Board.new()
	add_child_autofree(board)

	var adjacencies = [
		[1, 3, 4],        # 0
		[0, 2, 4, 5],     # 1
		[1, 5, 6],        # 2
		[0, 4, 7, 8],     # 3
		[0, 1, 3, 5, 8, 9],  # 4
		[1, 2, 4, 6, 9, 10], # 5
		[2, 5, 10, 11],   # 6
		[3, 8, 12],       # 7
		[3, 4, 7, 9, 12, 13], # 8
		[4, 5, 8, 10, 13, 14], # 9
		[5, 6, 9, 11, 14, 15], # 10
		[6, 10, 15],      # 11
		[7, 8, 13, 16],   # 12
		[8, 9, 12, 14, 16, 17], # 13
		[9, 10, 13, 15, 17, 18], # 14
		[10, 11, 14, 18], # 15
		[12, 13, 17],     # 16
		[13, 14, 16, 18], # 17
		[14, 15, 17],     # 18
	]

	for iteration in range(100):
		board.shuffle_valid_board()

		var hex_numbers = []
		var number_idx = 0
		for r in board.available_resources:
			if r == board.ResourceType.DESERT:
				hex_numbers.append(0)
			else:
				hex_numbers.append(board.available_numbers[number_idx])
				number_idx += 1

		for i in range(19):
			var num_i = hex_numbers[i]
			if num_i == 6 or num_i == 8:
				for adj in adjacencies[i]:
					var num_adj = hex_numbers[adj]
					assert_false(
						num_adj == 6 or num_adj == 8,
						"Adjacent 6/8 found at iteration %d, hex %d↔%d" % [iteration, i, adj]
					)


func test_board_no_resource_type_has_more_than_one_6_or_8():
	var board = Board.new()
	add_child_autofree(board)

	for iteration in range(100):
		board.shuffle_valid_board()

		var hex_numbers = []
		var number_idx = 0
		for r in board.available_resources:
			if r == board.ResourceType.DESERT:
				hex_numbers.append(0)
			else:
				hex_numbers.append(board.available_numbers[number_idx])
				number_idx += 1

		var red_counts = {}
		for i in range(19):
			var num_i = hex_numbers[i]
			if num_i == 6 or num_i == 8:
				var type = board.available_resources[i]
				red_counts[type] = red_counts.get(type, 0) + 1
				assert_true(
					red_counts[type] <= 1,
					"Resource type %s has >1 red tile on iteration %d" % [str(type), iteration]
				)


func test_board_always_has_19_hexes():
	var board = Board.new()
	add_child_autofree(board)
	board.shuffle_valid_board()
	assert_eq(board.available_resources.size(), 19)


func test_board_has_one_desert():
	var board = Board.new()
	add_child_autofree(board)
	board.shuffle_valid_board()
	var deserts = board.available_resources.filter(func(r): return r == board.ResourceType.DESERT)
	assert_eq(deserts.size(), 1)
