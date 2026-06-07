extends PanelContainer

@onready var entries_container = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var scroll = $VBoxContainer/ScrollContainer

var dice_textures: Array[Texture2D] = []
var resource_textures: Dictionary = {}
var font: Font


func _ready():
	font = load("res://assets/fonts/1_Minecraft-Regular.otf")
	entries_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	entries_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var log_texture = load("res://board_assets/LOG_BG.png")
	var style = StyleBoxTexture.new()
	style.texture = log_texture

	style.texture_margin_left = 22
	style.texture_margin_right = 22
	style.texture_margin_top = 0
	style.texture_margin_bottom = 18
	add_theme_stylebox_override("panel", style)


func setup_players(_players: Array[Player]):
	# Reservado para futuras configurações por jogador
	pass


func setup_dice_textures(textures: Array[Texture2D]):
	dice_textures = textures


# Chamado pelo game_manager para registrar as texturas dos recursos
# Espera um Dictionary: { "wood": Texture2D, "brick": ..., "wheat": ..., "sheep": ..., "ore": ... }
func setup_resource_textures(textures: Dictionary):
	resource_textures = textures


func add_roll_entry(player: Player, dice1: int, dice2: int):
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox = HFlowContainer.new()
	hbox.add_theme_constant_override("h_separation", 4)
	hbox.add_theme_constant_override("v_separation", 2)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if player.icon_texture:
		var icon_rect = TextureRect.new()
		icon_rect.texture = player.icon_texture
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_rect)
	else:
		hbox.add_child(_make_label(player.player_name, player.player_color.darkened(0.3), true))
	hbox.add_child(_make_label(" rolou ", Color(0.2, 0.2, 0.2)))
	hbox.add_child(_make_dice_sprite(dice1))
	hbox.add_child(_make_dice_sprite(dice2))

	margin.add_child(hbox)
	entries_container.add_child(margin)

	await get_tree().process_frame
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


# resources_gained: Dictionary { player_id (int) -> { resource_name (String) -> amount (int) } }
# players: Array[Player] para buscar ícone/cor pelo índice
func add_resources_entry(players: Array, resources_gained: Dictionary):
	var any_added = false

	for player_id in resources_gained:
		var gained: Dictionary = resources_gained[player_id]

		# Verifica se há algum recurso com quantidade > 0
		var total_cards = 0
		for res in gained:
			total_cards += gained[res]
		if total_cards == 0:
			continue

		var player: Player = players[player_id]

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)  # indent levinho
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var hbox = HFlowContainer.new()
		hbox.add_theme_constant_override("h_separation", 3)
		hbox.add_theme_constant_override("v_separation", 2)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Ícone do jogador
		if player.icon_texture:
			var icon_rect = TextureRect.new()
			icon_rect.texture = player.icon_texture
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(14, 14)
			icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(icon_rect)
		else:
			hbox.add_child(_make_label(player.player_name, player.player_color.darkened(0.3)))

		hbox.add_child(_make_label(" recebeu ", Color(0.2, 0.2, 0.2)))

		# Sprites de cada carta de recurso, repetidos pela quantidade
		var res_order = ["wood", "brick", "wheat", "sheep", "ore"]
		for res in res_order:
			if not gained.has(res):
				continue
			var amount: int = gained[res]
			for _i in range(amount):
				hbox.add_child(_make_resource_sprite(res))

		margin.add_child(hbox)
		entries_container.add_child(margin)
		any_added = true

	if any_added:
		await get_tree().process_frame
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


# Entrada especial para a fase de preparação: "jogador colocou casa e recebeu X recursos"
# resources_gained: { resource_name (String) -> amount (int) }
func add_preparation_resources_entry(player: Player, resources_gained: Dictionary):
	var total_cards = 0
	for res in resources_gained:
		total_cards += resources_gained[res]
	if total_cards == 0:
		return

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox = HFlowContainer.new()
	hbox.add_theme_constant_override("h_separation", 3)
	hbox.add_theme_constant_override("v_separation", 2)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if player.icon_texture:
		var icon_rect = TextureRect.new()
		icon_rect.texture = player.icon_texture
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_rect)
	else:
		hbox.add_child(_make_label(player.player_name, player.player_color.darkened(0.3)))

	hbox.add_child(_make_label(" recebeu ", Color(0.2, 0.2, 0.2)))

	var res_order = ["wood", "brick", "wheat", "sheep", "ore"]
	for res in res_order:
		if not resources_gained.has(res):
			continue
		var amount: int = resources_gained[res]
		for _i in range(amount):
			hbox.add_child(_make_resource_sprite(res))

	margin.add_child(hbox)
	entries_container.add_child(margin)

	await get_tree().process_frame
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


