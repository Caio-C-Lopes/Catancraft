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

# Referência ao DevCardPanel (filho direto deste nó ou ajuste o caminho)
@onready var _dev_card_panel = $DevCardPanel

var font: Font
var resource_icons: Dictionary = {}
var resource_labels: Dictionary = {}
var resource_panels: Dictionary = {}  # "wood" -> PanelContainer (para show/hide)
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

@export var trophy_icon: Texture2D
@export var knight_icon: Texture2D
@export var roads_longest_icon: Texture2D

var _house_btn: TextureButton = null
var _road_btn: TextureButton = null
var _city_btn: TextureButton = null
var _cards_btn: TextureButton = null

var _vp_label: Label = null
var _knights_label: Label = null
var _longest_road_label: Label = null

# Referência fixa ao jogador humano — definida uma única vez pelo game_manager
var _human_player: Player = null


func bind_human_player(player: Player):
	_human_player = player


var _end_turn_btn: TextureButton = null
var _trade_panel: Control = null
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
	_build_stats_panel()
	_setup_dice_display()
	if _player_icon_rect:
		_player_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_player_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_player_icon_rect.custom_minimum_size = Vector2(40, 40)
		_player_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_player_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_player_icon_rect.size = Vector2(40, 40)

	# Conecta o botão de cartas ao game_manager
	cards_pressed.connect(_on_cards_pressed)

	# Constrói o painel de trade — deve ser o ÚLTIMO passo do _ready
	# para garantir que o tamanho do PlayerHUD já foi calculado
	_build_trade_panel.call_deferred()


func _get_game_manager():
	return get_tree().get_root().find_child("Game", true, false)


func _is_human_turn_and_rolled() -> bool:
	var gm = _get_game_manager()
	if gm == null:
		return false
	return gm.current_player_index == 0 and gm.has_rolled_dice


func _on_cards_pressed():
	var gm = _get_game_manager()
	if gm and gm.has_method("buy_dev_card"):
		gm.buy_dev_card(0)


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
	update_action_buttons(player)
	update_vp_and_knights(player)


func setup_preparation_turn(player: Player):
	player_name_label.text = player.player_name
	player_name_label.add_theme_color_override("font_color", player.player_color)
	if _player_icon_rect and player.icon_texture:
		_player_icon_rect.texture = player.icon_texture
	update_pieces(player)
	update_action_buttons(player)
	update_vp_and_knights(player)


func update_resources(player: Player):
	for res in resource_labels.keys():
		var qty: int = player.resources.get(res, 0)
		resource_labels[res].text = str(qty)
		if resource_panels.has(res):
			resource_panels[res].visible = qty > 0
	update_action_buttons(player)
	update_vp_and_knights(player)


# Custos oficiais do Catan
const COSTS = {
	"road": {"wood": 1, "brick": 1},
	"house": {"wood": 1, "brick": 1, "wheat": 1, "sheep": 1},
	"city": {"ore": 3, "wheat": 2},
	"cards": {"ore": 1, "wheat": 1, "sheep": 1},
}

const COLOR_ON = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_OFF = Color(1.0, 1.0, 1.0, 0.5)


func update_action_buttons(_ignored: Player = null):
	# Sempre avalia com base nos recursos do jogador humano, nunca dos bots
	if _human_player == null:
		return
	_set_btn_affordable(
		_road_btn, _human_player.can_afford(COSTS["road"]) and _human_player.roads_remaining > 0
	)
	_set_btn_affordable(
		_house_btn,
		_human_player.can_afford(COSTS["house"]) and _human_player.settlements_remaining > 0
	)
	_set_btn_affordable(
		_city_btn, _human_player.can_afford(COSTS["city"]) and _human_player.cities_remaining > 0
	)
	_set_btn_affordable(_cards_btn, _human_player.can_afford(COSTS["cards"]))


func _set_btn_affordable(btn: TextureButton, affordable: bool):
	if btn == null:
		return
	btn.modulate = COLOR_ON if affordable else COLOR_OFF


func update_pieces(_ignored: Player = null):
	# Sempre exibe as peças do jogador humano, independente de quem está jogando
	var p = _human_player
	if p == null:
		return
	if piece_labels.has("road"):
		piece_labels["road"].text = str(p.roads_remaining)
	if piece_labels.has("settlement"):
		piece_labels["settlement"].text = str(p.settlements_remaining)
	if piece_labels.has("city"):
		piece_labels["city"].text = str(p.cities_remaining)
	update_action_buttons(p)


