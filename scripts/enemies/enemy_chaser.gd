extends EnemyUnit
class_name EnemyChaser

# Chases the player and turns to face them. Reused for both the slow
# "chaser" and fast "ship" archetypes (speed/turn_rate come from EnemyData),
# the tanky Strogghold boss, the splitting Squilltrant boss, the FlaschBourn
# chaser+shooter boss (via data.fires_projectiles), and mama/baby slime.

const STOP_DISTANCE := 50.0


func _move(_delta: float) -> void:
	var offset := _player.global_position - global_position
	if offset.length() < STOP_DISTANCE:
		velocity = Vector2.ZERO
	else:
		velocity = offset.normalized() * data.speed
	_face_player(data.turn_rate)
