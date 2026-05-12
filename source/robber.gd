extends Sprite2D


func moving_to(new_pos: Vector2, immediate: bool = false):
	if immediate:
		global_position = new_pos
	else:
		var tween = create_tween()
		(
			tween
			. tween_property(self, "global_position", new_pos, 0.5)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)
