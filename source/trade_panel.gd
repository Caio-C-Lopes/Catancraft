extends Control

# ── Sinais ────────────────────────────────────────────────────────────────────
signal trade_confirmed
signal trade_cancelled
signal bank_trade_requested(give_res: String, recv_res: String)

# ── Constantes ────────────────────────────────────────────────────────────────
const RESOURCES = ["wood", "brick", "wheat", "sheep", "ore"]
# Sem limite fixo — jogador pode selecionar quantas cartas quiser (regras Catan)
const MAX_SLOTS = 9  # máximo visual de slots por linha (suficiente para qualquer troca)

# ── Referências internas ──────────────────────────────────────────────────────
var _font: Font

# Slots de oferta (o humano dá) — populados a partir do clique no HUD
var _give_slots: Array[Control] = []
var _give_resources: Array[String] = []

# Slots de pedido (o humano quer receber) — populados pelo clique nos pickers
var _recv_slots: Array[Control] = []
var _recv_resources: Array[String] = []

# Containers das linhas de slots (para adicionar slots dinamicamente)
var _give_hbox_slots: HBoxContainer = null
var _recv_hbox_slots: HBoxContainer = null

# Botões de modo
var _btn_players: TextureButton
var _btn_bank: TextureButton
var _panel_players: PanelContainer = null
var _panel_bank: PanelContainer = null
var _give_mode_icon: TextureRect = null

# Estado
var _trade_with_bank: bool = false

# Botão de confirmação (precisa ser habilitado/desabilitado dinamicamente)
var _btn_check: TextureButton = null

# Referência ao PlayerHUD para preview visual das cartas oferecidas
var _hud: Control = null

# Label de feedback de erro (regra 4:1)
var _error_label: Label = null

# Assets de recursos
var resource_textures: Dictionary = {}


# ── Inicialização ──────────────────────────────────────────────────────────────
func _ready():
	_font = load("res://assets/fonts/1_Minecraft-Regular.otf")
	hide()
	_build_ui()


# ── API pública ───────────────────────────────────────────────────────────────
func open_trade():
	_resolve_hud()
	_clear_all_slots()
	_hide_error()
	_refresh_check_button()
	show()


func close_trade():
	hide()


func get_give_resources() -> Array:
	return _give_resources.filter(func(r): return r != "")


func get_recv_resources() -> Array:
	return _recv_resources.filter(func(r): return r != "")


# Chamado pelo PlayerHUD quando o jogador clica num recurso que possui
func on_hud_resource_clicked(res_name: String):
	if not visible:
		return
	if _give_resources.size() >= MAX_SLOTS:
		return
	_give_resources.append(res_name)
	var slot = _make_card_slot(res_name, true)
	var idx = _give_slots.size()
	slot.gui_input.connect(
		func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_remove_give_slot(idx)
	)
	_give_slots.append(slot)
	_give_hbox_slots.add_child(slot)
	_hide_error()
	_refresh_check_button()
	# Reflete no HUD: diminui 1 do recurso oferecido
	if _hud and _hud.has_method("hud_preview_give"):
		_hud.hud_preview_give(res_name, -1)


