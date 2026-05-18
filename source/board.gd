extends Node2D

enum ResourceType { WOOD, SHEEP, WHEAT, BRICK, ORE, DESERT }

@export_group("Size")
@export var HEX_SIZE: float = 60.0

@export_group("Resource Textures")
@export var wood_texture:   Texture2D
@export var sheep_texture:  Texture2D
@export var wheat_texture:  Texture2D
@export var brick_texture:  Texture2D
@export var ore_texture:    Texture2D
@export var desert_texture: Texture2D

var HEX_WIDTH  = sqrt(3) * HEX_SIZE
var HEX_HEIGHT = 2       * HEX_SIZE

signal selected_vertice(pos: Vector2)
signal selected_edge(pos: Vector2)

var _vertice_nodes: Dictionary = {}

var available_resources = [
	ResourceType.DESERT,
	ResourceType.WOOD,  ResourceType.WOOD,  ResourceType.WOOD,  ResourceType.WOOD,
	ResourceType.SHEEP, ResourceType.SHEEP, ResourceType.SHEEP, ResourceType.SHEEP,
	ResourceType.WHEAT, ResourceType.WHEAT, ResourceType.WHEAT, ResourceType.WHEAT,
	ResourceType.BRICK, ResourceType.BRICK, ResourceType.BRICK,
	ResourceType.ORE,   ResourceType.ORE,   ResourceType.ORE,
]

var available_numbers = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]
var number_font_sizes = {2: 12, 12: 12, 3: 14, 11: 14, 4: 16, 10: 16, 5: 18, 9: 18, 6: 24, 8: 24}
var board_layout      = [3, 4, 5, 4, 3]


func _ready():
	randomize()
	shuffle_valid_board()
	generate_board()


func shuffle_valid_board():
	var adjacencies = [
		[1, 3, 4], [0, 2, 4, 5], [1, 5, 6],
		[0, 4, 7, 8], [0, 1, 3, 5, 8, 9], [1, 2, 4, 6, 9, 10], [2, 5, 10, 11],
		[3, 8, 12], [3, 4, 7, 9, 12, 13], [4, 5, 8, 10, 13, 14],
		[5, 6, 9, 11, 14, 15], [6, 10, 15],
		[7, 8, 13, 16], [8, 9, 12, 14, 16, 17], [9, 10, 13, 15, 17, 18],
		[10, 11, 14, 18], [12, 13, 17], [13, 14, 16, 18], [14, 15, 17],
	]

	while true:
		available_resources.shuffle()
		available_numbers.shuffle()

		var hex_numbers = []
		var number_idx  = 0
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
					if hex_numbers[adj] == 6 or hex_numbers[adj] == 8:
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
				red_counts[type] = red_counts.get(type, 0) + 1
				if red_counts[type] > 1:
					is_valid = false
					break

		if is_valid:
			break


func generate_board():
	var bg_index   = randi() % 9 + 1
	var bg_texture = load("res://board_assets/BOARD_BG_%d.png" % bg_index)
	var bg         = Sprite2D.new()
	bg.texture     = bg_texture
	var vp         = get_viewport_rect().size
	bg.scale       = Vector2(vp.x / bg_texture.get_width(), vp.y / bg_texture.get_height())
	bg.position    = vp / 2.0
	add_child(bg)

	var resource_index = 0
	var number_index   = 0
	var screen_center  = get_viewport_rect().size / 2.0
	var grid_start_x   = screen_center.x - (2.5 * HEX_WIDTH)
	var grid_start_y   = screen_center.y - (2 * HEX_HEIGHT * 0.75)

	for row in range(board_layout.size()):
		var hexes_in_row = board_layout[row]
		var row_offset_x = (5 - hexes_in_row) * (HEX_WIDTH / 2.0)
		for col in range(hexes_in_row):
			var pos_x = grid_start_x + row_offset_x + (col * HEX_WIDTH)
			var pos_y = grid_start_y + (row * HEX_HEIGHT * 0.75)
			var type  = available_resources[resource_index]
			resource_index += 1
			var number = 0
			if type != ResourceType.DESERT:
				number = available_numbers[number_index]
				number_index += 1
			create_hex(Vector2(pos_x, pos_y), type, number)

	for child in get_children():
		if child.has_meta("resource_type") and child.get_meta("resource_type") == ResourceType.DESERT:
			var deserto_pos = child.position
			BoardState.set_initial_robber_pos(deserto_pos)
			var robber_node = get_tree().current_scene.find_child("Robber", true, false)
			if robber_node:
				robber_node.moving_to(deserto_pos, true)
			break


