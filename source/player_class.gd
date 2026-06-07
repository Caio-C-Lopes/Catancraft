class_name Player
extends Resource

@export var player_name: String
@export var player_color: Color
@export var icon_texture: Texture2D
@export var points: int = 0

var roads_remaining: int = 15
var settlements_remaining: int = 5
var cities_remaining: int = 4

var dev_cards_in_hand: int = 0
var knights_played: int = 0

# ── Cartas de desenvolvimento na mão ──────────────────────────────────────────
# Cada entrada é um inteiro correspondente a DevCardPanel.CardType
var dev_cards: Array[int] = []

# Controla se já jogou uma carta de desenvolvimento neste turno
var played_dev_card_this_turn: bool = false

# Carta comprada neste turno (não pode ser jogada no mesmo turno)
var dev_card_bought_this_turn: bool = false


func _init(name: String, color: Color, icon: Texture2D = null):
	player_name = name
	player_color = color
	icon_texture = icon


var resources := {"wood": 0, "brick": 0, "wheat": 0, "sheep": 0, "ore": 0}


func add_resource(type: String, amount: int):
	if not resources.has(type):
		return
	resources[type] += amount
	print("%s recebeu %d de %s (total: %d)" % [player_name, amount, type, resources[type]])


func remove_resource(type: String, amount: int):
	if not resources.has(type):
		return
	resources[type] = max(0, resources[type] - amount)


func can_afford(cost: Dictionary) -> bool:
	for r in cost:
		if not resources.has(r) or resources[r] < cost[r]:
			return false
	return true


# ── Cartas de desenvolvimento ──────────────────────────────────────────────────


func add_dev_card(card_type: int) -> void:
	dev_cards.append(card_type)
	dev_cards_in_hand = dev_cards.size()
	dev_card_bought_this_turn = true


func remove_dev_card(index: int) -> void:
	if index < 0 or index >= dev_cards.size():
		return
	dev_cards.remove_at(index)
	dev_cards_in_hand = dev_cards.size()


## Contagem de pontos de vitória de cartas (revelados apenas ao vencer)
func count_victory_point_cards() -> int:
	var count := 0
	for c in dev_cards:
		if c in [4, 5, 6, 7, 8]:  # índices de CHAPEL..MARKET em CardType
			count += 1
	return count


## Pontos totais reais (inclui cartas VP secretas) — usado para checar vitória
func get_total_points() -> int:
	return points + count_victory_point_cards()


## Reseta flags de turno
func reset_turn_flags() -> void:
	played_dev_card_this_turn = false
	dev_card_bought_this_turn = false
