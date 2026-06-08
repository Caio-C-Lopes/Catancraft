# bot_trade_offer.gd
extends Control

signal trade_accepted(bot_id: int)
signal trade_refused(bot_id: int)

var _bot_id: int = -1
var _give_res: String = ""
var _recv_res: String = ""
var _timer: float = 0.0
var _timeout: float = 20.0
var _active: bool = false

@onready var _timer_label: Label = $Panel/VBox/TimerLabel
@onready var _offer_label: Label = $Panel/VBox/OfferLabel
@onready var _accept_btn: Button = $Panel/VBox/HBox/AcceptBtn
@onready var _refuse_btn: Button = $Panel/VBox/HBox/RefuseBtn


func _ready():
	hide()
	_build_ui()


func _build_ui():
	# Painel principal
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 250)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0, 0, 0, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 15)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	# Título
	var title = Label.new()
	title.text = "Proposta de Troca"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Label da oferta
	_offer_label = Label.new()
	_offer_label.text = ""
	_offer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_label.add_theme_font_size_override("font_size", 14)
	_offer_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_offer_label)

	# Timer
	_timer_label = Label.new()
	_timer_label.text = "20s"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 14)
	_timer_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	vbox.add_child(_timer_label)

	# Botões
	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	_accept_btn = Button.new()
	_accept_btn.text = "Aceitar"
	_accept_btn.custom_minimum_size = Vector2(120, 50)
	_accept_btn.pressed.connect(_on_accept)
	hbox.add_child(_accept_btn)

	_refuse_btn = Button.new()
	_refuse_btn.text = "Recusar"
	_refuse_btn.custom_minimum_size = Vector2(120, 50)
	_refuse_btn.pressed.connect(_on_refuse)
	hbox.add_child(_refuse_btn)


func show_offer(bot_id: int, bot_name: String, give_res: String, recv_res: String):
	_bot_id = bot_id
	_give_res = give_res
	_recv_res = recv_res
	_timer = _timeout
	_active = true

	# Traduz nomes dos recursos
	var give_name = _translate_resource(give_res)
	var recv_name = _translate_resource(recv_res)

	_offer_label.text = (
		"%s oferece:\n1x %s\n\nEm troca de:\n1x %s" % [bot_name, recv_name, give_name]
	)
	_timer_label.text = "%ds" % ceil(_timer)

	show()


func _translate_resource(res: String) -> String:
	match res:
		"wood":
			return "Madeira"
		"brick":
			return "Tijolo"
		"wheat":
			return "Trigo"
		"sheep":
			return "Lã"
		"ore":
			return "Minério"
	return res


func _process(delta):
	if not _active:
		return

	_timer -= delta
	_timer_label.text = "%ds" % ceil(_timer)

	if _timer <= 5:
		_timer_label.add_theme_color_override("font_color", Color(1, 0, 0))

	if _timer <= 0:
		_on_timeout()


func _on_accept():
	_active = false
	hide()
	emit_signal("trade_accepted", _bot_id)


func _on_refuse():
	_active = false
	hide()
	emit_signal("trade_refused", _bot_id)


func _on_timeout():
	_active = false
	hide()
	print("[TIMEOUT] Troca recusada automaticamente.")
	emit_signal("trade_refused", _bot_id)
