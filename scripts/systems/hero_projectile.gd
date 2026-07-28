extends Area2D
class_name HeroProjectile

# Generic hero projectile — ports whichAim()/otherAims() from globalFunctions.lua.
# All 7 weapon types build one of these with different sprites/behaviours.

var speed: float = 800.0
var damage: int = 20
var pierce: int = 2
var lifetime: float = 1.0
var direction: Vector2 = Vector2.UP
var follow_target: Node2D = null      # weapons 5 & 7 stick to the hero
var spin_speed: float = 0.0            # radians/sec (weapon 5 sweep)
var scorching: bool = false            # scorching-attack module proc (red)
var electric: bool = false             # electric-attack module proc (yellow)

var _age: float = 0.0
var _hit_enemies: Array = []


static func create(cfg: Dictionary) -> HeroProjectile:
	var p := HeroProjectile.new()

	# Visual — either a static texture or an animated sheet
	if cfg.has("frames"):
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = cfg["frames"]
		anim.play("moving")
		p.add_child(anim)
	elif cfg.has("texture"):
		var spr := Sprite2D.new()
		spr.texture = cfg["texture"]
		p.add_child(spr)

	# Collision
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = cfg.get("radius", 14.0)
	shape.shape = circle
	p.add_child(shape)

	p.speed     = cfg.get("speed", 800.0)
	p.damage    = cfg.get("damage", 20)
	p.pierce    = cfg.get("pierce", 2)
	p.lifetime  = cfg.get("lifetime", 1.0)
	p.direction = cfg.get("direction", Vector2.UP)
	p.scale     = Vector2.ONE * cfg.get("visual_scale", 2.0)
	p.rotation  = cfg.get("rotation", 0.0)
	p.modulate.a = cfg.get("alpha", 1.0)
	p.follow_target = cfg.get("follow_target", null)
	p.spin_speed    = cfg.get("spin_speed", 0.0)

	p.collision_layer = 2   # Bullets
	p.collision_mask  = 0b111101  # everything but bullets
	return p


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if scorching:
		modulate = Color(1, 0.35, 0.35)
	elif electric:
		modulate = Color(1, 1, 0.35)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_pop()
		return

	if follow_target and is_instance_valid(follow_target):
		global_position = follow_target.global_position
	else:
		global_position += direction * speed * delta

	if spin_speed != 0.0:
		rotation += spin_speed * delta


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area.get_parent())


func _try_hit(node: Node) -> void:
	if node == null or not node.is_in_group("enemies"):
		return
	if node in _hit_enemies:
		return
	_hit_enemies.append(node)

	if node.has_method("apply_damage"):
		var final_damage := damage
		if scorching:
			final_damage = int(damage * 1.5)
		node.apply_damage(final_damage)

	pierce -= 1
	if pierce <= 0 and follow_target == null:
		_pop()


func _pop() -> void:
	queue_free()