# ── Construção da UI ──────────────────────────────────────────────────────────
func _build_ui():
	var panel = PanelContainer.new()
	panel.name = "TradeBackground"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(0, -50)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(1, 1, 1, 1)
	bg_style.border_width_left = 3
	bg_style.border_width_right = 3
	bg_style.border_width_top = 3
	bg_style.border_width_bottom = 3
	bg_style.border_color = Color(0, 0, 0, 1)
	panel.add_theme_stylebox_override("panel", bg_style)
	panel.custom_minimum_size = Vector2(630, 350)
	add_child(panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(main_vbox)

	# ── Linha do topo: seletor de modo ───────────────────────────────────────
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(top_hbox)

	_panel_players = _wrap_in_panel(_make_mode_button("res://icons_assets/players.png"))
	_btn_players = _panel_players.get_child(0)
	_btn_players.pressed.connect(_on_select_players)
	top_hbox.add_child(_panel_players)

	_panel_bank = _wrap_in_panel(_make_mode_button("res://icons_assets/bank.png"))
	_btn_bank = _panel_bank.get_child(0)
	_btn_bank.pressed.connect(_on_select_bank)
	top_hbox.add_child(_panel_bank)

	var spacer_top = Control.new()
	spacer_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer_top)

	# ── Linha dos recursos disponíveis para PEDIR ────────────────────────────
	var offer_row = HBoxContainer.new()
	offer_row.add_theme_constant_override("separation", 6)
	offer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(offer_row)

	_give_mode_icon = TextureRect.new()
	_give_mode_icon.texture = load("res://icons_assets/players.png")
	_give_mode_icon.custom_minimum_size = Vector2(40, 40)
	_give_mode_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_give_mode_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_give_mode_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	offer_row.add_child(_give_mode_icon)

	var arrow_down = TextureRect.new()
	arrow_down.texture = load("res://icons_assets/arrow_down.png")
	arrow_down.custom_minimum_size = Vector2(40, 40)
	arrow_down.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow_down.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow_down.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	offer_row.add_child(arrow_down)

	# 5 cards de recursos clicáveis (pickers)
	for i in range(5):
		var card = _make_resource_picker(RESOURCES[i])
		offer_row.add_child(card)

	# ── Linha dos slots do que o humano QUER receber ──────────────────────────
	var recv_row = HBoxContainer.new()
	recv_row.add_theme_constant_override("separation", 4)
	recv_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(recv_row)

	# Indent para alinhar com os pickers (pula ícone + seta)
	var recv_indent = Control.new()
	recv_indent.custom_minimum_size = Vector2(92, 0)
	recv_row.add_child(recv_indent)

	_recv_hbox_slots = HBoxContainer.new()
	_recv_hbox_slots.add_theme_constant_override("separation", 4)
	recv_row.add_child(_recv_hbox_slots)

	# ── Espaçador expansível ──────────────────────────────────────────────────
	var spacer_mid = Control.new()
	spacer_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer_mid)

	# ── Linha do jogador humano: o que oferece ────────────────────────────────
	var give_row = HBoxContainer.new()
	give_row.add_theme_constant_override("separation", 6)
	give_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(give_row)

	# Ícone do jogador humano
	var human_icon = TextureRect.new()
	var icon_name: String = ""
	var gc = _get_game_config()
	if gc and gc.get("player_icon_name"):
		icon_name = gc.player_icon_name
	if icon_name != "":
		var icon_tex = load("res://icons_assets/%s.png" % icon_name)
		if icon_tex:
			human_icon.texture = icon_tex
	else:
		human_icon.texture = load("res://icons_assets/players.png")
	human_icon.custom_minimum_size = Vector2(40, 40)
	human_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	human_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	human_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	give_row.add_child(human_icon)

	var arrow_up = TextureRect.new()
	arrow_up.texture = load("res://icons_assets/arrow_up.png")
	arrow_up.custom_minimum_size = Vector2(40, 40)
	arrow_up.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow_up.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow_up.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	give_row.add_child(arrow_up)

	# Container dinâmico dos slots de oferta (começa vazio)
	_give_hbox_slots = HBoxContainer.new()
	_give_hbox_slots.add_theme_constant_override("separation", 4)
	give_row.add_child(_give_hbox_slots)

	# ── Label de erro (regra 4:1) ─────────────────────────────────────────────
	_error_label = Label.new()
	_error_label.text = ""
	_error_label.add_theme_font_override("font", _font)
	_error_label.add_theme_font_size_override("font_size", 13)
	_error_label.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1, 1.0))
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error_label.visible = false
	main_vbox.add_child(_error_label)

	# ── Botões de confirmação / cancelamento ──────────────────────────────────
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(btn_hbox)

	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_hbox.add_child(spacer2)

	_btn_check = TextureButton.new()
	_btn_check.texture_normal = load("res://icons_assets/check.png")
	_btn_check.custom_minimum_size = Vector2(64, 64)
	_btn_check.ignore_texture_size = true
	_btn_check.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_btn_check.pressed.connect(_on_confirm)
	btn_hbox.add_child(_btn_check)

	var btn_cancel = TextureButton.new()
	btn_cancel.texture_normal = load("res://icons_assets/cancel.png")
	btn_cancel.custom_minimum_size = Vector2(64, 64)
	btn_cancel.ignore_texture_size = true
	btn_cancel.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_cancel.pressed.connect(_on_cancel)
	btn_hbox.add_child(btn_cancel)

	_refresh_mode_buttons()
	_refresh_check_button()


