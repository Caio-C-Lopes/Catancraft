extends Control

const COLORS: Array[Dictionary] = [
	{"name": "red", "label": "Vermelho", "color": Color(0.85, 0.25, 0.25)},
	{"name": "blue", "label": "Azul", "color": Color(0.22, 0.54, 0.87)},
	{"name": "green", "label": "Verde", "color": Color(0.27, 0.65, 0.27)},
	{"name": "purple", "label": "Roxo", "color": Color(0.55, 0.27, 0.80)},
]

const BOT_COLORS: Array[Dictionary] = [
	{"name": "blue", "color": Color(0.22, 0.54, 0.87)},
	{"name": "green", "color": Color(0.27, 0.65, 0.27)},
	{"name": "purple", "color": Color(0.55, 0.27, 0.80)},
	{"name": "red", "color": Color(0.85, 0.25, 0.25)},
]

const ICONS: Array[String] = ["steve", "creeper", "zombie", "pig"]

var selected_color_index: int = 0
var selected_bot_count: int = 3
var selected_player_icon: int = -1
var selected_bot_icons: Array[int] = [-1, -1, -1]

@onready var color_row: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ColorRow
@onready var bot_row: HBoxContainer = $Panel/MarginContainer/VBoxContainer/BotRow
@onready var preview: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Preview

var _color_btns: Array[Button] = []
var _bot_btns: Array[Button] = []

var _player_icon_row: HBoxContainer = null
var _bot_icon_rows: Array[HBoxContainer] = []


func _ready():
	_add_background()
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


func _all_icons_selected() -> bool:
	if selected_player_icon < 0:
		return false
	for i in range(selected_bot_count):
		if i >= selected_bot_icons.size() or selected_bot_icons[i] < 0:
			return false
	return true


func _refresh_start_button():
	var btn := $Panel/MarginContainer/VBoxContainer/Start as Button
	if btn:
		var ready := _all_icons_selected()
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
					_rebuild_icon_section()
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
		"Você",
		ICONS,
		selected_player_icon,
		func(idx: int):
			_steal_icon(-1, idx)
			selected_player_icon = idx
			_refresh_all_icon_rows()
			_update_preview()
	)
	vbox.add_child(_player_icon_row)
	vbox.move_child(_player_icon_row, _get_insert_index())

	_bot_icon_rows.clear()
	for b in range(selected_bot_count):
		var row := _make_bot_icon_row(b)
		vbox.add_child(row)
		vbox.move_child(row, _get_insert_index())
		_bot_icon_rows.append(row)


func _get_insert_index() -> int:
	var vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer
	for i in range(vbox.get_child_count()):
		var child = vbox.get_child(i)
		if child is HSeparator:
			return i
	return vbox.get_child_count()


func _rebuild_icon_section():
	var vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer

	for row in _bot_icon_rows:
		row.queue_free()
	_bot_icon_rows.clear()

	for b in range(selected_bot_count):
		var row := _make_bot_icon_row(b)
		vbox.add_child(row)
		vbox.move_child(row, _get_insert_index())
		_bot_icon_rows.append(row)


func _make_bot_icon_row(b: int) -> HBoxContainer:
	# Garante que o slot existe no array
	while selected_bot_icons.size() <= b:
		selected_bot_icons.append(-1)
	var slot := b
	return _make_icon_row(
		"Bot " + str(b + 1),
		ICONS,
		selected_bot_icons[b],
		func(idx: int):
			_steal_icon(slot, idx)
			selected_bot_icons[slot] = idx
			_refresh_all_icon_rows()
			_update_preview()
	)


func _steal_icon(new_owner_slot: int, icon_idx: int):
	if selected_player_icon == icon_idx and new_owner_slot != -1:
		selected_player_icon = -1
	for b in range(selected_bot_icons.size()):
		if b != new_owner_slot and selected_bot_icons[b] == icon_idx:
			selected_bot_icons[b] = -1


func _refresh_all_icon_rows():
	_refresh_icon_row(_player_icon_row, selected_player_icon)
	for b in range(_bot_icon_rows.size()):
		_refresh_icon_row(_bot_icon_rows[b], selected_bot_icons[b])


func _make_icon_row(
	label_text: String, icons: Array[String], current: int, on_select: Callable
) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(60, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)

	for i in range(icons.size()):
		var tex: Texture2D = load("res://icons_assets/%s.png" % icons[i])
		var btn := TextureButton.new()
		btn.texture_normal = tex
		btn.custom_minimum_size = Vector2(40, 40)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.modulate = Color(1, 1, 1, 1.0) if i == current else Color(1, 1, 1, 0.5)
		var idx: int = i
		btn.pressed.connect(func(): on_select.call(idx))
		hbox.add_child(btn)

	return hbox


func _refresh_icon_row(row: HBoxContainer, selected: int):
	for i in range(1, row.get_child_count()):
		row.get_child(i).modulate = (
			Color(1, 1, 1, 1.0) if (i - 1) == selected else Color(1, 1, 1, 0.5)
		)


func _update_preview():
	for child in preview.get_children():
		child.queue_free()

	var player_icon: Texture2D = null
	if selected_player_icon >= 0:
		player_icon = load("res://icons_assets/%s.png" % ICONS[selected_player_icon]) as Texture2D
	_add_preview_row("Você", COLORS[selected_color_index]["color"], "humano", player_icon)

	var player_name: String = COLORS[selected_color_index]["name"]
	var bot_i := 0
	for i in range(selected_bot_count):
		while BOT_COLORS[bot_i % BOT_COLORS.size()]["name"] == player_name:
			bot_i += 1
		var bc: Color = BOT_COLORS[bot_i % BOT_COLORS.size()]["color"]
		while selected_bot_icons.size() <= i:
			selected_bot_icons.append(-1)
		var bot_icon: Texture2D = null
		if selected_bot_icons[i] >= 0:
			bot_icon = load("res://icons_assets/%s.png" % ICONS[selected_bot_icons[i]]) as Texture2D
		_add_preview_row("Bot " + str(i + 1), bc, "ia", bot_icon)
		bot_i += 1

	_refresh_start_button()


func _add_preview_row(pname: String, col: Color, tag: String, icon: Texture2D = null):
	var sep := HSeparator.new()
	preview.add_child(sep)
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 36)
	hbox.add_theme_constant_override("separation", 8)

	# Ícone do personagem
	if icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(28, 28)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_rect)

	# Bolinha de cor
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

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.add_theme_font_size_override("font_size", 11)
	tag_lbl.modulate = Color(1, 1, 1, 0.5)
	hbox.add_child(tag_lbl)

	preview.add_child(hbox)


func _on_start_pressed() -> void:
	# Bloqueia se o jogador não escolheu ícone
	if selected_player_icon < 0:
		return
	# Bloqueia se algum bot não escolheu ícone
	for i in range(selected_bot_count):
		if i >= selected_bot_icons.size() or selected_bot_icons[i] < 0:
			return

	GameConfig.player_color_name = COLORS[selected_color_index]["name"]
	GameConfig.player_icon_name = ICONS[selected_player_icon]
	GameConfig.bot_count = selected_bot_count
	GameConfig.bot_icon_names.clear()
	for i in range(selected_bot_count):
		while GameConfig.bot_icon_names.size() <= i:
			GameConfig.bot_icon_names.append("")
		var icon_idx := selected_bot_icons[i] if i < selected_bot_icons.size() else -1
		GameConfig.bot_icon_names[i] = ICONS[icon_idx] if icon_idx >= 0 else ""
	get_tree().change_scene_to_file("res://game.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
