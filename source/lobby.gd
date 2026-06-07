extends Control

const COLORS: Array[Dictionary] = [
	{"name": "red", "label": "Vermelho", "color": Color(0.85, 0.25, 0.25)},
	{"name": "blue", "label": "Azul", "color": Color(0.22, 0.54, 0.87)},
	{"name": "green", "label": "Verde", "color": Color(0.27, 0.65, 0.27)},
	{"name": "purple", "label": "Roxo", "color": Color(0.55, 0.27, 0.80)},
]

const ICONS: Array[String] = ["steve", "creeper", "pig"]

var selected_color_index: int = 0
var selected_bot_count: int = 3
var selected_player_icon: int = -1

@onready var color_row: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ColorRow
@onready var bot_row: HBoxContainer = $Panel/MarginContainer/VBoxContainer/BotRow
@onready var preview: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Preview

var _color_btns: Array[Button] = []
var _bot_btns: Array[Button] = []
var _player_icon_row: HBoxContainer = null


func _ready():
	_add_background()
	# Remove o Label2 deixado na cena (.tscn) que ficava aparecendo como quadrado preto
	var label2 = $Panel/MarginContainer/VBoxContainer/Label2
	if label2:
		label2.queue_free()
	_build_color_buttons()
	_build_bot_buttons()
	_build_icon_section()
	_update_preview()
	_refresh_start_button()
	var panel := $Panel as Panel
	if panel:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.55)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		panel.add_theme_stylebox_override("panel", style)


func _add_background():
	var bg := TextureRect.new()
	bg.texture = load("res://lobby_bg.png")
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 0
	bg.offset_top = 0
	bg.offset_right = 0
	bg.offset_bottom = 0
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)


func _refresh_start_button():
	var btn := $Panel/MarginContainer/VBoxContainer/Start as Button
	if btn:
		var ready := selected_player_icon >= 0
		btn.disabled = not ready
		btn.modulate = Color(1, 1, 1, 1.0) if ready else Color(1, 1, 1, 0.45)


func _build_color_buttons():
	for i in range(COLORS.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.tooltip_text = COLORS[i]["label"]
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = COLORS[i]["color"]
		style_normal.corner_radius_top_left = 8
		style_normal.corner_radius_top_right = 8
		style_normal.corner_radius_bottom_left = 8
		style_normal.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_normal)
		btn.add_theme_stylebox_override("pressed", style_normal)
		var idx: int = i
		btn.pressed.connect(
			func():
				selected_color_index = idx
				_refresh_color_highlight()
				_update_preview()
		)
		color_row.add_child(btn)
		_color_btns.append(btn)
	_refresh_color_highlight()


func _refresh_color_highlight():
	for i in range(_color_btns.size()):
		var btn := _color_btns[i]
		var style := StyleBoxFlat.new()
		style.bg_color = COLORS[i]["color"]
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		if i == selected_color_index:
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_color = Color.WHITE
			btn.modulate = Color(1, 1, 1, 1.0)
		else:
			btn.modulate = Color(1, 1, 1, 0.65)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)


func _build_bot_buttons():
	for n in [1, 2, 3]:
		var btn := Button.new()
		btn.text = str(n) + (" bot" if n == 1 else " bots")
		btn.custom_minimum_size = Vector2(80, 40)
		btn.toggle_mode = true
		btn.button_pressed = (n == selected_bot_count)
		var count: int = n
		btn.toggled.connect(
			func(pressed: bool):
				if pressed:
					selected_bot_count = count
					_refresh_bot_highlight()
					_update_preview()
		)
		bot_row.add_child(btn)
		_bot_btns.append(btn)


func _refresh_bot_highlight():
	for i in range(_bot_btns.size()):
		_bot_btns[i].button_pressed = ((i + 1) == selected_bot_count)


func _build_icon_section():
	var vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer

	var title := Label.new()
	title.text = "Ícone"
	title.name = "IconSectionTitle"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(title)
	vbox.move_child(title, _get_insert_index())

	_player_icon_row = _make_icon_row(
		ICONS,
		selected_player_icon,
		func(idx: int):
			selected_player_icon = idx
			_refresh_icon_row(_player_icon_row, selected_player_icon)
			_update_preview()
	)
	vbox.add_child(_player_icon_row)
	vbox.move_child(_player_icon_row, _get_insert_index())