func create_hex(pos: Vector2, type: ResourceType, number: int):
	var hex_container = Node2D.new()
	hex_container.position = pos

	var area_hex      = Area2D.new()
	var collision_hex = CollisionShape2D.new()
	var shape_hex     = RectangleShape2D.new()
	shape_hex.size    = Vector2(HEX_WIDTH * 0.8, HEX_HEIGHT * 0.5)
	collision_hex.shape = shape_hex
	area_hex.add_child(collision_hex)
	hex_container.add_child(area_hex)
	area_hex.input_event.connect(_on_hex_input_event.bind(pos, type))

	var local_points  = PackedVector2Array()
	var global_points = PackedVector2Array()

	for i in range(6):
		var angle_rad = deg_to_rad(60 * i - 30)
		var local_pt  = Vector2(cos(angle_rad), sin(angle_rad)) * HEX_SIZE
		local_points.append(local_pt)
		var global_pt = pos + local_pt
		global_points.append(global_pt)
		BoardState.register_vertices(global_pt)
		_create_vertice_node(global_pt)
		var key = Vector2(round(global_pt.x), round(global_pt.y))
		BoardState.vertices[key]["links"].append(hex_container)

	for i in range(6):
		BoardState.register_edges(global_points[i], global_points[(i + 1) % 6])
		create_road_spaces(global_points[i], global_points[(i + 1) % 6])

	hex_container.set_meta("resource_type", type)
	hex_container.set_meta("dice_number",   number)

	var texture_to_use: Texture2D = null
	match type:
		ResourceType.WOOD:   texture_to_use = wood_texture
		ResourceType.SHEEP:  texture_to_use = sheep_texture
		ResourceType.WHEAT:  texture_to_use = wheat_texture
		ResourceType.BRICK:  texture_to_use = brick_texture
		ResourceType.ORE:    texture_to_use = ore_texture
		ResourceType.DESERT: texture_to_use = desert_texture

	if texture_to_use != null:
		var sprite   = Sprite2D.new()
		sprite.texture = texture_to_use
		sprite.scale   = Vector2(HEX_WIDTH / texture_to_use.get_width(), HEX_HEIGHT / texture_to_use.get_height())
		hex_container.add_child(sprite)
	else:
		var polygon = Polygon2D.new()
		polygon.polygon = local_points
		var outline = Line2D.new()
		var ol_pts  = local_points.duplicate()
		ol_pts.append(local_points[0])
		outline.points = ol_pts
		outline.width  = 4.0
		outline.default_color = Color(0.1, 0.1, 0.1)
		hex_container.add_child(polygon)
		hex_container.add_child(outline)

	if number > 0:
		var token_bg = Polygon2D.new()
		var circ_pts = PackedVector2Array()
		for i in range(32):
			var angle = (i / 32.0) * TAU
			circ_pts.append(Vector2(cos(angle), sin(angle)) * 18.0)
		token_bg.polygon = circ_pts
		token_bg.color   = Color(0.91, 0.82, 0.62)
		hex_container.add_child(token_bg)

		var label = Label.new()
		label.text = str(number)
		var font   = load("res://assets/fonts/1_Minecraft-Regular.otf")
		label.add_theme_font_override("font", font)
		if number == 6 or number == 8:
			label.add_theme_color_override("font_color", Color(0.7, 0.1, 0.1))
		else:
			label.add_theme_color_override("font_color", Color(0.1, 0.35, 0.1))
		label.add_theme_font_size_override("font_size", number_font_sizes[number])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size  = Vector2(40, 40)
		label.position             = Vector2(-20, -20)
		hex_container.add_child(label)

	add_child(hex_container)


func _create_vertice_node(pos: Vector2):
	var key = Vector2(round(pos.x), round(pos.y))
	if _vertice_nodes.has(key):
		return

	var container = Node2D.new()
	container.position = pos
	container.z_index  = 10
	container.visible  = false

	var shadow = _make_circle_poly(10.0, Color(0, 0, 0, 0.55))
	container.add_child(shadow)

	var circle = _make_circle_poly(17.0, Color(1, 1, 1, 0.55))
	container.add_child(circle)

	var border = _make_circle_outline(17.0, 2.5, Color(0.15, 0.15, 0.15, 0.9))
	container.add_child(border)

	var area      = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape     = CircleShape2D.new()
	shape.radius  = 20.0
	collision.shape = shape
	area.add_child(collision)
	container.add_child(area)

	area.mouse_entered.connect(func():
		circle.color = Color(1.0, 0.75, 0.1, 0.9)
		shadow.color = Color(0, 0, 0, 0.7)
	)
	area.mouse_exited.connect(func():
		circle.color = Color(1, 1, 1, 0.55)
		shadow.color = Color(0, 0, 0, 0.55)
	)
	area.input_event.connect(_on_vertice_input.bind(pos))

	_vertice_nodes[key] = {
		"container": container,
		"circle":    circle,
		"shadow":    shadow,
		"area":      area,
	}

	add_child(container)