func update_vp_and_knights(player: Player = null):
	# Sempre exibe os dados do jogador humano, independente de quem está jogando
	var p = _human_player if _human_player != null else player
	if p == null:
		return
	if _vp_label:
		# Humano vê seus pontos totais reais, incluindo cartas VP secretas
		_vp_label.text = str(p.get_total_points())
	if _knights_label:
		_knights_label.text = str(p.knights_played)
	if _longest_road_label:
		var gm = _get_game_manager()
		var road_len := 0
		if gm and gm.has_method("_calc_longest_road"):
			road_len = gm._calc_longest_road(0)
		_longest_road_label.text = str(road_len)


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
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)

		var icon = TextureRect.new()
		icon.texture = resource_icons[res]
		icon.custom_minimum_size = Vector2(50, 50)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon)

		var label = Label.new()
		label.text = "0"
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color.BLACK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

		resource_labels[res] = label
		panel.add_child(vbox)

		resource_panels[res] = panel
		panel.hide()  # começa oculto — aparece quando quantidade > 0

		# Ao clicar num recurso do HUD enquanto o trade panel estiver aberto,
		# envia esse recurso para a área "oferecer" do trade panel
		var res_name = res
		panel.gui_input.connect(
			func(ev):
				if (
					ev is InputEventMouseButton
					and ev.pressed
					and ev.button_index == MOUSE_BUTTON_LEFT
				):
					if _trade_panel != null and _trade_panel.visible:
						_trade_panel.on_hud_resource_clicked(res_name)
		)

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
		btn.pressed.connect(
			func():
				# Dados ainda não rolados — bloqueia tudo exceto rolar dados
				if sig_name == "roll_dice_pressed":
					emit_signal(sig_name)
					return
				# Encerrar turno não precisa de dados rolados (o game_manager já valida)
				if sig_name == "end_turn_pressed":
					emit_signal(sig_name)
					return
				# Todas as outras ações exigem ser o turno do humano E ter rolado os dados
				if not _is_human_turn_and_rolled():
					print("Ação bloqueada: role os dados primeiro ou aguarde seu turno.")
					return
				emit_signal(sig_name)
		)

		if b["store"] == "end_turn":
			_end_turn_btn = btn
		elif b["store"] == "house":
			_house_btn = btn
		elif b["store"] == "road":
			_road_btn = btn
		elif b["store"] == "city":
			_city_btn = btn
		elif sig_name == "cards_pressed":
			_cards_btn = btn

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


# Constrói o painel de VP e Cavaleiros à direita do botão de trade,
# inserido como irmão do ActionButtons dentro de BottomLeft.
func _build_stats_panel():
	var bottom_left = $BottomLeft
	if bottom_left == null:
		return

	# Container vertical que agrupa os dois itens (VP e Cavaleiros)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Wrapper com margem negativa para subir os ícones
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", -60)
	margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# ── Pontos de Vitória ──────────────────────────────────────────
	var vp_inner = VBoxContainer.new()
	vp_inner.add_theme_constant_override("separation", 2)

	var vp_icon = TextureRect.new()
	if trophy_icon:
		vp_icon.texture = trophy_icon
	vp_icon.custom_minimum_size = Vector2(40, 40)
	vp_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vp_inner.add_child(vp_icon)

	var vp_lbl = Label.new()
	vp_lbl.text = "0"
	vp_lbl.add_theme_font_override("font", font)
	vp_lbl.add_theme_font_size_override("font_size", 13)
	vp_lbl.add_theme_color_override("font_color", Color.WHITE)
	vp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp_inner.add_child(vp_lbl)
	_vp_label = vp_lbl

	vbox.add_child(vp_inner)

	# ── Cavaleiros Jogados ─────────────────────────────────────────
	var kn_inner = VBoxContainer.new()
	kn_inner.add_theme_constant_override("separation", 2)

	var kn_icon = TextureRect.new()
	if knight_icon:
		kn_icon.texture = knight_icon
	kn_icon.custom_minimum_size = Vector2(40, 40)
	kn_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kn_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kn_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kn_inner.add_child(kn_icon)

	var kn_lbl = Label.new()
	kn_lbl.text = "0"
	kn_lbl.add_theme_font_override("font", font)
	kn_lbl.add_theme_font_size_override("font_size", 13)
	kn_lbl.add_theme_color_override("font_color", Color.WHITE)
	kn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kn_inner.add_child(kn_lbl)
	_knights_label = kn_lbl

	# ── Maior Estrada (ao lado do cavaleiro) ───────────────────────
	var rd_inner = VBoxContainer.new()
	rd_inner.add_theme_constant_override("separation", 2)

	var rd_icon = TextureRect.new()
	# Carrega diretamente do caminho para não depender do Inspector
	var _roads_tex = load("res://icons_assets/roads.png") as Texture2D
	if _roads_tex:
		rd_icon.texture = _roads_tex
	elif roads_longest_icon:
		rd_icon.texture = roads_longest_icon
	rd_icon.custom_minimum_size = Vector2(40, 40)
	rd_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rd_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rd_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rd_inner.add_child(rd_icon)

	var rd_lbl = Label.new()
	rd_lbl.text = "0"
	rd_lbl.add_theme_font_override("font", font)
	rd_lbl.add_theme_font_size_override("font_size", 13)
	rd_lbl.add_theme_color_override("font_color", Color.WHITE)
	rd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rd_inner.add_child(rd_lbl)
	_longest_road_label = rd_lbl

	# Agrupa cavaleiro + estrada lado a lado num HBox
	var kn_rd_hbox = HBoxContainer.new()
	kn_rd_hbox.add_theme_constant_override("separation", 4)
	kn_rd_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kn_rd_hbox.add_child(kn_inner)
	kn_rd_hbox.add_child(rd_inner)

	vbox.add_child(kn_rd_hbox)

	margin.add_child(vbox)
	bottom_left.add_child(margin)


