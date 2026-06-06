extends PanelContainer

const BANK_INITIAL = {
	"wood": 19,
	"brick": 19,
	"wheat": 19,
	"sheep": 19,
	"ore": 19,
}
const DEV_CARDS_INITIAL = 25

const RESOURCE_ORDER = ["wood", "brick", "wheat", "sheep", "ore"]

var bank_amounts: Dictionary = {}
var dev_cards_remaining: int = DEV_CARDS_INITIAL
var _count_labels: Dictionary = {}
var _dev_label: Label = null
var font: Font

@export var wood_icon: Texture2D
@export var brick_icon: Texture2D
@export var wheat_icon: Texture2D
@export var sheep_icon: Texture2D
@export var ore_icon: Texture2D
@export var dev_card_icon: Texture2D


func _ready():
	font = load("res://assets/fonts/1_Minecraft-Regular.otf")

	for res in BANK_INITIAL:
		bank_amounts[res] = BANK_INITIAL[res]

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0, 0, 0, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)

	_build_ui()

	await get_tree().process_frame
	_snap_below_dice_log()


func _snap_below_dice_log():
	var dice_log = get_parent().get_node_or_null("DiceLog")
	if not dice_log:
		return

	anchor_left = dice_log.anchor_left
	anchor_right = dice_log.anchor_right
	anchor_top = dice_log.anchor_top
	anchor_bottom = dice_log.anchor_bottom

	var gap = 6.0
	var panel_w = 6 * 38 + 24
	var panel_h = 82.0

	offset_right = dice_log.offset_right
	offset_left = dice_log.offset_right - panel_w
	offset_top = dice_log.offset_bottom + gap
	offset_bottom = offset_top + panel_h


func _build_ui():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(root_vbox)

	var icons = {
		"wood": wood_icon,
		"brick": brick_icon,
		"wheat": wheat_icon,
		"sheep": sheep_icon,
		"ore": ore_icon,
	}

	var grid = HBoxContainer.new()
	grid.add_theme_constant_override("separation", 2)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(grid)

	for res in RESOURCE_ORDER:
		grid.add_child(
			_make_cell(icons[res], str(bank_amounts[res]), func(lbl): _count_labels[res] = lbl)
		)

	grid.add_child(_make_cell(dev_card_icon, str(dev_cards_remaining), func(lbl): _dev_label = lbl))


func _make_cell(icon: Texture2D, count_text: String, store_label: Callable) -> VBoxContainer:
	var cell = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 1)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_rect = TextureRect.new()
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(icon_rect)

	var count_lbl = Label.new()
	count_lbl.text = count_text
	count_lbl.add_theme_font_override("font", font)
	count_lbl.add_theme_font_size_override("font_size", 12)
	count_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(count_lbl)

	store_label.call(count_lbl)
	return cell


func draw_dev_card() -> bool:
	if dev_cards_remaining <= 0:
		return false
	dev_cards_remaining -= 1
	_refresh_dev_label()
	return true


func get_dev_cards_remaining() -> int:
	return dev_cards_remaining


func _refresh_label(resource: String):
	if not _count_labels.has(resource):
		return

	var lbl = _count_labels[resource]
	lbl.text = str(bank_amounts[resource])

	lbl.add_theme_color_override(
		"font_color", Color(0.8, 0.1, 0.1) if bank_amounts[resource] <= 3 else Color(0.1, 0.1, 0.1)
	)


func _refresh_dev_label():
	if not _dev_label:
		return
	_dev_label.text = str(dev_cards_remaining)
	_dev_label.add_theme_color_override(
		"font_color", Color(0.8, 0.1, 0.1) if dev_cards_remaining <= 3 else Color(0.1, 0.1, 0.1)
	)


func take_resource(resource: String, amount: int) -> bool:
	if not bank_amounts.has(resource):
		return false

	if bank_amounts[resource] < amount:
		print("Banco sem recurso:", resource)
		return false

	bank_amounts[resource] -= amount
	_refresh_label(resource)

	return true
