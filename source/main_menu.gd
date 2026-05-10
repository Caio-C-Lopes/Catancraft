extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	main_buttons.visible = true
	options.visible = false

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options: Panel = $Options
@onready var audio_player = $AudioStreamPlayer2D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_game_pressed() -> void:
	audio_player.play()
	print("Playing...")
	get_tree().change_scene_to_file("res://game.tscn")

func _on_options_pressed() -> void:
	audio_player.play()
	main_buttons.visible = false
	options.visible = true


func _on_quit_pressed() -> void:
	audio_player.play()
	get_tree().quit()


func _on_back_options_pressed() -> void:
	audio_player.play()
	_ready()
