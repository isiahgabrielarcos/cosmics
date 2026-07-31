extends EnemyUnit
class_name EnemyShooter

# Creeps toward the player at a crawl and fires from range (data.speed is
# tiny — "very very slow"), backing off once close instead of closing to melee.

const MIN_DISTANCE := 450.0


func _move(_delta: float) -> void:
	var offset := _player.global_position - global_position
	if offset.length() > MIN_DISTANCE:
		velocity = offset.normalized() * data.speed
	else:
		velocity = Vector2.ZERO
	_face_player(4.0)
