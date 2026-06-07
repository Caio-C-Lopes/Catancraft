extends CanvasLayer

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause()


func toggle_pause() -> void:
	var is_paused: bool = get_tree().paused
	get_tree().paused = !is_paused
	visible = get_tree().paused


func _on_resume_button_pressed() -> void:
	audio_player.play()
	toggle_pause()


func _on_quit_button_pressed() -> void:
	audio_player.play()
	get_tree().paused = false
	BoardState.reset_state()
	get_tree().change_scene_to_file("res://main_menu.tscn")
