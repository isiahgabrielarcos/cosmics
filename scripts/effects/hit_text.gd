extends Label
class_name HitText

# Floating damage-number popup. White for damage dealt to enemies, bright red
# for damage taken by the player — the caller passes the color at spawn time.
# Rises, fades out, then frees itself.

const RISE_DISTANCE := 60.0
const DURATION := 0.6


static func spawn(parent: Node, pos: Vector2, amount: int, color: Color = Color.WHITE) -> HitText:
	var txt: HitText = preload("res://scenes/effects/hit_text.tscn").instantiate()
	txt.global_position = pos + Vector2(-70.0 + randf_range(-14.0, 14.0), -50.0)
	parent.add_child(txt)
	txt._play(amount, color)
	return txt


func _play(amount: int, color: Color) -> void:
	text = str(amount)
	modulate = color

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, DURATION * 0.6).set_delay(DURATION * 0.4)
	tw.tween_callback(queue_free).set_delay(DURATION)
