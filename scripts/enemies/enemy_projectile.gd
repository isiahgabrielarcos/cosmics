extends Area2D
class_name EnemyProjectile

# Ports the enemyShooter() projectile — laserBeam1.png fired at the hero,
# damage 5, ~5 s lifetime.

const TEX := preload("res://assets/art/characters/laserBeam1.png")
const POP_FX := preload("res://scenes/effects/particle_projectile_pop.tscn")

const BASE_RADIUS := 10.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: int = 5
var lifetime: float = 5.0

## Sprite and hitbox multiplier. The FlaschBourn boss fires rounds several
## times this size, so the hitbox has to scale with the art rather than the
## shot being a huge sprite you can fly straight through.
var size_scale: float = 1.0

var _age: float = 0.0


func _ready() -> void:
	var spr := Sprite2D.new()
	spr.texture = TEX
	spr.scale = Vector2(size_scale, size_scale)
	add_child(spr)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BASE_RADIUS * size_scale
	shape.shape = circle
	add_child(shape)

	rotation = direction.angle() + PI / 2.0
	# On the Bullets layer so weapons that swat projectiles can detect it;
	# it still only *looks* for the player.
	collision_layer = 2
	collision_mask = 1
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_pop()
		return
	global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("friendlies") and body.has_method("take_damage"):
		body.take_damage(damage)
		_pop()


## Shot down by a player weapon rather than by hitting something.
func destroy() -> void:
	_pop()


func _pop() -> void:
	ParticleEffect.spawn(POP_FX, get_tree().current_scene, global_position)
	queue_free()