## Entrada de compra de carta de desenvolvimento
## [ícone jogador] "comprou" [ícone carta dev]
func add_dev_card_entry(player: Player) -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox = HFlowContainer.new()
	hbox.add_theme_constant_override("h_separation", 4)
	hbox.add_theme_constant_override("v_separation", 2)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Ícone do jogador
	if player.icon_texture:
		var icon_rect = TextureRect.new()
		icon_rect.texture = player.icon_texture
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_rect)
	else:
		hbox.add_child(_make_label(player.player_name, player.player_color.darkened(0.3)))

	hbox.add_child(_make_label(" comprou ", Color(0.2, 0.2, 0.2)))

	# Ícone da carta de desenvolvimento (fundo roxo com martelo)
	var card_tex := load("res://card_assets/development/development.png") as Texture2D
	if card_tex == null:
		card_tex = load("res://card_assets/development/KNIGHT.png") as Texture2D
	var card_rect = TextureRect.new()
	card_rect.texture = card_tex
	card_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_rect.custom_minimum_size = Vector2(16, 16)
	card_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(card_rect)

	margin.add_child(hbox)
	entries_container.add_child(margin)

	await get_tree().process_frame
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


## Entrada de troca entre jogadores ou com o banco
## [ícone jogador] "trocou" [sprites cartas dadas] "por" [sprites cartas recebidas] [ícone parceiro/banco]
## give_resources: Array[String]  — lista de nomes de recursos oferecidos
## recv_resources: Array[String]  — lista de nomes de recursos recebidos
## partner: Player ou null (null = banco)
func add_trade_entry(player: Player, give_resources: Array, recv_resources: Array, partner) -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox = HFlowContainer.new()
	hbox.add_theme_constant_override("h_separation", 3)
	hbox.add_theme_constant_override("v_separation", 2)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Ícone do jogador que fez a troca
	if player.icon_texture:
		var icon_rect = TextureRect.new()
		icon_rect.texture = player.icon_texture
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_rect)
	else:
		hbox.add_child(_make_label(player.player_name, player.player_color.darkened(0.3)))

	hbox.add_child(_make_label(" trocou ", Color(0.2, 0.2, 0.2)))

	# Sprites das cartas oferecidas
	for res in give_resources:
		hbox.add_child(_make_resource_sprite(res))

	hbox.add_child(_make_label(" por ", Color(0.2, 0.2, 0.2)))

	# Sprites das cartas recebidas
	for res in recv_resources:
		hbox.add_child(_make_resource_sprite(res))

	hbox.add_child(_make_label(" com ", Color(0.2, 0.2, 0.2)))

	# Ícone do parceiro (banco ou outro jogador)
	if partner == null:
		# Banco — usa o ícone do banco
		var bank_tex := load("res://icons_assets/bank.png") as Texture2D
		if bank_tex:
			var bank_rect = TextureRect.new()
			bank_rect.texture = bank_tex
			bank_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bank_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			bank_rect.custom_minimum_size = Vector2(16, 16)
			bank_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			bank_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(bank_rect)
		else:
			hbox.add_child(_make_label("banco", Color(0.2, 0.2, 0.2)))
	else:
		# Outro jogador
		if partner.icon_texture:
			var p_rect = TextureRect.new()
			p_rect.texture = partner.icon_texture
			p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			p_rect.custom_minimum_size = Vector2(16, 16)
			p_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			p_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(p_rect)
		else:
			hbox.add_child(_make_label(partner.player_name, partner.player_color.darkened(0.3)))

	margin.add_child(hbox)
	entries_container.add_child(margin)

	await get_tree().process_frame
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


func _make_label(text: String, color: Color, bold: bool = false) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", color)
	return label


func _make_dice_sprite(value: int) -> TextureRect:
	var rect = TextureRect.new()
	rect.custom_minimum_size = Vector2(16, 16)
	rect.size = Vector2(16, 16)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	if dice_textures.size() >= value and value >= 1:
		rect.texture = dice_textures[value - 1]
	return rect


func _make_resource_sprite(resource_name: String) -> TextureRect:
	var rect = TextureRect.new()
	rect.custom_minimum_size = Vector2(16, 16)
	rect.size = Vector2(16, 16)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	if resource_textures.has(resource_name):
		rect.texture = resource_textures[resource_name]
	return rect
