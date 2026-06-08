extends CanvasLayer

# ── Referências aos nós criados uma única vez no _ready() ─────────────────────
var _font: Font

var _overlay: ColorRect
var _panel_root: Control

# Labels atualizados a cada vitória
var _place_lbl: Label

# Linhas de jogadores (recriadas a cada show_victory para refletir n de jogadores)
var _players_container: VBoxContainer

# Botões (criados uma vez, sempre funcionais)
var _btn_play_again: Button
var _btn_main_menu: Button

# Destino do próximo botão (definido em _on_play_again / _on_main_menu)
var _next_scene: String = ""


# ─────────────────────────────────────────────────────────────────────────────
func _ready():
	# Roda sempre, mesmo com o jogo pausado — garante que botões respondam
	process_mode = Node.PROCESS_MODE_ALWAYS

	_font = load("res://assets/fonts/1_Minecraft-Regular.otf")

	_build_static_ui()

	# Começa escondido
	hide()


# ── Constrói toda a UI uma única vez ─────────────────────────────────────────
func _build_static_ui() -> void:
	# Overlay escuro
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.72)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	# Raiz do painel (centralizado)
	_panel_root = Control.new()
	_panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel_root)

	var panel := PanelContainer.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -380
	panel.offset_right  =  380
	panel.offset_top    = -300
	panel.offset_bottom =  300

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.09, 0.13, 0.97)
	panel_style.border_width_left   = 2
	panel_style.border_width_right  = 2
	panel_style.border_width_top    = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.9, 0.75, 0.2, 1.0)
	panel_style.corner_radius_top_left     = 10
	panel_style.corner_radius_top_right    = 10
	panel_style.corner_radius_bottom_left  = 10
	panel_style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	_panel_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# Label de colocação (texto atualizado a cada partida)
	_place_lbl = Label.new()
	_place_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place_lbl.add_theme_font_override("font", _font)
	_place_lbl.add_theme_font_size_override("font_size", 26)
	root_vbox.add_child(_place_lbl)

	root_vbox.add_child(_make_separator())
	root_vbox.add_child(_make_header_row())

	# Container das linhas de jogadores (limpo e repovoado a cada show_victory)
	_players_container = VBoxContainer.new()
	_players_container.add_theme_constant_override("separation", 4)
	root_vbox.add_child(_players_container)

	root_vbox.add_child(_make_separator())

	# Botões
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(btn_row)

	_btn_play_again = _make_button("Jogar Novamente", Color(0.2, 0.6, 0.2), _on_play_again)
	_btn_main_menu  = _make_button("Menu Principal",  Color(0.5, 0.2, 0.2), _on_main_menu)
	btn_row.add_child(_btn_play_again)
	btn_row.add_child(_btn_main_menu)


# ── Chamado pelo game_manager a cada vitória ──────────────────────────────────
func show_victory(
	original_players: Array,
	largest_army_owner: int,
	longest_road_owner: int
) -> void:
	# Ordena por pontuação decrescente
	var ranked: Array = original_players.duplicate()
	ranked.sort_custom(func(a, b): return a.get_total_points() > b.get_total_points())

	var human_player: Player = original_players[0]
	var human_rank: int = ranked.find(human_player) + 1

	# Atualiza label de colocação
	_place_lbl.text = _rank_message(human_rank)
	_place_lbl.add_theme_color_override("font_color", _rank_color(human_rank))

	# Limpa linhas antigas e recria
	for child in _players_container.get_children():
		child.queue_free()

	for i in range(ranked.size()):
		var p: Player = ranked[i]
		var orig_idx: int = original_players.find(p)
		_players_container.add_child(
			_make_player_row(
				p,
				i + 1,
				p == human_player,
				orig_idx == largest_army_owner,
				orig_idx == longest_road_owner
			)
		)

	show()


# ── Esconde tudo e muda de cena ───────────────────────────────────────────────
func _navigate(scene_path: String) -> void:
	hide()
	get_tree().paused = false
	# Limpa o BoardState (autoload) antes de trocar de cena.
	# Sem isso, os links dos vertices guardam referencias a nos ja liberados
	# da cena anterior, causando 'previously freed' na proxima partida.
	var board_state = get_node_or_null("/root/BoardState")
	if board_state != null:
		board_state.reset_state()
	get_tree().change_scene_to_file(scene_path)


func _on_play_again():
	_navigate("res://lobby.tscn")


func _on_main_menu():
	_navigate("res://main_menu.tscn")


