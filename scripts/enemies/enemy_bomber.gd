extends EnemyUnit
class_name EnemyBomber

# Walks straight at the player and stays upright — no facing rotation —
# then detonates the instant it makes contact instead of ticking damage.

const STOP_DISTANCE := 20.0


func _move(_delta: float) -> void:
	var offset := _player.global_position - global_position
	if offset.length() < STOP_DISTANCE:
		velocity = Vector2.ZERO
	else:
		velocity = offset.normalized() * data.speed
	# no _face_player() call — bombers stay upright


## Detonates only on genuine hull contact. This used to use its own inflated
## reach (55 * scale, ignoring the player entirely), which had bombers going
## off a body-length away from the ship.
func _check_contact() -> void:
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) > contact_reach():
		return
	AudioManager.play_sfx("explosionSound")
	if _player.has_method("take_damage"):
		# the instance value, not data's — difficulty scaling lives on the unit
		_player.take_damage(contact_damage, self)
	_die(false)
