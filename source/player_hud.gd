extends Control

signal dice_clicked

@onready var dice1 = $DiceContainer/Dice1
@onready var dice2 = $DiceContainer/Dice2


func _on_dice_pressed():
	emit_signal("dice_clicked")


@onready var player_name_label = $TopLeft/PlayerNameLabel
@onready var timer_label = $TopLeft/TimerLabel
@onready var resource_bar = $BottomBar/ResourceBar
@onready var action_buttons = $BottomLeft/ActionButtons
@onready var _dice1_rect: TextureButton = $DiceContainer/Dice1
@onready var _dice2_rect: TextureButton = $DiceContainer/Dice2
@onready var _player_icon_rect: TextureRect = $TopLeft/PlayerIcon

var font: Font
var resource_icons: Dictionary = {}
var resource_labels: Dictionary = {}
var piece_labels: Dictionary = {}

@export var wood_icon: Texture2D
@export var brick_icon: Texture2D
@export var wheat_icon: Texture2D
@export var sheep_icon: Texture2D
@export var ore_icon: Texture2D

@export var city_icon: Texture2D
@export var cards_icon: Texture2D
@export var house_icon: Texture2D
@export var trade_icon: Texture2D
@export var road_icon: Texture2D
@export var end_turn_icon_active: Texture2D
@export var end_turn_icon_inactive: Texture2D
@export var dice_face_textures: Array[Texture2D]

var _house_btn: TextureButton = null
var _road_btn: TextureButton = null
var _city_btn: TextureButton = null

var _end_turn_btn: TextureButton = null
var time_remaining: float = 0.0
var timer_running: bool = false
var _on_timeout_callback: Callable = Callable()

signal build_city_pressed
signal cards_pressed
signal build_house_pressed
signal trade_pressed
signal build_road_pressed
signal roll_dice_pressed
signal end_turn_pressed


func _ready():
	dice1.pressed.connect(_on_dice_pressed)
	dice2.pressed.connect(_on_dice_pressed)
	font = load("res://assets/fonts/1_Minecraft-Regular.otf")
	resource_icons = {
		"wood": wood_icon,
		"brick": brick_icon,
		"wheat": wheat_icon,
		"sheep": sheep_icon,
		"ore": ore_icon,
	}
	_build_resource_bar()
	_build_action_buttons()
	_setup_dice_display()
	if _player_icon_rect:
		_player_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_player_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_player_icon_rect.custom_minimum_size = Vector2(40, 40)
		_player_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_player_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_player_icon_rect.size = Vector2(40, 40)


func _process(delta):
	if not timer_running:
		return
	time_remaining -= delta
	if time_remaining <= 0.0:
		time_remaining = 0.0
		timer_running = false
		if _on_timeout_callback.is_valid():
			var cb = _on_timeout_callback
			_on_timeout_callback = Callable()
			cb.call()
		return
	_update_timer_display()


func start_timer(duration: float, callback: Callable):
	time_remaining = duration
	timer_running = true
	_on_timeout_callback = callback
	_update_timer_display()


func stop_timer():
	timer_running = false
	_on_timeout_callback = Callable()
	timer_label.text = "- : --"


func setup_turn(player: Player):
	player_name_label.text = player.player_name
	player_name_label.add_theme_color_override("font_color", player.player_color)
	if _player_icon_rect and player.icon_texture:
		_player_icon_rect.texture = player.icon_texture
	update_pieces(player)


func setup_preparation_turn(player: Player):
	player_name_label.text = player.player_name
	player_name_label.add_theme_color_override("font_color", player.player_color)
	if _player_icon_rect and player.icon_texture:
		_player_icon_rect.texture = player.icon_texture
	update_pieces(player)


func update_resources(_player: Player):
	pass


func update_pieces(player: Player):
	if piece_labels.has("road"):
		piece_labels["road"].text = str(player.roads_remaining)
	if piece_labels.has("settlement"):
		piece_labels["settlement"].text = str(player.settlements_remaining)
	if piece_labels.has("city"):
		piece_labels["city"].text = str(player.cities_remaining)


func _update_timer_display():
	var mins = int(time_remaining) / 60
	var secs = int(time_remaining) % 60
	timer_label.text = "%d : %02d" % [mins, secs]


func update_end_turn_button(is_human: bool, dice_rolled: bool):
	if _end_turn_btn == null:
		return
	if not is_human:
		_end_turn_btn.texture_normal = end_turn_icon_inactive
		_end_turn_btn.modulate = Color(1, 1, 1, 0.5)
	elif dice_rolled:
		_end_turn_btn.texture_normal = end_turn_icon_active
		_end_turn_btn.modulate = Color(1, 1, 1, 1.0)
	else:
		_end_turn_btn.texture_normal = end_turn_icon_inactive
		_end_turn_btn.modulate = Color(1, 1, 1, 1.0)