# ── Fábrica de widgets ────────────────────────────────────────────────────────


func _make_mode_button(icon_path: String) -> TextureButton:
	var btn = TextureButton.new()
	btn.texture_normal = load(icon_path)
	btn.custom_minimum_size = Vector2(52, 52)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	return btn


func _wrap_in_panel(btn: TextureButton) -> PanelContainer:
	var pc = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	pc.add_theme_stylebox_override("panel", style)
	pc.add_child(btn)
	return pc


# Card de recurso clicável para o jogador PEDIR (pickers fixos da linha de cima)
func _make_resource_picker(res_name: String) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(60, 80)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var card = TextureRect.new()
	var tex: Texture2D = _load_resource_tex(res_name)
	if tex:
		card.texture = tex
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(card)

	panel.gui_input.connect(
		func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_recv_picker_clicked(res_name)
	)
	return panel


# Slot de carta preenchida (sem borda, apenas a textura da carta)
func _make_card_slot(res_name: String, clickable: bool = false) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(60, 80)
	if clickable:
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var card = TextureRect.new()
	var tex: Texture2D = _load_resource_tex(res_name)
	if tex:
		card.texture = tex
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(card)
	return panel


func _load_resource_tex(res_name: String) -> Texture2D:
	if resource_textures.has(res_name):
		return resource_textures[res_name]
	var file_name := "STONE" if res_name == "ore" else res_name.to_upper()
	return load("res://card_assets/resources/%s.png" % file_name)


# ── Lógica de seleção ─────────────────────────────────────────────────────────


# Clique num picker da linha de cima → adiciona nos slots de pedido
func _on_recv_picker_clicked(res_name: String):
	if _recv_resources.size() >= MAX_SLOTS:
		return
	_recv_resources.append(res_name)
	var slot = _make_card_slot(res_name, true)
	var idx = _recv_slots.size()
	slot.gui_input.connect(
		func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_remove_recv_slot(idx)
	)
	_recv_slots.append(slot)
	_recv_hbox_slots.add_child(slot)
	_refresh_check_button()


# Remove slot de oferta pelo índice (clique na carta)
func _remove_give_slot(idx: int):
	if idx >= _give_slots.size():
		return
	var slot = _give_slots[idx]
	var res_name = _give_resources[idx]
	_give_slots.remove_at(idx)
	_give_resources.remove_at(idx)
	slot.queue_free()
	_hide_error()
	_refresh_check_button()
	# Devolve 1 do recurso removido da oferta ao HUD
	if _hud and _hud.has_method("hud_preview_give"):
		_hud.hud_preview_give(res_name, 1)
	# Reconecta os índices dos slots restantes
	_reconnect_give_slots()


# Remove slot de pedido pelo índice
func _remove_recv_slot(idx: int):
	if idx >= _recv_slots.size():
		return
	var slot = _recv_slots[idx]
	_recv_slots.remove_at(idx)
	_recv_resources.remove_at(idx)
	slot.queue_free()
	_refresh_check_button()
	_reconnect_recv_slots()


func _reconnect_give_slots():
	for i in range(_give_slots.size()):
		var slot = _give_slots[i]
		for conn in slot.get_signal_connection_list("gui_input"):
			slot.disconnect("gui_input", conn["callable"])
		var idx = i
		slot.gui_input.connect(
			func(ev):
				if (
					ev is InputEventMouseButton
					and ev.pressed
					and ev.button_index == MOUSE_BUTTON_LEFT
				):
					_remove_give_slot(idx)
		)


func _reconnect_recv_slots():
	for i in range(_recv_slots.size()):
		var slot = _recv_slots[i]
		for conn in slot.get_signal_connection_list("gui_input"):
			slot.disconnect("gui_input", conn["callable"])
		var idx = i
		slot.gui_input.connect(
			func(ev):
				if (
					ev is InputEventMouseButton
					and ev.pressed
					and ev.button_index == MOUSE_BUTTON_LEFT
				):
					_remove_recv_slot(idx)
		)


func _clear_all_slots():
	for slot in _give_slots:
		slot.queue_free()
	_give_slots.clear()
	_give_resources.clear()

	for slot in _recv_slots:
		slot.queue_free()
	_recv_slots.clear()
	_recv_resources.clear()