func _make_circle_outline(radius: float, width: float, color: Color) -> Line2D:
	var line = Line2D.new()
	var pts  = PackedVector2Array()
	for i in range(25):
		var angle = (i / 24.0) * TAU
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	line.points        = pts
	line.width         = width
	line.default_color = color
	return line


func _make_circle_poly(radius: float, color: Color) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts  = PackedVector2Array()
	for i in range(24):
		var angle = (i / 24.0) * TAU
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = pts
	poly.color   = color
	return poly


func _on_vertice_hover(_key: Vector2, _entered: bool):
	pass


@warning_ignore("unused_parameter")
func _on_vertice_input(viewport: Node, event: InputEvent, shape_idx: int, pos: Vector2):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var key = Vector2(round(pos.x), round(pos.y))
		if _vertice_nodes.has(key) and _vertice_nodes[key]["container"].visible:
			selected_vertice.emit(pos)


func show_settlement_highlights(player_id: int, is_preparation: bool, gm: Node):
	for key in _vertice_nodes:
		var valid = gm.village_construction_check(key, player_id, is_preparation)
		_vertice_nodes[key]["container"].visible       = valid
		_vertice_nodes[key]["area"].input_pickable     = valid


func hide_settlement_highlights():
	for key in _vertice_nodes:
		_vertice_nodes[key]["container"].visible   = false
		_vertice_nodes[key]["area"].input_pickable = false


func spawn_settlement_visual(pos: Vector2, color: Color):
	var key = Vector2(round(pos.x), round(pos.y))

	if _vertice_nodes.has(key):
		_vertice_nodes[key]["container"].visible   = false
		_vertice_nodes[key]["area"].input_pickable = false

	var settlement   = Node2D.new()
	settlement.position = pos
	settlement.z_index  = 10

	var texture_path = _get_house_texture_path(color)
	var texture      = load(texture_path)

	var sprite     = Sprite2D.new()
	sprite.texture = texture
	var target_size = 36.0
	sprite.scale    = Vector2(
		target_size / texture.get_width(),
		target_size / texture.get_height()
	)
	sprite.position = Vector2(0, -target_size * 0.4)

	settlement.add_child(sprite)
	settlement.add_to_group("settlements")
	add_child(settlement)


func _get_house_texture_path(color: Color) -> String:
	var r = color.r
	var g = color.g
	var b = color.b

	if r > 0.6 and g < 0.5 and b < 0.5:
		return "res://board_assets/house_red.png"
	if b > 0.6 and r < 0.5 and g < 0.7:
		return "res://board_assets/house_blue.png"
	if g > 0.6 and r < 0.5 and b < 0.5:
		return "res://board_assets/house_green.png"
	return "res://board_assets/house_purple.png"


func create_road_spaces(a_vertice: Vector2, b_vertice: Vector2):
	var center    = (a_vertice + b_vertice) / 2.0
	var area      = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape     = CircleShape2D.new()
	shape.radius  = 10.0
	collision.shape = shape
	area.position   = center
	area.add_child(collision)
	area.input_event.connect(road_click_check.bind(center))
	add_child(area)


@warning_ignore("unused_parameter")
func road_click_check(viewport: Node, event: InputEvent, shape_idx: int, pos: Vector2):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected_edge.emit(pos)


func _on_hex_input_event(_viewport, event, _shape_idx, pos, _type):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var gm = get_parent()
		if gm.waiting_robber_move:
			var clicked_pos = Vector2(round(pos.x), round(pos.y))
			if clicked_pos == BoardState.robber_hex_pos:
				print("O ladrão já está aqui! Escolha outro hexágono.")
				return
			var robber_node = get_tree().current_scene.find_child("Robber", true, false)
			if robber_node:
				robber_node.moving_to(pos, false)
			BoardState.update_robber_position(pos)
			hide_robber_options()
			gm.waiting_robber_move = false


func show_robber_options():
	var current_robber_pos = BoardState.robber_hex_pos
	for child in get_children():
		if child is Node2D and child.has_meta("resource_type"):
			var hex_pos = Vector2(round(child.position.x), round(child.position.y))
			if hex_pos != current_robber_pos:
				var highlight = _make_circle_poly(30.0, Color(1, 1, 1, 0.3))
				highlight.add_to_group("hex_highlights")
				child.add_child(highlight)

				var area      = Area2D.new()
				var collision = CollisionShape2D.new()
				var shape     = CircleShape2D.new()
				shape.radius  = 30.0
				collision.shape = shape
				area.add_child(collision)
				highlight.add_child(area)
				area.mouse_entered.connect(func(): highlight.color = Color(1, 0, 0, 0.5))
				area.mouse_exited.connect( func(): highlight.color = Color(1, 1, 1, 0.3))


func hide_robber_options():
	get_tree().call_group("hex_highlights", "queue_free")
