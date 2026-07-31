extends EnemyUnit
class_name EnemySlasher

# Approaches slowly; once within data.slash_range (100px by default), dashes
# straight through the player at high speed, then cools down before it can
# slash again.

var _slashing: bool = false
var _slash_dir: Vector2 = Vector2.ZERO
var _cooldown: float = 0.0


func _move(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	if _slashing:
		velocity = _slash_dir * data.slash_speed
		return

	var offset := _player.global_position - global_position
	if offset.length() <= data.slash_range and _cooldown <= 0.0:
		_start_slash(offset)
		return

	velocity = offset.normalized() * data.speed
	_face_player(data.turn_rate)


func _start_slash(offset: Vector2) -> void:
	_slashing = true
	_slash_dir = offset.normalized()
	_face_player(20.0)
	AudioManager.play_sfx("weapon6Shoot")

	var t := create_tween()
	t.tween_interval(0.22)
	t.tween_callback(_end_slash)


func _end_slash() -> void:
	_slashing = false
	_cooldown = data.slash_cooldown
