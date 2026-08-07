extends Node2D
class_name SpaceProp

# Runtime for the drifting scenery under scenes/environment/ — trash, scraps,
# asteroids and shrines.
#
# These are set in motion once at spawn and then never steered: constant
# velocity, constant spin, no physics response. Nothing can push them, because
# they aren't bodies in the first place — the collision inside them belongs to
# their own TileMapLayer, which is static geometry that the ship and the
# enemies slide along.
#
# They clean themselves up on distance rather than on a timer, so a prop the
# player is still flying toward never vanishes mid-approach.

## How far the player has to get before this is culled.
const DESPAWN_DISTANCE := 5000.0

## Only checked a few times a second — distance culling doesn't need to be
## frame-accurate and there can be a lot of these.
const CULL_INTERVAL := 0.5

var drift: Vector2 = Vector2.ZERO
var spin: float = 0.0

var _player: Node2D = null
var _cull_timer: float = 0.0


func _ready() -> void:
	add_to_group("space_props")
	_cull_timer = randf() * CULL_INTERVAL   # stagger the checks across props


func _process(delta: float) -> void:
	global_position += drift * delta
	rotation += spin * delta

	_cull_timer -= delta
	if _cull_timer > 0.0:
		return
	_cull_timer = CULL_INTERVAL

	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("friendlies")
		if players.is_empty():
			return
		_player = players[0]

	if global_position.distance_to(_player.global_position) > DESPAWN_DISTANCE:
		queue_free()