func set_dice_enabled(enabled: bool):
	_dice1_rect.disabled = not enabled
	_dice2_rect.disabled = not enabled
	if enabled:
		_dice1_rect.modulate = Color(1, 1, 1, 1.0)
		_dice2_rect.modulate = Color(1, 1, 1, 1.0)
	else:
		_dice1_rect.modulate = Color(1, 1, 1, 0.5)
		_dice2_rect.modulate = Color(1, 1, 1, 0.5)


func show_dice_result(dice1_val: int, dice2_val: int):
	if dice_face_textures.size() < 6:
		return
	_dice1_rect.texture_normal = dice_face_textures[clamp(dice1_val - 1, 0, 5)]
	_dice2_rect.texture_normal = dice_face_textures[clamp(dice2_val - 1, 0, 5)]


func _build_resource_bar():
	var order = ["wood", "brick", "wheat", "sheep", "ore"]
	for res in order:
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.9)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0, 0, 0, 1)
		panel.add_theme_stylebox_override("panel", style)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)

		var icon = TextureRect.new()
		icon.texture = resource_icons[res]
		icon.custom_minimum_size = Vector2(50, 50)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(icon)

		var label = Label.new()
		label.text = "0"
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color.BLACK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)

		resource_labels[res] = label
		panel.add_child(vbox)
		resource_bar.add_child(panel)


func _make_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0, 0, 0, 1)
	return style


func _build_action_buttons():
	action_buttons.columns = 2
	action_buttons.add_theme_constant_override("h_separation", 4)
	action_buttons.add_theme_constant_override("v_separation", 4)

	var buttons = [
		{"icon": city_icon, "signal": "build_city_pressed", "store": "city", "piece": "city"},
		{"icon": cards_icon, "signal": "cards_pressed", "store": "", "piece": ""},
		{
			"icon": house_icon,
			"signal": "build_house_pressed",
			"store": "house",
			"piece": "settlement"
		},
		{"icon": trade_icon, "signal": "trade_pressed", "store": "", "piece": ""},
		{"icon": road_icon, "signal": "build_road_pressed", "store": "road", "piece": "road"},
		{
			"icon": end_turn_icon_inactive,
			"signal": "end_turn_pressed",
			"store": "end_turn",
			"piece": ""
		},
	]

	for b in buttons:
		var panel = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _make_panel_style())
		panel.custom_minimum_size = Vector2(64, 64)

		var btn = TextureButton.new()
		btn.texture_normal = b["icon"]
		btn.custom_minimum_size = Vector2(64, 64)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var sig_name = b["signal"]
		btn.pressed.connect(func(): emit_signal(sig_name))

		if b["store"] == "end_turn":
			_end_turn_btn = btn
		elif b["store"] == "house":
			_house_btn = btn
		elif b["store"] == "road":
			_road_btn = btn
		elif b["store"] == "city":
			_city_btn = btn

		if b["piece"] != "":
			var vbox = VBoxContainer.new()
			vbox.add_theme_constant_override("separation", 0)
			vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

			btn.custom_minimum_size = Vector2(64, 46)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			vbox.add_child(btn)

			var count_lbl = Label.new()
			var initials = {"road": "15", "settlement": "5", "city": "4"}
			count_lbl.text = initials.get(b["piece"], "")
			count_lbl.add_theme_font_override("font", font)
			count_lbl.add_theme_font_size_override("font_size", 13)
			count_lbl.add_theme_color_override("font_color", Color.BLACK)
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			count_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
			vbox.add_child(count_lbl)

			piece_labels[b["piece"]] = count_lbl
			panel.add_child(vbox)
		else:
			panel.add_child(btn)

		action_buttons.add_child(panel)


func apply_player_color(color_name: String):
	var base = "res://board_assets/"
	var h = load(base + "house_" + color_name + ".png")
	var r = load(base + "road_" + color_name + ".png")
	var c = load(base + "city_" + color_name + ".png")
	if h and _house_btn:
		_house_btn.texture_normal = h
	if r and _road_btn:
		_road_btn.texture_normal = r
	if c and _city_btn:
		_city_btn.texture_normal = c
	house_icon = h
	road_icon = r
	city_icon = c


func _setup_dice_display():
	if dice_face_textures.size() >= 6:
		_dice1_rect.texture_normal = dice_face_textures[0]
		_dice2_rect.texture_normal = dice_face_textures[4]
	set_dice_enabled(false)
