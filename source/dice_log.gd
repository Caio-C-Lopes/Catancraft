extends PanelContainer

@onready var entries_container = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var scroll = $VBoxContainer/ScrollContainer

var dice_textures: Array[Texture2D] = []
var font: Font


func _ready():
	font = load("res://assets/fonts/1_Minecraft-Regular.otf")
	entries_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	entries_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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


func add_roll_entry(player: Player, dice1: int, dice2: int):
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var name_label = _make_label(player.player_name, player.player_color.darkened(0.3), true)
	hbox.add_child(name_label)
	hbox.add_child(_make_label(" rolou ", Color(0.2, 0.2, 0.2)))
	hbox.add_child(_make_dice_sprite(dice1))
	hbox.add_child(_make_dice_sprite(dice2))

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
