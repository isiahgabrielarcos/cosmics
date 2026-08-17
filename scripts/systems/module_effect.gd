extends Area2D
class_name ModuleEffect

# Shared runtime for the module attacks under scenes/modules/. Ports the
# collision half of activateGlobalModuleCollisions() — each of those Lua
# branches was the same thing with a different flag, so this is one node with
# the differences exported instead.
#
# Two shapes:
#   BURST   — a pulse that sits where it spawned (optionally riding the ship)
#             and hits everything inside it for `lifetime`. Shockwave,
#             Electric Aura, Energy Outburst, Dash Shockwave.
#   TRAVEL  — a projectile that flies along `direction`. Comets, Electro
#             Bubbles.
#
# ModuleSystem sets damage/radius/duration at spawn, so a module upgrade is a
# number change rather than a new scene.

enum Kind { BURST, TRAVEL }

@export var kind: Kind = Kind.BURST
@export var lifetime: float = 0.5
@export var speed: float = 0.0

## Set by ModuleSystem at spawn from the module's current upgrade level.
var damage: int = 0
var radius: float = 100.0
var direction: Vector2 = Vector2.RIGHT
var pierce: int = 99

## Status this effect inflicts on hit, if any.
var paralysis_duration: float = 0.0
var burn_ticks: int = 0
var burn_damage: int = 0

## BURST only — rides the ship instead of staying where it went off.
var follow_target: Node2D = null

## Re-hits on an interval (the aura ticking, or a drifting field sweeping up
## whatever wanders into it). Left at 0, each enemy is damaged once.
@export var retick_interval: float = 0.0

## Stretch the sprite to match `radius`. On for round fields, off for art
## that has its own silhouette (the comet).
@export var scale_sprite_to_radius: bool = true

var _age: float = 0.0
var _retick_timer: float = 0.0
var _hit_enemies: Array = []

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	collision_layer = 2           # Bullets
	collision_mask  = EnemyUnit.HOSTILE_MASK   # every enemy lane

	# Effects are spawned into the world alongside the drifting scenery, which
	# reaches z_index 8. Without this a burst going off around the ship was
	# drawn underneath the nearest asteroid and simply never seen.
	z_index = 15

	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	# The authored shapes carry a node scale (the shockwave's was over 9x) that
	# was left in place while the radius was overwritten here, multiplying the
	# real hitbox by it. That is why the shockwave paralysed things far outside
	# anything the player could see. `radius` is the whole truth now.
	_shape.scale = Vector2.ONE

	# The 96px-wide art is authored for a 48px radius, so anything whose
	# radius is set at spawn has to stretch its sprite to match. Off for the
	# comet, whose art is its own shape rather than a round field.
	if scale_sprite_to_radius:
		_sprite.scale = Vector2.ONE * (radius / 48.0)

	_sprite.play("moving")
	body_entered.connect(_on_body_entered)
	area_entered.connect(func(area: Area2D): _try_hit(area.get_parent()))

	if kind == Kind.BURST:
		# Bursts arrive already covering their area, so anything standing
		# inside at spawn has to be caught explicitly — body_entered only
		# fires on movement across the boundary.
		call_deferred("_sweep_overlaps")


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	match kind:
		Kind.TRAVEL:
			global_position += direction * speed * delta
		Kind.BURST:
			if follow_target and is_instance_valid(follow_target):
				global_position = follow_target.global_position

	if retick_interval > 0.0:
		_retick_timer -= delta
		if _retick_timer <= 0.0:
			_retick_timer = retick_interval
			_hit_enemies.clear()
			_sweep_overlaps()


func _sweep_overlaps() -> void:
	if not is_inside_tree():
		return
	for body in get_overlapping_bodies():
		_try_hit(body)
	for area in get_overlapping_areas():
		_try_hit(area.get_parent())


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _try_hit(node: Node) -> void:
	if node == null or not node.is_in_group("enemies"):
		return
	if node in _hit_enemies:
		return
	_hit_enemies.append(node)

	if damage > 0 and node.has_method("apply_damage"):
		node.apply_damage(damage)
	if not is_instance_valid(node):
		return

	if paralysis_duration > 0.0 and node.has_method("apply_paralysis"):
		node.apply_paralysis(paralysis_duration)
	if burn_ticks > 0 and node.has_method("apply_burn"):
		node.apply_burn(burn_damage, burn_ticks)

	if kind == Kind.TRAVEL:
		pierce -= 1
		if pierce <= 0:
			queue_free()