# ── Construtores de UI ────────────────────────────────────────────────────────
func _make_header_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(160, 1)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var headers := [
		["🏆", "Total"],
		["🏠", "Aldeias"],
		["🏙", "Cidades"],
		["⭐", "Cartas VP"],
		["⚔", "Exército"],
		["🛣", "Estrada"],
	]

	for h in headers:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(64, 1)
		col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_theme_constant_override("separation", 2)

		var icon_lbl := Label.new()
		icon_lbl.text = h[0]
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 16)
		col.add_child(icon_lbl)

		var text_lbl := Label.new()
		text_lbl.text = h[1]
		text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_lbl.add_theme_font_override("font", _font)
		text_lbl.add_theme_font_size_override("font_size", 9)
		text_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		col.add_child(text_lbl)

		row.add_child(col)

	return row


func _make_player_row(
	player: Player,
	rank: int,
	is_human: bool,
	has_largest_army: bool,
	has_longest_road: bool
) -> PanelContainer:
	var container := PanelContainer.new()

	var style := StyleBoxFlat.new()
	if is_human:
		style.bg_color = Color(player.player_color.r, player.player_color.g, player.player_color.b, 0.18)
		style.border_width_left   = 3
		style.border_width_right  = 3
		style.border_width_top    = 3
		style.border_width_bottom = 3
		style.border_color = player.player_color
	else:
		style.bg_color = Color(1, 1, 1, 0.04)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	container.add_theme_stylebox_override("panel", style)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left",   8)
	inner_margin.add_theme_constant_override("margin_right",  8)
	inner_margin.add_theme_constant_override("margin_top",    6)
	inner_margin.add_theme_constant_override("margin_bottom", 6)
	container.add_child(inner_margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	inner_margin.add_child(row)

	# Ícone
	var icon_rect := TextureRect.new()
	if player.icon_texture:
		icon_rect.texture = player.icon_texture
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_rect)

	# Nome + posição
	var name_vbox := VBoxContainer.new()
	name_vbox.custom_minimum_size = Vector2(120, 1)
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vbox.add_theme_constant_override("separation", 0)
	name_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_vbox)

	var rank_lbl := Label.new()
	rank_lbl.text = "%dº lugar" % rank
	rank_lbl.add_theme_font_override("font", _font)
	rank_lbl.add_theme_font_size_override("font_size", 9)
	rank_lbl.add_theme_color_override("font_color", _rank_color(rank))
	name_vbox.add_child(rank_lbl)

	var name_lbl := Label.new()
	name_lbl.text = player.player_name
	name_lbl.add_theme_font_override("font", _font)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", player.player_color)
	name_lbl.clip_text = true
	name_vbox.add_child(name_lbl)

	# Pontuações
	var settlements_built := 5 - player.settlements_remaining
	var cities_built      := 4 - player.cities_remaining
	var pts_settlements   := (settlements_built - cities_built)
	var pts_cities        := cities_built * 2
	var pts_vp_cards      := player.count_victory_point_cards()
	var pts_army          := 2 if has_largest_army else 0
	var pts_road          := 2 if has_longest_road else 0
	var pts_total         := player.get_total_points()

	var cols := [pts_total, pts_settlements, pts_cities, pts_vp_cards, pts_army, pts_road]

	for ci in range(cols.size()):
		row.add_child(_make_score_cell(cols[ci], ci == 0))

	return container


func _make_score_cell(value: int, is_total: bool) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(64, 40)
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var lbl := Label.new()
	lbl.text = str(value)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_override("font", _font)

	if is_total:
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.2))
	elif value > 0:
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	else:
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	cell.add_child(lbl)
	return cell


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.9, 0.75, 0.2, 0.35))
	return sep


func _make_button(label_text: String, col: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(160, 44)
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 13)

	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)

	var style_hover := style.duplicate() as StyleBoxFlat
	style_hover.bg_color = col.lightened(0.15)
	btn.add_theme_stylebox_override("hover", style_hover)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(callback)
	return btn


# ── Helpers de texto e cor ────────────────────────────────────────────────────
func _rank_message(rank: int) -> String:
	match rank:
		1: return "🏆  Você ficou em 1º lugar!"
		2: return "🥈  Você ficou em 2º lugar!"
		3: return "🥉  Você ficou em 3º lugar!"
		_: return "Você ficou em %dº lugar!" % rank


func _rank_color(rank: int) -> Color:
	match rank:
		1: return Color(0.95, 0.82, 0.2)
		2: return Color(0.78, 0.80, 0.85)
		3: return Color(0.80, 0.52, 0.25)
		_: return Color(0.65, 0.65, 0.65)
