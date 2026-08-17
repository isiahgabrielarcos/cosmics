extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var top_order: Area2D = $TopOrder
@onready var low_order: Area2D = $"Low Order"

const SPEED := 300.0

# ── Sprint ────────────────────────────────────────────────────────────────────
# The hub is a big place to cross at walking pace, so holding the dash key
# breaks into a run. Deliberately simpler than the ship's boost: no fuel, no
# cooldown and no lockout, because nothing here is chasing you and a stamina
# bar would only add bookkeeping to walking across a room.
#
# The animation is sped up rather than swapped, so it reads as the same Toby
# moving faster instead of needing a second set of frames.
const SPRINT_MULTIPLIER := 1.9
const SPRINT_ANIM_SPEED := 1.7

var is_sprinting: bool = false

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

	# Held, not tapped, and only while actually moving — standing still while
	# holding the key shouldn't play a run on the spot.
	is_sprinting = Input.is_action_pressed("boost") and dir != Vector2.ZERO \
		and not GameManager.ui_open

	if dir != Vector2.ZERO:
		velocity = dir.normalized() * SPEED * (SPRINT_MULTIPLIER if is_sprinting else 1.0)
		_update_animation(dir)
		sprite.speed_scale = SPRINT_ANIM_SPEED if is_sprinting else 1.0
	else:
		velocity = Vector2.ZERO
		sprite.speed_scale = 1.0

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
