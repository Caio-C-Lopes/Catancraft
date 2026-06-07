## dev_card_panel.gd
## Painel que exibe as cartas de desenvolvimento compradas pelo jogador humano.

extends Panel

enum CardType {
	KNIGHT,
	ROAD_BUILDING,
	YEAR_OF_PLENTY,
	MONOPOLY,
	CHAPEL,
	UNIVERSITY,
	PALACE,
	LIBRARY,
	MARKET,
}

const CARD_TEXTURES: Dictionary = {
	0: "res://card_assets/development/KNIGHT.png",
	1: "res://card_assets/development/ROAD_BUILDING.png",
	2: "res://card_assets/development/YEAR_OF_PLENTY.png",
	3: "res://card_assets/development/MONOPOLY.png",
	4: "res://card_assets/development/CHAPEL.png",
	5: "res://card_assets/development/UNIVERSITY.png",
	6: "res://card_assets/development/PALACE.png",
	7: "res://card_assets/development/LIBRARY.png",
	8: "res://card_assets/development/MARKET.png",
}

signal card_played(card_index: int, card_type: int)

# CardGrid está dentro de ScrollContainer
@onready var _card_grid: VBoxContainer = $ScrollContainer/CardGrid  # corrigido

var _cards_in_hand: Array[int] = []
var _card_buttons: Array = []
var _playable: bool = false

const CARD_WIDTH  := 140
const CARD_HEIGHT := 95
const PANEL_W     := 160.0
const PANEL_H     := 310.0


func _ready() -> void:
	await get_tree().process_frame
	_setup_panel_style()
	_setup_position()
	_setup_scroll()


func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.70)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.1, 0.1, 1.0)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)


func _setup_position() -> void:
	# Ancora canto superior esquerdo, logo abaixo dos botões de ação
	anchor_left   = 0.0
	anchor_right  = 0.0
	anchor_top    = 0.0
	anchor_bottom = 0.0
	offset_left   = 0.0
	offset_right  = PANEL_W
	offset_top    = 96.0
	offset_bottom = 35.0 + PANEL_H


func _setup_scroll() -> void:
	var scroll := get_node_or_null("ScrollContainer")
	if scroll == null:
		return
	scroll.anchor_left   = 0.0
	scroll.anchor_right  = 1.0
	scroll.anchor_top    = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left   = 4.0
	scroll.offset_right  = -4.0
	scroll.offset_top    = 4.0
	scroll.offset_bottom = -4.0

	if _card_grid:
		_card_grid.add_theme_constant_override("separation", 6)
		_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# ── API pública ────────────────────────────────────────────────────────────────

func add_card(card_type: int) -> void:
	_cards_in_hand.append(card_type)
	_rebuild_grid()


func remove_card(index: int) -> void:
	if index < 0 or index >= _cards_in_hand.size():
		return
	_cards_in_hand.remove_at(index)
	_rebuild_grid()


func set_playable(enabled: bool) -> void:
	_playable = enabled
	_update_interactivity()


func get_cards() -> Array[int]:
	return _cards_in_hand.duplicate()


# ── Grid interno ───────────────────────────────────────────────────────────────

func _rebuild_grid() -> void:
	for btn in _card_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_card_buttons.clear()

	for i in range(_cards_in_hand.size()):
		var ctype: int = _cards_in_hand[i]
		var btn := _make_card_button(ctype, i)
		_card_grid.add_child(btn)
		_card_buttons.append(btn)

	_update_interactivity()


func _make_card_button(card_type: int, idx: int) -> TextureButton:
	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var path: String = CARD_TEXTURES.get(card_type, "")
	if path != "":
		var tex := load(path) as Texture2D
		if tex:
			btn.texture_normal = tex

	btn.tooltip_text = _card_type_name(card_type)

	var captured_idx := idx
	btn.pressed.connect(func() -> void:
		if _playable:
			_on_card_button_pressed(captured_idx)
	)

	return btn


func _on_card_button_pressed(idx: int) -> void:
	if idx < 0 or idx >= _cards_in_hand.size():
		return
	card_played.emit(idx, _cards_in_hand[idx])


func _update_interactivity() -> void:
	for i in range(_card_buttons.size()):
		var btn = _card_buttons[i]
		if not is_instance_valid(btn):
			continue
		var is_vp := _is_victory_point(_cards_in_hand[i])
		btn.disabled = (not _playable) or is_vp
		btn.modulate = Color(1, 1, 1, 1.0) if (_playable and not is_vp) else Color(1, 1, 1, 0.6)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _is_victory_point(card_type: int) -> bool:
	return card_type in [4, 5, 6, 7, 8]


func _card_type_name(card_type: int) -> String:
	match card_type:
		0: return "Cavaleiro"
		1: return "Construção de Estradas"
		2: return "Ano da Abundância"
		3: return "Monopólio"
		4: return "Capela (1 PV)"
		5: return "Universidade (1 PV)"
		6: return "Palácio (1 PV)"
		7: return "Biblioteca (1 PV)"
		8: return "Mercado (1 PV)"
	return "Carta desconhecida"
