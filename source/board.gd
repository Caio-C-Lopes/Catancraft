extends Node2D

enum ResourceType { WOOD, SHEEP, WHEAT, BRICK, ORE, DESERT }

@export_group("Size")
@export var HEX_SIZE: float = 60.0

@export_group("Resource Textures")
@export var wood_texture: Texture2D
@export var sheep_texture: Texture2D
@export var wheat_texture: Texture2D
@export var brick_texture: Texture2D
@export var ore_texture: Texture2D
@export var desert_texture: Texture2D

var HEX_WIDTH = sqrt(3) * HEX_SIZE
var HEX_HEIGHT = 2 * HEX_SIZE

var available_resources = [
	ResourceType.DESERT,
	ResourceType.WOOD,
	ResourceType.WOOD,
	ResourceType.WOOD,
	ResourceType.WOOD,
	ResourceType.SHEEP,
	ResourceType.SHEEP,
	ResourceType.SHEEP,
	ResourceType.SHEEP,
	ResourceType.WHEAT,
	ResourceType.WHEAT,
	ResourceType.WHEAT,
	ResourceType.WHEAT,
	ResourceType.BRICK,
	ResourceType.BRICK,
	ResourceType.BRICK,
	ResourceType.ORE,
	ResourceType.ORE,
	ResourceType.ORE
]

var available_numbers = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]

# Higher chance of coming = Higher size
var number_font_sizes = {2: 12, 12: 12, 3: 14, 11: 14, 4: 16, 10: 16, 5: 18, 9: 18, 6: 24, 8: 24}

var board_layout = [3, 4, 5, 4, 3]


func _ready():
	randomize()
	shuffle_valid_board()
	generate_board()


func shuffle_valid_board():
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

	while true:
		available_resources.shuffle()
		available_numbers.shuffle()

		var hex_numbers = []
		var number_idx = 0
		for r in available_resources:
			if r == ResourceType.DESERT:
				hex_numbers.append(0)
			else:
				hex_numbers.append(available_numbers[number_idx])
				number_idx += 1

		var is_valid = true

		for i in range(19):
			var num_i = hex_numbers[i]
			if num_i == 6 or num_i == 8:
				for adj in adjacencies[i]:
					var num_adj = hex_numbers[adj]
					if num_adj == 6 or num_adj == 8:
						is_valid = false
						break
			if not is_valid:
				break

		if not is_valid:
			continue

		var red_counts = {}
		for i in range(19):
			var num_i = hex_numbers[i]
			if num_i == 6 or num_i == 8:
				var type = available_resources[i]
				if not red_counts.has(type):
					red_counts[type] = 0
				red_counts[type] += 1
				if red_counts[type] > 1:
					is_valid = false
					break

		if is_valid:
			break


func generate_board():
	var bg_index = randi() % 9 + 1
	var bg_texture = load("res://board_assets/BOARD_BG_%d.png" % bg_index)
	var bg = Sprite2D.new()
	bg.texture = bg_texture
	var viewport_size = get_viewport_rect().size
	bg.scale = Vector2(
		viewport_size.x / bg_texture.get_width(), viewport_size.y / bg_texture.get_height()
	)
	bg.position = viewport_size / 2.0
	add_child(bg)

	var resource_index = 0
	var number_index = 0

	var screen_center = get_viewport_rect().size / 2.0
	var grid_start_x = screen_center.x - (2.5 * HEX_WIDTH)
	var grid_start_y = screen_center.y - (2 * HEX_HEIGHT * 0.75)

	for row in range(board_layout.size()):
		var hexes_in_row = board_layout[row]
		var row_offset_x = (5 - hexes_in_row) * (HEX_WIDTH / 2.0)

		for col in range(hexes_in_row):
			var pos_x = grid_start_x + row_offset_x + (col * HEX_WIDTH)
			var pos_y = grid_start_y + (row * HEX_HEIGHT * 0.75)

			var type = available_resources[resource_index]
			resource_index += 1

			var number = 0
			if type != ResourceType.DESERT:
				number = available_numbers[number_index]
				number_index += 1

			create_hex(Vector2(pos_x, pos_y), type, number)


func create_hex(pos: Vector2, type: ResourceType, number: int):
	var hex_container = Node2D.new()
	hex_container.position = pos

	hex_container.set_meta("resource_type", type)
	hex_container.set_meta("dice_number", number)

	var texture_to_use: Texture2D = null
	match type:
		ResourceType.WOOD:
			texture_to_use = wood_texture
		ResourceType.SHEEP:
			texture_to_use = sheep_texture
		ResourceType.WHEAT:
			texture_to_use = wheat_texture
		ResourceType.BRICK:
			texture_to_use = brick_texture
		ResourceType.ORE:
			texture_to_use = ore_texture
		ResourceType.DESERT:
			texture_to_use = desert_texture

	if texture_to_use != null:
		var sprite = Sprite2D.new()
		sprite.texture = texture_to_use
		var scale_x = HEX_WIDTH / texture_to_use.get_width()
		var scale_y = HEX_HEIGHT / texture_to_use.get_height()
		sprite.scale = Vector2(scale_x, scale_y)
		hex_container.add_child(sprite)
	else:
		var polygon = Polygon2D.new()
		var points = PackedVector2Array()
		for i in range(6):
			var angle_rad = deg_to_rad(60 * i - 30)
			points.append(Vector2(cos(angle_rad), sin(angle_rad)) * HEX_SIZE)
		polygon.polygon = points

		var outline = Line2D.new()
		var outline_points = points.duplicate()
		outline_points.append(points[0])
		outline.points = outline_points
		outline.width = 4.0
		outline.default_color = Color(0.1, 0.1, 0.1)

		hex_container.add_child(polygon)
		hex_container.add_child(outline)

	if number > 0:
		var token_bg = Polygon2D.new()
		var circle_points = PackedVector2Array()
		for i in range(32):
			var angle = (i / 32.0) * TAU
			circle_points.append(Vector2(cos(angle), sin(angle)) * 18.0)
		token_bg.polygon = circle_points
		token_bg.color = Color(0.91, 0.82, 0.62)
		hex_container.add_child(token_bg)

		var label = Label.new()
		label.text = str(number)
		var font = load("res://assets/fonts/1_Minecraft-Regular.otf")
		label.add_theme_font_override("font", font)

		if number == 6 or number == 8:
			label.add_theme_color_override("font_color", Color(0.7, 0.1, 0.1))
		else:
			label.add_theme_color_override("font_color", Color(0.1, 0.35, 0.1))

		var font_size = number_font_sizes[number]
		label.add_theme_font_size_override("font_size", font_size)

		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(40, 40)
		label.position = Vector2(-20, -20)

		hex_container.add_child(label)

	add_child(hex_container)
