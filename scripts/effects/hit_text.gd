extends Label
class_name HitText

# Floating damage-number popup. White for damage dealt to enemies, bright red
# for damage taken by the player — the caller passes the color at spawn time.
# Rises, fades out, then frees itself.

const RISE_DISTANCE := 60.0
const DURATION := 0.6

const BURN_COLOR := Color(1.0, 0.45, 0.15)
const PARALYSIS_COLOR := Color(1.0, 0.95, 0.35)


static func spawn(parent: Node, pos: Vector2, amount: int, color: Color = Color.WHITE) -> HitText:
	return _make(parent, pos, str(amount), color)


## Status callout ("BURN!", "PARALYZED!") — spawns higher than damage numbers
## so it doesn't collide with the tick damage landing on the same enemy.
static func spawn_status(parent: Node, pos: Vector2, label: String, color: Color) -> HitText:
	return _make(parent, pos + Vector2(0.0, -34.0), label, color)


static func _make(parent: Node, pos: Vector2, label: String, color: Color) -> HitText:
	var txt: HitText = preload("res://scenes/effects/hit_text.tscn").instantiate()
	txt.global_position = pos + Vector2(-70.0 + randf_range(-14.0, 14.0), -50.0)
	parent.add_child(txt)
	txt._play(label, color)
	return txt


func _play(label: String, color: Color) -> void:
	text = label
	modulate = color

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, DURATION * 0.6).set_delay(DURATION * 0.4)
	tw.tween_callback(queue_free).set_delay(DURATION)