# ── Trade Panel ───────────────────────────────────────────────────────────────
func _build_trade_panel():
	var trade_script = load("res://source/trade_panel.gd")
	if trade_script == null:
		push_error("trade_panel.gd não encontrado!")
		return

	_trade_panel = Control.new()
	_trade_panel.set_script(trade_script)

	# IMPORTANTE: o painel deve ser filho direto do nó raiz da cena (Control
	# que ocupa a tela toda), NÃO de um container filho como BottomBar.
	# Containers (VBox, HBox, etc.) ignoram position e reposicionam os filhos
	# automaticamente — por isso o painel ficava preso embaixo.
	#
	# Aqui subimos na árvore até encontrar o Control raiz da cena (FullRect),
	# ou usamos o próprio PlayerHUD se ele já for o raiz da viewport.
	var root_control: Control = self

	# Sobe na hierarquia enquanto o pai também for Control (não Node puro)
	# para atingir o nó que cobre a tela inteira
	while root_control.get_parent() is Control:
		root_control = root_control.get_parent() as Control

	root_control.add_child(_trade_panel)

	# Posição absoluta em relação ao Control raiz:
	# canto inferior-esquerdo da tela, acima da HUD (~350 px de altura do painel)
	# Ajuste os valores abaixo conforme a resolução do seu projeto
	_trade_panel.position = Vector2(10, 200)  # Y positivo: distância do topo
	_trade_panel.z_index = 20
	_trade_panel.hide()

	# Passa as texturas de recurso para o painel montar os cards
	_trade_panel.resource_textures = resource_icons

	trade_pressed.connect(_on_trade_pressed)


func _on_trade_pressed():
	if _trade_panel == null:
		return
	if _trade_panel.visible:
		_trade_panel.close_trade()
	else:
		_trade_panel.open_trade()


# ── Preview de oferta no HUD ──────────────────────────────────────────────────
# Chamado pelo trade_panel para refletir visualmente as cartas que o jogador
# está selecionando como oferta, sem alterar os recursos reais do Player.
# delta = -1  →  jogador está oferecendo mais uma carta desse recurso
# delta = +1  →  jogador cancelou/removeu uma carta desse recurso
func hud_preview_give(res_name: String, delta: int):
	if not resource_labels.has(res_name):
		return
	var lbl: Label = resource_labels[res_name]
	var panel: Control = resource_panels.get(res_name, null)
	var current = lbl.text.to_int()
	var next = current + delta
	lbl.text = str(next)
	if panel:
		panel.visible = next > 0


# Restaura os labels do HUD para os valores reais do jogador humano.
# Chamado quando o trade é cancelado.
func hud_reset_preview():
	if _human_player == null:
		return
	for res in resource_labels.keys():
		var qty: int = _human_player.resources.get(res, 0)
		resource_labels[res].text = str(qty)
		if resource_panels.has(res):
			resource_panels[res].visible = qty > 0
