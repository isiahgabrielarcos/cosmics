extends EnemyUnit
class_name EnemyBomber

# Walks straight at the player and stays upright — no facing rotation —
# then detonates the instant it makes contact instead of ticking damage.

const STOP_DISTANCE := 20.0
const BLAST_REACH := 55.0


func _move(_delta: float) -> void:
	var offset := _player.global_position - global_position
	if offset.length() < STOP_DISTANCE:
		velocity = Vector2.ZERO
	else:
		velocity = offset.normalized() * data.speed
	# no _face_player() call — bombers stay upright


func _check_contact() -> void:
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) > BLAST_REACH * scale.x:
		return
	AudioManager.play_sfx("explosionSound")
	if _player.has_method("take_damage"):
		_player.take_damage(data.contact_damage)
	_die(false)
