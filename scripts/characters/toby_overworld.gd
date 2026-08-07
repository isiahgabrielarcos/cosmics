extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var top_order: Area2D = $TopOrder
@onready var low_order: Area2D = $"Low Order"

const SPEED := 300.0

# Fake depth against the walls and the NPCs. Two probes straddle the sprite:
# when the head probe is inside something solid, Toby is standing in front of
# it and draws over the top; when the feet probe is, he's standing behind it
# and drops under. Clear of both, he sits at the default.
#
# The walls are TileMapLayer collision, which reports as *bodies* — overlaps
# are polled each frame rather than signalled, so leaving a wall restores the
# order without needing to pair up enter/exit events.
const Z_IN_FRONT := 2
const Z_DEFAULT  := 1
const Z_BEHIND   := 0


func _ready() -> void:
	add_to_group("friendlies")
	sprite.play("down")


func _physics_process(_delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down")  - Input.get_action_strength("up")
	)

	if dir != Vector2.ZERO:
		velocity = dir.normalized() * SPEED
		_update_animation(dir)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_update_draw_order()


func _update_draw_order() -> void:
	if _touching_occluder(top_order):
		z_index = Z_IN_FRONT
	elif _touching_occluder(low_order):
		z_index = Z_BEHIND
	else:
		z_index = Z_DEFAULT


## Anything solid that Toby can stand in front of or behind: the wall tiles
## (physics layer 1, shared with Toby himself) and the NPCs' blocking bodies
## (layer 7). The probes mask both, so this only has to discount Toby.
func _touching_occluder(probe: Area2D) -> bool:
	for body in probe.get_overlapping_bodies():
		if body == self or body.is_in_group("friendlies"):
			continue
		return true
	return false


func _update_animation(dir: Vector2) -> void:
	# Up/down override left/right
	if dir.y < 0:
		sprite.play("up")
	elif dir.y > 0:
		sprite.play("down")
	elif dir.x < 0:
		sprite.play("left")
	else:
		sprite.play("right")
