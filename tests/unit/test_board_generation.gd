extends GutTest

var Board = load("res://source/board.gd")


func test_board_generation_constraints():
	var board = Board.new()

	var adjacencies = [
		[1, 3, 4],  # 0
		[0, 2, 4, 5],  # 1
		[1, 5, 6],  # 2
		[0, 4, 7, 8],  # 3
		[0, 1, 3, 5, 8, 9],  # 4
		[1, 2, 4, 6, 9, 10],  # 5
		[2, 5, 10, 11],  # 6
		[3, 8, 12],  # 7
		[3, 4, 7, 9, 12, 13],  # 8
		[4, 5, 8, 10, 13, 14],  # 9
		[5, 6, 9, 11, 14, 15],  # 10
		[6, 10, 15],  # 11
		[7, 8, 13, 16],  # 12
		[8, 9, 12, 14, 16, 17],  # 13
		[9, 10, 13, 15, 17, 18],  # 14
		[10, 11, 14, 18],  # 15
		[12, 13, 17],  # 16
		[13, 14, 16, 18],  # 17
		[14, 15, 17]  # 18
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

		var adjacent_violation = false
		for i in range(19):
			var num_i = hex_numbers[i]
			if num_i == 6 or num_i == 8:
				for adj in adjacencies[i]:
					var num_adj = hex_numbers[adj]
					if num_adj == 6 or num_adj == 8:
						adjacent_violation = true

		assert_false(adjacent_violation, "Found adjacent 6s or 8s on iteration %d" % iteration)

		var red_counts = {}
		var max_count_violation = false
		for i in range(19):
			var num_i = hex_numbers[i]
			if num_i == 6 or num_i == 8:
				var type = board.available_resources[i]
				if not red_counts.has(type):
					red_counts[type] = 0
				red_counts[type] += 1
				if red_counts[type] > 1:
					max_count_violation = true

		assert_false(
			max_count_violation,
			"Found resoure type with more than one 6 or 8 on iteration %d" % iteration
		)

	board.free()
