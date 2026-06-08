extends Control

signal discard_confirmed(discarded_resources: Array)
signal steal_target_chosen(target_player: Object)

var _target_amount: int = 0
var _discard_resources: Array[String] = []
var _discard_slots: Array[Control] = []

var _font: Font
var title_label: Label
var slots_hbox: HBoxContainer
var btn_confirm: TextureButton


func _ready():
	_font = load("res://assets/fonts/1_Minecraft-Regular.otf")
	hide()
	_build_ui()


# ─── CONSTRUÇÃO DA UI PROCEDURAL (Design Compacto e Bonito) ───────────────────
func _build_ui():
	# Âncora o painel no centro da tela (com um leve deslocamento para a esquerda e cima)
	position = Vector2(150, 150)  # Ajuste esses números se quiser ele mais pro lado

	# Fundo do Painel
	var panel = PanelContainer.new()
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.95, 0.95, 0.95, 1.0)  # Cinza bem clarinho/branco
	bg_style.border_width_left = 3
	bg_style.border_width_right = 3
	bg_style.border_width_top = 3
	bg_style.border_width_bottom = 3
	bg_style.border_color = Color(0.15, 0.15, 0.15, 1)  # Borda escura
	bg_style.corner_radius_top_left = 12  # Cantos arredondados
	bg_style.corner_radius_top_right = 12
	bg_style.corner_radius_bottom_left = 12
	bg_style.corner_radius_bottom_right = 12
	bg_style.shadow_color = Color(0, 0, 0, 0.3)  # Sombrinha charmosa
	bg_style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", bg_style)
	z_index = 100

	# Tamanho mínimo mais compacto
	panel.custom_minimum_size = Vector2(280, 140)
	add_child(panel)

	# Container de Margem (para o conteúdo não colar nas bordas)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	panel.add_child(margin)

	# Container Vertical Principal
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(main_vbox)

	# Título
	title_label = Label.new()
	title_label.add_theme_font_override("font", _font)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)

	# Linha onde as cartas ou botões vão aparecer
	slots_hbox = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 6)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(slots_hbox)

	# Botão Confirmar
	btn_confirm = TextureButton.new()
	btn_confirm.texture_normal = load("res://icons_assets/check.png")
	btn_confirm.custom_minimum_size = Vector2(48, 48)  # Botão menorzinho
	btn_confirm.ignore_texture_size = true
	btn_confirm.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_confirm.pressed.connect(_on_confirm_pressed)
	main_vbox.add_child(btn_confirm)


# ─── MODO DESCARTE ────────────────────────────────────────────────────────────
func open_discard_mode(amount_to_discard: int):
	_target_amount = amount_to_discard
	title_label.text = "O Ladrão atacou!\nDescarte %d cartas." % amount_to_discard
	_clear_slots()
	btn_confirm.show()
	_refresh_confirm_btn()
	show()


func add_discard_card(res_name: String):
	if _discard_resources.size() >= _target_amount:
		return

	_discard_resources.append(res_name)

	var slot = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	slot.add_theme_stylebox_override("panel", style)
	slot.custom_minimum_size = Vector2(40, 60)  # Cartas menores e mais proporcionais
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var card = TextureRect.new()
	var tex_file = "STONE" if res_name == "ore" else res_name.to_upper()
	card.texture = load("res://card_assets/resources/%s.png" % tex_file)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(card)

	var idx = _discard_slots.size()
	slot.gui_input.connect(
		func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_remove_discard_slot(idx)
	)

	_discard_slots.append(slot)
	slots_hbox.add_child(slot)
	_refresh_confirm_btn()


func _remove_discard_slot(idx: int):
	if idx >= _discard_slots.size():
		return
	var removed_res = _discard_resources[idx]

	_discard_slots[idx].queue_free()
	_discard_slots.remove_at(idx)
	_discard_resources.remove_at(idx)

	for i in range(_discard_slots.size()):
		var slot = _discard_slots[i]
		for conn in slot.get_signal_connection_list("gui_input"):
			slot.disconnect("gui_input", conn["callable"])
		var new_idx = i
		slot.gui_input.connect(
			func(ev):
				if (
					ev is InputEventMouseButton
					and ev.pressed
					and ev.button_index == MOUSE_BUTTON_LEFT
				):
					_remove_discard_slot(new_idx)
		)

	_refresh_confirm_btn()

	var hud = get_parent()
	if hud and hud.has_method("hud_preview_give"):
		hud.hud_preview_give(removed_res, 1)


func _refresh_confirm_btn():
	var count = _discard_resources.size()
	var valid = count == _target_amount
	var over = count > _target_amount
	btn_confirm.disabled = not valid
	btn_confirm.modulate = Color(1, 1, 1, 1.0) if valid else Color(1, 1, 1, 0.4)
	# Aviso visual se selecionou cartas demais
	if over:
		title_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
		title_label.text = (
			"O Ladrão atacou!\nDescarte %d cartas. (%d/%d)"
			% [_target_amount, count, _target_amount]
		)
	elif count > 0:
		title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		title_label.text = (
			"O Ladrão atacou!\nDescarte %d cartas. (%d/%d)"
			% [_target_amount, count, _target_amount]
		)
	else:
		title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		title_label.text = "O Ladrão atacou!\nDescarte %d cartas." % _target_amount


func _on_confirm_pressed():
	emit_signal("discard_confirmed", _discard_resources.duplicate())
	hide()


# ─── MODO ROUBO ───────────────────────────────────────────────────────────────
# victims: Array de objetos Player
func open_steal_mode(victims: Array):
	title_label.text = "De quem você\nquer roubar?"
	title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_clear_slots()
	btn_confirm.hide()

	for victim_player in victims:
		var slot = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.88, 0.88, 0.88, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.3, 0.3, 1)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		slot.add_theme_stylebox_override("panel", style)
		slot.custom_minimum_size = Vector2(72, 96)
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		slot.add_child(vbox)

		# Ícone do bot (tenta 'icon' e 'player_icon' como nomes de propriedade)
		var bot_img = TextureRect.new()
		var icon_tex: Texture2D = null
		if victim_player.get("icon") != null:
			icon_tex = victim_player.get("icon")
		elif victim_player.get("player_icon") != null:
			icon_tex = victim_player.get("player_icon")
		if icon_tex != null:
			bot_img.texture = icon_tex
		bot_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bot_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bot_img.custom_minimum_size = Vector2(48, 52)
		bot_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(bot_img)

		# Nome do bot
		var name_label = Label.new()
		name_label.text = victim_player.player_name
		name_label.add_theme_font_override("font", _font)
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_label)

		# Hover: destaca com a cor do bot
		var bot_color = victim_player.player_color
		slot.mouse_entered.connect(
			func():
				style.bg_color = bot_color.lightened(0.35)
				style.border_color = bot_color
				slot.add_theme_stylebox_override("panel", style)
		)
		slot.mouse_exited.connect(
			func():
				style.bg_color = Color(0.88, 0.88, 0.88, 1.0)
				style.border_color = Color(0.3, 0.3, 0.3, 1)
				slot.add_theme_stylebox_override("panel", style)
		)

		# Clique: emite o objeto Player escolhido
		slot.gui_input.connect(
			func(ev):
				if (
					ev is InputEventMouseButton
					and ev.pressed
					and ev.button_index == MOUSE_BUTTON_LEFT
				):
					emit_signal("steal_target_chosen", victim_player)
					hide()
		)

		slots_hbox.add_child(slot)

	show()


func _clear_slots():
	for child in slots_hbox.get_children():
		child.queue_free()
	_discard_slots.clear()
	_discard_resources.clear()
