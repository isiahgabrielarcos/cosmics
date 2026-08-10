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

# ── Salvage ───────────────────────────────────────────────────────────────────
# Space trash is worth Central Cosmic Currency: fly into it and it's collected.
# The payout goes into the run's haul, so it shows up live in the inventory and
# banks with everything else when the contract completes.

## What one piece of trash is worth.
const TRASH_CC_VALUE := 10

## Categories that can be picked up, and what each pays.
const SALVAGE_VALUES := { "trash": TRASH_CC_VALUE }

var drift: Vector2 = Vector2.ZERO
var spin: float = 0.0

var _player: Node2D = null
var _cull_timer: float = 0.0
var _collected: bool = false


func _ready() -> void:
	add_to_group("space_props")
	_cull_timer = randf() * CULL_INTERVAL   # stagger the checks across props
	# Deferred: the spawner records prop_radius just *after* add_child returns,
	# and the fallback pickup shape is sized from it.
	call_deferred("_arm_salvage")


## Wires up the pickup trigger. An Area2D authored into the prop scene is used
## as-is — that's the hook for hand-placed pickup shapes. If the prop doesn't
## have one, a circle sized to its own tiles is fitted instead, so trash is
## collectible whether or not its scene has been given a shape yet.
##
## Only ever armed on the solid layer: the parallax decor layers are scenery a
## long way off, and letting the player bank currency by flying "through"
## something painted in the far distance would be nonsense.
func _arm_salvage() -> void:
	var category := str(get_meta("prop_category", ""))
	if not SALVAGE_VALUES.has(category):
		return
	if int(get_meta("prop_layer", 0)) != 0:
		return

	var area := _find_area()
	if area == null:
		area = Area2D.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		# Radius the spawner already measured for this prop, in local terms.
		circle.radius = maxf(24.0, float(get_meta("prop_radius", 60.0))
			/ maxf(absf(global_scale.x), 0.01))
		shape.shape = circle
		area.add_child(shape)
		# The ship sits on the default entity layer; an authored Area2D keeps
		# whatever mask it was given.
		area.collision_mask = 1
		add_child(area)

	# Watch for the ship only — enemies shouldn't hoover up the salvage.
	area.monitoring = true
	area.body_entered.connect(_on_salvage_touched)


func _find_area() -> Area2D:
	for child in get_children():
		if child is Area2D:
			return child
	return null


func _on_salvage_touched(body: Node) -> void:
	if _collected or not body.is_in_group("friendlies"):
		return
	_collected = true
	GameManager.collect_currency(
		int(SALVAGE_VALUES.get(str(get_meta("prop_category", "")), 0)))
	AudioManager.play_sfx("cosmicShards")
	queue_free()


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