# ── Helpers ───────────────────────────────────────────────────────────────────


func _get_game_config():
	var root = get_tree().get_root()
	for i in range(root.get_child_count()):
		var child = root.get_child(i)
		if child.name == "GameConfig":
			return child
	return null


# Localiza o PlayerHUD na árvore para poder chamar hud_preview_give
func _resolve_hud():
	if _hud != null:
		return
	_hud = get_tree().get_root().find_child("PlayerHUD", true, false)


func _refresh_mode_buttons():
	var sel_style = StyleBoxFlat.new()
	sel_style.bg_color = Color(0.18, 0.47, 0.87, 0.18)
	sel_style.border_width_left = 3
	sel_style.border_width_right = 3
	sel_style.border_width_top = 3
	sel_style.border_width_bottom = 3
	sel_style.border_color = Color(0.18, 0.47, 0.87, 1.0)
	sel_style.corner_radius_top_left = 6
	sel_style.corner_radius_top_right = 6
	sel_style.corner_radius_bottom_left = 6
	sel_style.corner_radius_bottom_right = 6

	var unsel_style = StyleBoxFlat.new()
	unsel_style.bg_color = Color(1, 1, 1, 0)
	unsel_style.border_width_left = 0
	unsel_style.border_width_right = 0
	unsel_style.border_width_top = 0
	unsel_style.border_width_bottom = 0

	if _trade_with_bank:
		if _panel_bank:
			_panel_bank.add_theme_stylebox_override("panel", sel_style)
		if _panel_players:
			_panel_players.add_theme_stylebox_override("panel", unsel_style)
		if _give_mode_icon:
			var tex = load("res://icons_assets/bank.png")
			if tex:
				_give_mode_icon.texture = tex
	else:
		if _panel_players:
			_panel_players.add_theme_stylebox_override("panel", sel_style)
		if _panel_bank:
			_panel_bank.add_theme_stylebox_override("panel", unsel_style)
		if _give_mode_icon:
			var tex = load("res://icons_assets/players.png")
			if tex:
				_give_mode_icon.texture = tex


# ── Callbacks ─────────────────────────────────────────────────────────────────
func _on_select_players():
	_trade_with_bank = false
	_refresh_mode_buttons()
	_refresh_check_button()


func _on_select_bank():
	_trade_with_bank = true
	_refresh_mode_buttons()
	_refresh_check_button()


# Habilita ou desabilita o botão de confirmar conforme a validade da troca.
# No modo banco: válido só se houver exatamente 4 cartas do mesmo recurso
#                e exatamente 1 carta para receber.
# No modo jogadores: válido se houver pelo menos 1 carta em cada lado.
func _refresh_check_button():
	if _btn_check == null:
		return
	var valid := _is_trade_valid()
	_btn_check.disabled = not valid
	_btn_check.modulate = Color(1, 1, 1, 1.0) if valid else Color(1, 1, 1, 0.4)


func _is_trade_valid() -> bool:
	var give = get_give_resources()
	var recv = get_recv_resources()
	if _trade_with_bank:
		if give.size() != 4 or recv.size() != 1:
			return false
		var first = give[0]
		for r in give:
			if r != first:
				return false
		return true
	else:
		return give.size() >= 1 and recv.size() >= 1


func _on_confirm():
	if _trade_with_bank:
		_try_bank_trade()
	else:
		emit_signal("trade_confirmed")
		close_trade()


func _try_bank_trade():
	var give = get_give_resources()
	var recv = get_recv_resources()

	if give.size() != 4:
		_show_error("Ofereça exatamente 4 cartas do mesmo recurso.")
		return

	var first = give[0]
	for r in give:
		if r != first:
			_show_error("As 4 cartas oferecidas devem ser do mesmo recurso.")
			return

	if recv.size() != 1:
		_show_error("Escolha exatamente 1 recurso para receber.")
		return

	_hide_error()
	emit_signal("bank_trade_requested", first, recv[0])
	close_trade()


func _show_error(msg: String):
	if _error_label:
		_error_label.text = msg
		_error_label.visible = true


func _hide_error():
	if _error_label:
		_error_label.text = ""
		_error_label.visible = false


func _on_cancel():
	if _hud and _hud.has_method("hud_reset_preview"):
		_hud.hud_reset_preview()
	emit_signal("trade_cancelled")
	close_trade()