func _get_insert_index() -> int:
	var vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer
	for i in range(vbox.get_child_count()):
		var child = vbox.get_child(i)
		if child is HSeparator:
			return i
	return vbox.get_child_count()


func _make_icon_row(icons: Array[String], current: int, on_select: Callable) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	for i in range(icons.size()):
		var tex: Texture2D = load("res://icons_assets/%s.png" % icons[i])
		if tex == null:
			continue
		var idx: int = i
		var btn := TextureButton.new()
		btn.texture_normal = tex
		btn.custom_minimum_size = Vector2(40, 40)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.modulate = Color(1, 1, 1, 1.0) if idx == current else Color(1, 1, 1, 0.5)
		btn.set_meta("icon_idx", idx)
		btn.pressed.connect(func(): on_select.call(idx))
		hbox.add_child(btn)

	return hbox


func _refresh_icon_row(row: HBoxContainer, selected: int):
	for child in row.get_children():
		var icon_idx: int = child.get_meta("icon_idx", -1)
		child.modulate = Color(1, 1, 1, 1.0) if icon_idx == selected else Color(1, 1, 1, 0.5)


# Gera cores e ícones aleatórios para os bots, sem repetir a cor do jogador
# e sem repetir ícones entre si ou com o jogador.
func _random_bot_assignments() -> Array[Dictionary]:
	# Cores disponíveis para bots (excluir a do jogador)
	var available_colors: Array[Dictionary] = []
	for c in COLORS:
		if c["name"] != COLORS[selected_color_index]["name"]:
			available_colors.append(c)

	# Ícones disponíveis para bots (excluir o do jogador)
	var available_icons: Array[String] = []
	for ic in ICONS:
		if ic != ICONS[selected_player_icon]:
			available_icons.append(ic)

	# Seed baseada em microssegundos para garantir diferença a cada clique
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec()

	# Fisher-Yates shuffle — percorre todos incluindo índice 0
	for i in range(available_colors.size() - 1, -1, -1):
		var j := rng.randi_range(0, available_colors.size() - 1)
		var tmp := available_colors[i]
		available_colors[i] = available_colors[j]
		available_colors[j] = tmp

	for i in range(available_icons.size() - 1, -1, -1):
		var j := rng.randi_range(0, available_icons.size() - 1)
		var tmp := available_icons[i]
		available_icons[i] = available_icons[j]
		available_icons[j] = tmp

	var result: Array[Dictionary] = []
	for i in range(selected_bot_count):
		(
			result
			. append(
				{
					"color": available_colors[i % available_colors.size()],
					"icon": available_icons[i % available_icons.size()],
				}
			)
		)
	return result


func _update_preview():
	for child in preview.get_children():
		child.queue_free()

	# Linha do jogador
	var player_icon: Texture2D = null
	if selected_player_icon >= 0:
		player_icon = load("res://icons_assets/%s.png" % ICONS[selected_player_icon]) as Texture2D
	_add_preview_row("Você", COLORS[selected_color_index]["color"], player_icon)

	_refresh_start_button()


func _add_preview_row(pname: String, col: Color, icon: Texture2D = null):
	var sep := HSeparator.new()
	preview.add_child(sep)
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 36)
	hbox.add_theme_constant_override("separation", 8)

	if icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(28, 28)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_rect)

	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = col
	dot_style.corner_radius_top_left = 8
	dot_style.corner_radius_top_right = 8
	dot_style.corner_radius_bottom_left = 8
	dot_style.corner_radius_bottom_right = 8
	var dot := PanelContainer.new()
	dot.add_theme_stylebox_override("panel", dot_style)
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(dot)

	var lbl := Label.new()
	lbl.text = pname
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(lbl)

	preview.add_child(hbox)


func _on_start_pressed() -> void:
	if selected_player_icon < 0:
		return

	var bot_assignments := _random_bot_assignments()

	GameConfig.player_color_name = COLORS[selected_color_index]["name"]
	GameConfig.player_icon_name = ICONS[selected_player_icon]
	GameConfig.bot_count = selected_bot_count
	GameConfig.bot_icon_names.clear()
	GameConfig.bot_color_names.clear()
	for i in range(selected_bot_count):
		GameConfig.bot_icon_names.append(bot_assignments[i]["icon"])
		GameConfig.bot_color_names.append(bot_assignments[i]["color"]["name"])

	get_tree().change_scene_to_file("res://game.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
