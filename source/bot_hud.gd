extends PanelContainer

var bot_index: int = 1
var _player: Player = null
var font: Font

var _total_cards_lbl: Label = null
var _dev_cards_lbl: Label = null
var _points_lbl: Label = null
var _knights_lbl: Label = null
var _roads_lbl: Label = null
var _settlements_lbl: Label = null
var _cities_lbl: Label = null

@export var trophy_icon: Texture2D
@export var iron_golem_icon: Texture2D
@export var roads_icon: Texture2D
@export var dev_card_back_icon: Texture2D
@export var resource_card_icon: Texture2D

@export var house_red_icon: Texture2D
@export var house_blue_icon: Texture2D
@export var house_green_icon: Texture2D
@export var house_purple_icon: Texture2D
@export var city_red_icon: Texture2D
@export var city_blue_icon: Texture2D
@export var city_green_icon: Texture2D
@export var city_purple_icon: Texture2D
@export var road_red_icon: Texture2D
@export var road_blue_icon: Texture2D
@export var road_green_icon: Texture2D
@export var road_purple_icon: Texture2D

var _bot_icon_rect: TextureRect = null
var _house_icon_rect: TextureRect = null
var _city_icon_rect: TextureRect = null
var _road_icon_rect: TextureRect = null


func _ready():
	font = load("res://assets/fonts/1_Minecraft-Regular.otf")
	_apply_style()
	_build_ui()
	await get_tree().process_frame
	_snap_position()


func _apply_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0, 0, 0, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)


func _snap_position():
	var bank_panel = get_parent().get_node_or_null("BankPanel")
	if not bank_panel:
		return

	anchor_left = bank_panel.anchor_left
	anchor_right = bank_panel.anchor_right
	anchor_top = bank_panel.anchor_top
	anchor_bottom = bank_panel.anchor_bottom

	var gap = 6.0
	var panel_h = 95.0

	offset_right = bank_panel.offset_right
	offset_left = bank_panel.offset_left
	offset_top = bank_panel.offset_bottom + gap + (bot_index - 1) * (panel_h + gap)
	offset_bottom = offset_top + panel_h


func _build_ui():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(root_vbox)

	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	root_vbox.add_child(top_row)

	var icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bot_icon_rect = icon_rect
	top_row.add_child(icon_rect)

	# Cartas de recurso na mão (carta azul com ?)
	top_row.add_child(
		_make_icon_counter(resource_card_icon, "0", func(lbl): _total_cards_lbl = lbl)
	)

	# Cartas de desenvolvimento na mão (carta roxa)
	top_row.add_child(_make_icon_counter(dev_card_back_icon, "0", func(lbl): _dev_cards_lbl = lbl))

	# Pontos de vitória (troféu)
	top_row.add_child(_make_icon_counter(trophy_icon, "0", func(lbl): _points_lbl = lbl))

	# Cavaleiros jogados (golem de ferro)
	top_row.add_child(_make_icon_counter(iron_golem_icon, "0", func(lbl): _knights_lbl = lbl))

	var bot_row = HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 8)
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(bot_row)

	# Estrada
	_road_icon_rect = TextureRect.new()
	_road_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_road_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_road_icon_rect.custom_minimum_size = Vector2(28, 28)
	_road_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot_row.add_child(_road_icon_rect)
	bot_row.add_child(_make_piece_label("15", func(lbl): _roads_lbl = lbl))

	# Casa
	_house_icon_rect = TextureRect.new()
	_house_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_house_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_house_icon_rect.custom_minimum_size = Vector2(28, 28)
	_house_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot_row.add_child(_house_icon_rect)
	bot_row.add_child(_make_piece_label("5", func(lbl): _settlements_lbl = lbl))

	# Cidade
	_city_icon_rect = TextureRect.new()
	_city_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_city_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_city_icon_rect.custom_minimum_size = Vector2(28, 28)
	_city_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot_row.add_child(_city_icon_rect)
	bot_row.add_child(_make_piece_label("4", func(lbl): _cities_lbl = lbl))


func _make_icon_counter(icon: Texture2D, initial: String, store: Callable) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var icon_rect = TextureRect.new()
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_rect)

	var lbl = Label.new()
	lbl.text = initial
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(lbl)

	store.call(lbl)
	return hbox


func _make_piece_label(initial: String, store: Callable) -> Label:
	var lbl = Label.new()
	lbl.text = initial
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	store.call(lbl)
	return lbl


func setup(player: Player, color_name: String = ""):
	_player = player

	if _bot_icon_rect and player.icon_texture:
		_bot_icon_rect.texture = player.icon_texture

	var cname = color_name if color_name != "" else _color_name_from(player.player_color)
	_apply_piece_icons(cname)

	refresh()


func refresh():
	if not _player:
		return

	if _total_cards_lbl:
		var total = 0
		for r in _player.resources:
			total += _player.resources[r]
		_total_cards_lbl.text = str(total)

	if _dev_cards_lbl:
		_dev_cards_lbl.text = str(_player.dev_cards_in_hand)

	if _points_lbl:
		_points_lbl.text = str(_player.points)

	if _knights_lbl:
		_knights_lbl.text = str(_player.knights_played)

	if _roads_lbl:
		_roads_lbl.text = str(_player.roads_remaining)

	if _settlements_lbl:
		_settlements_lbl.text = str(_player.settlements_remaining)

	if _cities_lbl:
		_cities_lbl.text = str(_player.cities_remaining)


func _apply_piece_icons(color_name: String):
	var base = "res://board_assets/"
	var h = load(base + "house_" + color_name + ".png") as Texture2D
	var r = load(base + "road_" + color_name + ".png") as Texture2D
	var c = load(base + "city_" + color_name + ".png") as Texture2D
	if _house_icon_rect and h:
		_house_icon_rect.texture = h
	if _road_icon_rect and r:
		_road_icon_rect.texture = r
	if _city_icon_rect and c:
		_city_icon_rect.texture = c


func _color_name_from(color: Color) -> String:
	var r = color.r
	var g = color.g
	var b = color.b
	if r > 0.6 and g < 0.5 and b < 0.5:
		return "red"
	if b > 0.6 and r < 0.5 and g < 0.7:
		return "blue"
	if g > 0.6 and r < 0.5 and b < 0.5:
		return "green"
	return "purple"
